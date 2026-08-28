extends MeshInstance

onready var floor_ray: RayCast = $"../DistanceToFloordRay"

export var exclude_body: NodePath
export var floor_collision_mask: int = 1        # set to your ground-only physics layer
export var min_y_tolerance: float = 0.05
export var max_y_tolerance: float = 0.35
export var position_lerp_speed: float = 15.0     # kills the "flies behind you" snapping
export var max_snap_distance: float = 2.0        # beyond this, teleport instead of lerp
export var min_up_dot: float = 0.3               # ignore near-vertical hits (walls)

var _decal_scale: Vector3
var _mat: ShaderMaterial

func _ready():
	_decal_scale = scale
	_mat = get_surface_material(0) as ShaderMaterial

	floor_ray.collision_mask = floor_collision_mask

	# Exclude the exported body AND everything in the "player" group —
	# a single exception on the ray only covers one collider; if the
	# character has separate hitbox/hurtbox/ragdoll shapes any one of
	# them left un-excepted is enough to cause the "shadow on player" /
	# "shadow flying off" bugs, since the ray then reports a hit point
	# on the character instead of the ground.
	if exclude_body != NodePath():
		var body = get_node(exclude_body)
		if body:
			floor_ray.add_exception(body)
	for n in get_tree().get_nodes_in_group("player"):
		floor_ray.add_exception(n)

func _process(delta):
	if not floor_ray.is_colliding():
		return

	var collider = floor_ray.get_collider()
	if collider and collider.is_in_group("player"):
		return

	var hit_point: Vector3 = floor_ray.get_collision_point()
	var hit_normal: Vector3 = floor_ray.get_collision_normal()

	# Reject near-vertical normals (walls / bad geometry) instead of
	# snapping the decal onto them — this is the other common cause of
	# the shadow "flying behind" the player.
	if hit_normal.dot(Vector3.UP) < min_up_dot:
		return

	# Smooth the position instead of hard-teleporting every frame, unless
	# the jump is large (e.g. actually walking off a ledge), so a single
	# noisy raycast sample doesn't send the decal flying for one frame.
	var dist = global_transform.origin.distance_to(hit_point)
	if dist > max_snap_distance:
		global_transform.origin = hit_point
	else:
		global_transform.origin = global_transform.origin.linear_interpolate(hit_point, clamp(delta * position_lerp_speed, 0.0, 1.0))

	var up = Vector3.UP
	var axis = up.cross(hit_normal)
	var angle = acos(clamp(up.dot(hit_normal), -1.0, 1.0))

	var new_basis: Basis
	if axis.length() > 0.0001:
		new_basis = Basis(axis.normalized(), angle)
	else:
		new_basis = Basis()
	new_basis = new_basis.scaled(_decal_scale)
	global_transform.basis = new_basis

	# Slope-aware tolerance: flat floor -> angle ~0 -> tight tolerance,
	# steep floor -> angle grows -> tolerance grows. Only inflate when the
	# ground actually demands it, instead of permanently.
	if _mat:
		var slope_t = clamp(angle / (PI * 0.5), 0.0, 1.0)
		_mat.set_shader_param("box_half_size_y", lerp(min_y_tolerance, max_y_tolerance, slope_t))
