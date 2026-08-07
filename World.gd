extends Spatial #World.gd, script on the scene root of every map including mines and other maps, any map at all really, when entering the game world.tscn is loaded by default and player 
#added here, then the player on ready remebers in what scene he was supposed to be and moves there 
#mobs exist as children of Spawnpoint + mob name or generic Spawnpoints which are spatial
#mobs ar eonly ever spawned as a debug to test bugs example $SpawnpointMoleSpider/NPC10
#each NPC is non local .tscn not editable, with the default configuration of the scene, untouched
var auto_save:bool = false
var selected_player_name:String=  Global.selected_player_name
export(String) var world_id="world"
var skip_offline_autospawn := false


func _ready():
	set_process(false)
	add_to_group("World")
	call_deferred("startWorld")
	removeBothersomeKeybinds()
	hideLoadscreen()
	_rebuildEntityCache()
	if get_tree().network_peer != null:
		if world_id == "world":
			if !Network.is_connected("player_connected", self, "_on_player_connected"):
				Network.connect("player_connected", self, "_on_player_connected")
			if !Network.is_connected("player_disconnected", self, "_on_player_disconnected"):
				Network.connect("player_disconnected", self, "_on_player_disconnected")

			if get_tree().is_network_server():
				if Global.selected_player_name != "":
					var host_world_id = PlayerSpawner._readSavedWorldId(Global.selected_player_name)
					PlayerSpawner.spawnPlayerForPeer(get_tree().get_network_unique_id(), Global.selected_player_name, host_world_id)
			else:
				MobSync.rpc_id(1, "requestFullMobResync")
				PlayerSpawner.sendSpawnRequestOnceConnected(Global.selected_player_name)
				PlayerSpawner.rpc_id(1, "requestFullPlayerResync")

		if !get_tree().is_network_server():
			rpc_id(1, "requestWorldMobSync")
			rpc_id(1, "requestWorldResourceSync")
	else:
		if !skip_offline_autospawn:
			spawnOfflinePlayer()



func spawnOfflinePlayer() -> void:
	if Global.selected_player_name == "":
		push_error("World.gd: Global.selected_player_name is empty, cannot spawn offline player.")
		return

	for child in get_children():
		if child.is_in_group("Player") and "entity_name" in child and child.entity_name == Global.selected_player_name:
			return

	for node in get_tree().get_nodes_in_group("Player"):
		if is_instance_valid(node) and "entity_name" in node and node.entity_name == Global.selected_player_name:
			return

	var player_scene = load("res://world/player/scenes/Player.tscn")
	if player_scene == null:
		push_error("World.gd: failed to load res://world/player/scenes/Player.tscn for offline spawn.")
		return

	var player = player_scene.instance()
	player.entity_name = Global.selected_player_name
	add_child(player)
	loadPlayerData(player, getPlayerSaveBaseDir())

	var state_data = readPlayerStateSave(getPlayerSaveBaseDir() + player.entity_name + "/playerstate.save")

	# Do NOT call applyOwnStateSnapshot() synchronously here. World._ready()
	# is still inside the engine's own enter-tree/ready propagation for this
	# frame, and Player is a KinematicBody -- setting translation on it before
	# the physics server has finished registering the new body gets silently
	# overwritten once the physics server flushes its own (default, 0,0,0)
	# transform later this same frame. This is exactly why the old loadData()
	# path (which ran via call_deferred) worked and this direct call didn't.
	call_deferred("_applyOfflinePlayerState", player, state_data)

func _applyOfflinePlayerState(player:Node, state_data:Dictionary) -> void:
	if !is_instance_valid(player):
		return
	player.applyOwnStateSnapshot(state_data)











remote func requestWorldMobSync() -> void:
	if !get_tree().is_network_server():
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id == 0:
		return
	for mob in getAllEntities():
		if is_instance_valid(mob) and !mob.is_in_group("Player") and mob.has_method("_onPeerConnectedSyncMob"):
			mob._onPeerConnectedSyncMob(sender_id)


		
func _on_player_connected(id:int) -> void:
	if get_tree().is_network_server():
		call_deferred("_deferredOnPlayerConnected", id)

func _deferredOnPlayerConnected(id:int) -> void:
	if !get_tree().is_network_server():
		return
	if !get_tree().get_network_connected_peers().has(id):
		return
	for mob in get_tree().get_nodes_in_group("Entity"):
		if is_instance_valid(mob) and !mob.is_in_group("Player") and mob.has_method("_onPeerConnectedSyncMob"):
			mob._onPeerConnectedSyncMob(id)
	sendGatherableStatesToPeer(id)
	PlayerSpawner.catchUpNewPeer(id)

func _on_player_disconnected(id:int) -> void:
	PlayerSpawner.despawnPlayer(id)

var _gatherable_cache := {}

func _buildGatherableCache() -> void:
	_gatherable_cache.clear()
	for g in get_tree().get_nodes_in_group("Gatherable"):
		if is_instance_valid(g):
			_gatherable_cache[_gatherableKey(g)] = g

func _gatherableKey(g) -> String:
	return str(get_path_to(g))

func sendGatherableStatesToPeer(peer_id:int) -> void:
	if get_tree().network_peer == null or !get_tree().is_network_server():
		return
	_buildGatherableCache()
	var depleted := []
	for key in _gatherable_cache:
		var g = _gatherable_cache[key]
		if is_instance_valid(g) and g.resource_amount <= 0:
			depleted.append(key)
	if !depleted.empty():
		rpc_id(peer_id, "receiveGatherableBatch", depleted)

remote func requestWorldResourceSync() -> void:
	if !get_tree().is_network_server():
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id == 0:
		return
	sendGatherableStatesToPeer(sender_id)

remote func receiveGatherableBatch(depleted_paths:Array) -> void:
	if get_tree().is_network_server():
		return
	if _gatherable_cache.empty():
		_buildGatherableCache()
	for key in depleted_paths:
		var g = _gatherable_cache.get(key)
		if is_instance_valid(g):
			g._applyDeplete()
remote func requestGatherAt(path:NodePath) -> void:
	if !get_tree().is_network_server():
		return
	var g = get_node_or_null(path)
	if is_instance_valid(g) and g.is_in_group("Gatherable"):
		g._serverGather()

remote func remoteGatherableDeplete(path:NodePath) -> void:
	var g = get_node_or_null(path)
	if is_instance_valid(g):
		g._applyDeplete()

remote func remoteGatherableRespawn(path:NodePath) -> void:
	var g = get_node_or_null(path)
	if is_instance_valid(g):
		g._applyRespawn()

func removeBothersomeKeybinds()-> void:
	InputMap.action_erase_events("ui_accept")
	InputMap.action_erase_events("ui_select")
	InputMap.action_erase_events("ui_focus_next")
	InputMap.action_erase_events("ui_focus_prev")

func startWorld():
	while !is_instance_valid(get_node_or_null("/root/Skills")) or Skills.skills.size()==0:
		yield(get_tree(),"idle_frame")
	cacheSpawnpoints()
	getNearestSpawnpoint()
	if get_tree().network_peer == null or get_tree().is_network_server():
		call_deferred("loadData")



#func loadData():
#	if !is_inside_tree():
#		return
#	if get_tree().network_peer != null and !get_tree().is_network_server():
#		return
#	loadResourceStatesFile()
#	applyResourceStates()
#	var savePath = "user://" + name + "/" + name + ".save"
#	var file = File.new()
#	if !file.file_exists(savePath):
#		return
#	if file.open(savePath, File.READ) != OK:
#		return
#	var data = file.get_var()
#	file.close()
#	if typeof(data) != TYPE_DICTIONARY or !data.has("mobs"):
#		return
#
#	var loaded_mobs := []  # NEW
#
#	for mob_data in data["mobs"]:
#		if mob_data.get("world_id", world_id) != world_id:
#			continue
#		var mob = loadMob(mob_data)
#		if mob != null:
#			loaded_mobs.append({
#				"mob": mob,
#				"creator": mob_data.get("creator", ""),
#				"spawned_bodies": mob_data.get("spawned_bodies", []),
#				"aggro_target": mob_data.get("aggro_target", ""),
#				"aggro": mob_data.get("aggro", [])
#			})
#
#	if !loaded_mobs.empty():          # NEW -- these were dead code before
#		restoreCreators(loaded_mobs)
#		restoreAggro(loaded_mobs)
func loadData():
	if !is_inside_tree():
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return
	loadResourceStatesFile()
	applyResourceStates()

	var saveDirectory = getMobSaveBaseDir() + world_id + "/"
	var savePath = saveDirectory + world_id + ".save"
	var file = File.new()
	if !file.file_exists(savePath):
		return
	if file.open(savePath, File.READ) != OK:
		return
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY or !data.has("mobs"):
		return

	var loaded_mobs := []

	for mob_data in data["mobs"]:
		if mob_data.get("world_id", world_id) != world_id:
			continue
		var mob = loadMob(mob_data)
		if mob != null:
			loaded_mobs.append({
				"mob": mob,
				"creator": mob_data.get("creator", ""),
				"spawned_bodies": mob_data.get("spawned_bodies", []),
				"aggro_target": mob_data.get("aggro_target", ""),
				"aggro": mob_data.get("aggro", [])
			})

	if !loaded_mobs.empty():
		restoreCreators(loaded_mobs)
		if get_tree().network_peer == null:
			restoreAggro(loaded_mobs)



var collidable_shapes := []

func cacheCollidableShapes() -> void:
	collidable_shapes.clear()
	_collectCollidableShapes(self)

func _collectCollidableShapes(node) -> void:
	for child in node.get_children():
		if !is_instance_valid(child):
			continue

		if _isLandscapeNode(child):
			continue

		if child is CollisionShape:
			var owner_node = child.get_parent()
			if is_instance_valid(owner_node) and owner_node is StaticBody:
				collidable_shapes.append(child)

		_collectCollidableShapes(child)

func _isLandscapeNode(node) -> bool:
	if node.name.to_lower().find("landscape") != -1:
		return true

	var holder = get_node_or_null("LandscapeHolder")
	if holder != null:
		var current = node
		while current != null and current != self:
			if current == holder:
				return true
			current = current.get_parent()

	return false


export var collision_disable_distance := 60.0
var collision_disable_distance_sq := collision_disable_distance * collision_disable_distance

func disableCollisionsRecursive() -> void:
	var players = []
	for child in get_children():
		if is_instance_valid(child) and child.is_in_group("Player"):
			players.append(child)

	for shape in collidable_shapes:
		if !is_instance_valid(shape):
			continue

		var owner_node = shape.get_parent()
		if owner_node == null or !is_instance_valid(owner_node):
			continue

		var owner_origin = owner_node.global_transform.origin

		var nearest_distance_sq = INF
		for player in players:
			if !is_instance_valid(player):
				continue
			var distance_sq = owner_origin.distance_squared_to(player.global_transform.origin)
			if distance_sq < nearest_distance_sq:
				nearest_distance_sq = distance_sq

		var should_disable = nearest_distance_sq > collision_disable_distance_sq

		if should_disable == shape.disabled:
			continue

		shape.disabled = should_disable
export var autosave_interval:int = 666
var _entity_cache := []

func getCachedEntities() -> Array:
	return _entity_cache



func _rebuildEntityCache() -> void:
	var fresh = getAllEntities()
	_entity_cache.resize(0)
	for e in fresh:
		_entity_cache.append(e)

func _physics_process(delta):
	if get_tree().network_peer == null or get_tree().is_network_server():
		auto_save = true

	if Engine.get_physics_frames() %30 == 0:
		disableCollisionsRecursive()
	if Engine.get_physics_frames() %autosave_interval== 0:
		if auto_save:
			saveData()
			saveRecursive(self)

	if Input.is_action_just_pressed("savedata"):
		saveData()
		saveRecursive(self)


var cached_saveable_nodes := []
var _scanned_child_count := {}

func saveRecursive(node):
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return
	_scanSaveableNodes(node)

	for saveable in cached_saveable_nodes:
		if is_instance_valid(saveable):
			saveable.saveData()

func _scanSaveableNodes(node) -> void:
	if node is Occluder:
		return

	if _isUnderLandscapeHolder(node):
		return

	var id = node.get_instance_id()
	var current_child_count = node.get_child_count()

	if _scanned_child_count.has(id) and _scanned_child_count[id] == current_child_count:
		return

	_scanned_child_count[id] = current_child_count

	if node.has_method("saveData") and !cached_saveable_nodes.has(node):
		cached_saveable_nodes.append(node)

	for child in node.get_children():
		if is_instance_valid(child):
			_scanSaveableNodes(child)

func _isUnderLandscapeHolder(node) -> bool:
	var holder = get_node_or_null("LandscapeHolder")
	if holder == null:
		return false

	var current = node
	while current != null and current != self:
		if current == holder:
			return true
		current = current.get_parent()

	return false

var cached_spawnpoints = []

func cacheSpawnpoints()->void:
	cached_spawnpoints.clear()
	for sp in get_tree().get_nodes_in_group("Spawnpoint"):
		if is_instance_valid(sp) and isUnderThisWorld(sp):
			cached_spawnpoints.append(sp)

func isUnderThisWorld(node) -> bool:
	var n = node
	while n:
		if n == self:
			return true
		n = n.get_parent()
	return false
func getNearestSpawnpoint():
	var nearest_spawn = null
	var nearest_distance = INF

	for spawnpoint in cached_spawnpoints:
		if !is_instance_valid(spawnpoint):
			continue

		var distance = global_transform.origin.distance_squared_to(spawnpoint.global_transform.origin)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_spawn = spawnpoint

	return nearest_spawn


func pickSpawnpointForKeywords(spawn_points:Array, keywords:Array):
	for keyword in keywords:
		var matches=[]
		for spawn_point in spawn_points:
			if spawn_point.name.to_lower().find(keyword.to_lower())!=-1:
				matches.append(spawn_point)
		if !matches.empty():
			return matches[randi()%matches.size()]

	return spawn_points[randi()%spawn_points.size()]


#__________________________________SAVE_________________________________________

func getAllEntities(node=null)->Array:
	if node == null:
		node = self

	var entities=[]
	for child in node.get_children():
		if !is_instance_valid(child):
			continue
		if child.is_in_group("Entity"):
			entities.append(child)
		else:
			entities += getAllEntities(child)
	return entities


func saveData():
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return
	print("world.gd saved data")
	var saveDirectory = getMobSaveBaseDir() + world_id + "/"
	var savePath = saveDirectory + world_id + ".save"
	var dir = Directory.new()

	if !dir.dir_exists(saveDirectory):
		dir.make_dir_recursive(saveDirectory)

	var old_data = {}
	var old_file = File.new()

	if old_file.file_exists(savePath) and old_file.open(savePath, File.READ) == OK:
		old_data = old_file.get_var()
		old_file.close()

	var entityData = []

	for entity in getAllEntities():
		if is_instance_valid(entity) and !entity.is_in_group("Player"):
			var entry = buildSaveEntry(entity)
			entry["world_id"] = world_id
			entityData.append(entry)

	old_data["mobs"] = entityData

	var file = File.new()
	if file.open(savePath, File.WRITE) == OK:
		file.store_var(old_data)
		file.close()
	saveResourceStates()
	savePlayers()







var player_spawn_times := {} # peer_id or entity_name -> time spawned

func savePlayers() -> void:
	var players := findPlayersToSave()
	if players.empty():
		return

	var base_dir := getPlayerSaveBaseDir()

	for player in players:
		if !is_instance_valid(player):
			continue
		
		# Only save if UI is fully loaded
		var ui = player.get_node_or_null("UI")
		if !is_instance_valid(ui):
			continue
		var equipment = ui.get_node_or_null("Equipment")
		var inventory = ui.get_node_or_null("Inventory")
		if !is_instance_valid(equipment) or !is_instance_valid(inventory):
			continue

		savePlayerData(player, base_dir)



func findPlayersToSave() -> Array:
	var players := []

	if get_tree().network_peer != null:
		for node in get_tree().get_nodes_in_group("Player"):
			if is_instance_valid(node):
				players.append(node)
		return players

	var direct = get_node_or_null("Player")
	if is_instance_valid(direct):
		players.append(direct)
		return players

	push_error("World.gd findPlayersToSave(): 'Player' not found as direct child, doing recursive search.")

	var found = findNodeByName("Player")
	if is_instance_valid(found):
		players.append(found)
	else:
		push_error("World.gd findPlayersToSave(): no Player node found in tree.")

	return players


func getPlayerSaveBaseDir() -> String:
	if get_tree().network_peer == null:
		return "user://PlayerSaves/Offline/"
	return "user://PlayerSaves/Server_" + getServerAddressId() + "/"


func getServerAddressId() -> String:
	var raw := ""
	if get_tree().is_network_server():
		raw = "host_" + str(Network.DEFAULT_PORT)
	else:
		raw = Network.last_ip + "_" + str(Network.last_port)
	if raw.strip_edges() == "":
		raw = "unknown_server"
	return raw.replace(":", "_").replace("/", "_").replace("\\", "_").replace(".", "_")





func savePlayerData(player:Node, base_dir:String) -> void:
	if !("entity_name" in player) or player.entity_name == "":
		push_error("World.gd savePlayerData(): player has no entity_name, skipping.")
		return

	var ui = player.get_node_or_null("UI")
	if ui == null:
		push_error("World.gd savePlayerData(): 'UI' not found as direct child of " + player.name)
		return

	var player_dir = base_dir + player.entity_name + "/"
	var dir := Directory.new()
	if !dir.dir_exists(player_dir):
		dir.make_dir_recursive(player_dir)

	var is_remote_player = get_tree().network_peer != null and player.get_network_master() != get_tree().get_network_unique_id()
	if is_remote_player:
		var snapshot = PlayerSpawner.equipment_cache.get(player.entity_name, {})
		saveEquipmentFromSnapshot(snapshot, player_dir)
	else:
		var equipment = ui.get_node_or_null("Equipment")
		if is_instance_valid(equipment):
			saveEquipmentTo(equipment, player_dir)
		else:
			push_error("World.gd savePlayerData(): 'UI/Equipment' not found for " + player.entity_name)

	savePlayerStateTo(player, player_dir)


	var inventory = ui.get_node_or_null("Inventory")
	if !is_instance_valid(inventory):
		push_error("World.gd savePlayerData(): 'UI/Inventory' not found for " + player.entity_name)
		return

	if is_remote_player:
		inventory.rpc_id(player.get_network_master(), "requestSelfSaveInventory")
	else:
		saveInventoryTo(inventory, player_dir)

	var skillbar_node = ui.get_node_or_null("Skillbar")
	if is_instance_valid(skillbar_node):
		if is_remote_player:
			skillbar_node.rpc_id(player.get_network_master(), "requestSelfSaveSkillbar")
		else:
			saveSkillbarTo(skillbar_node, player_dir)

	if is_remote_player:
		inventory.rpc_id(player.get_network_master(), "requestSelfSaveInventory")
	else:
		saveInventoryTo(inventory, player_dir)

	var stats_node = player.get_node_or_null("Stats")
	if is_instance_valid(stats_node):
		if is_remote_player:
			stats_node.rpc_id(player.get_network_master(), "requestSelfSaveStats")
		else:
			saveStatsTo(stats_node, player_dir)


func saveSkillbarFor(player:Node, data:Dictionary) -> void:
	if !is_instance_valid(player) or !("entity_name" in player) or player.entity_name == "":
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		rpc_id(1, "requestSaveSkillbar", player.entity_name, data)
		return
	_writeSkillbarToDir(getPlayerSaveBaseDir() + player.entity_name + "/", data)

remote func requestSaveSkillbar(entity_name:String, data:Dictionary) -> void:
	if !get_tree().is_network_server():
		return
	_writeSkillbarToDir(getPlayerSaveBaseDir() + entity_name + "/", data)

func _writeSkillbarToDir(player_dir:String, data:Dictionary) -> void:
	var dir := Directory.new()
	if !dir.dir_exists(player_dir):
		dir.make_dir_recursive(player_dir)
	var file := File.new()
	if file.open(player_dir + "skillbar.save", File.WRITE) == OK:
		file.store_var(data)
		file.close()

func readSkillbarSave(path:String) -> Dictionary:
	var file := File.new()
	if !file.file_exists(path):
		return {}
	if file.open(path, File.READ) != OK:
		return {}
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data

func saveSkillbarTo(skillbar_node:Node, player_dir:String) -> void:
	if !is_instance_valid(skillbar_node) or !skillbar_node.has_method("gatherSkillbarSnapshot"):
		return
	_writeSkillbarToDir(player_dir, skillbar_node.gatherSkillbarSnapshot())






















func saveEquipmentFromSnapshot(snapshot:Dictionary, player_dir:String) -> void:
	if snapshot.empty():
		return
	var rings = snapshot.get("rings", ["","","","","","","",""])
	var data := {
		"Torso": snapshot.get("torso",""),
		"Hands": snapshot.get("hands",""),
		"Feet": snapshot.get("feet",""),
		"MainHand": snapshot.get("mainhand",""),
		"OffHand": snapshot.get("offhand",""),
		"Necklace": snapshot.get("necklace",""),
		"Ring": rings[0], "Ring2": rings[1], "Ring3": rings[2], "Ring4": rings[3],
		"Ring5": rings[4], "Ring6": rings[5], "Ring7": rings[6], "Ring8": rings[7]
	}
	var save_path := player_dir + "equipment.save"
	var file := File.new()
	if file.open(save_path, File.WRITE) == OK:
		file.store_var(data)
		file.close()

func saveInventoryTo(inventory:Node, player_dir:String) -> void:
	if !is_instance_valid(inventory):
		return

	var data := {
		"visible": inventory.visible,
		"coins": inventory.coins,
		"max_inventory_slots": inventory.max_inventory_slots,
		"slots": {}
	}

	for child in inventory.inventory_grid.get_children():
		var slot = child.get_node("Slot")
		data["slots"][child.name] = {
			"texture": slot.texture.resource_path if slot.texture != null else "",
			"quantity": child.quantity,
			"stackable": child.stackable,
			"max_quantity": child.max_quantity
		}

	var save_path := player_dir + "inventory.save"
	var file := File.new()
	if file.open(save_path, File.WRITE) == OK:
		file.store_var(data)
		file.close()


func readInventorySave(path:String) -> Dictionary:
	var file := File.new()
	if !file.file_exists(path):
		return {}
	if file.open(path, File.READ) != OK:
		return {}
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


func saveInventoryFor(player:Node, data:Dictionary) -> void:
	if !is_instance_valid(player) or !("entity_name" in player) or player.entity_name == "":
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		rpc_id(1, "requestSaveInventory", player.entity_name, data)
		return
	_writeInventoryToDir(getPlayerSaveBaseDir() + player.entity_name + "/", data)

remote func requestSaveInventory(entity_name:String, data:Dictionary) -> void:
	if !get_tree().is_network_server():
		return
	_writeInventoryToDir(getPlayerSaveBaseDir() + entity_name + "/", data)

func _writeInventoryToDir(player_dir:String, data:Dictionary) -> void:
	var dir := Directory.new()
	if !dir.dir_exists(player_dir):
		dir.make_dir_recursive(player_dir)
	var file := File.new()
	if file.open(player_dir + "inventory.save", File.WRITE) == OK:
		file.store_var(data)
		file.close()




func saveStatsFor(player:Node, data:Dictionary) -> void:
	if !is_instance_valid(player) or !("entity_name" in player) or player.entity_name == "":
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		rpc_id(1, "requestSaveStats", player.entity_name, data)
		return
	_writeStatsToDir(getPlayerSaveBaseDir() + player.entity_name + "/", data)

remote func requestSaveStats(entity_name:String, data:Dictionary) -> void:
	if !get_tree().is_network_server():
		return
	_writeStatsToDir(getPlayerSaveBaseDir() + entity_name + "/", data)

func _writeStatsToDir(player_dir:String, data:Dictionary) -> void:
	var dir := Directory.new()
	if !dir.dir_exists(player_dir):
		dir.make_dir_recursive(player_dir)
	var file := File.new()
	if file.open(player_dir + "playerstats.save", File.WRITE) == OK:
		file.store_var(data)
		file.close()

func readStatsSave(path:String) -> Dictionary:
	var file := File.new()
	if !file.file_exists(path):
		return {}
	if file.open(path, File.READ) != OK:
		return {}
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data

func saveStatsTo(stats_node:Node, player_dir:String) -> void:
	if !is_instance_valid(stats_node) or !stats_node.has_method("gatherStatsSnapshot"):
		return
	if "_post_load_guard" in stats_node and stats_node._post_load_guard:
		return
	_writeStatsToDir(player_dir, stats_node.gatherStatsSnapshot())



func savePlayerStateTo(player:Node, player_dir:String) -> void:
	if !is_instance_valid(player):
		return

	var data := {
		"position": player.translation,
		"rotation": player.rotation,
		"world_id": world_id
	}
	if "direction" in player: data["direction"] = player.direction
	if "cursor_visible" in player: data["cursor_visible"] = player.cursor_visible
	if "which_scene" in player: data["which_scene"] = player.which_scene

	var character = player.get_node_or_null("character")
	if is_instance_valid(character):
		data["character_rotation"] = character.rotation

	var turnable = player.get_node_or_null("Turnable")
	if is_instance_valid(turnable):
		data["turnable_rotation"] = turnable.rotation

	# Camera: h = yaw, v = pitch, Camera's own translation = zoom offset
	# (see Camroot.gd: camrot_h/camrot_v drive h/v rotation_degrees, and
	# Zoom() only ever moves the Camera node's own translation).
	var camroot = player.get_node_or_null("Camroot")
	if is_instance_valid(camroot):
		data["camera_h_rotation"] = camroot.camrot_h
		data["camera_v_rotation"] = camroot.camrot_v
		var cam = camroot.get_node_or_null("h/v/Camera")
		if is_instance_valid(cam):
			data["camera_translation"] = cam.translation

	_writePlayerStateToDir(player_dir, data)



func _writePlayerStateToDir(player_dir:String, data:Dictionary) -> void:
	var dir := Directory.new()
	if !dir.dir_exists(player_dir):
		dir.make_dir_recursive(player_dir)

	var save_path := player_dir + "playerstate.save"
	var old_data := {}
	var read_file := File.new()
	if read_file.file_exists(save_path) and read_file.open(save_path, File.READ) == OK:
		old_data = read_file.get_var()
		read_file.close()
	if typeof(old_data) != TYPE_DICTIONARY:
		old_data = {}

	var positions = old_data.get("positions", {})
	if typeof(positions) != TYPE_DICTIONARY:
		positions = {}
	if data.has("world_id") and data.has("position"):
		positions[data["world_id"]] = data["position"]
	data["positions"] = positions

	var file := File.new()
	if file.open(save_path, File.WRITE) == OK:
		file.store_var(data)
		file.close()


func readPlayerStateSave(path:String) -> Dictionary:
	var file := File.new()
	if !file.file_exists(path):
		return {}
	if file.open(path, File.READ) != OK:
		return {}
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


func savePlayerStateFor(player:Node, data:Dictionary) -> void:
	if !is_instance_valid(player) or !("entity_name" in player) or player.entity_name == "":
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		rpc_id(1, "requestSavePlayerState", player.entity_name, data)
		return
	_writePlayerStateToDir(getPlayerSaveBaseDir() + player.entity_name + "/", data)

remote func requestSavePlayerState(entity_name:String, data:Dictionary) -> void:
	if !get_tree().is_network_server():
		return
	_writePlayerStateToDir(getPlayerSaveBaseDir() + entity_name + "/", data)






















func saveEquipmentTo(equipment:Node, player_dir:String) -> void:
	var data := {
		"Torso": equipment.getTexturePath(equipment.slot_torso),
		"Hands": equipment.getTexturePath(equipment.slot_hands),
		"Feet": equipment.getTexturePath(equipment.slot_feet),
		"MainHand": equipment.getTexturePath(equipment.slot_mainhand),
		"OffHand": equipment.getTexturePath(equipment.slot_offhand),
		"Necklace": equipment.getTexturePath(equipment.get_node("Necklace/Slot")),
		"Ring": equipment.getTexturePath(equipment.ring.get_node("Slot")),
		"Ring2": equipment.getTexturePath(equipment.ring2.get_node("Slot")),
		"Ring3": equipment.getTexturePath(equipment.ring3.get_node("Slot")),
		"Ring4": equipment.getTexturePath(equipment.ring4.get_node("Slot")),
		"Ring5": equipment.getTexturePath(equipment.ring5.get_node("Slot")),
		"Ring6": equipment.getTexturePath(equipment.ring6.get_node("Slot")),
		"Ring7": equipment.getTexturePath(equipment.ring7.get_node("Slot")),
		"Ring8": equipment.getTexturePath(equipment.ring8.get_node("Slot"))
	}

	var save_path := player_dir + "equipment.save"
	var file := File.new()
	if file.open(save_path, File.WRITE) == OK:
		file.store_var(data)
		file.close()



func readEquipmentSave(path:String) -> Dictionary:
	var file := File.new()
	if !file.file_exists(path):
		return {}
	if file.open(path, File.READ) != OK:
		return {}
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return {
		"torso": data.get("Torso",""), "hands": data.get("Hands",""), "feet": data.get("Feet",""),
		"mainhand": data.get("MainHand",""), "offhand": data.get("OffHand",""), "necklace": data.get("Necklace",""),
		"rings": [data.get("Ring",""), data.get("Ring2",""), data.get("Ring3",""), data.get("Ring4",""),
			data.get("Ring5",""), data.get("Ring6",""), data.get("Ring7",""), data.get("Ring8","")]
	}






func loadPlayerData(player:Node, base_dir:String) -> void:
	if !is_instance_valid(player):
		return
	if !("entity_name" in player) or player.entity_name == "":
		push_error("World.gd loadPlayerData(): player has no entity_name, skipping.")
		return

	var ui = player.get_node_or_null("UI")
	if ui == null:
		push_error("World.gd loadPlayerData(): 'UI' not found as direct child of " + player.name)
		return

	var equipment = ui.get_node_or_null("Equipment")
	if is_instance_valid(equipment):
		var snapshot = readEquipmentSave(base_dir + player.entity_name + "/equipment.save")
		if snapshot.empty():
			snapshot = Items.getDefaultEquipmentSnapshot()
		if equipment.has_method("applyOwnEquipmentSnapshot"):
			equipment.applyOwnEquipmentSnapshot(snapshot)
	else:
		push_error("World.gd loadPlayerData(): 'UI/Equipment' not found for " + player.entity_name)

	var inventory = ui.get_node_or_null("Inventory")
	if is_instance_valid(inventory):
		var inv_snapshot = readInventorySave(base_dir + player.entity_name + "/inventory.save")
		if inventory.has_method("applyOwnInventorySnapshot"):
			inventory.applyOwnInventorySnapshot(inv_snapshot)
	else:
		push_error("World.gd loadPlayerData(): 'UI/Inventory' not found for " + player.entity_name)
	
	var skillbar = ui.get_node_or_null("Skillbar")
	if is_instance_valid(skillbar):
		var sb_snapshot = readSkillbarSave(base_dir + player.entity_name + "/skillbar.save")
		if skillbar.has_method("applyOwnSkillbarSnapshot"):
			skillbar.applyOwnSkillbarSnapshot(sb_snapshot)
	var stats_node2 = player.get_node_or_null("Stats")
	if is_instance_valid(stats_node2):
		var stats_snapshot = readStatsSave(base_dir + player.entity_name + "/playerstats.save")
		if !stats_snapshot.empty() and stats_node2.has_method("applyOwnStatsSnapshot"):
			stats_node2.applyOwnStatsSnapshot(stats_snapshot)
	# TODO: crafting, loot -- same pattern




























func getMobSaveBaseDir() -> String:
	if get_tree().network_peer == null:
		return "user://WorldSaves/Offline/"
	return "user://WorldSaves/Server_" + getServerAddressId() + "/"











func getSpawnedBodyNames(entity):
	if !entity.is_in_group("Player"):
		var names=[]
		for spawned_body in entity.spawned_bodies: 
			if is_instance_valid(spawned_body):
				names.append(spawned_body.name)
		return names

var scene_cache = {}
func getScene(path):
	if !scene_cache.has(path):
		scene_cache[path] = load(path)
	return scene_cache[path]

var resource_states := {}

func loadResourceStatesFile():
	var path = "user://" + world_id + "/resources.save"
	var file = File.new()
	if file.file_exists(path) and file.open(path, File.READ) == OK:
		resource_states = file.get_var()
		file.close()
	else:
		resource_states = {}

func getGatherableKey(gatherable) -> String:
	return gatherable.get_parent().name + "/" + gatherable.name

func applyResourceStates():
	for gatherable in get_tree().get_nodes_in_group("Resource"):
		if !is_instance_valid(gatherable):
			continue

		var key = getGatherableKey(gatherable)
		if !resource_states.has(key):
			continue

		var data = resource_states[key]

		gatherable.resource_amount = data.get("amount", gatherable.max_resource)
		gatherable.depleted_time = data.get("depleted_time", 0)

		var saved_rotation = data.get("rotation", gatherable.rotation)
		if typeof(saved_rotation) == TYPE_VECTOR3:
			gatherable.rotation = saved_rotation
		elif typeof(saved_rotation) == TYPE_REAL:
			gatherable.rotation.y = saved_rotation

		if gatherable.resource_amount <= 0:
			gatherable.visible = false
			gatherable.get_node("CollisionShape").disabled = true
			if !("world_id" in gatherable.get_parent()):
				gatherable.get_parent().visible = false
		else:
			gatherable.visible = true
			gatherable.get_node("CollisionShape").disabled = false

		gatherable.set_process(gatherable.resource_amount <= 0)

func saveResourceStates():
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return

	for gatherable in get_tree().get_nodes_in_group("Resource"):
		if !is_instance_valid(gatherable):
			continue

		resource_states[getGatherableKey(gatherable)] = {
			"amount": gatherable.resource_amount,
			"depleted_time": gatherable.depleted_time,
			"rotation": gatherable.rotation
		}

	var path = "user://" + world_id + "/resources.save"
	var dir = Directory.new()
	if !dir.dir_exists("user://" + world_id):
		dir.make_dir_recursive("user://" + world_id)
	var file = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_var(resource_states)
		file.close()


func _entityIdentifier(node:Node) -> String:
	if node.is_in_group("Player") and "entity_name" in node and node.entity_name != "":
		return "player:" + node.entity_name
	return "mob:" + node.name

func _findEntityByIdentifier(id:String):
	if id == "":
		return null
	for e in getAllEntities():
		if is_instance_valid(e) and _entityIdentifier(e) == id:
			return e
	return null






#_____________Reloading mobs ___________________________________________________
func buildSaveEntry(entity):
	var stats = entity.get_node_or_null("Stats")
	var is_offline = get_tree().network_peer == null

	var statuses = {}
	var debuff_buffs = {}

	if stats:
		statuses = stats.statuses.duplicate(true)
		for status_name in statuses:
			var status_value = statuses[status_name]
			if typeof(status_value) == TYPE_ARRAY:
				for status_entry in status_value:
					if typeof(status_entry) == TYPE_DICTIONARY:
						status_entry["applier"] = ""
			elif typeof(status_value) == TYPE_DICTIONARY:
				status_value["applier"] = ""

		debuff_buffs = stats.debuff_buffs_active.duplicate(true)
		for buff_name in debuff_buffs:
			debuff_buffs[buff_name]["applier"] = ""
			debuff_buffs[buff_name]["source_id"] = 0

	var creator_name = ""
	var creator_ref = safeGet(entity, "creator", null)
	if is_instance_valid(creator_ref):
		creator_name = _entityIdentifier(creator_ref)

	var spawned_names = []

	var character = entity.get_node_or_null("character")
	var character_rotation = null
	if character:
		character_rotation = character.rotation

	if !entity.is_in_group("Player") and "spawned_bodies" in entity:
		for spawned_body in entity.spawned_bodies:
			if is_instance_valid(spawned_body):
				spawned_names.append(_entityIdentifier(spawned_body))

	var parent_name = ""
	var entity_parent = entity.get_parent()
	if is_instance_valid(entity_parent) and entity_parent != self:
		parent_name = entity_parent.name

	var save_entry = {
		"character_rotation": character_rotation,
		"scene": entity.filename,
		"node_name": entity.name,
		"entity_name": safeGet(entity, "entity_name", ""),
		"finished": safeStats(entity, "is_finished", false),
		"position": entity.global_transform.origin,
		"rotation": entity.rotation,
		"name": safeStats(entity, "Name", ""),

		"nutrition": safeStats(entity, "nutrition"),
		"health": safeStats(entity, "health"),
		"energy": safeStats(entity, "energy"),
		"arcane": safeStats(entity, "arcane"),
		"is_dead": safeGet(entity, "is_dead", false),
		"aggro_target": (getAggroTargetName(entity) if is_offline else ""),
		"aggro": (saveAggro(entity) if is_offline else []),
		"respawn_time": safeGet(entity, "respawn_time", 3),
		"respawn_id": safeGet(entity, "respawn_id", 0),
		"creator": creator_name,
		"spawned_bodies": spawned_names,
		"parent_name": parent_name,
		"statuses": statuses,
		"debuff_buffs_active": debuff_buffs,
	}

	if stats:
		save_entry["species"] = stats.species
		save_entry["sex"] = stats.sex
	if "skill_cooldowns" in entity and entity.skill_cooldowns != null:
		save_entry["skill_cooldowns"] = entity.skill_cooldowns.duplicate(true)

	return save_entry

func loadMob(mobData):
	if !get_tree().is_network_server() and get_tree().network_peer != null:
		return null

	var parent_node = self
	var parent_name = mobData.get("parent_name", "")
	if parent_name != "":
		var found_parent = findNodeByName(parent_name)
		if is_instance_valid(found_parent):
			parent_node = found_parent

	var node_name = mobData.get("node_name", mobData["name"])

	var mob = parent_node.get_node_or_null(node_name)
	if mob == null or !is_instance_valid(mob) or !mob.is_in_group("Entity"):
		return null

	mob.global_transform.origin = mobData["position"]
	mob.rotation = mobData.get("rotation", mob.rotation)

	if !mob.is_in_group("Player"):
		mob.entity_name = mobData.get("entity_name", mob.entity_name)
		mob.creator = null
		mob.spawned_bodies = []
		mob.is_dead = mobData.get("is_dead", false)
		mob.respawn_time = mobData.get("respawn_time", mob.respawn_time)
		if mob.is_dead:
			mob.just_loaded_dead_grace = 300

	var stats = mob.get_node_or_null("Stats")
	if stats:
		stats.level = mobData.get("level", stats.level)
		stats.updateAttributes()
		stats.updateBuffDebuffs()
		stats.loadData()

		if mobData.has("statuses"):
			stats.statuses = mobData["statuses"].duplicate(true)
		if mobData.has("debuff_buffs_active"):
			stats.debuff_buffs_active = mobData["debuff_buffs_active"].duplicate(true)
		stats.markAttributeCacheDirty()
		stats.updateBuffDebuffs()
		stats.updateAttributes()

		stats.health = clamp(mobData.get("health", stats.max_health), 0, stats.max_health)
		stats.energy = clamp(mobData.get("energy", stats.max_energy), 0, stats.max_energy)
		stats.arcane = clamp(mobData.get("arcane", stats.max_arcane), 0, stats.max_arcane)
		if mob.is_dead and stats.health > 0:
			stats.health = 0

	if "nutrition" in mob:
		mob.nutrition = mobData.get("nutrition", mob.nutrition)

	return mob
func saveAggro(entity):
	if get_tree().network_peer != null:
		return []

	var aggro_data = []

	if !entity.has_method("get"):
		return aggro_data

	var target_list = safeGet(entity, "targets", [])

	for aggro_target in target_list:
		if aggro_target == null:
			continue
		if aggro_target.target_entity == null:
			continue
		if !is_instance_valid(aggro_target.target_entity):
			continue

		aggro_data.append({
			"target_name": _entityIdentifier(aggro_target.target_entity),
			"aggro": aggro_target.aggro
		})

	return aggro_data

func getAggroTargetName(entity):
	if get_tree().network_peer != null:
		return ""

	var combat_target = safeGet(entity, "target", null)
	if combat_target == null:
		return ""
	if !is_instance_valid(combat_target):
		return ""

	return _entityIdentifier(combat_target)
func findNodeByName(node_name:String, root=null):
	if root == null:
		root = self

	for child in root.get_children():
		if !is_instance_valid(child):
			continue
		if child.name == node_name:
			return child
		var found = findNodeByName(node_name, child)
		if found:
			return found

	return null

func findEntity(node_name:String):
	return findNodeByName(node_name)

func restoreCreators(loaded_mobs):
	var creator_map = {}
	var spawned_map = {}
	for e in getAllEntities():
		if is_instance_valid(e):
			var id = _entityIdentifier(e)
			creator_map[id] = e
			spawned_map[id] = e

	for entry in loaded_mobs:
		var mob = entry.get("mob")
		if mob == null or !is_instance_valid(mob):
			continue

		var creator_name = str(entry.get("creator", ""))
		if !mob.is_in_group("Player"):
			mob.creator = null

		if creator_map.has(creator_name):
			var creator_ref = creator_map[creator_name]
			if is_instance_valid(creator_ref):
				mob.creator = creator_ref

		mob.spawned_bodies = []
		for spawned_name in entry.get("spawned_bodies", []):
			spawned_name = str(spawned_name)
			if spawned_map.has(spawned_name):
				var spawned_ref = spawned_map[spawned_name]
				if is_instance_valid(spawned_ref):
					mob.spawned_bodies.append(spawned_ref)

func restoreAggro(loaded_mobs):
	if get_tree().network_peer != null:
		return

	for entry in loaded_mobs:
		if !entry.has("mob"):
			continue

		var mob = entry.mob
		if !is_instance_valid(mob):
			continue

		restoreCombatTarget(mob, entry.get("aggro_target", ""))
		restoreAggroList(mob, entry.get("aggro", []))

		if mob.has_method("findHighestAggro"):
			var highest = mob.findHighestAggro()
			if highest and highest.aggro > 0:
				mob.target = highest.target_entity
				if "_is_relevant" in mob:
					mob._is_relevant = true

func restoreCombatTarget(mob, target_name):
	if target_name == "":
		return
	var node = _findEntityByIdentifier(target_name)
	if node != null:
		mob.target = node

func restoreAggroList(mob, aggro_list):
	if !mob.has_method("getAggro"):
		return

	for saved_aggro in aggro_list:
		if !saved_aggro.has("target_name"):
			continue

		var node = _findEntityByIdentifier(str(saved_aggro["target_name"]))
		if node == null:
			continue

		var aggro_target = mob.getAggro(node)
		if aggro_target == null:
			continue

		aggro_target.aggro = saved_aggro.get("aggro", 0)








#________________________________UTILITY________________________________________

func safeGet(obj,property,default_value):
	if obj == null:
		return default_value

	if obj.get(property) != null:
		return obj.get(property)

	return default_value

func safeStats(entity, property, default_value = null):
	var stats = entity.get_node_or_null("Stats")
	if stats == null:
		return default_value

	var value = stats.get(property)
	if value == null:
		return default_value

	return value

func randomizeName(mobName,stats):
	if mobName == "":
		return stats.Names[randi() % stats.Names.size()]

	return mobName

#portal stuff____________________________________________________________________________________
func matchWorldIdGroup(node:Node) -> String:
	for group in node.get_groups():
		var g = str(group).to_lower()
		if WorldRegistry.isKnownWorldId(g):
			return g
	return ""

func findSafeplacement(portal_node:Node) -> Spatial:
	for child in portal_node.get_children():
		if child is Spatial and child.name.to_lower().find("safeplacement") != -1:
			return child
	return null



func _resolvePortalSpawnPosition(dest_world:Node, source_world_id:String) -> Vector3:
	var return_portal = findReturnPortal(dest_world, source_world_id)
	if return_portal != null:
		var safeplacement = findSafeplacement(return_portal)
		if safeplacement != null:
			return safeplacement.global_transform.origin
		return return_portal.global_transform.origin
	var spawnpoint = dest_world.getNearestSpawnpoint()
	if spawnpoint:
		return spawnpoint.global_transform.origin
	push_error("World.gd: no return portal or Spawnpoint found in '" + dest_world.world_id + "' for source '" + source_world_id + "' -- falling back to world origin")
	return dest_world.global_transform.origin

func saveLastWorldId(wid:String) -> void:
	var file = File.new()
	if file.open("user://last_world.save", File.WRITE) == OK:
		file.store_var({"world_id": wid, "player": Global.selected_player_name})
		file.close()

var changing_scene := false

# --- interactive loading state for portal() ---
var portal_loader:ResourceInteractiveLoader = null
var portal_dest_world_id := ""
var portal_real_progress := 0.0
var portal_displayed_progress := 0.0
export var portal_progress_catchup_speed := 1.5

# --- waiting for server to actually move our player after we've
# already swapped scenes locally ---
var waiting_for_portal_world:Node = null
var waiting_for_portal_start_time:int = 0
export var waiting_for_portal_timeout_ms:int = 8000
var portal_old_world:Node = null

onready var loading_label:Label = $LoadingScreen/Label

# target_portal must be in group "Portal" plus a group matching a
# WorldRegistry world_id (case-insensitive: "Mines", "mines", "MINES" all work)
func portal(target_portal:Node) -> void:
	if changing_scene or !is_instance_valid(target_portal):
		return

	var dest_world_id = worldIdFromPortalName(target_portal)
	if dest_world_id == "":
		push_error("World.gd portal(): '" + target_portal.name + "' name doesn't match PortalTo<WorldId>")
		return
	if dest_world_id == world_id:
		return # already there, refuse self-portal (loop guard)

	var path = WorldRegistry.getScenePath(dest_world_id)
	if path == "":
		push_error("World.gd portal(): no scene path for '" + dest_world_id + "'")
		return

	changing_scene = true
	showLoadscreen()
	loading_label.text = "Loading... 0%"
	saveData()
	saveRecursive(self)

	portal_dest_world_id = dest_world_id
	portal_real_progress = 0.0
	portal_displayed_progress = 0.0

	portal_loader = ResourceLoader.load_interactive(path)
	if portal_loader == null:
		push_error("Failed to start loading " + path)
		changing_scene = false
		hideLoadscreen()
		return
	set_process(true)

# World.gd — finishPortalLoad()
func finishPortalLoad(packed_scene:PackedScene) -> void:
	var dest_world = packed_scene.instance()
	dest_world.world_id = portal_dest_world_id
	dest_world.skip_offline_autospawn = true

	var tree = get_tree()
	tree.root.add_child(dest_world)
	tree.current_scene = dest_world

	if tree.network_peer != null:
		for child in get_children():
			if child.is_in_group("Player") and "entity_name" in child and child.entity_name == Global.selected_player_name:
				remove_child(child)
				child.queue_free()
				break

		PlayerSpawner.rpc_id(1, "requestPortal", portal_dest_world_id)
		waiting_for_portal_world = dest_world
		waiting_for_portal_start_time = OS.get_ticks_msec()
		portal_old_world = self
		return

	var local_player = null
	for child in get_children():
		if child.is_in_group("Player") and "entity_name" in child and child.entity_name == Global.selected_player_name:
			local_player = child
			break

	if local_player == null:
		tree.root.remove_child(dest_world)
		dest_world.queue_free()
		tree.current_scene = self
		changing_scene = false
		hideLoadscreen()
		return

	var spawn_pos = dest_world._resolvePortalSpawnPosition(dest_world, world_id)

	remove_child(local_player)
	dest_world.add_child(local_player)
	local_player.translation = spawn_pos
	local_player.which_scene = portal_dest_world_id
	local_player.disableFallDamage()
	local_player.portal_grace_timer = 1.0
	if local_player.has_method("reactivateAnimationTree"):
		local_player.reactivateAnimationTree()

	dest_world.saveLastWorldId(portal_dest_world_id)
	if local_player.has_method("saveData"):
		local_player.saveData()

	tree.root.remove_child(self)
	queue_free()

	changing_scene = false
	hideLoadscreen()













func _process(delta):
	if !changing_scene:
		set_process(false)
		return

	if waiting_for_portal_world != null:
		pollWaitingForPortal()
		return

	if portal_loader == null:
		return

	portal_displayed_progress = lerp(portal_displayed_progress, portal_real_progress, delta * portal_progress_catchup_speed)
	loading_label.text = "Loading... " + str(int(portal_displayed_progress * 100)) + "%"

	var err = portal_loader.poll()
	match err:
		OK:
			var stage_count = portal_loader.get_stage_count()
			if stage_count > 0:
				portal_real_progress = min(float(portal_loader.get_stage()) / stage_count, 0.99)
		ERR_FILE_EOF:
			var packed_scene:PackedScene = portal_loader.get_resource()
			portal_loader = null
			portal_real_progress = 1.0
			finishPortalLoad(packed_scene)
		_:
			portal_loader = null
			changing_scene = false
			hideLoadscreen()
			set_process(false)
			push_error("Failed to load portal destination, error code: " + str(err))

# PER-MAP POSITION SAVE
func savePerWorldPosition(wid:String, pos:Vector3) -> void:
	var path = "user://last_positions.save"
	var file = File.new()
	var data := {}
	if file.file_exists(path) and file.open(path, File.READ) == OK:
		data = file.get_var()
		file.close()
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	if !data.has(Global.selected_player_name):
		data[Global.selected_player_name] = {}
	data[Global.selected_player_name][wid] = pos
	if file.open(path, File.WRITE) == OK:
		file.store_var(data)
		file.close()


# World.gd — pollWaitingForPortal()
func pollWaitingForPortal() -> void:
	if !is_instance_valid(waiting_for_portal_world):
		waiting_for_portal_world = null
		portal_old_world = null
		changing_scene = false
		hideLoadscreen()
		return

	var found_player = false
	var found_player_node = null
	for child in waiting_for_portal_world.get_children():
		if child.is_in_group("Player") and "entity_name" in child and child.entity_name == Global.selected_player_name:
			found_player = true
			found_player_node = child
			if child.has_method("reactivateAnimationTree"):
				child.reactivateAnimationTree()
			if child.has_method("disableFallDamage"):
				child.disableFallDamage()
			break

	var timed_out = OS.get_ticks_msec() - waiting_for_portal_start_time >= waiting_for_portal_timeout_ms

	if found_player or timed_out:
		var wid = waiting_for_portal_world.world_id
		if timed_out and !found_player:
			push_error("World.gd portal(): timed out waiting for server to move player")

		if is_instance_valid(portal_old_world) and portal_old_world != waiting_for_portal_world:
			get_tree().root.remove_child(portal_old_world)
			portal_old_world.queue_free()
		portal_old_world = null

		waiting_for_portal_world = null
		changing_scene = false
		hideLoadscreen()
		if found_player:
			saveLastWorldId(wid)
			if is_instance_valid(found_player_node) and found_player_node.has_method("saveData"):
				found_player_node.saveData()















func showLoadscreen()->void:
	$LoadingScreen.visible = true

func hideLoadscreen()->void:
	$LoadingScreen.visible = false


func worldIdFromPortalName(node:Node) -> String:
	var n = node.name.to_lower()
	var prefix = "portalto"
	var idx = n.find(prefix)
	if idx == -1:
		return ""
	var rest = n.substr(idx + prefix.length())
	for wid in WorldRegistry.allWorldIds():
		if rest.begins_with(wid.to_lower()):
			return wid
	return ""
func findReturnPortal(root:Node, source_world_id:String) -> Node:
	for child in root.get_children():
		if !is_instance_valid(child):
			continue
		if child.is_in_group("Portal") and worldIdFromPortalName(child) == source_world_id:
			return child
		var found = findReturnPortal(child, source_world_id)
		if found:
			return found
	return null
