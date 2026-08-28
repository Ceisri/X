extends TextureButton
onready var icon = get_parent().get_node("Slot")
onready var parent = $"../../../../.."
var quantity = 1
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
	return true

func drop_data(p,d):
	if typeof(d)!=TYPE_DICTIONARY or !d.has("origin_texture"):return
	var o=d.get("origin_node");if o==self:return
	var oi=d.get("origin_icon")
	var from_skill_tree=d.get("origin_is_from_skill_tree",false)

	var tt=icon.texture
	var tq=quantity
	var ti=item
	var ty=type
	var ts=stackable
	var tm=max_quantity

	icon.texture=d["origin_texture"]
	quantity=d.get("origin_quantity",1)
	item=d.get("origin_item","null")
	type=d.get("type","item")
	stackable=d.get("origin_stackable",true)
	max_quantity=d.get("origin_max_quantity",9999999999)

	if oi and !from_skill_tree:
		oi.texture=tt

	if o and !from_skill_tree:
		if "quantity" in o:o.quantity=tq
		if "item" in o:o.item=ti
		if "type" in o:o.type=ty
		if "stackable" in o:o.stackable=ts
		if "max_quantity" in o:o.max_quantity=tm
		if o.has_method("displayQuantity"):o.displayQuantity()
