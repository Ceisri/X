extends TextureButton


onready var icon = get_node_or_null("Slot")

var quantity = 0 
var type = "item"
var stackable = false
var max_quantity = 9999999999




func get_drag_data(position:Vector2):
	if !icon or icon.texture==null:
		return null

	var preview=TextureRect.new()
	preview.texture=icon.texture
	preview.rect_size=Vector2(64,64)
	set_drag_preview(preview)

	return {
		"origin_node":self,
		"origin_icon":icon,
		"origin_slot":get_parent().name,
		"origin_texture":icon.texture,
		"origin_quantity":quantity,
		"origin_stackable":stackable,
		"origin_max_quantity":max_quantity,
		"type":type
	}


func can_drop_data(position,data):
	if typeof(data)!=TYPE_DICTIONARY or !data.has("origin_texture") or !data.has("origin_icon"):
		return false

	var origin_texture=data["origin_texture"]

	for armor_name in Global.armors:
		var armor=Global.armors[armor_name]
		if Global.sameIcon(armor["icon"],origin_texture):
			return armor.has("type") and armor["type"]=="feet"

	return false


func drop_data(position,data):
	if typeof(data)!=TYPE_DICTIONARY:return

	var origin_node=data.get("origin_node",null)
	if !is_instance_valid(origin_node) or origin_node==self:return

	var origin_icon=data.get("origin_icon",null)
	if origin_icon==null:return

	var origin_texture=data.get("origin_texture",null)
	if origin_texture==null:return

	var from_skill_tree=data.get("origin_is_from_skill_tree",false)

	var origin_quantity=data.get("origin_quantity",0)
	var origin_stackable=data.get("origin_stackable",false)
	var origin_max_quantity=data.get("origin_max_quantity",9999999999)

	var target_texture=icon.texture

	if !from_skill_tree and origin_texture==target_texture and stackable and origin_stackable:
		var total=quantity+origin_quantity

		if total<=max_quantity:
			quantity=total
			if "quantity" in origin_node:origin_node.quantity=0
			origin_icon.texture=null
		else:
			quantity=max_quantity
			if "quantity" in origin_node:origin_node.quantity=total-max_quantity
	else:
		icon.texture=origin_texture

		if !from_skill_tree:
			origin_icon.texture=target_texture

			var temp_qty=quantity
			quantity=origin_quantity
			if "quantity" in origin_node:origin_node.quantity=temp_qty

			var temp_stack=stackable
			stackable=origin_stackable
			if "stackable" in origin_node:origin_node.stackable=temp_stack

			var temp_max=max_quantity
			max_quantity=origin_max_quantity
			if "max_quantity" in origin_node:origin_node.max_quantity=temp_max



	if !from_skill_tree and origin_node.has_method("displayQuantity"):
		origin_node.displayQuantity()
