extends TextureButton
onready var icon = $Slot
onready var parent = $"../../../.."
var quantity = 0
var item = "null"
var type = "item"
var skill_tree = false
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
	var origin_texture = data["origin_texture"]
	var target_texture = icon.texture

	var origin_quantity = data["origin_quantity"]

	var origin_node = data["origin_node"]
	var origin_icon = origin_node.get_node("Slot")

	icon.texture = origin_texture

	if origin_texture == target_texture:
		quantity += origin_quantity

		origin_node.quantity = 0
		origin_node.item = "null"

		origin_icon.texture = null

		if origin_icon.has_node("CD"):
			origin_icon.get_node("CD").text = ""

	else:
		if origin_node.skill_tree == false:
			var temp_quantity = quantity

			quantity = origin_quantity
			origin_node.quantity = temp_quantity

			origin_icon.texture = target_texture

			if origin_icon.texture == null:
				origin_node.quantity = 0
				origin_node.item = "null"

				if origin_icon.has_node("CD"):
					origin_icon.get_node("CD").text = ""

			if icon.texture == null:
				quantity = 0
				item = "null"

				if icon.has_node("CD"):
					icon.get_node("CD").text = ""
