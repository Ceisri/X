extends ScrollContainer

onready var player = $"../../.."
onready var stats = $"../../../Stats"
onready var skill_tree = $".."
var dragging := false
var last_pos := Vector2()


var skills = {
	"cleave":0,
	"battlecry":0,
	"onslaught":0,
	"overhead_strike":0
}



func _gui_input(event):

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:

		if event.pressed:
			dragging = true
			last_pos = get_global_mouse_position()
		else:
			dragging = false

	elif event is InputEventMouseMotion and dragging:

		var current = get_global_mouse_position()
		var delta = current - last_pos

		scroll_horizontal -= delta.x
		scroll_vertical -= delta.y

		last_pos = current
