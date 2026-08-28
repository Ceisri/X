extends TextureButton
# Slot script

signal quantity_changed(new_quantity)

onready var icon = get_node_or_null("Slot")
onready var quantity_label = get_node_or_null("Quantity")
onready var inventory = get_node_or_null("../../..")

var quantity = 0 setget set_quantity
var type = "item"
var stackable = false
var max_quantity = 9999999999


func _ready():
	if quantity >= 2:
		stackable = true
	else:
		stackable = false
	if not icon:
		print("InventorySlot: missing Slot node")
	if not quantity_label:
		print("InventorySlot: missing Quantity label")

	connect("quantity_changed", self, "displayQuantity")
	
	updateStackableFromTexture()
	displayQuantity()


func set_quantity(value):
	if visible == false:
		return
	quantity = value


func updateStackableFromTexture():
	# no item → default
	if not icon or not icon.texture:
		stackable = false
		return

	# safety check for Items
	if not Engine.has_singleton("Items") and not get_node_or_null("/root/Items"):
		return

	# ARMOR = NOT stackable
	# everything else = stackable
	if icon.texture in Global.armors.values():
		stackable = false
	else:
		stackable = true


func displayQuantity():
	if visible == false:
		return
	if !icon:
		return

	if icon.texture == null:
		if quantity_label:
			quantity_label.text = ""
		return

	if quantity_label:
		quantity_label.text = str(quantity) if quantity > 0 else ""


func get_drag_data(position:Vector2):
	return null


func can_drop_data(position,data):
	return false
func drop_data(position,data):
	return
