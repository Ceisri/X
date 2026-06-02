extends CSGMesh

onready var sub = get_node("subtraction")
onready var add = get_node("addition")

var updated_mesh = null

var save_dir = "user://terrain/"
var save_path = ""

func _ready():
	save_path = save_dir+name+".mesh"

	var dir = Directory.new()

	if !dir.dir_exists(save_dir):
		dir.make_dir_recursive(save_dir)

	loadData()

	use_collision = true

func _physics_process(_delta):
	if Engine.get_physics_frames()%160==0:

		if sub.get_child_count()>0 or add.get_child_count()>0:
			update_mesh()

func update_mesh():

	_update_shape()

	var meshes = get_meshes()

	if meshes.size()>1:

		updated_mesh = meshes[1]

		if updated_mesh:

			cleanup_mesh(
				updated_mesh
			)

			mesh = updated_mesh

			saveData()

	for n in sub.get_children():
		n.queue_free()

	for n in add.get_children():
		n.queue_free()





func cleanup_mesh(m):

	if m.get_surface_count() == 0:
		return

	var min_vertices = 15000  # <- tweak this threshold

	var out_mesh = ArrayMesh.new()

	for s in range(m.get_surface_count()):

		var mdt = MeshDataTool.new()
		mdt.create_from_surface(m, s)

		var face_keep = {}
		var face_hash_map = {}

		# -------------------------
		# 1. remove duplicate faces
		# -------------------------
		for f in range(mdt.get_face_count()):

			var ids = [
				mdt.get_face_vertex(f, 0),
				mdt.get_face_vertex(f, 1),
				mdt.get_face_vertex(f, 2)
			]

			ids.sort()
			var key = str(ids[0], "_", ids[1], "_", ids[2])

			if face_hash_map.has(key):
				face_keep[f] = false
				face_keep[face_hash_map[key]] = false
			else:
				face_hash_map[key] = f
				face_keep[f] = true

		# -------------------------
		# 2. build adjacency graph
		# -------------------------
		var vertex_to_faces = {}

		for f in range(mdt.get_face_count()):

			if face_keep.has(f) and face_keep[f] == false:
				continue

			for i in range(3):
				var v = mdt.get_face_vertex(f, i)

				if !vertex_to_faces.has(v):
					vertex_to_faces[v] = []

				vertex_to_faces[v].append(f)

		# -------------------------
		# 3. flood-fill islands
		# -------------------------
		var visited = {}
		var islands = []

		for f in range(mdt.get_face_count()):

			if face_keep.has(f) and face_keep[f] == false:
				continue

			if visited.has(f):
				continue

			var stack = [f]
			var island = []

			while stack.size() > 0:

				var cf = stack.pop_back()

				if visited.has(cf):
					continue

				visited[cf] = true
				island.append(cf)

				for i in range(3):

					var v = mdt.get_face_vertex(cf, i)

					for nf in vertex_to_faces.get(v, []):

						if !visited.has(nf):
							stack.append(nf)

			islands.append(island)

		# -------------------------
		# 4. filter small islands
		# -------------------------
		var valid_faces = {}

		for island in islands:

			if island.size() < min_vertices:
				continue

			for f in island:
				valid_faces[f] = true

		# -------------------------
		# 5. rebuild mesh
		# -------------------------
		var verts = PoolVector3Array()
		var norms = PoolVector3Array()
		var uvs = PoolVector2Array()

		for f in range(mdt.get_face_count()):

			if !valid_faces.has(f):
				continue

			for i in range(3):

				var v = mdt.get_face_vertex(f, i)

				verts.append(mdt.get_vertex(v))
				norms.append(mdt.get_vertex_normal(v))
				uvs.append(mdt.get_vertex_uv(v))

		if verts.size() == 0:
			continue

		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs

		out_mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			arrays
		)

		var mat = m.surface_get_material(s)
		if mat is Material:
			out_mesh.surface_set_material(out_mesh.get_surface_count() - 1, mat)

	# -------------------------
	# 6. commit result safely
	# -------------------------
	if out_mesh.get_surface_count() == 0:
		return

	m.clear_surfaces()

	for s in range(out_mesh.get_surface_count()):

		var arr = out_mesh.surface_get_arrays(s)

		m.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			arr
		)

		var mat = out_mesh.surface_get_material(s)
		if mat is Material:
			m.surface_set_material(s, mat)









func saveData():

	if mesh:

		ResourceSaver.save(
			save_path,
			mesh
		)

func loadData():

	if ResourceLoader.exists(
		save_path
	):

		var loaded = ResourceLoader.load(
			save_path
		)

		if loaded:
			mesh = loaded
