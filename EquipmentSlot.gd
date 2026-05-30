extends TextureButton

onready var icon = $Slot

var quantity = 0
var type = "item"
var stackable = false
var max_quantity = 1
func get_drag_data(position:Vector2):
	var parent_slot = get_parent().get_name()

	return {
		"origin_node": self,
		"origin_slot": parent_slot,
		"origin_texture": icon.texture,
		"origin_quantity": 1,
		"origin_stackable": false,
		"origin_max_quantity": 1,
		"type": type
	}

func can_drop_data(position,data):
	if typeof(data) != TYPE_DICTIONARY:
		return false

	data["target_texture"] = icon.texture
	data["target_quantity"] = quantity
	return data.get("type","") != "skill"
func drop_data(position,data):
	var origin_node = data.get("origin_node", null)
	if not is_instance_valid(origin_node):
		return

	if origin_node == self:
		return

	var origin_icon = origin_node.get_node_or_null("Slot")
	if not origin_icon:
		return

	var origin_texture = data.get("origin_texture", null)
	if origin_texture == null:
		return

	var tmp_texture = icon.texture
	icon.texture = origin_texture
	origin_icon.texture = tmp_texture

	# NEVER destroy or overwrite inventory values here
	# only visuals for equipment

	if "quantity" in origin_node:
		origin_node.quantity = data.get("origin_quantity", 1)

	quantity = 1
