extends Control

onready var player = $"../.."
onready var animationcalls = $"../../AnimationCalls"
onready var grid = $GridContainer

var skill_bar_input:String = ""
var active_cooldowns = {}
var edit = false
var capture_slot = null

const CONFIG_FILE_PATH = "user://skillbar_keybinds.cfg"
const ACTION_PREFIX = "skill_slot_"

func _ready()->void:
	loadCooldowns()
	loadKeybinds()

	for button in grid.get_children():
		button.connect("pressed",self,"slotPressed",[button])

func _physics_process(delta)->void:
	updateCooldowns(delta)
	skillBarInputs()
	matchInputSlot()

func skills(slot)->void:
	if slot == null:
		return
	if slot.texture == null:
		return

	var path = slot.texture.resource_path
	if active_cooldowns.has(path):
		return

	if path == PlayerSkills.dodge.get_path():
		animationcalls.unlockAnim()
		player.anim_locks["dodge"] = true
		active_cooldowns[path] = PlayerSkills.getCooldown(path)
		saveCooldowns()
	elif path == PlayerSkills.cleave.get_path():
		animationcalls.unlockAnim()
		player.anim_locks["cleave"] = true
		active_cooldowns[path] = PlayerSkills.getCooldown(path)
		saveCooldowns()
	elif path == PlayerSkills.battlecry.get_path():
		animationcalls.unlockAnim()
		player.anim_locks["battlecry"] = true
		active_cooldowns[path] = PlayerSkills.getCooldown(path)
		saveCooldowns()


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
				saveCooldowns()
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

	var input_event = InputEventKey.new()
	input_event.scancode = event.scancode

	InputMap.action_add_event(action_name, input_event)

	capture_slot.get_node("Key").text = OS.get_scancode_string(event.scancode).to_upper()

	saveKeybinds()
	capture_slot = null

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

	config.save(CONFIG_FILE_PATH)

func loadKeybinds()->void:
	var config = ConfigFile.new()
	if config.load(CONFIG_FILE_PATH) != OK:
		return

	for i in range(grid.get_child_count()):
		var button = grid.get_child(i)
		var slot = button.get_node("Slot")

		var action_name = ACTION_PREFIX + str(i)

		if !InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		var scancode = config.get_value("Keys", "slot_" + str(i), -1)

		if typeof(scancode) == TYPE_INT and scancode != -1:
			var input_event = InputEventKey.new()
			input_event.scancode = scancode
			InputMap.action_add_event(action_name, input_event)
			slot.get_node("Key").text = OS.get_scancode_string(scancode).to_upper()


func getSlotIndex(slot)->int:
	for i in range(grid.get_child_count()):
		var button = grid.get_child(i)
		if button.get_node("Slot") == slot:
			return i
	return -1

func saveCooldowns()->void:
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
