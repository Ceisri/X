extends TextureButton
# Trash slot (destroys items on drop except skills)

func _can_drop_data(position, data):
	if typeof(data) != TYPE_DICTIONARY:
		return false

	if not data.has("origin_node"):
		return false

	# only block if explicitly a skill
	if data.has("type") and data["type"] == "skill":
		return false

	return true

func _drop_data(position, data):
	if typeof(data) != TYPE_DICTIONARY:
		return

	var origin_node = data.get("origin_node", null)
	if origin_node == null or not is_instance_valid(origin_node):
		print("Trash: invalid origin node")
		return

	# block skills here too (extra safety)
	if data.has("type") and data["type"] == "skill":
		print("Trash: ignored skill item")
		return

	var origin_icon = origin_node.get_node_or_null("Slot")
	if origin_icon == null:
		print("Trash: missing Slot node")
		return

	origin_icon.texture = null

	if "quantity" in origin_node:
		origin_node.quantity = 0

	if origin_node.has_method("displayQuantity"):
		origin_node.displayQuantity()

	var drag_preview = origin_node.get_node_or_null("Sprite")
	if drag_preview:
		drag_preview.queue_free()
