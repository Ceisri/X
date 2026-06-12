extends Spatial

var player_scene = preload("res://world/player/scenes/PlayerTemplate.tscn")

var auto_save:bool = false

func _ready():
	loadData()
	removeBothersomeKeybinds()
func removeBothersomeKeybinds()-> void:#Here just in case someone is using this as a template
	InputMap.action_erase_events("ui_accept")#avoids all the stupid ways you can click buttons or accept things by mistake
	InputMap.action_erase_events("ui_select")
	InputMap.action_erase_events("ui_focus_next")
	InputMap.action_erase_events("ui_focus_prev")
func _physics_process(delta):
	if Engine.get_physics_frames() %1200 == 0:
		if auto_save:
			saveData()
			saveRecursive(self)
			print("game saved")

	if Input.is_action_just_pressed("savedata"):
		saveData()
		saveRecursive(self)
		print("game saved")

	if Input.is_action_just_pressed("debugmob"):
		saveData()
		saveRecursive(self)
		debugMob()

	if Input.is_action_just_pressed("removemob"):
		saveData()
		saveRecursive(self)
		removeMob()

func saveRecursive(node):
	for child in node.get_children():
		if child.has_method("saveData"):
			child.saveData()
		saveRecursive(child)
		
func debugMob():
	pass
	var scenes = [
		preload("res://world/mobs/wolf/scene/wolf.tscn"),
		preload("res://world/mobs/goat/scene/goat.tscn"),
		preload("res://world/mobs/moose/scene/moose.tscn"),
		preload("res://world/mobs/boar/scene/boar.tscn")

	]

	var scene = scenes[randi() % scenes.size()]
	var mob = CommonBehaviours.spawn(self,scene,Vector3(rand_range(-20,20),0,rand_range(-20,20)))

	mob.rotation.y = deg2rad(rand_range(0,360))
	mob.name = mob.name + "_" + str(OS.get_unix_time())
func removeMob():
	for mob in get_tree().get_nodes_in_group("Entity"):
		if !mob.is_in_group("Player"):
			mob.queue_free()

#__________________________________SAVE_________________________________________

func saveData():
	var saveDirectory = "user://" + name + "/"
	var savePath = saveDirectory + name + ".save"
	var dir = Directory.new()

	if !dir.dir_exists(saveDirectory):
		dir.make_dir_recursive(saveDirectory)

	var entityData = []

	for entity in get_children():
		if is_instance_valid(entity):
			if entity.is_in_group("Entity"):
				entityData.append(buildSaveEntry(entity))

	var file = File.new()

	if file.open(savePath,File.WRITE) == OK:
		file.store_var({"mobs":entityData})
		file.close()

func buildSaveEntry(entity):
	var save_entry = {
		"scene":entity.filename,
		"node_name":entity.name,
		"finished":safeStats(entity,"is_finished",false),
		"position":entity.translation,
		"rotation":entity.rotation,
		"name":safeStats(entity,"Name",""),
		"attributes":safeStats(entity,"attributes",{}).duplicate(true),
		"attribute_points_spent":safeStats(entity,"attribute_points_spent",{}).duplicate(true),
		"available_attribute_points": safeStats(entity,"available_attribute_points",0),
		"nutrition":safeStats(entity,"nutrition",100),
		"health":safeStats(entity,"health",100),
		"is_sitting":safeGet(entity,"is_sitting",false),
		"anim_locks":safeGet(entity,"anim_locks",{}).duplicate(true),
		"aggro_target":getAggroTargetName(entity),
		"aggro":saveAggro(entity)
	}

	if entity.is_in_group("Player"):
		savePlayerData(entity,save_entry)

	return save_entry

func saveAggro(entity):
	var aggro_data = []

	if !entity.has_method("get"):
		return aggro_data

	var target_list = safeGet(entity,"targets",[])

	for aggro_target in target_list:

		if aggro_target == null:
			print("Save error: aggro target null")
			continue

		if aggro_target.target_entity == null:
			print("Save error: target_entity missing")
			continue

		if !is_instance_valid(aggro_target.target_entity):
			print("Save error: invalid target_entity")
			continue

		aggro_data.append({
			"target_name":aggro_target.target_entity.name,
			"aggro":aggro_target.aggro
		})

	return aggro_data

func getAggroTargetName(entity):
	var combat_target = safeGet(entity,"target",null)

	if combat_target == null:
		return ""

	if !is_instance_valid(combat_target):
		print("Save error: invalid combat target")
		return ""

	return combat_target.name

func savePlayerData(entity,save_entry):
	save_entry["camera_position"] = entity.camroot.camera.translation
	save_entry["camera_rotation"] = entity.camroot.camera.rotation
	save_entry["cam_h_position"] = entity.camroot.cam_h.translation
	save_entry["cam_h_rotation"] = entity.camroot.cam_h.rotation
	save_entry["cam_v_position"] = entity.camroot.cam_v.translation
	save_entry["cam_v_rotation"] = entity.camroot.cam_v.rotation
	save_entry["camrot_h"] = entity.camroot.camrot_h
	save_entry["camrot_v"] = entity.camroot.camrot_v
	save_entry["character_rotation"] = entity.character.rotation
	save_entry["direction"] = entity.direction

#__________________________________LOAD_________________________________________

func loadData():
	var saveDirectory = "user://" + name + "/"
	var savePath = saveDirectory + name + ".save"
	var file = File.new()

	if !file.file_exists(savePath):
		CommonBehaviours.spawn(self,player_scene)
		return

	if file.open(savePath,File.READ) != OK:
		CommonBehaviours.spawn(self,player_scene)
		return

	var data = file.get_var()

	file.close()

	if !data.has("mobs"):
		CommonBehaviours.spawn(self,player_scene)
		return

	for entity in get_children():
		if entity.is_in_group("Entity"):
			entity.queue_free()

	var loaded_mobs = []
	var player = null

	for mobData in data["mobs"]:

		if mobData["scene"] == player_scene.resource_path:
			player = loadPlayer(mobData)
			continue

		var mob = loadMob(mobData)

		if mob:
			loaded_mobs.append({
				"mob":mob,
				"aggro":mobData.get("aggro",[]),
				"aggro_target":mobData.get("aggro_target","")
			})

	restoreAggro(loaded_mobs)

	if !player:
		CommonBehaviours.spawn(self,player_scene)


func loadPlayer(mobData):
	var player = CommonBehaviours.spawn(self,player_scene,mobData["position"],mobData["name"],mobData.get("nutrition",100),mobData.get("health",100),mobData.get("finished",false))

	player.name = mobData.get("node_name",player.name)
	player.rotation = mobData.get("rotation",player.rotation)

	player.camroot.camera.translation = mobData.get("camera_position",player.camroot.camera.translation)
	player.camroot.camera.rotation = mobData.get("camera_rotation",player.camroot.camera.rotation)

	player.camroot.cam_h.translation = mobData.get("cam_h_position",player.camroot.cam_h.translation)
	player.camroot.cam_h.rotation = mobData.get("cam_h_rotation",player.camroot.cam_h.rotation)

	player.camroot.cam_v.translation = mobData.get("cam_v_position",player.camroot.cam_v.translation)
	player.camroot.cam_v.rotation = mobData.get("cam_v_rotation",player.camroot.cam_v.rotation)

	player.camroot.camrot_h = mobData.get("camrot_h",player.camroot.camrot_h)
	player.camroot.camrot_v = mobData.get("camrot_v",player.camroot.camrot_v)

	player.character.rotation = mobData.get("character_rotation",player.character.rotation)
	player.direction = mobData.get("direction",Vector3.ZERO)
	var stats = player.get_node_or_null("Stats")
	
	if stats:
		stats.attributes = mobData.get("attributes",stats.attributes)
		stats.attribute_points_spent = mobData.get("attribute_points_spent",stats.attribute_points_spent)
		stats.updateAttributes()
		
		
		stats.available_attribute_points = mobData.get("available_attribute_points",stats.available_attribute_points)
		
	return player


func loadMob(mobData):
	var scene = load(mobData["scene"])
	if scene == null:
		print("Load error: scene missing " + str(mobData["scene"]))
		return null
	var saved_health = mobData.get("health", -1)
	var mob = CommonBehaviours.spawn(self,scene,mobData["position"],mobData["name"],mobData.get("nutrition", 100),saved_health,mobData.get("finished", false))
	if !is_instance_valid(mob):
		print("Load error: failed spawn")
		return null

	mob.name = mobData.get("node_name", mob.name)
	mob.rotation = mobData.get("rotation", mob.rotation)

	if mob.get("is_sitting") != null:
		mob.is_sitting = mobData.get("is_sitting", false)

	if mob.get("anim_locks") != null:
		var saved_locks = mobData.get("anim_locks", {})
		for key in saved_locks:
			if mob.anim_locks.has(key):
				mob.anim_locks[key] = saved_locks[key]
			else:
				print("Load warning: unknown anim lock " + str(key))

	var stats = mob.get_node_or_null("Stats")
	if stats:
		stats.attributes = mobData.get("attributes", stats.attributes)
		stats.attribute_points_spent = mobData.get("attribute_points_spent", stats.attribute_points_spent)
		stats.updateAttributes()

	return mob



func restoreAggro(loaded_mobs):
	for entry in loaded_mobs:

		if !entry.has("mob"):
			print("Load error: missing mob entry")
			continue

		var mob = entry.mob

		if !is_instance_valid(mob):
			print("Load error: invalid mob")
			continue

		restoreCombatTarget(mob,entry.get("aggro_target",""))
		restoreAggroList(mob,entry.get("aggro",[]))

func restoreCombatTarget(mob,target_name):
	if target_name == "":
		return

	for node in get_tree().get_nodes_in_group("Entity"):
		if is_instance_valid(node):
			if node.name == target_name:
				mob.target = node
				return

	print("Load error: combat target missing " + str(target_name))

func restoreAggroList(mob,aggro_list):
	if !mob.has_method("get_or_create_aggro_target"):
		print("Load error: mob missing aggro method")
		return

	for saved_aggro in aggro_list:

		if !saved_aggro.has("target_name"):
			print("Load error: missing target_name")
			continue

		var found = false

		for node in get_tree().get_nodes_in_group("Entity"):

			if !is_instance_valid(node):
				continue

			if node.name == saved_aggro["target_name"]:

				var aggro_target = mob.get_or_create_aggro_target(node)

				if aggro_target == null:
					print("Load error: failed aggro create")
					break

				aggro_target.aggro = saved_aggro.get("aggro",0)

				found = true
				break

		if !found:
			print("Load error: entity missing " + str(saved_aggro["target_name"]))

#________________________________UTILITY________________________________________

func safeGet(obj,property,default_value):
	if obj == null:
		return default_value

	if obj.get(property) != null:
		return obj.get(property)

	return default_value

func safeStats(entity,property,default_value):
	if entity.get("stats") == null:
		return default_value

	if entity.stats.get(property) != null:
		return entity.stats.get(property)

	return default_value

func randomizeName(mobName,stats):
	if mobName == "":
		return stats.Names[randi() % stats.Names.size()]

	return mobName
