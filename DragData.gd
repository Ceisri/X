extends TextureButton
onready var icon = $Slot
onready var parent = $"../../../.."
var quantity = 0
var item = "null"
var type = "item"
var is_from_skill_tree = false
var SAVE_DIR = "user://slots/"


func _physics_process(delta):
	if Engine.get_physics_frames() % 66 == 0:
		if icon.texture == null:
			quantity = 0
			item = "null"

			if icon.has_node("CD"):
				icon.get_node("CD").text = ""
		


func get_drag_data(position: Vector2):
	var slot = get_parent().get_name()
	var data = {
		"origin_node": self,
		"origin_slot": slot,
		"origin_texture": icon.texture,
		"origin_quantity": quantity,
		"origin_item": item,
		"type": type
	}

	print("Item type:", item)

	return data
	

func can_drop_data(position, data):
	var target_slot = get_parent().get_name()
	data["target_texture"] = icon.texture
	data["target_quantity"] = quantity
	data["target_item"] = item

	return true
func drop_data(position,data):

	if !data.has("origin_texture"):
		return

	if !data.has("origin_node"):
		return

	var origin_texture = data["origin_texture"]
	var target_texture = icon.texture

	var origin_quantity = 1

	if data.has("origin_quantity"):
		origin_quantity = data["origin_quantity"]

	var origin_node = data["origin_node"]

	if origin_node == null:
		return

	var origin_icon = origin_node.get_node_or_null("Slot")

	if origin_icon == null:
		return

	icon.texture = origin_texture

	if origin_texture == target_texture:

		if has_method("set"):
			quantity += origin_quantity

		if origin_node.has_method("set"):
			origin_node.quantity = 0
			origin_node.item = "null"

		origin_icon.texture = null

		if origin_icon.has_node("CD"):
			origin_icon.get_node("CD").text = ""

	else:
		

		if origin_node.is_from_skill_tree == false:

			var temp_quantity = quantity

			quantity = origin_quantity

			if origin_node.has_method("set"):
				origin_node.quantity = temp_quantity

			origin_icon.texture = target_texture

			if origin_icon.texture == null:

				if origin_node.has_method("set"):
					origin_node.quantity = 0
					origin_node.item = "null"

				if origin_icon.has_node("CD"):
					origin_icon.get_node("CD").text = ""

			if icon.texture == null:

				quantity = 0
				item = "null"

				if icon.has_node("CD"):
					icon.get_node("CD").text = ""
