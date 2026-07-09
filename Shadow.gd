extends MeshInstance

onready var floor_ray_cast = $"../ShadowRay"
onready var mat = get_surface_material(0)

func _process(delta):
	rotateShadow()
	moveShadow()

func rotateShadow() -> void:
	var parent = get_parent()
	if parent == null:
		return

	if parent.is_on_floor():
		floor_ray_cast.force_raycast_update()

		if floor_ray_cast.is_colliding():
			var floor_normal = floor_ray_cast.get_collision_normal().normalized()
			if floor_normal.length() < 0.0001:
				return

			var up_dir = Vector3.UP
			var axis = up_dir.cross(floor_normal)

			if axis.length() > 0.0001:
				axis = axis.normalized()
				var angle = acos(clamp(up_dir.dot(floor_normal), -1.0, 1.0))

				var q = Quat(axis, angle)

				var t = global_transform
				t.basis = Basis(q)
				global_transform = t

func moveShadow() -> void:
	if floor_ray_cast.is_colliding():
		var p = floor_ray_cast.get_collision_point()
		var parent = get_parent()

		if parent and not parent.is_on_floor():
			global_transform.origin = p + Vector3(0, 0.1, 0)
		else:
			global_transform.origin = p + Vector3(0, 0.055, 0)
