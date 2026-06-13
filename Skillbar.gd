extends Control

onready var player = $"../.."
onready var character_ui =  $"../Menu/CharacterBar"
onready var animationcalls = $"../../AnimationCalls"
onready var grid =  $GridContainer
onready var grid2 = $GridContainer2 
onready var expand_button = $ExpandCollapse
var skill_bar_input:String = ""
var active_cooldowns = {}
var edit = false
var capture_slot = null
var expand_state = 0
var mouse_repeat_counter={}
var no_press_tween_skills=["base attack","parry"]
var hold_skills={
	"parry":true,
	"guard":true,
	"base attack":true,
}

const CONFIG_FILE_PATH = "user://skillbar_keybinds.cfg"
const ACTION_PREFIX = "skill_slot_"
const ACTION_PREFIX2="mouse_slot_"


func _ready()->void:
	loadCooldowns()
	loadKeybinds()

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
	var keys=["F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","1","2","3","4","5","6","7","8","9","0","Q","E","R","T","F","G","Y","C","V","B"]
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



func _physics_process(delta)->void:
	updateCooldowns(delta)
	if player.cursor_visible == false:
		matchInputSlot()
		holdInputs()


func holdInputs()->void:
	for skill in hold_skills.keys():
		if player.anim_locks.has(skill) and player.anim_locks[skill]:

			var still_held := false

			# -------------------------
			# KEY GRID
			# -------------------------
			for i in range(grid.get_child_count()):
				var holder = grid.get_child(i)
				var slot = holder.get_node("Slot")

				if slot.texture and Skills.skills.has(skill):
					if slot.texture == Skills.skills[skill]:
						var action_name = ACTION_PREFIX + str(i)
						if Input.is_action_pressed(action_name):
							still_held = true
						break

			# -------------------------
			# MOUSE GRID
			# -------------------------
			if !still_held:
				for i in range(grid2.get_child_count()):
					var holder = grid2.get_child(i)
					var slot = holder.get_node("Slot")

					if slot.texture and Skills.skills.has(skill):
						if slot.texture == Skills.skills[skill]:
							var action_name = ACTION_PREFIX2 + str(i)
							if Input.is_action_pressed(action_name):
								still_held = true
							break

			if !still_held:
				player.anim_locks[skill]=false # 
				if player.current_skill==skill: #
					player.current_skill="" #

func setSlotVisible(holder,state:bool)->void:
	holder.modulate.a=1.0 if state else 0.0
	holder.mouse_filter=Control.MOUSE_FILTER_STOP if state else Control.MOUSE_FILTER_IGNORE
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

func expandCollapse()->void:
	expand_state += 1
	if expand_state > 2:
		expand_state = 0
	applyExpandState()
	saveKeybinds()




onready var skill_tree =   $"../SkillTreeRoot/SkillsTreeHolder"

func skills(slot)->void:
	if player.anim_locks["stunned"] == true or player.anim_locks["staggered"] == true:
		return
	# ==================================================
	# CACHE REFERENCES
	# ==================================================
	var inventory_grid:GridContainer=$"../Inventory/ScrollContainer/GridContainer"
	var stats=player.stats
	var inventory=$"../Inventory"
	var tween:Tween=$Tween

	# invalid slot
	if slot==null or slot.texture==null:
		return

	var path=slot.texture.resource_path
	
	# ==================================================
	# DETECT IF TEXTURE IS A SKILL OR AN ITEM
	# ==================================================
	var is_skill=false
	for skill in Skills.skills:
		if Skills.skills[skill]==slot.texture:
			is_skill=true
			break

	# ==================================================
	# ITEM SECTION
	# ==================================================
	if !is_skill:

		var holder=slot.get_parent()
		var button=holder.get_node("TextureButton")

		if active_cooldowns.has(path):
			return

		tween.stop_all()
		tween.interpolate_property(slot,"rect_scale",Vector2.ONE,Vector2(.9,.9),.08,Tween.TRANS_QUAD,Tween.EASE_OUT)
		tween.interpolate_property(slot,"rect_scale",Vector2(.9,.9),Vector2.ONE,.08,Tween.TRANS_QUAD,Tween.EASE_IN,.08)

		if button.quantity<=0:
			tween.interpolate_property(slot,"modulate",Color.white,Color(1,0,0),.08,Tween.TRANS_QUAD,Tween.EASE_OUT)
			tween.interpolate_property(slot,"modulate",Color(1,0,0),Color.white,.15,Tween.TRANS_QUAD,Tween.EASE_IN,.08)
			tween.start()
			return

		tween.interpolate_property(slot,"modulate",Color.white,Color(0,1,0),.08,Tween.TRANS_QUAD,Tween.EASE_OUT)
		tween.interpolate_property(slot,"modulate",Color(0,1,0),Color.white,.15,Tween.TRANS_QUAD,Tween.EASE_IN,.08)
		tween.start()

		if CommonBehaviours.useItem(button,inventory_grid,stats):

			var cooldown=Items.getCooldown(path)

			if cooldown>0.0:
				active_cooldowns[path]=cooldown

			button.quantity-=1

			if button.quantity<=0:
				button.quantity=0
				slot.texture=null
				button.item="null"

		return
	# ==================================================
	# SKILL SECTION
	# ==================================================

	# skill already cooling down
	if active_cooldowns.has(path):
		return

	for skill in Skills.skills:

		var texture=Skills.skills[skill]

		# wrong skill
		if path!=texture.resource_path:
			continue

		# not unlocked
		if !skill_tree.skills.has(skill) or skill_tree.skills[skill]<=0:
			return

		# --------------------------------------------------
		# PREVENT DOUBLE-CASTING SAME SKILL
		# --------------------------------------------------
		# Ignore repeated presses while the skill's
		# animation lock is still active.
		#
		# Base attack is excluded because it uses combo
		# sequencing and should keep its current behavior.
		# --------------------------------------------------
		# --------------------------------------------------

		if !hold_skills.has(skill):
			if player.anim_locks.has(skill) and player.anim_locks[skill]:
				return
		elif active_cooldowns.has(path):
			return

		# --------------------------------------------------
		# RESOURCE COST CHECK
		# --------------------------------------------------
		var energy_cost=Skills.getEnergyCost(skill)

		if energy_cost>0:

			# insufficient energy
			if player.stats.energy<energy_cost:
				return

			# spend energy
			player.stats.energy-=energy_cost
			character_ui.updateBars()

		# --------------------------------------------------
		# CLICK ANIMATION
		# --------------------------------------------------
		if !no_press_tween_skills.has(skill):
			tween.stop_all()
			tween.interpolate_property(slot,"rect_scale",Vector2.ONE,Vector2(.9,.9),.08,Tween.TRANS_QUAD,Tween.EASE_OUT)
			tween.interpolate_property(slot,"rect_scale",Vector2(.9,.9),Vector2.ONE,.08,Tween.TRANS_QUAD,Tween.EASE_IN,.08)
			tween.start()

		# --------------------------------------------------
		# TRIGGER SKILL
		# --------------------------------------------------
		# base attack can NEVER interrupt anything
		if player.anim_locks.has("dodge") and player.anim_locks["dodge"] and skill!="dodge":
			return

		if skill=="dodge":
			animationcalls.unlockAnim()

		elif skill=="parry":
			if player.anim_locks.has("dodge") and player.anim_locks["dodge"]:
				return

			animationcalls.unlockAnim()

		elif skill=="base attack":
			if player.anim_locks.has("base attack") and player.anim_locks["base attack"]:
				return

			for k in player.anim_locks:
				if k!="base attack" and player.anim_locks[k]:
					return

		else:
			if player.anim_locks.has("base attack"):
				player.anim_locks["base attack"]=false

		player.animation_tree.active=true
		player.flip_blend_timer=0.0
		player.dodge_cleanup_timer=0.0
		player.dodge_cleanup_reset=false

		if skill!="base attack":
			animationcalls.unlockAnim()

		player.anim_locks[skill]=true
		player.current_skill=skill
		player.combat_timer=10



		# --------------------------------------------------
		# APPLY COOLDOWN
		# --------------------------------------------------
		var cooldown=Skills.getCooldown(path)
		cooldown/=max(.01,player.stats.derived_stats["cooldown_reduction"])

		active_cooldowns[path]=cooldown

		# Apply cooldown manipulation effects
		Skills.applyCooldownEffects(skill,active_cooldowns)

		return



onready var tween2 = $Tween2
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


onready var inventory_grid=$"../Inventory/ScrollContainer/GridContainer"
onready var inventory = $"../Inventory"

func updateCooldowns(delta):
	for key in active_cooldowns.keys():
		active_cooldowns[key]=max(active_cooldowns[key]-delta,0.0)

	inventory.inventoryCooldowns(delta)

	for container in [grid,grid2]:
		for holder in container.get_children():
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
		var holder=grid.get_child(i)
		if Input.is_action_pressed(ACTION_PREFIX+str(i)):
			skills(holder.get_node("Slot"))

	for i in range(grid2.get_child_count()):
		var holder=grid2.get_child(i)
		if Input.is_action_pressed(ACTION_PREFIX2+str(i)):
			skills(holder.get_node("Slot"))



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
	config.save(CONFIG_FILE_PATH)


func loadKeybinds()->void:
	var config=ConfigFile.new()
	var has_save=config.load(CONFIG_FILE_PATH)==OK

	createDefaultSlots()
	createDefaultMouseSlots()

	if has_save:
		expand_state=config.get_value("UI","expand_state",0)

	for i in range(grid.get_child_count()):
		var holder=grid.get_child(i)
		var key=holder.get_node("Key")
		var action_name=ACTION_PREFIX+str(i)

		if !InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		InputMap.action_erase_events(action_name)

		var scancode=-1

		if has_save:
			scancode=config.get_value("Keys","slot_"+str(i),-1)

		if scancode==-1:
			scancode=getScancode(key.text)

		if scancode>0:
			var e=InputEventKey.new()
			e.scancode=scancode
			InputMap.action_add_event(action_name,e)

			var s=InputEventKey.new()
			s.scancode=scancode
			s.shift=true
			InputMap.action_add_event(action_name,s)

			key.text=OS.get_scancode_string(scancode).to_upper()

	for i in range(grid2.get_child_count()):
		var holder=grid2.get_child(i)
		var key=holder.get_node("Key")
		var action_name=ACTION_PREFIX2+str(i)

		if !InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		InputMap.action_erase_events(action_name)

		var button_index=-1

		if has_save:
			button_index=config.get_value("MouseKeys","slot_"+str(i),-1)

		if button_index==-1:
			if i==0:
				button_index=BUTTON_LEFT
			else:
				button_index=BUTTON_RIGHT

		var e=InputEventMouseButton.new()
		e.button_index=button_index
		InputMap.action_add_event(action_name,e)

		match button_index:
			BUTTON_LEFT:
				key.text="LM"
			BUTTON_RIGHT:
				key.text="RM"
			BUTTON_MIDDLE:
				key.text="MM"
			_:
				key.text="M"+str(button_index)

	applyExpandState()

	if !has_save:
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
