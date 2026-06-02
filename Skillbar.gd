extends Control

onready var player = $"../.."
onready var character_ui = $"../Menu/CharacterBar"
onready var animationcalls = $"../../AnimationCalls"
onready var grid = $GridContainer
onready var expand_button = $ExpandCollapse
var skill_bar_input:String = ""
var active_cooldowns = {}
var edit = false
var capture_slot = null
var expand_state = 0
const CONFIG_FILE_PATH = "user://skillbar_keybinds.cfg"
const ACTION_PREFIX = "skill_slot_"

func _ready()->void:
	loadCooldowns()
	loadKeybinds()
	for button in grid.get_children():
		button.connect("pressed",self,"slotPressed",[button])
	expand_button.connect("pressed",self,"expandCollapse")
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
	if slot == null:
		return
	if slot.texture == null:
		return

	var path = slot.texture.resource_path

	if active_cooldowns.has(path):
		return

	for skill in PlayerSkills.skills:
		var texture = PlayerSkills.skills[skill]

		if path == texture.resource_path:
			if !skill_tree.skills.has(skill):
				return
			if skill_tree.skills[skill] <= 0:
				return

			# Check energy cost
			var energy_cost = PlayerSkills.getEnergyCost(skill)

			if energy_cost > 0:
				if player.stats.energy < energy_cost:
					return # Not enough energy

				player.stats.energy -= energy_cost
				character_ui.updateBars()
				
			animationcalls.unlockAnim()
			player.anim_locks[skill] = true
			var cooldown = PlayerSkills.getCooldown(path)
			cooldown /= max(0.01,player.stats.derived_stats["cooldown_reduction"])
			active_cooldowns[path] = cooldown
			return
func updateCooldowns(delta)->void:
	for button in grid.get_children():
		if !button.has_node("Slot"):
			continue
		var slot = button.get_node("Slot")
		if slot.texture == null:
			continue
		var path = slot.texture.resource_path
		if active_cooldowns.has(path):
			active_cooldowns[path] -= delta
			var cd = max(active_cooldowns[path],0)
			slot.get_node("CD").text = str(int(ceil(cd)))
			if cd <= 0:
				active_cooldowns.erase(path)
				slot.get_node("CD").text = ""

		else:
			slot.get_node("CD").text = ""
func matchInputSlot()->void:
	for i in range(grid.get_child_count()):
		var action_name = ACTION_PREFIX + str(i)
		if Input.is_action_just_pressed(action_name):
			var button = grid.get_child(i)
			skills(button.get_node("Slot"))
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

	InputMap.action_add_event(
		action_name,
		normal_event
	)

	var shift_event = InputEventKey.new()
	shift_event.scancode = event.scancode
	shift_event.shift = true

	InputMap.action_add_event(
		action_name,
		shift_event
	)

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
	var config = ConfigFile.new()
	for i in range(grid.get_child_count()):
		var button = grid.get_child(i)
		var slot = button.get_node("Slot")
		var action_name = ACTION_PREFIX + str(i)
		var events = InputMap.get_action_list(action_name)
		var scancode = -1
		for e in events:
			if e is InputEventKey:
				scancode = e.scancode
				break
		config.set_value("Keys", "slot_" + str(i), scancode)
	config.set_value("UI", "expand_state", expand_state)
	config.save(CONFIG_FILE_PATH)
func loadKeybinds()->void:
	var config = ConfigFile.new()
	var has_save = (config.load(CONFIG_FILE_PATH) == OK)
	if has_save:
		expand_state = config.get_value("UI", "expand_state", 0)
	for i in range(grid.get_child_count()):
		var button = grid.get_child(i)
		var slot = button.get_node("Slot")
		var action_name = (ACTION_PREFIX + str(i))
		if !InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		var key_text = (slot.get_node("Key").text.to_upper())
		var scancode = -1
		if has_save:
			scancode = config.get_value("Keys", "slot_" + str(i), -1)
		if scancode == -1:
			scancode = getScancode(key_text)
		if scancode == 0:
			continue
		var normal_event = InputEventKey.new()
		normal_event.scancode = (scancode)
		InputMap.action_add_event(action_name, normal_event)
		var shift_event = InputEventKey.new()
		shift_event.scancode = (scancode)
		shift_event.shift = true
		InputMap.action_add_event(action_name, shift_event)
		slot.get_node("Key").text = OS.get_scancode_string(scancode).to_upper()
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
