extends Camera

var target

func _ready():
	target = $"../../../../.."

func _physics_process(delta)->void:
	if Engine.get_physics_frames() % 3 == 0:
		global_transform.origin = target.global_transform.origin + Vector3(0, 20, 0)
