# ============================================================
# PerformanceMetrics.gd — FULL REWRITE
#
# Dedicated-server model: clients are never servers.
#
#   AUTHORITY — true when offline (network_peer == null) or when this
#               is the dedicated server's bookkeeping copy of a
#               connected player. Authority is the ONLY thing allowed
#               to write _is_relevant / visibilityCachedInterval and
#               to freeze/unfreeze a mob.
#
#   RENDERER  — true only for this machine's own local player
#               (isLocalPlayer()), online or offline. Renderer only
#               drives local cosmetics: skeleton-mesh LOD swap,
#               character visibility, animation time-scale. It never
#               touches freeze/relevance.
#
# The old bug: every connected player's copy independently called
# freezeMob()/unfreezeMob() on the SAME shared mob -- whichever call
# landed last won, which is why mobs randomly re-froze, ignored hits,
# or never woke up. Fixed by making the decision a pure function of
# state stored ON THE MOB (mob.get_meta("lodViewers")): each authority
# pass writes its own player's current contribution, then reads back
# the FULL table (every player's contribution, pruning stale entries)
# and applies the result. freezeMob()/unfreezeMob() are idempotent
# (NPC.gd no-ops if already in that state), so redundant converging
# calls from different players in the same frame are harmless -- they
# always land on the same answer.
#
#   - A mob is kept alive (unfrozen, _is_relevant, synced) the instant
#     ANY player sees it in-frustum at LOD1 or LOD2. LOD3 does NOT
#     count, per spec ("visible AND at least LOD2").
#   - It freezes the instant NO player sees it that well (and it's not
#     mid-combat / mid-death / mid anim-lock).
#   - Refresh rate (visibilityCachedInterval, read by NPC.gd's AI tick
#     throttle) follows the BEST (nearest) LOD any current viewer
#     reports.
#   - LOD itself (mesh detail, animation speed) is purely per-viewer:
#     each player's own renderer pass decides LOD for its own screen
#     based on its own distance to the mob.
# ============================================================
# PerformanceMetrics.gd — dynamic-batch revision 
#
# Same authority/renderer contract as before:
#   AUTHORITY — offline, or the dedicated server's bookkeeping copy of a
#               connected player. Only authority writes _is_relevant /
#               visibilityCachedInterval and calls freeze/unfreeze.
#   RENDERER  — only this machine's own local player. Drives LOD mesh
#               swap / character visibility / animation time-scale only.
#
# WHAT CHANGED (server-lag fix):
#   relevanceBatches and mobRescanInterval are no longer fixed. They now
#   scale with entityCache.size() so the amount of per-mob work done in
#   any single physics frame stays close to a fixed budget
#   (targetMobsPerBatch) no matter whether there are 30 mobs or 3000.
#   Previously a fixed relevanceBatches=8 meant 30 mobs cost ~4 mobs of
#   work per frame (cheap) but 2000 mobs cost ~250 mobs of work per
#   frame (the server-side spike the profiler showed) -- and it also
#   meant a LOW mob count did comparatively MORE redundant per-frame
#   overhead (rescans, frustum fetch, viewer aggregation) relative to
#   its own batch, which is the "spikes even with only ~30 mobs active"
#   symptom in the screenshots. Scaling batch count by mob count keeps
#   cost roughly flat either way. Combat/dying mobs and anything within
#   alwaysFreshRange still get processed EVERY frame regardless of
#   batching, so responsiveness near the player and mid-fight is never
#   throttled -- only far, idle, out-of-combat mobs get spread out.
#
#   Everything else (visibility test, viewer aggregation, freeze/unfreeze
#   decision, LOD tiering) is unchanged from the previous revision.
# ============================================================
extends RichTextLabel

onready var player:KinematicBody = $"../.."

# ---------------- tunables (plain vars, no export) ----------------
var mobRescanIntervalBase = 60
var relevanceBatchesBase = 8
var targetMobsPerBatch = 40      # aim to touch ~this many mobs/frame regardless of total count

var alwaysFreshRange = 15

var lod1Range = 20.0
var lod2Range = 70.0
var lod3Range = 300.0

var refreshLod1Interval = 1
var refreshLod2Interval = 3
var refreshFarInterval = 6
var refreshFrozenInterval = 20

var viewerStaleFrames = 45

var defaultVisibilityRadius = 1.5
var visibilityRadiusPadding = 1.35

var lodUpdateInterval = 10
var animLodMinTimeScale = 0.35
var animLodTimeScaleParam = "parameters/TimeScale/scale"
var maxFullAnimMobs = 12
var _pm_frame_offset:int = 0
var cameraPath = "Camroot/h/v/Camera"

# ---------------- runtime state ----------------
var entityCache:Array = []
var mobWorldCache:Dictionary = {}
var mobRadiusCache:Dictionary = {}

var mobCombatFlagCache:Dictionary = {} # instance_id -> {"has_target":bool,"has_flag":bool}
var rendererStates:Dictionary = {}


var rescanFrame = -999999
var mobRescanInterval = 60
var lastScannedWorldId := ""
var relevanceBatches = 8
var batchIndex = 0
var camera:Camera = null
var lodFrame = -999999
var frustum:Array = []

var lastVisibleCount = 0
var lastRelevantCount = 0


func _ready() -> void:
	set_process(true)
	set_physics_process(true)
	hide()
	if is_instance_valid(player):
		_pm_frame_offset = get_instance_id() % 20
		lastScannedWorldId = currentWorldId()
		rescanMobs()
		refreshCameraReference()
var _last_processed_visual_frame:int = -1
func _physics_process(delta:float) -> void:
	if !is_instance_valid(player):
		return
	
	var authority = authorityHere()
	var renderer = rendererHere()
	if !authority and !renderer:
		return
		
	var visual_frame:int = Engine.get_frames_drawn()
	var is_new_visual_frame:bool = visual_frame != _last_processed_visual_frame
	if visual_frame == _last_processed_visual_frame:
		return
	_last_processed_visual_frame = visual_frame
	processRadiusCacheQueue()
	if Input.is_action_just_pressed("0"):
		visible = !visible
	var frame = Engine.get_physics_frames()
	var worldId = currentWorldId()

	# Forces an immediate rescan the instant this player's world changes
	# (portal, respawn-to-graveyard scene swap, etc), instead of waiting
	# up to mobRescanInterval frames with a stale/empty-for-the-new-map
	# entityCache. Otherwise scoping the cache to a single world (below)
	# would leave mobs in a freshly entered map un-evaluated for several
	# seconds.
	if worldId != lastScannedWorldId or frame - rescanFrame >= positiveInt(mobRescanInterval):
		rescanFrame = frame
		lastScannedWorldId = worldId
		rescanMobs()
		recomputeScaling()
	if (frame + _pm_frame_offset) % 20 == 0:
		refreshCameraReference()
		if !is_instance_valid(camera):
			if visible:
				updateDisplay()
			return

		frustum = camera.get_frustum()
		if frustum.empty():
			if visible:
				updateDisplay()
			return

		var batchCount = positiveInt(relevanceBatches)
		batchIndex = int((batchIndex + 1) % batchCount)

		var viewerId = player.get_network_master()
		var playerPos = player.global_transform.origin

		lastVisibleCount = 0
		lastRelevantCount = 0

		for mob in entityCache:
			if !is_instance_valid(mob):
				continue
			processMob(mob, batchCount, viewerId, frame, authority, renderer, worldId, playerPos)

		if renderer and frame - lodFrame >= positiveInt(lodUpdateInterval):
			lodFrame = frame
			updateRenderLod(authority)

		if visible:
			updateDisplay()
		
		

func authorityHere() -> bool:
	return get_tree().network_peer == null or get_tree().is_network_server()


func rendererHere() -> bool:
	return is_instance_valid(player) and player.has_method("isLocalPlayer") and player.isLocalPlayer()


func isPuppetedHere(mob) -> bool:
	return get_tree().network_peer != null and !mob.is_network_master()


func positiveInt(value) -> int:
	var result = int(value)
	if result < 1:
		result = 1
	return result


# Batch count and rescan interval both scale with how many mobs actually
# exist right now, so per-frame cost stays close to a fixed budget
# (targetMobsPerBatch) instead of growing linearly with total mob count,
# and instead of over-processing a small mob count relative to its own
# batch (the "still spikes with only ~30 mobs" symptom).
func recomputeScaling() -> void:
	var count = entityCache.size()
	if count <= 0:
		relevanceBatches = 1
		mobRescanInterval = mobRescanIntervalBase
		return
	var wanted = int(ceil(float(count) / float(max(targetMobsPerBatch, 1))))
	relevanceBatches = clamp(wanted, 1, 64)
	# fewer batches (small mob count) -> rescan less often too, nothing to save by rescanning fast
	mobRescanInterval = clamp(mobRescanIntervalBase * relevanceBatches, mobRescanIntervalBase, mobRescanIntervalBase * 8)




# ---------------- camera ----------------
func refreshCameraReference() -> void:
	var cam = findLocalCamera()
	if cam == camera and is_instance_valid(cam):
		return
	camera = cam
	lodFrame = -999999


func findLocalCamera() -> Camera:
	if !is_instance_valid(player):
		return null
	var camroot = player.get_node_or_null("Camroot")
	if is_instance_valid(camroot):
		var direct = camroot.get_node_or_null("h/v/Camera")
		if direct is Camera and is_instance_valid(direct):
			return direct
		var configured = camroot.get_node_or_null(cameraPath)
		if configured is Camera and is_instance_valid(configured):
			return configured
	var cameras = []
	collectCameras(player, cameras)
	for c in cameras:
		if c is Camera and is_instance_valid(c) and c.current:
			return c
	if !cameras.empty() and cameras[0] is Camera and is_instance_valid(cameras[0]):
		return cameras[0]
	return null


func collectCameras(node, out:Array) -> void:
	if !is_instance_valid(node):
		return
	for child in node.get_children():
		if child is Camera:
			out.append(child)
		collectCameras(child, out)


# ---------------- mob cache / world / radius / stats ----------------
var _radius_cache_queue: Array = []
export var radius_cache_per_frame := 20

#func rescanMobs() -> void:
#	entityCache.clear()
#	_radius_cache_queue.clear()
#	var worldId = currentWorldId()
#	if worldId == "":
#		return
#	var world = Global._getWorldById(worldId)
#	if !is_instance_valid(world) or !world.has_method("getAllEntities"):
#		return
#
#	for e in world.getAllEntities():
#		if !is_instance_valid(e) or e.is_in_group("Player"):
#			continue
#		cacheMobWorld(e)
#		entityCache.append(e)
#		cacheMobStats(e)
#		if !mobRadiusCache.has(e.get_instance_id()):
#			_radius_cache_queue.append(e)
#
#	var validIds = {}
#	for e in entityCache:
#		validIds[e.get_instance_id()] = true
#	for id in mobRadiusCache.keys():
#		if !validIds.has(id):
#			mobRadiusCache.erase(id)
#	for id in mobWorldCache.keys():
#		if !validIds.has(id):
#			mobWorldCache.erase(id)
#	for id in mobDataCache.keys():
#		if !validIds.has(id):
#			mobDataCache.erase(id)
#	for id in mobCombatFlagCache.keys():
#		if !validIds.has(id):
#			mobCombatFlagCache.erase(id)
#	for id in rendererStates.keys():
#		if !validIds.has(id):
#			rendererStates.erase(id)
var _rescan_count:int = 0
var prune_every_n_rescans:int = 5

func rescanMobs() -> void:
	entityCache.clear()
	_radius_cache_queue.clear()
	var worldId = currentWorldId()
	if worldId == "":
		return
	var world = Global._getWorldById(worldId)
	if !is_instance_valid(world):
		return

	var source_list:Array
	if world.has_method("getCachedEntities"):
		source_list = world.getCachedEntities()
	elif world.has_method("getAllEntities"):
		source_list = world.getAllEntities()
	else:
		return

	for e in source_list:
		if !is_instance_valid(e) or e.is_in_group("Player"):
			continue
		cacheMobWorld(e)
		entityCache.append(e)
		cacheMobStats(e)
		if !mobRadiusCache.has(e.get_instance_id()):
			_radius_cache_queue.append(e)

	_rescan_count += 1
	if _rescan_count % int(max(prune_every_n_rescans, 1.0)) != 0:
		return

	var validIds = {}
	for e in entityCache:
		validIds[e.get_instance_id()] = true
	for id in mobRadiusCache.keys():
		if !validIds.has(id):
			mobRadiusCache.erase(id)
	for id in mobWorldCache.keys():
		if !validIds.has(id):
			mobWorldCache.erase(id)
	for id in mobDataCache.keys():
		if !validIds.has(id):
			mobDataCache.erase(id)
	for id in mobCombatFlagCache.keys():
		if !validIds.has(id):
			mobCombatFlagCache.erase(id)
	for id in rendererStates.keys():
		if !validIds.has(id):
			rendererStates.erase(id)







func processRadiusCacheQueue() -> void:
	var n := 0
	while n < radius_cache_per_frame and !_radius_cache_queue.empty():
		var mob = _radius_cache_queue.pop_back()
		if is_instance_valid(mob) and !mobRadiusCache.has(mob.get_instance_id()):
			cacheMobRadius(mob)
		n += 1
func cacheMobWorld(mob) -> void:
	var id = mob.get_instance_id()
	if mobWorldCache.has(id):
		return
	var n = mob.get_parent()
	while n:
		if "world_id" in n:
			mobWorldCache[id] = n.world_id
			return
		n = n.get_parent()
	mobWorldCache[id] = ""


var mobDataCache:Dictionary = {} # instance_id -> {"stats":Node,"has_target":bool,"has_flag":bool}

func cacheMobStats(mob) -> void:
	var id = mob.get_instance_id()
	if mobDataCache.has(id):
		return
	mobDataCache[id] = {
		"stats": mob.get_node("Stats"),
		"has_target": "target" in mob,
		"has_flag": "is_in_combat" in mob,
		"has_is_dead": "is_dead" in mob
	}
func getMobData(mob) -> Dictionary:
	var id = mob.get_instance_id()
	if !mobDataCache.has(id):
		cacheMobStats(mob)
	return mobDataCache[id]

func cacheMobCombatFlags(mob) -> void:
	mobCombatFlagCache[mob.get_instance_id()] = {
		"has_target": "target" in mob,
		"has_flag": "is_in_combat" in mob
	}







func currentWorldId() -> String:
	var w = player.get_parent()
	while w:
		if "world_id" in w:
			return w.world_id
		w = w.get_parent()
	return ""


# ============================================================
# PerformanceMetrics.gd — replace cacheMobRadius() and
# collectVisualAabbs() in full
# ============================================================

func cacheMobRadius(mob) -> void:
	var id = mob.get_instance_id()
	if mobRadiusCache.has(id):
		return
	var radius = defaultVisibilityRadius
	var visuals: Array = []
	collectVisualInstancesFlat(mob, visuals)
	for vi in visuals:
		if !is_instance_valid(vi) or !vi.visible or !vi.has_method("get_transformed_aabb"):
			continue
		var box: AABB = vi.get_transformed_aabb()
		if box.size.length_squared() > 0.000001:
			var r = box.size.length() * 0.5
			if r > radius:
				radius = r
	radius *= max(visibilityRadiusPadding, 1.0)
	mobRadiusCache[id] = max(radius, 0.5)

# Single flat, non-recursive-call-heavy collection pass. Same traversal
# as before but appends into a plain array via an explicit stack instead
# of function-call recursion, so the profiler's call count for this stops
# scaling with skeleton/bone-attachment node count (previously each bone/
# mesh/attachment node under a mob's full skeleton counted as its own
# recursive "call", which is what produced "thousands of calls" for a
# literal handful of mobs).
func collectVisualInstancesFlat(root: Node, out: Array) -> void:
	var stack: Array = [root]
	while !stack.empty():
		var node = stack.pop_back()
		if !is_instance_valid(node):
			continue
		if node is VisualInstance:
			out.append(node)
		for child in node.get_children():
			stack.append(child)





func distanceSqToPlayer(mobOrigin:Vector3, playerPos:Vector3) -> float:
	return playerPos.distance_squared_to(mobOrigin)



# Memoized-per-frame check removed: this is only ever called once per
# mob per physics tick (from processMob), so the old combatCache dict
# lookup/store never actually produced a cache hit — it was pure
# overhead. Delete the "var combatCache:Dictionary = {}" declaration
# above along with this.
func isMobInCombatOrDying(mob) -> bool:
	if !is_instance_valid(mob):
		return false

	var data = getMobData(mob)
	if bool(data["has_target"]) and mob.target != null:
		return true
	if bool(data["has_flag"]) and mob.is_in_combat:
		return true

	var stats = data["stats"]
	if is_instance_valid(stats):
		if stats.health > 0:
			return false # common case (mob is fine) exits without touching is_dead at all
		if bool(data["has_is_dead"]):
			return !mob.is_dead
		return true

	return false









func lodTierForDistance(distSq:float) -> int:
	if distSq <= lod1Range * lod1Range:
		return 1
	if distSq <= lod2Range * lod2Range:
		return 2
	if distSq <= lod3Range * lod3Range:
		return 3
	return 0


func isMobInFrustum(mobOrigin:Vector3, radius:float) -> bool:
	if frustum.empty():
		return false
	for plane in frustum:
		if plane.distance_to(mobOrigin) > radius:
			return false
	return true


func processMob(mob, batchCount:int, viewerId:int, frame:int, authority:bool, renderer:bool, worldId:String, playerPos:Vector3) -> void:
	var id = mob.get_instance_id()

	if String(mobWorldCache.get(id, "")) != worldId:
		if authority:
			clearViewer(mob, viewerId)
		return

	var mobOrigin:Vector3 = mob.global_transform.origin
	var distSq = distanceSqToPlayer(mobOrigin, playerPos)
	var combatOrDying = isMobInCombatOrDying(mob)
	var hot = distSq <= alwaysFreshRange * alwaysFreshRange
	var inBatch = batchCount <= 1 or int(id) % batchCount == batchIndex

	if !hot and !inBatch and !combatOrDying:
		return

	var radius:float = mobRadiusCache.get(id, defaultVisibilityRadius)
	var lod = lodTierForDistance(distSq)
	var inView = lod > 0 and isMobInFrustum(mobOrigin, radius)
	var dist = sqrt(max(distSq, 0.0))

	# A mob standing right next to the player must never depend on the
	# frustum/cached-radius test to stay alive. That test uses an AABB
	# radius captured once at whatever pose the mob was in when first
	# scanned -- a leaping or attacking mob's mesh regularly swings past
	# that cached sphere, or straddles a frustum plane for a frame, and
	# isMobInFrustum() wrongly reports "not visible" for something plainly
	# on screen. That false negative is what was freezing mobs mid-
	# animation right beside the player. Inside alwaysFreshRange, treat
	# the mob as always visible/contributing regardless of what the
	# frustum test says -- distance alone is proof enough at that range.
	var effectiveLod = lod if lod > 0 else 1
	var effectiveInView = inView or hot

	if authority:
		var contributes = effectiveInView and effectiveLod <= 2
		if contributes:
			reportViewer(mob, viewerId, effectiveLod, dist, frame)
		else:
			clearViewer(mob, viewerId)
		applyAuthorityDecision(mob, combatOrDying, frame)

	if renderer:
		var visibleNow = effectiveInView or combatOrDying
		rendererStates[id] = {"visible": visibleNow, "dist": dist, "lod": effectiveLod}
		if visibleNow:
			lastVisibleCount += 1
# ---------------- shared per-mob viewer table (lives on the mob itself) ----------------
func viewerTable(mob) -> Dictionary:
	if !mob.has_meta("lodViewers"):
		mob.set_meta("lodViewers", {})
	return mob.get_meta("lodViewers")


func reportViewer(mob, viewerId:int, lod:int, dist:float, frame:int) -> void:
	var table = viewerTable(mob)
	table[viewerId] = {"lod": lod, "dist": dist, "frame": frame}
	mob.set_meta("lodViewers", table)


func clearViewer(mob, viewerId:int) -> void:
	if !mob.has_meta("lodViewers"):
		return
	var table = mob.get_meta("lodViewers")
	if table.has(viewerId):
		table.erase(viewerId)
		mob.set_meta("lodViewers", table)


func aggregateViewers(mob, frame:int) -> Dictionary:
	var bestLod = 99
	var bestDist = INF
	var any = false
	if mob.has_meta("lodViewers"):
		var table = mob.get_meta("lodViewers")
		var stale = []
		for viewerId in table.keys():
			var entry = table[viewerId]
			var age:int = frame - int(entry.get("frame", -999999))
			if age > viewerStaleFrames:
				stale.append(viewerId)
				continue
			any = true
			var lod:int = int(entry.get("lod", 3))
			if lod < bestLod:
				bestLod = lod
			var d:float = float(entry.get("dist", INF))
			if d < bestDist:
				bestDist = d
		if !stale.empty():
			for viewerId in stale:
				table.erase(viewerId)
			mob.set_meta("lodViewers", table)
	return {"any": any, "lod": bestLod, "dist": bestDist}


# ---------------- authority: the ONLY place that decides relevance/freeze ----------------
func applyAuthorityDecision(mob, combatOrDying:bool, frame:int) -> void:
	var agg = aggregateViewers(mob, frame)
	var relevant:bool = bool(agg.any) or combatOrDying
	var wasRelevant:bool = bool(mob._is_relevant) if "_is_relevant" in mob else false

	if "_is_relevant" in mob:
		mob._is_relevant = relevant

	var interval = refreshFrozenInterval
	if combatOrDying:
		interval = 1
	elif int(agg.lod) == 1:
		interval = refreshLod1Interval
	elif int(agg.lod) == 2:
		interval = refreshLod2Interval
	elif relevant:
		interval = refreshFarInterval

	if "visibilityCachedInterval" in mob:
		mob.visibilityCachedInterval = interval
	var nearest:float = float(agg.dist)
	if "visibilityCachedNearestDist" in mob:
		mob.visibilityCachedNearestDist = nearest
	if "cachedNearestPlayerDist" in mob:
		mob.cachedNearestPlayerDist = nearest

	if relevant:
		if "is_frozen" in mob and bool(mob.is_frozen) and mob.has_method("unfreezeMob"):
			mob.unfreezeMob()
	else:
		var hasLock = false
		if "anim_locks" in mob and typeof(mob.anim_locks) == TYPE_ARRAY:
			for lockState in mob.anim_locks:
				if lockState:
					hasLock = true
					break
		if !hasLock and "is_frozen" in mob and !bool(mob.is_frozen) and mob.has_method("freezeMob"):
			mob.freezeMob()

	if wasRelevant != relevant and is_instance_valid(Global):
		if relevant:
			Global.markActive(mob)
			lastRelevantCount += 1
		else:
			Global.markInactive(mob)


# ---------------- renderer: cosmetics only, never touches freeze/relevance ----------------
func updateRenderLod(authority:bool) -> void:
	var list = []
	for mob in entityCache:
		if !is_instance_valid(mob):
			continue
		var id = mob.get_instance_id()
		if !rendererStates.has(id):
			continue
		var st = rendererStates[id]
		if !bool(st.get("visible", false)):
			continue
		list.append({"mob": mob, "dist": float(st.get("dist", INF)), "lod": int(st.get("lod", 3)), "combat": isMobInCombatOrDying(mob)})

	list.sort_custom(self, "sortByDistAsc")

	var budget = positiveInt(maxFullAnimMobs)
	var slotIndex = 0

	for entry in list:
		var mob = entry.mob
		var combatOrDying:bool = entry.combat
		var wantsFullAnim:bool = combatOrDying or slotIndex < budget
		if !combatOrDying:
			slotIndex += 1
		applyRenderingLod(mob, float(entry.dist), int(entry.lod), combatOrDying, wantsFullAnim, authority)


func sortByDistAsc(a, b) -> bool:
	return float(a.dist) < float(b.dist)


func applyRenderingLod(mob, dist:float, lod:int, combatOrDying:bool, wantsFullAnim:bool, authority:bool) -> void:
	if !is_instance_valid(mob):
		return
	if "is_dead" in mob and mob.is_dead:
		return

	if is_instance_valid(Global):
		var skeleton = Global._getMobSkeleton(mob)
		if is_instance_valid(skeleton):
			var lodNodes:Dictionary = Global._getMobLODNodes(mob, skeleton)
			if lodNodes.get("lod1") != null or lodNodes.get("lod2") != null or lodNodes.get("lod3") != null:
				var bucket:int = lod if lod > 0 else 3
				for key in ["lod1", "lod2", "lod3"]:
					var node = lodNodes.get(key)
					if node != null and is_instance_valid(node):
						node.visible = (key == "lod" + str(bucket))

		var character = Global.getMobCharacterNode(mob)
		if is_instance_valid(character):
			character.visible = true

	if authority:
		return
	if !("animation_tree" in mob and is_instance_valid(mob.animation_tree)):
		return

	if isPuppetedHere(mob):
		mob.animation_tree.active = wantsFullAnim or combatOrDying

	if !wantsFullAnim:
		return

	var scale = 1.0
	if !combatOrDying and dist > lod1Range:
		var denom = max(lod3Range - lod1Range, 1.0)
		var t = clamp((dist - lod1Range) / denom, 0.0, 1.0)
		scale = lerp(1.0, animLodMinTimeScale, t)
	mob.animation_tree.set(animLodTimeScaleParam, scale)


# ---------------- debug display (toggle key "0") ----------------
func updateDisplay() -> void:
	text = "FPS: %d\nMobs total: %d\nBatches: %d (rescan every %d frames)\nVisible this pass: %d\nBecame relevant this pass: %d" % [
		Engine.get_frames_per_second(), entityCache.size(), relevanceBatches, mobRescanInterval, lastVisibleCount, lastRelevantCount
	]
