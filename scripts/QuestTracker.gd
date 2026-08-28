extends Control

onready var bg = $Bg
onready var tween = $Tween
onready var grid = $ScrollContainer/GridContainer


func _ready() -> void:
	# Make sure this Control actually receives mouse events.
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Children should NOT steal the mouse events from this Control.
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	bg.modulate.a = 0.0
	grid.modulate.a = 0.5


func _on_mouse_entered() -> void:
	tween.stop_all()

	tween.interpolate_property(
		bg,
		"modulate:a",
		bg.modulate.a,
		1.0,
		0.2,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)

	tween.interpolate_property(
		grid,
		"modulate:a",
		grid.modulate.a,
		1.0,
		0.2,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)

	tween.start()


func _on_mouse_exited() -> void:
	tween.stop_all()

	tween.interpolate_property(
		bg,
		"modulate:a",
		bg.modulate.a,
		0.0,
		0.2,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)

	tween.interpolate_property(
		grid,
		"modulate:a",
		grid.modulate.a,
		0.5,
		0.2,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)

	tween.start()
