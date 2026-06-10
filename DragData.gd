extends TextureButton
onready var icon = get_parent().get_node("Slot")
onready var parent = $"../../../../.."
var quantity = 0
var max_quantity = 100
var item = "null"
var type = "item"
var stackable = true 
var is_from_skill_tree = false
var SAVE_DIR = "user://slots/"


func _physics_process(delta):
	if Engine.get_physics_frames() % 66 == 0:
		if icon.texture == null:
			quantity = 0
			item = "null"

			if icon.has_node("CD"):
				icon.get_node("CD").text = ""
		


func get_drag_data(position:Vector2):
	if icon.texture==null:
		return null

	var preview=TextureRect.new()
	preview.texture=icon.texture
	preview.rect_size=Vector2(64,64)
	set_drag_preview(preview)

	return {
		"origin_node":self,
		"origin_icon":icon,
		"origin_texture":icon.texture,
		"origin_quantity":quantity,
		"origin_item":item,
		"type":type,
		"origin_stackable":stackable,
		"origin_max_quantity":max_quantity,
		"origin_is_from_skill_tree":is_from_skill_tree
	}

func can_drop_data(position,data):
	if data==null:
		return false

	if !data.has("origin_texture"):
		return false

	return true


func drop_data(position,data):
	if data==null or !data.has("origin_texture"):
		return

	var origin_node=data.get("origin_node",null)
	var origin_icon=data.get("origin_icon",null)

	if origin_icon==null:
		return

	var source_is_skill_tree=data.get("origin_is_from_skill_tree",false)

	if source_is_skill_tree:
		icon.texture=data["origin_texture"]
		item=data.get("origin_item","null")
		type=data.get("type","item")
		return

	if origin_node==self:
		return

	var temp_texture=icon.texture
	var temp_quantity=quantity
	var temp_stackable=stackable
	var temp_max_quantity=max_quantity
	var temp_item=item
	var temp_type=type

	icon.texture=data["origin_texture"]
	quantity=data.get("origin_quantity",0)
	stackable=data.get("origin_stackable",true)
	max_quantity=data.get("origin_max_quantity",9999999999)
	item=data.get("origin_item","null")
	type=data.get("type","item")

	origin_icon.texture=temp_texture

	if origin_node!=null:
		if "quantity" in origin_node:
			origin_node.quantity=temp_quantity
		if "stackable" in origin_node:
			origin_node.stackable=temp_stackable
		if "max_quantity" in origin_node:
			origin_node.max_quantity=temp_max_quantity
		if "item" in origin_node:
			origin_node.item=temp_item
		if "type" in origin_node:
			origin_node.type=temp_type
