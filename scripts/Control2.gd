extends Control

onready var label = $Label



onready var UI_node:Node = $".."

var resolutions = [
	Vector2(800, 600),
	Vector2(1024, 768),
	Vector2(1152, 864),
	Vector2(1280, 720),
	Vector2(1280, 800),
	Vector2(1280, 1024),
	Vector2(1360, 768),
	Vector2(1366, 768),
	Vector2(1440, 900),
	Vector2(1600, 900),
	Vector2(1680, 1050),
	Vector2(1920, 1080),

	# 12 more
	Vector2(960, 540),
	Vector2(1024, 576),
	Vector2(1176, 664),
	Vector2(1280, 600),
	Vector2(1400, 900),
	Vector2(1536, 864),
	Vector2(1600, 1024),
	Vector2(1768, 992),
	Vector2(1920, 1200),
	Vector2(2048, 1152),
	Vector2(2560, 1080),
	Vector2(2560, 1440)
]

var selected_resolution := 3

func _ready():
	update_label()


func apply_resolution():
	var r = resolutions[selected_resolution]

	get_tree().set_screen_stretch(
		SceneTree.STRETCH_MODE_2D,
		SceneTree.STRETCH_ASPECT_EXPAND,
		r,
		1
	)

func _on_up_pressed():
	selected_resolution -= 1
	if selected_resolution < 0:
		selected_resolution = resolutions.size() - 1

	update_label()
	apply_resolution()

func _on_down_pressed():
	selected_resolution += 1
	if selected_resolution >= resolutions.size():
		selected_resolution = 0

	update_label()
	apply_resolution()
func update_label():
	var r = resolutions[selected_resolution]
	label.text = str(r.x) + "x" + str(r.y)
