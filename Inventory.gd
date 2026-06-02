extends Control

onready var player = $"../.."
onready var stats = $"../../Stats"
onready var close_button:TextureButton = $Close
onready var combine_button:TextureButton = $Combine
onready var split_button:TextureButton = $Split
onready var order_button:TextureButton = $Order
onready var combine_selected_button:TextureButton = $CombineSelected
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

func _ready()->void:
	close_button.connect("pressed",self,"collapse")
	combine_button.connect("pressed",self,"combine")
	split_button.connect("pressed",self,"splitSelectedSlot")
	order_button.connect("pressed",self,"orderSlots")
	combine_selected_button.connect("pressed",self,"combineSelectedSlot")
	
	debug_give_me_items.connect("pressed",self,"getRandItems")

	setupInventorySlots()
	loadData()
	updateInventory()
func isArmor(texture)->bool:
	for key in Items.armors:
		if texture == Items.armors[key]["icon"]:
			return true
	return false


func combine()->void:
	var slots = inventory_grid.get_children()
	for i in range(slots.size()):
		var slot_a = slots[i]
		var texture_a = slot_a.get_node("Slot").texture
		if texture_a == null:
			continue
		if isArmor(texture_a):
			continue
		for j in range(i + 1, slots.size()):
			var slot_b = slots[j]
			var texture_b = slot_b.get_node("Slot").texture
			if texture_b == null:
				continue
			if isArmor(texture_b):
				continue
			if texture_a != texture_b:
				continue
			var max_quantity = max(slot_a.max_quantity, 9999999999)
			var space_left = max_quantity - slot_a.quantity
			if space_left <= 0:
				break
			var amount_to_move = min(space_left, slot_b.quantity)
			slot_a.stackable = true
			slot_b.stackable = true
			slot_a.quantity += amount_to_move
			slot_b.quantity -= amount_to_move

			if slot_b.quantity <= 0:
				slot_b.quantity = 0
				slot_b.get_node("Slot").texture = null

			slot_a.displayQuantity()
			slot_b.displayQuantity()

	updateInventory()




var selected_slot:TextureButton = null
onready var debug:Label = $Selected
func splitSelectedSlot()->void:
	if selected_slot != null:
		var selected_icon = selected_slot.get_node("Slot")
		if selected_icon.texture != null:
			var original_quantity = selected_slot.quantity
			if original_quantity > 1:
				for child in inventory_grid.get_children():
						var icon = child.get_node("Slot")
						if icon.texture == null:
							icon.texture = selected_icon.texture
							child.quantity += original_quantity / 2
							var new_quantity = original_quantity / 2  # Calculate the new quantity
							selected_slot.quantity = original_quantity - new_quantity  # Update the quantity of the first slot
							updateInventory()
							break

func combineSelectedSlot()->void:
	if selected_slot != null:
		var selected_icon = selected_slot.get_node("Slot")
		if selected_icon.texture != null:
			for child in inventory_grid.get_children():
				if child != selected_slot:
					var icon = child.get_node("Slot")
					if icon.texture == selected_icon.texture:
						selected_slot.quantity += child.quantity  # Add the quantities
						child.quantity = 0  # Reset the quantity of the combined slot
						icon.texture = null  # Clear the texture of the combined slot
						updateInventory()
func orderSlots() -> void:
	var slots_with_texture = []
	var slots_without_texture = []
	# Separate slots based on their icon texture
	for child in inventory_grid.get_children():
		var icon_texture = child.get_node("Slot").texture
		if icon_texture != null:
			slots_with_texture.append(child)
		else:
			slots_without_texture.append(child)
	# Reorder slots so that slots with texture come first
	var ordered_slots = []
	ordered_slots += slots_with_texture
	ordered_slots += slots_without_texture
	# Reposition the slots in the inventory_grid
	for i in range(ordered_slots.size()):
		var slot = ordered_slots[i]
		inventory_grid.move_child(slot, i)
func updateInventory()->void:
	for child in inventory_grid.get_children():
		child.displayQuantity()
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

	var alt_pressed = Input.is_action_pressed("ui_alt") or Input.is_key_pressed(KEY_ALT)

	if last_pressed_index == index and current_time - last_press_time <= double_press_time:
		last_pressed_index = -1
		last_press_time = 0.0

		if alt_pressed:
			clearSlot(index)
			return

		useItem(index)
		return
	selected_slot = inventory_grid.get_node("InventorySlot" + str(index))
	showSlotDebug(inventory_grid.get_node("InventorySlot" + str(index))) 
	last_pressed_index = index
	last_press_time = current_time
	updateInventory()


func useItem(index):
	var button = inventory_grid.get_node("InventorySlot" + str(index))
	var slot = button.get_node("Slot")
	var texture = slot.texture

	if texture == null:
		return

	var potion_flasks = [
		Items.flasks["energy"]["icon"],
		Items.flasks["medicine"]["icon"],
		Items.flasks["poison"]["icon"],
		Items.flasks["power"]["icon"]
	]

	if texture == Items.flasks["medicine"]["icon"]:
		stats.health += 10

	if texture in potion_flasks:
		button.quantity -= 1

		if button.quantity <= 0:
			button.quantity = 0
			slot.texture = null

		CommonBehaviours.addStackableItem(inventory_grid, Items.flasks["empty"])

	button.displayQuantity()
	updateInventory()
func clearSlot(index):
	var button = inventory_grid.get_node("InventorySlot" + str(index))
	var slot = button.get_node("Slot")

	button.quantity = 0
	slot.texture = null

	button.displayQuantity()
	updateInventory()
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
			"quantity": child.quantity,
			"stackable": child.stackable,
			"max_quantity": child.max_quantity
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
					child.quantity = slot_data.get("quantity", 0)
					child.stackable = slot_data.get("stackable", false)
					child.max_quantity = slot_data.get("max_quantity", 9999999999)



					if slot_data["texture"] != "":
						slot.texture = load(slot_data["texture"])
					else:
						slot.texture = null
		file.close()

func collapse()->void:
	hide()
	updateInventory()

func getRandItems()->void:
	for child in inventory_grid.get_children():
		child.displayQuantity()
	CommonBehaviours.addStackableItem(inventory_grid,Items.flasks["energy"],10)
	CommonBehaviours.addNotStackableItem(inventory_grid,Items.armors["torso1"])
	CommonBehaviours.addNotStackableItem(inventory_grid,Items.armors["torso2"])
	CommonBehaviours.addNotStackableItem(inventory_grid,Items.armors["torso1"])
	CommonBehaviours.addNotStackableItem(inventory_grid,Items.armors["feet1"])
	CommonBehaviours.addNotStackableItem(inventory_grid,Items.weapons["sword"])
	CommonBehaviours.addNotStackableItem(inventory_grid,Items.weapons["fork"])
	CommonBehaviours.addNotStackableItem(inventory_grid,Items.armors["hands1"])
	CommonBehaviours.addNotStackableItem(inventory_grid,Items.armors["hands2"])
	CommonBehaviours.addStackableItem(inventory_grid,Items.flasks["energy"],5)
	CommonBehaviours.addStackableItem(inventory_grid,Items.flasks["medicine"],5)
	CommonBehaviours.addStackableItem(inventory_grid,Items.flasks["medicine"],5)
	CommonBehaviours.addStackableItem(inventory_grid,Items.flasks["poison"],5)
	CommonBehaviours.addStackableItem(inventory_grid,Items.flasks["power"],5)
	CommonBehaviours.addStackableItem(inventory_grid,Items.flasks["power"],5)

	updateInventory()
func _on_inventory_slot_mouse_entered(index):
	updateInventory()

func _on_inventory_slot_mouse_exited(index):
	updateInventory()



func showSlotDebug(slot):
	if slot == null:
		debug.text = "null slot"
		return

	var icon = slot.get_node("Slot")

	var item_name = "empty"
	var qty = slot.quantity

	if icon.texture != null:
		item_name = icon.texture.resource_path.get_file().get_basename()

	debug.text = str(slot) + " | " + item_name + " x" + str(qty)
