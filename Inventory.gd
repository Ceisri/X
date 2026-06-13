extends Control

onready var player = $"../.."
onready var stats = $"../../Stats"
onready var close_button:TextureButton = $Close
onready var combine_button:TextureButton = $Tools/ToolGrid/Combine
onready var split_button:TextureButton = $Tools/ToolGrid/Split
onready var order_button:TextureButton = $Tools/ToolGrid/Order

onready var debug_give_me_items =  $DebugGiveMeItems
onready var inventory_grid =  $ScrollContainer/GridContainer

var last_pressed_index:int = -1
var last_press_time:float = 0.0

export var double_press_time:float = 0.4
export var max_inventory_slots:int = 60

const SAVE_DIR = "user://Characters/"
const SAVE_FILE = "/inventory.save"

func _physics_process(delta):
	if Input.is_action_just_pressed("Inventory"):
		visible = !visible
		updateInventory()

func _ready()->void:
	$Close.connect("pressed",self,"collapse")
	combine_button.connect("pressed",self,"combinePressed")
	split_button.connect("pressed",self,"splitSelectedSlot")
	order_button.connect("pressed",self,"orderSlots")

	debug_give_me_items.connect("pressed",self,"getRandItems")

	setupInventorySlots()
	loadData()
	updateInventory()
func isArmor(texture)->bool:
	for key in Items.armors:
		if texture == Items.armors[key]["icon"]:
			return true
	return false

var combine_mode := 0 # 0=selected, 1=all
func combinePressed()->void:
	if combine_mode == 0:
		combineSelectedSlot()
	else:
		combine()

	combine_mode = (combine_mode + 1) % 2
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
	if selected_slot:
		splitSlot(int(selected_slot.name.replace("InventorySlot","")))

func combineSelectedSlot()->void:
	if selected_slot:
		combineSlot(int(selected_slot.name.replace("InventorySlot","")))
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
		if !child.is_connected("gui_input",self,"_on_inventory_slot_gui_input"):
			child.connect("gui_input",self,"_on_inventory_slot_gui_input",[index])
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

	if Input.is_key_pressed(KEY_SHIFT):
		combineSlot(index)
	return



func _on_inventory_slot_gui_input(event,index):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_RIGHT:
			splitSlot(index)



func splitSlot(index):
	var slot=inventory_grid.get_node("InventorySlot"+str(index))
	var icon=slot.get_node("Slot")

	if icon.texture==null or slot.quantity<2:
		return

	var split_amount=int(slot.quantity/2)

	for child in inventory_grid.get_children():
		if child==slot:
			continue

		var cicon=child.get_node("Slot")

		if cicon.texture==null:
			cicon.texture=icon.texture
			child.quantity=split_amount
			child.stackable=slot.stackable
			child.max_quantity=slot.max_quantity

			slot.quantity-=split_amount

			slot.displayQuantity()
			child.displayQuantity()
			updateInventory()
			return




func combineSlot(index):
	var slot=inventory_grid.get_node("InventorySlot"+str(index))
	var icon=slot.get_node("Slot")

	if icon.texture==null or !slot.stackable:
		return

	for child in inventory_grid.get_children():
		if child==slot:
			continue

		var cicon=child.get_node("Slot")

		if cicon.texture==icon.texture and child.stackable:
			slot.quantity+=child.quantity
			child.quantity=0
			cicon.texture=null

			child.displayQuantity()

	slot.displayQuantity()
	updateInventory()



onready var tween = $Tween
var cooldowns = {}

var flash_time={}
onready var skillbar= $"../Skillbar"

func get_cd(k):
	return skillbar.active_cooldowns[k] if skillbar.active_cooldowns.has(k) else 0.0

func set_cd(k,t):
	if t>0.0:skillbar.active_cooldowns[k]=t
func useItem(index):
	var slot=inventory_grid.get_node("InventorySlot"+str(index))
	var icon=slot.get_node("Slot")
	if !icon.texture:return
	var key=icon.texture.resource_path
	if get_cd(key)>0.0:return
	if !CommonBehaviours.useItem(slot,inventory_grid,stats):return
	slot.quantity-=1
	if slot.quantity<=0:
		slot.quantity=0
		icon.texture=null
	set_cd(key,Items.getCooldown(key))

func inventoryCooldowns(delta):
	for key in skillbar.active_cooldowns.keys():
		var t=skillbar.active_cooldowns[key]-delta
		skillbar.active_cooldowns[key]=0.0 if t<=0.0 else t
	for slot in inventory_grid.get_children():
		var icon=slot.get_node("Slot")
		if !icon.texture:continue
		var key=icon.texture.resource_path
		if get_cd(key)<=0.0:continue



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
	var floating_text_parent = $"../Menu/CharacterBar/Control"

	for child in inventory_grid.get_children():
		child.displayQuantity()

	CommonBehaviours.addStackableItem(inventory_grid, Items.flasks["energy"], floating_text_parent, 10)

	CommonBehaviours.addNotStackableItem(inventory_grid, Items.armors["torso1"], floating_text_parent)
	CommonBehaviours.addNotStackableItem(inventory_grid, Items.armors["torso2"], floating_text_parent)
	CommonBehaviours.addNotStackableItem(inventory_grid, Items.armors["torso1"], floating_text_parent)
	CommonBehaviours.addNotStackableItem(inventory_grid, Items.armors["feet1"], floating_text_parent)
	CommonBehaviours.addNotStackableItem(inventory_grid, Items.weapons["sword"], floating_text_parent)
	CommonBehaviours.addNotStackableItem(inventory_grid, Items.weapons["fork"], floating_text_parent)
	CommonBehaviours.addNotStackableItem(inventory_grid, Items.weapons["shield"], floating_text_parent)
	CommonBehaviours.addNotStackableItem(inventory_grid, Items.armors["hands1"], floating_text_parent)
	CommonBehaviours.addNotStackableItem(inventory_grid, Items.armors["hands2"], floating_text_parent)

	CommonBehaviours.addStackableItem(inventory_grid, Items.flasks["energy"], floating_text_parent, 5)
	CommonBehaviours.addStackableItem(inventory_grid, Items.flasks["medicine"], floating_text_parent, 5)
	CommonBehaviours.addStackableItem(inventory_grid, Items.flasks["medicine"], floating_text_parent, 5)
	CommonBehaviours.addStackableItem(inventory_grid, Items.flasks["poison"], floating_text_parent, 5)
	CommonBehaviours.addStackableItem(inventory_grid, Items.flasks["power"], floating_text_parent, 5)
	CommonBehaviours.addStackableItem(inventory_grid, Items.flasks["power"], floating_text_parent, 5)
		
	
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
