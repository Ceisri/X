extends Control

onready var player = $"../.."
onready var character_ui =  $"../Menu/CharacterBar"
onready var animationcalls = $"../../AnimationCalls"
onready var anim_calls = $"../../AnimationCalls"
onready var grid =  $GridContainer
onready var grid2 = $GridContainer2 
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

var no_press_tween_skills=["combo attack","parry","guard"]
var hold_skills={
	"parry":true,
	"guard":true,
	"combo attack":true,
	"obliteration charge":true,
}

const CONFIG_FILE_PATH = "user://skillbar_keybinds.cfg"
const ACTION_PREFIX = "skill_slot_"
const ACTION_PREFIX2="mouse_slot_"




func _ready():
	loadCooldowns()
	loadKeybinds()
	connectButtons()
	resetSkillRuntime()



func resetSkillRuntime():
	active_cooldowns.clear()
	continue_combo_atk = true
	input_lock = false
	input_lock_time = 0.0
	player.current_skill = ""
	for k in player.anim_locks.keys():
		player.anim_locks[k] = false




var input_lock_time := 0.0
var input_lock := false
func _physics_process(delta):
	updateCooldowns(delta)

	input_lock_time -= delta
	if input_lock_time <= 0:
		input_lock = false
	if player.cursor_visible == false:
		matchInputSlot()
		holdInputs()


var combo_atk_mode_hold:bool = false
var continue_combo_atk:bool = true 
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
	for skill in hold_skills.keys():
		if player.anim_locks.has(skill) and player.anim_locks[skill]:
#__________________press to atk vs hold to atk for the base attack__________________________________
			if skill=="combo attack" and combo_atk_mode_hold==false:
				if continue_combo_atk:
					continue
#___________________________________________________________________________________________________
			var still_held:bool=false

			for i in range(grid.get_child_count()):
				var holder=grid.get_child(i)
				var slot=holder.get_node("Slot")

				if slot.texture and Skills.skills.has(skill):
					if slot.texture==Skills.skills[skill]:
						var action_name=ACTION_PREFIX+str(i)

						if Input.is_action_pressed(action_name):
							still_held=true

						break

			if !still_held:
				for i in range(grid2.get_child_count()):
					var holder=grid2.get_child(i)
					var slot=holder.get_node("Slot")

					if slot.texture and Skills.skills.has(skill):
						if slot.texture==Skills.skills[skill]:
							var action_name=ACTION_PREFIX2+str(i)

							if Input.is_action_pressed(action_name):
								still_held=true

							break

			if !still_held:
				player.anim_locks[skill]=false

				if player.current_skill==skill:
					player.current_skill=""

			chargeSkill(still_held,skill)

func chargeSkill(still_held,skill):
	if still_held:
		if skill == "obliteration charge":
			player.current_skill = "obliteration"

			if Engine.get_physics_frames() % 40 == 0:
				var energy_cost = Skills.getEnergyCost("obliteration charge")
				var max_health = stats.max_health 

				if player.stats.energy >= energy_cost:
					player.stats.energy -= energy_cost
					stats.charged_attack_stacks["obliteration"]["stacks"] += 1
				elif player.stats.health > max_health * 0.5:
					player.stats.health -= energy_cost
					stats.charged_attack_stacks["obliteration"]["stacks"] += 2
				else:
					player.stats.health -= energy_cost * 2
					stats.charged_attack_stacks["obliteration"]["stacks"] += 5

				character_ui.updateBars()

	if !still_held:
		if skill == "obliteration charge":
			player.anim_locks["obliteration charge"] = false
			player.anim_locks["obliteration"] = true
			player.current_skill = "obliteration"

			var texture = Skills.skills["obliteration charge"]
			var path = texture.resource_path
			var cooldown = Skills.getCooldown(path)
			cooldown /= max(0.01, player.stats.derived_stats["cooldown_reduction"])

			active_cooldowns[path] = cooldown
			Skills.applyCooldownEffects("obliteration charge", active_cooldowns)


var skill_data = {
	"combo attack": {"path":"", "energy_cost":0, "slot":null}
}

func getSkillData(slot):
	if slot == null or slot.texture == null:
		return null

	var path = slot.texture.resource_path
	var skill_name = ""

	for s in Skills.skills:
		if Skills.skills[s].resource_path == path:
			skill_name = s
			break

	if skill_name == "":
		return null

	return {
		"skill_name": skill_name,
		"path": path,
		"energy_cost": Skills.getEnergyCost(skill_name),
		"slot": slot
	}

func skills(slot)->void:
	if input_lock: return
	var data=getSkillData(slot)
	if data==null: return

	var skill_name=data.skill_name
	var path=data.path
	var energy_cost=data.energy_cost

	var is_hold=hold_skills.has(skill_name)
	var is_combo=skill_name=="combo attack"
	var is_exempt=is_combo or skill_name=="guard" or skill_name=="parry"

	player.is_in_combat=true
	player.combat_timer=10

	if player.anim_locks.get("stunned",false) or player.anim_locks.get("staggered",false):
		return

	var is_skill:=false
	for s in Skills.skills:
		if Skills.skills[s]==slot.texture:
			is_skill=true
			break

	useItemFromKeyboard(is_skill,slot,path)

	if !is_hold and !is_exempt and active_cooldowns.has(path):
		return

	var texture=Skills.skills[skill_name]

	var unlocked:=false
	var stack=[$"../SkillTreeRoot"]

	while stack.size()>0:
		var node=stack.pop_back()
		for child in node.get_children():
			stack.append(child)
			if !(child is TextureButton): continue
			if !child.has_node("Slot"): continue
			var has_skill_level:=false
			for prop in child.get_property_list():
				if prop.name=="skill_level":
					has_skill_level=true
					break
			if !has_skill_level: continue

			var slot_node=child.get_node("Slot")
			if slot_node.texture==texture and child.skill_level>0:
				unlocked=true
				break
		if unlocked: break

	if !unlocked: return

	if !is_hold:
		if player.anim_locks.get(skill_name,false): return

	if not skill_name in Skills.chargeable_skills and energy_cost>0:
		if player.stats.energy<energy_cost: return

	if is_combo:
		if combo_atk_mode_hold: continue_combo_atk=true
		else: continue_combo_atk=true

	delayedSkill(skill_name,path,energy_cost,slot)
	
	
var skill_delay_busy:=false
func delayedSkill(skill_name,path,energy_cost,slot):
	if player.current_skill!="" and player.current_skill!="none":
		var l:=false
		for k in player.anim_locks:
			if player.anim_locks[k]:l=true;break
		if l:yield(get_tree().create_timer(0.15),"timeout")
	applySkill(skill_name,path,energy_cost,slot)
	
	
func applySkill(skill_name,path,energy_cost,slot):
	if skill_name!="combo attack":
		player.unlockAnim()
		anim_calls.unlockAnim()
	player.flip_blend_timer = 0.0
	player.dodge_cleanup_timer = 0.0
	player.dodge_cleanup_reset = false
	player.anim_locks[skill_name] = true
	player.current_skill = skill_name
	player.combat_timer = 10
	applyCooldownAndCost(skill_name, path, energy_cost)
	tweenSkillIcons(skill_name, slot)




func applyCooldownAndCost(skill_name,path,energy_cost)->void:
	var cooldown = Skills.getCooldown(path)
	cooldown /= max(0.01, player.stats.derived_stats["cooldown_reduction"])

	if skill_name != "obliteration charge":
		active_cooldowns[path] = cooldown
		Skills.applyCooldownEffects(skill_name, active_cooldowns)

		if energy_cost > 0:
			player.stats.energy -= energy_cost
			character_ui.updateBars()
func reimburseSkill(skill_name:String)->void:
	if !Skills.skills.has(skill_name):
		return

	var texture=Skills.skills[skill_name]
	var path=texture.resource_path

	var energy_cost=Skills.getEnergyCost(skill_name)

	if energy_cost>0:
		player.stats.energy+=energy_cost
		character_ui.updateBars()

	if active_cooldowns.has(path):
		active_cooldowns.erase(path)


func useItemFromKeyboard(is_skill,slot,path)->void:
	if !is_skill:
		var holder = slot.get_parent()
		var button = holder.get_node("TextureButton")

		if active_cooldowns.has(path):
			return

		tween.stop_all()

		tween.interpolate_property(slot, "rect_scale",Vector2.ONE, Vector2(0.9, 0.9),0.08, Tween.TRANS_QUAD, Tween.EASE_OUT)

		tween.interpolate_property(slot, "rect_scale",Vector2(0.9, 0.9), Vector2.ONE,0.08, Tween.TRANS_QUAD, Tween.EASE_IN, 0.08)

		if button.quantity <= 0:
			tween.interpolate_property(slot, "modulate",Color.white, Color(1, 0, 0),0.08, Tween.TRANS_QUAD, Tween.EASE_OUT)

			tween.interpolate_property(slot, "modulate",Color(1, 0, 0), Color.white,0.15, Tween.TRANS_QUAD, Tween.EASE_IN, 0.08)

			tween.start()
			return

		tween.interpolate_property(slot, "modulate",Color.white, Color(0, 1, 0),0.08, Tween.TRANS_QUAD, Tween.EASE_OUT)

		tween.interpolate_property(slot, "modulate",Color(0, 1, 0), Color.white,0.15, Tween.TRANS_QUAD, Tween.EASE_IN, 0.08)

		tween.start()

		if CommonBehaviours.useItem(button, inventory_grid, stats):
			var cooldown = Items.getCooldown(path)

			if cooldown > 0.0:
				active_cooldowns[path] = cooldown

			button.quantity -= 1

			if button.quantity <= 0:
				button.quantity = 0
				slot.texture = null
				button.item = "null"
func tweenSkillIcons(skill_name,slot)->void:
	if !no_press_tween_skills.has(skill_name):
		tween.stop_all()
		tween.interpolate_property(slot, "rect_scale",Vector2.ONE, Vector2(0.9, 0.9),0.08, Tween.TRANS_QUAD, Tween.EASE_OUT)
		tween.interpolate_property(slot, "rect_scale",Vector2(0.9, 0.9), Vector2.ONE,0.08, Tween.TRANS_QUAD, Tween.EASE_IN, 0.08)
		tween.start()

func resetTween(slot)->void:
	if slot.texture == null:
		return

	var path = slot.texture.resource_path

	# no cooldown defined or explicitly zero -> ignore
	if !Skills.cooldowns.has(path):
		return
	if Skills.cooldowns[path] <= 0.0:
		return

	var t:Tween = tween2
	t.stop_all()
	slot.modulate = Color.white

	t.interpolate_property(slot,"modulate",Color.white,Color(0.5,0.8,1.4,1),0.12,Tween.TRANS_QUAD,Tween.EASE_OUT)
	t.interpolate_property(slot,"modulate",Color(0.5,0.8,1.4,1),Color.white,0.20,Tween.TRANS_QUAD,Tween.EASE_IN,0.12)

	t.start()


func updateCooldowns(delta):# I suspect this funciton is called twice somewhere and I can't find where, momentary solution, divide delta by 2 
	for key in active_cooldowns.keys():
		active_cooldowns[key]=max(active_cooldowns[key]-delta *0.5 ,0.0)

	inventory.inventoryCooldowns(delta)

	for container in [grid,grid2]:
		for holder in container.get_children():
			var icon=holder.get_node("Slot")
			var label=holder.get_node("CD")

			if !icon.texture:
				label.text=""
				continue

			var key=icon.texture.resource_path
			var has_skill_cd=Skills.cooldowns.has(key) and Skills.cooldowns[key]>0.0

			if !has_skill_cd:
				label.text=""
				continue

			if !active_cooldowns.has(key):
				label.text=""
				continue

			var t=active_cooldowns[key]
			label.text=str(int(ceil(max(t,0))))
			if t<=0:
				active_cooldowns.erase(key)

	for holder in inventory_grid.get_children():
		var icon=holder.get_node("Slot")
		var label=holder.get_node("CD")

		if !icon.texture:
			label.text=""
			continue

		var key=icon.texture.resource_path
		if !active_cooldowns.has(key):
			label.text=""
			continue

		var t=active_cooldowns[key]
		label.text=str(int(ceil(max(t,0))))
		if t<=0:
			active_cooldowns.erase(key)
			

func matchInputSlot()->void:
	for i in range(grid.get_child_count()):
		var a=ACTION_PREFIX+str(i)
		if Input.is_action_just_pressed(a):
			var slot=grid.get_child(i).get_node("Slot")
			if slot.texture==Skills.skills["combo attack"] and !combo_atk_mode_hold: continue_combo_atk=true
			skills(slot)
			return

	for i in range(grid2.get_child_count()):
		var a=ACTION_PREFIX2+str(i)
		if Input.is_action_just_pressed(a):
			var slot=grid2.get_child(i).get_node("Slot")
			if slot.texture==Skills.skills["combo attack"] and !combo_atk_mode_hold: continue_combo_atk=true
			skills(slot)
			return


func slotPressed(holder)->void:
	if !edit:
		return

	capture_holder=holder
	capture_slot=holder.get_node("Slot")
	holder.get_node("Key").text="..."

func _input(event)->void:
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
	# CHECK IF THIS CHARACTER ALREADY HAS A SAVE
	# --------------------------------------------------
	var has_character_save := false

	if player.save_id != "":
		var dir = Directory.new()
		var save_dir = "user://save/" + player.save_id

		if dir.dir_exists(save_dir):
			has_character_save = true

	# --------------------------------------------------
	# DEFAULT MOUSE SKILLS ONLY FOR BRAND-NEW CHARACTERS
	# --------------------------------------------------
	if !has_character_save:
		var left_slot = grid2.get_node("ButtonHolder0").get_node("Slot")
		var right_slot = grid2.get_node("ButtonHolder1").get_node("Slot")

		if left_slot.texture == null and Skills.skills.has("combo attack"):
			left_slot.texture = Skills.skills["combo attack"]

		if right_slot.texture == null and Skills.skills.has("guard"):
			right_slot.texture = Skills.skills["guard"]

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

	if !has_keybinds:
		saveKeybinds()

func getSlotIndex(slot)->int:
	for i in range(grid.get_child_count()):
		var holder=grid.get_child(i)
		if holder.get_node("Slot")==slot:
			return i
	return -1
func saveData()->void:
	var savePath = "user://save/" + player.save_id + "/skill_cooldowns.save"
	var dir = Directory.new()
	if !dir.dir_exists("user://save"):
		dir.make_dir("user://save")
	if !dir.dir_exists("user://save/" + player.save_id):
		dir.make_dir("user://save/" + player.save_id)
	var file = File.new()
	if file.open(savePath,File.WRITE) == OK:
		file.store_var(active_cooldowns)
		file.close()
func loadCooldowns()->void:
	var savePath = "user://save/" + player.save_id + "/skill_cooldowns.save"
	var file = File.new()
	if file.file_exists(savePath):
		if file.open(savePath,File.READ) == OK:
			var data = file.get_var()
			if data is Dictionary:
				active_cooldowns = data
			file.close()
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
	for holder in grid.get_children():
		for c in holder.get_children():
			if c is TextureButton:
				c.connect("pressed",self,"slotPressed",[holder])
				break

	for holder in grid2.get_children():
		for c in holder.get_children():
			if c is TextureButton:
				c.connect("pressed",self,"slotPressed",[holder])
				break

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

