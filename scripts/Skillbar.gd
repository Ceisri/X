extends Control

onready var player = $"../.."
onready var character_ui =  $"../Menu/CharacterBar"
onready var animationcalls = $"../../AnimationCalls"
onready var anim_calls = $"../../AnimationCalls"
onready var grid:GridContainer =  $GridContainer
onready var grid2:GridContainer = $GridContainer2 
onready var expand_button = $ExpandCollapse
onready var inventory_grid: GridContainer = $"../Inventory/ScrollContainer/GridContainer"
onready var inventory = $"../Inventory"
onready var stats:Node = $"../../Stats"
onready var tween: Tween = $Tween
onready var tween2:Tween = $Tween2
var skill_bar_input:String = ""
var active_cooldowns = {}
var edit = false
var capture_slot = null
var expand_state = 0
var mouse_repeat_counter={}

var no_press_tween_skills=["combo attack","guard"]
var hold_skills={
	"guard":true,
	"combo attack":true,
}
var _skill_slot_cache := {} # skill_name -> Array of {"action":String,"slot":TextureRect}
var _skill_slot_cache_dirty := true
var _last_hold_inputs_frame:int = -1
var combo_queue:int= 0
const COMBO_QUEUE_MAX :int= 2
var combo_atk_mode_hold:bool = false #false = click to attack, true = hold to attack like taking down a tree in minecraft
var continue_combo_atk:bool = true#this sets combo attack to true and the animation continenues till this is false, set it false in animaiton cals, saves time in Animation creation
var _cd_cache := []
var _cd_cache2 := []
var _inv_cd_cache := []
var cooldown_label_update_interval:int= 6
const CONFIG_FILE_PATH = "user://skillbar_keybinds.cfg"
const ACTION_PREFIX = "skill_slot_"
const ACTION_PREFIX2="mouse_slot_"
func _ready():
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		# Remote/puppet players must never touch global InputMap actions or
		# process input here — Skillbar reads/writes InputMap.action_* by a
		# fixed name (skill_slot_N / mouse_slot_N), which is shared across
		# every Player.tscn instance in the tree. Letting a remote player's
		# Skillbar run loadKeybinds()/_physics_process()/_input() would
		# silently overwrite the local player's keybinds and react to their
		# key presses.
		set_physics_process(false)
		set_process_input(false)
		set_process(false)
		return

	loadKeybinds()
	connectButtons()
	resetSkillRuntime()
	call_deferred("initializeSkillsToPreventAstupidFuckingBugIDontKnowHowToFix")

	
var _warming_up_skills:bool= false
const SKILL_INIT_PASSES = 1
func initializeSkillsToPreventAstupidFuckingBugIDontKnowHowToFix()->void:
	if player == null or grid == null or grid2 == null:
		return

	var energy_before = stats.energy
	var health_before = stats.health
	var cooldowns_before = active_cooldowns.duplicate(true)

	_warming_up_skills = true

	for _i in range(SKILL_INIT_PASSES):
		for key in player.anim_locks.keys():
			player.anim_locks[key] = true
		for key in player.anim_locks.keys():
			player.anim_locks[key] = false

		for container in [grid,grid2]:
			for holder in container.get_children():
				var slot = holder.get_node("Slot")
				if !slot.texture:
					continue
				var skill_data_ = getSkillData(slot)
				if skill_data_ == null:
					continue
				if hold_skills.has(skill_data_["skill_name"]):
					continue

				anim_calls.unlockAnim()
				skills(slot)
				var warm_delta = get_physics_process_delta_time()
				if player.has_method("animationOrder"):
					player.animationOrder(warm_delta)

				reimburseSkill(skill_data_["skill_name"])

	_warming_up_skills = false

	anim_calls.unlockAnim()
	player.current_skill = ""
	active_cooldowns = cooldowns_before.duplicate(true)
	stats.energy = energy_before
	stats.health = health_before
	character_ui.updateBars()
	player.is_in_combat = false

func resetSkillRuntime():#initialization to prevent bugs where multiple inputs are possible at the start of the game 
	active_cooldowns.clear()
	continue_combo_atk = true
	input_lock = false
	input_lock_time = 0.0
	player.current_skill = ""
	for k in player.anim_locks.keys():
		player.anim_locks[k] = false









# ---------- skillbar save/load, routed through World.gd (same pattern as Inventory.gd) ----------

func gatherSkillbarSnapshot() -> Dictionary:
	var data := {
		"cooldowns": active_cooldowns.duplicate(true),
		"expand_state": expand_state,
		"combo_atk_mode_hold": combo_atk_mode_hold,
		"keys": {}, "mouse_keys": {}, "slots": {}, "slots2": {}, "quantities": {}, "quantities2": {}
	}
	for i in range(grid.get_child_count()):
		var scancode = -1
		for e in InputMap.get_action_list(ACTION_PREFIX+str(i)):
			if e is InputEventKey:
				scancode = e.scancode
				break
		data["keys"][str(i)] = scancode
		var holder = grid.get_child(i)
		var slot = holder.get_node("Slot")
		data["slots"][str(i)] = slot.texture.resource_path if slot.texture != null else ""
		var button = holder.get_node_or_null("TextureButton")
		data["quantities"][str(i)] = int(button.quantity) if is_instance_valid(button) and "quantity" in button else 0
	for i in range(grid2.get_child_count()):
		var button_idx = -1
		for e in InputMap.get_action_list(ACTION_PREFIX2+str(i)):
			if e is InputEventMouseButton:
				button_idx = e.button_index
				break
		data["mouse_keys"][str(i)] = button_idx
		var holder2 = grid2.get_child(i)
		var slot2 = holder2.get_node("Slot")
		data["slots2"][str(i)] = slot2.texture.resource_path if slot2.texture != null else ""
		var button2 = holder2.get_node_or_null("TextureButton")
		data["quantities2"][str(i)] = int(button2.quantity) if is_instance_valid(button2) and "quantity" in button2 else 0
	# never hand back a snapshot where every slot is empty if we
	# have previously captured a real, non-empty snapshot this session.
	# A momentary blank grid (mid-reinit, mid-load) must never be allowed
	# to look like "the player deliberately emptied their bar."
	if _isSnapshotEmpty(data) and !_last_known_good_snapshot.empty():
		return _last_known_good_snapshot.duplicate(true)

	if !_isSnapshotEmpty(data):
		_last_known_good_snapshot = data.duplicate(true)

	return data
func _isSnapshotEmpty(data:Dictionary) -> bool:
	for key in ["slots","slots2"]:
		if !data.has(key):
			continue
		for slot_index in data[key]:
			if str(data[key][slot_index]) != "":
				return false
	return true
remote func applyOwnSkillbarSnapshot(data: Dictionary) -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if data.empty():
		return

	if data.has("expand_state"): expand_state = data["expand_state"]
	if data.has("combo_atk_mode_hold"): combo_atk_mode_hold = data["combo_atk_mode_hold"]
	if data.has("cooldowns"): active_cooldowns = data["cooldowns"].duplicate(true)

	if data.has("keys"):
		for i in range(grid.get_child_count()):
			if !data["keys"].has(str(i)): continue
			var scancode = int(data["keys"][str(i)])
			if scancode <= 0: continue
			var action_name = ACTION_PREFIX+str(i)
			if !InputMap.has_action(action_name): InputMap.add_action(action_name)
			InputMap.action_erase_events(action_name)
			var e = InputEventKey.new(); e.scancode = scancode
			InputMap.action_add_event(action_name, e)
			var s = InputEventKey.new(); s.scancode = scancode; s.shift = true
			InputMap.action_add_event(action_name, s)
			grid.get_child(i).get_node("Key").text = OS.get_scancode_string(scancode).to_upper()

	if data.has("mouse_keys"):
		for i in range(grid2.get_child_count()):
			if !data["mouse_keys"].has(str(i)): continue
			var button_index = int(data["mouse_keys"][str(i)])
			if button_index <= 0: continue
			var action_name = ACTION_PREFIX2+str(i)
			if !InputMap.has_action(action_name): InputMap.add_action(action_name)
			InputMap.action_erase_events(action_name)
			var e = InputEventMouseButton.new(); e.button_index = button_index
			InputMap.action_add_event(action_name, e)
			var holder = grid2.get_child(i)
			match button_index:
				BUTTON_LEFT: holder.get_node("Key").text = "LM"
				BUTTON_RIGHT: holder.get_node("Key").text = "RM"
				BUTTON_MIDDLE: holder.get_node("Key").text = "MM"
				_: holder.get_node("Key").text = "M"+str(button_index)

	if data.has("slots"):
		for i in range(grid.get_child_count()):
			if !data["slots"].has(str(i)): continue
			var path = str(data["slots"][str(i)])
			var holder = grid.get_child(i)
			var slot = holder.get_node("Slot")
			slot.texture = load(path) if path != "" and ResourceLoader.exists(path) else null
			var button = holder.get_node_or_null("TextureButton")
			if is_instance_valid(button) and "quantity" in button:
				var qty := 0
				if data.has("quantities") and data["quantities"].has(str(i)):
					qty = int(data["quantities"][str(i)])
				button.quantity = qty

	if data.has("slots2"):
		for i in range(grid2.get_child_count()):
			if !data["slots2"].has(str(i)): continue
			var path2 = str(data["slots2"][str(i)])
			var holder2 = grid2.get_child(i)
			var slot2 = holder2.get_node("Slot")
			slot2.texture = load(path2) if path2 != "" and ResourceLoader.exists(path2) else null
			var button2 = holder2.get_node_or_null("TextureButton")
			if is_instance_valid(button2) and "quantity" in button2:
				var qty2 := 0
				if data.has("quantities2") and data["quantities2"].has(str(i)):
					qty2 = int(data["quantities2"][str(i)])
					button2.quantity = qty2
	if !_isSnapshotEmpty(data):
		_last_known_good_snapshot = data.duplicate(true)
	applyExpandState()
	markSkillSlotCacheDirty()
var _last_known_good_snapshot := {}
func saveData()->void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	# FIX: never write this bar to disk until this player's own real
	# skillbar data has actually finished loading/applying. Saving before
	# that point (pooled-node reuse, snapshot RPC still in flight) would
	# capture whatever blank/default grid state currently exists and
	# permanently overwrite the real save with it.
	if "data_fully_loaded" in player and !player.data_fully_loaded:
		return
	var world = player.get_parent()
	if is_instance_valid(world) and world.has_method("saveSkillbarFor"):
		world.saveSkillbarFor(player, gatherSkillbarSnapshot())

# server calls this on the owning client during periodic autosave for remote players
remote func requestSelfSaveSkillbar() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if "data_fully_loaded" in player and !player.data_fully_loaded:
		return
	saveData()




























func consumeCombo():#called by the node AnimationCalls in animation call tracks for combo attack animations, enables queuing multiple base attacks 
	if stats.health <= 0:
		continue_combo_atk=false
		combo_queue=0
	if combo_queue>0:
		if !player.anim_locks["flinch"] and !player.anim_locks["knocked back"] and !player.anim_locks["knocked down"]:
			continue_combo_atk=true
			combo_queue-=1
	elif combo_atk_mode_hold:
		var combo_held=false

		for i in range(grid.get_child_count()):
			var slot=grid.get_child(i).get_node("Slot")
			if slot.texture==Global.skills["combo attack"] and Input.is_action_pressed(ACTION_PREFIX+str(i)):
				combo_held=true
				break

		if !combo_held:
			for i in range(grid2.get_child_count()):
				var slot=grid2.get_child(i).get_node("Slot")
				if slot.texture==Global.skills["combo attack"] and Input.is_action_pressed(ACTION_PREFIX2+str(i)):
					combo_held=true
					break

		if combo_held and !player.anim_locks["flinch"] and !player.anim_locks["knocked back"] and !player.anim_locks["knocked down"]:
			continue_combo_atk=true
			


var input_lock_time := 0.0
var input_lock := false
var _last_processed_visual_frame:int = -1
func _physics_process(delta):
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return

	input_lock_time -= delta
	if input_lock_time <= 0:
		input_lock = false


	handleObliterationCharge()
	if Engine.get_physics_frames() % 6 == 0:
		updateSkillAvailabilityVisuals()
	if Engine.get_physics_frames() % 60 == 0:
		updateCooldowns()
	var visual_frame:int = Engine.get_frames_drawn()
	if visual_frame == _last_processed_visual_frame:
		return
	_last_processed_visual_frame = visual_frame
	if player.cursor_visible == false:
		holdInputs()

	if Engine.get_physics_frames() % 180 == 0:
		markSkillSlotCacheDirty()
	if player.cursor_visible == false:
		matchInputSlot()







func markSkillSlotCacheDirty() -> void:
	_skill_slot_cache_dirty = true

func rebuildSkillSlotCache() -> void:
	_skill_slot_cache.clear()
	for i in range(grid.get_child_count()):
		var slot = grid.get_child(i).get_node("Slot")
		if slot.texture == null:
			continue
		var data = getSkillData(slot)
		if data == null:
			continue
		var arr = _skill_slot_cache.get(data.skill_name, [])
		arr.append({"action": ACTION_PREFIX + str(i), "slot": slot})
		_skill_slot_cache[data.skill_name] = arr
	for i in range(grid2.get_child_count()):
		var slot2 = grid2.get_child(i).get_node("Slot")
		if slot2.texture == null:
			continue
		var data2 = getSkillData(slot2)
		if data2 == null:
			continue
		var arr2 = _skill_slot_cache.get(data2.skill_name, [])
		arr2.append({"action": ACTION_PREFIX2 + str(i), "slot": slot2})
		_skill_slot_cache[data2.skill_name] = arr2
	_skill_slot_cache_dirty = false

func getSkillSlotEntries(skill_name:String) -> Array:
	if _skill_slot_cache_dirty:
		rebuildSkillSlotCache()
	return _skill_slot_cache.get(skill_name, [])

func isSkillHeld(skill_name:String) -> bool:
	for entry in getSkillSlotEntries(skill_name):
		if Input.is_action_pressed(entry.action):
			return true
	return false

func handleObliterationCharge() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if player.cursor_visible:
		return

	var skill_name := "obliteration charge"
	if !player.anim_locks.get(skill_name, false):
		return

	var still_held:bool = isSkillHeld(skill_name)

	if !still_held:
		player.anim_locks[skill_name] = false
		if player.current_skill == skill_name:
			player.current_skill = ""

	chargeSkill(still_held, skill_name)
"""
AnimationCalls.combo_atk()->void stops the combo attack animation by setting continue_combo_atk to false.
While it is true, the combo attack animation continues playing. combo_atk splits the animation into multiple
phases, making it a click-stop-click-stop input. When combo_atk_mode_hold is true, it always functions
as hold-to-attack: release to stop, always.
This saves time, by allowing the use of only one animation for the "combo attack" instead of splitting it into 
multiple phases and having to blend them or needing to creat their own animation nodes in the AnimationBlendTree
Call this for press-to-attack; otherwise, the player needs to hold the combo attack
button to keep performing base attacks. There is a mode to switch between the two,
but for players who want press-to-attack instead of hold-to-attack, this is required.

Call this at the end of every hit in the combo attack animation, during the recovery frames.
"""
func holdInputs()->void:
	var visual_frame:int = Engine.get_frames_drawn()
	if visual_frame == _last_hold_inputs_frame:
		return
	_last_hold_inputs_frame = visual_frame

	if stats.health <= 0:
		continue_combo_atk=false
		combo_queue=0
		if player.anim_locks.get("obliteration charge",false) or player.anim_locks.get("obliteration",false):
			player.anim_locks["obliteration charge"]=false
			player.anim_locks["obliteration"]=false
			player.current_skill=""
			resetChargeSkillColor("obliteration")
			stats.charged_attack_stacks["obliteration"]["stacks"]=0
		return

	var guard_held:bool = isSkillHeld("guard")

	if guard_held and !player.anim_locks["guard"]:
		var blocked=false
		for lock_name in player.anim_locks:
			if lock_name!="guard" and player.anim_locks[lock_name]:
				blocked=true
				break

		if !blocked:
			player.anim_locks["guard"]=true
			player.current_skill="guard"

	for skill in hold_skills.keys():
		if player.anim_locks.has(skill) and player.anim_locks[skill]:
#__________________press to atk vs hold to atk for the base attack__________________________________
			if skill=="combo attack" and combo_atk_mode_hold==false:
				if player.anim_locks["flinch"] == false or player.anim_locks["knocked back"] == false or player.anim_locks["knocked down"] == false:
					player.is_in_combat=true

				if continue_combo_atk:
					continue
#___________________________________________________________________________________________________
			if skill=="guard":
				player.anim_locks["guard"]=true

			var still_held:bool = isSkillHeld(skill)

			if !still_held:
				player.anim_locks[skill]=false

				if player.current_skill==skill:
					player.current_skill=""

	if !player.anim_locks.get("combo attack",false):
		for entry in getSkillSlotEntries("combo attack"):
			if Input.is_action_pressed(entry.action):
				skills(entry.slot)
				return


var obl_color:=Color(1,1,1,1)
var obl_slots=[]
var obl_active:=false

var obl_current_color:=Color(1,1,1,1)
var obl_target_color:=Color(1,1,1,1)
var obl_skill_slots:=[]
var obl_is_active:=false


var chargeSkillColors={}

func updateChargeSkillColor(skill_name,max_stacks,color_points):
	if !Global.skills.has(skill_name):return

	if !chargeSkillColors.has(skill_name):
		chargeSkillColors[skill_name]={"color":Color.white,"slots":[]}
	var data=chargeSkillColors[skill_name]

	if data.slots.empty():
		for container in [grid,grid2]:
			for holder in container.get_children():
				var slot=holder.get_node("Slot")
				if slot.texture==Global.skills[skill_name]:
					data.slots.append(slot)

	var stacks=float(stats.charged_attack_stacks[skill_name]["stacks"])
	var percent=clamp(stacks/max_stacks,0.0,1.0)

	var point_count=color_points.size()-1
	var segment=percent*point_count
	var segment_index=int(floor(segment))
	var segment_alpha=segment-segment_index

	if segment_index>=point_count:
		segment_index=point_count-1
		segment_alpha=1.0

	var start_color=color_points[segment_index]
	var end_color=color_points[segment_index+1]

	data.color=start_color.linear_interpolate(end_color,segment_alpha)

	for slot in data.slots:
		if is_instance_valid(slot):
			slot.modulate=data.color

func chargeSkill(still_held_state,skill_name):
	if stats.health <= 0:
		player.anim_locks["obliteration charge"]=false
		player.anim_locks["obliteration"]=false
		if player.current_skill=="obliteration" or player.current_skill=="obliteration charge":
			player.current_skill=""
		resetChargeSkillColor("obliteration")
		stats.charged_attack_stacks["obliteration"]["stacks"]=0
		return
	player.is_in_combat = true
	player.equipment.instantWeaponCarryUpdate()
	if skill_name!="obliteration charge":return

	var skill_resource_path=Global.skills[skill_name].resource_path
	if active_cooldowns.has(skill_resource_path):return

	updateChargeSkillColor("obliteration",100.0,[Color.white,Color(0,0.6,1),Color(0.6,0,0.8),Color(1,0,0)])

	if !still_held_state:
		if chargeSkillColors.has("obliteration"):
			chargeSkillColors["obliteration"].color=Color.white

			for slot in chargeSkillColors["obliteration"].slots:
				if is_instance_valid(slot):
					slot.modulate=Color.white

		player.anim_locks["obliteration charge"]=false
		player.anim_locks["obliteration"]=true
		player.current_skill="obliteration"

		var cooldown_value=Global.getCooldown(skill_resource_path)
		cooldown_value/=max(0.01,player.stats.derived_stats["cooldown_reduction"])
		active_cooldowns[skill_resource_path]=cooldown_value
		Global.applyCooldownEffects(skill_name,active_cooldowns)
		refreshCooldownDisplaysNow()
		return

	player.current_skill="obliteration"

	var atk_speed=stats.derived_stats["attack_speed"]
	var interval=int(max(1,40.0/atk_speed))

	if Engine.get_physics_frames()%interval==0:
		var energy_cost_value=Global.getEnergyCost(skill_name)
		var max_health_value=stats.max_health

		if player.stats.energy>=energy_cost_value:
			player.stats.energy-=energy_cost_value
			stats.charged_attack_stacks["obliteration"]["stacks"]+=1
		elif player.stats.health>max_health_value*0.5:
			player.stats.health-=energy_cost_value
			stats.charged_attack_stacks["obliteration"]["stacks"]+=2
		else:
			player.stats.health-=energy_cost_value*2
			stats.charged_attack_stacks["obliteration"]["stacks"]+=5

		character_ui.updateBars()
		refreshCooldownDisplaysNow()


func getChargeSkillStacks(path):
	for skill_name in stats.charged_attack_stacks:
		if Global.skills.has(skill_name) and Global.skills[skill_name].resource_path == path:
			return int(stats.charged_attack_stacks[skill_name]["stacks"])
	return -1

func resetChargeSkillColor(skill_name):
	if !chargeSkillColors.has(skill_name):
		return

	chargeSkillColors[skill_name].color=Color.white

	for slot in chargeSkillColors[skill_name].slots:
		if is_instance_valid(slot):
			slot.modulate=Color.white




var skill_data = {
	"combo attack": {"path":"", "energy_cost":0, "slot":null}
}

func getSkillData(slot):
	if slot == null or slot.texture == null: 
		return null

	if _skill_texture_path_cache.empty():
		_buildSkillTextureCache()

	var path = slot.texture.resource_path
	var skill_name = _skill_texture_path_cache.get(path, "")

	if skill_name == "":
		return null

	return {
		"skill_name": skill_name,
		"path": path,
		"energy_cost": Global.getEnergyCost(skill_name),
		"slot": slot
	}

onready var slot_mainhand:TextureRect = $"../Equipment/MainHand/Slot"
func skills(slot)->void:

	if player.is_chatting == true:
		return 
	if stats.health <=0:
		return
	if player.anim_locks["flinch"] == true or player.anim_locks["knocked back"] == true or player.anim_locks["knocked down"] == true or player.anim_locks["guard react"] == true:
		return
	var data=getSkillData(slot)
	var skill_name
	if data != null:
		skill_name=data.skill_name

	var weapon_mode = player.weapons

	if skill_name == null:
		return

	if !player.skill_animations.has(skill_name):
		return
	var anims = player.skill_animations[skill_name]

	if anims.has(weapon_mode):
		pass
	elif anims.has(player.WeaponMode.NONE):
		weapon_mode = player.WeaponMode.NONE
	else:
		return
	if skill_name=="gather":player.is_in_combat = false
	if skill_name=="chop" or skill_name=="mine":
		var required= "chopping power" if skill_name=="chop" else "mining power"
		var has_tool=false

		for key in Global.weapons:
			var weapon=Global.weapons[key]
			if weapon.has(required):
				var icon=weapon["icon"]
				if typeof(icon)==TYPE_STRING:
					icon=load(icon)

				if slot_mainhand.texture==icon:
					has_tool=true
					break

				for child in inventory_grid.get_children():
					var slot_icon=child.get_node_or_null("Slot")
					if slot_icon and slot_icon.texture==icon:
						has_tool=true
						break

			if has_tool:
				break

		if !has_tool:
			return
		
	if skill_name == "guard":
		anim_calls.unlockAnim()
		player.anim_locks["guard"] = true
	if input_lock: return
	if data==null: return

	var path=data.path
	var energy_cost=data.energy_cost
	player.animation_tree.active = true
	var is_hold=hold_skills.has(skill_name)
	var is_combo=skill_name=="combo attack"
	if is_combo:
		for lock_name in player.anim_locks:
			if lock_name!="combo attack" and player.anim_locks[lock_name]:
				return
				
				
	var is_exempt=is_combo or skill_name=="guard" or skill_name=="parry"


	if player.anim_locks.get("stunned",false) or player.anim_locks.get("staggered",false):
		return

	var is_skill:=false
	for s in Global.skills:
		if Global.skills[s]==slot.texture:
			is_skill=true
			break

	if !is_hold and !is_exempt and active_cooldowns.has(path):
		return

	var unlocked = skill_name in ["combo attack","guard","evasion","parry","backstep","penetrating blow"]
	if !unlocked:
		var texture = Global.skills[skill_name]
		var roots := []

		var skill_tree_root = get_node_or_null("../SkillTreeRoot")
		if is_instance_valid(skill_tree_root):
			var basic_skills = skill_tree_root.get_node_or_null("BasicSkils")
			if is_instance_valid(basic_skills):
				roots.append(basic_skills)

			# Single unified skill tree now (was 16 per-class holders) --
			# expected path first, name-search fallback so a future rename
			# doesn't silently disable every skill unlock check.
			var buttons_container = skill_tree_root.get_node_or_null("SkillTree/Control/MoveThis")
			if !is_instance_valid(buttons_container):
				buttons_container = findNodeByNameRecursive(skill_tree_root,"MoveThis")
			if is_instance_valid(buttons_container):
				roots.append(buttons_container)

		for root in roots:
			if !is_instance_valid(root):
				continue
			var stack = [root]
			while stack.size() > 0 and !unlocked:
				var node = stack.pop_back()
				if !is_instance_valid(node):
					continue
				for child in node.get_children():
					stack.append(child)
					if child is TextureButton and child.has_node("Slot") and "skill_level" in child and child.skill_level > 0 and child.get_node("Slot").texture == texture:
						unlocked = true
						break
	if !unlocked:
		return


	if !is_hold:
		if player.anim_locks.get(skill_name,false): return

	if not skill_name in Global.chargeable_skills and energy_cost>0:
		if stats.energy<energy_cost: return

	var arcane_cost_check:float = Global.getArcaneCost(skill_name)
	if not skill_name in Global.chargeable_skills and arcane_cost_check>0:
		if stats.arcane<arcane_cost_check: return

	if is_combo:
		if player.anim_locks["flinch"] == false or player.anim_locks["knocked back"] == false or player.anim_locks["knocked down"] == false:
			if combo_atk_mode_hold: continue_combo_atk=true
			else: continue_combo_atk=true
		else:
			continue_combo_atk= false
			combo_queue = 0 

	player.current_skill = skill_name
	delayedSkill(skill_name,path,energy_cost,slot)
	
	if skill_name == "aegis" and !_warming_up_skills:
		inventory.switchDefensiveStanceWeapons()


func findNodeByNameRecursive(node:Node, target_name:String) -> Node:
	for child in node.get_children():
		if child.name == target_name:
			return child
		var found = findNodeByNameRecursive(child,target_name)
		if is_instance_valid(found):
			return found
	return null
	
var skill_delay_busy:=false
func delayedSkill(skill_name,path,energy_cost,slot):
	if player.current_skill!="" and player.current_skill!="none":
		var l:=false
		for k in player.anim_locks:
			if player.anim_locks[k]:l=true;break
		if l:yield(get_tree().create_timer(0.15),"timeout")
	applySkill(skill_name,path,energy_cost,slot)
	
	
func applySkill(skill_name,path,energy_cost,slot):
	if active_cooldowns.has(path) and skill_name!="combo attack":return
	if player.current_skill=="obliteration" or player.current_skill=="obliteration charge":
		resetChargeSkillColor("obliteration")
	if skill_name!="combo attack":
		player.unlockAnim()
		anim_calls.unlockAnim()

	player.flip_blend_timer=0.0
	player.dodge_cleanup_timer=0.0
	player.dodge_cleanup_reset=false
	player.anim_locks[skill_name]=true
	player.is_in_combat=true
	player.equipment.instantWeaponCarryUpdate()
	player.current_skill=skill_name

	applyCooldownAndCost(skill_name,path,energy_cost)
	tweenSkillIcons(skill_name,slot)



func applyCooldownAndCost(skill_name,path,energy_cost)->void:
	if player == null:
		return
	var cooldown = Global.getCooldown(path)
	var stats = $"../../Stats"
	cooldown /= max(0.01, stats.derived_stats["cooldown_reduction"])

	if skill_name!="obliteration charge" and !hold_skills.has(skill_name):
		active_cooldowns[path]=cooldown
		Global.applyCooldownEffects(skill_name,active_cooldowns)
		refreshCooldownDisplaysNow()

		if energy_cost > 0:
			stats.energy -= energy_cost
			character_ui.updateBars()

		var arcane_cost:float = Global.getArcaneCost(skill_name)
		if arcane_cost > 0:
			stats.arcane -= arcane_cost
			character_ui.updateBars()


func reimburseSkill(skill_name:String)->void:
	if !Global.skills.has(skill_name):
		return

	var texture=Global.skills[skill_name]
	var path=texture.resource_path

	var energy_cost=Global.getEnergyCost(skill_name)

	if energy_cost>0:
		player.stats.energy+=energy_cost
		character_ui.updateBars()

	if active_cooldowns.has(path):
		active_cooldowns.erase(path)
		refreshCooldownDisplaysNow()

func castSkill(skill_name:String)->void:
	var weapon_mode=player.weapons
	var anims=player.skill_animations[skill_name]

	if !anims.has(weapon_mode):
		weapon_mode=player.WeaponMode.NONE

	var path=Global.skills[skill_name].resource_path
	var energy_cost=Global.getEnergyCost(skill_name)
	var arcane_cost=Global.getArcaneCost(skill_name)

	if energy_cost>0 and stats.energy<energy_cost:
		return
	if arcane_cost>0 and stats.arcane<arcane_cost:
		return

	player.animation_tree.active=true
	player.current_skill=skill_name
	player.anim_locks[skill_name]=true
	player.is_in_combat=true

	var cooldown=Global.getCooldown(path)
	cooldown/=max(0.01,stats.derived_stats["cooldown_reduction"])

	active_cooldowns[path]=cooldown
	Global.applyCooldownEffects(skill_name,active_cooldowns)
	refreshCooldownDisplaysNow()

	if energy_cost>0:
		stats.energy-=energy_cost
		character_ui.updateBars()

	if arcane_cost>0:
		stats.arcane-=arcane_cost
		character_ui.updateBars()




func tweenSkillIcons(skill_name,slot)->void:
	if !no_press_tween_skills.has(skill_name):
		tween.stop_all()
		tween.interpolate_property(slot, "rect_scale",Vector2.ONE, Vector2(0.9, 0.9),0.08, Tween.TRANS_QUAD, Tween.EASE_OUT)
		tween.interpolate_property(slot, "rect_scale",Vector2(0.9, 0.9), Vector2.ONE,0.08, Tween.TRANS_QUAD, Tween.EASE_IN, 0.08)
		tween.start()


func useItem(slot)->bool:
	if stats.health<=0:return false
	if slot==null or slot.texture==null:return false

	for resource_name in Global.resources:
		var resource=Global.resources[resource_name]
		if resource_name=="crafting book" and Global.sameIcon(resource["icon"],slot.texture):
			tween.stop_all()
			tween.interpolate_property(slot,"rect_scale",Vector2.ONE,Vector2(0.9,0.9),0.08,Tween.TRANS_QUAD,Tween.EASE_OUT)
			tween.interpolate_property(slot,"rect_scale",Vector2(0.9,0.9),Vector2.ONE,0.08,Tween.TRANS_QUAD,Tween.EASE_IN,0.08)
			tween.start()

			var recipes_book:Control=$"../Crafting/RecipeeBook"
			recipes_book.visible=!recipes_book.visible
			inventory.visible=recipes_book.visible
			player.crafting.visible=recipes_book.visible
			return true


	var holder=slot.get_parent()
	var button=holder.get_node("TextureButton")
	var path=slot.texture.resource_path

	if !Global.cooldowns.has(path):return false
	if active_cooldowns.has(path):return true

	tween.stop_all()
	tween.interpolate_property(slot,"rect_scale",Vector2.ONE,Vector2(0.9,0.9),0.08,Tween.TRANS_QUAD,Tween.EASE_OUT)
	tween.interpolate_property(slot,"rect_scale",Vector2(0.9,0.9),Vector2.ONE,0.08,Tween.TRANS_QUAD,Tween.EASE_IN,0.08)

	if button.quantity<=0:
		tween.interpolate_property(slot,"modulate",Color.white,Color(1,0,0),0.08,Tween.TRANS_QUAD,Tween.EASE_OUT)
		tween.interpolate_property(slot,"modulate",Color(1,0,0),Color.white,0.15,Tween.TRANS_QUAD,Tween.EASE_IN,0.08)
		tween.start()
		return true

	tween.interpolate_property(slot,"modulate",Color.white,Color(0,1,0),0.08,Tween.TRANS_QUAD,Tween.EASE_OUT)
	tween.interpolate_property(slot,"modulate",Color(0,1,0),Color.white,0.15,Tween.TRANS_QUAD,Tween.EASE_IN,0.08)
	tween.start()

	if Global.useItem(button,inventory_grid,stats):
		var cooldown=Global.getCooldown(path)
		if cooldown>0.0:
			active_cooldowns[path]=cooldown

		button.quantity-=1

		if button.quantity<=0:
			button.quantity=0
			slot.texture=null
			button.item="null"

	return true
	
var _skill_texture_path_cache := {} # resource_path -> skill_name, built once and reused

func _buildSkillTextureCache() -> void:
	_skill_texture_path_cache.clear()
	for s in Global.skills:
		var tex = Global.skills[s]
		if tex != null and !_skill_texture_path_cache.has(tex.resource_path):
			_skill_texture_path_cache[tex.resource_path] = s
func updateSkillAvailabilityVisuals():
	if _skill_texture_path_cache.empty():
		_buildSkillTextureCache()

	var weapon_mode=player.weapons
	for container in [grid,grid2]:
		for holder in container.get_children():
			var icon=holder.get_node("Slot")
			if !icon.texture:
				continue

			var skill_name = _skill_texture_path_cache.get(icon.texture.resource_path, "")

			if skill_name=="":
				icon.modulate=Color(1,1,1,1)
				continue

			# FIX (charge color flicker): a chargeable skill currently held
			# owns its own icon tint via updateChargeSkillColor(), called
			# every physics tick from chargeSkill(). This pass used to
			# unconditionally overwrite that back to white/grey every 6
			# physics frames -- that's what produced the visible flicker.
			# Skip tinting entirely while the skill is actively charging;
			# chargeSkill() already restores modulate to white itself the
			# instant the charge is released, so nothing is left stale.
			if Global.chargeable_skills.has(skill_name) and player.anim_locks.get(skill_name, false):
				continue

			if !player.skill_animations.has(skill_name):
				icon.modulate=Color(1,1,1,1)
				continue

			var anims=player.skill_animations[skill_name]

			if anims.has(weapon_mode):
				icon.modulate=Color(1,1,1,1)
				continue

			if anims.has(player.WeaponMode.NONE):
				icon.modulate=Color(1,1,1,1)
				continue

			icon.modulate=Color(0.4,0.4,0.4,1)
			
func refreshCooldownDisplaysNow() -> void:
	updateCooldownGroup(_cd_cache)
	updateCooldownGroup(_cd_cache2)
	if is_instance_valid(inventory) and inventory.visible:
		updateCooldownGroup(_inv_cd_cache)
func updateCooldowns():
	for key in active_cooldowns.keys():
		active_cooldowns[key]=max(active_cooldowns[key]-1,0.0)

	inventory.inventoryCooldowns()
	updateCooldownGroup(_cd_cache)
	updateCooldownGroup(_cd_cache2)

	if inventory.visible:
		updateCooldownGroup(_inv_cd_cache)


func updateCooldownGroup(cache:Array) -> void:
	for entry in cache:
		var icon = entry["icon"]
		var label = entry["label"]

		if !is_instance_valid(icon) or !is_instance_valid(label):
			continue

		if !icon.texture:
			if entry["last"] != "":
				entry["last"] = ""
				label.text = ""
			continue

		var key = icon.texture.resource_path
		var stacks = getChargeSkillStacks(key)
		var new_text := ""

		if stacks > 0 and player.current_skill == "obliteration":
			new_text = str(stacks)
		else:
			var has_cd = Global.cooldowns.has(key) and Global.cooldowns[key] > 0.0
			if has_cd and active_cooldowns.has(key):
				var t = active_cooldowns[key]
				if t <= 0.0:
					active_cooldowns.erase(key)
				else:
					new_text = str(int(ceil(t)))

		if new_text != entry["last"]:
			entry["last"] = new_text
			label.text = new_text
			
func rebuildCooldownCache() -> void:
	_cd_cache.clear()
	for holder in grid.get_children():
		_cd_cache.append({"icon": holder.get_node("Slot"), "label": holder.get_node("CD"), "last": " "})
	_cd_cache2.clear()
	for holder in grid2.get_children():
		_cd_cache2.append({"icon": holder.get_node("Slot"), "label": holder.get_node("CD"), "last": " "})
	_inv_cd_cache.clear()
	for holder in inventory_grid.get_children():
		_inv_cd_cache.append({"icon": holder.get_node("Slot"), "label": holder.get_node("CD"), "last": " "})




func matchInputSlot()->void:
	for i in range(grid.get_child_count()):
		var a=ACTION_PREFIX+str(i)
		if Input.is_action_just_pressed(a):
			var slot=grid.get_child(i).get_node("Slot")
			if slot.texture == Global.skills["combo attack"] and !combo_atk_mode_hold:
				if continue_combo_atk == true:
					player.is_in_combat=true
					combo_queue = min(combo_queue + 1, COMBO_QUEUE_MAX)
			skills(slot)
			useItem(slot)
			return

	for i in range(grid2.get_child_count()):
		var a=ACTION_PREFIX2+str(i)
		if Input.is_action_just_pressed(a):
			var slot=grid2.get_child(i).get_node("Slot")
			if slot.texture == Global.skills["combo attack"] and !combo_atk_mode_hold:
				if continue_combo_atk == true:
					player.is_in_combat=true
					combo_queue = min(combo_queue + 1, COMBO_QUEUE_MAX)
			skills(slot)
			useItem(slot)
			return


func slotPressed(holder)->void:
	if !edit:
		return

	capture_holder=holder
	capture_slot=holder.get_node("Slot")
	holder.get_node("Key").text="..."

func _input(event)->void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if capture_slot==null:
		return
	if event is InputEventKey and event.pressed:
		assignKey(event)
	elif event is InputEventMouseButton and event.pressed:
		assignMouseButton(event)




var capture_holder=null
func assignMouseButton(event)->void:
	var index=getMouseSlotIndex(capture_slot)
	if index==-1:
		return
	var action_name=ACTION_PREFIX2+str(index)
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	var e=InputEventMouseButton.new()
	e.button_index=event.button_index
	InputMap.action_add_event(action_name,e)
	match event.button_index:
		BUTTON_LEFT:
			capture_holder.get_node("Key").text="LM"
		BUTTON_RIGHT:
			capture_holder.get_node("Key").text="RM"
		BUTTON_MIDDLE:
			capture_holder.get_node("Key").text="MM"
		_:
			capture_holder.get_node("Key").text="M"+str(event.button_index)
	saveKeybinds()
	capture_slot=null
	capture_holder=null



func assignKey(event)->void:
	var index=getSlotIndex(capture_slot)
	var action_name=ACTION_PREFIX+str(index)
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	var normal_event=InputEventKey.new()
	normal_event.scancode=event.scancode
	InputMap.action_add_event(action_name,normal_event)
	var shift_event=InputEventKey.new()
	shift_event.scancode=event.scancode
	shift_event.shift=true
	InputMap.action_add_event(action_name,shift_event)
	capture_holder.get_node("Key").text=OS.get_scancode_string(event.scancode).to_upper()
	saveKeybinds()
	capture_slot=null
	capture_holder=null
	
func getMouseSlotIndex(slot)->int:
	for i in range(grid2.get_child_count()):
		if grid2.get_child(i).get_node("Slot")==slot:
			return i
	return -1

func getScancode(key_text:String)->int:
	match key_text.to_upper():
		"F1":
			return KEY_F1
		"F2":
			return KEY_F2
		"F3":
			return KEY_F3
		"F4":
			return KEY_F4
		"F5":
			return KEY_F5
		"F6":
			return KEY_F6
		"F7":
			return KEY_F7
		"F8":
			return KEY_F8
		"F9":
			return KEY_F9
		"F10":
			return KEY_F10
		_:
			return OS.find_scancode_from_string(key_text)

func saveKeybinds()->void:
	var config=ConfigFile.new()
	for i in range(grid.get_child_count()):
		var action_name=ACTION_PREFIX+str(i)
		var events=InputMap.get_action_list(action_name)
		var scancode=-1
		for e in events:
			if e is InputEventKey:
				scancode=e.scancode
				break
		config.set_value("Keys","slot_"+str(i),scancode)
	for i in range(grid2.get_child_count()):
		var action_name=ACTION_PREFIX2+str(i)
		var events=InputMap.get_action_list(action_name)
		var button=-1
		for e in events:
			if e is InputEventMouseButton:
				button=e.button_index
				break
		config.set_value("MouseKeys","slot_"+str(i),button)
	config.set_value("UI","expand_state",expand_state)
	config.set_value("UI","combo_atk_mode_hold",combo_atk_mode_hold)
	config.save(CONFIG_FILE_PATH)


func loadKeybinds()->void:
	var config = ConfigFile.new()
	var has_keybinds = config.load(CONFIG_FILE_PATH) == OK

	createDefaultSlots()
	createDefaultMouseSlots()

	# --------------------------------------------------
	# CHECK IF THIS CHARACTER ALREADY HAS A REAL SAVE
	# (check for an actual save FILE, not just the folder --
	# queueFileWrite() creates the folder synchronously the moment
	# a save is queued, even before the write itself lands, so an
	# empty leftover folder must never count as "has a save".)
	# --------------------------------------------------
	var has_character_save := false

	if player.entity_name != "" and is_instance_valid(player.get_parent()) and player.get_parent().has_method("getPlayerSaveBaseDir"):
		var save_dir = player.get_parent().getPlayerSaveBaseDir() + player.entity_name + "/"
		var check_file = File.new()
		if check_file.file_exists(save_dir + "skillbar.save") or check_file.file_exists(save_dir + "inventory.save"):
			has_character_save = true

	# --------------------------------------------------
	# DEFAULT MOUSE SKILLS ONLY FOR BRAND-NEW CHARACTERS
	# --------------------------------------------------
	if !has_character_save:
		var left_slot = grid2.get_node("ButtonHolder0").get_node("Slot")
		var right_slot = grid2.get_node("ButtonHolder1").get_node("Slot")

		if left_slot.texture == null and Global.skills.has("combo attack"):
			left_slot.texture = Global.skills["combo attack"]

		if right_slot.texture == null and Global.skills.has("guard"):
			right_slot.texture = Global.skills["guard"]
		if grid.has_node("ButtonHolder17"):
			var c_slot = grid.get_node("ButtonHolder17").get_node("Slot")
			if c_slot.texture == null and Global.skills.has("evasion"):
				c_slot.texture = Global.skills["evasion"]

		if grid.has_node("ButtonHolder19"):
			var b_slot = grid.get_node("ButtonHolder19").get_node("Slot")
			if b_slot.texture == null and Global.skills.has("backstep"):
				b_slot.texture = Global.skills["backstep"]
	if has_keybinds:
		expand_state = config.get_value("UI", "expand_state", 0)
		combo_atk_mode_hold = config.get_value("UI", "combo_atk_mode_hold", false)

	# --------------------------------------------------
	# KEYBOARD SLOTS
	# --------------------------------------------------
	for i in range(grid.get_child_count()):
		var holder = grid.get_child(i)
		var key = holder.get_node("Key")
		var action_name = ACTION_PREFIX + str(i)

		if !InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		InputMap.action_erase_events(action_name)

		var scancode = -1

		if has_keybinds:
			scancode = config.get_value("Keys", "slot_" + str(i), -1)

		if scancode == -1:
			scancode = getScancode(key.text)

		if scancode > 0:
			var e = InputEventKey.new()
			e.scancode = scancode
			InputMap.action_add_event(action_name, e)

			var s = InputEventKey.new()
			s.scancode = scancode
			s.shift = true
			InputMap.action_add_event(action_name, s)

			key.text = OS.get_scancode_string(scancode).to_upper()

	# --------------------------------------------------
	# MOUSE SLOTS
	# --------------------------------------------------
	for i in range(grid2.get_child_count()):
		var holder = grid2.get_child(i)
		var key = holder.get_node("Key")
		var action_name = ACTION_PREFIX2 + str(i)

		if !InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		InputMap.action_erase_events(action_name)

		var button_index = -1

		if has_keybinds:
			button_index = config.get_value("MouseKeys", "slot_" + str(i), -1)

		if button_index == -1:
			button_index = BUTTON_LEFT if i == 0 else BUTTON_RIGHT

		var e = InputEventMouseButton.new()
		e.button_index = button_index
		InputMap.action_add_event(action_name, e)

		match button_index:
			BUTTON_LEFT:
				key.text = "LM"
			BUTTON_RIGHT:
				key.text = "RM"
			BUTTON_MIDDLE:
				key.text = "MM"
			_:
				key.text = "M" + str(button_index)

	applyExpandState()
	markSkillSlotCacheDirty()
	if !has_keybinds:
		saveKeybinds()
	rebuildCooldownCache()


func getSlotIndex(slot)->int:
	for i in range(grid.get_child_count()):
		var holder=grid.get_child(i)
		if holder.get_node("Slot")==slot:
			return i
	return -1



func _on_Button_pressed()->void:
	edit = !edit


func _on_ComboModeButton_pressed():
	combo_atk_mode_hold = !combo_atk_mode_hold

func createDefaultMouseSlots()->void:
	var keys=["LM","RM"]
	var base=grid2.get_node("ButtonHolder0")

	for i in range(1,2):
		if grid2.has_node("ButtonHolder"+str(i)):
			continue

		var b=base.duplicate()
		b.name="ButtonHolder"+str(i)
		grid2.add_child(b)
		b.owner=self

		for c in b.get_children():
			if c is TextureButton:
				c.connect("pressed",self,"slotPressed",[b])
				break

	for i in range(2):
		var b=grid2.get_node("ButtonHolder"+str(i))

		b.get_node("Key").text=keys[i]

		if !InputMap.has_action(ACTION_PREFIX2+str(i)):
			InputMap.add_action(ACTION_PREFIX2+str(i))

		InputMap.action_erase_events(ACTION_PREFIX2+str(i))

		var e=InputEventMouseButton.new()
		e.button_index=BUTTON_LEFT if i==0 else BUTTON_RIGHT
		InputMap.action_add_event(ACTION_PREFIX2+str(i),e)


func createDefaultSlots()->void:
	var keys=["F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","Q","E","R","T","F","G","Y","C","V","B","1","2","3","4","5","6","7","8","9","0"]
	var base=grid.get_node("ButtonHolder0")

	for i in range(1,30):
		if grid.has_node("ButtonHolder"+str(i)):
			continue

		var b=base.duplicate()
		b.name="ButtonHolder"+str(i)
		grid.add_child(b)
		b.owner=self

		for c in b.get_children():
			if c is TextureButton:
				c.connect("pressed",self,"slotPressed",[b])
				break

	for i in range(30):
		grid.get_node("ButtonHolder"+str(i)).get_node("Key").text=keys[i]




func setSlotVisible(holder,state:bool)->void:
	holder.modulate.a=1.0 if state else 0.0
	holder.mouse_filter=Control.MOUSE_FILTER_STOP if state else Control.MOUSE_FILTER_IGNORE
	
func expandCollapse()->void:
	expand_state += 1
	if expand_state > 2:
		expand_state = 0
	applyExpandState()
	saveKeybinds()
func connectButtons()->void:
	for slotHolder in grid.get_children():
		for slotButton in slotHolder.get_children():
			if slotButton is TextureButton and !slotButton.is_connected("pressed",self,"slotPressed"):
				slotButton.connect("pressed",self,"slotPressed",[slotHolder])
				break

	for slotHolder in grid2.get_children():
		for slotButton in slotHolder.get_children():
			if slotButton is TextureButton and !slotButton.is_connected("pressed",self,"slotPressed"):
				slotButton.connect("pressed",self,"slotPressed",[slotHolder])
				break

	if !expand_button.is_connected("pressed",self,"expandCollapse"):
		expand_button.connect("pressed",self,"expandCollapse")
	
func applyExpandState()->void:
	for i in range(20):
		if grid.has_node("ButtonHolder" + str(i)):
			setSlotVisible(grid.get_node("ButtonHolder" + str(i)), true)
	match expand_state:
		1:
			for i in range(10):
				if grid.has_node("ButtonHolder" + str(i)):
					setSlotVisible(grid.get_node("ButtonHolder" + str(i)), false)
		2:
			for i in range(20):
				if grid.has_node("ButtonHolder" + str(i)):
					setSlotVisible(grid.get_node("ButtonHolder" + str(i)), false)

func reinitializeAsLocalPlayer() -> void:
	set_physics_process(true)
	set_process_input(true)
	set_process(true)
	loadKeybinds()
	connectButtons()
	resetSkillRuntime()
	call_deferred("initializeSkillsToPreventAstupidFuckingBugIDontKnowHowToFix")

func hardResetForPool() -> void:
	active_cooldowns.clear()
	for i in range(grid.get_child_count()):
		var slot = grid.get_child(i).get_node_or_null("Slot")
		if is_instance_valid(slot):
			slot.texture = null
	for i in range(grid2.get_child_count()):
		var slot = grid2.get_child(i).get_node_or_null("Slot")
		if is_instance_valid(slot):
			slot.texture = null

func fixSlotMouseFilters() -> void:
	for container in [grid, grid2]:
		for holder in container.get_children():
			var slot = holder.get_node_or_null("Slot")
			if slot:
				slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

