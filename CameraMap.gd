extends Camera

var target
var rotation_speed := 0.005
var yaw := 0.0

func _ready():
	target = $"../../../../.."
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * rotation_speed

func _physics_process(delta) -> void:
	if Engine.get_physics_frames() % 3 == 0:
		global_transform.origin = target.global_transform.origin + Vector3(0, 20, 0)

		# Look straight down
		rotation = Vector3(deg2rad(-90), yaw, 0)
