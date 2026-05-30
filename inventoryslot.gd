extends TextureButton
# inventory slot script

signal quantity_changed(new_quantity)

onready var icon = get_node_or_null("Slot")
onready var quantity_label = get_node_or_null("Quantity")
onready var inventory = get_node_or_null("../../..")

var quantity = 0 setget set_quantity
var type = "item"
var stackable = false
var max_quantity = 9999999999


func _ready():
	if not icon:
		print("InventorySlot: missing Slot node")
	if not quantity_label:
		print("InventorySlot: missing Quantity label")

	connect("quantity_changed", self, "displayQuantity")
	
	updateStackableFromTexture()
	displayQuantity()


func set_quantity(value):
	quantity = value
	emit_signal("quantity_changed", quantity)


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
	if icon.texture in Items.armors.values():
		stackable = false
	else:
		stackable = true


func displayQuantity():
	if not icon:
		print("displayQuantity: icon missing")
		return

	if icon.texture == null:
		quantity = 0
		if quantity_label:
			quantity_label.text = ""
		return

	if quantity > 0:
		if quantity_label:
			quantity_label.text = str(round(quantity))
	else:
		if quantity_label:
			quantity_label.text = ""
		icon.texture = null


func get_drag_data(position: Vector2):
	if not icon:
		print("get_drag_data: missing icon")
		return null

	var parent_slot = get_parent().get_name() if get_parent() else "UNKNOWN"

	var data = {
		"origin_node": self,
		"origin_slot": parent_slot,
		"origin_texture": icon.texture,
		"origin_quantity": quantity,
		"origin_stackable": stackable,
		"origin_max_quantity": max_quantity,
		"type": type
	}

	displayQuantity()
	return data


func can_drop_data(position, data):
	if typeof(data) != TYPE_DICTIONARY:
		print("can_drop_data: invalid data type")
		return false

	if not data.has("type"):
		print("can_drop_data: missing type key")
		return false

	if icon:
		data["target_texture"] = icon.texture
	data["target_quantity"] = quantity

	return data.get("type", "") != "skill"


func drop_data(position, data):
	if typeof(data) != TYPE_DICTIONARY:
		print("drop_data: invalid data")
		return

	if not data.has("origin_node"):
		print("drop_data: missing origin_node")
		return

	var origin_node = data["origin_node"]
	if not is_instance_valid(origin_node):
		print("drop_data: origin_node is invalid")
		return

	var origin_icon = origin_node.get_node_or_null("Slot")
	if not origin_icon:
		print("drop_data: origin_slot missing Slot node")
		return

	var dragPreview = origin_node.get_node_or_null("Sprite")
	if dragPreview:
		dragPreview.queue_free()

	var origin_texture = data.get("origin_texture", null)
	var origin_quantity = data.get("origin_quantity", 0)
	var origin_stackable = data.get("origin_stackable", false)
	var origin_max_quantity = data.get("origin_max_quantity", 0)

	if origin_texture == null:
		print("drop_data: origin_texture is null")
		return

	var target_texture = icon.texture if icon else null

	if (
		origin_texture == target_texture
		and stackable
		and origin_stackable
	):
		var total = quantity + origin_quantity

		if total <= max_quantity:
			quantity = total
			origin_node.quantity = 0
			origin_icon.texture = null
		else:
			quantity = max_quantity
			origin_node.quantity = total - max_quantity
	else:
		if origin_icon:
			origin_icon.texture = target_texture
		if icon:
			icon.texture = origin_texture

		origin_node.quantity = data.get("target_quantity", quantity)
		quantity = origin_quantity

		origin_node.stackable = data.get("target_stackable", stackable)
		stackable = origin_stackable

		origin_node.max_quantity = data.get("target_max_quantity", max_quantity)
		max_quantity = origin_max_quantity

	displayQuantity()

	if origin_node and origin_node.has_method("displayQuantity"):
		origin_node.displayQuantity()

	if inventory and inventory.has_method("saveData"):
		inventory.saveData()
