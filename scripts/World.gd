extends Spatial #World.gd, script on the scene root of every map including mines and other maps, any map at all really, when entering the game world.tscn is loaded by default and player 
#added here, then the player on ready remebers in what scene he was supposed to be and moves there 
#mobs exist as children of Spawnpoint + mob name or generic Spawnpoints which are spatial
#mobs ar eonly ever spawned as a debug to test bugs example $SpawnpointMoleSpider/NPC10
#each NPC is non local .tscn not editable, with the default configuration of the scene, untouched
var auto_save:bool = false
var selected_player_name:String=  Global.selected_player_name
export(String) var world_id="world"
var skip_offline_autospawn := false
var autosave_interval:int = 3700
var _entity_cache := []
var _autosave_running := false
export var autosave_min_spread_time:float = 60
export var autosave_entities_per_batch:int = 3
 
 
 
 
 
 
 
 
 
 
 
 
 
 
func _ready():
	startFileWriteThread()
	wrapLoadingScreenInCanvasLayer()
	set_process(false)
	add_to_group("World")
	Global.loadListings()
	removeBothersomeKeybinds()
	showLoadscreen()
	call_deferred("beginStaggeredWorldEntry")


func beginStaggeredWorldEntry() -> void:
	# call_deferred() runs before the CURRENT frame ends, not on a later
	# frame -- so startWorld()/warmShaderCache()/spawnOfflinePlayer() used
	# to all stack onto the same already-expensive scene-entry frame.
	# Real yield(get_tree(),"idle_frame") calls force each stage onto its
	# own later frame instead, so no single frame does all the work.
	yield(get_tree(), "idle_frame")

	if get_tree().network_peer != null:
		if world_id == "world":
			if !Network.is_connected("player_connected", self, "_on_player_connected"):
				Network.connect("player_connected", self, "_on_player_connected")
			if !Network.is_connected("player_disconnected", self, "_on_player_disconnected"):
				Network.connect("player_disconnected", self, "_on_player_disconnected")
			if get_tree().is_network_server():
				Global._loadBannerRostersIfNeeded()
				if Global.selected_player_name != "":
					var host_world_id = Global._readSavedWorldId(Global.selected_player_name)
					var host_world = Global._getWorldById(host_world_id)
					var host_spawn_pos := Vector3.ZERO
					var host_has_spawn_pos := false
					if is_instance_valid(host_world) and host_world.has_method("resolveSpawnPositionForPlayer"):
						host_spawn_pos = host_world.resolveSpawnPositionForPlayer(Global.selected_player_name, host_world_id)
						host_has_spawn_pos = true
					Global.spawnPlayerForPeer(get_tree().get_network_unique_id(), Global.selected_player_name, host_world_id, host_spawn_pos, host_has_spawn_pos)
			else:
				Global.rpc_id(1, "requestFullMobResync")
				Global.sendSpawnRequestOnceConnected(Global.selected_player_name)
				Global.rpc_id(1, "requestFullPlayerResync")

		if !get_tree().is_network_server():
			rpc_id(1, "requestWorldMobSync")
			rpc_id(1, "requestWorldResourceSync")

	yield(get_tree(), "idle_frame")

	var world_state = startWorld()
	if world_state is GDScriptFunctionState:
		yield(world_state, "completed")

	yield(get_tree(), "idle_frame")

	if get_tree().network_peer == null and !skip_offline_autospawn:
		var spawn_state = spawnOfflinePlayer()
		if spawn_state is GDScriptFunctionState:
			yield(spawn_state, "completed")
		for i in range(5):
			yield(get_tree(), "idle_frame")

	var warm_state = warmShaderCache()
	if warm_state is GDScriptFunctionState:
		yield(warm_state, "completed")
 
 
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

	var load_state = loadPlayerData(player, getPlayerSaveBaseDir())
	if load_state is GDScriptFunctionState:
		yield(load_state, "completed")

	Global.deliverPendingProceedsTo(1)
	var state_path = getPlayerSaveBaseDir() + player.entity_name + "/playerstate.save"
	var has_save = File.new().file_exists(state_path)
	var state_data = readPlayerStateSave(state_path)
 
	call_deferred("applyOfflinePlayerState", player, state_data, has_save)













func applyOfflinePlayerState(player:Node, state_data:Dictionary, has_save:bool) -> void:
	if !is_instance_valid(player):
		return
	if !has_save or state_data.empty():
		player.translation = getPlayerStartPosition()
	else:
		player.applyOwnStateSnapshot(state_data)
	player.data_fully_loaded = true
	if player.has_method("_revealAfterLoad"):
		player._revealAfterLoad()
 
 
 
 
remote func requestWorldMobSync() -> void:
	pass # handled by MobSync's requestFullMobResync now
 
 
		
func _on_player_connected(id:int) -> void:
	if get_tree().is_network_server():
		call_deferred("_deferredOnPlayerConnected", id)
 
# ===== World.gd — _deferredOnPlayerConnected() =====
func _deferredOnPlayerConnected(id:int) -> void:
	if !get_tree().is_network_server():
		return
	if !get_tree().get_network_connected_peers().has(id):
		return
	sendGatherableStatesToPeer(id)
	Global.catchUpNewPeer(id)
	Global.sendCatchUpTo(id)
	# NEW: requested -- resend this peer's own full data too, not just
	# other players' presence.
	Global.resendFullDataTo(id)
 
func _on_player_disconnected(id:int) -> void:
	Global.despawnPlayer(id)
 
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
	cacheSpawnpoints()
	getNearestSpawnpoint()
	cacheRespawnNodes()
	_rebuildEntityCache()
	if get_tree().network_peer == null or get_tree().is_network_server():
		call_deferred("loadData")
	
 
export var mob_load_chunk_size := 5

func loadData():
	if !is_inside_tree():
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return
	Global.loadListings()
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

	var name_cache_state = buildNodeNameCache()
	if name_cache_state is GDScriptFunctionState:
		yield(name_cache_state, "completed")
	loadMobsStaggered(data["mobs"])


func loadMobsStaggered(mob_data_list:Array) -> void:
	var loaded_mobs := []
	var n := 0

	for mob_data in mob_data_list:
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

		n += 1
		if n % mob_load_chunk_size == 0:
			_rebuildEntityCache()
			yield(get_tree(), "idle_frame")

	_rebuildEntityCache()

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
 
var _collision_check_index := 0
export var collision_checks_per_batch := 60

func disableCollisionsRecursive() -> void:
	if collidable_shapes.empty():
		return
	var players = []
	for child in get_children():
		if is_instance_valid(child) and child.is_in_group("Player"):
			players.append(child)

	var checked := 0
	while checked < collision_checks_per_batch and !collidable_shapes.empty():
		if _collision_check_index >= collidable_shapes.size():
			_collision_check_index = 0
		var shape = collidable_shapes[_collision_check_index]
		_collision_check_index += 1
		checked += 1

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



func getCachedEntities() -> Array:
	return _entity_cache
 
 
 
func _rebuildEntityCache() -> void:
	var fresh = getAllEntities()
	_entity_cache.resize(0)
	for e in fresh:
		_entity_cache.append(e)
 

export var position_safety_save_interval:int = 120 # ~2s @60fps -- cheap, position/world_id only, independent of the slower full autosave
func _physics_process(delta):
	if get_tree().network_peer == null or get_tree().is_network_server():
		auto_save = true
	loadingScreenProcess(delta)
	if Engine.get_physics_frames() %30 == 0:
		disableCollisionsRecursive()
	if Engine.get_physics_frames() % frozen_mob_recheck_interval == 0:
		recheckFrozenMobs()
	if Engine.get_physics_frames() % position_safety_save_interval == 0:
		savePositionsOnlyForAllPlayers()
	if Engine.get_physics_frames() %autosave_interval== 0:
		if auto_save and !_autosave_running:
			call_deferred("startStaggeredAutosave")
	processSaveQueue()

	if Input.is_action_just_pressed("savedata"):
		saveData()
		saveRecursive(self)
var pendingFileWrites := [] # Array of {"path":String,"data":Variant}
export var file_writes_per_frame := 3 # kept for compatibility, no longer used to gate the thread

var _fileWriteMutex := Mutex.new()
var _fileWriteSemaphore := Semaphore.new()
var _fileWriteThread := Thread.new()
var _fileWriteThreadRunning := false

func startFileWriteThread() -> void:
	if _fileWriteThreadRunning:
		return
	_fileWriteThreadRunning = true
	_fileWriteThread.start(self, "fileWriteThreadLoop")

func stopFileWriteThread() -> void:
	if !_fileWriteThreadRunning:
		return
	_fileWriteThreadRunning = false
	_fileWriteSemaphore.post() # wake the thread so it can see the stop flag
	_fileWriteThread.wait_to_finish()

func fileWriteThreadLoop(_unused) -> void:
	while true:
		_fileWriteSemaphore.wait()
		if !_fileWriteThreadRunning:
			return
		while true:
			_fileWriteMutex.lock()
			var empty = pendingFileWrites.empty()
			var entry = null
			if !empty:
				entry = pendingFileWrites.pop_front()
			_fileWriteMutex.unlock()
			if entry == null:
				break
			var file := File.new()
			if file.open(entry["path"], File.WRITE) == OK:
				file.store_var(entry["data"])
				file.close()

func queueFileWrite(path:String, data) -> void:
	var dir_path := path.get_base_dir()
	var dir := Directory.new()
	if !dir.dir_exists(dir_path):
		dir.make_dir_recursive(dir_path)
	_fileWriteMutex.lock()
	pendingFileWrites.append({"path": path, "data": data})
	_fileWriteMutex.unlock()
	_fileWriteSemaphore.post()

func processFileWriteQueue() -> void:
	pass # writes now happen entirely on the background thread -- nothing to do here on the main thread anymore

func flushFileWriteQueue() -> void:
	# Synchronous drain for shutdown -- runs on THIS (main) thread since
	# we're about to quit and the worker thread might not get another tick.
	_fileWriteMutex.lock()
	var remaining = pendingFileWrites.duplicate()
	pendingFileWrites.clear()
	_fileWriteMutex.unlock()
	for entry in remaining:
		var file := File.new()
		if file.open(entry["path"], File.WRITE) == OK:
			file.store_var(entry["data"])
			file.close()
func savePositionsOnlyForAllPlayers() -> void:
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return
	for player in findPlayersToSave():
		if !is_instance_valid(player):
			continue
		if "data_fully_loaded" in player and !player.data_fully_loaded:
			continue
		savePlayerStateTo(player, getPlayerSaveBaseDir() + player.entity_name + "/")
 









func getPartySaveDir(entity_name:String) -> String:
	return getPlayerSaveBaseDir() + entity_name + "/"

func savePartyTo(party_node:Node, entity_name:String) -> void:
	if !is_instance_valid(party_node) or !party_node.has_method("gatherPartySnapshot"):
		return
	queueFileWrite(getPartySaveDir(entity_name) + "party.save", party_node.gatherPartySnapshot())

func savePartyFor(player:Node, data:Dictionary) -> void:
	if !is_instance_valid(player) or !("entity_name" in player) or player.entity_name == "":
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		rpc_id(1, "requestSaveParty", player.entity_name, data)
		return
	queueFileWrite(getPartySaveDir(player.entity_name) + "party.save", data)

remote func requestSaveParty(entity_name:String, data:Dictionary) -> void:
	if !get_tree().is_network_server():
		return
	queueFileWrite(getPartySaveDir(entity_name) + "party.save", data)

func readPartySave(path:String) -> Dictionary:
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








export var frozen_mob_recheck_interval:int = 90 # was 30 — has_method scan was dead weight every 0.5s

func recheckFrozenMobs() -> void:
	for mob in getCachedEntities():
		if !is_instance_valid(mob) or mob.is_in_group("Player"):
			continue
		if !mob.is_frozen:
			continue
		if !is_instance_valid(mob.stats):
			continue
		if mob.stats.health <= 0 and !mob.is_dead:
			mob.is_dead = true
			mob.freezeAtDeathPose()
var cached_saveable_nodes := []
var _scanned_child_count := {}
 
func saveRecursive(node):
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return
	scanSaveableNodes(node)
 
	for saveable in cached_saveable_nodes:
		if is_instance_valid(saveable):
			saveable.saveData()
 
func scanSaveableNodes(node) -> void:
	if node is Occluder:
		return

	if isUnderLandscapeHolder(node):
		return

	# Nothing that ever implements saveData() lives under a "character"
	# root (Skeleton, bones, MeshInstances, weapon/shield scenes attached
	# to BoneAttachments) -- but bots reparent weapon nodes in and out of
	# bone holders constantly during combat, which changes child counts
	# all the way up that subtree and forced a full recursive rescan of
	# it every single time. Cutting the walk off at "character" removes
	# that entire (large, frequently-churning) subtree from the scan.
	if node.name == "character":
		return
	if node.name == "occluder":
		return
	if node.name == "AnimationPlayer":
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
			scanSaveableNodes(child)





func isUnderLandscapeHolder(node) -> bool:
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
const spawnpointNamesByWorld:Dictionary = {
	"world": [
		"SpawnpointStart",
		"SpawnpointStartPlantera",
		"SpawnpointStartPlantera2",
		"SpawnpointStartPlantera3",
		"SpawnpointStartPlantera4",
		"SpawnpointStartPlantera7",
		"SpawnpointStartPlantera5",
		"SpawnpointStart2",
		"SpawnpointStart3",
	],
	"mines": [
		"SpawnpointMoleSpider_Mines",
		"SpawnpointMoleSpider_Mines2",
		"SpawnpointMountainWyvern_Mines",
	],
	"test": [
		"SpawnpointTest",
	],
}
 
func cacheSpawnpoints() -> void:
	cached_spawnpoints.clear()
	var names:Array = spawnpointNamesByWorld.get(world_id, [])
	for spawnpoint_name in names:
		var sp:Node = get_node_or_null(spawnpoint_name)
		if is_instance_valid(sp):
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
 
func getAllEntities() -> Array:
	var entities:Array = []
 
	for player in get_tree().get_nodes_in_group("Player"):
		if is_instance_valid(player) and player.get_parent() == self:
			entities.append(player)
 
	for spawnpoint in cached_spawnpoints:
		if is_instance_valid(spawnpoint):
			collectEntitiesUnder(spawnpoint, entities)
 
	return entities
 
func collectEntitiesUnder(node:Node, out:Array) -> void:
	for child in node.get_children():
		if !is_instance_valid(child):
			continue
		if child.is_in_group("Entity"):
			out.append(child)
		else:
			collectEntitiesUnder(child, out)

func startStaggeredAutosave() -> void:
	if _autosave_running:
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return
	_autosave_running = true

	var mob_save_state = staggeredSaveMobData()
	if mob_save_state is GDScriptFunctionState:
		yield(mob_save_state, "completed")

	var player_save_state = staggeredSavePlayers()
	if player_save_state is GDScriptFunctionState:
		yield(player_save_state, "completed")

	Global.saveListings()
	queueSaveRecursive(self)
	_autosave_running = false

func staggeredSavePlayers() -> void:
	var players := findPlayersToSave()
	if players.empty():
		return
	var base_dir := getPlayerSaveBaseDir()
	var delay_between = autosave_min_spread_time / float(players.size())
	for player in players:
		if !is_instance_valid(player):
			continue
		var ui = player.get_node_or_null("UI")
		if !is_instance_valid(ui):
			continue
		var equipment = ui.get_node_or_null("Equipment")
		var inventory = ui.get_node_or_null("Inventory")
		if !is_instance_valid(equipment) or !is_instance_valid(inventory):
			continue
		savePlayerData(player, base_dir)
		yield(get_tree().create_timer(delay_between), "timeout")
# Server-side self-save RPCs (loot/crafting/friends/quests/skillbar/
# stats/playerstate) from several players routinely land in the same
# physics frame, each doing its own synchronous File.store_var() --
# that's the 80%-of-frame spikes in the profiler. Queuing the actual
# disk write and draining a few per frame spreads that cost out instead
# of stacking it. WHAT gets saved and the file format are unchanged --
# only WHEN the bytes actually hit disk.




func _writeSkillbarToDir(player_dir:String, data:Dictionary) -> void:
	queueFileWrite(player_dir + "skillbar.save", data)

func _writeCraftingToDir(player_dir:String, data:Dictionary, wid:String) -> void:
	queueFileWrite(player_dir + "crafting_" + wid + ".save", data)

func _writeLootToDir(player_dir:String, data:Dictionary, wid:String) -> void:
	queueFileWrite(player_dir + "corpse_loot_" + wid + ".save", data)

func _writeQuestsToDir(player_dir:String, data:Dictionary) -> void:
	queueFileWrite(player_dir + "quests.save", data)

func _writeFriendsToDir(player_dir:String, data:Dictionary) -> void:
	queueFileWrite(player_dir + "friends.save", data)

func _writeInventoryToDir(player_dir:String, data:Dictionary, entity_name:String = "") -> void:
	if entity_name != "" and get_tree().network_peer != null:
		data["coins"] = Global.getBalance(entity_name)
	queueFileWrite(player_dir + "inventory.save", data)

func _writeStatsToDir(player_dir:String, data:Dictionary) -> void:
	queueFileWrite(player_dir + "playerstats.save", data)
func _writePlayerStateToDir(player_dir:String, data:Dictionary) -> void:
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

	queueFileWrite(save_path, data)

 
 
 
 
 
 
onready var player_start_node:Spatial = $PlayerStart
func findPlayerStartNode(root=null) -> Spatial:
	return player_start_node
 
func getPlayerStartPosition() -> Vector3:
	var start_node = findPlayerStartNode()
	if start_node != null:
		return start_node.global_transform.origin
	push_error("World.gd getPlayerStartPosition(): no PlayerStart node found under '" + world_id + "', falling back to world origin")
	return global_transform.origin
func spawnAtPlayerStart()->void:
	var start_node = findPlayerStartNode()
 
	if start_node == null:
		print("Player.gd spawnAtPlayerStart(): warning - no PlayerStart node found")
		return
 
	var start_origin = start_node.global_transform.origin
 
 
 
 
 
 
 
 
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
 
 
 
#func findPlayersToSave() -> Array:
#	var players := []
#
#	if get_tree().network_peer != null:
#		for node in get_tree().get_nodes_in_group("Player"):
#			if is_instance_valid(node):
#				players.append(node)
#		return players
#
#	var direct = get_node_or_null("Player")
#	if is_instance_valid(direct):
#		players.append(direct)
#		return players
#
#	push_error("World.gd findPlayersToSave(): 'Player' not found as direct child, doing recursive search.")
#
#	var found = findNodeByName("Player")
#	if is_instance_valid(found):
#		players.append(found)
#	else:
#		push_error("World.gd findPlayersToSave(): no Player node found in tree.")
#
#	return players
# ===== World.gd — replace findPlayersToSave() =====
 
func findPlayersToSave() -> Array:
	if get_tree().network_peer != null:
		# Only players actually standing in THIS world, not every connected
		# player server-wide -- filter PlayerSpawner's registry by world_id
		# instead of scanning the "Player" group across every map.
		var players := []
		for peer_id in Global.spawned_players.keys():
			if Global.spawned_players[peer_id]["world_id"] != world_id:
				continue
			var node = get_node_or_null(str(peer_id))
			if is_instance_valid(node):
				players.append(node)
		return players
 
	var direct = get_node_or_null("Player")
	if is_instance_valid(direct):
		return [direct]
 
	push_error("World.gd findPlayersToSave(): 'Player' not found as direct child, doing recursive search.")
	var found = findNodeByName("Player")
	if is_instance_valid(found):
		return [found]
 
	push_error("World.gd findPlayersToSave(): no Player node found in tree.")
	return []
 
 
 
 
 
 
 
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
 
 
 
const BOT_SAVE_DIR := "user://BotSaves/"

func getBotSaveDir() -> String:
	return BOT_SAVE_DIR + world_id + "/"

func getBotSavePath(bot_node_name:String) -> String:
	return getBotSaveDir() + bot_node_name + ".save"

func saveBotFor(bot:Node, data:Dictionary) -> void:
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return
	if !is_instance_valid(bot):
		return
	queueFileWrite(getBotSavePath(bot.name), data)

func readBotSave(bot_node_name:String) -> Dictionary:
	var path = getBotSavePath(bot_node_name)
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
 
func savePlayerData(player:Node, base_dir:String) -> void:
	if !("entity_name" in player) or player.entity_name == "":
		push_error("World.gd savePlayerData(): player has no entity_name, skipping.")
		return
	if "data_fully_loaded" in player and !player.data_fully_loaded:
		return # never overwrite a good save with a not-yet-restored node
 
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
		var snapshot = Global.equipment_cache.get(player.entity_name, {})
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
			# FIX: same "data_fully_loaded" gate every other per-player system
			# (Inventory, Stats, Quests) already has. Without it, this direct
			# (non-RPC) save path for the HOST's own local player could fire
			# during an autosave tick before the skillbar's own load/snapshot
			# had actually finished applying, capturing a blank grid and
			# permanently overwriting the real save -- this was the actual
			# cause of skills (including basic defaults) vanishing.
			var skillbar_owner_ready = !("data_fully_loaded" in player) or player.data_fully_loaded
			if is_remote_player:
				skillbar_node.rpc_id(player.get_network_master(), "requestSelfSaveSkillbar")
			elif skillbar_owner_ready:
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
 
 
	var crafting_node = ui.get_node_or_null("Crafting")
	if is_instance_valid(crafting_node):
		if is_remote_player:
			crafting_node.rpc_id(player.get_network_master(), "requestSelfSaveCrafting")
		else:
			saveCraftingTo(crafting_node, player_dir, world_id)
 
 
	var friends_node = ui.get_node_or_null("Friends")
	if is_instance_valid(friends_node):
		if is_remote_player:
			friends_node.rpc_id(player.get_network_master(), "requestSelfSaveFriends")
		else:
			saveFriendsTo(friends_node, player.entity_name)
 
	var loot_node = player.get_node_or_null("UI/Loot")
	if is_instance_valid(loot_node):
		if is_remote_player:
			loot_node.rpc_id(player.get_network_master(), "requestSelfSaveLoot")
		else:
			saveLootTo(loot_node, player.entity_name, world_id)
 
	var quest_node = player.get_node_or_null("UI/QuestSystem")
	if is_instance_valid(quest_node):
		if is_remote_player:
			quest_node.rpc_id(player.get_network_master(), "requestSelfSaveQuests")
		else:
			saveQuestsTo(quest_node, player.entity_name)
 
	 var party_node = ui.get_node_or_null("Party")
		if is_instance_valid(party_node):
			if is_remote_player:
				party_node.rpc_id(player.get_network_master(), "requestSelfSaveParty")
			else:
				savePartyTo(party_node, player.entity_name)
	 
 
 
 
 
 
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
 
 
 
 
 
 
 
 
 
 
 
func saveCraftingTo(crafting_node:Node, player_dir:String, wid:String) -> void:
	if !is_instance_valid(crafting_node) or !crafting_node.has_method("gatherCraftingSnapshot"):
		return
	_writeCraftingToDir(player_dir, crafting_node.gatherCraftingSnapshot(), wid)
 
func saveCraftingFor(player:Node, data:Dictionary, wid:String) -> void:
	if !is_instance_valid(player) or !("entity_name" in player) or player.entity_name == "":
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		rpc_id(1, "requestSaveCrafting", player.entity_name, data, wid)
		return
	_writeCraftingToDir(getPlayerSaveBaseDir() + player.entity_name + "/", data, wid)
 
remote func requestSaveCrafting(entity_name:String, data:Dictionary, wid:String) -> void:
	if !get_tree().is_network_server():
		return
	_writeCraftingToDir(getPlayerSaveBaseDir() + entity_name + "/", data, wid)
 

 
func readCraftingSave(path:String) -> Dictionary:
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
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
# World.gd — add alongside saveFriendsTo/saveCraftingTo etc.
 
func getLootSaveDir(entity_name:String) -> String:
	return getPlayerSaveBaseDir() + entity_name + "/"
 
func saveLootTo(loot_node:Node, entity_name:String, wid:String) -> void:
	if !is_instance_valid(loot_node) or !loot_node.has_method("gatherLootSnapshot"):
		return
	_writeLootToDir(getLootSaveDir(entity_name), loot_node.gatherLootSnapshot(), wid)
 
func saveLootFor(player:Node, data:Dictionary, wid:String) -> void:
	if !is_instance_valid(player) or !("entity_name" in player) or player.entity_name == "":
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		rpc_id(1, "requestSaveLoot", player.entity_name, data, wid)
		return
	_writeLootToDir(getLootSaveDir(player.entity_name), data, wid)
 
remote func requestSaveLoot(entity_name:String, data:Dictionary, wid:String) -> void:
	if !get_tree().is_network_server():
		return
	_writeLootToDir(getLootSaveDir(entity_name), data, wid)
 

 
func readLootSave(path:String) -> Dictionary:
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
 
 
 
 
 
 
 
 
 
func getQuestsSaveDir(entity_name:String) -> String:
	return getPlayerSaveBaseDir() + entity_name + "/"
 
func saveQuestsTo(quest_node:Node, entity_name:String) -> void:
	if !is_instance_valid(quest_node) or !quest_node.has_method("gatherQuestSnapshot"):
		return
	_writeQuestsToDir(getQuestsSaveDir(entity_name), quest_node.gatherQuestSnapshot())
 
func saveQuestsFor(player:Node, data:Dictionary) -> void:
	if !is_instance_valid(player) or !("entity_name" in player) or player.entity_name == "":
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		rpc_id(1, "requestSaveQuests", player.entity_name, data)
		return
	_writeQuestsToDir(getQuestsSaveDir(player.entity_name), data)
 
remote func requestSaveQuests(entity_name:String, data:Dictionary) -> void:
	if !get_tree().is_network_server():
		return
	_writeQuestsToDir(getQuestsSaveDir(entity_name), data)
 

 
func readQuestsSave(path:String) -> Dictionary:
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
 
 
 
 
 
 
 
 
 
func getBannerSaveDir() -> String:
	return getPlayerSaveBaseDir() # server-wide, not per-map/per-player
 
func saveBannerRosters(rosters:Dictionary) -> void:
	var dir_path = getBannerSaveDir()
	var dir := Directory.new()
	if !dir.dir_exists(dir_path):
		dir.make_dir_recursive(dir_path)
	var file := File.new()
	if file.open(dir_path + "banners.save", File.WRITE) == OK:
		file.store_var(rosters)
		file.close()
 
func readBannerRosters() -> Dictionary:
	var path = getBannerSaveDir() + "banners.save"
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
 
 
 
 
 
 
 
 
 
 
 
 
 
 
func getFriendsSaveDir(entity_name:String) -> String:
	return getPlayerSaveBaseDir() + entity_name + "/"
 
func saveFriendsTo(friends_node:Node, entity_name:String) -> void:
	if !is_instance_valid(friends_node) or !friends_node.has_method("gatherFriendsSnapshot"):
		return
	_writeFriendsToDir(getFriendsSaveDir(entity_name), friends_node.gatherFriendsSnapshot())
 
func saveFriendsFor(player:Node, data:Dictionary) -> void:
	if !is_instance_valid(player) or !("entity_name" in player) or player.entity_name == "":
		return
	if get_tree().network_peer != null and !get_tree().is_network_server():
		rpc_id(1, "requestSaveFriends", player.entity_name, data)
		return
	_writeFriendsToDir(getFriendsSaveDir(player.entity_name), data)
 
remote func requestSaveFriends(entity_name:String, data:Dictionary) -> void:
	if !get_tree().is_network_server():
		return
	_writeFriendsToDir(getFriendsSaveDir(entity_name), data)

 
func readFriendsSave(path:String) -> Dictionary:
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
	queueFileWrite(player_dir + "equipment.save", data)
 
 
 
 
 
 
 
 

func saveInventoryTo(inventory:Node, player_dir:String) -> void:
	if !is_instance_valid(inventory):
		return
 
	var data := {
		"visible": inventory.visible,
		"coins": inventory.coins,
	#	"max_inventory_slots": inventory.max_inventory_slots,
		"slots": {}
	}
 
	# Coins on disk should always reflect the SERVER's ledger, not
	# whatever the client's local mirror currently shows (display can lag
	# a round trip behind after a buy/sell). Only overrides when we're
	# actually online and have an entity_name to look up.
	if get_tree().network_peer != null and "player" in inventory and is_instance_valid(inventory.player):
		var entity_name = inventory.player.entity_name
		if entity_name != "":
			data["coins"] = Global.getBalance(entity_name)
 
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
	_writeInventoryToDir(getPlayerSaveBaseDir() + entity_name + "/", data, entity_name)
 

 
 
 
 
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
	queueFileWrite(player_dir + "equipment.save", data)
 
 
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
			snapshot = Global.getDefaultEquipmentSnapshot()
		if equipment.has_method("applyOwnEquipmentSnapshot"):
			equipment.applyOwnEquipmentSnapshot(snapshot)
	else:
		push_error("World.gd loadPlayerData(): 'UI/Equipment' not found for " + player.entity_name)

	yield(get_tree(), "idle_frame")
 
	var inventory = ui.get_node_or_null("Inventory")
	if is_instance_valid(inventory):
		var inv_snapshot = readInventorySave(base_dir + player.entity_name + "/inventory.save")
		if inventory.has_method("applyOwnInventorySnapshot"):
			var inv_state = inventory.applyOwnInventorySnapshot(inv_snapshot)
			if inv_state is GDScriptFunctionState:
				yield(inv_state, "completed")
	else:
		push_error("World.gd loadPlayerData(): 'UI/Inventory' not found for " + player.entity_name)

	yield(get_tree(), "idle_frame")

	var skillbar = ui.get_node_or_null("Skillbar")
	if is_instance_valid(skillbar):
		var sb_snapshot = readSkillbarSave(base_dir + player.entity_name + "/skillbar.save")
		if skillbar.has_method("applyOwnSkillbarSnapshot"):
			skillbar.applyOwnSkillbarSnapshot(sb_snapshot)

	yield(get_tree(), "idle_frame")

	var stats_node2 = player.get_node_or_null("Stats")
	if is_instance_valid(stats_node2):
		var stats_snapshot = readStatsSave(base_dir + player.entity_name + "/playerstats.save")
		if !stats_snapshot.empty() and stats_node2.has_method("applyOwnStatsSnapshot"):
			stats_node2.applyOwnStatsSnapshot(stats_snapshot)

	yield(get_tree(), "idle_frame")
 
	var crafting = ui.get_node_or_null("Crafting")
	if is_instance_valid(crafting):
		var craft_snapshot = readCraftingSave(base_dir + player.entity_name + "/crafting_" + world_id + ".save")
		if !craft_snapshot.empty() and crafting.has_method("applyOwnCraftingSnapshot"):
			crafting.applyOwnCraftingSnapshot(craft_snapshot)

	yield(get_tree(), "idle_frame")
 
	var friends = ui.get_node_or_null("Friends")
	if is_instance_valid(friends):
		var friends_snapshot = readFriendsSave(getFriendsSaveDir(player.entity_name) + "friends.save")
		if !friends_snapshot.empty() and friends.has_method("applyOwnFriendsSnapshot"):
			friends.applyOwnFriendsSnapshot(friends_snapshot)

	yield(get_tree(), "idle_frame")
 
	var loot = ui.get_node_or_null("Loot")
	if is_instance_valid(loot):
		var loot_snapshot = readLootSave(getLootSaveDir(player.entity_name) + "corpse_loot_" + world_id + ".save")
		if !loot_snapshot.empty() and loot.has_method("applyOwnLootSnapshot"):
			loot.applyOwnLootSnapshot(loot_snapshot)

	yield(get_tree(), "idle_frame")
 
	var quests = ui.get_node_or_null("QuestSystem")
	if is_instance_valid(quests):
		var quest_snapshot = readQuestsSave(getQuestsSaveDir(player.entity_name) + "quests.save")
		if !quest_snapshot.empty() and quests.has_method("applyOwnQuestSnapshot"):
			quests.applyOwnQuestSnapshot(quest_snapshot)
	var party = ui.get_node_or_null("Party")
	if is_instance_valid(party):
		var party_snapshot = readPartySave(getPartySaveDir(player.entity_name) + "party.save")
		if !party_snapshot.empty() and party.has_method("applyOwnPartySnapshot"):
			party.applyOwnPartySnapshot(party_snapshot)

	yield(get_tree(), "idle_frame")




 
 
 
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
 
var resource_states := {}
 
func loadResourceStatesFile():
	var path = getMobSaveBaseDir() + world_id + "/resources.save"
	var file = File.new()
	if file.file_exists(path) and file.open(path, File.READ) == OK:
		resource_states = file.get_var()
		file.close()
	else:
		resource_states = {}
 
func staggeredSaveMobData() -> void:
	var saveDirectory = getMobSaveBaseDir() + world_id + "/"
	var savePath = saveDirectory + world_id + ".save"

	var old_data = {}
	var old_file = File.new()
	if old_file.file_exists(savePath) and old_file.open(savePath, File.READ) == OK:
		old_data = old_file.get_var()
		old_file.close()

	var mob_list := []
	for entity in getAllEntities():
		if is_instance_valid(entity) and !entity.is_in_group("Player"):
			mob_list.append(entity)

	var batch_count = max(1, int(ceil(float(mob_list.size()) / float(max(autosave_entities_per_batch, 1)))))
	var delay_between_batches = autosave_min_spread_time / float(batch_count)

	var entityData := []
	var n := 0
	for entity in mob_list:
		if !is_instance_valid(entity):
			continue
		var entry = buildSaveEntry(entity)
		entry["world_id"] = world_id
		entityData.append(entry)
		n += 1
		if n % autosave_entities_per_batch == 0:
			yield(get_tree().create_timer(delay_between_batches), "timeout")

	old_data["mobs"] = entityData

	# FIX: this was a synchronous File.open()/store_var()/close() right
	# here on the main thread, serializing ~150 mobs' worth of data in
	# one blocking call every autosave cycle. Any main-thread stall is
	# exactly what tips Godot's physics catch-up into the runaway spiral
	# described in Global.gd._ready(). Route through the background
	# write thread like every other save path already does.
	queueFileWrite(savePath, old_data)

	saveResourceStates()


func saveResourceStates() -> void:
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

	var saveDirectory = getMobSaveBaseDir() + world_id + "/"
	var path = saveDirectory + "resources.save"

	# FIX: same synchronous-write-on-main-thread problem as
	# staggeredSaveMobData() above. Moved to the background thread.
	queueFileWrite(path, resource_states)


func saveData():
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return
	print("world.gd saved data")
	var saveDirectory = getMobSaveBaseDir() + world_id + "/"
	var savePath = saveDirectory + world_id + ".save"

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

	# FIX: was a synchronous main-thread write (manual "savedata" key,
	# portal, respawn) -- same runaway-catch-up risk. Queued instead.
	queueFileWrite(savePath, old_data)
	saveResourceStates()
	savePlayers()
	Global.saveListings()
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
 
func _exit_tree() -> void:
	stopFileWriteThread()
 
func buildFullPlayerSnapshot(entity_name:String, world_id:String) -> Dictionary:
	var base_dir = getPlayerSaveBaseDir()
	var player_dir = base_dir + entity_name + "/"
 
	var equipment_snapshot = readEquipmentSave(player_dir + "equipment.save")
	if equipment_snapshot.empty():
		equipment_snapshot = Global.getDefaultEquipmentSnapshot()
 
	var inventory_snapshot = readInventorySave(player_dir + "inventory.save")
	# Coins are always authoritative from AuctionHouseData's ledger, never
	# whatever number is sitting in the save file -- same rule
	# _writeInventoryToDir() already applies on the save side. Seed the
	# ledger from disk the first time this entity_name is ever seen this
	# server run, then always hand back the ledger's live number.
	if get_tree().network_peer != null:
		Global.seedBalanceIfAbsent(entity_name, int(inventory_snapshot.get("coins", 0)))
		inventory_snapshot["coins"] = Global.getBalance(entity_name)
 
	return {
		"equipment": equipment_snapshot,
		"inventory": inventory_snapshot,
		"skillbar": readSkillbarSave(player_dir + "skillbar.save"),
		"stats": readStatsSave(player_dir + "playerstats.save"),
		"crafting": readCraftingSave(player_dir + "crafting_" + world_id + ".save"),
		"friends": readFriendsSave(player_dir + "friends.save"),
		"state": readPlayerStateSave(player_dir + "playerstate.save"),
		"loot": readLootSave(player_dir + "corpse_loot_" + world_id + ".save"),
		"quests": readQuestsSave(player_dir + "quests.save"),
		"party": readPartySave(getPartySaveDir(entity_name) + "party.save"),
	}
 
 
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
			mob.freezeAtDeathPose()
			Global.setCorpseCollisionState(mob, true)
 
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
var _node_name_cache := {}
var _node_name_cache_built := false

export var node_name_cache_nodes_per_frame := 500

func buildNodeNameCache() -> void:
	_node_name_cache.clear()
	_node_name_cache_built = false
	var stack := []
	for spawnpoint in cached_spawnpoints:
		if is_instance_valid(spawnpoint):
			stack.append(spawnpoint)

	var processed := 0
	while !stack.empty():
		var node = stack.pop_back()
		if !is_instance_valid(node):
			continue
		if !_node_name_cache.has(node.name):
			_node_name_cache[node.name] = node
		for child in node.get_children():
			stack.append(child)
		processed += 1
		if processed >= node_name_cache_nodes_per_frame:
			processed = 0
			yield(get_tree(), "idle_frame")

	_node_name_cache_built = true


func findNodeByName(node_name:String, root=null):
	# root param kept for signature compatibility; cache is scoped to
	# the whole World tree either way, which matches every real caller
	# (loadMob's parent_name lookup, findEntity()) since they always
	# searched from World's root.
	if !_node_name_cache_built:
		buildNodeNameCache()
	if _node_name_cache.has(node_name):
		var cached = _node_name_cache[node_name]
		if is_instance_valid(cached):
			return cached
		_node_name_cache.erase(node_name)
		buildNodeNameCache()
		return _node_name_cache.get(node_name, null)
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
 
 
 
 
func resolveSpawnPositionForPlayer(entity_name:String, saved_world_id:String) -> Vector3:
	var state_path = getPlayerSaveBaseDir() + entity_name + "/playerstate.save"
	if !File.new().file_exists(state_path):
		return getPlayerStartPosition()
 
	var state_data = readPlayerStateSave(state_path)
	if state_data.empty():
		return getPlayerStartPosition()
 
	var positions = state_data.get("positions", {})
	if typeof(positions) == TYPE_DICTIONARY and positions.has(saved_world_id):
		return positions[saved_world_id]
 
	return getPlayerStartPosition()
 
 
 
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
		if Global.isKnownWorldId(g):
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
 


var _pending_save_queue := []
export var saves_per_frame := 1

# Replaces the direct saveRecursive(self) call in the autosave branch of
# _physics_process(). Scans (same as before, cheap) but instead of writing
# every node's file in this one frame, queues them up for a few-per-frame
# drain -- spreads the actual disk I/O across ~(node_count / saves_per_frame)
# frames instead of spiking all of it into a single tick.
func queueSaveRecursive(node) -> void:
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return
	scanSaveableNodes(node)
	_pending_save_queue = cached_saveable_nodes.duplicate()

func processSaveQueue() -> void:
	if _pending_save_queue.empty():
		return
	var n := 0
	while n < saves_per_frame and !_pending_save_queue.empty():
		var saveable = _pending_save_queue.pop_back()
		if is_instance_valid(saveable):
			saveable.saveData()
		n += 1
		
		
		
		
		
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
 
	var path = Global.getScenePath(dest_world_id)
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
 
#
func finishPortalLoad(packed_scene:PackedScene) -> void:
	Global.resetForWorldChange()
	var dest_world = packed_scene.instance()
	dest_world.world_id = portal_dest_world_id
	dest_world.skip_offline_autospawn = true
	var is_respawn = _respawning_to_graveyard 
	_respawning_to_graveyard = false
 
	var tree = get_tree()
	tree.root.add_child(dest_world)
	tree.current_scene = dest_world
 
	if tree.network_peer != null:
		for child in get_children():
			if child.is_in_group("Player") and "entity_name" in child and child.entity_name == Global.selected_player_name:
				remove_child(child)
				child.queue_free()
				break
 
		if is_respawn:
			Global.rpc_id(1, "requestRespawnPortal", portal_dest_world_id)
		else:
			Global.rpc_id(1, "requestPortal", portal_dest_world_id)
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
 
	var spawn_pos
	if is_respawn:
		spawn_pos = dest_world.getRespawnPosition(Vector3.ZERO)
	else:
		spawn_pos = dest_world._resolvePortalSpawnPosition(dest_world, world_id)
 
	remove_child(local_player)
	dest_world.add_child(local_player)
	local_player.translation = spawn_pos
	local_player.which_scene = portal_dest_world_id
	local_player.disableFallDamage()
	local_player.portal_grace_timer = 1.0
	if local_player.has_method("reactivateAnimationTree"):
		local_player.reactivateAnimationTree()
	if is_respawn and local_player.has_method("reviveAfterRespawn"):
		local_player.reviveAfterRespawn()
 
	dest_world.saveLastWorldId(portal_dest_world_id)
	if local_player.has_method("saveData"):
		local_player.saveData()
 
	tree.root.remove_child(self)
	queue_free()
 
	changing_scene = false
	_waitForPlayerReadyThenHide(dest_world)
 
 
func _waitForPlayerReadyThenHide(world:Node) -> void:
	if Global.isPlayerReady():
		if is_instance_valid(world):
			world.hideLoadscreen()
		return
	if !Global.is_connected("player_ready", self, "_onPortalPlayerReady"):
		Global.connect("player_ready", self, "_onPortalPlayerReady", [world], CONNECT_ONESHOT)
	yield(get_tree().create_timer(10.0), "timeout")
	if is_instance_valid(world) and world.loading_screen.visible:
		world.hideLoadscreen()
 
func _onPortalPlayerReady(world:Node) -> void:
	if is_instance_valid(world):
		world.hideLoadscreen()
 
 
 
var cached_respawn_nodes= []

var _respawn_cache_stack= []
var respawn_cache_nodes_per_frame:int = 45

func cacheRespawnNodes() -> void:
	if !_respawn_cache_stack.empty():
		return # a chunked build is already running, don't restart it
	cached_respawn_nodes.clear()
	_respawn_cache_stack = [self]
	buildRespawnCacheChunk()

func buildRespawnCacheChunk() -> void:
	while !_respawn_cache_stack.empty():
		var processed := 0
		while processed < respawn_cache_nodes_per_frame and !_respawn_cache_stack.empty():
			var node = _respawn_cache_stack.pop_back()
			if !is_instance_valid(node):
				continue
			if node is Occluder:
				continue
			if node is Spatial and node != self:
				var n = node.name.to_lower().replace(" ", "").replace("_", "")
				if n.find("graveyard") != -1 or n.find("respawn") != -1:
					cached_respawn_nodes.append(node)
			for child in node.get_children():
				_respawn_cache_stack.append(child)
			processed += 1
		if !_respawn_cache_stack.empty():
			yield(get_tree(), "idle_frame")










func findRespawnCandidates(root=null, results=null) -> Array:
	# Kept for API compatibility with any external caller -- now backed
	# by the cache instead of a fresh recursive walk.
	if cached_respawn_nodes.empty() and root == null:
		cacheRespawnNodes()
	return cached_respawn_nodes

func findNearestRespawnNode(from_position:Vector3) -> Spatial:
	if cached_respawn_nodes.empty():
		cacheRespawnNodes()
	var nearest = null
	var nearest_distance = INF
	for node in cached_respawn_nodes:
		if !is_instance_valid(node):
			continue
		var d = from_position.distance_squared_to(node.global_transform.origin)
		if d < nearest_distance:
			nearest_distance = d
			nearest = node
	return nearest
 
func getRespawnPosition(from_position:Vector3) -> Vector3:
	var node = findNearestRespawnNode(from_position)
	if node != null:
		return node.global_transform.origin
	return getPlayerStartPosition()
 
var _respawning_to_graveyard := false
 
func respawnToNearestGraveyard() -> void:
	if changing_scene: return
 
	var local_player = null
	for child in get_children():
		if child.is_in_group("Player") and "entity_name" in child and child.entity_name == Global.selected_player_name:
			local_player = child
			break
	if !is_instance_valid(local_player): return
 
	# 1) A graveyard/respawn node right here -- no scene change needed.
	var local_node = findNearestRespawnNode(local_player.global_transform.origin)
	if local_node != null:
		local_player.global_transform.origin = local_node.global_transform.origin
		local_player.disableFallDamage()
		if local_player.has_method("reviveAfterRespawn"):
			local_player.reviveAfterRespawn()
		if get_tree().network_peer != null and local_player.has_method("saveData"):
			local_player.saveData()
		return
 
	# 2) Already in world.tscn and still nothing -- fall back to spawn.
	if world_id == "world":
		local_player.global_transform.origin = getPlayerStartPosition()
		local_player.disableFallDamage()
		if local_player.has_method("reviveAfterRespawn"):
			local_player.reviveAfterRespawn()
		return
 
	# 3) Different world -- same loading-screen scene swap portal() uses.
	_beginRespawnPortal()
 
func _beginRespawnPortal() -> void:
	var path = Global.getScenePath("world")
	if path == "":
		push_error("World.gd respawnToNearestGraveyard(): no scene path for 'world'")
		return
	changing_scene = true
	_respawning_to_graveyard = true
	showLoadscreen()
	loading_label.text = "Loading... 0%"
	saveData()
	saveRecursive(self)
	portal_dest_world_id = "world"
	portal_real_progress = 0.0
	portal_displayed_progress = 0.0
	portal_loader = ResourceLoader.load_interactive(path)
	if portal_loader == null:
		changing_scene = false
		_respawning_to_graveyard = false
		hideLoadscreen()
		push_error("Failed to start loading " + path)
		return
	set_process(true)
 
 
 
 
 
 
 
func loadingScreenProcess(delta):
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
 
 
 
 
 
 
 
 
 
 
 
 
 
 
onready var loading_screen:Control
func wrapLoadingScreenInCanvasLayer() -> void:
	loading_screen = $LoadingScreen
	var layer := CanvasLayer.new()
	layer.name = "LoadingScreenLayer"
	layer.layer = 128 # anything above default (0/1) wins, regardless of tree order
	remove_child(loading_screen)
	layer.add_child(loading_screen)
	add_child(layer)
	loading_label = loading_screen.get_node("Label")
func showLoadscreen()->void:
	
	loading_screen.visible = true
	loading_screen.raise()

func hideLoadscreen()->void:
	loading_screen.visible = false
 
 
func worldIdFromPortalName(node:Node) -> String:
	var n = node.name.to_lower()
	var prefix = "portalto"
	var idx = n.find(prefix)
	if idx == -1:
		return ""
	var rest = n.substr(idx + prefix.length())
	for wid in Global.allWorldIds():
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
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
export var active_players_cache_refresh_interval := 15
var _active_players_cache := []
var _active_players_cache_frame := -999999
 
# World.gd — replace getActivePlayersCached()
 
func getActivePlayersCached() -> Array:
	var frame = Engine.get_physics_frames()
	if _active_players_cache_frame != -999999 and frame - _active_players_cache_frame < active_players_cache_refresh_interval:
		return _active_players_cache
 
	_active_players_cache_frame = frame
	_active_players_cache.clear()
 
	if get_tree().network_peer == null:
		var p = get_node_or_null("Player")
		if is_instance_valid(p):
			_active_players_cache.append(p)
		return _active_players_cache
 
	# Online: read straight from PlayerSpawner's own registry instead of
	# get_children() + is_in_group("Player"). That combo only works if the
	# player node is actually reparented under THIS exact World instance
	# and already tagged in the group at the moment this runs -- portal/
	# respawn/reconnect (World.gd finishPortalLoad, PlayerSpawner
	# _doSpawnPlayer reparenting) don't guarantee that lands the same
	# frame, so mobs online could see an empty/incomplete list and never
	# acquire a target. spawned_players is keyed by peer_id and already
	# tracks each player's world_id authoritatively -- same direct-
	# registry approach CommonBehaviour already uses for player cameras.
	for peer_id in Global.spawned_players.keys():
		if Global.spawned_players[peer_id]["world_id"] != world_id:
			continue
		var node = get_node_or_null(str(peer_id))
		if is_instance_valid(node):
			_active_players_cache.append(node)
 
	return _active_players_cache
 
export var shader_warmup_frames := 20
export var shader_warmup_batch_size := 12       # was 30 — smaller batches spread the cost further
export var shader_warmup_yield_frames := 6     # was 2 — more breathing room between force_draw calls
export var shader_warmup_max_total_ms := 700.0  # hard budget — never let this run past this long total

export var mesh_collect_nodes_per_frame := 600


func warmShaderCache() -> void:
	var mesh_instances := []
	var mesh_owner_root := {}   # MeshInstance instance_id -> owning "character" root Node
	var character_roots := []  # every hidden "character" root found (mobs hidden at spawn now)

	var collect_state = collectMeshInstancesForWarmupChunked(self, mesh_instances, mesh_owner_root, character_roots, null)
	if collect_state is GDScriptFunctionState:
		yield(collect_state, "completed")

	if mesh_instances.empty():
		for root in character_roots:
			if is_instance_valid(root):
				root.visible = true
		hideLoadscreen()
		return

	var valid_instances := []
	var original_visibility := []
	for mi in mesh_instances:
		if !is_instance_valid(mi):
			continue
		valid_instances.append(mi)
		original_visibility.append(mi.visible)
		mi.visible = false

	for root in character_roots:
		if is_instance_valid(root):
			root.visible = false

	if valid_instances.empty():
		for root in character_roots:
			if is_instance_valid(root):
				root.visible = true
		hideLoadscreen()
		return

	var start_ms := OS.get_ticks_msec()
	var index := 0
	var revealed_roots := {}
	while index < valid_instances.size():
		if OS.get_ticks_msec() - start_ms > shader_warmup_max_total_ms:
			for i in range(index, valid_instances.size()):
				if is_instance_valid(valid_instances[i]):
					valid_instances[i].visible = original_visibility[i]
			break

		var batch_end = min(index + shader_warmup_batch_size, valid_instances.size())

		var touched_roots := {}
		for i in range(index, batch_end):
			if !is_instance_valid(valid_instances[i]):
				continue
			var root = mesh_owner_root.get(valid_instances[i].get_instance_id())
			if root != null and is_instance_valid(root) and !revealed_roots.has(root) and !touched_roots.has(root):
				touched_roots[root] = true
				root.visible = true
			if original_visibility[i]:
				valid_instances[i].visible = true

		VisualServer.force_draw()

		for i in range(index, batch_end):
			if !is_instance_valid(valid_instances[i]):
				continue
			valid_instances[i].visible = original_visibility[i]

		for root in touched_roots.keys():
			revealed_roots[root] = true
			if is_instance_valid(root):
				root.visible = true

		index = batch_end
		for j in range(shader_warmup_yield_frames):
			yield(get_tree(), "idle_frame")

	# safety net: never leave a mob invisible forever if it fell outside budget
	for root in character_roots:
		if is_instance_valid(root) and !revealed_roots.has(root):
			root.visible = true

	hideLoadscreen()


func collectMeshInstancesForWarmupChunked(root: Node, out: Array, owner_map: Dictionary, character_roots_out: Array, current_root) -> void:
	var stack := [[root, current_root]]
	var processed := 0
	while !stack.empty():
		var entry = stack.pop_back()
		var node = entry[0]
		var owning_root = entry[1]
		if !is_instance_valid(node):
			continue
		if node is Occluder:
			continue
		if node.name == "character" and node is Spatial and !node.visible:
			character_roots_out.append(node)
			owning_root = node
		if node is MeshInstance:
			out.append(node)
			if owning_root != null:
				owner_map[node.get_instance_id()] = owning_root
		for child in node.get_children():
			if is_instance_valid(child):
				stack.append([child, owning_root])
		processed += 1
		if processed >= mesh_collect_nodes_per_frame:
			processed = 0
			yield(get_tree(), "idle_frame")
