extends Control

onready var player = $"../.."
onready var character_ui = $"../Menu/CharacterBar"
onready var animationcalls = $"../../AnimationCalls"
onready var grid = $GridContainer
onready var grid2 = $GridContainer2 
onready var expand_button = $ExpandCollapse
var skill_bar_input:String = ""
var active_cooldowns = {}
var edit = false
var capture_slot = null
var expand_state = 0
const CONFIG_FILE_PATH = "user://skillbar_keybinds.cfg"
const ACTION_PREFIX = "skill_slot_"
const ACTION_PREFIX2="mouse_slot_"


func _ready()->void:
	loadCooldowns()
	loadKeybinds()
	for button in grid.get_children():
		button.connect("pressed",self,"slotPressed",[button])
	expand_button.connect("pressed",self,"expandCollapse")
	
func createDefaultMouseSlots()->void:
	var keys=["LM","RM"]
	var base=grid2.get_node("TextureButton0")

	for i in range(1,2):
		if grid2.has_node("TextureButton"+str(i)):
			continue

		var b=base.duplicate()
		b.name="TextureButton"+str(i)
		grid2.add_child(b)
		b.owner=self

	for i in range(2):
		var b=grid2.get_node("TextureButton"+str(i))
		b.get_node("Slot/Key").text=keys[i]

		if !InputMap.has_action(ACTION_PREFIX2+str(i)):
			InputMap.add_action(ACTION_PREFIX2+str(i))

		InputMap.action_erase_events(ACTION_PREFIX2+str(i))

		var e=InputEventMouseButton.new()
		e.button_index=BUTTON_LEFT if i==0 else BUTTON_RIGHT
		InputMap.action_add_event(ACTION_PREFIX2+str(i),e)



func createDefaultSlots()->void:
	var keys=["F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","1","2","3","4","5","6","7","8","9","0","Q","E","R","T","F","G","Y","C","V","B"]
	var base=grid.get_node("TextureButton0")
	for i in range(1,30):
		if grid.has_node("TextureButton"+str(i)):
			continue
		var b=base.duplicate()
		b.name="TextureButton"+str(i)
		grid.add_child(b)
		b.owner=self
		b.connect("pressed",self,"slotPressed",[b])
	for i in range(30):
		var b=grid.get_node("TextureButton"+str(i))
		b.get_node("Slot/Key").text=keys[i]


func _physics_process(delta)->void:
	updateCooldowns(delta)
	skillBarInputs()
	matchInputSlot()
func setSlotVisible(button, state:bool)->void:
	button.modulate.a = (1.0 if state else 0.0)
	button.disabled = !state
	button.mouse_filter = (Control.MOUSE_FILTER_STOP if state else Control.MOUSE_FILTER_IGNORE)
func applyExpandState()->void:
	for i in range(20):
		if grid.has_node("TextureButton" + str(i)):
			setSlotVisible(grid.get_node("TextureButton" + str(i)), true)
	match expand_state:
		1:
			for i in range(10):
				if grid.has_node("TextureButton" + str(i)):
					setSlotVisible(grid.get_node("TextureButton" + str(i)), false)
		2:
			for i in range(20):
				if grid.has_node("TextureButton" + str(i)):
					setSlotVisible(grid.get_node("TextureButton" + str(i)), false)

func expandCollapse()->void:
	expand_state += 1
	if expand_state > 2:
		expand_state = 0
	applyExpandState()
	saveKeybinds()




onready var skill_tree =   $"../SkillTreeRoot/SkillsTreeHolder"

func skills(slot)->void:
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
	for skill in PlayerSkills.skills:
		if PlayerSkills.skills[skill]==slot.texture:
			is_skill=true
			break

	# ==================================================
	# ITEM SECTION
	# ==================================================
	if !is_skill:

		var button=slot.get_parent()

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

	for skill in PlayerSkills.skills:

		var texture=PlayerSkills.skills[skill]

		# wrong skill
		if path!=texture.resource_path:
			continue

		# not unlocked
		if !skill_tree.skills.has(skill) or skill_tree.skills[skill]<=0:
			return

		# --------------------------------------------------
		# RESOURCE COST CHECK
		# --------------------------------------------------
		var energy_cost=PlayerSkills.getEnergyCost(skill)

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
		tween.stop_all()
		tween.interpolate_property(slot,"rect_scale",Vector2.ONE,Vector2(.9,.9),.08,Tween.TRANS_QUAD,Tween.EASE_OUT)
		tween.interpolate_property(slot,"rect_scale",Vector2(.9,.9),Vector2.ONE,.08,Tween.TRANS_QUAD,Tween.EASE_IN,.08)
		tween.start()

		# --------------------------------------------------
		# TRIGGER SKILL
		# --------------------------------------------------
		animationcalls.unlockAnim()
		player.anim_locks[skill]=true

		# --------------------------------------------------
		# APPLY COOLDOWN
		# --------------------------------------------------
		var cooldown=PlayerSkills.getCooldown(path)
		cooldown/=max(.01,player.stats.derived_stats["cooldown_reduction"])
		active_cooldowns[path]=cooldown

		return
func updateCooldowns(delta)->void:
	var processed={}

	for container in [grid,grid2]:
		for button in container.get_children():
			if !button.has_node("Slot"):
				continue

			var slot=button.get_node("Slot")

			if slot.texture==null:
				slot.get_node("CD").text=""
				continue

			var path=slot.texture.resource_path

			if active_cooldowns.has(path):
				if !processed.has(path):
					active_cooldowns[path]-=delta
					processed[path]=true

				var cd=max(active_cooldowns[path],0)
				slot.get_node("CD").text=str(int(ceil(cd)))

				if cd<=0:
					active_cooldowns.erase(path)
					slot.get_node("CD").text=""
			else:
				slot.get_node("CD").text=""
func matchInputSlot()->void:#calls skills based on slot and asigned key
	for i in range(grid.get_child_count()):
		var action_name=ACTION_PREFIX+str(i)

		if Input.is_action_just_pressed(action_name):
			skills(grid.get_child(i).get_node("Slot"))

	for i in range(grid2.get_child_count()):
		var action_name=ACTION_PREFIX2+str(i)

		if Input.is_action_just_pressed(action_name):
			skills(grid2.get_child(i).get_node("Slot"))
func skillBarInputs()->void:
	pass
func slotPressed(button)->void:
	if !edit:
		return
	capture_slot = button.get_node("Slot")
	capture_slot.get_node("Key").text = "..."

func _input(event)->void:
	if capture_slot == null:
		return
	if event is InputEventKey and event.pressed:
		assignKey(event)

func assignKey(event)->void:
	var index = getSlotIndex(capture_slot)
	var action_name = ACTION_PREFIX + str(index)

	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)

	var normal_event = InputEventKey.new()
	normal_event.scancode = event.scancode

	InputMap.action_add_event(action_name,normal_event)

	var shift_event = InputEventKey.new()
	shift_event.scancode = event.scancode
	shift_event.shift = true

	InputMap.action_add_event(action_name,shift_event)

	capture_slot.get_node("Key").text = OS.get_scancode_string(
		event.scancode
	).to_upper()

	saveKeybinds()

	capture_slot = null

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
			return OS.find_scancode_from_string(
				key_text
			)
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
		var button=grid.get_child(i)
		var slot=button.get_node("Slot")
		var action_name=ACTION_PREFIX+str(i)

		if !InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		InputMap.action_erase_events(action_name)

		var scancode=-1

		if has_save:
			scancode=config.get_value("Keys","slot_"+str(i),-1)

		if scancode==-1:
			scancode=getScancode(slot.get_node("Key").text)

		if scancode<=0:
			continue

		var e=InputEventKey.new()
		e.scancode=scancode
		InputMap.action_add_event(action_name,e)

		var s=InputEventKey.new()
		s.scancode=scancode
		s.shift=true
		InputMap.action_add_event(action_name,s)

		slot.get_node("Key").text=OS.get_scancode_string(scancode).to_upper()

	applyExpandState()

	if !has_save:
		saveKeybinds()
func getSlotIndex(slot)->int:
	for i in range(grid.get_child_count()):
		var button = grid.get_child(i)
		if button.get_node("Slot") == slot:
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
