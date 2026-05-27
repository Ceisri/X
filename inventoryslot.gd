extends TextureButton
#inventory slot script

onready var icon = $Slot
onready var quantity_label = $Quantity
onready var inventory = $"../../.."

var quantity = 0
var item = "null"
var type = "item"
var stackable = true
var max_quantity = 9999999999

func _ready():
	displayQuantity()

func _physics_process(delta):
	if Engine.get_physics_frames() % 12 == 0:
		displayQuantity()

func displayQuantity():
	if icon.texture == null:
		quantity = 0
		quantity_label.text = ""
		return

	if quantity > 0:
		quantity_label.text = str(round(quantity))
	else:
		quantity_label.text = ""
		icon.texture = null

func get_drag_data(position:Vector2):
	var parent_slot = get_parent().get_name()

	var data = {
		"origin_node": self,
		"origin_slot": parent_slot,
		"origin_texture": icon.texture,
		"origin_quantity": quantity,
		"origin_item": item,
		"type": type
	}

	displayQuantity()
	return data

func can_drop_data(position,data):
	displayQuantity()

	data["target_texture"] = icon.texture
	data["target_quantity"] = quantity
	data["target_item"] = item

	return data["type"] != "skill"

func drop_data(position,data):
	displayQuantity()

	var origin_node = data["origin_node"]

	if origin_node == self:
		return

	var origin_icon = origin_node.get_node("Slot")

	var dragPreview = origin_node.get_node_or_null("Sprite")

	if dragPreview:
		dragPreview.queue_free()

	var origin_texture = data["origin_texture"]
	var origin_item = data["origin_item"]
	var origin_quantity = data["origin_quantity"]

	var target_texture = icon.texture
	var target_item = item
	var target_quantity = quantity

	if origin_texture == null:
		return

	if (
		origin_item == target_item
		and origin_texture == target_texture
		and stackable
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
		origin_icon.texture = target_texture
		icon.texture = origin_texture

		origin_node.item = target_item
		item = origin_item

		origin_node.quantity = target_quantity
		quantity = origin_quantity

	displayQuantity()
	origin_node.displayQuantity()

	inventory.saveData()
