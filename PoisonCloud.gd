extends MeshInstance

export var ray_height := 2.0
export var ray_depth := 5.0
export var max_height_offset := 1.0
export var collision_mask := 1

func _ready():
	conform_to_terrain()

func conform_to_terrain():
	var arrays = mesh.surface_get_arrays(0)

	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var space = get_world().direct_space_state

	for i in vertices.size():
		var local_v = vertices[i]

		var world_v = global_transform.xform(local_v)

		var from = world_v + Vector3.UP * ray_height
		var to = world_v + Vector3.DOWN * ray_depth

		var exclude = [self]

		while true:
			var hit = space.intersect_ray(from, to, exclude, collision_mask)

			if hit.empty():
				break

			if hit.collider is KinematicBody:
				exclude.append(hit.collider)
				continue

			var local_hit = to_local(hit.position)

			if abs(local_hit.y - local_v.y) > max_height_offset:
				break

			local_v.y = local_hit.y + 0.03

			break

		vertices[i] = local_v

	arrays[Mesh.ARRAY_VERTEX] = vertices

	var new_mesh = ArrayMesh.new()

	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	mesh = new_mesh
