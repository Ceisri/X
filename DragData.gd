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
	if data == null:
		print("Drop rejected: data is null")
		return false

	if !data.has("origin_node"):
		print("Drop rejected: missing origin_node")
		return false

	if !data.has("origin_texture"):
		print("Drop rejected: missing origin_texture")
		return false

	data["target_texture"] = icon.texture
	data["target_quantity"] = quantity
	data["target_item"] = item

	return true


func drop_data(position, data):

	if data == null:
		print("Drop failed: data is null")
		return

	if !data.has("origin_texture"):
		print("Drop failed: missing origin_texture")
		return

	if !data.has("origin_node"):
		print("Drop failed: missing origin_node")
		return

	var origin_node = data["origin_node"]

	if origin_node == null:
		print("Drop failed: origin_node is null")
		return

	if !is_instance_valid(origin_node):
		print("Drop failed: origin_node is invalid")
		return

	var origin_texture = data["origin_texture"]

	if origin_texture == null:
		print("Drop failed: origin_texture is null")
		return

	var target_texture = icon.texture

	var origin_quantity = 1

	if data.has("origin_quantity"):
		origin_quantity = int(data["origin_quantity"])

	var origin_icon = origin_node.get_node_or_null("Slot")

	if origin_icon == null:
		print("Drop failed: origin Slot node missing")
		return

	if !is_instance_valid(origin_icon):
		print("Drop failed: origin Slot node invalid")
		return

	var source_is_skill_tree = false

	if "is_from_skill_tree" in origin_node:
		source_is_skill_tree = origin_node.is_from_skill_tree

	# Same texture dropped onto same slot
	if origin_texture == target_texture:

		if source_is_skill_tree:
			print("Ignored duplicate skill-tree drop")
			return

		quantity += origin_quantity

		if "quantity" in origin_node:
			origin_node.quantity = 0

		if "item" in origin_node:
			origin_node.item = "null"

		origin_icon.texture = null

		if origin_icon.has_node("CD"):
			var cd = origin_icon.get_node_or_null("CD")
			if cd:
				cd.text = ""

		return

	# Skill tree -> skill bar = copy
	if source_is_skill_tree:

		icon.texture = origin_texture

		if data.has("origin_item"):
			item = data["origin_item"]

		if data.has("type"):
			type = data["type"]

		print("Skill copied from skill tree")
		return

	# Inventory/skillbar swap
	var temp_texture = icon.texture
	var temp_quantity = quantity
	var temp_item = item

	icon.texture = origin_texture
	quantity = origin_quantity

	if data.has("origin_item"):
		item = data["origin_item"]

	origin_icon.texture = temp_texture

	if "quantity" in origin_node:
		origin_node.quantity = temp_quantity

	if "item" in origin_node:
		origin_node.item = temp_item

	if origin_icon.texture == null:

		if "quantity" in origin_node:
			origin_node.quantity = 0

		if "item" in origin_node:
			origin_node.item = "null"

		if origin_icon.has_node("CD"):
			var cd = origin_icon.get_node_or_null("CD")
			if cd:
				cd.text = ""

	if icon.texture == null:

		quantity = 0
		item = "null"

		if icon.has_node("CD"):
			var cd = icon.get_node_or_null("CD")
			if cd:
				cd.text = ""
