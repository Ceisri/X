extends Control

onready var player = $"../.."
onready var stats = $"../../Stats"
onready var close_button = $Close
onready var debug_give_me_items = $DebugGiveMeItems
onready var inventory_grid = $ScrollContainer/GridContainer

var last_pressed_index:int = -1
var last_press_time:float = 0.0

export var double_press_time:float = 0.4
export var max_inventory_slots:int = 60

const SAVE_DIR = "user://Characters/"
const SAVE_FILE = "/inventory.save"

func _physics_process(delta):
	if Input.is_action_just_pressed("Inventory"):
		visible = !visible
		saveData()

func _ready()->void:
	close_button.connect("pressed",self,"collapse")
	debug_give_me_items.connect("pressed",self,"getRandItems")

	setupInventorySlots()
	loadData()

func setupInventorySlots():
	var original_slot = inventory_grid.get_child(0)

	for i in range(inventory_grid.get_child_count(),max_inventory_slots):
		var new_slot = original_slot.duplicate()

		new_slot.name = "InventorySlot" + str(i)
		new_slot.quantity = 0
		new_slot.get_node("Slot").texture = null

		inventory_grid.add_child(new_slot)

	for child in inventory_grid.get_children():
		var index_str = child.get_name().replace("InventorySlot","")
		var index = int(index_str)

		if !child.is_connected("pressed",self,"_on_inventory_slot_pressed"):
			child.connect("pressed",self,"_on_inventory_slot_pressed",[index])

		if !child.is_connected("mouse_entered",self,"_on_inventory_slot_mouse_entered"):
			child.connect("mouse_entered",self,"_on_inventory_slot_mouse_entered",[index])

		if !child.is_connected("mouse_exited",self,"_on_inventory_slot_mouse_exited"):
			child.connect("mouse_exited",self,"_on_inventory_slot_mouse_exited",[index])

func _on_inventory_slot_pressed(index):
	var current_time = OS.get_ticks_msec() / 1000.0

	if last_pressed_index == index and current_time - last_press_time <= double_press_time:
		last_pressed_index = -1
		last_press_time = 0.0

		useItem(index)
		return

	last_pressed_index = index
	last_press_time = current_time

func useItem(index):
	var button = inventory_grid.get_node("InventorySlot" + str(index))
	var slot = button.get_node("Slot")
	var texture = slot.texture

	if texture == null:
		return

	var potion_flasks = [
		Items.flasks["energy"],
		Items.flasks["medicine"],
		Items.flasks["poison"],
		Items.flasks["power"]
	]

	if texture == Items.flasks["medicine"]:
		stats.health += 10

	if texture in potion_flasks:
		button.quantity -= 1

		if button.quantity <= 0:
			button.quantity = 0
			slot.texture = null

		CommonBehaviours.addStackableItem(
			inventory_grid,
			Items.flasks["empty"]
		)

	saveData()

func saveData():
	var dir = Directory.new()
	var character_dir = SAVE_DIR + player.entity_name

	if !dir.dir_exists(character_dir):
		dir.make_dir_recursive(character_dir)

	var file = File.new()

	if file.open(character_dir + SAVE_FILE,File.WRITE) == OK:
		var data = {
			"visible": visible,
			"max_inventory_slots": max_inventory_slots,
			"slots": {}
		}

		for child in inventory_grid.get_children():
			var slot = child.get_node("Slot")

			data["slots"][child.name] = {
				"texture": slot.texture.resource_path if slot.texture != null else "",
				"quantity": child.quantity
			}

		file.store_var(data)
		file.close()

func loadData():
	var path = SAVE_DIR + player.entity_name + SAVE_FILE

	var file = File.new()

	if !file.file_exists(path):
		return

	if file.open(path,File.READ) == OK:
		var data = file.get_var()

		if data.has("visible"):
			visible = data["visible"]

		if data.has("max_inventory_slots"):
			max_inventory_slots = data["max_inventory_slots"]

		if data.has("slots"):
			for child in inventory_grid.get_children():
				if data["slots"].has(child.name):
					var slot = child.get_node("Slot")
					var slot_data = data["slots"][child.name]

					child.quantity = slot_data["quantity"]

					if slot_data["texture"] != "":
						slot.texture = load(slot_data["texture"])
					else:
						slot.texture = null

		file.close()

func collapse()->void:
	hide()
	saveData()

func getRandItems()->void:
	CommonBehaviours.addStackableItem(
		inventory_grid,
		Items.flasks["energy"]
	)

	CommonBehaviours.addStackableItem(
		inventory_grid,
		Items.flasks["energy"]
	)

	CommonBehaviours.addStackableItem(
		inventory_grid,
		Items.flasks["medicine"]
	)

	CommonBehaviours.addStackableItem(
		inventory_grid,
		Items.flasks["medicine"]
	)

	CommonBehaviours.addStackableItem(
		inventory_grid,
		Items.flasks["poison"]
	)

	CommonBehaviours.addStackableItem(
		inventory_grid,
		Items.flasks["poison"]
	)

	CommonBehaviours.addStackableItem(
		inventory_grid,
		Items.flasks["power"]
	)

	CommonBehaviours.addStackableItem(
		inventory_grid,
		Items.flasks["power"]
	)

	saveData()

func _on_inventory_slot_mouse_entered(index):
	pass

func _on_inventory_slot_mouse_exited(index):
	pass
