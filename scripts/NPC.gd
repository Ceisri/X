extends KinematicBody
## NPC.gd — Mob / NPC controller (server-authoritative, client-puppeted).
##
## ARCHITECTURE (this revision — "decoupled decision/movement"):
##
## Every previous revision ran targeting, aggro, skill-picking AND the
## actual [method KinematicBody.move_and_slide] call from the exact same
## throttled tick (once every [member visibilityCachedInterval] physics
## frames). That is why movement looked jagged and got WORSE under lag:
## a mob only actually moved once every N frames, in one big lurch sized
## to cover the whole gap (`move_tick_scale`), so any jitter in how long
## that gap actually was (lag, frame drops) showed up directly as jitter
## in how far each lurch travelled.
##
## This revision splits mob behaviour into two independently-scheduled
## passes:
##
## 1. [b]Decision pass[/b] (throttled, see [method getAiTickIntervalCached]):
##    aggro resolution, target acquisition, skill selection, area-overlap
##    queries, animation-lock bookkeeping. This is the expensive part and
##    is exactly what used to run every frame in older revisions — it is
##    still throttled the same way. It no longer calls
##    [method KinematicBody.move_and_slide] itself. Instead it writes three
##    small pieces of intent into cheap member fields:
##    [member _move_dir], [member _move_speed], [member _face_dir].
##
## 2. [b]Movement pass[/b] (every physics frame the mob is relevant and
##    unfrozen): reads those three fields and performs the actual
##    [method KinematicBody.move_and_slide_with_snap] call plus a smooth
##    turn-toward-facing step, at full undistorted speed. Because this
##    runs every physics tick with a constant, un-scaled speed, the
##    resulting motion is a plain continuous walk/run — the same kind of
##    motion a player character produces — regardless of how throttled
##    the decision pass behind it is. There is no `move_tick_scale`
##    multiplier distorting the size of each step any more, which is
##    also what removed the "faster under lag" bug: a throttled decision
##    tick can now be *late* without making the mob teleport further to
##    compensate, because movement was never paused waiting for it.
##
## A real [Tween] node is intentionally NOT used here: [Tween] would have
## to write directly to `translation`, which fights
## [method KinematicBody.move_and_slide]'s own collision resolution on
## every tick a tween is also active — that produces sinking into floors,
## clipping into walls/other mobs, and undone collision pushback, which
## is worse than the jitter it would be trying to fix. Continuous, un-
## throttled `move_and_slide` calls ARE the correct smoothing primitive
## for a physics-driven [KinematicBody]; that is what section
## [b]MOVEMENT / ROTATION EXECUTION[/b] below implements.
##
## PerformanceMetrics.gd remains the sole owner of visibility / relevance /
## LOD decisions (see the contract fields in section 3) — nothing in this
## file computes those independently. This file only reacts to them.
##
## Every custom function name and every field read/written by
## Global.gd, World.gd, Stats.gd, CrossairInspect.gd and
## PerformanceMetrics.gd is preserved unchanged from the previous
## revision so none of those systems need to change.


# =============================================================================
# SECTION 1 — NODE REFERENCES
# =============================================================================
onready var animation_tree: AnimationTree = $AnimationTree
onready var flinch_anim = animation_tree.tree_root.get_node("Flinch")
onready var stats: Node = $Stats
onready var ray_down: RayCast = $RayDown
onready var anim_calls: Node = $AnimationCalls
onready var damage_area: Area = $AreaDamage
onready var animation: AnimationPlayer = $character/AnimationPlayer
onready var skill_anim = animation_tree.tree_root.get_node("Skill")
onready var detection_area: Area = $DetectionArea
onready var ranged_detection_area: Area = $RangedDetectionArea
onready var dmg_area: Area = $AreaDamage


# =============================================================================
# SECTION 2 — IDENTITY / CREATOR / SPAWNED BODIES
# =============================================================================
var creator: KinematicBody = null setget setCreatorValue
var spawned_bodies: Array = []
var entity_name: String = "nameless"

## Assigns [member creator] and immediately reconciles aggro in both
## directions with the new creator. Called by the engine via the
## `setget` on [member creator].
func setCreatorValue(value: KinematicBody) -> void:
	creator = value
	if creator != null and is_instance_valid(creator):
		shareAggro(creator)
		getAggroFromOtherMob(creator)

## Registers this mob under [member creator]'s `spawned_bodies` list
## (idempotent) and reconciles aggro both ways. Safe to call repeatedly.
func addSelfToCreator() -> void:
	if creator == null:
		return
	if creator.spawned_bodies == null:
		creator.spawned_bodies = []
	if creator.spawned_bodies.has(self):
		return
	creator.spawned_bodies.append(self)
	shareAggro(creator)
	getAggroFromOtherMob(creator)

## Picks a random flavour name for this mob if it doesn't already have
## a non-default one. Purely cosmetic, never re-runs once named.
func randomizeEntityName() -> void:
	if entity_name != "nameless":
		return
	var prefixes: Array = ["Iron","Dark","Wild","Blood","Stone","Shadow","Frost","Fire","Storm","Ash"]
	var suffixes: Array = ["fang","claw","heart","walker","hunter","reaver","maw","blade","caller","born"]
	entity_name = prefixes[randi() % prefixes.size()] + " " + suffixes[randi() % suffixes.size()].capitalize()


# =============================================================================
# SECTION 3 — CORE STATE
# =============================================================================
var current_skill: String = ""
var is_dead: bool = false
var just_loaded_dead_grace: int = 0
var is_in_combat: bool = false
var is_being_carried: bool = false
var last_anim_lock_time: int = 0
var anim_lock_delay_ms: int = 500
var vertical_velocity: Vector3 = Vector3.ZERO
var _death_sequence_active := false

var can_move: bool = true
var _sync_offset: int = 0

## PerformanceMetrics.gd CONTRACT FIELDS.
## These names must never change: [code]PerformanceMetrics.gd[/code] reads
## AND writes them directly every physics frame it evaluates this mob,
## whether or not the mob is currently frozen. This file never computes
## these values itself — it only reacts to them.
var _is_relevant := false
var visibilityCachedInterval: int = 600
var visibilityCachedNearestDist: float = INF
var cachedNearestPlayerDist: float = INF
var is_frozen := false

## Legacy speed-compensation multiplier. Kept only for backward
## compatibility with any external reader; this revision no longer uses
## it to distort movement distance per tick (see the architecture note
## at the top of this file for why that was the source of the
## lag-dependent speed-up bug). Always effectively 1.0 in normal play.
var move_tick_scale: float = 1.0

## Legacy flag some external scripts (CrossairInspect.gd, Stats.gd) still
## poke defensively via `if "sleeping" in body: body.sleeping = false`.
## Drives nothing here; kept so those writes remain harmless no-ops.
var sleeping: bool = false

var _stats_frozen := false


# =============================================================================
# SECTION 4 — NETWORK / PUPPET STATE
# =============================================================================
puppet var net_translation := Vector3() setget setNetTranslation
puppet var net_rotation_y := 0.0
puppet var net_movement_mode := "idle"
puppet var net_current_skill := ""
puppet var net_active_lock := -1
puppet var net_is_dead := false
puppet var net_dying := false
puppet var net_skill_cooldowns := {}
puppet var net_aggro_list := []

var mob_sync_rate: float = 0.1
var puppet_lerp_speed: float = 10.0
var _has_received_mob_sync := false
var attack_instance_id: int = 0
var skill_cooldowns: Dictionary = {}

func setNetTranslation(value: Vector3) -> void:
	_has_received_mob_sync = true
	net_translation = value


# =============================================================================
# SECTION 5 — MOVEMENT / PHYSICS TUNABLES
# =============================================================================
export var aggressive: bool = false
export var hyper_aggressive: bool = true
export var aggressive_range: float = 30.0
var passive_aggro_drop_distance: float = 14.0
var passive_aggro_decay_per_second: float = 6.0
var max_fall_speed: int = 40
var activity_range: int = 400
var cached_entities: Array = []
export var near_visible_ai_interval: int = 2
export var slowest_ai_refresh_fps: float = 15.0

## Movement/rotation intent written by the decision pass and consumed
## every physics frame by the movement pass (see section 8B). Kept
## intentionally tiny and cheap to touch.
var _move_dir: Vector3 = Vector3.ZERO      ## normalized world-space direction, ZERO = not moving
var _move_speed: float = 0.0               ## units/sec to move along [member _move_dir]
var _face_dir: Vector3 = Vector3.ZERO      ## normalized world-space direction to smoothly face, ZERO = don't rotate
var _face_turn_speed: float = 3.0          ## slerp rate used this frame (walk vs run vs melee turn rates)


# =============================================================================
# SECTION 6 — RELEVANCE CONTRACT / FREEZE MECHANICS / TARGETING HELPERS
# =============================================================================

## Returns every player within [member activity_range] of this mob, used
## purely for aggro acquisition / leash checks. Has nothing to do with
## camera visibility (that's PerformanceMetrics.gd's job entirely).
func getActivePlayers() -> Array:
	if get_tree().network_peer == null:
		var world = getMyWorld()
		if !is_instance_valid(world):
			return []
		var p = world.get_node_or_null("Player")
		if is_instance_valid(p):
			return [p]
		for node in get_tree().get_nodes_in_group("Player"):
			if is_instance_valid(node) and node.get_parent() == world:
				return [node]
		return []

	var world = getMyWorld()
	var worldId: String = world.world_id if is_instance_valid(world) else ""
	if worldId == "":
		return []

	var candidates: Array = Global.getActivePlayersInWorld(worldId)
	if candidates.empty():
		for node in get_tree().get_nodes_in_group("Player"):
			if is_instance_valid(node) and node.get_parent() == world:
				candidates.append(node)

	var origin: Vector3 = global_transform.origin
	var rangeSq: float = float(activity_range) * float(activity_range)
	var players: Array = []
	for p in candidates:
		if is_instance_valid(p) and origin.distance_squared_to(p.global_transform.origin) <= rangeSq:
			players.append(p)
	return players

## Converts the externally-supplied [member visibilityCachedInterval]
## into "how many physics frames between full decision ticks" for THIS
## mob. In real combat the mob always decides at the fastest rate
## regardless of what PerformanceMetrics.gd cached, since combat
## responsiveness must never degrade due to camera framing. Movement
## itself is never gated by this value any more (see section 8B) — only
## the expensive decision-making is.
func getAiTickInterval() -> int:
	if target != null:
		if is_instance_valid(Global) and Global.getActiveMobCount() > Global.near_mob_count_threshold:
			return 4
		return 2

	var interval:int = int(visibilityCachedInterval)
	if interval < 1:
		interval = 1
	if interval > 6:
		interval = 6
	return interval

var cachedAiTickInterval := 2
var cachedAiTickFrame := -1

## Same as [method getAiTickInterval] but memoized once per physics
## frame, since several call sites want the same answer within one tick.
func getAiTickIntervalCached() -> int:
	var frame: int = Engine.get_physics_frames()
	if frame == cachedAiTickFrame:
		return cachedAiTickInterval
	cachedAiTickFrame = frame
	cachedAiTickInterval = getAiTickInterval()
	return cachedAiTickInterval

## Called by Global's MobSync ([code]buildPayload[/code]) to decide
## whether this mob belongs in a network broadcast at all this tick.
## Combat/dying are always checked live (never trusted to a stale
## cache); everything else falls through to [member _is_relevant].
func isRelevantForSync() -> bool:
	if target != null:
		return true
	if stats.health <= 0 and !is_dead:
		return true
	return _is_relevant


## Reactivates the AnimationTree without the classic
## `active = false; active = true` double-toggle, which forces a full
## graph rebuild every single call and is the actual source of the
## `_process_graph: Condition "!track_pp" is true` flood when hundreds
## of mobs do it every combat tick. Leaving the tree active and only
## swapping animation names is enough to restart blending correctly.
func reactivateTree() -> void:
	if is_instance_valid(animation_tree) and !animation_tree.active:
		animation_tree.active = true


## FREEZE MECHANICS.
## Pure mechanics only: stop/resume this node's own physics processing
## and every descendant's processing, and (for freeze) lock the
## animation into its death pose if applicable. Contains no decision-
## making of its own — PerformanceMetrics.gd calls these only after it
## has already decided, via its own camera-first visibility pass, that
## this mob should freeze or unfreeze.
func freezeMob() -> void:
	if is_frozen:
		return
	if stats.health <= 0:
		freezeAtDeathPose()
	elif is_instance_valid(animation_tree) and animation_tree.active:
		animation_tree.active = false
	is_frozen = true
	set_physics_process(false)
	setDescendantProcessing(self, false)

func unfreezeMob() -> void:
	if !is_frozen:
		return
	is_frozen = false
	set_physics_process(true)
	setDescendantProcessing(self, true)
	if !is_dead and is_instance_valid(animation_tree):
		animation_tree.active = true

var _descendant_cache: Array = []
var _descendant_cache_built := false

func buildDescendantCache() -> void:
	_descendant_cache.clear()
	collectDescendantsFlat(self, _descendant_cache)
	_descendant_cache_built = true

func collectDescendantsFlat(node: Node, out: Array) -> void:
	for child in node.get_children():
		if !is_instance_valid(child):
			continue
		if child is Occluder:
			continue
		out.append(child)
		collectDescendantsFlat(child, out)

func setDescendantProcessing(node: Node, enabled: bool) -> void:
	if !_descendant_cache_built:
		buildDescendantCache()
	for child in _descendant_cache:
		if is_instance_valid(child):
			child.set_physics_process(enabled)
			child.set_process(enabled)


## STALE ANIM-LOCK SAFETY NET.
## A mob whose anim lock never got cleared (edge case) is never eligible
## for freezing while locked, which protects against interrupting a
## mid-animation mob — but a genuinely stuck lock with no target and no
## camera watching it would otherwise tick forever for nothing. This
## timer force-clears every lock after [member stale_lock_grace_ms] of
## continuously being irrelevant AND locked.
var stale_lock_grace_ms: int = 4000
var _staleLockGraceStart: int = 0

func checkStaleAnimLockGrace() -> void:
	var now := OS.get_ticks_msec()
	if _staleLockGraceStart == 0:
		_staleLockGraceStart = now
		return
	if now - _staleLockGraceStart >= stale_lock_grace_ms:
		for i in range(anim_locks.size()):
			anim_locks[i] = false
		has_anim_lock = false
		attack_waiting = false
		_staleLockGraceStart = 0


# =============================================================================
# SECTION 7 — ENGINE LIFECYCLE
# =============================================================================
enum Lock {
	ATK1, ATK2, ATK3, ATK4, ATK5, ATK6, ATK7,
	GUARD, GUARD_REACT, PARRY, DIE,
	FLINCH, FLINCH_BACK, KNOCKED_DOWN, KNOCKED_BACK, DOWNED,
}
var anim_locks: Array = []

func initAnimLocks() -> void:
	anim_locks.resize(Lock.size())
	for i in range(anim_locks.size()):
		anim_locks[i] = false

func _ready() -> void:
	mobReady()

func mobReady()-> void:
	if get_tree().network_peer != null:
		set_network_master(1, true)
		if stats.isAuthority():
			get_tree().connect("network_peer_connected", self, "onPeerConnectedSyncMob")
	visible = true
	initAnimLocks()
	if is_instance_valid(skill_anim) and String(skill_anim.animation) == "":
		if animation.has_animation("atk1"):
			skill_anim.animation = "atk1"
		elif animation.get_animation_list().size() > 0:
			skill_anim.animation = animation.get_animation_list()[0]
	var node = get_parent()
	while node:
		if node is Spatial and (node.name.to_lower() == "spawnpoint" or node.name.to_lower().find("spawnpoint") != -1 or node.is_in_group("spawnpoint")):
			spawn_point = node
			break
		node = node.get_parent()

	call_deferred("deferredCacheEntitiesStaggered")
	registerInGlobal()
	randomize()
	spawn_point = get_parent()
	random_interval = int(rand_range(2, 5))
	addSelfToCreator()

	# No self-driven visibility pass any more — this mob starts unfrozen
	# and simply not-yet-marked-relevant. PerformanceMetrics.gd picks it
	# up on its next scan and sets _is_relevant/is_frozen correctly.
	_is_relevant = false

	is_in_combat = false
	_sync_offset = int(rand_range(0, 600))
	setupMobCollisionLayer()

	var characterNode = get_node("character")
	if characterNode != null:
		characterNode.visible = false

func deferredCacheEntitiesStaggered() -> void:
	while !Global.canBuildEntityCacheThisFrame():
		yield(get_tree(), "idle_frame")
	if !is_instance_valid(self):
		return
	cacheEntities()

func onPeerConnectedSyncMob(_id: int) -> void:
	pass # hook kept for parity; MobSync's catch-up already handles new peers

func _exit_tree() -> void:
	if is_instance_valid(Global):
		Global._freeImpostorSlot(get_instance_id())
		Global.unregister(self)
	if _is_relevant and is_instance_valid(Global):
		Global.markInactive(self)
	setStatsFrozen(false)

func registerInGlobal() -> void:
	if !is_instance_valid(Global):
		return
	var world = getMyWorld()
	var worldId: String = world.world_id if is_instance_valid(world) and "world_id" in world else ""
	Global.register(self, worldId)


# =============================================================================
# SECTION 8 — MAIN PHYSICS LOOP
# =============================================================================

func setStatsFrozen(freeze: bool) -> void:
	if freeze == _stats_frozen:
		return
	_stats_frozen = freeze
	if is_instance_valid(stats):
		stats.set_physics_process(!freeze)
		stats.set_process(!freeze)

## Applies gravity every frame it's called. Cheap (pure vector math), so
## unlike the old revision this is safe to call every physics tick — it
## no longer needs its own throttling interval, and doing so removes one
## more source of visible per-tick stutter on slopes/ledges.
onready var collision_shape: CollisionShape = $CollisionShape
func applyGravity() -> void:
	if collision_shape.disabled:
		return
	if is_on_floor():
		vertical_velocity = Vector3.DOWN * 0.5
	else:
		vertical_velocity += Vector3.DOWN * stats.weight * 2.0
		if vertical_velocity.length() > float(max_fall_speed):
			vertical_velocity = vertical_velocity.normalized() * float(max_fall_speed)
var _last_processed_visual_frame:int = -1
var _accumulated_delta:float = 0.0
var _cached_active_lock: int = -1
var _last_anim_decision_frame: int = -1
var _aiTickCounter:int = 0

func _physics_process(delta: float) -> void:
	mobPhyProcess(delta)

## SECTION 8A — DECISION SCHEDULING.
## Runs once per physics frame. Decides (via a cheap visual-frame-gated
## counter, immune to physics-substep drift) whether this is a decision
## tick, and if so calls [method runDecisionTick]. Movement/rotation
## execution (section 8B, [method runMovementTick]) always runs every
## physics frame regardless, which is what keeps motion smooth no matter
## how throttled decisions are.
func mobPhyProcess(delta)->void:
	_accumulated_delta += delta
	var rawFrame: int = Engine.get_physics_frames()
	var frame: int = rawFrame + _sync_offset
	var visual_frame_now: int = Engine.get_frames_drawn()
	var aiInterval: int = max(int(getAiTickIntervalCached()), 1)
	var hasActiveLock: bool = hasAnyAnimLock()
	var isDyingPlayback: bool = stats.health <= 0 and !is_dead

	if get_tree().network_peer != null and !is_network_master():
		applyMobPuppetState(delta)
		return

	# ---- Decision pass: throttled, expensive ----
	if _is_relevant and visual_frame_now != _last_anim_decision_frame:
		_last_anim_decision_frame = visual_frame_now
		_aiTickCounter += 1
		if hasActiveLock or isDyingPlayback or _aiTickCounter >= aiInterval:
			_aiTickCounter = 0
			runDecisionTick(delta)

	if visual_frame_now == _last_processed_visual_frame:
		return
	_last_processed_visual_frame = visual_frame_now
	_accumulated_delta = 0.0

	if is_network_master():
		if frame % 6 == 0:
			Global.updatePosition(self)

	if frame % 600 == 0:
		respawn()

	if stats.health <= 0:
		if target != null or !targets.empty():
			clearAggro()
		if !is_dead and is_instance_valid(Global):
			Global.markActive(self)

	if target != null:
		var combatInterval:int = int(combat_distance_refresh_interval)
		if combatInterval < 1:
			combatInterval = 1
		if frame % combatInterval == 0:
			updateCachedNearestPlayerDistFast()

	setStatsFrozen(!_is_relevant and target == null)

	if !is_dead and is_instance_valid(animation_tree):
		animation_tree.active = _is_relevant

	if target == null and !_is_relevant and !isDyingPlayback:
		var hasLockNow: bool = false
		for lockState in anim_locks:
			if lockState:
				hasLockNow = true
				break
		if hasLockNow:
			checkStaleAnimLockGrace()
			hasLockNow = false
			for lockState2 in anim_locks:
				if lockState2:
					hasLockNow = true
					break
		else:
			_staleLockGraceStart = 0
		if !hasLockNow:
			if !is_frozen:
				freezeMob()
			return
		if frame % 6000 == 0:
			unstuck()
		return

	# ---- Movement pass: every frame, cheap ----
	runMovementTick(delta)

	if frame % 120 == 0 and anim_locks[Lock.DIE]:
		anim_locks[Lock.DIE] = false
		if stats.health <= 0:
			freezeAtDeathPose()
		elif is_instance_valid(animation_tree):
			animation_tree.active = _is_relevant

	if frame % aiInterval == 0:
		cleanIframes()


## SECTION 8A cont. — the actual decision work: anim-lock bookkeeping,
## skill triggers and the state machine (target acquisition, combat vs
## wander choice). This is the throttled, expensive pass. It writes
## [member _move_dir] / [member _move_speed] / [member _face_dir] as its
## only interface to movement — it never calls move_and_slide itself.
func runDecisionTick(delta: float) -> void:
	_cached_active_lock = getActiveAnimLock()
	setCurrentSkillBasedOnSpecies(_cached_active_lock)
	animLockOrder()
	syncAnimLockAnimation(_cached_active_lock)
	if target != null:
		combatAnimations()
	switchState(delta, _cached_active_lock)


## SECTION 8B — MOVEMENT / ROTATION EXECUTION.
## Runs every physics frame this mob is relevant and unfrozen. Reads the
## intent fields the decision pass last wrote and performs the actual
## [method KinematicBody.move_and_slide_with_snap] plus a smooth
## turn-toward-facing step. Deliberately tiny: a couple of vector ops
## and one physics call, safe at full per-frame rate for hundreds of
## simultaneous mobs.
var _settle_skip_counter:int = 0

func runMovementTick(delta: float) -> void:
	var frame = Engine.get_physics_frames()
	if frame % 18 == 0:
		if is_dead == false:
			applyGravity()

	# Mid-attack: root motion drives the body, free movement is suppressed.
	if hasAnyAnimLock():
		if can_move:
			var velocity: Vector3 = rootMotion(delta)
			if velocity != Vector3.ZERO:
				move_and_slide(velocity, Vector3.UP)
		else:
			# Locked but not root-motion-driven (flinch/knockdown, etc) --
			# resting under gravity, same category as idle below. Must be
			# snapped or it slides down any slope over the lock's duration.
			move_and_slide_with_snap(vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)
		return

	if stats.health <= 0:
		# Corpse resting under gravity -- snap so it doesn't creep down slopes forever.
		move_and_slide_with_snap(vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)
		return

	if _face_dir != Vector3.ZERO:
		var origin: Vector3 = global_transform.origin
		var lookPos: Vector3 = origin - _face_dir
		lookPos.y = origin.y
		var targetTransform: Transform = global_transform.looking_at(lookPos, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(targetTransform.basis, delta * _face_turn_speed * 60.0 * 0.05)

	if _move_dir != Vector3.ZERO and can_move:
		_settle_skip_counter = 0
		move_and_slide_with_snap(_move_dir * _move_speed + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)
		return

	# Idle / resting: THIS branch is what was sliding mobs down slopes --
	# it used to be a bare move_and_slide(vertical_velocity, UP) with no
	# snap and no stop_on_slope, called every single frame for every
	# unfrozen idle mob instead of almost never like the old throttled code.
	if is_on_floor() and vertical_velocity.length_squared() < 0.26:
		# Fully settled (grounded, resting at the constant grounded
		# downward velocity) -- skip the physics call entirely most
		# frames instead of paying for move_and_slide on a body that
		# isn't going anywhere. Same settle-skip pattern PlayerBOT.gd
		# already uses. Still re-grounds periodically in case the mob
		# got pushed/the floor moved out from under it.
		_settle_skip_counter += 1
		if _settle_skip_counter < 10:
			return
	_settle_skip_counter = 0
	move_and_slide_with_snap(vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)

# =============================================================================
# SECTION 9 — WORLD / ENTITY CACHE
# =============================================================================
var cachedWorld: Node = null

func getMyWorld() -> Node:
	if cachedWorld != null and is_instance_valid(cachedWorld):
		return cachedWorld
	var node = get_parent()
	while node:
		if "world_id" in node:
			cachedWorld = node
			return node
		node = node.get_parent()
	return null

func cacheEntities() -> void:
	cached_entities.clear()
	var myWorld = getMyWorld()
	if !is_instance_valid(myWorld):
		return
	if myWorld.has_method("getCachedEntities"):
		for e in myWorld.getCachedEntities():
			if is_instance_valid(e):
				cached_entities.append(e)
		return
	if myWorld.has_method("getAllEntities"):
		for e in myWorld.getAllEntities():
			if is_instance_valid(e):
				cached_entities.append(e)


# =============================================================================
# SECTION 10 — COLLISION LAYER SETUP
# =============================================================================
const MOB_COLLISION_LAYER_BIT: int = 1 << 19

func setupMobCollisionLayer() -> void:
	collision_mask = collision_mask & ~collision_layer
	collision_layer = collision_layer | MOB_COLLISION_LAYER_BIT
	collision_mask = collision_mask & ~MOB_COLLISION_LAYER_BIT


# =============================================================================
# SECTION 11 — MOB SYNC (SERVER -> PUPPET)
# =============================================================================
remote func applyBruteForceSync(pos: Vector3, rotY: float, mode: String, skill: String, lock: int, dead: bool, aid: int = 0, dying: bool = false) -> void:
	_has_received_mob_sync = true
	net_translation = pos
	net_rotation_y = rotY
	net_movement_mode = mode
	net_current_skill = skill
	net_active_lock = lock
	net_is_dead = dead
	net_dying = dying
	attack_instance_id = aid

remote func applyBruteForceCombatSync(cooldowns: Dictionary, aggroList: Array) -> void:
	net_skill_cooldowns = cooldowns.duplicate()
	net_aggro_list = aggroList.duplicate()
	skill_cooldowns = net_skill_cooldowns

func buildAggroSnapshotForSync() -> Array:
	var snapshot: Array = []
	for aggroTarget in targets:
		if !is_instance_valid(aggroTarget.target_entity):
			continue
		var entName: String = "?"
		if "entity_name" in aggroTarget.target_entity:
			entName = aggroTarget.target_entity.entity_name
		snapshot.append({
			"name": aggroTarget.target_entity.name,
			"entity_name": entName,
			"aggro": aggroTarget.aggro,
			"time": aggroTarget.last_aggro_time
		})
	return snapshot

## Applies interpolated puppet state on non-authoritative peers. This is
## already the "smooth" path (linear_interpolate/lerp_angle every frame)
## and is unaffected by the decision/movement split above, which only
## concerns the authoritative side.
var _puppet_corpse_state_applied := false

func applyMobPuppetState(delta: float) -> void:
	if !_has_received_mob_sync:
		return

	global_transform.origin = global_transform.origin.linear_interpolate(net_translation, delta * puppet_lerp_speed)
	rotation.y = lerp_angle(rotation.y, net_rotation_y, delta * puppet_lerp_speed)

	movement_mode = net_movement_mode
	current_skill = net_current_skill
	is_dead = net_is_dead

	if net_dying and stats.health > 0:
		stats.health = 0
	elif !net_dying and !net_is_dead and stats.health <= 0:
		stats.health = 1

	if is_dead != _puppet_corpse_state_applied:
		_puppet_corpse_state_applied = is_dead
		Global.setCorpseCollisionState(self, is_dead)

	if is_dead:
		if animation_tree.active:
			freezeAtDeathPose()
		return

	reactivateTree()

	for i in range(anim_locks.size()):
		anim_locks[i] = false
	if net_active_lock >= 0 and net_active_lock < anim_locks.size():
		anim_locks[net_active_lock] = true

	var active: int = getActiveAnimLock()
	setCurrentSkillBasedOnSpecies(active)
	animLockOrder()
	syncAnimLockAnimation(active)
	movementanimation()

	if active >= Lock.ATK1 and active <= Lock.ATK7:
		setAnimParam("parameters/Interraction/blend_amount", 1)
	else:
		setAnimParam("parameters/Interraction/blend_amount", 0)

# =============================================================================
# SECTION 12 — DEATH POSE / ANIM PARAM HELPERS
# =============================================================================
var animParamCache: Dictionary = {}

## Sets an AnimationTree blend parameter only if it actually changed.
## [method AnimationTree.set] resolves the whole string path through the
## blend graph on every call regardless of whether the value moved, so
## this cache is what keeps that cost from being paid every frame for
## every mob whose blend values are steady.
func setAnimParam(path: String, value) -> void:
	if animParamCache.get(path) == value:
		return
	animParamCache[path] = value
	animation_tree.set(path, value)

func freezeAtDeathPose() -> void:
	var dieNode = animation_tree.tree_root.get_node("Die")
	if dieNode == null or !("animation" in dieNode):
		return
	var animName: String = dieNode.animation
	if animName == "" or !animation.has_animation(animName):
		return

	setAnimParam("parameters/IsAlive/blend_amount", 1)
	var rootMotionTrack: NodePath = animation_tree.get("root_motion_track")
	animation_tree.active = false
	animation.play(animName)
	animation.seek(animation.get_animation(animName).length, true)
	animation.stop(false)
	cancelRootMotionOnFrozenPose(rootMotionTrack)

func cancelRootMotionOnFrozenPose(rootMotionTrack: NodePath) -> void:
	if rootMotionTrack == null or rootMotionTrack == NodePath() or rootMotionTrack.get_subname_count() == 0:
		return

	var boneName: String = rootMotionTrack.get_subname(0)
	var nodePathStr := ""
	for i in range(rootMotionTrack.get_name_count()):
		nodePathStr += rootMotionTrack.get_name(i)
		if i < rootMotionTrack.get_name_count() - 1:
			nodePathStr += "/"

	var skeleton = null
	if nodePathStr != "":
		skeleton = get_node_or_null(NodePath(nodePathStr))
	if skeleton == null:
		var characterNode = get_node("character")
		if characterNode != null and nodePathStr != "":
			skeleton = characterNode.get_node_or_null(NodePath(nodePathStr))
	if skeleton == null:
		var characterNode2 = get_node_or_null("character")
		if characterNode2 != null:
			skeleton = characterNode2.get_node_or_null("Skeleton")
	if skeleton == null or !(skeleton is Skeleton):
		return

	var boneIdx: int = skeleton.find_bone(boneName)
	if boneIdx == -1:
		return

	var pose: Transform = skeleton.get_bone_pose(boneIdx)
	var rest: Transform = skeleton.get_bone_rest(boneIdx)
	pose.origin = rest.origin
	skeleton.set_bone_pose(boneIdx, pose)

func animLockOrder() -> void:
	if stats.health <= 0:
		stats.getReleased()
		setAnimParam("parameters/IsAlive/blend_amount", 1)
		can_move = false
		if is_dead == false or just_loaded_dead_grace > 0:
			animation_tree.active = true
			if just_loaded_dead_grace > 0:
				just_loaded_dead_grace -= 1
		else:
			animation_tree.active = false
	else:
		setAnimParam("parameters/IsAlive/blend_amount", 0)
		if anim_locks[Lock.KNOCKED_DOWN] == true:
			setAnimParam("parameters/Interuption/blend_amount", 1)
			setAnimParam("parameters/React/blend_amount", 0)
			can_move = false
		elif anim_locks[Lock.KNOCKED_BACK] == true:
			setAnimParam("parameters/Interuption/blend_amount", 1)
			setAnimParam("parameters/React/blend_amount", -1)
			can_move = false
		elif anim_locks[Lock.FLINCH] == true:
			setAnimParam("parameters/Interuption/blend_amount", 1)
			setAnimParam("parameters/React/blend_amount", 1)
			can_move = false
		else:
			setAnimParam("parameters/Interuption/blend_amount", 0)
			can_move = true
	if movement_mode == "run":
		setAnimParam("parameters/Interuption/blend_amount", 0)
		setAnimParam("parameters/Interraction/blend_amount", 0)
		setAnimParam("parameters/Movement/blend_amount", 1)
		anim_locks[Lock.KNOCKED_DOWN] = false
		anim_locks[Lock.KNOCKED_BACK] = false
		anim_locks[Lock.FLINCH] = false
		anim_locks[Lock.FLINCH_BACK] = false
		can_move = true


# =============================================================================
# SECTION 13 — RESPAWN
# =============================================================================
var respawn_time: float = 3
export var max_respawn_time: float = 6
export var can_respawn: bool = true
var respawn_id: int = 0
var spawn_point: Spatial
var hadTargetRecentlyUntil: int = 0

func respawn() -> void:
	if stats.health > 0:
		return
	if is_dead == true:
		respawn_time -= 1
		clearAggro()
		resetCooldowns()
	if respawn_time <= 0:
		if can_respawn:
			respawn_id += 1
			is_dead = false
			Global.setCorpseCollisionState(self, false)
			animation_tree.active = true
			setAnimParam("parameters/IsAlive/blend_amount", 0)
			setAnimParam("parameters/Interuption/blend_amount", 0)
			setAnimParam("parameters/Interraction/blend_amount", 0)
			stats.health = stats.max_health
			stats.arcane = stats.max_arcane
			stats.energy = stats.max_energy
			respawn_time = max_respawn_time
			clearAggro()
			resetCooldowns()
			is_in_combat = false
			can_move = true

			if spawn_point and is_instance_valid(spawn_point):
				var spawnPos: Vector3 = spawn_point.global_transform.origin
				global_transform.origin = Vector3(spawnPos.x + rand_range(-5, 5), spawnPos.y + 0.1, spawnPos.z + rand_range(-5, 5))
				snapToFloorInstantly()
			if is_frozen:
				unfreezeMob()
			_is_relevant = true
			if is_instance_valid(Global):
				Global.markActive(self)
			hadTargetRecentlyUntil = OS.get_ticks_msec() + 2000
		else:
			queue_free()

func snapToFloorInstantly() -> void:
	var space_state = get_world().direct_space_state
	var from:Vector3 = global_transform.origin + Vector3.UP * 50.0
	var to:Vector3 = global_transform.origin + Vector3.DOWN * 500.0
	var result = space_state.intersect_ray(from, to, [self], 0x7FFFFFFF, false, false)
	if !result.empty():
		global_transform.origin.y = result.position.y + 0.05
		vertical_velocity = Vector3.ZERO
		return
	if is_instance_valid(ray_down):
		ray_down.force_raycast_update()
		if ray_down.is_colliding():
			global_transform.origin.y = ray_down.get_collision_point().y + 0.05
			vertical_velocity = Vector3.ZERO


export var root_motion_compensation: float = 0.1

func rootMotion(delta: float) -> Vector3:
	var motion: Vector3 = animation_tree.get_root_motion_transform().origin
	motion.y = 0.0
	if motion.length_squared() < 0.000001:
		return Vector3.ZERO
	motion = global_transform.basis.xform(motion)
	return motion * root_motion_compensation / delta


# =============================================================================
# SECTION 14 — COMBAT / SKILL SELECTION
# =============================================================================
var last_active_skill: String = ""
var attack_pattern: Array = []
var attack_pattern_index: int = 0

func resetCooldowns() -> void:
	skill_cooldowns.clear()
	attack_waiting = false
	next_attack_time = 0
	has_anim_lock = false
	current_skill = ""

func getAvailableSkills() -> Array:
	var entries:Array = Global.getSpeciesSkillEntries(stats.species)
	if entries.empty():
		return []
	var result: Array = []
	for entry in entries:
		if skill_cooldowns.has(entry[1]):
			continue
		result.append({"skill": entry[0], "cooldown": entry[2]})
	return result

func startCooldown(skillName: String) -> void:
	if !Global.skills.has(skillName):
		return
	var path: String = Global.skills[skillName].resource_path
	var cd: float = Global.getCooldown(path)
	var haste: float = stats.derived_stats["cooldown_reduction"]
	cd = cd / max(0.01, haste)
	if cd > 0.0:
		skill_cooldowns[path] = cd

func updateCooldowns() -> void:
	var toRemove: Array = []
	for path in skill_cooldowns.keys():
		skill_cooldowns[path] -= 1
		if skill_cooldowns[path] <= 0.0:
			toRemove.append(path)
	for p in toRemove:
		skill_cooldowns.erase(p)

func sortCooldownDesc(a, b) -> bool:
	return a.cooldown > b.cooldown

func pickNextSkill(entries: Array) -> String:
	if entries.empty():
		return ""
	var hpRatio: float = float(stats.health) / max(stats.max_health, 1.0)
	var supportEntries: Array = []
	var normalEntries: Array = []
	for entry in entries:
		if entry.skill in Global.support_skills:
			supportEntries.append(entry)
		else:
			normalEntries.append(entry)
	supportEntries.sort_custom(self, "sortCooldownDesc")
	normalEntries.sort_custom(self, "sortCooldownDesc")
	if hpRatio <= 0.3:
		if !supportEntries.empty():
			return supportEntries[0].skill
		if !normalEntries.empty():
			return normalEntries[0].skill
		return ""
	if !supportEntries.empty():
		var supportChance: int = int(clamp((1.0 - hpRatio) * 100.0, 0, 100))
		if randi() % 100 < supportChance:
			return supportEntries[0].skill
	if !normalEntries.empty():
		return normalEntries[0].skill
	if !supportEntries.empty():
		return supportEntries[0].skill
	return ""

var randomInterval: int = 2
var skill_to_lock: Dictionary = {}
var has_anim_lock: bool = false
var next_attack_time: int = 0
var attack_waiting: bool = false
var sameSkillUses: int = 0
var previousSkillName: String = ""
var lastSpecies: String = ""
var lastSkill: String = ""
var lastLock: String = ""
var random_interval: int = 2

func getActiveAnimLock() -> int:
	for state in [Lock.DIE, Lock.FLINCH, Lock.FLINCH_BACK, Lock.KNOCKED_DOWN, Lock.KNOCKED_BACK]:
		if anim_locks[state]:
			return state
	for i in range(Lock.ATK1, Lock.ATK7 + 1):
		if anim_locks[i]:
			return i
	return -1

func setCurrentSkillBasedOnSpecies(active: int) -> void:
	var species: String = stats.species
	if !Global.skills_by_species.has(species):
		return
	if active < Lock.ATK1 or active > Lock.ATK7:
		return
	var index: int = active - Lock.ATK1
	var speciesSkills: Array = Global.skills_by_species[species]
	if index < 0 or index >= speciesSkills.size():
		return
	var skill: String = speciesSkills[index]
	if !Global.skills.has(skill):
		return
	lastSpecies = species
	lastSkill = skill

func setSkillAnimation(animName: String) -> void:
	var final: String = animName if animation.has_animation(animName) else "atk1"
	if !animation.has_animation(final):
		return
	if skill_anim.animation == final:
		reactivateTree()
	skill_anim.animation = final

func syncAnimLockAnimation(active: int) -> void:
	if active in [Lock.FLINCH, Lock.FLINCH_BACK, Lock.KNOCKED_DOWN, Lock.KNOCKED_BACK, Lock.DIE]:
		has_anim_lock = false
		attack_waiting = false
		lastLock = ""
		for i in range(Lock.ATK1, Lock.ATK7 + 1):
			anim_locks[i] = false
		return

	if active < Lock.ATK1 or active > Lock.ATK7:
		return

	var species: String = stats.species
	if !Global.skills_by_species.has(species):
		return
	var speciesSkills: Array = Global.skills_by_species[species]
	var skillIndex: int = active - Lock.ATK1
	if skillIndex < 0 or skillIndex >= speciesSkills.size():
		return
	var skillName: String = speciesSkills[skillIndex]
	if !Global.skills.has(skillName):
		return

	var animStr: String = "atk" + str(active - Lock.ATK1 + 1)
	var animName: String = animStr if animation.has_animation(animStr) else "atk1"
	if !animation.has_animation(animName):
		return

	if animName != lastLock:
		lastLock = animName
		skill_anim.animation = animName

export var ranged_aim_dot_threshold: float = 0.85
export var ranged_aim_max_wait_ms: float = 700.0
var rangedAimWaitStart: int = 0
var rangedAimSkillTracked: String = ""

func combatAnimations() -> void:
	if stats.debuff_buffs_active.has("stunned") and float(stats.debuff_buffs_active["stunned"].get("duration", 0.0)) > 0.0:
		return

	if stats.health <= 0:
		for i in range(anim_locks.size()):
			anim_locks[i] = false
		has_anim_lock = false
		attack_waiting = false
		current_skill = ""
		return

	if anim_locks[Lock.FLINCH] or anim_locks[Lock.FLINCH_BACK] or anim_locks[Lock.KNOCKED_DOWN] or anim_locks[Lock.KNOCKED_BACK] or anim_locks[Lock.DIE]:
		has_anim_lock = false
		attack_waiting = false
		for i in range(Lock.ATK1, Lock.ATK7 + 1):
			anim_locks[i] = false
		current_skill = ""
		return

	var now: int = OS.get_ticks_msec()
	if has_anim_lock:
		return
	if attack_waiting and now < next_attack_time:
		forceIdleAnimBlend()
		return
	if now - last_anim_lock_time < anim_lock_delay_ms:
		forceIdleAnimBlend()
		return

	var available: Array = getAvailableSkills()
	if available.empty():
		forceCombatIdle()
		return

	var skillName: String = pickNextSkill(available)
	if skillName == "":
		forceCombatIdle()
		return

	var energyCost: float = Global.getEnergyCost(skillName)
	if stats.energy < energyCost:
		var affordableSkill: String = ""
		for entry in available:
			var candidateCost: float = Global.getEnergyCost(entry.skill)
			if stats.energy >= candidateCost:
				affordableSkill = entry.skill
				energyCost = candidateCost
				break
		if affordableSkill == "":
			forceCombatIdle()
			return
		skillName = affordableSkill

	current_skill = skillName

	if Global.isRanged(skillName):
		if target == null or !is_instance_valid(target):
			forceCombatIdle()
			return
		var isUnrestricted: bool = Global.support_skills.has(skillName) and Global.skill_ranges.get(skillName, true) != false
		if ranged_detection_area != null:
			if !isUnrestricted and !ranged_detection_area.get_overlapping_bodies().has(target):
				forceIdleAnimBlend()
				return
	else:
		var isUnrestrictedMelee: bool = Global.support_skills.has(skillName) and Global.skill_ranges.get(skillName, true) != false
		if !isUnrestrictedMelee and !detection_area.get_overlapping_bodies().has(target):
			return

	if !Global.skills.has(skillName):
		forceCombatIdle()
		return
	var skillResource = Global.skills.get(skillName, null)
	if skillResource == null:
		forceCombatIdle()
		return
	var skillPath: String = skillResource.resource_path
	if skill_cooldowns.has(skillPath):
		return
	if !Global.skills_by_species.has(stats.species):
		forceCombatIdle()
		return

	var speciesSkillsList: Array = Global.skills_by_species[stats.species]
	var index: int = speciesSkillsList.find(skillName)
	if index < 0:
		forceCombatIdle()
		return
	if index > (Lock.ATK7 - Lock.ATK1):
		forceCombatIdle()
		return

	var lock: int = Lock.ATK1 + index
	if anim_locks[lock] and current_skill == skillName:
		return

	var animName: String = "atk" + str(index + 1)
	for i in range(Lock.ATK1, Lock.ATK7 + 1):
		anim_locks[i] = false
	anim_locks[lock] = true

	stats.energy -= energyCost
	current_skill = skillName
	_combat_idle_forced = false

	setSkillAnimation(animName)
	lastLock = animName

	has_anim_lock = true
	last_anim_lock_time = now
	next_attack_time = now + 400
	attack_waiting = true

	reactivateTree()

	startCooldown(skillName)
	setAnimationSpeed()

var _combat_idle_forced := false

func forceCombatIdle() -> void:
	if _combat_idle_forced:
		return
	_combat_idle_forced = true
	has_anim_lock = false
	attack_waiting = false
	current_skill = ""
	for i in range(Lock.ATK1, Lock.ATK7 + 1):
		anim_locks[i] = false
	animation.stop(true)
	movement_mode = "idle"
	setAnimParam("parameters/Interraction/blend_amount", 0)
	setAnimParam("parameters/Movement/blend_amount", -1)
	reactivateTree()

func forceIdleAnimBlend() -> void:
	setAnimParam("parameters/Interraction/blend_amount", 0)

func setAnimationSpeed() -> void:
	var skillScale: float = stats.derived_stats["attack_speed"]
	setAnimParam("parameters/SkillTimeScale/scale", skillScale)


# =============================================================================
# SECTION 15 — STATE MACHINE / TARGETING
# =============================================================================
var aggressive_check_interval: int = 120

func switchState(delta: float, activeLock: int) -> void:
	if stats.health <= 0:
		for i in range(anim_locks.size()):
			if i != Lock.DIE:
				anim_locks[i] = false
		if target != null or !targets.empty():
			clearAggro()
		_move_dir = Vector3.ZERO
		_face_dir = Vector3.ZERO
		return

	var rawFrame: int = Engine.get_physics_frames()
	var frame: int = rawFrame + _sync_offset

	if frame % 120 == 0:
		cleanupAggrotargets()
		cleanupDeadAggro()
		aggro_changed = true

	if aggro_changed:
		var highest: AggroTarget = findHighestAggro()
		target = highest.target_entity if highest else null
		aggro_changed = false

	if target != null:
		if !is_instance_valid(target) or isTargetDownedOrDead(target):
			removeAggroTarget(target)
			target = null
			interruptAttack()

	if target != null:
		checkLeashDistance()

	if target == null:
		if is_in_combat:
			resetCooldowns()
			is_in_combat = false
		wander()
		return

	combat(delta, activeLock)
	is_in_combat = true

	if frame % 60 == 0:
		updateCooldowns()
		decayAggroWhileRunning()


var target_history: Array = []
export var target_delay_frames: int = 10
var delayedTargetPos: Vector3 = Vector3.ZERO
var usingDelayedTarget: bool = false
var chaseOffset: Vector3 = Vector3.ZERO
var lastOffsetTarget: Vector3 = Vector3.ZERO

func updateTargetHistory(targ: Node) -> void:
	target_history.append(targ.global_transform.origin)
	if target_history.size() > target_delay_frames:
		delayedTargetPos = target_history.pop_front()
		usingDelayedTarget = true

var combat_animation_mode: float = 0
var last_melee_time: int = 0
var reached_melee_time: int = 0
var resume_chase_time: int = 0
var melee_entered: bool = true

var side_history: Array = []
export var side_check_frames: int = 30
export var side_dot_threshold: float = 0.6
var flanking: bool = false
var flank_target: Vector3 = Vector3.ZERO
var flank_timeout: int = 0
export var flank_min_distance: float = 12.0
export var flank_max_distance: float = 32.0
var walk_timer: float = 0.0

## Decision-tick combat logic. Determines whether the mob should stand
## and fight (melee/ranged range reached) or close distance, and writes
## that choice into [member _move_dir] / [member _move_speed] /
## [member _face_dir] for the per-frame movement pass to execute
## smoothly and continuously. This function itself is still throttled
## to the decision cadence — it contains the expensive area-overlap
## queries — but it no longer performs the movement itself.
func combat(delta: float, activeLock: int) -> void:
	if stats.health <= 0:
		for i in range(anim_locks.size()):
			if i != Lock.DIE:
				anim_locks[i] = false
		_move_dir = Vector3.ZERO
		_face_dir = Vector3.ZERO
		return

	if stats.debuff_buffs_active.has("stunned") and float(stats.debuff_buffs_active["stunned"].get("duration", 0.0)) > 0.0:
		_move_dir = Vector3.ZERO
		return

	if target == null or !is_instance_valid(target):
		target_history.clear()
		usingDelayedTarget = false
		movement_mode = "idle"
		melee_entered = false
		chaseOffset = Vector3.ZERO
		lastOffsetTarget = Vector3.ZERO
		current_skill = ""
		_move_dir = Vector3.ZERO
		_face_dir = Vector3.ZERO
		return

	stuckDetection(activeLock)
	updateTargetHistory(target)

	if !detection_area.monitoring:
		detection_area.monitoring = true
	if !damage_area.monitoring:
		damage_area.monitoring = true

	var origin: Vector3 = global_transform.origin
	var realTarget: Vector3 = target.global_transform.origin

	var hasLock := false
	for i in range(anim_locks.size()):
		if anim_locks[i]:
			hasLock = true
			break

	if hasLock:
		movement_mode = "idle"
		setAnimParam("parameters/Interraction/blend_amount", 1)
		_move_dir = Vector3.ZERO
		_face_dir = Vector3.ZERO
		return

	var rangedSkill: bool = false
	if current_skill != "" and Global.skills.has(current_skill):
		rangedSkill = Global.isRanged(current_skill)

	if rangedSkill:
		melee_entered = false
		var isUnrestricted: bool = Global.support_skills.has(current_skill) and Global.skill_ranges.get(current_skill, true) != false
		if ranged_detection_area != null:
			if isUnrestricted or ranged_detection_area.get_overlapping_bodies().has(target):
				movement_mode = "idle"
				setAnimParam("parameters/Interraction/blend_amount", 1)
				_move_dir = Vector3.ZERO
				_face_dir = (realTarget - origin)
				_face_dir.y = 0.0
				if _face_dir.length_squared() > 0.0001:
					_face_dir = _face_dir.normalized()
				else:
					_face_dir = Vector3.ZERO
				_face_turn_speed = turn_speed
				return
	else:
		var isUnrestrictedMelee: bool = Global.support_skills.has(current_skill) and Global.skill_ranges.get(current_skill, true) != false
		var targetInMeleeRange: bool = isUnrestrictedMelee or detection_area.get_overlapping_bodies().has(target)
		if targetInMeleeRange:
			melee_entered = true
			movement_mode = "idle"
			setAnimParam("parameters/Interraction/blend_amount", 1)
			_move_dir = Vector3.ZERO
			_face_dir = (realTarget - origin)
			_face_dir.y = 0.0
			if _face_dir.length_squared() > 0.0001:
				_face_dir = _face_dir.normalized()
			else:
				_face_dir = Vector3.ZERO
			_face_turn_speed = turn_speed
			return

	animation_tree.active = stats.health > 0
	if is_dead == false:
		animation_tree.active = true
		setAnimParam("parameters/Interraction/blend_amount", 0)

	var direction: Vector3 = realTarget - origin
	direction.y = 0

	if direction.length_squared() <= 0.001:
		movement_mode = "idle"
		_move_dir = Vector3.ZERO
		_face_dir = Vector3.ZERO
		return

	stats.getReleased()

	var isClose := false
	if rangedSkill:
		isClose = ranged_detection_area.get_overlapping_bodies().has(target)
	else:
		isClose = detection_area.get_overlapping_bodies().has(target)

	if !isClose:
		walk_timer = 0.17

	var dirNorm: Vector3 = direction.normalized()
	_face_dir = dirNorm

	if walk_timer > 0.0:
		walk_timer -= delta
		movement_mode = "run"
		_face_turn_speed = run_turn_speed
		_move_dir = dirNorm
		_move_speed = stats.run_speed
	else:
		movement_mode = "walk"
		_face_turn_speed = turn_speed
		_move_dir = dirNorm
		_move_speed = stats.walk_speed


var separationResult: Vector3 = Vector3.ZERO
var separationNextFrame: int = 0
export var separation_recalc_interval: int = 6

func applySeparation(baseTarget: Vector3) -> Vector3:
	if Engine.get_physics_frames() < separationNextFrame:
		return separationResult
	separationNextFrame = Engine.get_physics_frames() + separation_recalc_interval

	var result: Vector3 = baseTarget
	var targetPosition: Vector3 = result
	targetPosition.y = 0

	for node in cached_entities:
		if !is_instance_valid(node) or node == self or !(node is KinematicBody):
			continue
		var npcPosition: Vector3 = node.global_transform.origin
		npcPosition.y = 0
		if npcPosition.distance_squared_to(targetPosition) < 2.25:
			var separation: Vector3 = targetPosition - npcPosition
			if separation.length_squared() < 0.0001:
				separation = Vector3(rand_range(-1, 1), 0, rand_range(-1, 1))
			separation = separation.normalized()
			result += separation * 3.0

	separationResult = result
	return result

func isTargetDownedOrDead(t) -> bool:
	if t == null or !is_instance_valid(t):
		return true
	if t.has_node("Stats") and t.get_node("Stats").health <= 0:
		return true
	if "is_downed" in t and t.is_downed:
		return true
	if "is_dead" in t and t.is_dead:
		return true
	return false

func interruptAttack() -> void:
	for i in range(Lock.ATK1, Lock.ATK7 + 1):
		anim_locks[i] = false
	has_anim_lock = false
	attack_waiting = false
	setAnimParam("parameters/Interraction/blend_amount", 0)
	reactivateTree()

var animLockStartedTime: int = 0
var trackedAnimLock: int = -1
export var max_stuck_time: int = 5000

func stuckDetection(activeAnimLock: int) -> void:
	if activeAnimLock == -1:
		trackedAnimLock = -1
		animLockStartedTime = 0
		return

	var timeToStop: int = 1000 if (activeAnimLock == Lock.FLINCH or activeAnimLock == Lock.FLINCH_BACK) else max_stuck_time

	if trackedAnimLock != activeAnimLock:
		trackedAnimLock = activeAnimLock
		animLockStartedTime = OS.get_ticks_msec()
		return

	if OS.get_ticks_msec() - animLockStartedTime < timeToStop:
		return

	for i in range(anim_locks.size()):
		anim_locks[i] = false

	has_anim_lock = false
	attack_waiting = false
	trackedAnimLock = -1
	animLockStartedTime = 0

	animation_tree.active = stats.health > 0
	setAnimParam("parameters/Interuption/blend_amount", 0)
	setAnimParam("parameters/Interraction/blend_amount", 0)
	setAnimParam("parameters/InteruptionOneShot/active", false)

	if target == null:
		movement_mode = "idle"
	else:
		movement_mode = "run"

var _has_any_anim_lock_cache:bool = false
var _has_any_anim_lock_frame:int = -1

func hasAnyAnimLock() -> bool:
	var frame:int = Engine.get_frames_drawn()
	if frame == _has_any_anim_lock_frame:
		return _has_any_anim_lock_cache
	_has_any_anim_lock_frame = frame
	for i in range(anim_locks.size()):
		if anim_locks[i]:
			_has_any_anim_lock_cache = true
			return true
	_has_any_anim_lock_cache = false
	return false


# =============================================================================
# SECTION 16 — ROTATION / MOVEMENT ANIMATION HELPERS
# =============================================================================
var turn_speed: float = 3.0
var run_turn_speed: float = 6.0
var last_yaw: float = 0.0
var turn_anim: String = ""
var run_turn_anim: String = ""

## Kept for any external/legacy caller; the per-frame movement pass
## (section 8B) now performs its own equivalent slerp every tick using
## [member _face_dir], so this is no longer on the hot path internally.
func rotateToTargetMelee(speed: float, targetPos: Vector3) -> void:
	var origin: Vector3 = global_transform.origin
	var direction: Vector3 = targetPos - origin
	direction.y = 0
	if direction.length_squared() <= 0.001:
		turn_anim = ""
		return
	direction = direction.normalized()
	var lookPos: Vector3 = origin - direction
	lookPos.y = origin.y
	var targetTransform: Transform = global_transform.looking_at(lookPos, Vector3.UP)
	var currentTurnSpeed: float = turn_speed
	if movement_mode == "run":
		currentTurnSpeed = run_turn_speed
	global_transform.basis = global_transform.basis.slerp(targetTransform.basis, speed * currentTurnSpeed)
	var forward: Vector3 = -global_transform.basis.z.normalized()
	forward.y = 0
	var angle: float = forward.angle_to(direction)
	var yaw: float = rotation.y
	var deltaYaw: float = wrapf(yaw - last_yaw, -PI, PI)
	if angle > deg2rad(15):
		if deltaYaw > 0:
			turn_anim = "turn_l"
		else:
			turn_anim = "turn_r"
	else:
		turn_anim = ""
	last_yaw = yaw

func rotateToTarget(speed: float, targetPos: Vector3) -> void:
	var origin: Vector3 = global_transform.origin
	var direction: Vector3 = targetPos - origin
	direction.y = 0
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var lookPos: Vector3 = origin - direction
	lookPos.y = origin.y
	var targetTransform: Transform = global_transform.looking_at(lookPos, Vector3.UP)
	var currentTurnSpeed: float = turn_speed
	if movement_mode == "run":
		currentTurnSpeed = run_turn_speed
	global_transform.basis = global_transform.basis.slerp(targetTransform.basis, speed * currentTurnSpeed)

func movementanimation() -> void:
	match movement_mode:
		"idle":
			setAnimParam("parameters/Movement/blend_amount", -1)
		"walk":
			setAnimParam("parameters/Interraction/blend_amount", 0)
			setAnimParam("parameters/Movement/blend_amount", 0)
		"run":
			setAnimParam("parameters/Interraction/blend_amount", 0)
			setAnimParam("parameters/Movement/blend_amount", 1)


# =============================================================================
# SECTION 17 — WANDER / LEASH
# =============================================================================
var wander_dir: Vector3 = Vector3.ZERO
var wander_dir_next_change: int = 0
export var max_wander_distance: float = 50.0
export var return_distance: float = 25.0
var returningToSpawn: bool = false
var returningToSpawnStuckCheckTime: int = 0
var returningToSpawnStuckCheckPos: Vector3 = Vector3.ZERO
var returningToSpawnProgressDeadline: int = 0
export var return_stuck_check_interval_ms: int = 1500
export var return_stuck_min_progress: float = 1.0
export var return_stuck_grace_ms: int = 12000
export var leash_return_teleport_time: float = 8000.0
var returningToSpawnStartTime: int = 0
var returningToCreator: bool = false
var returningToCreatorStartTime: int = 0
var wanderTargetStartTime: int = 0
var movement_mode: String = "idle"
var stored_body: KinematicBody = null
var nav_path: Array = []
var nav_index: int = 0
var wander_target: Vector3 = Vector3.ZERO

func checkLeashDistance() -> void:
	if hyper_aggressive:
		return
	if target == null:
		return
	var anchor: Vector3
	if creator != null and is_instance_valid(creator):
		anchor = creator.global_transform.origin
	elif spawn_point and is_instance_valid(spawn_point):
		anchor = spawn_point.global_transform.origin
	else:
		return
	if !is_instance_valid(target):
		return
	var targetPos: Vector3 = target.global_transform.origin
	if anchor.distance_to(targetPos) > max_wander_distance:
		removeAggroTarget(target)


var _wander_state_next_frame:int = -1
var _wander_is_stopped:bool = false
var _wander_dir_vec:Vector3 = Vector3.ZERO
var _move_state_next_ms:int = -1
var _wander_next_move_state_ms:int=-1
var _wander_next_detection_frame:int=0
var _wander_next_teleport_check_frame:int=0
var _wander_creator:KinematicBody=null
var _wander_creator_valid:bool=false
var _wander_last_anim_move:int=999

## Decision-tick wander logic. Same responsibilities as before (idle/
## moving state switch, follow-creator wander, return-to-spawn leash,
## random free wander, nav-path following) but now only WRITES
## [member _move_dir] / [member _move_speed] / [member _face_dir]
## instead of calling [method KinematicBody.move_and_slide_with_snap]
## directly — the per-frame movement pass executes the actual motion
## smoothly and continuously between decision ticks.
func wander()->void:
	var frame:int=Engine.get_physics_frames()

	var stun=stats.debuff_buffs_active.get("stunned",null)
	if stun!=null and float(stun.get("duration",0.0))>0.0:
		movement_mode="idle"
		setWanderMovementAnim(-1)
		_move_dir = Vector3.ZERO
		_face_dir = Vector3.ZERO
		return

	if is_in_combat:
		is_in_combat=false
	setAnimParam("parameters/Interraction/blend_amount",0)

	if frame>=_wander_state_next_frame: updateState()

	var now_ms:int=-1

	if frame>=_wander_next_move_state_ms:
		if now_ms==-1: now_ms=OS.get_ticks_msec()
		movementStateSwitchCached(now_ms)

	if frame>=_wander_next_detection_frame:
		_wander_next_detection_frame=frame+30
		if detection_area.monitoring: detection_area.monitoring=false
		if damage_area.monitoring: damage_area.monitoring=false

	if _wander_is_stopped:
		movement_mode="idle"
		setWanderMovementAnim(-1)
		_move_dir = Vector3.ZERO
		_face_dir = Vector3.ZERO
		return

	var creator_valid:=is_instance_valid(creator)
	if creator_valid:
		_wander_creator=creator
		_wander_creator_valid=true
	elif _wander_creator_valid:
		_wander_creator=null
		_wander_creator_valid=false

	if _wander_creator_valid:
		var creator_pos:Vector3=_wander_creator.global_transform.origin
		var my_pos:Vector3=global_transform.origin

		if wander_target==Vector3.ZERO or frame>=wander_dir_next_change:
			var angle:=randf()*TAU
			var radius:=rand_range(3.0,12.0)
			wander_target=creator_pos+Vector3(cos(angle)*radius,0.0,sin(angle)*radius)
			wander_dir_next_change=frame+int(rand_range(60,180))
			if now_ms==-1: now_ms=OS.get_ticks_msec()
			wanderTargetStartTime=now_ms

		var dir:Vector3=wander_target-my_pos
		dir.y=0.0
		var dir_len_sq:float=dir.length_squared()

		if dir_len_sq<2.25:
			wander_target=Vector3.ZERO
			wanderTargetStartTime=0
			movement_mode="idle"
			setWanderMovementAnim(-1)
			_move_dir = Vector3.ZERO
			_face_dir = Vector3.ZERO
			return

		if frame>=_wander_next_teleport_check_frame:
			_wander_next_teleport_check_frame=frame+30
			if now_ms==-1: now_ms=OS.get_ticks_msec()
			if now_ms-wanderTargetStartTime>=leash_return_teleport_time:
				global_transform.origin=Vector3(creator_pos.x+rand_range(-5.0,5.0),creator_pos.y+0.5,creator_pos.z+rand_range(-5.0,5.0))
				wander_target=Vector3.ZERO
				wanderTargetStartTime=0
				return

		dir=dir/sqrt(dir_len_sq)
		_wander_dir_vec=-dir

		if nav_path.size()>0:
			moveforward()
			return

		setWanderIntent(dir)
		return

	if spawn_point!=null and is_instance_valid(spawn_point):
		var my_pos:Vector3=global_transform.origin
		var spawn_pos:Vector3=spawn_point.global_transform.origin
		var dir_to_spawn:Vector3=spawn_pos-my_pos
		dir_to_spawn.y=0.0
		var dist_sq:=dir_to_spawn.length_squared()
		var return_sq:=return_distance*return_distance
		var max_wander_sq:=max_wander_distance*max_wander_distance

		if returningToSpawn:
			if dist_sq<=return_sq:
				returningToSpawn=false
				returningToSpawnStartTime=0
				returningToSpawnStuckCheckTime=0
				returningToSpawnProgressDeadline=0
			else:
				if now_ms==-1: now_ms=OS.get_ticks_msec()

				if returningToSpawnStuckCheckTime==0:
					returningToSpawnStuckCheckTime=now_ms
					returningToSpawnStuckCheckPos=my_pos
					returningToSpawnProgressDeadline=now_ms+return_stuck_grace_ms
				elif now_ms-returningToSpawnStuckCheckTime>=return_stuck_check_interval_ms:
					var moved_sq:=my_pos.distance_squared_to(returningToSpawnStuckCheckPos)
					returningToSpawnStuckCheckTime=now_ms
					returningToSpawnStuckCheckPos=my_pos
					if moved_sq>=return_stuck_min_progress*return_stuck_min_progress: returningToSpawnProgressDeadline=now_ms+return_stuck_grace_ms

				if now_ms>=returningToSpawnProgressDeadline:
					global_transform.origin=Vector3(spawn_pos.x+rand_range(-5.0,5.0),spawn_pos.y+0.5,spawn_pos.z+rand_range(-5.0,5.0))
					returningToSpawn=false
					returningToSpawnStartTime=0
					returningToSpawnStuckCheckTime=0
					returningToSpawnProgressDeadline=0
					return

				var inv_len:float=1.0/sqrt(dist_sq) if dist_sq>0.0 else 0.0
				dir_to_spawn=dir_to_spawn*inv_len
				_wander_dir_vec=-dir_to_spawn
				movement_mode="run"
				setWanderMovementAnim(1)
				_face_dir = dir_to_spawn
				_face_turn_speed = run_turn_speed
				_move_dir = dir_to_spawn
				_move_speed = stats.run_speed
				return
		elif dist_sq>max_wander_sq:
			returningToSpawn=true
			if now_ms==-1: now_ms=OS.get_ticks_msec()
			returningToSpawnStartTime=now_ms
			returningToSpawnStuckCheckTime=0
			returningToSpawnProgressDeadline=0
			return

	if wander_dir==Vector3.ZERO or frame>=wander_dir_next_change:
		wander_dir=Vector3(randf()*2.0-1.0,0.0,randf()*2.0-1.0)
		var wd_len_sq:float=wander_dir.length_squared()
		if wd_len_sq<0.0001: wander_dir=Vector3.FORWARD
		else: wander_dir=wander_dir/sqrt(wd_len_sq)
		wander_dir_next_change=frame+int(rand_range(30,120))

	_wander_dir_vec=-wander_dir

	if nav_path.size()>0:
		moveforward()
		return

	setWanderIntent(wander_dir)

## Writes [member _move_dir]/[member _move_speed]/[member _face_dir]
## for a plain free-wander step in direction [param dir], honouring the
## current walk/run [member movement_mode].
func setWanderIntent(dir: Vector3) -> void:
	_face_dir = dir
	_face_turn_speed = run_turn_speed if movement_mode == "run" else turn_speed
	if movement_mode=="run":
		setWanderMovementAnim(1)
		_move_dir = dir
		_move_speed = stats.run_speed
	else:
		movement_mode="walk"
		setWanderMovementAnim(0)
		_move_dir = dir
		_move_speed = stats.walk_speed

func movementStateSwitchCached(now:int)->void:
	if _wander_next_move_state_ms>=0 and now<_wander_next_move_state_ms: return
	_wander_next_move_state_ms=now+int(rand_range(8500,35000))
	if randf()<=0.9:
		movement_mode="walk"
		setWanderMovementAnim(0)
	else:
		movement_mode="run"
		setWanderMovementAnim(1)

func setWanderMovementAnim(mode:int)->void:
	if _wander_last_anim_move==mode: return
	_wander_last_anim_move=mode
	if mode==1: setAnimParam("parameters/Movement/blend_amount",1)
	elif mode==0: setAnimParam("parameters/Movement/blend_amount",0)
	else: setAnimParam("parameters/Movement/blend_amount",-1)

## Legacy standalone rotate step. No longer called from the wander/
## combat decision paths (the per-frame movement pass in section 8B
## performs the equivalent rotation every tick using [member _face_dir]
## instead), kept only for any external caller.
func rotateMobLight()->void:
	if _wander_dir_vec==Vector3.ZERO: return
	var target_pos:Vector3=global_transform.origin+_wander_dir_vec
	target_pos.y=global_transform.origin.y
	var forward:Vector3=-global_transform.basis.z
	forward.y=0.0
	if forward.length_squared()>0.0001:
		forward=forward.normalized()
		if forward.dot(_wander_dir_vec)>0.995: return
	var target_transform:Transform=global_transform.looking_at(target_pos,Vector3.UP)
	global_transform.basis=global_transform.basis.slerp(target_transform.basis,0.1)

## Nav-path follow, decision-tick side: advances [member nav_index] as
## points are reached and writes intent fields for the current leg.
func moveforward()->void:
	if nav_path.size()<=0:
		_move_dir = Vector3.ZERO
		return
	if nav_index>=nav_path.size():
		nav_path.clear()
		nav_index=0
		_move_dir = Vector3.ZERO
		return

	var nextPos:Vector3=nav_path[nav_index]
	var dir:Vector3=nextPos-global_transform.origin
	dir.y=0.0

	if dir.length_squared()<1.0:
		nav_index+=1
		if nav_index>=nav_path.size():
			nav_path.clear()
			nav_index=0
		return

	dir=dir.normalized()
	set_meta("dir",-dir)

	if movement_mode=="run":
		setWanderMovementAnim(1)
		_face_dir = dir
		_face_turn_speed = run_turn_speed
		_move_dir = dir
		_move_speed = stats.run_speed
	elif movement_mode=="walk":
		setWanderMovementAnim(0)
		_face_dir = dir
		_face_turn_speed = turn_speed
		_move_dir = dir
		_move_speed = stats.walk_speed


func updateState()->void:
	var frames:int=Engine.get_physics_frames()
	if _wander_state_next_frame<0:
		_wander_state_next_frame=frames+int(rand_range(120,600))
		_wander_is_stopped=false
		return
	if frames<_wander_state_next_frame: return
	_wander_is_stopped=!_wander_is_stopped
	if _wander_is_stopped:
		nav_path.clear()
		nav_index=0
	_wander_state_next_frame=frames+int(rand_range(120,600))


func movementStateSwitch()->void:
	var now:int=OS.get_ticks_msec()
	if _wander_next_move_state_ms>=0 and now<_wander_next_move_state_ms: return
	_wander_next_move_state_ms=now+int(rand_range(8500,35000))
	if randf()<=0.9:
		movement_mode="walk"
		setWanderMovementAnim(0)
	else:
		movement_mode="run"
		setWanderMovementAnim(1)

func moveToTarget() -> void:
	if !is_instance_valid(target):
		return
	var dir: Vector3 = target.global_transform.origin - global_transform.origin
	dir.y = 0
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	set_meta("dir", -dir)
	_face_dir = dir
	_move_dir = dir
	_move_speed = stats.run_speed

func rotateMob() -> void:
	if _wander_dir_vec == Vector3.ZERO:
		return
	var targetPos: Vector3 = global_transform.origin + _wander_dir_vec
	targetPos.y = global_transform.origin.y
	var targetTransform: Transform = global_transform.looking_at(targetPos, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(targetTransform.basis, 0.1)


# =============================================================================
# SECTION 18 — PRE-AGGRO / AGGRESSIVE ACQUISITION
# =============================================================================
func hasRealCombatWith(entity: Node) -> bool:
	if !is_instance_valid(entity):
		return false
	if stats.damage_meter.has(entity.get_instance_id()):
		return true
	if entity.has_node("Stats"):
		var theirStats = entity.get_node("Stats")
		if "damage_meter" in theirStats and theirStats.damage_meter.has(get_instance_id()):
			return true
	return false


# =============================================================================
# SECTION 19 — AGGRO MANAGEMENT
# =============================================================================
var target: Node = null
var targets: Array = []
var aggro_changed: bool = true

class AggroTarget:
	var target_entity: Node
	var aggro: float = 0
	var last_aggro_time: int = 0

func addAggro(targetEntity: Node, amount: int) -> AggroTarget:
	if stats.health <= 0:
		return getAggro(targetEntity)
	sleeping = false
	var aggroTarget: AggroTarget = getAggro(targetEntity)
	aggroTarget.aggro += amount
	aggroTarget.last_aggro_time = OS.get_system_time_secs()

	var highest = findHighestAggro()
	target = highest.target_entity if highest and highest.aggro > 0 else null

	if creator != null and is_instance_valid(creator):
		creator.addAggro(targetEntity, amount)
		aggro_changed = true
	return aggroTarget

func setAggroValue(targetEntity: Node, amount: float, time: int) -> void:
	if targetEntity == null or stats.health <= 0:
		return
	var aggroTarget: AggroTarget = getAggro(targetEntity)
	if aggroTarget == null:
		return
	if amount > aggroTarget.aggro:
		aggroTarget.aggro = amount
		aggroTarget.last_aggro_time = time
		aggro_changed = true

func shareAggro(withWhom) -> void:
	if withWhom == null or !is_instance_valid(withWhom):
		return
	if stats.health <= 0:
		return
	for aggroTarget in targets:
		if !is_instance_valid(aggroTarget.target_entity):
			continue
		withWhom.setAggroValue(aggroTarget.target_entity, aggroTarget.aggro, aggroTarget.last_aggro_time)

func getAggroFromOtherMob(otherMob) -> void:
	if otherMob == null or !is_instance_valid(otherMob):
		return
	if stats.health <= 0:
		return
	for otherAggro in otherMob.targets:
		if !is_instance_valid(otherAggro.target_entity):
			continue
		setAggroValue(otherAggro.target_entity, otherAggro.aggro, otherAggro.last_aggro_time)
	aggro_changed = true
	var highest = findHighestAggro()
	target = highest.target_entity if highest and highest.aggro > 0 else null

func clearAggro() -> void:
	if target != null:
		hadTargetRecentlyUntil = OS.get_ticks_msec() + 5000
	target = null
	targets.clear()
	dead_target_aggro.clear()
	target_history.clear()
	usingDelayedTarget = false

func removeAggroTarget(targetEntity: Node) -> void:
	for i in range(targets.size() - 1, -1, -1):
		if targets[i].target_entity == targetEntity:
			targets.remove(i)
	if target == targetEntity:
		target = null
	if dead_target_aggro.has(targetEntity):
		dead_target_aggro.erase(targetEntity)

export var aggro_drop_distance: float = 70
export var aggro_decay_per_second: float = 6.0
export var run_aggro_decay: float = 3.0
export var sustained_run_time_before_percent_decay: float = 25.0
export var sustained_run_percent_decay: float = 0.6
var uninterruptedRunTime: float = 0.0

func decayAggroWhileRunning() -> void:
	if movement_mode != "run":
		uninterruptedRunTime = 0.0
		return
	uninterruptedRunTime += 1.0
	for aggroTarget in targets:
		if uninterruptedRunTime >= sustained_run_time_before_percent_decay:
			aggroTarget.aggro -= aggroTarget.aggro * sustained_run_percent_decay
			aggroTarget.aggro -= run_aggro_decay
			aggro_changed = true

var dead_target_aggro: Dictionary = {}

func cleanupDeadAggro() -> void:
	if targets.empty():
		return
	var targetRemoved := false
	for i in range(targets.size() - 1, -1, -1):
		var aggroTarget = targets[i]
		if !is_instance_valid(aggroTarget.target_entity):
			continue
		if isTargetDownedOrDead(aggroTarget.target_entity):
			dead_target_aggro[aggroTarget.target_entity] = aggroTarget.aggro
			if aggroTarget.target_entity == target:
				targetRemoved = true
			targets.remove(i)
			animation_tree.active = true
			setAnimParam("parameters/Interraction/blend_amount", 0)

	var highest = findHighestAggro()
	target = highest.target_entity if highest and highest.aggro > 0 else null
	if targetRemoved:
		interruptAttack()

func getAggro(targetEntity: Node) -> AggroTarget:
	if targetEntity == null or targetEntity == self:
		return null
	for existingTarget in targets:
		if existingTarget.target_entity == targetEntity:
			return existingTarget
	var aggroTarget := AggroTarget.new()
	aggroTarget.target_entity = targetEntity
	aggroTarget.last_aggro_time = OS.get_system_time_secs()
	targets.append(aggroTarget)
	aggro_changed = true
	return aggroTarget

func findHighestAggro() -> AggroTarget:
	var best: AggroTarget = null
	var highest: float = -INF
	for t in targets:
		if t.target_entity == self:
			continue
		if t.aggro > highest:
			highest = t.aggro
			best = t
	return best

func team_aggro() -> Array:
	var sortedTargets: Array = targets.duplicate()
	sortedTargets.sort_custom(self, "sortAggroDesc")
	return sortedTargets.slice(0, min(5, sortedTargets.size()))

func sortAggroDesc(a, b) -> bool:
	return a.aggro > b.aggro

func cleanupAggrotargets() -> void:
	if targets.empty():
		return
	var remainingTargets: Array = []
	for aggroTarget in targets:
		if !is_instance_valid(aggroTarget.target_entity):
			continue
		var distance: float = global_transform.origin.distance_to(aggroTarget.target_entity.global_transform.origin)
		var inRealCombat: bool = hasRealCombatWith(aggroTarget.target_entity)
		var dropDistance: float = aggro_drop_distance if inRealCombat else passive_aggro_drop_distance
		var decayRate: float = aggro_decay_per_second if inRealCombat else passive_aggro_decay_per_second
		if distance > dropDistance:
			aggroTarget.aggro -= decayRate * get_physics_process_delta_time()
		if aggroTarget.aggro > 0:
			remainingTargets.append(aggroTarget)
	targets = remainingTargets


# =============================================================================
# SECTION 20 — DEBUG / DISPLAY
# =============================================================================
func displayAnimLocks(label) -> void:
	var text: String = "AnimationTree: " + str(animation_tree.active) + "\n\n"
	for i in range(anim_locks.size()):
		if anim_locks[i]:
			text += Lock.keys()[i] + "\n"
	label.text = text

func displayAggro(label) -> void:
	var text: String = ""
	if get_tree().network_peer != null and not is_network_master():
		for entry in net_aggro_list:
			var dt = OS.get_datetime_from_unix_time(int(entry.get("time", 0)))
			text += (str(entry.get("name", "?")) + " : " + str(entry.get("entity_name", "?")) + " : " + str(round(entry.get("aggro", 0))) + " | " + str(dt.hour).pad_zeros(2) + ":" + str(dt.minute).pad_zeros(2) + ":" + str(dt.second).pad_zeros(2) + " " + str(dt.day).pad_zeros(2) + "/" + str(dt.month).pad_zeros(2) + "/" + str(dt.year) + "\n")
		label.text = text
		return

	for aggroTarget in team_aggro():
		if !is_instance_valid(aggroTarget.target_entity):
			continue
		var dt = OS.get_datetime_from_unix_time(aggroTarget.last_aggro_time)
		text += (aggroTarget.target_entity.name + " : " + aggroTarget.target_entity.entity_name + " : " + str(round(aggroTarget.aggro)) + " | " + str(dt.hour).pad_zeros(2) + ":" + str(dt.minute).pad_zeros(2) + ":" + str(dt.second).pad_zeros(2) + " " + str(dt.day).pad_zeros(2) + "/" + str(dt.month).pad_zeros(2) + "/" + str(dt.year) + "\n")
	label.text = text

var was_stuck_there: Dictionary = {"position": Vector3(), "time": 0}
var fall_time: float = 0.0

func unstuck() -> void:
	if is_dead:
		return
	if !is_on_floor() and !ray_down.is_colliding():
		fall_time += 1
		if fall_time >= 12.0:
			was_stuck_there.position = global_transform.origin
			was_stuck_there.time = OS.get_unix_time()
			if spawn_point and is_instance_valid(spawn_point):
				var spawnPos: Vector3 = spawn_point.global_transform.origin
				global_transform.origin = Vector3(spawnPos.x + rand_range(-5, 5), spawnPos.y + 0.5, spawnPos.z + rand_range(-5, 5))
			fall_time = 0.0
	else:
		fall_time = 0.0

var forcedRefreshRepetitions: int = 0
var lastForcedRefreshSkill: String = ""
var lastForcedRefreshAnim: String = ""
var forcedRefreshStuckCounter: int = 0

func forceRefreshCombatAnimation() -> void:
	if stats.health <= 0:
		return
	if current_skill == "" or !Global.skills.has(current_skill):
		return
	var species: String = stats.species
	if !Global.skills_by_species.has(species):
		return
	var skillIndex: int = Global.skills_by_species[species].find(current_skill)
	if skillIndex < 0:
		return
	var animName: String = "atk" + str(skillIndex + 1)
	if !animation.has_animation(animName):
		animName = "atk1"
	var skillPath: String = Global.skills[current_skill].resource_path
	var hasCooldown: bool = Global.getCooldown(skillPath) > 0.0
	var onCooldown: bool = skill_cooldowns.has(skillPath)
	if current_skill != lastForcedRefreshSkill or animName != lastForcedRefreshAnim:
		lastForcedRefreshSkill = current_skill
		lastForcedRefreshAnim = animName
		forcedRefreshRepetitions = 0
		forcedRefreshStuckCounter = 0
		return
	forcedRefreshStuckCounter += 1
	if hasCooldown:
		if onCooldown:
			forcedRefreshRepetitions = 999
		else:
			forcedRefreshRepetitions += 1
	else:
		forcedRefreshRepetitions += 1
	var maxRepetitions: int = 0 if hasCooldown else 3
	if forcedRefreshRepetitions <= maxRepetitions and forcedRefreshStuckCounter < 30:
		return
	forcedRefreshRepetitions = 0
	forcedRefreshStuckCounter = 0
	has_anim_lock = false
	attack_waiting = false
	for i in range(Lock.ATK1, Lock.ATK7 + 1):
		anim_locks[i] = false
	animation.stop(true)
	var available: Array = getAvailableSkills()
	var nextSkill: String = pickNextSkill(available)
	if nextSkill == "":
		current_skill = ""
		return
	current_skill = nextSkill
	skillIndex = Global.skills_by_species[species].find(nextSkill)
	if skillIndex < 0:
		return
	animName = "atk" + str(skillIndex + 1)
	if !animation.has_animation(animName):
		animName = "atk1"
	skill_anim.animation = animName
	reactivateTree()


# =============================================================================
# SECTION 21 — COMBAT DISTANCE THROTTLING HELPERS
# =============================================================================
export var combat_distance_refresh_interval: int = 15
var warnedNoOfflinePlayer := false

func updateCachedNearestPlayerDistFast() -> void:
	var nearest: float = INF
	for player in getActivePlayers():
		if !is_instance_valid(player):
			continue
		var d: float = global_transform.origin.distance_to(player.global_transform.origin)
		if d < nearest:
			nearest = d
	cachedNearestPlayerDist = nearest


# =============================================================================
# SECTION 22 — IFRAME / COLLISION TOGGLE FOR BURROW-STYLE SKILLS
# =============================================================================
var collisionsAreEnabled := true

func cleanIframes() -> void:
	var shouldBeEnabled: bool = (current_skill != "burrow")
	if shouldBeEnabled != collisionsAreEnabled:
		collisionsAreEnabled = shouldBeEnabled
		if shouldBeEnabled:
			anim_calls.enableCollisions()
		else:
			anim_calls.disableCollisions()
