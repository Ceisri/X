extends Node
#=============================================================================
# Global.gd — merged autoload singleton.
# Combines what used to be separate autoloads: WorldRegistry, the
# CommonBehaviour/LOD system, SpatialGrid, Network, PlayerSpawner,
# MobSync, AuctionHouseData, the Banner system, and the Items/Skills
# database. All cross-singleton calls (PlayerSpawner.x, Network.x,
# AuctionHouseData.x, SpatialGrid.x, WorldRegistry.x, MobSync.x) have been
# rewritten as local calls since everything now lives in this one script.
#=============================================================================
 
# ============================ WORLD REGISTRY ============================
const SCENES := {
	"world": "res://World.tscn",
	"mines": "res://world/terrain/mines/mines.tscn",
	"test": "res://SceneTest.tscn",
}
func getScenePath(world_id:String) -> String:
	return SCENES.get(world_id.to_lower(), "")
func isKnownWorldId(world_id:String) -> bool:
	return SCENES.has(world_id.to_lower())
func allWorldIds() -> Array:
	return SCENES.keys()
 
 
# ============================ LOD / COMMON BEHAVIOUR ============================
var krogun_scale:float = 1.2
var lod_batches: int = 16
var near_mob_count_threshold: int = 25
var near_throttled_time_scale: float = 0.4
var anim_lod_near_range: float = 60.0
var visibility_cull_range: float = 400.0
var impostor_range: float = 150.0
var impostor_pool_size: int = 700
var _impostor_multimeshes: Dictionary = {}
var _impostor_mesh_cache: Dictionary = {}
var _impostor_slot_of_mob: Dictionary = {}
var _impostor_mob_of_slot: Dictionary = {}
var _mob_species_cache: Dictionary = {}
var _mob_last_impostor_xform: Dictionary = {}
 
const CHARACTER_PATH: String = "character"
var active_mob_recount_interval: int = 24
var all_mob_recount_interval: int = 90
var anim_lod_check_interval: int = 20
var mob_hide_distance: float = 300.0         # mesh hides beyond this distance
var mob_show_distance: float = 299.0         # mesh shows again once within this distance (hysteresis)
var anim_freeze_range: float = 220.0          # beyond this: mob freezes entirely (no anim, no AI/physics ticking)
var anim_freeze_hysteresis: float = 20.0      # buffer so freeze/unfreeze can't thrash right at the boundary
 
 
var _mob_character_cache: Dictionary = {}
 
var _active_mob_list_cache: Array = []
var _active_mob_recount_frame: int = -999999
 
var _all_mob_list_cache: Array = []
var _all_mob_recount_frame: int = -999999
 
var skeleton_lod_near: float = 15
var skeleton_lod_mid: float = 45
 
var _mob_skeleton_cache: Dictionary = {}
var _mob_lod_cache: Dictionary = {}
 
var anim_lod_check_interval_min: int = 4
var anim_lod_check_interval_max: int = 120
var anim_lod_check_interval_step: int = 4
 
var anim_freeze_when_far: bool = true
var anim_lod_min_time_scale: float = 0.15
var anim_lod_time_scale_param: String = "parameters/TimeScale/scale"
 
var _mob_time_scale_cache: Dictionary = {}
 
var _active_mob_dict: Dictionary = {}   # instance_id -> mob
var _all_mob_dict: Dictionary = {}      # instance_id -> mob
var _lod_batch_index: int = 0
 
func _mobsForBatch(batch_index: int) -> Array:
	if lod_batches <= 1:
		return _all_mob_list_cache
	var result: Array = []
	var i := 0
	for mob in _all_mob_list_cache:
		if i % lod_batches == batch_index:
			result.append(mob)
		i += 1
	return result
 
func markActive(mob: Node) -> void:
	if !is_instance_valid(mob):
		return
	var id: int = mob.get_instance_id()
	_all_mob_dict[id] = mob
	_active_mob_dict[id] = mob
 
 
func markInactive(mob: Node) -> void:
	if !is_instance_valid(mob):
		return
	_active_mob_dict.erase(mob.get_instance_id())
 



var botAiFrameToken:int = -999999
var botAiRanThisFrame:Dictionary = {} # bot instance_id -> true, cleared every physics frame

# Each unique bot may call updateBotAI() at most ONCE per physics frame,
# no matter how many times it asks -- this is a per-bot dedupe, not a
# headcount. With N bots you get at most N calls total this frame,
# regardless of N. Previously this was a single shared counter with no
# notion of which bot was calling, so a handful of bots calling multiple
# times in the same frame could burn the whole per-frame budget on
# themselves while every other bot never got polled at all.
func canRunBotAIThisFrame(bot:Node) -> bool:
	var frame:int = Engine.get_physics_frames()
	if frame != botAiFrameToken:
		botAiFrameToken = frame
		botAiRanThisFrame.clear()
	var id:int = bot.get_instance_id()
	if botAiRanThisFrame.has(id):
		return false
	botAiRanThisFrame[id] = true
	return true




var _mobStatsLoadBudgetPerFrame:int = 6
var _mobStatsLoadUsedThisFrame:int = 0
var _mobStatsLoadFrame:int = -999999

func canLoadMobStatsThisFrame() -> bool:
	var frame:int = Engine.get_physics_frames()
	if frame != _mobStatsLoadFrame:
		_mobStatsLoadFrame = frame
		_mobStatsLoadUsedThisFrame = 0
	if _mobStatsLoadUsedThisFrame >= _mobStatsLoadBudgetPerFrame:
		return false
	_mobStatsLoadUsedThisFrame += 1
	return true

var _entityCacheBuildBudgetPerFrame:int = 20
var _entityCacheBuildUsedThisFrame:int = 0
var _entityCacheBuildFrame:int = -999999

func canBuildEntityCacheThisFrame() -> bool:
	var frame:int = Engine.get_physics_frames()
	if frame != _entityCacheBuildFrame:
		_entityCacheBuildFrame = frame
		_entityCacheBuildUsedThisFrame = 0
	if _entityCacheBuildUsedThisFrame >= _entityCacheBuildBudgetPerFrame:
		return false
	_entityCacheBuildUsedThisFrame += 1
	return true

var _used_bot_names := {}

func isBotNameTaken(bot_name:String) -> bool:
	return _used_bot_names.has(bot_name)

func registerBotName(bot_name:String) -> void:
	if bot_name != "":
		_used_bot_names[bot_name] = true

func unregisterBotName(bot_name:String) -> void:
	_used_bot_names.erase(bot_name)
















var _searchBudgetPerFrame:int = 6
var _searchBudgetUsedThisFrame:int = 0
var _searchBudgetFrame:int = -999999

# Global cap on expensive spatial-grid searches (findMobTarget,
# findDownedAlly, etc) executed in a single physics frame, regardless of
# how many bots/mobs want to run one this tick. Each bot already retries
# on its own short cooldown if it doesn't get a slot, so nothing is ever
# silently skipped -- it just runs a frame or few later instead of all
# bots bursting queryRadius() on the same tick.
func canRunExpensiveSearchThisFrame() -> bool:
	var frame:int = Engine.get_physics_frames()
	if frame != _searchBudgetFrame:
		_searchBudgetFrame = frame
		_searchBudgetUsedThisFrame = 0
	if _searchBudgetUsedThisFrame >= _searchBudgetPerFrame:
		return false
	_searchBudgetUsedThisFrame += 1
	return true


 
func getActiveMobCount() -> int:
	return _active_mob_dict.size()
 
 
func getActiveMobList() -> Array:
	return _active_mob_dict.values()
 
 
func rescanAllMobs() -> void:
	_all_mob_dict.clear()
	_active_mob_dict.clear()
	_all_mob_list_cache.clear()
	_active_mob_list_cache.clear()
	for world in get_tree().get_node("World"):
		if !is_instance_valid(world) or !world.has_method("getAllEntities"):
			continue
		for e in world.getAllEntities():
			if !is_instance_valid(e) or e.is_in_group("Player"):
				continue
			var id: int = e.get_instance_id()
			_all_mob_dict[id] = e
			_all_mob_list_cache.append(e)
			if "_is_relevant" in e and e._is_relevant:
				_active_mob_dict[id] = e
				_active_mob_list_cache.append(e)
	_clearLODCachesForInvalidMobs()
var losRaycastBudgetPerFrame:int = 64
var losRaycastUsedThisFrame:int = 0
var losRaycastBudgetFrame:int = -1
 
func canDoLosRaycastThisFrame() -> bool:
	var currentFrame:int = Engine.get_physics_frames()
	if currentFrame != losRaycastBudgetFrame:
		losRaycastBudgetFrame = currentFrame
		losRaycastUsedThisFrame = 0
	if losRaycastUsedThisFrame >= losRaycastBudgetPerFrame:
		return false
	losRaycastUsedThisFrame += 1
	return true
 
 
 
# 2) updateAnimationLOD — stop batching this. Batching across
# lod_batches (16) * anim_lod_check_interval (~20 frames) meant any
# given mob's animation_tree.active only got re-evaluated once every
# ~5+ seconds, while NPC.gd's own _physics_process kept moving the mob
# every frame regardless — that's the "sliding on the floor with frozen
# animation" bug. This loop is cheap (distance checks + bool toggles),
# so run it over every mob every check tick instead of 1/16th of them.
func updateAnimationLOD(batch_index: int = 0) -> void:
	if get_tree().network_peer != null and get_tree().is_network_server():
		return
	var near_range: float = anim_lod_near_range
	var freeze_range: float = max(anim_freeze_range, near_range + 0.01)
	var crowded: bool = getActiveMobCount() > near_mob_count_threshold
 
	for mob in _all_mob_list_cache:
		if !is_instance_valid(mob) or !("animation_tree" in mob) or !is_instance_valid(mob.animation_tree):
			continue
		if _isPuppetedHere(mob):
			continue
 
		var relevant: bool = ("_is_relevant" in mob) and mob._is_relevant
		if !relevant:
			_setMobAnimActive(mob, false)
			continue
 
		if "is_dead" in mob and mob.is_dead:
			_setMobAnimActive(mob, false)
			continue
 
		var in_combat: bool = mob.target != null
		var id: int = mob.get_instance_id()
		if _impostor_slot_of_mob.has(id):
			_setMobAnimActive(mob, false)
			continue
 
		var is_dying: bool = false
		if mob.has_node("Stats"):
			var mob_stats = mob.get_node("Stats")
			is_dying = is_instance_valid(mob_stats) and mob_stats.health <= 0 and !mob.is_dead
 
		if in_combat or is_dying:
			_setMobAnimActive(mob, true)
			_setMobTimeScale(mob, id, 1.0)
			continue
 
		var players: Array = getPlayersForMob(mob)
		if players.empty():
			_setMobAnimActive(mob, false)
			continue
 
		var origin: Vector3 = mob.global_transform.origin
		var nearest_sq: float = INF
		for p in players:
			if !is_instance_valid(p):
				continue
			var d: float = origin.distance_squared_to(p.global_transform.origin)
			if d < nearest_sq:
				nearest_sq = d
 
		if nearest_sq == INF:
			_setMobAnimActive(mob, false)
			continue
 
		if nearest_sq <= near_range * near_range:
			_setMobAnimActive(mob, true)
			_setMobTimeScale(mob, id, 1.0)
			continue
 
		var nearest_dist: float = sqrt(nearest_sq)
 
		if nearest_dist > freeze_range:
			_setMobAnimActive(mob, false)
			continue
 
		var t: float = clamp((nearest_dist - near_range) / (freeze_range - near_range), 0.0, 1.0)
		var scale: float = lerp(1.0, anim_lod_min_time_scale, t)
 
		_setMobAnimActive(mob, true)
		_setMobTimeScale(mob, id, scale)
func updateMobFreezeState(batchIndex: int = 0) -> void:
	for mob in _all_mob_list_cache:
		if !is_instance_valid(mob):
			continue
		if !("target" in mob) or !("stats" in mob) or !("is_frozen" in mob):
			continue
		if !is_instance_valid(mob.stats):
			continue
 
		var isDying:bool = mob.stats.health <= 0 and !mob.is_dead
 
		var hasActiveLock:bool = false
		if "anim_locks" in mob and typeof(mob.anim_locks) == TYPE_ARRAY:
			for lockState in mob.anim_locks:
				if lockState:
					hasActiveLock = true
					break
 
		if mob.is_frozen:
			# FIX: this used to assign mob._is_relevant = mob.computeRelevance()
			# directly, bypassing the mob's own relevance_fail_debounce and
			# skipping Global.markActive() -- so a single noisy check here
			# (LOS budget exhausted, a frustum plane grazing the mob) could
			# flip _is_relevant true without ever registering the mob in
			# Global's active dict, or flip it back off next tick without
			# ever un-registering it, letting the flag and the dict drift
			# out of sync. Route through the mob's own gated method instead,
			# which already keeps both in lockstep.
			if mob.has_method("refreshVisibilityAndInterval"):
				mob.refreshVisibilityAndInterval()
			if mob.target != null or isDying or hasActiveLock or mob._is_relevant:
				if mob.has_method("unfreezeMob"):
					mob.unfreezeMob()
			continue
 
		if mob.target == null and !isDying and !hasActiveLock and !mob._is_relevant:
			if mob.has_method("freezeMob"):
				mob.freezeMob()
 
 
 
func updateSkeletonLOD(batch_index: int = 0) -> void:
	if get_tree().network_peer != null and get_tree().is_network_server():
		return
 
	var player_cameras: Array = _getPlayerCameras()
	if player_cameras.empty():
		_mesh_lod_counts = {1: 0, 2: 0, 3: 0}
		_material_lod_counts = {1: 0, 2: 0, 3: 0}
		return
 
	_mesh_lod_counts = {1: 0, 2: 0, 3: 0}
	_material_lod_counts = {1: 0, 2: 0, 3: 0}
 
	for mob in _all_mob_list_cache:
		if !is_instance_valid(mob):
			continue
		var skeleton: Node = _getMobSkeleton(mob)
		if skeleton == null:
			continue
 
		var lod_nodes: Dictionary = _getMobLODNodes(mob, skeleton)
		if lod_nodes["lod1"] == null and lod_nodes["lod2"] == null and lod_nodes["lod3"] == null:
			continue
 
		var mob_pos: Vector3 = mob.global_transform.origin
		var nearest_dist: float = INF
		for cam in player_cameras:
			if !is_instance_valid(cam):
				continue
			var dist: float = mob_pos.distance_to(cam.global_transform.origin)
			if dist < nearest_dist:
				nearest_dist = dist
		if nearest_dist == INF:
			continue
 
		var lod_materials: Dictionary = _getMobLODMaterials(mob, lod_nodes)
		var bucket := 3
 
		if nearest_dist <= _eff_skeleton_lod_near:
			bucket = 1
			if lod_nodes["lod1"] != null and is_instance_valid(lod_nodes["lod1"]):
				lod_nodes["lod1"].visible = true
			if lod_nodes["lod2"] != null and is_instance_valid(lod_nodes["lod2"]):
				lod_nodes["lod2"].visible = false
			if lod_nodes["lod3"] != null and is_instance_valid(lod_nodes["lod3"]):
				lod_nodes["lod3"].visible = false
		elif nearest_dist <= _eff_skeleton_lod_mid:
			bucket = 2
			if lod_nodes["lod1"] != null and is_instance_valid(lod_nodes["lod1"]):
				lod_nodes["lod1"].visible = false
			if lod_nodes["lod2"] != null and is_instance_valid(lod_nodes["lod2"]):
				lod_nodes["lod2"].visible = true
			if lod_nodes["lod3"] != null and is_instance_valid(lod_nodes["lod3"]):
				lod_nodes["lod3"].visible = false
		else:
			bucket = 3
			if lod_nodes["lod1"] != null and is_instance_valid(lod_nodes["lod1"]):
				lod_nodes["lod1"].visible = false
			if lod_nodes["lod2"] != null and is_instance_valid(lod_nodes["lod2"]):
				lod_nodes["lod2"].visible = false
			if lod_nodes["lod3"] != null and is_instance_valid(lod_nodes["lod3"]):
				lod_nodes["lod3"].visible = true
 
		mob.set_meta("_lod_bucket", bucket)
		_mesh_lod_counts[bucket] = _mesh_lod_counts.get(bucket, 0) + 1
 
 
 
func _handleDebugInput() -> void:
	if Input.is_action_just_pressed("ui_up"):
		anim_lod_check_interval = int(clamp(anim_lod_check_interval + anim_lod_check_interval_step, anim_lod_check_interval_min, anim_lod_check_interval_max))
	elif Input.is_action_just_pressed("ui_down"):
		anim_lod_check_interval = int(clamp(anim_lod_check_interval - anim_lod_check_interval_step, anim_lod_check_interval_min, anim_lod_check_interval_max))
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
		anim_freeze_when_far = !anim_freeze_when_far
 
 
func _findWorldOf(node: Node) -> Node:
	var n: Node = node
	while n:
		if "world_id" in n and n.is_in_group("World"):
			return n
		n = n.get_parent()
	return null
 
 
func getPlayersForMob(mob: Node) -> Array:
	var world: Node = null
	if mob.has_method("getMyWorld"):
		world = mob.getMyWorld()
	if !is_instance_valid(world):
		world = _findWorldOf(mob)
	if !is_instance_valid(world):
		return []

	var world_id: String = world.world_id if "world_id" in world else ""
	if world_id == "":
		return []

	return getActivePlayersInWorld(world_id)
 
 
func getAllActivePlayers() -> Array:
	var result: Array = []
	var seen: Dictionary = {}
 
	if get_tree().network_peer == null:
		var world: Node = get_tree().current_scene
		if is_instance_valid(world):
			var p: Node = world.get_node_or_null("Player")
			if is_instance_valid(p):
				result.append(p)
		return result
 
	for peer_id in spawned_players.keys():
		var node = getPlayerNodeByPeer(peer_id)
		if is_instance_valid(node):
			var id: int = node.get_instance_id()
			if !seen.has(id):
				seen[id] = true
				result.append(node)
 
	for w in get_tree().get_nodes_in_group("World"):
		if !is_instance_valid(w):
			continue
		for child in w.get_children():
			if is_instance_valid(child) and child.is_in_group("Player"):
				var id2: int = child.get_instance_id()
				if !seen.has(id2):
					seen[id2] = true
					result.append(child)
 
	return result
 
 
func _getPlayerCameras() -> Array:
	var cams: Array = []
	for player in getAllActivePlayers():
		if !is_instance_valid(player):
			continue
		var camroot: Node = player.get_node_or_null("Camroot")
		if is_instance_valid(camroot):
			var cam: Node = camroot.get_node_or_null("h/v/Camera")
			if is_instance_valid(cam):
				cams.append(cam)
	return cams
 
 
func _getMobSpecies(mob: Node) -> String:
	var id: int = mob.get_instance_id()
	if _mob_species_cache.has(id):
		return _mob_species_cache[id]
	var species: String = ""
	var stats: Node = mob.get_node_or_null("Stats")
	if stats != null:
		species = stats.species
	_mob_species_cache[id] = species
	return species
 
 
func _getOrCreateImpostorMM(species: String, sample_mesh: Mesh, sample_material: Material) -> MultiMeshInstance:
	if _impostor_multimeshes.has(species):
		var existing: MultiMeshInstance = _impostor_multimeshes[species]
		if is_instance_valid(existing):
			return existing
		_impostor_multimeshes.erase(species)
		_impostor_mob_of_slot.erase(species)
 
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sample_mesh
	mm.instance_count = impostor_pool_size
	mm.visible_instance_count = 0
 
	var mmi: MultiMeshInstance = MultiMeshInstance.new()
	mmi.multimesh = mm
	mmi.material_override = sample_material
	mmi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
 
	get_tree().current_scene.call_deferred("add_child", mmi)
 
	_impostor_multimeshes[species] = mmi
	_impostor_mob_of_slot[species] = []
	return mmi
 
 
func _assignImpostorSlot(mob_id: int, species: String, mmi: MultiMeshInstance) -> int:
	var arr: Array = _impostor_mob_of_slot.get(species, [])
	var slot: int = arr.size()
	arr.append(mob_id)
	_impostor_mob_of_slot[species] = arr
	_impostor_slot_of_mob[mob_id] = {"species": species, "slot": slot}
	mmi.multimesh.visible_instance_count = arr.size()
	return slot
 
 
func _freeImpostorSlot(id: int) -> void:
	if !_impostor_slot_of_mob.has(id):
		return
 
	var info: Dictionary = _impostor_slot_of_mob[id]
	var species: String = info.species
	var slot: int = info.slot
 
	var mmi: MultiMeshInstance = _impostor_multimeshes.get(species)
	var arr: Array = _impostor_mob_of_slot.get(species, [])
 
	if arr.empty() or slot >= arr.size():
		_impostor_slot_of_mob.erase(id)
		_mob_last_impostor_xform.erase(id)
		return
 
	var last_index: int = arr.size() - 1
 
	if slot != last_index:
		var moved_mob_id: int = arr[last_index]
		arr[slot] = moved_mob_id
 
		var moved_info: Dictionary = _impostor_slot_of_mob.get(moved_mob_id, {})
		moved_info["slot"] = slot
		_impostor_slot_of_mob[moved_mob_id] = moved_info
 
		if is_instance_valid(mmi) and mmi.multimesh != null and _mob_last_impostor_xform.has(moved_mob_id):
			mmi.multimesh.set_instance_transform(slot, _mob_last_impostor_xform[moved_mob_id])
 
	arr.resize(last_index)
	_impostor_mob_of_slot[species] = arr
 
	if is_instance_valid(mmi) and mmi.multimesh != null:
		mmi.multimesh.visible_instance_count = arr.size()
 
	_impostor_slot_of_mob.erase(id)
	_mob_last_impostor_xform.erase(id)
var _impostor_current_ids_cycle: Dictionary = {}
 
 
 
func updateImpostors(batch_index: int = 0) -> void:
	if get_tree().network_peer != null and get_tree().is_network_server():
		return
 
	_impostor_current_ids_cycle.clear()
 
	var impostor_range_sq: float = _eff_impostor_range * _eff_impostor_range
	var far_range_sq: float = mob_hide_distance * mob_hide_distance
 
	for mob in _all_mob_list_cache:
		if !is_instance_valid(mob):
			continue
		var id: int = mob.get_instance_id()
 
		var character: Spatial = getMobCharacterNode(mob)
		if character == null:
			continue
 
		var stats: Node = mob.get_node_or_null("Stats")
		var is_dead_or_dying: bool = stats != null and stats.health <= 0
 
		var players: Array = getPlayersForMob(mob)
		var nearest_sq: float = INF
		if !players.empty():
			var origin: Vector3 = mob.global_transform.origin
			for p in players:
				if !is_instance_valid(p):
					continue
				var d: float = origin.distance_squared_to(p.global_transform.origin)
				if d < nearest_sq:
					nearest_sq = d
 
		var has_players: bool = !players.empty() and nearest_sq != INF
		var has_slot: bool = _impostor_slot_of_mob.has(id)
 
		if !has_players:
			if has_slot:
				_freeImpostorSlot(id)
				character.visible = true
			continue
 
		_impostor_current_ids_cycle[id] = true
 
		var exit_range_sq: float = impostor_range_sq * 0.49
		var effective_enter_sq: float = exit_range_sq if has_slot else impostor_range_sq
		var wants_impostor: bool = nearest_sq > effective_enter_sq and nearest_sq <= far_range_sq and !is_dead_or_dying
 
		if wants_impostor:
			var skeleton: Node = _getMobSkeleton(mob)
			if skeleton == null:
				if has_slot:
					_freeImpostorSlot(id)
					character.visible = true
				continue
 
			var lod_nodes: Dictionary = _getMobLODNodes(mob, skeleton)
			var lod3: Node = lod_nodes.get("lod3")
			if lod3 == null or !is_instance_valid(lod3) or !(lod3 is MeshInstance) or lod3.mesh == null:
				if has_slot:
					_freeImpostorSlot(id)
					character.visible = true
				continue
 
			var species: String = _getMobSpecies(mob)
			if species == "":
				if has_slot:
					_freeImpostorSlot(id)
					character.visible = true
				continue
 
			if !_impostor_mesh_cache.has(species):
				_impostor_mesh_cache[species] = lod3.mesh
 
			var mat: Material = _getMobLODMaterials(mob, lod_nodes).get("lod3")
			var mmi: MultiMeshInstance = _getOrCreateImpostorMM(species, _impostor_mesh_cache[species], mat)
			if !is_instance_valid(mmi) or mmi.multimesh == null:
				continue
 
			var slot: int
			if !has_slot:
				if _impostor_mob_of_slot.get(species, []).size() >= impostor_pool_size:
					continue
				slot = _assignImpostorSlot(id, species, mmi)
				character.visible = false
			else:
				slot = _impostor_slot_of_mob[id].slot
 
			var xform: Transform = lod3.global_transform
			mmi.multimesh.set_instance_transform(slot, xform)
			_mob_last_impostor_xform[id] = xform
		else:
			if has_slot:
				_freeImpostorSlot(id)
				character.visible = true
 
	for id in _impostor_slot_of_mob.keys():
		if !_impostor_current_ids_cycle.has(id):
			_freeImpostorSlot(id)
func _getMobSkeleton(mob: Node) -> Node:
	var id: int = mob.get_instance_id()
	if _mob_skeleton_cache.has(id):
		var cached: Node = _mob_skeleton_cache[id]
		if cached == null or !is_instance_valid(cached):
			_mob_skeleton_cache.erase(id)
			_mob_lod_cache.erase(id)
			return null
		return cached
 
	var character: Node = mob.get_node_or_null(CHARACTER_PATH)
	if character == null:
		return null
 
	var skeleton: Node = character.get_node_or_null("Skeleton")
 
	if skeleton != null and is_instance_valid(skeleton):
		_mob_skeleton_cache[id] = skeleton
 
	return skeleton
 
 
func _getMobLODNodes(mob: Node, skeleton: Node) -> Dictionary:
	var id: int = mob.get_instance_id()
	if _mob_lod_cache.has(id):
		return _mob_lod_cache[id]
 
	var lod_data: Dictionary = {
		"lod1": skeleton.get_node_or_null("LOD1"),
		"lod2": skeleton.get_node_or_null("LOD2"),
		"lod3": skeleton.get_node_or_null("LOD3")
	}
 
	_mob_lod_cache[id] = lod_data
	return lod_data
 
 
var _mob_lod_material_cache: Dictionary = {}
 
 
func _getMobLODMaterials(mob: Node, lod_nodes: Dictionary) -> Dictionary:
	var id: int = mob.get_instance_id()
	if _mob_lod_material_cache.has(id):
		return _mob_lod_material_cache[id]
 
	var materials: Dictionary = {"lod1": null, "lod2": null, "lod3": null}
	for key in materials.keys():
		var node: Node = lod_nodes.get(key)
		if node == null or !is_instance_valid(node) or !(node is MeshInstance):
			continue
		var mat: Material = node.get_surface_material(0)
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0)
		if mat is ShaderMaterial:
			materials[key] = mat
 
	_mob_lod_material_cache[id] = materials
	return materials
 
 
func _applyAlbedoLOD(material: Material, level: int) -> void:
	if material == null or !(material is ShaderMaterial):
		return
	material.set_shader_param("use_lod2_albedo", level == 2)
	material.set_shader_param("use_lod3_albedo", level == 3)
 
 
var _mesh_lod_counts: Dictionary = {1: 0, 2: 0, 3: 0}
var _material_lod_counts: Dictionary = {1: 0, 2: 0, 3: 0}
 
 
func getMeshLODCounts() -> Dictionary:
	return _mesh_lod_counts
 
 
func getMaterialLODCounts() -> Dictionary:
	return _material_lod_counts
 
 
func _clearLODCachesForInvalidMobs() -> void:
	var ids_to_remove: Array = []
	for id in _mob_skeleton_cache.keys():
		if !_mob_skeleton_cache[id] or !is_instance_valid(_mob_skeleton_cache[id]):
			ids_to_remove.append(id)
 
	for id in ids_to_remove:
		_mob_skeleton_cache.erase(id)
		_mob_lod_cache.erase(id)
		_mob_lod_material_cache.erase(id)
 
 
# A mob is puppeted on this machine whenever network_peer exists and the
# mob is not this machine's network master -- CommonBehaviour must never
# manage animation_tree.active/time-scale for those; NPC.gd's own puppet
# code already handles it every frame.
func _isPuppetedHere(mob: Node) -> bool:
	return get_tree().network_peer != null and not mob.is_network_master()
 
 
func _setMobAnimActive(mob: Node, active: bool) -> void:
	if mob.animation_tree.active != active:
		mob.animation_tree.active = active
 
 
func _setMobTimeScale(mob: Node, id: int, scale: float) -> void:
	if is_equal_approx(_mob_time_scale_cache.get(id, -1.0), scale):
		return
	_mob_time_scale_cache[id] = scale
	mob.animation_tree.set(anim_lod_time_scale_param, scale)
 
 
func resetForWorldChange() -> void:
	for species in _impostor_multimeshes.keys():
		var mmi: MultiMeshInstance = _impostor_multimeshes[species]
		if is_instance_valid(mmi):
			mmi.queue_free()
	_impostor_multimeshes.clear()
	_impostor_mesh_cache.clear()
	_impostor_slot_of_mob.clear()
	_impostor_mob_of_slot.clear()
	_mob_last_impostor_xform.clear()
 
	_mob_species_cache.clear()
	_mob_character_cache.clear()
	_mob_skeleton_cache.clear()
	_mob_lod_cache.clear()
	_mob_lod_material_cache.clear()
	_mob_time_scale_cache.clear()
 
	_all_mob_list_cache.clear()
	_active_mob_list_cache.clear()
	_active_mob_recount_frame = -999999
	_all_mob_recount_frame = -999999
 
 
func getActivePlayersForLOD() -> Array:
	return getAllActivePlayers()
 
 
func getMobCharacterNode(mob: Node) -> Spatial:
	var id: int = mob.get_instance_id()
	if _mob_character_cache.has(id):
		return _mob_character_cache[id]
	var node: Node = mob.get_node_or_null(CHARACTER_PATH)
	_mob_character_cache[id] = node if node is Spatial else null
	return _mob_character_cache[id]
 
 
var _next_id: int = 0
 
 
func spawnProjectile(scene_path: String, shooter: Node, spawn_transform = null) -> Node:
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return null
	if !is_instance_valid(shooter):
		return null
 
	var world: Node = _findWorldFor(shooter)
	if world == null:
		return null
 
	var use_transform: Transform = spawn_transform if spawn_transform != null else shooter.global_transform
 
	_next_id += 1
	var node_name: String = "Projectile_" + str(_next_id)
 
	if get_tree().network_peer != null:
		var shooter_path: NodePath = world.get_path_to(shooter)
		rpc("spawnProjectileRemote", scene_path, world.world_id, node_name, shooter_path, use_transform)
 
	return _instanceLocal(scene_path, world, node_name, shooter, use_transform)
 
 
remote func spawnProjectileRemote(scene_path: String, world_id: String, node_name: String, shooter_path: NodePath, spawn_transform: Transform) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	if get_tree().is_network_server():
		return
 
	var world: Node = _getWorldById(world_id)
	if world == null:
		return
	if world.has_node(node_name):
		return
 
	var shooter: Node = world.get_node_or_null(shooter_path)
	_instanceLocal(scene_path, world, node_name, shooter, spawn_transform)
 
 
func _instanceLocal(scene_path: String, world: Node, node_name: String, shooter: Node, spawn_transform: Transform) -> Node:
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return null
 
	var node: Node = scene.instance()
	node.name = node_name
 
	if "shooter" in node:
		node.shooter = shooter
	node.transform = spawn_transform
 
	world.add_child(node)
 
	if get_tree().network_peer != null:
		node.set_network_master(1, true)
 
	return node
 
 
func _findWorldFor(node: Node) -> Node:
	var n: Node = node
	while n:
		if n.is_in_group("World") and "world_id" in n:
			return n
		n = n.get_parent()
	return null
 
 
var _world_players_cache: Dictionary = {} # world_id -> Array, rebuilt at most once per physics frame
var _world_players_cache_frame: int = -1
 
func getActivePlayersInWorld(world_id: String) -> Array:
	var frame: int = Engine.get_physics_frames()
	if frame != _world_players_cache_frame:
		_world_players_cache.clear()
		_world_players_cache_frame = frame
	if _world_players_cache.has(world_id):
		return _world_players_cache[world_id]
 
	var result: Array = []
	var seen: Dictionary = {}
	var world: Node = _getWorldById(world_id)
	if is_instance_valid(world):
		for child in world.get_children():
			if is_instance_valid(child) and child.is_in_group("Player"):
				var id: int = child.get_instance_id()
				if !seen.has(id):
					seen[id] = true
					result.append(child)
	if get_tree().network_peer != null:
		for peer_id in spawned_players.keys():
			var data = spawned_players[peer_id]
			if data.get("world_id", "") != world_id:
				continue
			var node = getPlayerNodeByPeer(peer_id)
			if is_instance_valid(node):
				var id2: int = node.get_instance_id()
				if !seen.has(id2):
					seen[id2] = true
					result.append(node)
 
	_world_players_cache[world_id] = result
	return result
 
func _getWorldById(world_id: String) -> Node:
	for w in get_tree().get_nodes_in_group("World"):
		if is_instance_valid(w) and "world_id" in w and w.world_id == world_id:
			return w
	return null
 
 
# ============================ SPATIAL GRID ============================
var cell_size:float = 48.0
# world_id -> { cell_key_int: {instance_id: node} }
var _grid:Dictionary = {}
# instance_id -> {"world_id":String, "cell":Vector3, "node":Spatial}
var _entry:Dictionary = {}
 
func cellCoord(pos:Vector3) -> Vector3:
	return Vector3(floor(pos.x / cell_size), 0, floor(pos.z / cell_size))
 
func cellKey(cell:Vector3) -> int: # packed int key -- cheaper than string concat per call
	return (int(cell.x) + 200000) * 400000 + (int(cell.z) + 200000)
 
func register(node:Spatial, world_id:String) -> void:
	if !is_instance_valid(node):
		return
	var id:int = node.get_instance_id()
	var pos:Vector3 = node.global_transform.origin
	var cell:Vector3 = cellCoord(pos)
	_entry[id] = {"world_id": world_id, "cell": cell, "node": node}
	ensureBucket(world_id, cell)[id] = node
 
func unregister(node:Spatial) -> void:
	if !is_instance_valid(node):
		unregisterById(node.get_instance_id() if node else -1)
		return
	unregisterById(node.get_instance_id())
 
func unregisterById(id:int) -> void:
	if !_entry.has(id):
		return
	var e:Dictionary = _entry[id]
	var world_buckets:Dictionary = _grid.get(e["world_id"], {})
	var bucket = world_buckets.get(cellKey(e["cell"]))
	if bucket != null:
		bucket.erase(id)
	_entry.erase(id)
	_entity_group_cache.erase(id)
 
func ensureBucket(world_id:String, cell:Vector3) -> Dictionary:
	if !_grid.has(world_id):
		_grid[world_id] = {}
	var key:int = cellKey(cell)
	if !_grid[world_id].has(key):
		_grid[world_id][key] = {}
	return _grid[world_id][key]
 
# Call whenever a registered node moves (cheap no-op if it stayed in the
# same cell, which is true almost every frame for almost every mob).
func updatePosition(node:Spatial) -> void:
	if !is_instance_valid(node):
		return
	var id:int = node.get_instance_id()
	if !_entry.has(id):
		return
	var e:Dictionary = _entry[id]
	var new_cell:Vector3 = cellCoord(node.global_transform.origin)
	if new_cell == e["cell"]:
		return
	var world_buckets:Dictionary = _grid.get(e["world_id"], {})
	var old_bucket = world_buckets.get(cellKey(e["cell"]))
	if old_bucket != null:
		old_bucket.erase(id)
	e["cell"] = new_cell
	ensureBucket(e["world_id"], new_cell)[id] = node
 
# Every registered node within `radius` of `pos` in `world_id`. Only
# scans the block of cells around pos, never the whole world roster.
func queryRadius(world_id:String, pos:Vector3, radius:float) -> Array:
	var result:Array = []
	if !_grid.has(world_id):
		return result
	var world_buckets:Dictionary = _grid[world_id]
	var span:int = int(ceil(radius / cell_size))
	var center_x:int = int(floor(pos.x / cell_size))
	var center_z:int = int(floor(pos.z / cell_size))
	var radius_sq:float = radius * radius
	for dx in range(-span, span + 1):
		var cx:int = center_x + dx
		for dz in range(-span, span + 1):
			var key:int = (cx + 200000) * 400000 + (center_z + dz + 200000)
			var bucket = world_buckets.get(key)
			if bucket == null:
				continue
			for id in bucket:
				var node:Spatial = bucket[id]
				if !is_instance_valid(node):
					continue
				if node.global_transform.origin.distance_squared_to(pos) <= radius_sq:
					result.append(node)
	return result
 
var _species_skill_entries_cache: Dictionary = {} # species -> Array of [skill_name, path, base_cooldown]

func getSpeciesSkillEntries(species:String) -> Array:
	if _species_skill_entries_cache.has(species):
		return _species_skill_entries_cache[species]
	var entries := []
	if skills_by_species.has(species):
		for skill_name in skills_by_species[species]:
			var res = skills.get(skill_name, null)
			if res == null:
				continue
			entries.append([skill_name, res.resource_path, getCooldown(res.resource_path)])
	_species_skill_entries_cache[species] = entries
	return entries



func countNearby(world_id:String, pos:Vector3, radius:float) -> int:
	return queryRadius(world_id, pos, radius).size()
 
func clearWorld(world_id:String) -> void:
	if !_grid.has(world_id):
		return
	var world_buckets:Dictionary = _grid[world_id]
	for key in world_buckets.keys():
		var bucket:Dictionary = world_buckets[key]
		for id in bucket.keys():
			_entry.erase(id)
	_grid.erase(world_id)
 
 
# ============================ NETWORK ============================
const DEFAULT_PORT := 8910
const MAX_PLAYERS := 100
 
signal player_connected(id)
signal player_disconnected(id)
signal server_started()
signal connected_to_server()
signal connection_failed()
signal server_disconnected()
 
var is_server := false
 
# ---- manual RTT tracking (ENetPacketPeer stats aren't exposed to GDScript) ----
var _ping_sent_at := {}
var _last_rtt := {}
var ping_interval := 2.0
var _ping_timer := 0.0
 
remote func _receivePing() -> void:
	rpc_id(1, "_receivePong")
 
remote func _receivePong() -> void:
	if !is_server:
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if !_ping_sent_at.has(sender_id):
		return
	_last_rtt[sender_id] = OS.get_ticks_msec() - _ping_sent_at[sender_id]
	_ping_sent_at.erase(sender_id)
 
func getPingMs(peer_id:int) -> int:
	return _last_rtt.get(peer_id, -1)
 
 
func _checkServerLaunchFlag() -> void:
	if OS.has_feature("editor"):
		return # editor already handles the positional-scene-arg case itself
	for arg in OS.get_cmdline_args():
		if arg == "--server":
			call_deferred("_bootServerScene")
			return
 
func _bootServerScene() -> void:
	get_tree().change_scene("res://Server.tscn")
 
# Call once, from Server.gd, to start listening.
func start_server(port:int = DEFAULT_PORT, max_players:int = MAX_PLAYERS) -> void:
	var peer := NetworkedMultiplayerENet.new()
	var err := peer.create_server(port, max_players)
	if err != OK:
		print("Network: failed to start server (error ", err, ")")
		return
	get_tree().network_peer = peer
	is_server = true
	print("Network: server listening on port ", port)
	emit_signal("server_started")
 
# Call from a client to connect to a running server.
func join_server(ip:String, port:int = DEFAULT_PORT) -> void:
	remember_target(ip, port)
	var peer := NetworkedMultiplayerENet.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		print("Network: failed to create client (error ", err, ")")
		emit_signal("connection_failed")
		return
	get_tree().network_peer = peer
	is_server = false
 
func disconnect_network() -> void:
	if get_tree().network_peer:
		intentional_disconnect = true
		get_tree().network_peer.close_connection()
		get_tree().network_peer = null
 
# Handles both Network's own peer-connected bookkeeping AND MobSync's
# catch-up push for a freshly joined peer (both used to be separately
# named "_on_peer_connected" -- merged into one so the connect() in
# _ready() only needs to fire once).
func _on_peer_connected(id:int) -> void:
	print("Network: peer connected -> ", id)
	emit_signal("player_connected", id)
	if get_tree().is_network_server():
		call_deferred("deferredSendMobBatch", id)
 
func _on_peer_disconnected(id:int) -> void:
	print("Network: peer disconnected -> ", id)
	emit_signal("player_disconnected", id)
	ready_peers.erase(id)
 
func _on_connected_ok() -> void:
	print("Network: connected to server")
	emit_signal("connected_to_server")
 
func _on_connection_failed() -> void:
	print("Network: connection failed")
	emit_signal("connection_failed")
 
func _on_server_disconnected() -> void:
	print("Network: lost connection to server")
	emit_signal("server_disconnected")
	if intentional_disconnect:
		intentional_disconnect = false
		return
	if is_server:
		return # the server itself doesn't "reconnect" to anything
	emit_signal("connection_lost")
	_startReconnecting()
 
# Renamed from "player_ready(id)" to "peer_ready(id)" -- it collided with
# the unrelated, argument-less "player_ready" signal further down (the
# local "finished loading" flag). Same behavior, different name only.
signal peer_ready(id)
var ready_peers := {}
 
remote func notify_ready() -> void:
	var id = get_tree().get_rpc_sender_id()
	if id == 0: id = 1
	ready_peers[id] = true
	emit_signal("peer_ready", id)
 
func is_peer_ready(id:int) -> bool:
	return ready_peers.get(id, false)
 
func mark_client_ready() -> void:
	rpc_id(1, "notify_ready")
 
var last_ip := ""
var last_port := DEFAULT_PORT
var is_reconnecting := false
var reconnect_attempts := 0
var max_reconnect_attempts := 10
var reconnect_interval := 3.0
var intentional_disconnect := false
 
signal connection_lost()
signal reconnect_attempt(attempt_number)
signal reconnected()
signal reconnect_failed()
 
func remember_target(ip:String, port:int) -> void:
	last_ip = ip
	last_port = port
 
func _startReconnecting() -> void:
	if is_reconnecting:
		return
	is_reconnecting = true
	reconnect_attempts = 0
	_attemptReconnect()
 
func _attemptReconnect() -> void:
	if !is_reconnecting:
		return
	reconnect_attempts += 1
	emit_signal("reconnect_attempt", reconnect_attempts)
 
	if reconnect_attempts > max_reconnect_attempts:
		is_reconnecting = false
		emit_signal("reconnect_failed")
		return
 
	var peer := NetworkedMultiplayerENet.new()
	var err := peer.create_client(last_ip, last_port)
	if err != OK:
		call_deferred("_scheduleNextAttempt")
		return
 
	get_tree().network_peer = peer
	is_server = false
 
	if !get_tree().is_connected("connected_to_server", self, "_onReconnectSuccess"):
		get_tree().connect("connected_to_server", self, "_onReconnectSuccess", [], CONNECT_ONESHOT)
	if !get_tree().is_connected("connection_failed", self, "_onReconnectFailed"):
		get_tree().connect("connection_failed", self, "_onReconnectFailed", [], CONNECT_ONESHOT)
 
func _onReconnectSuccess() -> void:
	if get_tree().is_connected("connection_failed", self, "_onReconnectFailed"):
		get_tree().disconnect("connection_failed", self, "_onReconnectFailed")
	is_reconnecting = false
	reconnect_attempts = 0
	emit_signal("reconnected")
	_cleanupStaleLocalPlayer()
	if selected_player_name != "":
		sendSpawnRequestOnceConnected(selected_player_name)
 
func _onReconnectFailed() -> void:
	if get_tree().is_connected("connected_to_server", self, "_onReconnectSuccess"):
		get_tree().disconnect("connected_to_server", self, "_onReconnectSuccess")
	get_tree().network_peer = null
	_scheduleNextAttempt()
 
func _scheduleNextAttempt() -> void:
	yield(get_tree().create_timer(reconnect_interval), "timeout")
	_attemptReconnect()
 
func _cleanupStaleLocalPlayer() -> void:
	# Reconnecting gets a new peer id, so the old player node (owned by
	# the dead peer id) is now an orphan -- remove it before the server
	# spawns a fresh one under the new id.
	var worlds = get_tree().get_nodes_in_group("World")
	if worlds.empty():
		return
	var world = worlds[0]
	for child in world.get_children():
		if child.is_in_group("Player") and "entity_name" in child and child.entity_name == selected_player_name:
			child.queue_free()
 
 
# ============================ PLAYER SPAWNER ============================
var spawned_players := {} # peer_id -> {"entity_name":String, "world_id":String}
var party_rosters := {}
var _pending_entity_name := ""
var _pending_world_id := "world"
var _last_known_roster_size := -1
const save_data_password := "kQ7$mZp2!____vLx9rT&eB4_____^wN8c___are_you_really_trying_to_crack_this_lock?J6#hY3@fD1*sG5%uA0~o_____R"
 
var player_pool_size := 100
var pool_fill_per_tick := 1
var _player_pool := []
var _player_scene:PackedScene = preload("res://world/player/scenes/Player.tscn")
var _pool_holder:Node = null
 
var pool_fill_interval := 0.5   # seconds between each pooled instance
var _pool_fill_timer := 0.0
var _pool_filling := false
 
# server's own copy's data_fully_loaded is only ever set true once the
# CLIENT confirms it applied its OWN snapshot (see reportClientFullyLoaded
# and _markPlayerFullyLoaded) -- never optimistically here, or an
# autosave in the gap can overwrite the real save with blank data.
func _sendFullSnapshotWithRetry(world:Node, peer_id:int, entity_name:String, world_id:String, has_spawn_pos:bool, attempt:int = 0) -> void:
	if !_stillValidForSnapshot(world, peer_id):
		return
 
	var snapshot = world.buildFullPlayerSnapshot(entity_name, world_id)
	if has_spawn_pos:
		snapshot.erase("state")
 
	_applySnapshotAuthority(world, peer_id, snapshot)
 
	var server_player = world.get_node_or_null(str(peer_id))
 
	if peer_id == get_tree().get_network_unique_id():
		if is_instance_valid(server_player) and server_player.has_method("applyFullSnapshot"):
			server_player.applyFullSnapshot(snapshot, has_spawn_pos)
	else:
		rpc_id(peer_id, "receiveFullSnapshot", peer_id, snapshot, has_spawn_pos)
 
	deliverPendingProceedsTo(peer_id)
 
	if attempt >= 3:
		return
 
	yield(get_tree().create_timer(snapshot_retry_timeout), "timeout")
	if !_stillValidForSnapshot(world, peer_id):
		return
	var player = world.get_node_or_null(str(peer_id))
	if is_instance_valid(player) and "data_fully_loaded" in player and !player.data_fully_loaded:
		_sendFullSnapshotWithRetry(world, peer_id, entity_name, world_id, false, attempt + 1)
 
 
func _sendLiveSnapshotToPeer(world:Node, peer_id:int, has_spawn_pos:bool, attempt:int = 0) -> void:
	if !_stillValidForSnapshot(world, peer_id):
		return
	var player = world.get_node_or_null(str(peer_id))
	if !is_instance_valid(player):
		return
 
	var snapshot := {
		"equipment": {}, "inventory": {}, "skillbar": {},
		"stats": {}, "crafting": {}, "friends": {}, "state": {}
	}
 
	var ui = player.get_node_or_null("UI")
	if is_instance_valid(ui):
		var eq = ui.get_node_or_null("Equipment")
		if is_instance_valid(eq) and eq.has_method("_buildSnapshot"):
			snapshot["equipment"] = eq._buildSnapshot()
			equipment_cache[player.entity_name] = snapshot["equipment"]
 
		var inv = ui.get_node_or_null("Inventory")
		if is_instance_valid(inv) and inv.has_method("gatherInventorySnapshot"):
			snapshot["inventory"] = inv.gatherInventorySnapshot()
 
		var sb = ui.get_node_or_null("Skillbar")
		if is_instance_valid(sb) and sb.has_method("gatherSkillbarSnapshot"):
			snapshot["skillbar"] = sb.gatherSkillbarSnapshot()
 
		var crafting_node = ui.get_node_or_null("Crafting")
		if is_instance_valid(crafting_node) and crafting_node.has_method("gatherCraftingSnapshot"):
			snapshot["crafting"] = crafting_node.gatherCraftingSnapshot()
 
		var friends_node = ui.get_node_or_null("Friends")
		if is_instance_valid(friends_node) and friends_node.has_method("gatherFriendsSnapshot"):
			snapshot["friends"] = friends_node.gatherFriendsSnapshot()
 
	var stats_node = player.get_node_or_null("Stats")
	if is_instance_valid(stats_node) and stats_node.has_method("gatherStatsSnapshot"):
		snapshot["stats"] = stats_node.gatherStatsSnapshot()
 
	if has_spawn_pos:
		snapshot.erase("state")
 
	if peer_id == get_tree().get_network_unique_id():
		if player.has_method("applyFullSnapshot"):
			player.applyFullSnapshot(snapshot, has_spawn_pos)
	else:
		rpc_id(peer_id, "receiveFullSnapshot", peer_id, snapshot, has_spawn_pos)
 
	deliverPendingProceedsTo(peer_id)
 
	if attempt >= 3:
		return
 
	yield(get_tree().create_timer(snapshot_retry_timeout), "timeout")
	if !_stillValidForSnapshot(world, peer_id):
		return
	var recheck_player = world.get_node_or_null(str(peer_id))
	if is_instance_valid(recheck_player) and "data_fully_loaded" in recheck_player and !recheck_player.data_fully_loaded:
		_sendLiveSnapshotToPeer(world, peer_id, false, attempt + 1)
 
 
remote func reportClientFullyLoaded(entity_name:String) -> void:
	if !get_tree().is_network_server():
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id == 0:
		return
	if !spawned_players.has(sender_id):
		return
	if spawned_players[sender_id]["entity_name"] != entity_name:
		return
	var data = spawned_players[sender_id]
	var world = _getWorldById(data["world_id"])
	if !is_instance_valid(world):
		return
	var server_player = world.get_node_or_null(str(sender_id))
	if is_instance_valid(server_player):
		server_player.data_fully_loaded = true
 
 
remote func setPlayerSpawnPosition(pos: Vector3) -> void:
	call_deferred("_applyClientSpawnPosition", pos, 0)
 
func _applyClientSpawnPosition(pos: Vector3, attempt:int = 0) -> void:
	var my_id = get_tree().get_network_unique_id()
	var player = getPlayerNodeByPeer(my_id)
	if !is_instance_valid(player):
		for p in get_tree().get_nodes_in_group("Player"):
			if p.get_network_master() == my_id:
				player = p
				break
	if !is_instance_valid(player):
		if attempt < 5:
			yield(get_tree().create_timer(0.2), "timeout")
			_applyClientSpawnPosition(pos, attempt + 1)
		return
	if player.has_method("setAuthoritativeSpawnPosition"):
		player.setAuthoritativeSpawnPosition(pos)
	else:
		player.global_transform.origin = pos
 



func findPartyOwnersOfMember(entity_name:String) -> Array:
	var owners := []
	for leader_name in party_rosters.keys():
		for m in party_rosters[leader_name]:
			if str(m.get("entity_name","")) == entity_name:
				owners.append(leader_name)
				break
	return owners

func findEntityNodeByName(entity_name:String) -> Node:
	if entity_name == "":
		return null
	if get_tree().network_peer != null:
		var found = getPlayerNode(entity_name)
		if is_instance_valid(found):
			return found
	for node in get_tree().get_nodes_in_group("Player"):
		if is_instance_valid(node) and "entity_name" in node and node.entity_name == entity_name:
			return node
	return null




remote func requestBotPartyInvite(bot_path:NodePath, inviter_name:String, inviter_peer:int, inviter_level:int) -> void:
	if !get_tree().is_network_server():
		return
	var bot = get_node_or_null(bot_path)
	if !is_instance_valid(bot) or !bot.has_method("receiveBotPartyInvite"):
		return
	bot.receiveBotPartyInvite(inviter_name, inviter_peer, inviter_level)

remote func onBotPartyInviteReply(bot_entity_name:String, bot_level:int, accepted:bool) -> void:
	var my_player = null
	if get_tree().network_peer == null:
		for p in get_tree().get_nodes_in_group("Player"):
			if is_instance_valid(p) and p.has_method("isLocalPlayer") and p.isLocalPlayer():
				my_player = p
				break
	else:
		if get_tree().get_rpc_sender_id() != 1:
			return
		my_player = getPlayerNodeByPeer(get_tree().get_network_unique_id())
	if !is_instance_valid(my_player):
		return
	var party_node = my_player.get_node_or_null("UI/Party")
	if is_instance_valid(party_node) and party_node.has_method("onBotInviteReply"):
		party_node.onBotInviteReply(bot_entity_name, bot_level, accepted)

remote func requestBotLeaveParty(bot_path:NodePath) -> void:
	if !get_tree().is_network_server():
		return
	var bot = get_node_or_null(bot_path)
	if is_instance_valid(bot) and bot.has_method("leaveBotParty"):
		bot.leaveBotParty()


















# Never force-unblocks the save gate -- a stuck-closed gate just pauses
# saves for that player until the chain resolves, which is safer than
# writing unverified blank data over a real save.
func _forceUnblockSaveGate(world_id:String, peer_id:int, entity_name:String) -> void:
	yield(get_tree().create_timer(20.0), "timeout")
	if get_tree().network_peer == null:
		return
	if !spawned_players.has(peer_id) or spawned_players[peer_id]["entity_name"] != entity_name:
		return
	var world = _getWorldById(world_id)
	if !is_instance_valid(world):
		return
	var player = world.get_node_or_null(str(peer_id))
	if is_instance_valid(player) and "data_fully_loaded" in player and !player.data_fully_loaded:
		push_error("PlayerSpawner: snapshot chain never confirmed for " + entity_name + " after 20s -- saves remain BLOCKED for this player until it resolves")
 
remote func requestRespawnPortal(new_world_id: String) -> void:
	if !get_tree().is_network_server(): return
	var sender_id = get_tree().get_rpc_sender_id()
	if !spawned_players.has(sender_id): return
 
	var entity_name = spawned_players[sender_id]["entity_name"]
	var dest_world = _getWorldById(new_world_id)
	var spawn_pos := Vector3.ZERO
	var has_spawn_pos := false
	if dest_world != null and dest_world.has_method("getRespawnPosition"):
		spawn_pos = dest_world.getRespawnPosition(Vector3.ZERO)
		has_spawn_pos = true
 
	despawnPlayer(sender_id)
	spawnPlayerForPeer(sender_id, entity_name, new_world_id, spawn_pos, has_spawn_pos)
 
remote func requestSpawn(entity_name: String, world_id: String = "world") -> void:
	if !get_tree().is_network_server():
		return
	var sender_id = get_tree().get_rpc_sender_id()
 
	if suspended_player_nodes.has(entity_name):
		world_id = suspended_player_nodes[entity_name]["world_id"]
	elif !isKnownWorldId(world_id):
		world_id = "world"
 
	var world = _getWorldById(world_id)
	var spawn_pos := Vector3.ZERO
	var has_spawn_pos := false
 
	if suspended_player_nodes.has(entity_name):
		# Node never left memory -- its transform is ground truth.
		var suspended_node = suspended_player_nodes[entity_name]["node"]
		if is_instance_valid(suspended_node):
			spawn_pos = suspended_node.global_transform.origin
			has_spawn_pos = true
 
	if !has_spawn_pos and world != null and world.has_method("getPlayerSaveBaseDir"):
		var state_path = world.getPlayerSaveBaseDir() + entity_name + "/playerstate.save"
		if File.new().file_exists(state_path):
			var saved = world.readPlayerStateSave(state_path)
			var positions = saved.get("positions", {})
			if typeof(positions) == TYPE_DICTIONARY and positions.has(world_id):
				spawn_pos = positions[world_id]
				has_spawn_pos = true
			elif saved.has("position"):
				spawn_pos = saved["position"]
				has_spawn_pos = true
 
	if !has_spawn_pos and world != null and world.has_method("getPlayerStartPosition"):
		spawn_pos = world.getPlayerStartPosition()
		has_spawn_pos = true
 
	spawnPlayerForPeer(sender_id, entity_name, world_id, spawn_pos, has_spawn_pos)
 
func _applyServerSpawnPosition(world:Node, peer_id:int, spawn_pos:Vector3) -> void:
	if !is_instance_valid(world):
		return
	var player = world.get_node_or_null(str(peer_id))
	if !is_instance_valid(player):
		return
	if player.has_method("setAuthoritativeSpawnPosition"):
		player.setAuthoritativeSpawnPosition(spawn_pos)
	else:
		player.global_transform.origin = spawn_pos
 
remote func receiveFullSnapshot(peer_id:int, snapshot:Dictionary, has_spawn_pos:bool) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	var player = getPlayerNodeByPeer(peer_id)
	if !is_instance_valid(player):
		yield(get_tree().create_timer(0.2), "timeout")
		player = getPlayerNodeByPeer(peer_id)
		if !is_instance_valid(player):
			return
	if player.has_method("applyFullSnapshot"):
		player.applyFullSnapshot(snapshot, has_spawn_pos)
 
 
remote func relayToPeer(target_peer:int, node_relative_path:String, method:String, args:Array) -> void:
	if !get_tree().is_network_server():
		return
	var target_player = getPlayerNodeByPeer(target_peer)
	if !is_instance_valid(target_player):
		return
	var target_node = target_player.get_node_or_null(node_relative_path)
	if !is_instance_valid(target_node):
		return
	target_node.callv("rpc_id", [target_peer, method] + args)
 
func _setupPool() -> void:
	get_tree().root.add_child(_pool_holder)
	if get_tree().is_network_server():
		_pool_filling = true
 
func poolingProcess(delta:float) -> void:
	if !_pool_filling:
		return
	if !get_tree().is_network_server():
		_pool_filling = false
		return
	if _player_pool.size() >= player_pool_size:
		_pool_filling = false
		return
 
	_pool_fill_timer += delta
	if _pool_fill_timer < pool_fill_interval:
		return
	_pool_fill_timer = 0.0
 
	_player_pool.append(_instanceIdlePlayer())
 
func _instanceIdlePlayer() -> Node:
	var player = _player_scene.instance()
	player.set_meta("is_pooled_idle", true)
	player.entity_name = ""
	_pool_holder.add_child(player)
	player.visible = false
	player.set_physics_process(false)
	if player.has_method("setSuspended"):
		player.setSuspended(true)
	return player
 
 
var suspended_player_nodes := {} # entity_name -> {"node": Node, "world_id": String}
 
remote func requestOwnFullSnapshot() -> void:
	if !get_tree().is_network_server():
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id == 0 or !spawned_players.has(sender_id):
		return
	var data = spawned_players[sender_id]
	var world = _getWorldById(data["world_id"])
	if world == null:
		return
	_sendFullSnapshotWithRetry(world, sender_id, data["entity_name"], data["world_id"], true)
 
 
var player_full_sync_interval := 3.0
var _player_sync_timer := 0.0
 
func processPlayerSpawn(delta:float) -> void:
	poolingProcess(delta)
	if !get_tree().is_network_server():
		return
	if get_tree().network_peer == null:
		return
	_player_sync_timer += delta
	if _player_sync_timer < player_full_sync_interval:
		return
	_player_sync_timer = 0.0
	_broadcastAllPlayersToEveryone()
 
remote func batchSpawnPlayersRemote(players_data:Array) -> void:
	for entry in players_data:
		spawnPlayerRemote(entry["peer_id"], entry["entity_name"], entry["world_id"])
 
var _peer_known_players := {} # peer_id -> {other_id:true, ...}
var _broadcast_tick_count := 0
var full_resync_every_n_ticks := 10
 
func _broadcastAllPlayersToEveryone() -> void:
	var peers = get_tree().get_network_connected_peers()
	if peers.empty():
		return
 
	_broadcast_tick_count += 1
	var roster_changed = spawned_players.size() != _last_known_roster_size
	_last_known_roster_size = spawned_players.size()
	var force_full = roster_changed or (_broadcast_tick_count % full_resync_every_n_ticks == 0)
 
	for peer_id in peers:
		if !_peer_known_players.has(peer_id):
			_peer_known_players[peer_id] = {}
		var known: Dictionary = _peer_known_players[peer_id]
 
		for other_id in spawned_players.keys():
			if other_id == peer_id:
				continue
			if !force_full and known.has(other_id):
				continue
			var other_data = spawned_players[other_id]
			rpc_id(peer_id, "spawnPlayerRemote", other_id, other_data["entity_name"], other_data["world_id"])
			known[other_id] = true
 
		for known_id in known.keys():
			if !spawned_players.has(known_id):
				known.erase(known_id)
 
 
var equipment_cache := {} # entity_name -> snapshot dict
 
remote func reportEquipment(data:Dictionary) -> void:
	var sender_id = get_tree().get_rpc_sender_id()
	if !spawned_players.has(sender_id):
		return
	equipment_cache[spawned_players[sender_id]["entity_name"]] = data
 
func _findExistingPlayerNode(world:Node, entity_name:String) -> Node:
	if !is_instance_valid(world):
		return null
	for child in world.get_children():
		if child.is_in_group("Player") and "entity_name" in child and child.entity_name == entity_name:
			return child
	return null
 
func _findPlayerNodeAnywhereByEntityName(entity_name:String) -> Dictionary:
	if entity_name == "":
		return {} # blank identity is never a legitimate match target
	for w in get_tree().get_nodes_in_group("World"):
		if !is_instance_valid(w):
			continue
		for child in w.get_children():
			if child.is_in_group("Player") and "entity_name" in child and child.entity_name == entity_name:
				return {"node": child, "world": w}
	return {}
 
# Only safe to steal/reclaim if it's actually suspended OR its owning
# peer isn't connected anymore.
func _isNodeGenuinelyLive(node:Node, exclude_peer_id:int) -> bool:
	if node.name.begins_with("suspended_"):
		return false
	var master_id = node.get_network_master()
	if master_id == exclude_peer_id:
		return false
	return get_tree().get_network_connected_peers().has(master_id)
 
func _doSpawnPlayer(world:Node, peer_id:int, entity_name:String) -> bool:
	if !is_instance_valid(world):
		return false
	if world.has_node(str(peer_id)):
		return false
 
	var existing = _findExistingPlayerNode(world, entity_name)
	var reused := false
 
	# Only the server reclaims a node parked in another world instance --
	# a client has no business reparenting player nodes by entity_name.
	if !is_instance_valid(existing) and get_tree().is_network_server():
		var found = _findPlayerNodeAnywhereByEntityName(entity_name)
		if !found.empty() and found["world"] != world and !_isNodeGenuinelyLive(found["node"], peer_id):
			existing = found["node"]
			existing.get_parent().remove_child(existing)
			world.add_child(existing)
 
	if is_instance_valid(existing):
		existing.name = str(peer_id)
		existing.set_network_master(peer_id, true)
		if existing.has_method("setSuspended"):
			existing.setSuspended(false)
		suspended_player_nodes.erase(entity_name)
		reused = true
		if existing.has_method("reinitializeForEntity"):
			existing.reinitializeForEntity(entity_name)
	else:
		var player = _getPooledOrFreshPlayer()
		player.name = str(peer_id)
		# entity_name must be set BEFORE anything else touches this node --
		# a freshly-instanced node still carries this peer's OWN default
		# name (Player.gd's class-level default), and calling
		# setSuspended(false) before correcting it makes isLocalPlayer()
		# wrongly true for someone else's puppet.
		player.entity_name = entity_name
		if player.get_parent() != world:
			if is_instance_valid(player.get_parent()):
				player.get_parent().remove_child(player)
			world.add_child(player)
		player.set_network_master(peer_id, true)
		if player.has_method("setSuspended"):
			player.setSuspended(false)
		if player.has_method("reinitializeForEntity"):
			player.reinitializeForEntity(entity_name)
		else:
			player.entity_name = entity_name
		player.set_network_master(peer_id, true)
 
	if peer_id == get_tree().get_network_unique_id():
		call_deferred("_markClientReadyAfterSpawn")
 
	return reused
 
func _getPooledOrFreshPlayer() -> Node:
	if !_player_pool.empty():
		return _player_pool.pop_back()
	var fresh = _player_scene.instance()
	fresh.set_meta("is_pooled_idle", true)
	fresh.entity_name = ""
	return fresh
 
func spawnPlayerForPeer(peer_id:int, entity_name:String, world_id:String = "world", spawn_pos:Vector3 = Vector3.ZERO, has_spawn_pos:bool = false) -> void:
	if spawned_players.has(peer_id):
		return
	var world = _getWorldById(world_id)
	if world == null:
		yield(get_tree().create_timer(0.25), "timeout")
		if spawned_players.has(peer_id) or get_tree().network_peer == null:
			return
		if peer_id != 1 and !get_tree().get_network_connected_peers().has(peer_id):
			return
		spawnPlayerForPeer(peer_id, entity_name, world_id, spawn_pos, has_spawn_pos)
		return
 
	spawned_players[peer_id] = {"entity_name": entity_name, "world_id": world_id}
 
	var reused:bool = spawnPlayerRemote(peer_id, entity_name, world_id)
	if has_spawn_pos:
		call_deferred("_applyServerSpawnPosition", world, peer_id, spawn_pos)
	rpc("spawnPlayerRemote", peer_id, entity_name, world_id)
	if has_spawn_pos:
		rpc_id(peer_id, "setPlayerSpawnPosition", spawn_pos)
 
	if get_tree().is_network_server():
		call_deferred("_sendFullSnapshotWithRetry", world, peer_id, entity_name, world_id, has_spawn_pos)
		call_deferred("_forceUnblockSaveGate", world_id, peer_id, entity_name)
		call_deferred("_syncBannerForPeer", peer_id, entity_name)
 
func resendFullDataTo(peer_id:int) -> void:
	if !get_tree().is_network_server():
		return
	if !spawned_players.has(peer_id):
		return
	var data = spawned_players[peer_id]
	var world = _getWorldById(data["world_id"])
	if world == null:
		return
	var player = world.get_node_or_null(str(peer_id))
	if !is_instance_valid(player):
		return
	player.data_fully_loaded = false
	_sendFullSnapshotWithRetry(world, peer_id, data["entity_name"], data["world_id"], true)
 
 
func _markClientReadyAfterSpawn() -> void:
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	mark_client_ready()
 
 
func _sendEquipmentSnapshot(world:Node, peer_id:int, entity_name:String) -> void:
	if !equipment_cache.has(entity_name):
		var loaded = _readEquipmentFromDisk(world, entity_name)
		if !loaded.empty():
			equipment_cache[entity_name] = loaded
		else:
			equipment_cache[entity_name] = getDefaultEquipmentSnapshot()
	if !equipment_cache.has(entity_name):
		return
	var player = world.get_node_or_null(str(peer_id))
	if !is_instance_valid(player):
		return
	var eq = player.get_node_or_null("UI/Equipment")
	if !is_instance_valid(eq):
		return
 
	if eq.has_method("applyEquipmentSnapshotAuthority"):
		eq.applyEquipmentSnapshotAuthority(equipment_cache[entity_name])
 
	if peer_id == get_tree().get_network_unique_id():
		eq.applyOwnEquipmentSnapshot(equipment_cache[entity_name])
	else:
		eq.rpc_id(peer_id, "applyOwnEquipmentSnapshot", equipment_cache[entity_name])
 
func _readEquipmentFromDisk(world:Node, entity_name:String) -> Dictionary:
	if !is_instance_valid(world) or !world.has_method("getPlayerSaveBaseDir"):
		return {}
	return world.readEquipmentSave(world.getPlayerSaveBaseDir() + entity_name + "/equipment.save")
 
 
func _sendInventorySnapshot(world:Node, peer_id:int, entity_name:String) -> void:
	if !is_instance_valid(world) or !world.has_method("getPlayerSaveBaseDir"):
		return
	var path = world.getPlayerSaveBaseDir() + entity_name + "/inventory.save"
	var data = world.readInventorySave(path)
 
	seedBalanceIfAbsent(entity_name, int(data.get("coins", 0)))
	data["coins"] = getBalance(entity_name)
 
	var player = world.get_node_or_null(str(peer_id))
	if !is_instance_valid(player):
		return
	var inv = player.get_node_or_null("UI/Inventory")
	if !is_instance_valid(inv):
		return
 
	if peer_id == get_tree().get_network_unique_id():
		inv.applyOwnInventorySnapshot(data)
	else:
		inv.rpc_id(peer_id, "applyOwnInventorySnapshot", data)
 
func _sendSkillbarSnapshot(world:Node, peer_id:int, entity_name:String) -> void:
	if !is_instance_valid(world) or !world.has_method("getPlayerSaveBaseDir"):
		return
	var path = world.getPlayerSaveBaseDir() + entity_name + "/skillbar.save"
	var data = world.readSkillbarSave(path)
 
	var player = world.get_node_or_null(str(peer_id))
	if !is_instance_valid(player):
		return
	var sb = player.get_node_or_null("UI/Skillbar")
	if !is_instance_valid(sb):
		return
 
	if peer_id == get_tree().get_network_unique_id():
		sb.applyOwnSkillbarSnapshot(data)
	else:
		sb.rpc_id(peer_id, "applyOwnSkillbarSnapshot", data)
 
 
# ---- Banner system (image chunking + revision counter) ----
var banner_rosters := {} # banner_name -> {"leader":String, "members":[{"entity_name":String,"peer_id":int}], "description":String, "image_data":PoolByteArray, "image_revision":int}
var _banner_rosters_loaded := false
 
remote func requestCreateBanner(entity_name:String, peer_id:int, banner_name:String) -> void:
	if !get_tree().is_network_server(): return
	_loadBannerRostersIfNeeded()
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id > 0: peer_id = sender_id
	if banner_name == "" or banner_rosters.has(banner_name):
		_notifyBanner(peer_id, "onBannerCreateFailed", [banner_name])
		return
	banner_rosters[banner_name] = {
		"leader": entity_name,
		"members": [{"entity_name":entity_name, "peer_id":peer_id}],
		"description": "",
		"image_data": PoolByteArray(),
		"image_revision": 0
	}
	_saveBannerRosters()
	_notifyBanner(peer_id, "onBannerCreateSucceeded", [banner_name])
	broadcastBannerListToAll()
 
 
func _applyBannerImageUpdate(entity_name:String, banner_name:String, image_data:PoolByteArray) -> void:
	_loadBannerRostersIfNeeded()
	if !banner_rosters.has(banner_name): return
	var roster = banner_rosters[banner_name]
	if roster.leader != entity_name: return  # leader-only, enforced server-side too
	if image_data.size() > max_banner_image_bytes: return
 
	roster["image_data"] = image_data
	roster["image_revision"] = int(roster.get("image_revision", 0)) + 1
	_saveBannerRosters()
 
	var revision = roster["image_revision"]
	for m in roster.members:
		_sendBannerImageChunked(m.peer_id, banner_name, image_data, revision)
 
func _sendBannerImageChunked(peer_id:int, banner_name:String, image_data:PoolByteArray, revision:int = 0) -> void:
	_sendChunkedBannerBytes(peer_id, "receiveBannerImageChunk", banner_name, image_data, revision)
 
func _sendBannerListImageChunked(peer_id:int, banner_name:String, image_data:PoolByteArray, revision:int = 0) -> void:
	_sendChunkedBannerBytes(peer_id, "receiveBannerListImageChunk", banner_name, image_data, revision)
 
func _sendChunkedBannerBytes(peer_id:int, method:String, banner_name:String, image_data:PoolByteArray, revision:int = 0) -> void:
	if peer_id <= 0:
		return
	if peer_id == get_tree().get_network_unique_id():
		var target_player = getPlayerNodeByPeer(peer_id)
		if !is_instance_valid(target_player):
			return
		var banner_node = target_player.get_node_or_null("UI/BannerSystem")
		if is_instance_valid(banner_node):
			banner_node.call(method, banner_name, image_data, true, true, revision)
		return
 
	if !get_tree().is_network_server():
		return
 
	var total = image_data.size()
	if total == 0:
		rpc_id(peer_id, "receiveBannerCallback", method, [banner_name, PoolByteArray(), true, true, revision])
		return
 
	var offset = 0
	var first = true
	while offset < total:
		var end = min(offset + banner_image_chunk_size, total)
		var chunk = image_data.subarray(offset, end - 1)
		var is_last = end >= total
		rpc_id(peer_id, "receiveBannerCallback", method, [banner_name, chunk, first, is_last, revision])
		first = false
		offset = end
 
func _syncBannerForPeer(peer_id:int, entity_name:String, attempt:int = 0) -> void:
	_loadBannerRostersIfNeeded()
	for banner_name in banner_rosters:
		var roster = banner_rosters[banner_name]
		for m in roster.members:
			if m.entity_name == entity_name:
				m.peer_id = peer_id
				_notifyBanner(peer_id, "syncBannerRoster", [banner_name, roster.leader, roster.members, roster.get("description",""), PoolByteArray()])
				_sendBannerImageChunked(peer_id, banner_name, roster.get("image_data", PoolByteArray()), int(roster.get("image_revision", 0)))
				_saveBannerRosters()
				if attempt < 4:
					yield(get_tree().create_timer(1.0), "timeout")
					if get_tree().network_peer == null or !spawned_players.has(peer_id):
						return
					_syncBannerForPeer(peer_id, entity_name, attempt + 1)
				return
 
remote func requestJoinBanner(entity_name:String, peer_id:int, banner_name:String) -> void:
	if !get_tree().is_network_server(): return
	_loadBannerRostersIfNeeded()
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id > 0: peer_id = sender_id
	if !banner_rosters.has(banner_name): return
	var roster = banner_rosters[banner_name]
	for m in roster.members:
		if m.entity_name == entity_name: return
	roster.members.append({"entity_name":entity_name, "peer_id":peer_id})
	_saveBannerRosters()
	_pushBannerRoster(banner_name, roster)
	broadcastBannerListToAll()
 
remote func requestBannerRosterSync() -> void:
	if !get_tree().is_network_server():
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id == 0 or !spawned_players.has(sender_id):
		return
	var entity_name = spawned_players[sender_id]["entity_name"]
	_loadBannerRostersIfNeeded()
	for banner_name in banner_rosters:
		var roster = banner_rosters[banner_name]
		for m in roster.members:
			if m.entity_name == entity_name:
				m.peer_id = sender_id
				_notifyBanner(sender_id, "syncBannerRoster", [banner_name, roster.leader, roster.members, roster.get("description",""), PoolByteArray()])
				_sendBannerImageChunked(sender_id, banner_name, roster.get("image_data", PoolByteArray()), int(roster.get("image_revision", 0)))
				_saveBannerRosters()
				return
 
remote func requestBannerList(peer_id:int) -> void:
	if !get_tree().is_network_server(): return
	_loadBannerRostersIfNeeded()
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id > 0: peer_id = sender_id
	_notifyBanner(peer_id, "receiveBannerList", [buildBannerSummary()])
	for banner_name in banner_rosters:
		var roster = banner_rosters[banner_name]
		_sendBannerListImageChunked(peer_id, banner_name, roster.get("image_data", PoolByteArray()), int(roster.get("image_revision", 0)))
 
func _pushBannerRoster(banner_name:String, roster:Dictionary) -> void:
	var revision = int(roster.get("image_revision", 0))
	for m in roster.members:
		_notifyBanner(m.peer_id, "syncBannerRoster", [banner_name, roster.leader, roster.members, roster.get("description",""), PoolByteArray()])
		_sendBannerImageChunked(m.peer_id, banner_name, roster.get("image_data", PoolByteArray()), revision)
 
func _loadBannerRostersIfNeeded() -> void:
	if _banner_rosters_loaded:
		return
	var world = _getAnyWorldNode()
	if world == null or !world.has_method("readBannerRosters"):
		return
	banner_rosters = world.readBannerRosters()
	_banner_rosters_loaded = true
 
func _saveBannerRosters() -> void:
	var world = _getAnyWorldNode()
	if world == null or !world.has_method("saveBannerRosters"):
		return
	world.saveBannerRosters(banner_rosters)
 
 
var banner_image_chunk_size := 16000
var max_banner_image_bytes := 512000
 
var _incoming_banner_image_uploads := {} # sender_id -> PoolByteArray (in progress)
 
remote func requestUpdateBannerImageChunk(entity_name:String, banner_name:String, chunk:PoolByteArray, is_last:bool) -> void:
	if !get_tree().is_network_server(): return
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id == 0 or !spawned_players.has(sender_id): return
	if spawned_players[sender_id]["entity_name"] != entity_name: return
 
	if !_incoming_banner_image_uploads.has(sender_id):
		_incoming_banner_image_uploads[sender_id] = PoolByteArray()
	_incoming_banner_image_uploads[sender_id].append_array(chunk)
 
	if _incoming_banner_image_uploads[sender_id].size() > max_banner_image_bytes:
		_incoming_banner_image_uploads.erase(sender_id) # abort, oversized
		return
 
	if is_last:
		var full_bytes = _incoming_banner_image_uploads[sender_id]
		_incoming_banner_image_uploads.erase(sender_id)
		_applyBannerImageUpdate(entity_name, banner_name, full_bytes)
 
 
remote func requestLeaveBanner(entity_name:String, peer_id:int, banner_name:String) -> void:
	if !get_tree().is_network_server(): return
	_loadBannerRostersIfNeeded()
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id > 0: peer_id = sender_id
	if !banner_rosters.has(banner_name): return
	var roster = banner_rosters[banner_name]
	for i in range(roster.members.size()-1,-1,-1):
		if roster.members[i].entity_name == entity_name:
			roster.members.remove(i)
			break
	if roster.members.empty():
		banner_rosters.erase(banner_name)
	else:
		if roster.leader == entity_name:
			roster.leader = roster.members[0].entity_name
		_pushBannerRoster(banner_name, roster)
	_saveBannerRosters()
	_notifyBanner(peer_id, "onLeftBanner", [])
	broadcastBannerListToAll()
 
 
remote func requestUpdateBannerDescription(entity_name:String, banner_name:String, description:String) -> void:
	if !get_tree().is_network_server(): return
	_loadBannerRostersIfNeeded()
	if !banner_rosters.has(banner_name): return
	var roster = banner_rosters[banner_name]
	if roster.leader != entity_name: return  # leader-only, enforced server-side too
	if description.length() > 500:
		description = description.substr(0, 500)
	roster["description"] = description
	_saveBannerRosters()
	for m in roster.members:
		_notifyBanner(m.peer_id, "receiveBannerDescription", [banner_name, description])
 
remote func requestKickFromBanner(requester_entity_name:String, banner_name:String, target_entity_name:String) -> void:
	if !get_tree().is_network_server(): return
	_loadBannerRostersIfNeeded()
	if !banner_rosters.has(banner_name): return
	var roster = banner_rosters[banner_name]
	if roster.leader != requester_entity_name: return
	if target_entity_name == requester_entity_name: return
 
	var kicked_peer := -1
	for i in range(roster.members.size()-1,-1,-1):
		if roster.members[i].entity_name == target_entity_name:
			kicked_peer = roster.members[i].peer_id
			roster.members.remove(i)
			break
	if kicked_peer == -1:
		return
 
	if kicked_peer > 0:
		_notifyBanner(kicked_peer, "onKickedFromBanner", [])
 
	if roster.members.empty():
		banner_rosters.erase(banner_name)
	else:
		_pushBannerRoster(banner_name, roster)
	_saveBannerRosters()
	broadcastBannerListToAll()
 
 
func _notifyBanner(peer_id:int, method:String, args:Array) -> void:
	if peer_id <= 0:
		return
	if !get_tree().is_network_server():
		return
	if peer_id == get_tree().get_network_unique_id():
		var target_player = getPlayerNodeByPeer(peer_id)
		if !is_instance_valid(target_player):
			push_error("_notifyBanner: no player node for own peer_id " + str(peer_id) + " (method=" + method + ")")
			return
		var banner_node = target_player.get_node_or_null("UI/BannerSystem")
		if !is_instance_valid(banner_node):
			push_error("_notifyBanner: no UI/BannerSystem for own peer_id " + str(peer_id) + " (method=" + method + ")")
			return
		banner_node.callv(method, args)
	else:
		rpc_id(peer_id, "receiveBannerCallback", method, args)
 
remote func receiveBannerCallback(method:String, args:Array) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	var my_id = get_tree().get_network_unique_id()
	var player = getPlayerNodeByPeer(my_id)
	if !is_instance_valid(player):
		return
	var banner_node = player.get_node("UI/BannerSystem")
	if !is_instance_valid(banner_node):
		return
	banner_node.callv(method, args)
 
 
func buildBannerSummary() -> Array:
	var summary := []
	for banner_name in banner_rosters:
		summary.append({
			"name": banner_name,
			"leader": banner_rosters[banner_name].leader,
			"member_count": banner_rosters[banner_name].members.size()
		})
	return summary
 
func broadcastBannerListToAll() -> void:
	var summary = buildBannerSummary()
	for peer_id in spawned_players.keys():
		_notifyBanner(peer_id, "receiveBannerList", [summary])
 
 
func _readSavedWorldId(entity_name:String) -> String:
	var world = _getAnyWorldNode()
	if world == null or !world.has_method("getPlayerSaveBaseDir"):
		return "world"
	var path = world.getPlayerSaveBaseDir() + entity_name + "/playerstate.save"
	var data = world.readPlayerStateSave(path)
	return data.get("world_id", "world")
 
func _getAnyWorldNode() -> Node:
	var worlds = get_tree().get_nodes_in_group("World")
	if worlds.size() > 0:
		return worlds[0]
	return null
 
var _already_requested_spawn := false
 
func sendSpawnRequestOnceConnected(entity_name: String) -> void:
	if _already_requested_spawn:
		return
	var peer = get_tree().network_peer
	if peer == null:
		push_error("PlayerSpawner: no network_peer set, cannot request spawn")
		return
	_already_requested_spawn = true
	_pending_entity_name = entity_name
	_pending_world_id = _readSavedWorldId(entity_name)
	if peer.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTED:
		rpc_id(1, "requestSpawn", entity_name, _pending_world_id)
		return
	if !get_tree().is_connected("connected_to_server", self, "_on_connected_to_server"):
		get_tree().connect("connected_to_server", self, "_on_connected_to_server")
	if !get_tree().is_connected("connection_failed", self, "_on_connection_failed_spawn"):
		get_tree().connect("connection_failed", self, "_on_connection_failed_spawn")
	if !get_tree().is_connected("server_disconnected", self, "_on_server_disconnected_spawn"):
		get_tree().connect("server_disconnected", self, "_on_server_disconnected_spawn")
 
func _on_connected_to_server() -> void:
	rpc_id(1, "requestSpawn", _pending_entity_name, _pending_world_id)
 
func _on_connection_failed_spawn() -> void:
	push_error("PlayerSpawner: failed to connect to server, spawn request aborted")
	_already_requested_spawn = false
 
func _on_server_disconnected_spawn() -> void:
	_already_requested_spawn = false
 
 
remote func requestPortal(new_world_id: String) -> void:
	if !get_tree().is_network_server(): return
	var sender_id = get_tree().get_rpc_sender_id()
	if !spawned_players.has(sender_id): return
 
	var entity_name = spawned_players[sender_id]["entity_name"]
	var source_world_id = spawned_players[sender_id]["world_id"]
 
	var dest_world = _getWorldById(new_world_id)
	var spawn_pos := Vector3.ZERO
	var has_spawn_pos := false
	if dest_world != null and dest_world.has_method("_resolvePortalSpawnPosition"):
		spawn_pos = dest_world._resolvePortalSpawnPosition(dest_world, source_world_id)
		has_spawn_pos = true
 
	despawnPlayer(sender_id)
	spawnPlayerForPeer(sender_id, entity_name, new_world_id, spawn_pos, has_spawn_pos)
 
 
remote func resumePlayerRemote(peer_id:int, entity_name:String, world_id:String) -> void:
	spawned_players[peer_id] = {"entity_name": entity_name, "world_id": world_id}
 
	var entry = suspended_player_nodes.get(entity_name, null)
	if entry == null:
		return
	suspended_player_nodes.erase(entity_name)
 
	var node = entry["node"]
	if !is_instance_valid(node):
		return
 
	node.name = str(peer_id)
	node.set_network_master(peer_id, true)
	if node.has_method("setSuspended"):
		node.setSuspended(false)
 
 
var snapshot_retry_timeout := 8.0
 
func _applySnapshotAuthority(world:Node, peer_id:int, snapshot:Dictionary) -> void:
	var player = world.get_node(str(peer_id))
	if !is_instance_valid(player):
		return
 
	var eq = player.get_node("UI/Equipment")
	if is_instance_valid(eq) and eq.has_method("applyEquipmentSnapshotAuthority"):
		eq.applyEquipmentSnapshotAuthority(snapshot.get("equipment", {}))
		equipment_cache[player.entity_name] = snapshot.get("equipment", {})
 
	var stats_node = player.get_node("Stats")
	if is_instance_valid(stats_node) and stats_node.has_method("applyStatsSnapshotAuthority") and !snapshot.get("stats", {}).empty():
		stats_node.applyStatsSnapshotAuthority(snapshot["stats"])
 
	if snapshot.has("state") and player.has_method("applyStateSnapshotAuthority"):
		player.applyStateSnapshotAuthority(snapshot["state"])
 
 
func _applyFullSnapshotToPlayer(player:Node, snapshot:Dictionary, has_spawn_pos:bool) -> void:
	if !is_instance_valid(player):
		return
 
	var eq = player.get_node("UI/Equipment")
	if is_instance_valid(eq):
		eq.applyOwnEquipmentSnapshot(snapshot.get("equipment", {}))
 
	var inv = player.get_node("UI/Inventory")
	if is_instance_valid(inv):
		inv.applyOwnInventorySnapshot(snapshot.get("inventory", {}))
 
	var sb = player.get_node("UI/Skillbar")
	if is_instance_valid(sb):
		sb.applyOwnSkillbarSnapshot(snapshot.get("skillbar", {}))
 
	var stats_node = player.get_node("Stats")
	if is_instance_valid(stats_node) and !snapshot.get("stats", {}).empty():
		stats_node.applyOwnStatsSnapshot(snapshot["stats"])
 
	var crafting_node = player.get_node("UI/Crafting")
	if is_instance_valid(crafting_node) and !snapshot.get("crafting", {}).empty():
		crafting_node.applyOwnCraftingSnapshot(snapshot["crafting"])
 
	var friends_node = player.get_node("UI/Friends")
	if is_instance_valid(friends_node) and !snapshot.get("friends", {}).empty():
		friends_node.applyOwnFriendsSnapshot(snapshot["friends"])
 
	if !has_spawn_pos and player.has_method("applyOwnStateSnapshot"):
		player.applyOwnStateSnapshot(snapshot.get("state", {}))
 
	var loot_node = player.get_node("UI/Loot")
	if is_instance_valid(loot_node) and loot_node.has_method("applyOwnLootSnapshot"):
		loot_node.applyOwnQuestSnapshot(snapshot.get("loot", {}))
 
	var quest_node = player.get_node("UI/QuestSystem")
	if is_instance_valid(quest_node) and quest_node.has_method("applyOwnQuestSnapshot"):
		quest_node.applyOwnQuestSnapshot(snapshot.get("quests", {}))
 
	player.data_fully_loaded = true
	if player.has_method("_revealAfterLoad"):
		player._revealAfterLoad()
 
 
func _sendAllSnapshotsStaggered(world:Node, peer_id:int, entity_name:String, world_id:String, has_spawn_pos:bool) -> void:
	if !_stillValidForSnapshot(world, peer_id):
		return
	_sendEquipmentSnapshot(world, peer_id, entity_name)
 
	yield(get_tree(), "idle_frame")
	if !_stillValidForSnapshot(world, peer_id):
		return
	_sendInventorySnapshot(world, peer_id, entity_name)
 
	yield(get_tree(), "idle_frame")
	if !_stillValidForSnapshot(world, peer_id):
		return
	_sendSkillbarSnapshot(world, peer_id, entity_name)
 
	yield(get_tree(), "idle_frame")
	if !_stillValidForSnapshot(world, peer_id):
		return
	_sendStatsSnapshot(world, peer_id, entity_name)
 
	yield(get_tree(), "idle_frame")
	if !_stillValidForSnapshot(world, peer_id):
		return
	_sendCraftingSnapshot(world, peer_id, entity_name, world_id)
 
	yield(get_tree(), "idle_frame")
	if !_stillValidForSnapshot(world, peer_id):
		return
	_sendFriendsSnapshot(world, peer_id, entity_name)
 
	yield(get_tree(), "idle_frame")
	if !_stillValidForSnapshot(world, peer_id):
		return
	deliverPendingProceedsTo(peer_id)
 
	if !has_spawn_pos:
		yield(get_tree(), "idle_frame")
		if !_stillValidForSnapshot(world, peer_id):
			return
		_sendPlayerStateSnapshot(world, peer_id, entity_name)
 
	yield(get_tree(), "idle_frame")
	if !_stillValidForSnapshot(world, peer_id):
		return
	_markPlayerFullyLoaded(world, peer_id)
 
func _markPlayerFullyLoaded(world:Node, peer_id:int) -> void:
	var player = world.get_node(str(peer_id))
	if !is_instance_valid(player):
		return
	player.data_fully_loaded = true
	if peer_id != get_tree().get_network_unique_id():
		player.rpc_id(peer_id, "setDataFullyLoaded")
 
 
func _stillValidForSnapshot(world:Node, peer_id:int) -> bool:
	return get_tree().network_peer != null and is_instance_valid(world) and spawned_players.has(peer_id)
 
 
func _sendPlayerStateSnapshot(world:Node, peer_id:int, entity_name:String) -> void:
	if !is_instance_valid(world) or !world.has_method("getPlayerSaveBaseDir"):
		return
	var path = world.getPlayerSaveBaseDir() + entity_name + "/playerstate.save"
	var data = world.readPlayerStateSave(path)
 
	var player = world.get_node(str(peer_id))
	if !is_instance_valid(player):
		return
 
	if player.has_method("applyStateSnapshotAuthority"):
		player.applyStateSnapshotAuthority(data)
 
	if peer_id == get_tree().get_network_unique_id():
		player.applyOwnStateSnapshot(data)
	else:
		player.rpc_id(peer_id, "applyOwnStateSnapshot", data)
 
 
func catchUpNewPeer(peer_id:int) -> void:
	if !get_tree().is_network_server():
		return
	for other_id in spawned_players.keys():
		if other_id == peer_id:
			continue
		var other_data = spawned_players[other_id]
		rpc_id(peer_id, "spawnPlayerRemote", other_id, other_data["entity_name"], other_data["world_id"])
 
 
func _ensureWorldLoaded(world_id:String) -> Node:
	if get_tree().is_network_server():
		return null # server already has every world instanced at startup
	if !isKnownWorldId(world_id):
		return null
 
	var path = getScenePath(world_id)
	var scene:PackedScene = load(path)
	if scene == null:
		push_error("PlayerSpawner._ensureWorldLoaded(): failed to load scene for '" + world_id + "'")
		return null
 
	var instance = scene.instance()
	instance.world_id = world_id
	instance.skip_offline_autospawn = true
 
	var old_scene = get_tree().current_scene
	get_tree().root.add_child(instance)
	get_tree().current_scene = instance
	if is_instance_valid(old_scene) and old_scene != instance:
		old_scene.queue_free()
 
	return instance
 
 
func despawnPlayer(peer_id: int) -> void:
	if !get_tree().is_network_server():
		return
	if !spawned_players.has(peer_id):
		return
	var entity_name = spawned_players[peer_id]["entity_name"]
	var world_id = spawned_players[peer_id]["world_id"]
	despawnPlayerRemote(peer_id, world_id, entity_name)
	rpc("despawnPlayerRemote", peer_id, world_id, entity_name)
 
 
remote func despawnPlayerRemote(peer_id: int, world_id: String, entity_name: String) -> void:
	spawned_players.erase(peer_id)
	_peer_known_players.erase(peer_id)
	if !get_tree().is_network_server():
		# Clients only need the departed player's node gone from view --
		# they never run the suspend/rename/save logic below.
		var client_world = _getWorldById(world_id)
		if is_instance_valid(client_world):
			var client_node = client_world.get_node(str(peer_id))
			if is_instance_valid(client_node):
				client_node.queue_free()
		return
 
	var world = _getWorldById(world_id)
	var node = null
	if world != null:
		node = world.get_node(str(peer_id))
 
	if !is_instance_valid(node):
		var found = _findPlayerNodeAnywhereByEntityName(entity_name)
		if !found.empty():
			node = found["node"]
			world = found["world"]
 
	if !is_instance_valid(node):
		return
 
	node.name = "suspended_" + entity_name
	if node.has_method("setSuspended"):
		node.setSuspended(true)
	suspended_player_nodes[entity_name] = {"node": node, "world_id": world.world_id}
 
	if world.has_method("savePlayerData") and world.has_method("getPlayerSaveBaseDir"):
		world.savePlayerData(node, world.getPlayerSaveBaseDir())
 
 
remote func spawnPlayerRemote(peer_id: int, entity_name: String, world_id: String) -> bool:
	spawned_players[peer_id] = {"entity_name": entity_name, "world_id": world_id}
 
	var world = _getWorldById(world_id)
	if world != null:
		return _doSpawnPlayer(world, peer_id, entity_name)
 
	if get_tree().is_network_server():
		push_error("PlayerSpawner.spawnPlayerRemote(): server has no world '" + world_id + "' instanced")
		return false
 
	if peer_id == get_tree().get_network_unique_id():
		call_deferred("_deferredEnsureWorldAndSpawn", peer_id, entity_name, world_id)
		return false
 
	# OTHER player, world not loaded here yet -- retry instead of dropping.
	call_deferred("_retrySpawnPlayerRemote", peer_id, entity_name, world_id, 0)
	return false
 
func _retrySpawnPlayerRemote(peer_id:int, entity_name:String, world_id:String, attempt:int) -> void:
	if get_tree().network_peer == null:
		return
	if attempt >= 10:
		return
	var world = _getWorldById(world_id)
	if world != null:
		_doSpawnPlayer(world, peer_id, entity_name)
		return
	yield(get_tree().create_timer(0.3), "timeout")
	_retrySpawnPlayerRemote(peer_id, entity_name, world_id, attempt + 1)
 
 
func _deferredEnsureWorldAndSpawn(peer_id:int, entity_name:String, world_id:String) -> void:
	if get_tree().network_peer == null:
		return # disconnected before this ran
	var world = _ensureWorldLoaded(world_id)
	if world == null:
		push_error("PlayerSpawner._deferredEnsureWorldAndSpawn(): could not load world '" + world_id + "', player not instanced")
		return
	_doSpawnPlayer(world, peer_id, entity_name)
 
 
remote func requestFullPlayerResync() -> void:
	if !get_tree().is_network_server():
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id == 0:
		return
	catchUpNewPeer(sender_id)
 
 
func _sendStatsSnapshot(world:Node, peer_id:int, entity_name:String) -> void:
	if !is_instance_valid(world) or !world.has_method("getPlayerSaveBaseDir"):
		return
	var path = world.getPlayerSaveBaseDir() + entity_name + "/playerstats.save"
	var data = world.readStatsSave(path)
	if data.empty():
		return
 
	var player = world.get_node_or_null(str(peer_id))
	if !is_instance_valid(player):
		return
	var stats_node = player.get_node_or_null("Stats")
	if !is_instance_valid(stats_node):
		return
 
	if peer_id == get_tree().get_network_unique_id():
		stats_node.applyOwnStatsSnapshot(data)
	else:
		stats_node.applyStatsSnapshotAuthority(data)
		stats_node.rpc_id(peer_id, "applyOwnStatsSnapshot", data)
 
 
func _sendCraftingSnapshot(world:Node, peer_id:int, entity_name:String, world_id:String) -> void:
	if !is_instance_valid(world) or !world.has_method("getPlayerSaveBaseDir"):
		return
	var path = world.getPlayerSaveBaseDir() + entity_name + "/crafting_" + world_id + ".save"
	var data = world.readCraftingSave(path)
	if data.empty():
		return
	var player = world.get_node_or_null(str(peer_id))
	if !is_instance_valid(player):
		return
	var crafting_node = player.get_node_or_null("UI/Crafting")
	if !is_instance_valid(crafting_node):
		return
	if peer_id == get_tree().get_network_unique_id():
		crafting_node.applyOwnCraftingSnapshot(data)
	else:
		crafting_node.rpc_id(peer_id, "applyOwnCraftingSnapshot", data)
 
 
func _sendFriendsSnapshot(world:Node, peer_id:int, entity_name:String) -> void:
	if !is_instance_valid(world) or !world.has_method("getFriendsSaveDir"):
		return
	var path = world.getFriendsSaveDir(entity_name) + "friends.save"
	var data = world.readFriendsSave(path)
	if data.empty():
		return
	var player = world.get_node_or_null(str(peer_id))
	if !is_instance_valid(player):
		return
	var friends_node = player.get_node_or_null("UI/Friends")
	if !is_instance_valid(friends_node):
		return
	if peer_id == get_tree().get_network_unique_id():
		friends_node.applyOwnFriendsSnapshot(data)
	else:
		friends_node.rpc_id(peer_id, "applyOwnFriendsSnapshot", data)
 
 
func getPlayerNode(entity_name:String) -> Node:
	for peer_id in spawned_players.keys():
		var data = spawned_players[peer_id]
		if data["entity_name"] != entity_name:
			continue
		var world = _getWorldById(data["world_id"])
		if world == null:
			return null
		return world.get_node_or_null(str(peer_id))
	return null
func getPlayerOrBotNode(entity_name:String) -> Node:
	var found = getPlayerNode(entity_name)
	if is_instance_valid(found):
		return found
	for b in get_tree().get_nodes_in_group("BOT"):
		if is_instance_valid(b) and "entity_name" in b and b.entity_name == entity_name:
			return b
	return null
func getPlayerNodeByPeer(peer_id:int) -> Node:
	if !spawned_players.has(peer_id):
		return null
	var data = spawned_players[peer_id]
	var world = _getWorldById(data["world_id"])
	if world == null:
		return null
	return world.get_node_or_null(str(peer_id))
 
func getAllPlayerNodes() -> Array:
	var result := []
	for peer_id in spawned_players.keys():
		var node = getPlayerNodeByPeer(peer_id)
		if is_instance_valid(node):
			result.append(node)
	return result
 
 
# ============================ AUCTION HOUSE DATA ============================
signal listing_added(listing_id, listing)
signal listing_quantity_changed(listing_id, quantity)
signal listing_removed(listing_id)
signal buy_result(listing_id, success, amount, texture_path, price, listing_removed_after, authoritative_coins)
signal sale_proceeds_received(amount, authoritative_coins)
signal retrieve_confirmed(listing_id, texture_path, quantity)
var player_coins := {} # entity_name -> int, server's best-known balance
signal shop_buy_result(success, granted_items, total_cost, new_balance)
signal shop_sell_result(total_credit, new_balance)
 
const MAX_LISTINGS := 500
const AH_SAVE_FILE = "auctionhouse.save"
 
func _getSaveDir() -> String:
	if get_tree().network_peer == null:
		return "user://AuctionHouse/Offline/"
	return "user://AuctionHouse/Server_" + _getServerAddressId() + "/"
 
func _getServerAddressId() -> String:
	var raw := ""
	if get_tree().is_network_server():
		raw = "host_" + str(DEFAULT_PORT)
	else:
		raw = last_ip + "_" + str(last_port)
	if raw.strip_edges() == "":
		raw = "unknown_server"
	return raw.replace(":", "_").replace("/", "_").replace("\\", "_").replace(".", "_")
 
var listings := {} # listing_id:String -> Dictionary
var _next_listing_id := 0
var _dirty := false
var _loaded_once := false
 
 
func isServer() -> bool:
	return get_tree().network_peer == null or get_tree().is_network_server()
 
func _callCameFromServer() -> bool:
	var sender = get_tree().get_rpc_sender_id()
	if sender == 1:
		return true
	if sender == 0 and isServer():
		return true # our own local reflection of an rpc() we just broadcast, as the server
	return false
 
 
var pending_sale_messages := {} # entity_name -> Array of message strings, delivered on next login
 
func saveListings() -> void:
	if !isServer() or !_dirty:
		return
	_dirty = false
	var save_dir = _getSaveDir()
	var dir = Directory.new()
	if !dir.dir_exists(save_dir):
		dir.make_dir_recursive(save_dir)
	var file = File.new()
	if file.open(save_dir + AH_SAVE_FILE, File.WRITE) == OK:
		file.store_var({
			"listings": listings,
			"next_id": _next_listing_id,
			"pending_proceeds": pending_proceeds,
			"pending_sale_messages": pending_sale_messages,
			"player_coins": player_coins,
		})
		file.close()
 
var _loaded_from_dir := ""
 
func loadListings() -> void:
	if !isServer():
		return
	var save_dir = _getSaveDir()
	if _loaded_from_dir == save_dir:
		return
	_loaded_from_dir = save_dir
 
	listings = {}
	_next_listing_id = 0
	pending_proceeds = {}
	pending_sale_messages = {}
	player_coins = {}
 
	var file = File.new()
	if !file.file_exists(save_dir + AH_SAVE_FILE):
		return
	if file.open(save_dir + AH_SAVE_FILE, File.READ) != OK:
		return
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	listings = data.get("listings", {})
	_next_listing_id = int(data.get("next_id", 0))
	pending_proceeds = data.get("pending_proceeds", {})
	pending_sale_messages = data.get("pending_sale_messages", {})
	player_coins = data.get("player_coins", {})
 
 
# Listings/proceeds are keyed to a PERSISTENT identity (entity_name),
# never seller_peer_id/rpc_sender_id -- those are session numbers Godot
# recycles across reconnects.
func _entityNameForPeer(peer_id:int) -> String:
	if get_tree().network_peer == null:
		return selected_player_name
	if spawned_players.has(peer_id):
		return spawned_players[peer_id]["entity_name"]
	return ""
 
func _peerForEntityName(entity_name:String) -> int:
	if get_tree().network_peer == null:
		return 1
	for peer_id in spawned_players.keys():
		if spawned_players[peer_id]["entity_name"] == entity_name:
			return peer_id
	return -1
 
 
# ---- shop buy ----
func requestShopBuy(merchant_type:String, cart_items:Array) -> void:
	if get_tree().network_peer == null:
		_serverProcessShopBuy(1, merchant_type, cart_items)
		return
	rpc_id(1, "serverProcessShopBuy", merchant_type, cart_items)
 
remote func serverProcessShopBuy(merchant_type:String, cart_items:Array) -> void:
	if !isServer():
		return
	var buyer_peer_id = get_tree().get_rpc_sender_id()
	if buyer_peer_id == 0:
		buyer_peer_id = 1
	_serverProcessShopBuy(buyer_peer_id, merchant_type, cart_items)
 
func _serverProcessShopBuy(buyer_peer_id:int, merchant_type:String, cart_items:Array) -> void:
	var buyer_name = _entityNameForPeer(buyer_peer_id)
	if buyer_name == "":
		_sendShopBuyResultTo(buyer_peer_id, false, [], 0, -1)
		return
 
	var merchant_items = merchant_inventories.get(merchant_type, [])
	var known_balance = int(player_coins.get(buyer_name, 0))
 
	if merchant_items.empty(): # was a call to an undefined "merchant_empty()" -- fixed
		_sendShopBuyResultTo(buyer_peer_id, false, [], 0, known_balance)
		return
 
	var total_cost = 0
	var granted := []
	for entry in cart_items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var texture_path = str(entry.get("texture_path",""))
		var quantity = int(entry.get("quantity",0))
		if texture_path == "" or quantity <= 0:
			continue
 
		var matched = null
		for item in merchant_items:
			if str(item.get("icon","")) == texture_path:
				matched = item
				break
		if matched == null:
			continue
 
		total_cost += int(matched.get("price",0)) * quantity
		granted.append({"texture_path": texture_path, "quantity": quantity})
 
	if granted.empty() or total_cost > known_balance:
		_sendShopBuyResultTo(buyer_peer_id, false, [], 0, known_balance)
		return
 
	known_balance -= total_cost
	player_coins[buyer_name] = known_balance
	_dirty = true
	saveListings()
 
	_sendShopBuyResultTo(buyer_peer_id, true, granted, total_cost, known_balance)
 
func _sendShopBuyResultTo(peer_id:int, success:bool, granted:Array, total_cost:int, new_balance:int) -> void:
	if get_tree().network_peer == null or peer_id == get_tree().get_network_unique_id():
		emit_signal("shop_buy_result", success, granted, total_cost, new_balance)
		return
	rpc_id(peer_id, "clientReceiveShopBuyResult", success, granted, total_cost, new_balance)
 
remote func clientReceiveShopBuyResult(success:bool, granted:Array, total_cost:int, new_balance:int) -> void:
	if !_callCameFromServer():
		return
	emit_signal("shop_buy_result", success, granted, total_cost, new_balance)
 
 
# ---- shop sell ----
func requestShopSell(sold_items:Array) -> void:
	if get_tree().network_peer == null:
		_serverProcessShopSell(1, sold_items)
		return
	rpc_id(1, "serverProcessShopSell", sold_items)
 
remote func serverProcessShopSell(sold_items:Array) -> void:
	if !isServer():
		return
	var seller_peer_id = get_tree().get_rpc_sender_id()
	if seller_peer_id == 0:
		seller_peer_id = 1
	_serverProcessShopSell(seller_peer_id, sold_items)
 
func _serverProcessShopSell(seller_peer_id:int, sold_items:Array) -> void:
	var seller_name = _entityNameForPeer(seller_peer_id)
	if seller_name == "":
		_sendShopSellResultTo(seller_peer_id, 0, -1)
		return
 
	var total_credit = 0
	for entry in sold_items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var texture_path = str(entry.get("texture_path",""))
		var quantity = int(entry.get("quantity",0))
		if texture_path == "" or quantity <= 0:
			continue
 
		var item = _findSellableItemByPath(texture_path)
		if item == null:
			continue # server refuses to price anything it doesn't recognize
 
		var unit_price = int(round(max(1.0, float(item.get("price",0)) * 0.8)))
		total_credit += unit_price * quantity
 
	var new_balance = int(player_coins.get(seller_name, 0)) + total_credit
	player_coins[seller_name] = new_balance
	_dirty = true
	saveListings()
 
	_sendShopSellResultTo(seller_peer_id, total_credit, new_balance)
 
func _findSellableItemByPath(texture_path:String):
	for list in categories:
		for item in list.values():
			if str(item.get("icon","")) == texture_path:
				return item
	for merchant_items in merchant_inventories.values():
		for item in merchant_items:
			if str(item.get("icon","")) == texture_path:
				return item
	return null
 
func _sendShopSellResultTo(peer_id:int, total_credit:int, new_balance:int) -> void:
	if get_tree().network_peer == null or peer_id == get_tree().get_network_unique_id():
		emit_signal("shop_sell_result", total_credit, new_balance)
		return
	rpc_id(peer_id, "clientReceiveShopSellResult", total_credit, new_balance)
 
remote func clientReceiveShopSellResult(total_credit:int, new_balance:int) -> void:
	if !_callCameFromServer():
		return
	emit_signal("shop_sell_result", total_credit, new_balance)
 
 
# reportCoins only seeds a first-time balance -- once player_coins has an
# entry, self-reporting can never move the number again.
remote func reportCoins(amount:int) -> void:
	if !isServer():
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id == 0:
		sender_id = 1
	var entity_name = _entityNameForPeer(sender_id)
	if entity_name == "":
		return
	seedBalanceIfAbsent(entity_name, amount)
 
 
var pending_proceeds := {} # entity_name -> accumulated coins earned while offline
 
func deliverPendingProceedsTo(peer_id:int) -> void:
	if !isServer():
		return
	var entity_name = _entityNameForPeer(peer_id)
	if entity_name == "":
		return
 
	var messages : Array = pending_sale_messages.get(entity_name, [])
	var has_messages = !messages.empty()
	if has_messages:
		pending_sale_messages.erase(entity_name)
 
	var has_proceeds = pending_proceeds.has(entity_name)
	if !has_proceeds and !has_messages:
		return
 
	var amount = int(pending_proceeds.get(entity_name, 0))
	if has_proceeds:
		pending_proceeds.erase(entity_name)
 
	_dirty = true
	saveListings()
 
	if amount > 0:
		if get_tree().network_peer == null or peer_id == get_tree().get_network_unique_id():
			emit_signal("sale_proceeds_received", amount, int(player_coins.get(entity_name, 0)))
		else:
			rpc_id(peer_id, "clientReceiveSaleProceeds", amount, int(player_coins.get(entity_name, 0)))
 
	for message in messages:
		_sendSystemMessageTo(peer_id, entity_name, message)
 
 
func requestPlaceListing(texture_path:String, item_name:String, quantity:int, price:int, seller_name:String) -> void:
	if get_tree().network_peer == null:
		_serverCreateListing(seller_name, texture_path, item_name, quantity, price)
		return
	rpc_id(1, "serverCreateListing", seller_name, texture_path, item_name, quantity, price)
 
func requestBuy(listing_id:String, amount:int) -> void:
	if get_tree().network_peer == null:
		_serverProcessBuy(1, listing_id, amount)
		return
	rpc_id(1, "serverProcessBuy", listing_id, amount)
 
func requestRetrieve(listing_id:String) -> void:
	if get_tree().network_peer == null:
		_serverProcessRetrieve(1, listing_id)
		return
	rpc_id(1, "serverProcessRetrieve", listing_id)
 
 
remote func serverCreateListing(seller_name:String, texture_path:String, item_name:String, quantity:int, price:int) -> void:
	if !isServer():
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id == 0:
		sender_id = 1
	# Only allow a peer to create a listing attributed to their OWN
	# server-resolved identity.
	if _entityNameForPeer(sender_id) != seller_name:
		return
	_serverCreateListing(seller_name, texture_path, item_name, quantity, price)
 
func _serverCreateListing(seller_name:String, texture_path:String, item_name:String, quantity:int, price:int) -> void:
	if price <= 0 or quantity <= 0 or listings.size() >= MAX_LISTINGS or seller_name == "":
		return
 
	_next_listing_id += 1
	var listing_id = "AH" + str(_next_listing_id)
	var listing = {
		"seller_name": seller_name,
		"texture_path": texture_path,
		"item_name": item_name,
		"quantity": quantity,
		"price": price
	}
	listings[listing_id] = listing
	_dirty = true
	saveListings()
 
	emit_signal("listing_added", listing_id, listing)
	if get_tree().network_peer != null:
		rpc("clientReceiveListingAdded", listing_id, listing)
 
 
remote func serverProcessBuy(listing_id:String, amount:int) -> void:
	if !isServer():
		return
	var buyer_peer_id = get_tree().get_rpc_sender_id()
	if buyer_peer_id == 0:
		buyer_peer_id = 1
	_serverProcessBuy(buyer_peer_id, listing_id, amount)
 
func _serverProcessBuy(buyer_peer_id:int, listing_id:String, amount:int) -> void:
	var buyer_name = _entityNameForPeer(buyer_peer_id)
	if buyer_name == "":
		_sendBuyResultTo(buyer_peer_id, listing_id, false, 0, "", 0, false, -1)
		return
 
	var known_balance = int(player_coins.get(buyer_name, 0))
	var listing = listings.get(listing_id, null)
 
	if listing == null or amount <= 0 or amount > int(listing["quantity"]) or buyer_name == listing.get("seller_name", ""):
		_sendBuyResultTo(buyer_peer_id, listing_id, false, 0, "", 0, false, known_balance)
		return
 
	var price = int(listing["price"])
	var total_cost = price * amount
 
	if total_cost > known_balance:
		_sendBuyResultTo(buyer_peer_id, listing_id, false, 0, "", 0, false, known_balance)
		return
 
	var texture_path = listing["texture_path"]
	var item_name = str(listing.get("item_name", "an item"))
	var remaining = int(listing["quantity"]) - amount
	var listing_removed_after = remaining <= 0
 
	if listing_removed_after:
		listings.erase(listing_id)
	else:
		listing["quantity"] = remaining
		listings[listing_id] = listing
 
	known_balance -= total_cost
	player_coins[buyer_name] = known_balance
	_dirty = true
	saveListings()
 
	var sale_message = "%s bought %dx %s from your Auction House listing for %d coins" % [buyer_name, amount, item_name, total_cost]
	_creditSeller(listing["seller_name"], total_cost, sale_message)
	_sendBuyResultTo(buyer_peer_id, listing_id, true, amount, texture_path, price, listing_removed_after, known_balance)
 
	if listing_removed_after:
		emit_signal("listing_removed", listing_id)
		if get_tree().network_peer != null:
			rpc("clientReceiveListingRemoved", listing_id)
	else:
		emit_signal("listing_quantity_changed", listing_id, remaining)
		if get_tree().network_peer != null:
			rpc("clientReceiveListingQuantity", listing_id, remaining)
 
func _creditSeller(seller_name:String, amount:int, message:String = "") -> void:
	if amount <= 0 or seller_name == "":
		return
 
	player_coins[seller_name] = int(player_coins.get(seller_name, 0)) + amount
	_dirty = true
 
	var seller_peer_id = _peerForEntityName(seller_name)
	if seller_peer_id == -1:
		pending_proceeds[seller_name] = int(pending_proceeds.get(seller_name, 0)) + amount
		if message != "":
			if !pending_sale_messages.has(seller_name):
				pending_sale_messages[seller_name] = []
			pending_sale_messages[seller_name].append(message)
		saveListings()
		return
 
	if get_tree().network_peer == null or seller_peer_id == get_tree().get_network_unique_id():
		emit_signal("sale_proceeds_received", amount, player_coins[seller_name])
	else:
		rpc_id(seller_peer_id, "clientReceiveSaleProceeds", amount, player_coins[seller_name])
 
	if message != "":
		_sendSystemMessageTo(seller_peer_id, seller_name, message)
 
func _sendSystemMessageTo(peer_id:int, entity_name:String, message:String) -> void:
	var player_node = getPlayerNode(entity_name)
	if !is_instance_valid(player_node):
		return
	var chat_node = player_node.get_node_or_null("UI/Chat")
	if !is_instance_valid(chat_node):
		return
	if get_tree().network_peer == null or peer_id == get_tree().get_network_unique_id():
		chat_node.sendSystemMessage(message)
	else:
		chat_node.rpc_id(peer_id, "receiveSystemMessage", message)
 
remote func clientReceiveSaleProceeds(amount:int, authoritative_coins:int) -> void:
	if !_callCameFromServer():
		return
	emit_signal("sale_proceeds_received", amount, authoritative_coins)
 
 
func _sendBuyResultTo(buyer_peer_id:int, listing_id:String, success:bool, amount:int, texture_path:String, price:int, listing_removed_after:bool, authoritative_coins:int) -> void:
	if get_tree().network_peer == null or buyer_peer_id == get_tree().get_network_unique_id():
		emit_signal("buy_result", listing_id, success, amount, texture_path, price, listing_removed_after, authoritative_coins)
		return
	rpc_id(buyer_peer_id, "clientReceiveBuyResult", listing_id, success, amount, texture_path, price, listing_removed_after, authoritative_coins)
 
remote func clientReceiveBuyResult(listing_id:String, success:bool, amount:int, texture_path:String, price:int, listing_removed_after:bool, authoritative_coins:int) -> void:
	if !_callCameFromServer():
		return
	emit_signal("buy_result", listing_id, success, amount, texture_path, price, listing_removed_after, authoritative_coins)
 
 
remote func serverProcessRetrieve(listing_id:String) -> void:
	if !isServer():
		return
	var requester_peer_id = get_tree().get_rpc_sender_id()
	if requester_peer_id == 0:
		requester_peer_id = 1
	_serverProcessRetrieve(requester_peer_id, listing_id)
 
func _serverProcessRetrieve(requester_peer_id:int, listing_id:String) -> void:
	var listing = listings.get(listing_id, null)
	var requester_name = _entityNameForPeer(requester_peer_id)
 
	if listing == null or requester_name == "" or listing.get("seller_name", "") != requester_name:
		_sendRetrieveConfirmationTo(requester_peer_id, listing_id, "", 0)
		return
 
	listings.erase(listing_id)
	_dirty = true
	saveListings()
 
	_sendRetrieveConfirmationTo(requester_peer_id, listing_id, listing["texture_path"], int(listing["quantity"]))
 
	emit_signal("listing_removed", listing_id)
	if get_tree().network_peer != null:
		rpc("clientReceiveListingRemoved", listing_id)
 
func _sendRetrieveConfirmationTo(peer_id:int, listing_id:String, texture_path:String, quantity:int) -> void:
	if get_tree().network_peer == null or peer_id == get_tree().get_network_unique_id():
		emit_signal("retrieve_confirmed", listing_id, texture_path, quantity)
		return
	rpc_id(peer_id, "clientReceiveRetrieveConfirmation", listing_id, texture_path, quantity)
 
remote func clientReceiveRetrieveConfirmation(listing_id:String, texture_path:String, quantity:int) -> void:
	if !_callCameFromServer():
		return
	emit_signal("retrieve_confirmed", listing_id, texture_path, quantity)
 
 
remote func clientReceiveListingAdded(listing_id:String, listing:Dictionary) -> void:
	if !_callCameFromServer():
		return
	listings[listing_id] = listing
	emit_signal("listing_added", listing_id, listing)
 
remote func clientReceiveListingQuantity(listing_id:String, quantity:int) -> void:
	if !_callCameFromServer():
		return
	if listings.has(listing_id):
		listings[listing_id]["quantity"] = quantity
	emit_signal("listing_quantity_changed", listing_id, quantity)
 
remote func clientReceiveListingRemoved(listing_id:String) -> void:
	if !_callCameFromServer():
		return
	listings.erase(listing_id)
	emit_signal("listing_removed", listing_id)
 
 
func sendCatchUpTo(peer_id:int) -> void:
	if !isServer() or listings.empty():
		return
	rpc_id(peer_id, "clientReceiveFullListingSnapshot", listings)
 
remote func clientReceiveFullListingSnapshot(all_listings:Dictionary) -> void:
	if !_callCameFromServer():
		return
	for listing_id in all_listings:
		if listings.has(listing_id):
			continue
		listings[listing_id] = all_listings[listing_id]
		emit_signal("listing_added", listing_id, all_listings[listing_id])
 
 
func getBalance(entity_name:String) -> int:
	return int(player_coins.get(entity_name, 0))
 
func seedBalanceIfAbsent(entity_name:String, amount:int) -> void:
	if entity_name == "" or player_coins.has(entity_name):
		return
	player_coins[entity_name] = amount
	_dirty = true
 
func grantMoney(entity_name:String, amount:int) -> void:
	if get_tree().network_peer == null:
		_grantMoneyAuthority(entity_name, amount)
		return
	rpc_id(1, "serverGrantMoney", entity_name, amount)
 
remote func serverGrantMoney(entity_name:String, amount:int) -> void:
	if !isServer():
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id == 0:
		sender_id = 1
	if _entityNameForPeer(sender_id) != entity_name:
		return
	_grantMoneyAuthority(entity_name, amount)
 
func _grantMoneyAuthority(entity_name:String, amount:int) -> void:
	if amount <= 0 or entity_name == "":
		return
	_creditSeller(entity_name, amount)
 
 
# ============================ MOB SYNC ============================
var _mobs := {}
var _cache_built := false
var aoi_radius :int= 440
var aoi_near_radius:int= 60
var aoi_mid_radius:int= 200
var far_tier_stagger:int= 6
var _player_tier_cache := {} # peer_id -> {"near":Array,"mid":Array,"far":Array,"pos":Vector3,"frame":int,"wid":String}
var tier_cache_refresh_frames := 12    # force a fresh queryRadius+classify at least this often, even for a stationary player, so mobs that wandered into/out of range are still caught promptly
var tier_cache_move_threshold := 4.0   # meters -- player moving more than this since the last recompute forces an immediate refresh regardless of the frame budget above
var _far_tier_bucket:int= 0
var sync_rate :float= 0.11
var full_sync_interval := 16
var cache_rebuild_interval :float= 4.0
var _timer := 0.0
var _cache_timer := 0.0
var _tick_count := 0
 
var sync_rate_base :float= 0.11
var full_sync_interval_base := 16
 
func broadcastMobs(peer_ids:Array) -> void:
	if !_cache_built or peer_ids.empty():
		return
	_tick_count += 1
	var send_full = (_tick_count % full_sync_interval == 0)
	_far_tier_bucket = (_far_tier_bucket + 1) % far_tier_stagger
 
	for peer_id in peer_ids:
		var player = getPlayerNodeByPeer(peer_id)
		if !is_instance_valid(player):
			continue
		var wid = peerWorldId(peer_id)
		if wid == "":
			continue
 
		var player_pos = player.global_transform.origin
		var tiers = getMobTiersForPlayer(peer_id, wid, player, player_pos)
		var near_mobs:Array = tiers["near"]
		var mid_mobs:Array = tiers["mid"]
		var far_mobs:Array = tiers["far"]
 
		var far_this_tick := []
		if !far_mobs.empty():
			var i := 0
			for mob in far_mobs:
				if i % far_tier_stagger == _far_tier_bucket:
					far_this_tick.append(mob)
				i += 1
 
		var near_mid_mobs = near_mobs + mid_mobs
		if near_mid_mobs.empty() and far_this_tick.empty():
			continue
 
		var near_mid_payload = buildPayload(near_mid_mobs, send_full, true)
		var far_payload = buildPayload(far_this_tick, false, false)
 
		# No more re-fetching each mob from _mobs to check target != null --
		# buildPayload() already stamped "cbt" while it had the node in hand.
		var combat_payload := []
		var idle_payload := []
		for entry in near_mid_payload:
			if entry.get("cbt", false) or entry.get("dying", false):
				combat_payload.append(entry)
			else:
				idle_payload.append(entry)
		for entry in far_payload:
			idle_payload.append(entry)
 
		if !combat_payload.empty():
			rpc_id(peer_id, "receiveMobBatch", combat_payload)
		if !idle_payload.empty():
			rpc_unreliable_id(peer_id, "receiveMobBatch", idle_payload)
 
 
var _catchup_timers := {} # peer_id -> Timer, reused instead of allocated per chunk
# Reuses the previous tier classification for this peer if the player
# hasn't moved much and the cache isn't stale yet -- skips the
# queryRadius() + per-node distance/classification loop entirely for
# a player standing still. Mob POSITIONS still get refreshed every
# tick regardless (buildPayload() in _broadcastMobs always fetches
# live data for whatever keys this returns) -- only the SET of which
# mobs belong in which tier is what gets cached here.
func getMobTiersForPlayer(peer_id:int, wid:String, player:Node, player_pos:Vector3) -> Dictionary:
	var frame = Engine.get_physics_frames()
	var cache = _player_tier_cache.get(peer_id)
 
	if cache != null and cache.get("wid", "") == wid:
		var age:int = frame - int(cache.get("frame", -999999))
		var moved_sq:float = player_pos.distance_squared_to(cache.get("pos", player_pos))
		if age < tier_cache_refresh_frames and moved_sq < tier_cache_move_threshold * tier_cache_move_threshold:
			return cache
 
	# Stores live Node references directly now, instead of string keys that
	# buildPayload() then had to look back up in _mobs -- that round trip
	# (node -> key -> dictionary lookup -> node) was pure waste since we
	# already hold the node right here from queryRadius().
	var near_mobs := []
	var mid_mobs := []
	var far_mobs := []
 
	for node in queryRadius(wid, player_pos, aoi_radius):
		if node == player or !is_instance_valid(node):
			continue
		if node.is_in_group("Player"):
			continue
		if !("movement_mode" in node):
			continue
		var d = player_pos.distance_to(node.global_transform.origin)
		if d <= aoi_near_radius:
			near_mobs.append(node)
		elif d <= aoi_mid_radius:
			mid_mobs.append(node)
		else:
			far_mobs.append(node)
 
	var new_cache = {"near": near_mobs, "mid": mid_mobs, "far": far_mobs, "pos": player_pos, "frame": frame, "wid": wid}
	_player_tier_cache[peer_id] = new_cache
	return new_cache
 
 
 
 
 
 
 
 
 
 
func _getCatchupTimer(id:int) -> Timer:
	if _catchup_timers.has(id) and is_instance_valid(_catchup_timers[id]):
		return _catchup_timers[id]
	var t := Timer.new()
	t.one_shot = true
	add_child(t)
	t.connect("timeout", self, "_onCatchupChunkTimeout", [id])
	_catchup_timers[id] = t
	return t
 
 
func peerWorldId(peer_id:int) -> String:
	var data = spawned_players.get(peer_id)
	return data.get("world_id", "") if data != null else ""
 
func deferredSendMobBatch(id:int) -> void:
	if !get_tree().is_network_server():
		return
	if !get_tree().get_network_connected_peers().has(id):
		return
	_buildCache()
	var player = getPlayerNodeByPeer(id)
	var wid = peerWorldId(id)
	var mobs := []
	if is_instance_valid(player) and wid != "":
		for node in queryRadius(wid, player.global_transform.origin, aoi_radius):
			if !node.is_in_group("Player") and "movement_mode" in node:
				mobs.append(node)
	var payload = buildPayload(mobs, true, true)
	if payload.empty():
		return
	_catchup_queues[id] = payload
	_sendNextCatchupChunk(id)
 
#func buildPayload(mob_keys:Array, include_full:bool = true, ignore_relevance:bool = false) -> Array:
#	var payload := []
#	for mob_key in mob_keys:
#		var mob = _mobs.get(mob_key)
#		if mob == null or !is_instance_valid(mob):
#			continue
#		if !ignore_relevance and mob.has_method("isRelevantForSync") and !mob.isRelevantForSync():
#			continue
#		var lock = -1
#		if mob.has_method("getActiveAnimLock"):
#			lock = mob.getActiveAnimLock()
#
#		var dying = false
#		if mob.stats:
#			dying = mob.stats.health <= 0
#
#		var entry = {
#			"n": mob_key,
#			"pos": mob.global_transform.origin,
#			"rot": mob.rotation.y,
#			"mode": mob.movement_mode,
#			"skill": mob.current_skill,
#			"lock": lock,
#			"dead": mob.is_dead,
#			"dying": dying,
#			"aid": (mob.attack_instance_id if "attack_instance_id" in mob else 0),
#		}
#
#		var stats_stable = true
#		if mob.stats and ("_stats_stable" in mob.stats):
#			stats_stable = mob.stats._stats_stable
#
#		if include_full and stats_stable:
#			var hp = 0;var maxhp = 0;var energy = 0;var maxenergy = 0
#			var arcane = 0;var maxarcane = 0
#			var statuses = {};var debuffs = {};var attrs = {};var derived = {}
#			var attr_points_spent = {};var avail_points = 0
#			if mob.stats:
#				hp = mob.stats.health
#				maxhp = mob.stats.max_health
#				energy = mob.stats.energy
#				maxenergy = mob.stats.max_energy
#				arcane = mob.stats.arcane
#				maxarcane = mob.stats.max_arcane
#				statuses = mob.stats.statuses.duplicate(true)
#				debuffs = mob.stats.debuff_buffs_active.duplicate(true)
#				attrs = mob.stats.attributes.duplicate(true)
#				derived = mob.stats.derived_stats.duplicate(true)
#				attr_points_spent = mob.stats.attribute_points_spent.duplicate(true)
#				avail_points = mob.stats.available_attribute_points
#
#			var cooldowns_snapshot = {}
#			if "skill_cooldowns" in mob and mob.skill_cooldowns != null:
#				cooldowns_snapshot = mob.skill_cooldowns.duplicate()
#
#			entry["hp"] = hp; entry["maxhp"] = maxhp
#			entry["e"] = energy; entry["maxe"] = maxenergy
#			entry["arc"] = arcane; entry["maxarc"] = maxarcane
#			entry["st"] = statuses; entry["db"] = debuffs
#			entry["atr"] = attrs; entry["der"] = derived
#			entry["aps"] = attr_points_spent; entry["avp"] = avail_points
#			entry["cd"] = cooldowns_snapshot
#			entry["aggro"] = _buildMobAggroList(mob)
#		payload.append(entry)
#	return payload
# Now takes an Array of live mob Nodes instead of string keys, cutting out
# the "_mobs.get(key)" lookup that was happening for every single entry,
# every sync tick, for every player. Also computes and stores whether the
# mob is actively targeting something ("cbt") right here, in the same pass
# that already touches the mob -- so the caller never needs to look the
# mob up again just to decide reliable-vs-unreliable channel routing.
func buildPayload(mobs:Array, include_full:bool = true, ignore_relevance:bool = false) -> Array:
	var payload := []
	for mob in mobs:
		if mob == null or !is_instance_valid(mob):
			continue
		if !ignore_relevance and mob.has_method("isRelevantForSync") and !mob.isRelevantForSync():
			continue
		var lock = -1
		if mob.has_method("getActiveAnimLock"):
			lock = mob.getActiveAnimLock()
 
		var dying = false
		if mob.stats:
			dying = mob.stats.health <= 0
 
		var is_targeting = ("target" in mob) and mob.target != null
 
		var entry = {
			"n": mobKey(mob),
			"pos": mob.global_transform.origin,
			"rot": mob.rotation.y,
			"mode": mob.movement_mode,
			"skill": mob.current_skill,
			"lock": lock,
			"dead": mob.is_dead,
			"dying": dying,
			"cbt": is_targeting,
			"aid": (mob.attack_instance_id if "attack_instance_id" in mob else 0),
		}
 
		var stats_stable = true
		if mob.stats and ("_stats_stable" in mob.stats):
			stats_stable = mob.stats._stats_stable
 
		if include_full and stats_stable:
			var hp = 0;var maxhp = 0;var energy = 0;var maxenergy = 0
			var arcane = 0;var maxarcane = 0
			var statuses = {};var debuffs = {};var attrs = {};var derived = {}
			var attr_points_spent = {};var avail_points = 0
			if mob.stats:
				hp = mob.stats.health
				maxhp = mob.stats.max_health
				energy = mob.stats.energy
				maxenergy = mob.stats.max_energy
				arcane = mob.stats.arcane
				maxarcane = mob.stats.max_arcane
				statuses = mob.stats.statuses.duplicate(true)
				debuffs = mob.stats.debuff_buffs_active.duplicate(true)
				attrs = mob.stats.attributes.duplicate(true)
				derived = mob.stats.derived_stats.duplicate(true)
				attr_points_spent = mob.stats.attribute_points_spent.duplicate(true)
				avail_points = mob.stats.available_attribute_points
 
			var cooldowns_snapshot = {}
			if "skill_cooldowns" in mob and mob.skill_cooldowns != null:
				cooldowns_snapshot = mob.skill_cooldowns.duplicate()
 
			entry["hp"] = hp; entry["maxhp"] = maxhp
			entry["e"] = energy; entry["maxe"] = maxenergy
			entry["arc"] = arcane; entry["maxarc"] = maxarcane
			entry["st"] = statuses; entry["db"] = debuffs
			entry["atr"] = attrs; entry["der"] = derived
			entry["aps"] = attr_points_spent; entry["avp"] = avail_points
			entry["cd"] = cooldowns_snapshot
			entry["aggro"] = buildMobAggroList(mob)
		payload.append(entry)
	return payload
 
# departed peer's stale tier cache doesn't sit around forever.
func _on_peer_disconnected_cleanup(id:int) -> void:
	_catchup_queues.erase(id)
	_player_tier_cache.erase(id)
	if _catchup_timers.has(id):
		if is_instance_valid(_catchup_timers[id]):
			_catchup_timers[id].queue_free()
		_catchup_timers.erase(id)
 
var catchup_chunk_size := 15
var catchup_chunk_interval := 0.05
var _catchup_queues := {}   # peer_id -> Array of remaining entries
 
func _sendNextCatchupChunk(id:int) -> void:
	if !get_tree().is_network_server():
		return
	if !_catchup_queues.has(id):
		return
	if !get_tree().get_network_connected_peers().has(id):
		_catchup_queues.erase(id)
		if _catchup_timers.has(id):
			if is_instance_valid(_catchup_timers[id]):
				_catchup_timers[id].queue_free()
			_catchup_timers.erase(id)
		return
 
	var queue: Array = _catchup_queues[id]
	if queue.empty():
		_catchup_queues.erase(id)
		return
 
	var chunk := []
	var n = min(catchup_chunk_size, queue.size())
	for i in range(n):
		chunk.append(queue.pop_front())
 
	rpc_id(id, "receiveMobBatch", chunk)
 
	if !queue.empty():
		var t := _getCatchupTimer(id)
		t.wait_time = catchup_chunk_interval
		t.start()
	else:
		_catchup_queues.erase(id)
 
func _onCatchupChunkTimeout(id:int) -> void:
	_sendNextCatchupChunk(id)
 
 
# Players are deliberately never added to _mobs -- Players have their own
# authoritative stats channel (Stats._pushStatsToOwner/receiveStatsPush
# plus PlayerSpawner snapshots); letting a Player ride along in the mob
# broadcast caused their hp/energy to flicker back to stale values.
func _buildCache() -> void:
	_mobs.clear()

	# Don't scan the entire SceneTree.
	# World is the current scene/root containing the entities.
	var world: Node = get_tree().current_scene

	if is_instance_valid(world) and world.has_method("getAllEntities"):
		for mob in world.getAllEntities():
			if !is_instance_valid(mob):
				continue
			if mob.is_in_group("Player"):
				continue
			if !("movement_mode" in mob):
				continue

			_mobs[mobKey(mob)] = mob

	_cache_built = _mobs.size() > 0

	var liveIds := {}
	for mob in _mobs.values():
		liveIds[mob.get_instance_id()] = true

	for id in _mobKeyCache.keys():
		if !liveIds.has(id):
			_mobKeyCache.erase(id)
var _mobKeyCache := {} # instance_id -> String
 
func mobKey(mob:Node) -> String:
	var id = mob.get_instance_id()
	if _mobKeyCache.has(id):
		return _mobKeyCache[id]
	var key := ""
	var world = _getMobWorld(mob)
	if world:
		key = world.world_id + ":" + str(world.get_path_to(mob))
	else:
		key = str(mob.get_path())
	_mobKeyCache[id] = key
	return key
 
 
func _getMobWorld(mob:Node) -> Node:
	var n = mob.get_parent()
	while n:
		if n.is_in_group("World") and "world_id" in n:
			return n
		n = n.get_parent()
	return null
 
 
func buildMobAggroList(mob:Node) -> Array:
	var aggro_list := []
	if !mob.has_method("team_aggro"):
		return aggro_list
	for aggro_target in mob.team_aggro():
		if !is_instance_valid(aggro_target.target_entity):
			continue
		aggro_list.append({
			"name": aggro_target.target_entity.name,
			"entity_name": (str(aggro_target.target_entity.entity_name) if "entity_name" in aggro_target.target_entity else "?"),
			"aggro": aggro_target.aggro,
			"time": aggro_target.last_aggro_time
		})
	return aggro_list
remote func receiveMobBatch(payload:Array) -> void:
	if get_tree().is_network_server():
		return
	if !_cache_built:
		_buildCache()
	for entry in payload:
		var mob = _mobs.get(entry["n"])
		if mob == null or !is_instance_valid(mob):
			continue
		if !mob.is_in_group("Player"):
			mob.applyBruteForceSync(entry["pos"], entry["rot"], entry["mode"], entry["skill"], entry["lock"], entry["dead"], entry.get("aid", 0), entry.get("dying", false))
			if entry.has("cd") and mob.has_method("applyBruteForceCombatSync"):
				mob.applyBruteForceCombatSync(entry.get("cd", {}), entry.get("aggro", []))
		if mob.stats and entry.has("hp"):
			mob.stats._has_received_stats_sync = true
			mob.stats.net_health = entry["hp"]
			mob.stats.net_max_health = entry["maxhp"]
			mob.stats.net_energy = entry.get("e", mob.stats.net_energy)
			mob.stats.net_max_energy = entry.get("maxe", mob.stats.net_max_energy)
			mob.stats.net_arcane = entry.get("arc", mob.stats.net_arcane)
			mob.stats.net_max_arcane = entry.get("maxarc", mob.stats.net_max_arcane)
			mob.stats.net_statuses = entry.get("st", mob.stats.net_statuses)
			mob.stats.net_debuff_buffs_active = entry.get("db", mob.stats.net_debuff_buffs_active)
			mob.stats.net_attributes = entry.get("atr", mob.stats.net_attributes)
			mob.stats.net_derived_stats = entry.get("der", mob.stats.net_derived_stats)
			mob.stats.net_attribute_points_spent = entry.get("aps", mob.stats.net_attribute_points_spent)
			mob.stats.net_available_attribute_points = entry.get("avp", mob.stats.net_available_attribute_points)
			mob.stats.net_is_dead = entry["dead"]
 
 
# ============================ MISC GAMEPLAY HELPERS ============================
var _entity_group_cache: Dictionary = {} # instance_id -> {group_name:true}

func _cachedGroups(node) -> Dictionary:
	var id = node.get_instance_id()
	if _entity_group_cache.has(id):
		return _entity_group_cache[id]
	var g := {}
	for group in node.get_groups():
		g[group] = true
	_entity_group_cache[id] = g
	return g

func canHitEnemy(parent,body:Node)->bool:
	if body==null or body==parent:
		return false

	var parent_is_player=parent.is_in_group("Player")
	var body_is_player=body.is_in_group("Player")

	var parent_creator=parent.creator if "creator" in parent else null
	var body_creator=body.creator if "creator" in body else null

	if body==parent_creator or parent==body_creator:
		return false

	if parent_creator!=null and parent_creator==body_creator:
		return false

	if parent_is_player and body_is_player:
		var parent_pvp = bool(parent.get("pvp_enabled")) if "pvp_enabled" in parent else false
		var body_pvp = bool(body.get("pvp_enabled")) if "pvp_enabled" in body else false
		return parent_pvp and body_pvp

	if parent_is_player!=body_is_player:
		if parent_creator!=null and parent_creator.is_in_group("Player"):
			return false
		if body_creator!=null and body_creator.is_in_group("Player"):
			return false
		return true

	if !parent_is_player and !body_is_player:
		var my_stats=parent.get_node_or_null("Stats")
		var other_stats=body.get_node_or_null("Stats")
		var my_species=my_stats.species.to_lower() if my_stats else ""
		var other_species=other_stats.species.to_lower() if other_stats else ""

		if my_species!="" and other_species!="" and (my_species==other_species or my_species.find(other_species)!=-1 or other_species.find(my_species)!=-1):
			return false

		var my_name=parent.name.to_lower()
		var other_name=body.name.to_lower()

		if my_name==other_name or my_name.find(other_name)!=-1 or other_name.find(my_name)!=-1:
			return false

		var parent_groups = _cachedGroups(parent)
		var body_groups = _cachedGroups(body)
		for group in parent_groups:
			if group=="Entity":
				continue
			if body_groups.has(group):
				return false

	return true
 
var FloatingResScene: PackedScene = preload("res://world/player/modules/Interface/scenes/FloatingRes.tscn")
 
func getIconPath(icon):
	if icon is String: return icon
	if icon is Resource: return icon.resource_path
	return ""
 
func addNotStackableItem(inventory_grid,item_data,floating_parent:Node=null):
	var icon=item_data.icon if item_data.has("icon") else item_data["icon"]
	var texture=icon if icon is Texture else load(icon)
	for child in inventory_grid.get_children():
		var slot=child.get_node("Slot")
		if slot.texture==null:
			slot.texture=texture
			child.stackable=false
			child.quantity=1
			child.max_quantity=1
			if floating_parent: showFloatingItem(floating_parent,item_data,1)
			return
 
func addStackableItem(inventory_grid,item_data,floating_parent:Node=null,quantity:int=1):
	var icon=item_data.icon if item_data.has("icon") else item_data["icon"]
	var icon_path=getIconPath(icon)
	var texture=icon if icon is Texture else load(icon)
	for child in inventory_grid.get_children():
		var slot=child.get_node("Slot")
		if slot.texture and getIconPath(slot.texture)==icon_path and child.stackable:
			child.quantity+=quantity
			if floating_parent: showFloatingItem(floating_parent,item_data,quantity)
			return
	for child in inventory_grid.get_children():
		var slot=child.get_node("Slot")
		if slot.texture==null:
			slot.texture=texture
			child.stackable=true
			child.quantity=quantity
			child.max_quantity=9999999999
			if floating_parent: showFloatingItem(floating_parent,item_data,quantity)
			return
 
 
func removeItemByTexture(texture, inventory_grid) -> bool:
	if texture == null:
		return false
	for child in inventory_grid.get_children():
		var slot = child.get_node("Slot")
		if slot.texture == texture:
			child.quantity -= 1
			if child.quantity <= 0:
				child.quantity = 0
				slot.texture = null
			if child.has_method("displayQuantity"):
				child.displayQuantity()
			return true
	return false
 
func inventoryHasItem(texture, inventory_grid) -> bool:
	if texture == null:
		return false
	for child in inventory_grid.get_children():
		var slot = child.get_node("Slot")
		if slot.texture == texture and child.quantity > 0:
			return true
	return false
 
func showFloatingItem(parent_node,item_data,quantity:int=1):
	var floating=FloatingResScene.instance()
	floating.text="+"+str(quantity)
	var icon=item_data["icon"]
	floating.icon=icon if icon is Texture else load(icon)
	floating.use_screen_center=false
	floating.world_position=Vector2.ZERO
	parent_node.add_child(floating)
 
 
func useItem(button,inventory_grid,stats,floating_text_parent=null)->bool:
	if button==null:return false
 
	var slot=button.get_node_or_null("Slot")
	if slot==null and button.get_parent()!=null:
		slot=button.get_parent().get_node_or_null("Slot")
	if slot==null:return false
 
	var texture=slot.texture
	if texture==null:return false
 
	var consumed=false
 
	if sameIcon(flasks["medicine potion"]["icon"],texture):
		if stats.health>=stats.max_health:return false
		stats.applyBuffDebuff("medicine potion",stats.get_parent())
		consumed=true
 
	elif sameIcon(flasks["energy potion"]["icon"],texture):
		if stats.energy>=stats.max_energy:return false
		stats.applyBuffDebuff("energy potion",stats.get_parent())
		consumed=true
 
	elif sameIcon(flasks["power potion"]["icon"],texture):
		stats.applyBuffDebuff("power potion",stats.get_parent())
		consumed=true
 
	elif sameIcon(flasks["poison potion"]["icon"],texture):
		stats.applyBuffDebuff("poison potion",stats.get_parent())
		consumed=true
 
	if !consumed:return false
 
	var empty_flask=flasks["empty"].duplicate()
	empty_flask["icon"]=load(empty_flask["icon"]) if empty_flask["icon"] is String else empty_flask["icon"]
	addStackableItem(inventory_grid,empty_flask,floating_text_parent)
 
	return true
 
 
func spawn(controller, scene, position=null, mob_name="", finished=false):
	var mob = scene.instance()
	var spawn_position = position if position != null else Vector3(controller.global_transform.origin.x + rand_range(-10, 10),controller.global_transform.origin.y,controller.global_transform.origin.z + rand_range(-10, 10))
	mob.translation = spawn_position
	var stats = mob.get_node("Stats")
	stats.is_finished = finished
	controller.add_child(mob)
	return mob
 
 
func gravity(mob):
	var gravity_amount = mob.stats.weight * 10
	var ray = mob.ray_down
	if !mob.is_on_floor():
		if !ray.is_colliding():
			mob.move_and_slide(Vector3.DOWN * gravity_amount)
		else:
			var collider = ray.get_collider()
			if collider != mob:
				if collider.is_in_group("Entity"):
					mob.move_and_slide(Vector3.DOWN * gravity_amount)
 
func floor_slope(mob):
	if Engine.get_physics_frames() % 3 == 0:
		if mob:
			if mob.ray_down:
				var ray = mob.ray_down
				if ray.is_colliding():
					var collider = ray.get_collider()
					if collider != mob:
						if !collider.is_in_group("Entity"):
							var normal = ray.get_collision_normal()
							var slope = rad2deg(acos(normal.dot(Vector3.UP)))
							return slope
	return 0
 
func checkHealth(mob)->bool:
	if mob.stats.last_health == -1:
		mob.stats.last_health = mob.stats.health
 
	if mob.stats.health < mob.stats.last_health:
		mob.stats.last_damage_time = OS.get_ticks_msec()
 
	mob.stats.last_health = mob.stats.health
 
	if (OS.get_ticks_msec() - mob.stats.last_damage_time) <= mob.stats.damage_check_window:
		return true
 
	return false
 
func getAvoidDirection(mob):
	return (mob.global_transform.basis.z + mob.global_transform.basis.x).normalized()
 
func moveforwardAvoid(mob):
	var dir = mob.get_meta("avoid_dir") if mob.has_meta("avoid_dir") else Vector3.ZERO
	if dir == Vector3.ZERO:
		return
	mob.move_and_slide(-dir * mob.stats.walk_speed)
 
func rotateAvoid(mob):
	var dir = mob.get_meta("avoid_dir") if mob.has_meta("avoid_dir") else Vector3.ZERO
	if dir == Vector3.ZERO:
		return
	var target_pos = mob.global_transform.origin + dir
	target_pos.y = mob.global_transform.origin.y
	var target_transform = mob.global_transform.looking_at(target_pos,Vector3.UP)
	mob.global_transform.basis = mob.global_transform.basis.slerp(target_transform.basis,0.1)
 
func sameIcon(icon,texture)->bool:
	if !icon or !texture:return false
	return (icon if icon is String else icon.resource_path)==texture.resource_path
 
 
# ============================ SCENE / QUIT / LIFECYCLE ============================
var current_scene = null
var loader = null
var next_scene_path = ""
var did_auto_switch_world := false
var selected_player_name:String = ""
var pending_equipment_snapshot := {}
 
func _ready() -> void:
	# ---- physics/quit setup ----
	ProjectSettings.set_setting("physics/common/max_physics_steps_per_frame", 3)# ignore this 
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	get_tree().set_auto_accept_quit(false)
	for skill_name in skills:
		var resource = skills[skill_name]
		if resource == null or resource.resource_path == "" or not ResourceLoader.exists(resource.resource_path):
			print(skill_name)
 
	# ---- Network setup ----
	get_tree().connect("network_peer_connected", self, "_on_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_peer_disconnected")
	get_tree().connect("connected_to_server", self, "_on_connected_ok")
	get_tree().connect("connection_failed", self, "_on_connection_failed")
	get_tree().connect("server_disconnected", self, "_on_server_disconnected")
	_checkServerLaunchFlag()
 
	# ---- MobSync setup ----
	get_tree().connect("network_peer_disconnected", self, "_on_peer_disconnected_cleanup")
 
	# ---- PlayerSpawner pool setup ----
	_pool_holder = Node.new()
	_pool_holder.name = "PlayerPoolHolder"
	call_deferred("_setupPool")
 
	set_process(false)
 
# ===================== Global.gd =====================
 
func _physics_process(delta: float) -> void:
	# ---- CommonBehaviour / LOD ----
	_handleDebugInput()
	processPlayerSpawn(delta)
	var frame: int = Engine.get_physics_frames()
 
	# ---- Network ping ----
	if is_server and get_tree().network_peer != null:
		_ping_timer += delta
		if _ping_timer >= ping_interval:
			_ping_timer = 0.0
			for peer_id in get_tree().get_network_connected_peers():
				_ping_sent_at[peer_id] = OS.get_ticks_msec()
				rpc_id(peer_id, "_receivePing")
 
	# ---- MobSync ----
	if get_tree().network_peer != null:
		_cache_timer += delta
		if !_cache_built or _cache_timer >= cache_rebuild_interval:
			_cache_timer = 0.0
			_buildCache()
		if get_tree().is_network_server():
			var total_mobs = _mobs.size()
			sync_rate = sync_rate_base * (1.0 if total_mobs <= 200 else (1.0 + float(total_mobs - 200) / 200.0))
			full_sync_interval = full_sync_interval_base if total_mobs <= 200 else full_sync_interval_base * 2
			_timer += delta
			if _timer >= sync_rate:
				_timer = 0.0
				broadcastMobs(get_tree().get_network_connected_peers()) 
 
 
var _mob_seen_frame := {}   # mob instance id -> physics frame last reported visible by any player camera
export var mob_visibility_grace_frames := 45
export var mob_visibility_sweep_interval := 15
 
remote func reportMobVisible(mob_path:NodePath) -> void:
	if !get_tree().is_network_server():
		return
	var mob = get_tree().root.get_node_or_null(mob_path)
	_markMobSeenByPlayer(mob)
 
 
func _markMobSeenByPlayer(mob) -> void:
	if !is_instance_valid(mob) or !("is_frozen" in mob):
		return
 
	_mob_seen_frame[mob.get_instance_id()] = Engine.get_physics_frames()
 
	if mob.is_frozen and mob.has_method("unfreezeMob"):
		mob.unfreezeMob()
 
	if "_is_relevant" in mob:
		mob._is_relevant = true
 
	if "animation_tree" in mob and is_instance_valid(mob.animation_tree) and !mob.animation_tree.active and !("is_dead" in mob and mob.is_dead):
		mob.animation_tree.active = true
 
	markActive(mob)
 
 
 
 
 
 
 
 
export var force_wake_range := 25.0
export var force_freeze_grace_frames := 12
var _mob_last_seen_frame := {} # instance_id -> physics frame last seen in a player's frustum
 
func forceWakeVisibleNearbyMobs() -> void:
	var frame = Engine.get_physics_frames()
	for player in getAllActivePlayers():
		if !is_instance_valid(player):
			continue
		var camroot = player.get_node_or_null("Camroot")
		if !is_instance_valid(camroot):
			continue
		var cam = camroot.get_node_or_null("h/v/Camera")
		if !is_instance_valid(cam):
			continue
 
		var world = _findWorldOf(player)
		var wid = world.world_id if is_instance_valid(world) and "world_id" in world else ""
		if wid == "":
			continue
 
		var frustum = cam.get_frustum()
 
		for mob in queryRadius(wid, player.global_transform.origin, force_wake_range):
			if !is_instance_valid(mob) or mob.is_in_group("Player"):
				continue
			if !("is_frozen" in mob):
				continue
 
			var origin = mob.global_transform.origin + Vector3.UP * 0.9
			var in_frustum = true
			for plane in frustum:
				if plane.distance_to(origin) > 0.0:
					in_frustum = false
					break
			if !in_frustum:
				continue
 
			_mob_last_seen_frame[mob.get_instance_id()] = frame
 
			if mob.is_frozen:
				mob.unfreezeMob()
 
			mob._is_relevant = true
			mob._relevance_fail_streak = 0
			mob.visibilityCachedInterval = mob.refreshIntervalNear
			var d = player.global_transform.origin.distance_to(mob.global_transform.origin)
			mob.visibilityCachedNearestDist = min(mob.visibilityCachedNearestDist, d)
			mob.cachedNearestPlayerDist = mob.visibilityCachedNearestDist
 
			if is_instance_valid(mob.animation_tree) and !mob.animation_tree.active and !mob.is_dead:
				mob.animation_tree.active = true
 
			markActive(mob)
 
func forceFreezeUnseenMobs() -> void:
	var frame = Engine.get_physics_frames()
	for id in _all_mob_dict.keys():
		var mob = _all_mob_dict[id]
		if !is_instance_valid(mob) or mob.is_in_group("Player"):
			continue
		if !("is_frozen" in mob) or mob.is_frozen:
			continue
		if ("target" in mob) and mob.target != null:
			continue
		if is_instance_valid(mob.stats) and mob.stats.health <= 0 and !mob.is_dead:
			continue
 
		var hasLock := false
		if "anim_locks" in mob and typeof(mob.anim_locks) == TYPE_ARRAY:
			for lockState in mob.anim_locks:
				if lockState:
					hasLock = true
					break
		if hasLock:
			continue
 
		var last_seen = _mob_last_seen_frame.get(id, -999999)
		if frame - last_seen > force_freeze_grace_frames:
			mob._is_relevant = false
			markInactive(mob)
			if mob.has_method("freezeMob"):
				mob.freezeMob()
 
 
 
var combatChatBudgetPerFrame:int = 6
var combatChatUsedThisFrame:Dictionary = {} # peer_id -> count used this frame
var combatChatFrame:int = -999999

func canSendCombatChatMessage(peer_id:int) -> bool:
	var frame:int = Engine.get_physics_frames()
	if frame != combatChatFrame:
		combatChatFrame = frame
		combatChatUsedThisFrame.clear()
	var used:int = combatChatUsedThisFrame.get(peer_id, 0)
	if used >= combatChatBudgetPerFrame:
		return false
	combatChatUsedThisFrame[peer_id] = used + 1
	return true
 
 
 
 
 
 
var crowd_scale_reference: int = 60      # active mob count at which scaling starts kicking in
var crowd_scale_max: float = 2.5          # max shrink factor at very high crowd counts
var _eff_impostor_range: float = impostor_range
var _eff_skeleton_lod_near: float = skeleton_lod_near
var _eff_skeleton_lod_mid: float = skeleton_lod_mid
 
func updateCrowdScaling() -> void:
	var active_count: int = getActiveMobCount()
	var factor: float = 1.0
	if active_count > crowd_scale_reference:
		factor = 1.0 + min(crowd_scale_max - 1.0, float(active_count - crowd_scale_reference) / float(crowd_scale_reference))
	# Shrinking impostor_range pulls MORE distant-but-still-nearby mobs into
	# billboard mode sooner during crowds -- billboards are cheap (single
	# MultiMesh draw), never turn into a slideshow, and the swap happens
	# well outside the near_range where players actually look closely.
	var target_impostor_range: float = max(impostor_range / factor, anim_lod_near_range)
	# Smoothed instead of snapped -- active_count churns frame to frame as
	# mobs cross the relevance boundary, and snapping the impostor radius
	# to match every time made mobs sitting near that radius flicker
	# between full mesh and billboard.
	_eff_impostor_range = lerp(_eff_impostor_range, target_impostor_range, 0.1)
	# Skeleton LOD thresholds shrink too, so fewer of the still-fully-
	# animated close mobs pay full bone-count cost during a crowd -- LOD2/3
	# meshes are simplified, not stopped, so nothing freezes or stutters.
	_eff_skeleton_lod_near = max(skeleton_lod_near / factor, 6.0)
	_eff_skeleton_lod_mid = max(skeleton_lod_mid / factor, _eff_skeleton_lod_near + 5.0)
const CORPSE_COLLISION_LAYER_BIT: int = 1 << 20
const PLAYER_NOCOLLIDE_LAYER_BIT: int = 1 << 21
func excludeCorpseLayer(body:PhysicsBody) -> void:
	body.collision_mask = body.collision_mask & ~CORPSE_COLLISION_LAYER_BIT

# instance_id -> collision_layer the body had before it became a corpse.
# Needed so revive/respawn can restore the REAL original layer instead of
# guessing, since setCorpseCollisionState() below now fully replaces the
# layer instead of just OR-ing a bit onto it.
var _corpse_original_layer: Dictionary = {}

# Call whenever a body's dead/downed state changes.
#
# is_corpse=true  -> the body's collision_layer is replaced with ONLY the
#                     corpse bit. This is the actual fix: previously the
#                     corpse kept its normal entity layer bit (mob layer,
#                     player layer, etc) IN ADDITION to the corpse bit, and
#                     nothing ever excluded that normal layer from living
#                     entities' masks -- so corpses kept colliding with
#                     everyone through their original layer regardless of
#                     excludeCorpseLayer(). Stripping the layer down to
#                     corpse-only is what actually makes living entities
#                     (whose masks exclude CORPSE_COLLISION_LAYER_BIT via
#                     excludeCorpseLayer) stop colliding with it.
# is_corpse=false -> restores the original pre-corpse layer.
func setCorpseCollisionState(body:PhysicsBody, is_corpse:bool) -> void:
	if !is_instance_valid(body):
		return
	var id:int = body.get_instance_id()
	if is_corpse:
		if !_corpse_original_layer.has(id):
			_corpse_original_layer[id] = body.collision_layer
		body.collision_layer = CORPSE_COLLISION_LAYER_BIT
	else:
		if _corpse_original_layer.has(id):
			body.collision_layer = _corpse_original_layer[id]
			_corpse_original_layer.erase(id)
		else:
			body.collision_layer = body.collision_layer & ~CORPSE_COLLISION_LAYER_BIT
var _skill_load_next_ticket:int = 0
var skill_load_served_ticket:int = 0

func claimSkillLoadTicket() -> int:
	var t := _skill_load_next_ticket
	_skill_load_next_ticket += 1
	return t
 
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		saveEverythingBeforeQuit()
		if get_tree().network_peer != null:
			get_tree().network_peer.close_connection()
			yield(get_tree().create_timer(0.3), "timeout")
		get_tree().quit()
 
func saveEverythingBeforeQuit() -> void:
	for world in get_tree().get_nodes_in_group("World"):
		if !is_instance_valid(world):
			continue
		if world.has_method("saveData"):
			world.saveData()
		if world.has_method("saveRecursive"):
			world.saveRecursive(world)
		if world.has_method("flushFileWriteQueue"):
			world.flushFileWriteQueue()
	for player in get_tree().get_nodes_in_group("Player"):
		if is_instance_valid(player) and player.has_method("saveData"):
			player.saveData()
 
func goto_scene(path):
	next_scene_path = path
	loader = ResourceLoader.load_interactive(path)
	if loader == null:
		push_error("Failed to load: " + path)
		return
	set_process(true)
 
func _process(_delta):
	if loader == null:
		set_process(false)
		return
	var result = loader.poll()
	if result == ERR_FILE_EOF:
		var packed_scene = loader.get_resource()
		current_scene.free()
		current_scene = packed_scene.instance()
		get_tree().root.add_child(current_scene)
		get_tree().current_scene = current_scene
		loader = null
		set_process(false)
	elif result != OK:
		push_error("Loading failed: " + next_scene_path)
		loader = null
		set_process(false)
 
signal player_ready
var _player_ready := false
 
func markPlayerReady() -> void:
	if _player_ready:
		return
	_player_ready = true
	emit_signal("player_ready")
 
func resetPlayerReady() -> void:
	_player_ready = false
 
func isPlayerReady() -> bool:
	return _player_ready
 
 
# ============================ ITEMS SECTION ============================
func generateLootForCorpse(corpse):
	var loot = []
	var weight = 100.0
	var species = "wolf"

	if is_instance_valid(corpse) and "stats" in corpse and is_instance_valid(corpse.stats):
		weight = corpse.stats.weight
		species = corpse.stats.species

	var bone_amount = 250
	# FIX: round(weight*0.6) could hit 0 for very light mobs, making that
	# entry silently worthless and, combined with any other failure, leave
	# the corpse looking empty. Guaranteed minimum of 1.
	var meat_amount = max(1, int(round(weight * 0.6)))
	var meat_key = ""

	match species.to_lower():
		"wolf":
			meat_key = "wolf meat"
		"goat":
			meat_key = "goat meat"
		"boar":
			meat_key = "boar meat"
		"moose":
			meat_key = "moose meat"
		_:
			meat_key = "wolf meat"

	loot.append({"item_key": meat_key, "quantity": meat_amount, "category": "food"})
	loot.append({"item_key": "bone", "quantity": bone_amount, "category": "food"})
	return loot
 
 
var flasks = {
	"empty": {"price": 1, "stackable":true, "icon": "res://world/interface/assets/icons/ProfessionAndCraftIcons/Alchemy/Alchemy_19_little_flask.png", "rarity": 0.0, "description": "placeholder1"},
	"energy potion": {"price": 15, "stackable":true, "icon": "res://world/interface/assets/icons/ProfessionAndCraftIcons/Alchemy/Alchemy_20_littlemana_flask.png", "rarity": 0.0, "description": "placeholder2"},
	"medicine potion": {"price": 7, "stackable":true, "icon": "res://world/interface/assets/icons/ProfessionAndCraftIcons/Alchemy/Alchemy_21_littleheal_flask.png", "rarity": 0.0, "description": "placeholder3"},
	"poison potion": {"price": 5, "stackable":true, "icon": "res://world/interface/assets/icons/ProfessionAndCraftIcons/Alchemy/Alchemy_22_deadly_poison.png", "rarity": 0.0, "description": "placeholder4"},
	"power potion": {"price": 35, "stackable":true, "icon": "res://world/interface/assets/icons/ProfessionAndCraftIcons/Alchemy/Alchemy_23_black_poison.png", "rarity": 0.0, "description": "placeholder1"}
}
 
var resources = {
	"crafting book": {"price": 17, "icon": "res://world/interface/assets/icons/books/book_crafting.png", "rarity": 3.0, "description": "contains all the crafting recipes"},
	"stone": {"price": 1, "stackable":true, "icon": "res://world/interface/assets/icons/resources/mining/stone.png", "rarity": 0.0, "description": "merely a rock"},
	"wood log": {"price": 2, "stackable":true, "icon": "res://world/interface/assets/icons/resources/chopping/wood_log.png", "rarity": 0.0},
	"iron ore": {"price": 5, "stackable":true, "icon": "res://world/interface/assets/icons/resources/mining/ironore.png", "rarity": 0.0},
	"iron powder": {"price": 9, "stackable":true, "icon":"res://world/interface/assets/icons/resources/powders/iron powder.png", "rarity": 0.0},
	"coal powder": {"price": 9, "stackable":true, "icon":"res://world/interface/assets/icons/resources/powders/coal powder.png", "rarity": 0.0},
	"steel powder": {"price": 9, "stackable":true, "icon":"res://world/interface/assets/icons/resources/powders/steel powder.png", "rarity": 0.0},
	"iron bar": {"price": 15, "stackable":true, "icon": "res://world/interface/assets/icons/resources/metals/iron_bar.png", "rarity": 0.0},
	"gold ore": {"price":550, "stackable":true, "icon": "res://world/interface/assets/icons/resources/mining/goldore.png", "rarity": 0.0},
	"gold powder": {"price":200, "stackable":true, "icon": "res://world/interface/assets/icons/resources/powders/gold powder.png", "rarity": 0.0},
	"gold bar": {"price": 800, "stackable":true, "icon":"res://world/interface/assets/icons/resources/metals/gold_bar.png", "rarity": 0.0},
	"tomato": {"price":1, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/Tomato.png", "rarity": 0.0},
	"oyster mushrooms": {"price":1, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/Res_131_mushroom.png", "rarity": 0.0},
	"mooncap": {"price":9, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/mushrooms/mooncap.png", "rarity": 0.0, "gatherable_qauntity":7},
	"azuregrass": {"price":1, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/Res_131_mushroom.png", "rarity": 0.0, "gatherable_qauntity":5},
	"duskspike": {"price":90, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/mushrooms/duskspike.png", "rarity": 0.0, "gatherable_qauntity":1},
	"skydrop": {"price":10, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/mushrooms/skydrop.png", "rarity": 0.0, "gatherable_qauntity":1},
	"ossifidia": {"price":15, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/mushrooms/ossifidia.png", "rarity": 0.0, "gatherable_qauntity":1},
	"puffbelly": {"price":3, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/mushrooms/puffbelly.png", "rarity": 0.0, "gatherable_qauntity":1},
	"embercap": {"price":10, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/mushrooms/embercap.png", "rarity": 0.0, "gatherable_qauntity":1},
	"briarcap": {"price":3, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/mushrooms/briarcap.png", "rarity": 0.0, "gatherable_qauntity":1},
	"dandilion": {"price":1, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/Res_57_flowers.png", "rarity": 0.0, "gatherable_qauntity":3},
	"olives": {"price":1, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/Olives.png", "rarity": 0.0, "gatherable_qauntity":15},
	"leaves": {"price":1, "stackable":true, "icon": "res://world/interface/assets/icons/resources/gathering/Res_54_leaves.png", "rarity": 0.0},
}
 
var food = {
	"boar meat": {"price": 35, "stackable":true, "icon": "res://world/interface/assets/icons/ProfessionAndCraftIcons/Cooking_fishing/Cooking_34_meat.png", "rarity": 0.0, "description": "placeholder1"},
	"moose meat": {"price": 80, "stackable":true, "icon": "res://world/interface/assets/icons/ProfessionAndCraftIcons/Cooking_fishing/Cooking_27_meat.png", "rarity": 0.0, "description": "placeholder2"},
	"wolf meat": {"price": 25, "stackable":true, "icon": "res://world/interface/assets/icons/ProfessionAndCraftIcons/Cooking_fishing/Cooking_23_meat.png", "rarity": 0.0, "description": "placeholder3"},
	"goat meat": {"price": 20, "stackable":true, "icon":"res://world/interface/assets/icons/ProfessionAndCraftIcons/Cooking_fishing/Cooking_24_meat.png", "rarity": 0.0, "description": "placeholder4"},
	"bone": {"price": 9, "stackable":true, "icon":"res://world/interface/assets/icons/ProfessionAndCraftIcons/Cooking_fishing/Cooking_25_bone.png", "rarity": 0.0, "description": "placeholder1"}
}
 
# Kragun has no per-armor models yet, so every torso/hands/feet armor gets
# the shared kragun unisex placeholder scene. Equipment.gd's
# findArmorScene() picks this up via its species -> unisex fallback.
var armors = {
	"torso1": {"type":"torso", "price":90, "icon":"res://world/interface/assets/icons/equipment/armor/PlateMailChest3.png",
		"scene":{"human":{"male":preload("res://world/player/human/male/Torso1.tscn"), "female":preload("res://world/player/human/female/Torso1.tscn")}, "kragun":{"unisex":preload("res://world/player/kragun/unisex/KragunTorso0.tscn")}},
		"rarity":0.0, "description":"Leather armor",
		"defences":{"slash":5, "pierce":5, "cold":5, "heat":5, "blunt":1},
		"max_health":1, "max_arcane":1, "max_energy":1, "mov_speed":0.5,
		"derived_stats":{"attack_speed":0.01, "cooldown_reduction":0.08, "climb_speed":1.17, "swim_speed":0.94, "fall_resistance":1.36, "tenacity":0.01, "atk_turn_speed":0.16, "dash_turn_speed":2.83, "jump_power":1.51, "crit_chance":0.07, "penetrating_hit_chance":0.04, "penetration_power":0.31, "crit_damage":0.63, "detection_range":2.48, "energy_regeneration":1.82, "health_regeneration":0.74}
	},
	"torso2": {"type":"torso", "price":110, "icon":"res://world/interface/assets/icons/equipment/armor/PlateMailChest.png",
		"scene":{"human":{"male":preload("res://world/player/human/male/Torso2.tscn"), "female":preload("res://world/player/human/female/Torso2.tscn")}, "kragun":{"unisex":preload("res://world/player/kragun/unisex/KragunTorso0.tscn")}},
		"rarity":0.0, "description":"Plate armor", "defences":{"slash":30, "pierce":20, "blunt":10}, "max_health":35, "max_arcane":4, "max_energy":18, "mov_speed":1
	},
	"torso3": {"type":"torso", "price":120, "icon":"res://world/interface/assets/icons/equipment/armor/PlateMailChestBlue.png",
		"scene":{"human":{"male":preload("res://world/player/human/male/Torso3.tscn"), "female":preload("res://world/player/human/female/Torso3.tscn")}, "kragun":{"unisex":preload("res://world/player/kragun/unisex/KragunTorso0.tscn")}},
		"rarity":0.0, "description":"Plate armor", "defences":{"slash":30, "pierce":20, "blunt":10}, "max_health":22, "max_arcane":15, "max_energy":30, "mov_speed":2, "balance":0.1
	},
	"torso4": {"type":"torso", "price":190, "icon":"res://world/interface/assets/icons/equipment/armor/PlateMailChestPurple.png",
		"scene": {"human": {"male": preload("res://world/player/human/male/Torso4.tscn"), "female": preload("res://world/player/human/female/Torso4.tscn")}, "kragun":{"unisex":preload("res://world/player/kragun/unisex/KragunTorso0.tscn")}},
		"rarity": 0.0, "description": "Plate armor", "defences": {"slash": 30, "pierce": 20, "blunt": 10}, "max_health": 20
	},
	"torso5": {"type":"torso", "price":250, "icon":"res://world/interface/assets/icons/equipment/armor/PlateMailChestRed.png",
		"scene": {"human": {"male": preload("res://world/player/human/male/Torso5.tscn"), "female": preload("res://world/player/human/female/Torso5.tscn")}, "kragun":{"unisex":preload("res://world/player/kragun/unisex/KragunTorso0.tscn")}},
		"rarity": 0.0, "description": "Plate armor", "defences": {"slash": 30, "pierce": 20, "blunt": 10}, "max_health": 20
	},
	"torso6": {"type":"torso", "price":390, "icon":"res://world/interface/assets/icons/equipment/armor/PlateMailChestYellow.png",
		"scene": {"human": {"male": preload("res://world/player/human/male/Torso6.tscn"), "female": preload("res://world/player/human/female/Torso6.tscn")}, "kragun":{"unisex":preload("res://world/player/kragun/unisex/KragunTorso0.tscn")}},
		"rarity": 0.0, "description": "Plate armor", "defences": {"slash": 30, "pierce": 20, "blunt": 10}, "max_health": 20
	},
	"hands1": {"type":"hands", "price":7, "icon":"res://world/interface/assets/icons/equipment/gloves/LeatherBracers.png",
		"scene": {"human": {"male": preload("res://world/player/human/male/Hands1.tscn"), "female": preload("res://world/player/human/female/Hands1.tscn")}, "kragun":{"unisex":preload("res://world/player/kragun/unisex/Hands0.tscn")}},
		"rarity": 0.0, "description": "Leather gloves", "defences": {"slash": 4, "pierce": 2, "blunt": 1}, "max_health": 2
	},
	"hands2": {"type":"hands", "price":18, "icon":"res://world/interface/assets/icons/equipment/gloves/MetalBracers.png",
		"scene": {"human": {"male": preload("res://world/player/human/male/Hands2.tscn"), "female": preload("res://world/player/human/female/Hands2.tscn")}, "kragun":{"unisex":preload("res://world/player/kragun/unisex/Hands0.tscn")}},
		"rarity": 0.0, "description": "Steel gauntlets", "defences": {"slash": 8, "pierce": 6, "blunt": 4}, "max_health": 5
	},
	"feet1": {"type":"feet", "price": 25, "icon":"res://world/interface/assets/icons/equipment/footwear/WorkShoes.png",
		"scene": {"human": {"male": preload("res://world/player/human/male/Feet1.tscn"), "female": preload("res://world/player/human/female/Feet1.tscn")}, "kragun":{"unisex":preload("res://world/player/kragun/unisex/Feet0.tscn")}},
		"rarity": 0.0, "description": "Leather boots", "defences": {"slash": 3, "pierce": 2, "blunt": 2}, "max_health": 3
	},
	"feet2": {"type":"feet", "price": 55, "icon":"res://world/interface/assets/icons/equipment/footwear/PlateBoots2.png",
		"scene": {"human": {"male": preload("res://world/player/human/male/Feet2.tscn"), "female": preload("res://world/player/human/female/Feet2.tscn")}, "kragun":{"unisex":preload("res://world/player/kragun/unisex/Feet0.tscn")}},
		"rarity": 0.0, "description": "Leather boots", "defences": {"slash": 3, "pierce": 2, "blunt": 2}, "max_health": 3
	}
}
 
var weapons = {
	"iron pickaxe": {
		"scene": preload("res://world/player/weapons/Pickaxe.tscn"),
		"price": 15,
		"icon": "res://world/interface/assets/icons/equipment/tools/BasicPick.png",
		"rarity": 0.0,
		"two handed": true,
		"carry": "back low",
		"block": 2,
		"mining power": 3,
		"description": "Battle axe",
		"damages": {
			"slash": 0.01,
			"blunt": 0.05,
			"pierce": 0.15,
		},
	},

	"axe": {
		"scene": preload("res://world/player/weapons/Axe.tscn"),
		"price": 15,
		"icon": "res://world/interface/assets/icons/weapon_icons/AxeOld.png",
		"rarity": 0.0,
		"two handed": false,
		"carry": "hips inverted",
		"block": 2,
		"description": "Battle axe",
		"chopping power": 3,
		"damages": {
			"slash": 0.1,
			"blunt": 0.05,
		},
		"max_health": 3,
		"max_arcane": 1,
		"max_energy": 5,
		"mov_speed": 2,
		"derived_stats": {
			"cooldown_reduction": 0.08,
			"climb_speed": 0.15,
			"swim_speed": 0.10,
			"fall_resistance": 0.08,
			"stagger": 0.20,
			"tenacity": 0.12,
			"turn_speed": 0.20,
			"atk_turn_speed": 0.03,
			"dash_turn_speed": 0.30,
			"jump_power": 0.10,
			"crit_chance": 0.07,
			"penetrating_hit_chance": 0.02,
			"penetration_power": 0.025,
			"crit_damage": 0.045,
			"energy_regeneration": 0.08,
			"health_regeneration": 0.03,
			"threat": 0.15,
		},
	},

	"hatchet": {
		"scene": preload("res://world/player/weapons/Axe.tscn"),
		"price": 25,
		"icon": "res://world/interface/assets/icons/equipment/tools/AxeOld.png",
		"rarity": 0.0,
		"two handed": false,
		"carry": "hips inverted",
		"block": 1.6,
		"description": "Battle axe",
		"chopping power": 15,
		"damages": {
			"slash": 0.05,
			"blunt": 0.05,
		},
	},

	"steel pickaxe": {
		"scene": preload("res://world/player/weapons/Pickaxe.tscn"),
		"price": 45,
		"icon": "res://world/interface/assets/icons/equipment/tools/Loot_13_pick.png",
		"rarity": 0.0,
		"two handed": true,
		"carry": "back low",
		"block": 2,
		"mining power": 6,
		"description": "Battle axe",
		"damages": {
			"slash": 0.01,
			"blunt": 0.05,
			"pierce": 0.15,
		},
	},

	"shield": {
		"scene": preload("res://world/player/weapons/Shield.tscn"),
		"price": 75,
		"icon": "res://world/interface/assets/icons/weapon_icons/GreeceShield.png",
		"rarity": 0.0,
		"two handed": false,
		"carry": "shield",
		"block": 5000000000,
		"description": "Tower shield",
		"damages": {
			"blunt": 0.05,
		},
		"mov_speed": -1.5,
		"impact": 0.1,
		"agility": -0.15,
		"dexterity": -0.05,
		"balance": 0.1,
		"authority": 0.15,
		"derived_stats": {
			"attack_speed": -0.05,
			"climb_speed": -0.2,
			"swim_speed": -0.3,
			"fall_resistance": -0.3,
			"stagger": 0.5,
			"tenacity": 0.5,
			"jump_power": -0.15,
			"crit_chance": 0.01,
			"penetrating_hit_chance": 0.0,
			"penetration_power": 0.1,
			"crit_damage": 0.2,
			"detection_range": 0.5,
			"energy_regeneration": 2.0,
			"health_regeneration": 3.0,
			"threat": 8.0,
		},
	},

	"pickaxe3": {
		"scene": preload("res://world/player/weapons/Pickaxe.tscn"),
		"price": 95,
		"icon": "res://world/interface/assets/icons/equipment/tools/BasicDigger.png",
		"rarity": 0.0,
		"two handed": true,
		"carry": "back low",
		"block": 2,
		"mining power": 10,
		"description": "Battle axe",
		"damages": {
			"slash": 0.01,
			"blunt": 0.05,
			"pierce": 0.15,
		},
	},

	"greataxe": {
		"scene": preload("res://world/player/weapons/GreatAxe.tscn"),
		"price": 125,
		"icon": "res://world/interface/assets/icons/weapon_icons/AxeViking.png",
		"rarity": 0.0,
		"two handed": true,
		"carry": "back low",
		"block": 1.8,
		"chopping power": 1,
		"description": "War axe",
		"damages": {
			"slash": 0.125,
			"blunt": 0.01,
		},
		"max_health": 15,
		"max_arcane": 2,
		"max_energy": 35,
		"mov_speed": -4,
		"authority": 0.1,
		"derived_stats": {
			"cooldown_reduction": -0.02,
			"climb_speed": 0.09,
			"swim_speed": 0.02,
			"fall_resistance": 0.40,
			"stagger": 1.00,
			"tenacity": 0.60,
			"turn_speed": -0.10,
			"atk_turn_speed": -0.08,
			"dash_turn_speed": -0.08,
			"jump_power": 0.22,
			"crit_chance": 0.06,
			"penetrating_hit_chance": 0.01,
			"penetration_power": 0.10,
			"crit_damage": 0.15,
			"detection_range": 0.03,
			"energy_regeneration": 0.20,
			"health_regeneration": 0.15,
			"threat": 0.60,
		},
	},

	"sword": {
		"scene": preload("res://world/player/weapons/Sword.tscn"),
		"price": 225,
		"icon": "res://world/interface/assets/icons/weapon_icons/Sword2.png",
		"rarity": 0.0,
		"two handed": false,
		"carry": "hips",
		"block": 2.3,
		"description": "Steel sword",
		"damages": {
			"slash": 0.1,
			"pierce": 0.1,
		},
		"max_health": 5,
		"max_arcane": 3,
		"max_energy": 10,
		"mov_speed": 1,
	},

	"greatsword": {
		"scene": preload("res://world/player/weapons/Greatsword.tscn"),
		"price": 525,
		"icon": "res://world/interface/assets/icons/weapon_icons/Sword.png",
		"rarity": 0.0,
		"two handed": true,
		"carry": "back up",
		"block": 2,
		"description": "Heavy greatsword",
		"damages": {
			"pierce": 0.02,
			"slash": 0.15,
		},
		"max_health": 20,
		"max_arcane": 5,
		"max_energy": 25,
		"mov_speed": -5,
		"derived_stats": {
			"cooldown_reduction": -0.04,
		},
	},
}
var necklaces = {
	"orange necklace":{"icon":"res://world/interface/assets/icons/equipment/necklace/Jewelry_41_orangeneck.png", "rarity":0.0, "price":250, "description":"Orange necklace", "max_health":90},
	"blue necklace":{"icon":"res://world/interface/assets/icons/equipment/necklace/Jewelry_42_blueneck.png", "rarity":0.0, "price":350, "description":"Blue necklace", "max_health":30},
	"blue pendant":{"icon":"res://world/interface/assets/icons/equipment/necklace/Jewelry_52_blueneck.png", "rarity":0.0, "price":500, "description":"Blue pendant", "max_health":140},
	"medallion":{"icon":"res://world/interface/assets/icons/equipment/necklace/Jewelry_55_medallion.png", "rarity":0.0, "price":650, "description":"Medallion"},
	"clay necklace":{"icon":"res://world/interface/assets/icons/equipment/necklace/Jewelry_59_clay_neck.png", "rarity":0.0, "price":120, "description":"Clay necklace", "max_health":240},
	"immortal necklace":{"icon":"res://world/interface/assets/icons/equipment/necklace/Jewelry_60_immortal_neck.png", "rarity":0.0, "price":2500, "description":"Immortal necklace", "max_health":340},
	"gold medallion":{"icon":"res://world/interface/assets/icons/equipment/necklace/Jewelry_56_gold_medallion.png", "rarity":0.0, "price":1200, "description":"Gold medallion", "max_health":140}
}
 
var rings = {
	"silver ring":{"icon":"res://world/interface/assets/icons/equipment/rings/silver_ring.png", "rarity":0.0, "price":300, "description":"Silver ring", "max_health":40, "max_arcane":60, "max_energy":50, "mov_speed":0.2, "haste":0.05, "derived_stats":{"health_regeneration":1}},
	"strength ring":{"icon":"res://world/interface/assets/icons/equipment/rings/Jewelry_40_megastrength_ring.png", "rarity":0.0, "price":900, "description":"strength ring", "strength":0.05, "derived_stats":{"climb_speed":0.5, "swim_speed":0.5}},
	"devil ring":{"icon":"res://world/interface/assets/icons/equipment/rings/Jewelry_39_devil_ring.png", "rarity":0.0, "price":6300, "description":"Devil ring", "max_health":-5, "max_arcane":75, "max_energy":75, "mov_speed":0.5, "derived_stats":{"attack_speed":0.015}}
}
 
var bracelets = {}
 
var merchant_inventories = {
	"generic": [flasks["energy potion"], flasks["medicine potion"], flasks["poison potion"], flasks["power potion"], food["boar meat"], food["moose meat"], food["wolf meat"], food["goat meat"], food["bone"], armors["torso1"], armors["torso2"], armors["torso3"], armors["torso4"], armors["torso5"], weapons["greatsword"], armors["hands1"], armors["hands2"], armors["feet1"], armors["feet2"], rings["silver ring"], rings["strength ring"], rings["devil ring"], resources["crafting book"], resources["stone"]],
	"alchemist": [flasks["energy potion"], flasks["medicine potion"], flasks["poison potion"], flasks["power potion"]],
	"cook": [food["boar meat"], food["moose meat"], food["wolf meat"], food["goat meat"], food["bone"]]
}
 
func getAllItems()->Array:
	var items=[]
	for p in get_script().get_script_property_list():
		if p.type!=TYPE_DICTIONARY:continue
		var d=get(p.name)
		for v in d.values():
			if typeof(v)==TYPE_DICTIONARY and v.has("icon") and v.has("price"):
				items.append(v)
	return items
 
func getItemByIcon(icon):
	var path=icon.resource_path if typeof(icon)==TYPE_OBJECT else icon
	for p in get_script().get_script_property_list():
		if p.type!=TYPE_DICTIONARY and p.type!=TYPE_ARRAY:continue
		var data=get(p.name)
		if typeof(data)==TYPE_DICTIONARY:
			for item in data.values():
				if typeof(item)==TYPE_DICTIONARY and item.has("icon") and item["icon"]==path:
					return item
				if typeof(item)==TYPE_ARRAY:
					for sub in item:
						if typeof(sub)==TYPE_DICTIONARY and sub.has("icon") and sub["icon"]==path:
							return sub
		elif typeof(data)==TYPE_ARRAY:
			for item in data:
				if typeof(item)==TYPE_DICTIONARY and item.has("icon") and item["icon"]==path:
					return item
	return null
 
var categories=[food,resources,weapons,rings,necklaces,armors,flasks]
 
func getDefaultEquipmentSnapshot() -> Dictionary:
	return {
		"torso": armors["torso1"]["icon"], "hands": "", "feet": armors["feet1"]["icon"],
		"mainhand": "", "offhand": "", "necklace": "", "rings": ["", "", "", "", "", "", "", ""]
	}
 
 
enum Type {slash, blunt, pierce, sonic, heat, cold, jolt, toxic, acid, arcane, bleed, radiant}
 
static func dmg_to_string(t:int) -> String:
	match t:
		Type.slash: return "Slash"
		Type.blunt: return "Blunt"
		Type.pierce: return "Pierce"
		Type.sonic: return "Sonic"
		Type.heat: return "Heat"
		Type.cold: return "Cold"
		Type.jolt: return "Jolt"
		Type.toxic: return "Toxic"
		Type.acid: return "Acid"
		Type.arcane: return "Arcane"
		Type.bleed: return "Bleed"
		Type.radiant: return "Radiant"
		_: return "Unknown"
 











var _skill_name_by_icon_path := {}
var _skill_clean_name_cache := {}

func getSkillNameByIconPath(path:String) -> String:
	if path == "":
		return ""
	if _skill_name_by_icon_path.empty():
		for skill_name in skills:
			var tex = skills[skill_name]
			if tex != null and typeof(tex) == TYPE_OBJECT:
				_skill_name_by_icon_path[tex.resource_path] = skill_name
	return _skill_name_by_icon_path.get(path, "")

func getSkillCleanName(skill_name:String) -> String:
	if _skill_clean_name_cache.has(skill_name):
		return _skill_clean_name_cache[skill_name]
	var clean_name := ""
	for c in skill_name:
		if c >= "a" and c <= "z":
			clean_name += c
		elif c >= "A" and c <= "Z":
			clean_name += c
		elif c == " ":
			clean_name += c
	_skill_clean_name_cache[skill_name] = clean_name
	return clean_name
var descriptions = {
"combo attack":"""Hits all enemies in front of you. Successful hits restore energy.""",
"stone splitter":"""
Very slow slamming attack, sped up by the end of [combo attack]
and most berserk skills.
 
Deals double damage to staggered, downed or stunned enemies.
""",
"reckless":"""
Enter a blood frenzy state, taking 80% more damage from all sources.
100% of damage received is reflected back to the attacker, and this reflected damage ignores all defenses, resistances, and damage reduction effects.
Movement speed and attack speed are reduced by 11%, but all attacks deal 55% more damage.
Resets [Raze] and reduces the cooldown of all berserk skills by 5 seconds.
""",
"bite":"""Basic bite attack. Successful hits restore energy, heal the user, and reduce cooldowns of all mob skills by 3 seconds."""
}
 
var egg_spawners = {"forest spider":preload("res://world/mobs/eggs_skills_spawnables/EggSpawner.tscn")}
var projectiles = {"elemental":preload("res://world/mobs/eggs_skills_spawnables/MagicElementalProjectile.tscn")}
 
var fallback=load("res://world/interface/assets/interface_elements/MapIcon_XmarkRed.png")
 
var skills = {
"combo attack":preload("res://world/interface/assets/icons/Combat_icons/Basic_skills_icons/combo_attack.png"),
"penetrating blow":preload("res://world/interface/assets/icons/Combat_icons/Basic_skills_icons/Skill_ThousandBlows.png"),
"guard":preload("res://world/interface/assets/icons/Combat_icons/Basic_skills_icons/guard.png"),
"backstep":preload("res://world/interface/assets/icons/Combat_icons/Basic_skills_icons/backstep.png"),
"evasion":preload("res://world/interface/assets/icons/Combat_icons/Basic_skills_icons/evasion.png"),
"mine":preload("res://world/interface/assets/icons/non_combat_skills/mining.png"),
"chop":preload("res://world/interface/assets/icons/non_combat_skills/chop_wood.png"),
"gather":preload("res://world/interface/assets/icons/non_combat_skills/harvest.png"),
"cross draw":preload("res://world/interface/assets/icons/Combat_icons/Assasin_skill_icons/pendulum_slash.png"),
"lunar slash":preload("res://world/interface/assets/icons/Combat_icons/Assasin_skill_icons/death_from_above.png"),
"recoil slash":preload("res://world/interface/assets/icons/Combat_icons/Assasin_skill_icons/ambush.png"),
"veiled thrust":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/veiled_thrust.png"),
"shield bash":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/shield_bash.png"),
"shield pummel":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/shield_pummel.png"),
"mighty push":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/mighty_push.png"),
"smite":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/smite.png"),
"counterstrike":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/counterstrike.png"),
"aegis":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/Druideskill_41_armord.png"),
"intercept":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/intercept.png"),
"second wind":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/second_wind.png"),
"raze":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/raze.png"),
"reckless":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/reckless.png"),
"shoulder bash":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/shouler_bash.png"),
"stone splitter":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/stone_splitter.png"),
"brutal chop":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/brutal_chop.png"),
"sadistic blow":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/sadistic_blow.png"),
"fury strike":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/fury_strike.png"),
"obliteration charge":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/obliteration.png"),
"obliteration":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/obliteration.png"),
"heart thrust":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/heart_thrust.png"),
"sunder":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/sunder.png"),
"sledge":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/sledge.png"),
"toad spit":load("res://world/interface/assets/icons/Combat_icons/Generic_skills/Aura_Filth.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Generic_skills/Aura_Filth.png") else fallback,
"plantera bite":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/plantera_skills/planterabite.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") else fallback,
"plantera screech":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/plantera_skills/planteraclaw.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") else fallback,
"plantera scratch":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/plantera_skills/planterascratch.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") else fallback,
"plantera clawstrike":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/plantera_skills/planterascreech.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") else fallback,
"plantera tongueshot":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/plantera_skills/planteratongueshot.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") else fallback,
"bite":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") else fallback,
"scratch":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/claw_srtrike3.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") else fallback,
"screech":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/wall_breaker.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") else fallback,
"roll":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/wall_breaker.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") else fallback,
"devastation":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/claw_srtrike3.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") else fallback,
"infected bite":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/infected_bite.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/infected_bite.png") else fallback,
"slam":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/slam.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/slam.png") else fallback,
"claw strike":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/clawstrike.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/clawstrike.png") else fallback,
"laceration":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/claw_srtrike3.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/claw_srtrike3.png") else fallback,
"lifeline":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/lifeline.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/lifeline.png") else fallback,
"pounce":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/pounce.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/pounce.png") else fallback,
"wall breaker":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/wall_breaker.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/wall_breaker.png") else fallback,
"surge":load("res://world/interface/assets/icons/Combat_icons/Generic_skills/Druideskill_02_compund.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Generic_skills/Druideskill_02_compund.png") else fallback,
"unbreakable":load("res://world/interface/assets/icons/Combat_icons/Generic_skills/Aura_Exile.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Generic_skills/Aura_Exile.png") else fallback,
"eat":load("res://world/interface/assets/icons/Combat_icons/Generic_skills/Aura_Exile.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Generic_skills/Aura_Exile.png") else fallback,
"web shot":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/web_shot.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/web_shot.png") else fallback,
"poison shot":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/poison_shot.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/poison_shot.png") else fallback,
"burrow":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/burrow.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/burrow.png") else fallback,
"spawn spiderlings":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/spawn.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/spawn.png") else fallback,
"poisonous hairs":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/poison.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/poison.png") else fallback,
"venomous fangs":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/venomous_fangs.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/venomous_fangs.png") else fallback,
"ice breath":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/ice_breath.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/ice_breath.png") else fallback,
"fire breath":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/fire_breath.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/fire_breath.png") else fallback,
"cocytus breath":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/cocytus_breath.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/cocytus_breath.png") else fallback,
"infernal breath":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/infernal_breath.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/infernal_breath.png") else fallback,
"frost bombardment":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/frost_bombardment.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/frost_bombardment.png") else fallback,
"fire bombardment":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/fire_bombardment.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/fire_bombardment.png") else fallback,
"scorched earth":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/scorched_earth.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/scorched_earth.png") else fallback,
"frozen earth":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/frozen_earth.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/frozen_earth.png") else fallback
}
 
var skill_dmg_immunity = ["evasion", "backstep", "recoil slash", "burrow"]
var skill_collision_ingnored = ["evasion", "backstep", "recoil slash", "dodge", "slide"]
 
var skill_dmg_reduction = {
	"veiled thrust": 0.9, "counterstrike":0.75, "shield pummel":0.5, "shield bash":0.35,
	"obliteration": 0.65, "mighty push":0.5, "smite":0.1, "aegis":0.95, "second wind":0.5, "eat":0.1, "raze": 0.3
}
 
var skill_aether_cost={"second wind":15}
 
var skill_energy_cost={
"combo attack":0, "penetrating blow":1, "guard":0, "backstep":0,
"veiled thrust":15, "shield pummel":12, "shield bash":10, "mighty push":15, "smite":25, "aegis":45,
"cross draw":5, "lunar slash":10, "recoil slash":20,
"raze":24, "reckless":25, "shoulder bash":11, "stone splitter":24, "brutal chop":12, "sadistic blow":14, "fury strike":10, "obliteration charge":7, "heart thrust":35, "sunder":11, "sledge":5,
"plantera screech":5, "plantera scratch":10, "plantera clawstrike":15, "plantera tongueshot":80,
"laceration":12, "bite":0, "infected bite":10, "lifeline":47, "pounce":17, "wall breaker":45, "web shot":15, "poison shot":22, "burrow":77, "spawn spiderlings":15, "poisonous hairs":30, "venomous fangs":10,
"unbreakable":45, "surge":15,
"claw strike":0, "slam":12, "infernal breath":18, "cocytus breath":18, "fire breath":24, "ice breath":24, "fire bombardment":30, "frost bombardment":30, "scorched earth":36, "frozen earth":36,
"devastation":35,
}
var support_skills=["lifeline","unbreakable", "surge","burrow"]
var skills_by_species = {
"human":["combo attack", "shoulder bash", "laceration", "bite", "lifeline", "pounce", "sunder"],
"generic":["combo attack", "laceration", "bite", "lifeline", "pounce"],
"behemoth toad":["toad spit", "surge", "roll"],
"mudclaw":["claw strike", "laceration", "burrow", "eat", "devastation"],
"plantera":["plantera bite", "plantera screech", "plantera scratch", "plantera clawstrike", "plantera tongueshot"],
"azultera":["plantera bite", "plantera screech", "plantera scratch", "plantera clawstrike", "plantera tongueshot"],
"rosatera":["plantera bite", "plantera screech", "plantera scratch", "plantera clawstrike", "plantera tongueshot"],
"embertera":["plantera bite", "plantera screech", "plantera scratch", "plantera clawstrike", "plantera tongueshot"],
"virelia":["plantera bite", "plantera screech", "plantera scratch", "plantera clawstrike", "plantera tongueshot"],
"mole spider":["bite", "infected bite", "web shot", "wall breaker", "burrow"],
"sea spider":["bite", "infected bite", "web shot", "venomous fangs", "poison shot", "unbreakable", "surge"],
"forest spider":["bite", "venomous fangs", "web shot", "spawn spiderlings", "poison shot"],
"spiderling":["bite", "venomous fangs", "poisonous hairs", "burrow"],
"wyvern":["claw strike", "infernal breath", "fire breath", "scorched earth", "slam", "fire bombardment", "laceration"],
"mountain wyvern":["claw strike", "cocytus breath", "ice breath", "frozen earth", "slam", "frost bombardment", "laceration"],
}
var skill_penetration_chance = {"penetrating blow":1.0}
 
var skill_ranges = {
	"toad spit": true, "web shot": true, "poison shot": true, "fire breath": true, "ice breath": true,
	"infernal breath": true, "cocytus breath": true, "fire bombardment": true, "frost bombardment": true,
	"scorched earth": true, "frozen earth": true,
}
 
func isRanged(skill_name:String) -> bool:
	return skill_ranges.get(skill_name, false)
 
var skill_damages = {
"combo attack":{Type.slash:10}, "penetrating blow":{Type.pierce:15},
"veiled thrust":{Type.pierce:45}, "shield pummel":{Type.blunt:25}, "shield bash":{Type.blunt:20}, "mighty push":{Type.blunt:33}, "smite":{Type.slash:25,Type.blunt:25}, "counterstrike":{Type.slash:15,Type.blunt:10},
"cross draw":{Type.slash:15}, "recoil slash":{Type.slash:15}, "lunar slash":{Type.slash:45},
"raze":{Type.slash:40}, "stone splitter":{Type.slash:25,Type.blunt:10}, "brutal chop":{Type.slash:10,Type.blunt:10}, "shoulder bash":{Type.blunt:18}, "heart thrust":{Type.pierce:125}, "fury strike":{Type.slash:40}, "sadistic blow":{Type.slash:25}, "sunder":{Type.slash:15,Type.blunt:15}, "sledge":{Type.slash:15,Type.blunt:15}, "obliteration":{Type.slash:35},
"plantera bite":{Type.pierce:6}, "plantera screech":{Type.sonic:5}, "plantera scratch":{Type.slash:5}, "plantera clawstrike":{Type.slash:15}, "plantera tongueshot":{Type.blunt:7},
"roll":{Type.blunt:3},
"bite":{Type.pierce:15}, "infected bite":{Type.pierce:15,Type.toxic:17}, "wall breaker":{Type.blunt:35},
"devastation":{Type.slash:8},
"poisonous hairs":{Type.toxic:7}, "poison shot":{Type.toxic:15}, "web shot":{Type.blunt:10}, "venomous fangs":{Type.pierce:5,Type.blunt:3,Type.toxic:20},
"claw strike":{Type.slash:17}, "slam":{Type.blunt:28}, "infernal breath":{Type.heat:8}, "fire breath":{Type.heat:8}, "cocytus breath":{Type.cold:5}, "ice breath":{Type.cold:5}, "fire bombardment":{Type.heat:24,Type.blunt:10}, "frost bombardment":{Type.cold:24}, "scorched earth":{Type.heat:12}, "frozen earth":{Type.cold:12},
"laceration":{Type.pierce:14,Type.bleed:10}, "pounce":{Type.blunt:12,Type.pierce:6},
"toad spit":{Type.blunt:12},
}
var skill_extra_aggro = {
	"penetrating blow":50, "shield bash":50, "shield pummel":75, "counterstrike":125, "mighty push":150, "intercept":200, "smite":50,
}
 
var cooldowns = {
flasks["energy potion"].icon: 15.0,
flasks["medicine potion"].icon: 30.0,
flasks["poison potion"].icon: 20.0,
flasks["power potion"].icon: 60.0,
skills["combo attack"].resource_path:0.0,
skills["penetrating blow"].resource_path:3.0,
skills["guard"].resource_path:0.0,
skills["backstep"].resource_path:2.0,
skills["evasion"].resource_path:4.0,
skills["mine"].resource_path:1.0,
skills["chop"].resource_path:1.0,
skills["gather"].resource_path:1.0,
skills["veiled thrust"].resource_path:12.0,
skills["shield pummel"].resource_path:6.0,
skills["shield bash"].resource_path:3.0,
skills["mighty push"].resource_path:13.0,
skills["smite"].resource_path:8.0,
skills["aegis"].resource_path:3.0,
skills["counterstrike"].resource_path:10.0,
skills["intercept"].resource_path:6.0,
skills["second wind"].resource_path:65.0,
skills["cross draw"].resource_path:8,
skills["recoil slash"].resource_path:15,
skills["lunar slash"].resource_path:7,
skills["raze"].resource_path:16,
skills["shoulder bash"].resource_path:7,
skills["stone splitter"].resource_path:8,
skills["brutal chop"].resource_path:4,
skills["fury strike"].resource_path:9,
skills["sunder"].resource_path:15,
skills["sadistic blow"].resource_path:5,
skills["heart thrust"].resource_path:21,
skills["obliteration charge"].resource_path:3,
skills["obliteration"].resource_path:3,
skills["sledge"].resource_path:12,
skills["reckless"].resource_path:32,
skills["plantera screech"].resource_path:10.0,
skills["plantera scratch"].resource_path:5.0,
skills["plantera clawstrike"].resource_path:8.0,
skills["plantera tongueshot"].resource_path:25.0,
skills["toad spit"].resource_path:1.0,
skills["bite"].resource_path:1,
skills["roll"].resource_path:12.0,
skills["infected bite"].resource_path:9,
skills["wall breaker"].resource_path:22,
skills["laceration"].resource_path:5,
skills["lifeline"].resource_path:35,
skills["pounce"].resource_path:15,
skills["devastation"].resource_path:20,
skills["eat"].resource_path:30,
skills["spawn spiderlings"].resource_path:30,
skills["poisonous hairs"].resource_path:23,
skills["poison shot"].resource_path:20,
skills["web shot"].resource_path:7,
skills["burrow"].resource_path:31,
skills["venomous fangs"].resource_path:18,
skills["claw strike"].resource_path:1,
skills["slam"].resource_path:8,
skills["infernal breath"].resource_path:12,
skills["fire breath"].resource_path:18,
skills["cocytus breath"].resource_path:12,
skills["ice breath"].resource_path:18,
skills["fire bombardment"].resource_path:24,
skills["frost bombardment"].resource_path:24,
skills["scorched earth"].resource_path:30,
skills["frozen earth"].resource_path:30,
skills["unbreakable"].resource_path:45,
skills["surge"].resource_path:60,
}
var cooldown_effects = {
	"bite":{
		"reduce_cooldowns":{
			"laceration":3, "pounce":3, "infected bite":3, "wall breaker":3, "lifeline":3,
			"spawn spiderlings":3, "poisonous hairs":3, "poison shot":3, "web shot":3, "burrow":3, "venomous fangs":3,
		},
	},
}
 
# Merged getCooldown: accepts an item/skill icon Texture, a resource-path
# String, or a skill-name String -- looks it up in the single shared
# `cooldowns` dictionary (which already carries both flask icon paths and
# skill resource paths as keys), instead of Skills.gd and Global.gd
# keeping two separate cooldown dictionaries.
func getCooldown(key) -> float:
	var path := ""
	if key is Texture:
		path = key.resource_path
	elif key is String:
		if skills.has(key):
			path = skills[key].resource_path
		else:
			path = key
	else:
		return 0.0
 
	return cooldowns[path] if cooldowns.has(path) else 0.0
 
 
var on_hit_effects = {
	"combo attack":{"energy_flat":10.0, "lifesteal_flat":0.0, "lifesteal_percent":0.0},
	"penetrating blow":{"energy_flat":2.0},
	"smite":{"energy_flat":20.0},
	"plantera bite":{"energy_flat":5.0, "lifesteal_flat":0.0, "lifesteal_percent":0.0},
	"toad spit":{"energy_flat":5.0, "lifesteal_flat":0.0, "lifesteal_percent":0.0},
	"bite":{"energy_flat":5.0, "lifesteal_flat":5.0, "lifesteal_percent":1.0},
	"claw strike":{"energy_flat":15.0, "lifesteal_flat":0.0, "lifesteal_percent":0.0},
	"slam":{"energy_flat":14.0},
}
 
var status_icons = {
	"wrenched":preload("res://world/interface/assets/icons/Combat_icons/Effects_buffs_debuffs/Shamanskill_18.png"),
	"stunned":preload("res://world/interface/assets/icons/Combat_icons/Status/hypnosis.png"),
}
 
var debuffs_buffs = {
	"stunned": {"duration": 2, "malus": true},
	"plantera screech": {"stackable": true, "duration": 8, "def": -3, "def modified": ["sonic"], "balance": -0.015, "agility": -0.01, "dexterity": -0.03, "mov speed": 0.95, "malus": true},
	"eat": {"stackable": true, "duration": 8, "def": -3, "regen energy": 3, "instant regen health": 5, "balance": 0.015, "dot timer": 1, "malus": false},
	"second wind": {"stackable": false, "duration": 3, "regen health": 3, "regen energy": 10, "instant regen health": 15, "dot timer": 1, "malus": false},
	"aegis": {"stackable": true, "duration": 16, "def": 125, "def modified": ["blunt","slash","pierce","sonic","heat","cold","jolt","toxic","acid","arcane","bleed","radiant"], "balance": 0.25, "toughness": 0.15, "malus": false},
	"unbreakable": {"stackable": true, "duration": 6, "def": 8, "def modified": ["blunt", "slash", "pierce","cold","acid","heat","jolt","radiant"], "balance": 0.15, "malus": false},
	"surge": {"stackable": false, "duration": 3, "vitality": 0.15, "regen health": 15, "regen energy": 5, "dot timer": 1, "malus": false},
	"wrenched": {"stackable": false, "duration": 40, "def": -30, "def modified": ["jolt", "cold"], "balance": -0.05, "agility": -0.01, "mov speed": 0.95, "malus": true},
	"shoulder bash": {"stackable": true, "duration": 8, "def": -7, "def modified": ["blunt", "slash", "pierce","cold","acid"], "atk":-0.1, "atk modified": ["blunt"], "balance": -0.05, "malus": true},
	"medicine potion": {"stackable": false, "duration": 8, "regen health": 5, "instant regen health": 25, "dot timer": 1, "malus": false},
	"energy potion": {"stackable": false, "duration": 16, "regen energy": 10, "instant regen energy": 10, "dot timer": 1, "malus": false},
	"poison potion": {"stackable": false, "duration": 8, "damage type": Type.toxic, "damage ammount": 15, "dot timer": 1, "malus": true},
	"infected bite": {"stackable": false, "duration": 15, "damage type": Type.toxic, "damage ammount": 7, "dot timer": 1, "malus": true},
	"poison shot": {"stackable": false, "duration": 15, "damage type": Type.toxic, "damage ammount": 5, "dot timer": 3, "toughness": -0.5, "def": -15, "def modified": ["acid","toxic"], "malus": true},
	"web shot": {"stackable": false, "duration": 16, "dexterity": -0.05, "balance": -0.05, "mov speed": 0.25, "malus": true},
	"power potion": {"stackable": false, "duration": 160, "strength": 0.15, "agility": 0.03, "dexterity": 0.05, "malus": false},
	"reckless": {"stackable": false, "duration": 11, "strength": 0.35, "impact": 0.35, "agility": 0.035, "dexterity": 0.05, "def": -20, "mov speed": 1.5, "def modified": ["blunt"], "regen energy": 15, "dot timer": 1, "malus": false},
	"lifeline": {"stackable": false, "duration": 9, "regen health": 5, "regen energy": 12, "instant regen health": 15, "malus": false},
	"infernal breath":{"stackable":true, "duration":8, "damage type":Type.heat, "damage ammount":10, "def": -5, "def modified": ["heat","slash","blunt","frost"], "dot timer":1, "malus":true},
	"fire breath":{"stackable":false, "duration":12, "damage type":Type.heat, "damage ammount":16, "dot timer":1, "malus":true},
	"ice breath":{"stackable":false, "duration":12, "damage type":Type.cold, "damage ammount":16, "mov speed": 0.4, "dot timer":1, "malus":true},
	"cocytus breath":{"stackable":false, "duration":8, "damage type":Type.cold, "damage ammount":10, "mov speed": 0.4, "dot timer":1, "malus":true},
	"fire bombardment":{"stackable":false, "duration":10, "damage type":Type.heat, "damage ammount":12, "dot timer":1, "malus":true},
	"frost bombardment":{"stackable":false, "duration":10, "damage type":Type.cold, "damage ammount":12, "mov speed": 0.4, "dot timer":1, "malus":true},
	"scorched earth":{"stackable":false, "duration":15, "damage type":Type.heat, "damage ammount":14, "dot timer":1, "malus":true},
	"frozen earth":{"stackable":false, "duration":15, "damage type":Type.cold, "damage ammount":14, "mov speed": 0.4, "dot timer":1, "malus":true},
}
 
var status_effects = {}
 
func applyCooldownEffects(casted_skill:String,active_cooldowns:Dictionary)->void:
	if !cooldown_effects.has(casted_skill):
		return
	var effects=cooldown_effects[casted_skill]
 
	if effects.has("self_reset_chance"):
		if randf()<=effects["self_reset_chance"]:
			var texture=skills[casted_skill]
			active_cooldowns[texture.resource_path] = 0.01
 
	if effects.has("reset_skills"):
		for target_skill in effects["reset_skills"]:
			var chance=effects["reset_skills"][target_skill]
			if randf()<=chance:
				var texture=skills[target_skill]
				active_cooldowns.erase(texture.resource_path)
 
	if effects.has("reduce_cooldowns"):
		for target_skill in effects["reduce_cooldowns"]:
			var reduction=effects["reduce_cooldowns"][target_skill]
			var texture=skills[target_skill]
			var path=texture.resource_path
			if active_cooldowns.has(path):
				active_cooldowns[path]=max(0.0,active_cooldowns[path]-reduction)
				if active_cooldowns[path]<=0:
					active_cooldowns.erase(path)
 
var chargeable_skills = ["obliteration charge"]
var skill_rotation_allowed = {"none":true, "":true, "penetrating blow":true, "combo attack":true, "raze":true, "downed":true}
var skill_damage_level_multiplier = {"combo attack": 0.10, "sledge": 0.15, "stone splitter": 0.20, "shoulder bash":0.33}
 
func getDamageMultiplier(skill_name:String, skill_level:int) -> float:
	return 1.0 + skill_level * skill_damage_level_multiplier.get(skill_name, 0.0)
 
func canRotateDuringSkill(skill:String)->bool:
	return skill_rotation_allowed.get(skill,true)
 
func getSpeciesSkills(species):
	return skills_by_species.get(species,[])
 
func getDamages(skill_name:String, weapon_mult:float = 1.0) -> Dictionary:
	var base = skill_damages.get(skill_name, {}).duplicate(true)
	if weapon_mult != 1.0:
		for k in base.keys():
			base[k] *= weapon_mult
	return base
 
func getEnergyCost(skill:String) -> float:
	return skill_energy_cost.get(skill, 0)
 
var unbreakable_skills=[
"raze", "sledge", "stone splitter", "burrow", "web shot", "obliteration", "obliteration charge",
"infernal breath", "fire breath", "scorched earth", "slam", "fire bombardment", "cocytus breath",
"ice breath", "frozen earth", "frost bombardment"]
 
# Works whether target.anim_locks is an old-style Dictionary keyed by
# string, or a new-style Array indexed by a Lock enum defined on the
# target's own script.
const LOCK_KEY_MAP := {
	"atk1": "ATK1", "atk2": "ATK2", "atk3": "ATK3", "atk4": "ATK4", "atk5": "ATK5", "atk6": "ATK6", "atk7": "ATK7",
	"guard": "GUARD", "guard react": "GUARD_REACT", "parry": "PARRY", "die": "DIE",
	"flinch": "FLINCH", "flinch back": "FLINCH_BACK", "knocked down": "KNOCKED_DOWN", "knocked back": "KNOCKED_BACK", "downed": "DOWNED",
}
 
func getAnimLock(target, key:String) -> bool:
	if typeof(target.anim_locks) == TYPE_ARRAY:
		if !("Lock" in target) or !target.Lock.has(LOCK_KEY_MAP.get(key,"")):
			return false
		var enum_val = target.Lock[LOCK_KEY_MAP[key]]
		if enum_val < 0 or enum_val >= target.anim_locks.size():
			return false
		return target.anim_locks[enum_val]
	else:
		return target.anim_locks.get(key, false)
 
func setAnimLock(target, key:String, value:bool) -> void:
	if typeof(target.anim_locks) == TYPE_ARRAY:
		if !("Lock" in target) or !target.Lock.has(LOCK_KEY_MAP.get(key,"")):
			return
		var enum_val = target.Lock[LOCK_KEY_MAP[key]]
		if enum_val < 0 or enum_val >= target.anim_locks.size():
			return
		target.anim_locks[enum_val] = value
	else:
		target.anim_locks[key] = value
 
var impact_effects = {
	"debuffer debugging stuff":{"flinch_chance":0.0, "knockback_chance":100.0, "knockdown_chance":0.0},
	"combo attack":{"flinch_chance":8.5, "knockback_chance":5.0, "knockdown_chance":3.0},
	"penetrating blow":{"flinch_chance":100},
	"shoulder bash":{"flinch_chance":5.5, "knockback_chance":100.0, "knockdown_chance":1.25},
	"raze":{"flinch_chance":50.5, "knockback_chance":90.0, "knockdown_chance":50.0},
	"sledge":{"knockdown_chance":100.0},
	"stone splitter":{"flinch_chance":100.0},
	"brutal chop":{"flinch_chance":75.0},
	"heart thrust":{"flinch_chance":75.0},
	"fury strike":{"flinch_chance":75.0},
	"sadistic blow":{"flinch_chance":75.0},
	"sunder":{"flinch_chance":75.0},
	"obliteration":{"flinch_chance":75.0},
	"mighty push":{"knockback_chance":100.0},
	"smite":{"flinch_chance":100.0},
	"laceration":{"flinch_chance":75.0},
	"bite":{"flinch_chance":100.0},
	"infected bite":{"flinch_chance":75.0},
	"lifeline":{"flinch_chance":75.0},
	"pounce":{"flinch_chance":75.0},
	"poison shot":{"flinch_chance":100.0},
	"web shot":{"flinch_chance":100.0},
	"wall breaker":{"knockdown_chance":100.0},
	"claw strike":{"flinch_chance":75.0},
	"slam":{"knockdown_chance":100.0},
	"infernal breath":{"flinch_chance":100.0},
	"fire breath":{"flinch_chance":100.0,"knockback_chance":100.0},
	"cocytus breath":{"flinch_chance":100.0},
	"ice breath":{"flinch_chance":100.0,"knockback_chance":100.0},
	"fire bombardment":{"knockback_chance":100.0,"knockdown_chance":35.0},
	"frost bombardment":{"knockback_chance":100.0,"knockdown_chance":35.0},
	"scorched earth":{"knockdown_chance":100.0},
	"frozen earth":{"knockdown_chance":100.0},
}
var overpower_dampening:float = 0.5
var tenacity_dampening:float = 0.863
var impact_icd_ms:float = 800.0
var impact_cleanup_interval_ms:float = 30000.0  # prune stale entries every 30s
 
var last_impact_time := {}
var last_cleanup_time := 0
 
func applyImpactEffects(skill_name:String,target,attacker)->void:
	if !is_instance_valid(target) or !impact_effects.has(skill_name):
		return
	if target.current_skill in unbreakable_skills:return
	if target.current_skill in skill_dmg_immunity:return
 
	var now = OS.get_ticks_msec()
	cleanupStaleImpactEntries(now)
 
	if last_impact_time.has(target):
		if now - last_impact_time[target] < impact_icd_ms:
			return
 
	var stagger = attacker.stats.derived_stats.get("stagger", 1.0)
	var tenacity = target.stats.derived_stats.get("tenacity", 1.0)
 
	var effect_chance_multiplier = 1.0
	if tenacity > stagger:
		var raw_ratio = (tenacity - stagger) / max(stagger, 0.01)
		var resist_power = pow(raw_ratio, tenacity_dampening)
		var resist_chance = resist_power * 100.0
 
		if randf() * 100.0 <= resist_chance:
			return
 
		effect_chance_multiplier = 1.0 / (1.0 + resist_power)
	elif stagger > tenacity:
		var raw_ratio = stagger / max(tenacity, 0.01)
		effect_chance_multiplier = pow(raw_ratio, overpower_dampening)
 
	var effect = impact_effects[skill_name]
	if target.stats.health <= 0:
		return
	if getAnimLock(target,"downed") or getAnimLock(target,"die"):
		return
	if target.is_dead:
		return
	if getAnimLock(target,"guard"):
		return
	if getAnimLock(target,"guard react"):
		return
 
	if !getAnimLock(target,"flinch") or !getAnimLock(target,"knocked back") or !getAnimLock(target,"knocked down"):
			var knockback_chance = effect.get("knockback_chance", 0.0)
			var knockdown_chance = effect.get("knockdown_chance", 0.0)
			var flinch_chance = effect.get("flinch_chance", 0.0)
			var applied = false
 
			if randf() * 100.0 <= knockback_chance * effect_chance_multiplier:
				target.anim_calls.unlockAnim()
				setAnimLock(target,"knocked back",true)
				target.animation_tree.active = true
				applied = true
 
			if knockdown_chance > 0.0:
				if randf() * 100.0 <= knockdown_chance * effect_chance_multiplier:
					target.anim_calls.unlockAnim()
					setAnimLock(target,"knocked down",true)
					target.animation_tree.active = true
					applied = true
 
			if randf() * 100.0 <= flinch_chance * effect_chance_multiplier:
				target.anim_calls.unlockAnim()
				setAnimLock(target,"flinch",true)
				target.animation_tree.active = true
				applied = true
			if applied:
				last_impact_time[target] = now
 
 
func cleanupStaleImpactEntries(now:int)->void:
	if now - last_cleanup_time < impact_cleanup_interval_ms:
		return
	last_cleanup_time = now
 
	var stale_keys = []
	for key in last_impact_time.keys():
		if !is_instance_valid(key):
			stale_keys.append(key)
	for key in stale_keys:
		last_impact_time.erase(key)
 
 
func applyOnHitEffects(skill_name:String,effects:Dictionary,active_cooldowns:Dictionary,stats,damage_dealt:float)->void:
	if !effects.has(skill_name):
		return
 
	var effect=effects[skill_name]
 
	if effect.has("energy_flat") or effect.has("energy"):
		var energy_gain=effect.get("energy_flat",effect.get("energy",0.0))
		stats.energy=min(stats.max_energy,stats.energy+energy_gain)
 
	if effect.has("energy_percentage"):
		stats.energy=min(stats.max_energy,stats.energy+stats.max_energy*effect["energy_percentage"]/100.0)
 
	if effect.has("lifesteal_flat") or effect.has("lifesteal"):
		var life_gain=effect.get("lifesteal_flat",effect.get("lifesteal",0.0))
		stats.health=min(stats.max_health,stats.health+life_gain)
 
	if effect.has("lifesteal_percent"):
		stats.health=min(stats.max_health,stats.health+damage_dealt*effect["lifesteal_percent"])
 
	if effect.has("reduce_cooldowns"):
		for target_skill in effect["reduce_cooldowns"]:
			if !skills.has(target_skill):
				continue
			var reduction=effect["reduce_cooldowns"][target_skill]
			var path=skills[target_skill].resource_path
			if !active_cooldowns.has(path):
				continue
			active_cooldowns[path]=max(0.0,active_cooldowns[path]-reduction)
			if active_cooldowns[path]<=0.0:
				active_cooldowns.erase(path)
 
	if stats.health>stats.max_health:
		stats.health=stats.max_health
 

















# Fired periodically by every player/bot (see Player.gd/PlayerBOT.gd). Same
# conceptual range as a mob's LOD1 threshold (PerformanceMetrics.gd's
# lod1Range), but as a 30x30 (900 sq meter) square instead of a circle.
# Draws exactly 1 aggro from every "aggressive" mob currently inside that
# square -- tracked per entity so it's a one-time pulse per mob-enter-range
# event, not continuous spam every frame the mob stays in range.
export var aggro_pulse_half_size:float = 15.0 # 30m x 30m square (900 sq meters)
var aggro_pulse_state:Dictionary = {} # entity instance_id -> {mob instance_id: true}

func pulseAggroSignal(entity:Node) -> void:
	if !is_instance_valid(entity):
		return
	if !canRunExpensiveSearchThisFrame():
		return
	var world = _findWorldOf(entity)
	if !is_instance_valid(world) or !("world_id" in world):
		return

	var origin:Vector3 = entity.global_transform.origin
	var half:float = aggro_pulse_half_size
	var query_radius:float = half * 1.4143

	var id:int = entity.get_instance_id()
	var previously_in_range:Dictionary = aggro_pulse_state.get(id, {})
	var still_in_range:Dictionary = {}

	for node in queryRadius(world.world_id, origin, query_radius):
		if !is_instance_valid(node) or node == entity or node.is_in_group("Player"):
			continue
		if !("aggressive" in node) or !node.aggressive:
			continue

		var offset:Vector3 = node.global_transform.origin - origin
		if abs(offset.x) > half or abs(offset.z) > half:
			continue

		var mob_id:int = node.get_instance_id()
		still_in_range[mob_id] = true

		if !previously_in_range.has(mob_id) and node.has_method("addAggro"):
			node.addAggro(entity, 1)

	aggro_pulse_state[id] = still_in_range
func clearAggroPulseState(entity:Node) -> void:
	if !is_instance_valid(entity):
		return
	aggro_pulse_state.erase(entity.get_instance_id())
var _bot_visual_setup_next_ticket := 0
var bot_visual_setup_served_ticket := 0

func claimBotVisualSetupTicket() -> int:
	var t := _bot_visual_setup_next_ticket
	_bot_visual_setup_next_ticket += 1
	return t
var _texture_load_cache: Dictionary = {} # path -> Texture

func loadCachedTexture(path:String) -> Texture:
	if path == "":
		return null
	if _texture_load_cache.has(path):
		return _texture_load_cache[path]
	if !ResourceLoader.exists(path):
		return null
	var tex = load(path)
	_texture_load_cache[path] = tex
	return tex



# button_list.save was being opened from disk separately by Player.gd's
# loadCharacterData(), loadBoneData(), loadHairData(),
# loadBlendShapeDataDeferred(), and loadEyeData() -- 5 separate File.open()
# calls per player spawn. Cached here so it's read from disk once and
# reused; invalidated only when something actually writes to that file.
var _button_list_cache = null
var _button_list_cache_valid := false

func getButtonListData() -> Dictionary:
	if _button_list_cache_valid:
		return _button_list_cache
	var data := safeLoadButtonListFile("user://button_list.save")
	_button_list_cache = data
	_button_list_cache_valid = true
	return data

func safeLoadButtonListFile(path:String) -> Dictionary:
	var file := File.new()
	if file.file_exists(path) and file.open(path, File.READ) == OK:
		var loaded = file.get_var()
		file.close()
		if typeof(loaded) == TYPE_DICTIONARY and loaded.has("buttons") and typeof(loaded["buttons"]) == TYPE_ARRAY and !loaded["buttons"].empty():
			return loaded
	# Primary missing, corrupt, or has an empty roster -- fall back to the
	# last known-good backup instead of treating every character as gone.
	var bak_path := path + ".bak"
	if file.file_exists(bak_path) and file.open(bak_path, File.READ) == OK:
		var loaded_bak = file.get_var()
		file.close()
		if typeof(loaded_bak) == TYPE_DICTIONARY:
			return loaded_bak
	return {}

func invalidateButtonListCache() -> void:
	_button_list_cache_valid = false


# DragDataSkillTree.gd used to open ONE FILE PER SKILL BUTTON NODE
# ("user://Characters/<entity_name>/<node_name>.save") -- with ~166 skill
# buttons that's 166 separate File.open() calls every time a player's
# skill tree loads. Consolidated into a single file per character,
# cached in memory, written in one batch instead of per-node.
var _skill_tree_data_cache := {}   # entity_name -> {node_name: {...}}
var _skill_tree_data_loaded := {}  # entity_name -> bool
var _dirty_skill_tree_saves := {}  # entity_name -> true

func getSkillTreeSaveDir(entity_name:String) -> String:
	return "user://Characters/" + entity_name + "/"

func loadSkillTreeData(entity_name:String) -> Dictionary:
	if _skill_tree_data_loaded.get(entity_name, false):
		return _skill_tree_data_cache.get(entity_name, {})
	_skill_tree_data_loaded[entity_name] = true
	var path = getSkillTreeSaveDir(entity_name) + "skilltree.save"
	var file = File.new()
	var data := {}
	if file.file_exists(path) and file.open(path, File.READ) == OK:
		var loaded = file.get_var()
		file.close()
		if typeof(loaded) == TYPE_DICTIONARY:
			data = loaded
	_skill_tree_data_cache[entity_name] = data
	return data

func getSkillTreeNodeData(entity_name:String, node_name:String) -> Dictionary:
	var all = loadSkillTreeData(entity_name)
	var d = all.get(node_name, {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

func setSkillTreeNodeData(entity_name:String, node_name:String, node_data:Dictionary) -> void:
	if !_skill_tree_data_loaded.get(entity_name, false):
		loadSkillTreeData(entity_name)
	_skill_tree_data_cache[entity_name][node_name] = node_data
	_dirty_skill_tree_saves[entity_name] = true

func flushSkillTreeSaves() -> void:
	if _dirty_skill_tree_saves.empty():
		return
	for entity_name in _dirty_skill_tree_saves.keys():
		var dir_path = getSkillTreeSaveDir(entity_name)
		var dir = Directory.new()
		if !dir.dir_exists(dir_path):
			dir.make_dir_recursive(dir_path)
		var file = File.new()
		if file.open(dir_path + "skilltree.save", File.WRITE) == OK:
			file.store_var(_skill_tree_data_cache.get(entity_name, {}))
			file.close()
	_dirty_skill_tree_saves.clear()




var _mirrored_bot_owners := {} # bot_entity_name -> owning player's entity_name it was last mirrored under

remote func requestUpdatePartyRoster(entity_name:String, roster:Array) -> void:
	if !get_tree().is_network_server():
		return
	updatePartyRosterAndMirrorBots(entity_name, roster)

# Bots have no Party.gd node of their own to self-report a roster like a
# real player does, so Stats.shareExperienceWithParty() could never find a
# party when a BOT itself lands the kill. This mirrors a reciprocal roster
# entry keyed under the bot's own entity_name whenever a player's roster
# containing that bot changes, so bot-earned kill XP correctly shares back.
func updatePartyRosterAndMirrorBots(owner_entity_name:String, roster:Array) -> void:
	party_rosters[owner_entity_name] = roster.duplicate(true)

	for bot_name in _mirrored_bot_owners.keys():
		if _mirrored_bot_owners[bot_name] != owner_entity_name:
			continue
		var still_present := false
		for member in roster:
			if str(member.get("entity_name","")) == bot_name:
				still_present = true
				break
		if !still_present:
			party_rosters.erase(bot_name)
			_mirrored_bot_owners.erase(bot_name)

	for member in roster:
		var member_name = str(member.get("entity_name",""))
		if member_name == "":
			continue
		if !isBotEntityName(member_name):
			continue
		var bot_roster := []
		bot_roster.append({"entity_name": owner_entity_name, "peer_id": 1})
		for other in roster:
			var other_name = str(other.get("entity_name",""))
			if other_name != "" and other_name != member_name:
				bot_roster.append(other)
		party_rosters[member_name] = bot_roster
		_mirrored_bot_owners[member_name] = owner_entity_name

func isBotEntityName(entity_name:String) -> bool:
	for b in get_tree().get_nodes_in_group("BOT"):
		if is_instance_valid(b) and "entity_name" in b and b.entity_name == entity_name:
			return true
	return false
# ---------------- trader slot reservation (prevents bot pile-ups) ----------------
var _trader_slots := {} # trader_instance_id -> {bot_instance_id: slot_index}
export var trader_max_slots := 4

func reserveTraderSlot(trader:Node, bot:Node) -> int:
	if !is_instance_valid(trader) or !is_instance_valid(bot):
		return -1
	var tid := trader.get_instance_id()
	var bid := bot.get_instance_id()
	if !_trader_slots.has(tid):
		_trader_slots[tid] = {}
	var slots:Dictionary = _trader_slots[tid]
	if slots.has(bid):
		return slots[bid]
	var used := {}
	for v in slots.values():
		used[v] = true
	for i in range(trader_max_slots):
		if !used.has(i):
			slots[bid] = i
			_trader_slots[tid] = slots
			return i
	return -1

func releaseTraderSlot(trader:Node, bot:Node) -> void:
	if !is_instance_valid(trader) or !is_instance_valid(bot):
		return
	var tid := trader.get_instance_id()
	if !_trader_slots.has(tid):
		return
	var slots:Dictionary = _trader_slots[tid]
	slots.erase(bot.get_instance_id())
	if slots.empty():
		_trader_slots.erase(tid)
	else:
		_trader_slots[tid] = slots

func getTraderReservedCount(trader:Node) -> int:
	if !is_instance_valid(trader):
		return 0
	var tid := trader.get_instance_id()
	if !_trader_slots.has(tid):
		return 0
	return _trader_slots[tid].size()

func getTraderApproachOffset(slot_index:int) -> Vector3:
	if slot_index < 0:
		slot_index = 0
	var angle:float = (float(slot_index) / float(max(trader_max_slots,1))) * TAU
	var radius:float = 1.8
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func isTraderCrowded(trader:Node, world_id:String) -> bool:
	if !is_instance_valid(trader):
		return true
	var reserved := getTraderReservedCount(trader)
	if reserved >= trader_max_slots:
		return true
	if world_id == "":
		return false
	var nearby_players := 0
	for node in queryRadius(world_id, trader.global_transform.origin, 4.0):
		if is_instance_valid(node) and node.is_in_group("Player") and !node.is_in_group("BOT"):
			nearby_players += 1
	return (reserved + nearby_players) >= trader_max_slots

# ---------------- revive claim system (prevents pile-ups on one downed target) ----------------
# instance_id (downed entity) -> {"bot_id":int, "claimed_ms":int}
var _revive_claims := {}
export var revive_claim_stale_ms:int = 4000

func claimReviveTarget(target:Node, bot:Node) -> bool:
	if !is_instance_valid(target) or !is_instance_valid(bot):
		return false
	var tid := target.get_instance_id()
	var bid := bot.get_instance_id()
	var now := OS.get_ticks_msec()

	if _revive_claims.has(tid):
		var entry:Dictionary = _revive_claims[tid]
		var holder = instance_from_id(int(entry.get("bot_id", -1)))
		var holder_valid := is_instance_valid(holder)
		var stale:bool = now - int(entry.get("claimed_ms", 0)) > revive_claim_stale_ms

		if entry["bot_id"] == bid:
			entry["claimed_ms"] = now
			_revive_claims[tid] = entry
			return true

		if holder_valid and !stale:
			return false # someone else already has it, and it's fresh

	_revive_claims[tid] = {"bot_id": bid, "claimed_ms": now}
	return true

func releaseReviveTarget(target:Node, bot:Node) -> void:
	if !is_instance_valid(target) or !is_instance_valid(bot):
		return
	var tid := target.get_instance_id()
	if _revive_claims.has(tid) and int(_revive_claims[tid].get("bot_id", -1)) == bot.get_instance_id():
		_revive_claims.erase(tid)

func isReviveTargetClaimedByOther(target:Node, bot:Node) -> bool:
	if !is_instance_valid(target):
		return false
	var tid := target.get_instance_id()
	if !_revive_claims.has(tid):
		return false
	var entry:Dictionary = _revive_claims[tid]
	if int(entry.get("bot_id", -1)) == bot.get_instance_id():
		return false
	var holder = instance_from_id(int(entry.get("bot_id", -1)))
	if !is_instance_valid(holder):
		_revive_claims.erase(tid)
		return false
	if OS.get_ticks_msec() - int(entry.get("claimed_ms", 0)) > revive_claim_stale_ms:
		_revive_claims.erase(tid)
		return false
	return true
