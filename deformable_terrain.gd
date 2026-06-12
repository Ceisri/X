extends StaticBody

onready var terrain_mesh = get_parent()

var mesh_data = MeshDataTool.new()

func getDigged(amount,ray):
	if !ray.is_colliding():
		return
	
	var hit_pos = terrain_mesh.to_local(
		ray.get_collision_point()
	)
	
	var radius = 55.0
	
	var old_mesh = terrain_mesh.mesh as ArrayMesh
	
	if old_mesh == null:
		return
	
	var materials = []
	
	for i in range(
		old_mesh.get_surface_count()
	):
		materials.append(
			old_mesh.surface_get_material(i)
		)
	
	mesh_data.clear()
	mesh_data.create_from_surface(
		old_mesh,
		0
	)
	
	for i in range(
		mesh_data.get_vertex_count()
	):
		var v = mesh_data.get_vertex(i)
		
		var dist = v.distance_to(
			hit_pos
		)
		
		if dist < radius:
			var falloff = (
				1.0 -
				(dist/radius)
			)
			
			v.y -= (
				amount *
				falloff
			)
			
			mesh_data.set_vertex(
				i,
				v
			)
	
	var rebuilt = ArrayMesh.new()
	
	mesh_data.commit_to_surface(
		rebuilt
	)
	
	for i in range(
		rebuilt.get_surface_count()
	):
		if i < materials.size():
			rebuilt.surface_set_material(
				i,
				materials[i]
			)
	
	terrain_mesh.mesh = rebuilt
	
	updateCollision()

func updateCollision():
	if has_node(
		"CollisionShape"
	):
		var shape = ConcavePolygonShape.new()
		
		shape.set_faces(
			terrain_mesh.mesh.get_faces()
		)
		
		$CollisionShape.shape = shape
