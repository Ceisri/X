extends Control

var drag_target = null
var drag_offset = Vector2()
var can_move_ui:bool = false
onready var move_ui_button:Button = $moveUI

onready var ui_nodes = [
	$"../Menu",
	$"../Minimap",
	$"../SkillTreeRoot",
	$"../CrossairInspect",
	$"../Equipment",
	$"../Loot",
	$"../Inventory",
	$"../Skillbar"
]

func _ready():
	move_ui_button.connect("pressed",self,"enable")
	for n in ui_nodes:
		n.mouse_filter = Control.MOUSE_FILTER_STOP
	loadData()

func enable()->void:
	can_move_ui = !can_move_ui
func _input(event):
	if can_move_ui == true:
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
			if event.pressed:
				var clicked = _get_top_control_under_mouse()
				if clicked:
					drag_target = clicked
					drag_offset = drag_target.rect_global_position - get_global_mouse_position()
			else:
				drag_target = null

		elif event is InputEventMouseMotion and drag_target:
			drag_target.rect_global_position = get_global_mouse_position() + drag_offset

func _get_top_control_under_mouse():
	var mouse_pos = get_global_mouse_position()
	for n in ui_nodes:
		if n.get_global_rect().has_point(mouse_pos):
			return n
	return null
func saveData():
	var data = {}
	for n in ui_nodes:
		data[n.name] = n.rect_position

	var file = File.new()
	file.open("user://ui_layout.save", File.WRITE)
	file.store_var(data)
	file.close()

func loadData():
	var file = File.new()
	if not file.file_exists("user://ui_layout.save"):
		return

	file.open("user://ui_layout.save", File.READ)
	var data = file.get_var()
	file.close()

	for n in ui_nodes:
		if data.has(n.name):
			n.rect_position = data[n.name]
