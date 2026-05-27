extends Control

onready var tree =  $".."

var dragging = false
var last_mouse_position = Vector2()

func _process(delta):

	var mouse_position = get_global_mouse_position()

	if Input.is_mouse_button_pressed(BUTTON_LEFT):

		if get_global_rect().has_point(mouse_position):

			if !dragging:
				dragging = true
				last_mouse_position = mouse_position

			var mouse_delta = mouse_position - last_mouse_position

			tree.rect_position += mouse_delta

			last_mouse_position = mouse_position

	else:
		dragging = false
