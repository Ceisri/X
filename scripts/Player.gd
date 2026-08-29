extends KinematicBody #Player.gd  #NEW


const save_data_password := "kQ7$mZp2!____vLx9rT&eB4_____^wN8c___are_you_really_trying_to_crack_this_lock?J6#hY3@fD1*sG5%uA0~o_____R"


onready var tween:Tween = $Tween
onready var player_mesh = $character
onready var animation =  $character/AnimationPlayer
onready var anim_calls = $AnimationCalls
onready var character = $character
onready var equipment =$UI/Equipment
onready var skeleton = $character/root/Skeleton
onready var character_bars = $UI/Menu/CharacterBar
onready var crossair_inspect =$UI/CrossairInspect
onready var ui_holder:Control = $UI
onready var stats =$Stats
onready var camroot = $Camroot
onready var camera_v = $Camroot/h/v
onready var camera_h = $Camroot/h
onready var camera = $Camroot/h/v/Camera
onready var skillbar = $UI/Skillbar
onready var loot = $UI/Loot
onready var inventory = $UI/Inventory
onready var turnable:Spatial = $Turnable
export var sync_rate := 0.08
var sync_timer := 0.0
export var puppet_lerp_speed := 18.0
var _entity_initialized := false
var pvp_enabled:bool = false
var respawn_id:int = 0
var entity_name = Global.selected_player_name
export var sex:String = "female"
puppet var net_sex := "male"


puppet var net_camrot_h := 0.0
puppet var net_camrot_v := 0.0
var _last_applied_puppet_sex := ""
var creator
var spawned_bodies
export var gravity = 9.8 
# Physics values
var direction = Vector3()
var horizontal_velocity = Vector3()
var aim_turn = float()
var movement = Vector3()
var vertical_velocity = Vector3()
var movement_speed = int()
var angular_acceleration:int = 7.5
var acceleration:int = 10
var can_move= true
var is_carrying = false
var cursor_visible = false
var is_swimming:bool = false
var is_downed:bool = false
var is_dead:bool = false
var revive_lock_until_ms:int = 0
var wall_incline
var is_on_stairs: bool = false
var wall_hanging:bool = false
var _player_frame_offset:int = -1
onready var head_ray = $Turnable/Vault
onready var climb_ray = $Turnable/MidRay
onready var root_bone = skeleton.find_bone("ik_foot_root")
var root_motion_active:bool= false
var last_root_pos := Vector3.ZERO
var root_motion_velocity := Vector3.ZERO
var _last_root_motion_pos := Vector3.ZERO
var is_climbing:bool= false
var _crafting_was_visible := false
onready var animation_tree:AnimationTree = $AnimationTree
onready var _unique_animation_tree_root = _makeAnimationTreeRootUnique()
onready var skill_anim = animation_tree.tree_root.get_node("Skill")
var self_downed_autorespawn_time:float = 50.0
var _downed_started_ms:int = 0
# Guards every save path (World.gd.savePlayerData, saveRecursive's
# saveData() call, everything) from writing this player's data to disk
# until a full, successful load/restore has actually completed. Without
# this, ANY transient bad spawn gets IMMORTALIZED the moment the next
# periodic autosave fires and overwrites the real saved data with
# whatever blank/zeroed state is currently sitting in this node.
var data_fully_loaded := false
# Only the server may flip this -- it's the single, authoritative signal
# that every equipment/inventory/skillbar/stats/state snapshot has
# actually landed on this client's own copy of its own player.
remote func setDataFullyLoaded() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	data_fully_loaded = true
	_revealAfterLoad()


# ===== Player.gd — new function, add anywhere at top level =====
export var full_load_watchdog_timeout := 8.0
var _watchdog_attempts := 0

func _watchdogForFullLoad() -> void:
	if !isLocalPlayer():
		return
	yield(get_tree().create_timer(full_load_watchdog_timeout), "timeout")
	if !is_instance_valid(self) or !isLocalPlayer():
		return
	if data_fully_loaded:
		return

	_watchdog_attempts += 1

	if get_tree().network_peer != null:
		# Pull-based redundancy: actively ask the server to resend our
		# own full snapshot instead of just hoping the original push
		# arrives. Self-heals a dropped/lost initial RPC without the
		# player needing to relog.
		Global.rpc_id(1, "requestOwnFullSnapshot")

	if _watchdog_attempts >= 3:
		# Gave up after ~24s of retries. Reveal anyway -- being invisible
		# forever is strictly worse than showing up with stale/default
		# state -- but do NOT touch data_fully_loaded, so every save path
		# (Player.gd.saveData, World.gd.savePlayerData,
		# _savePositionsOnlyForAllPlayers) stays blocked and can never
		# stomp the real saved data on disk with this broken session.
		visible = true
		set_physics_process(true)
		if is_instance_valid(fullbody_collision): fullbody_collision.disabled = false
		if is_instance_valid(upper_body_collision): upper_body_collision.disabled = false
		if is_instance_valid(lower_body_collision): lower_body_collision.disabled = false
		push_error("Player.gd: gave up waiting for full snapshot for " + entity_name + " -- revealed anyway, saves remain blocked")
		return

	call_deferred("_watchdogForFullLoad")


func _makeAnimationTreeRootUnique():
	if !_needsUniqueAnimationTree():
		return false
	if is_instance_valid(animation_tree) and animation_tree.tree_root != null:
		animation_tree.tree_root = animation_tree.tree_root.duplicate(true)
	return true

func _needsUniqueAnimationTree() -> bool:
	# duplicate(true) on the whole state-graph is expensive and was running
	# for EVERY player, including the dedicated server's own invisible
	# bookkeeping copies of every OTHER connected player -- a real per-spawn
	# stall once several players were online.
	if get_tree() == null:
		return true
	if get_tree().network_peer == null:
		return true
	if !get_tree().is_network_server():
		return true
	return isLocalPlayer()


enum WeaponMode {
	NONE,
	SWORD,
	DUAL,
	SHIELD,
	TWO_HANDED
}
var which_portal = ""
var which_scene = ""



#ONLINE ADDITION 
var connection_status_active := false
puppet var net_position := Vector3() setget _set_net_position
func _set_net_position(value):
	var now = OS.get_ticks_msec()
	if _net_position_recv_time != 0:
		var dt = (now - _net_position_recv_time) / 1000.0
		if dt > 0.01:
			_net_velocity_estimate = (value - _net_position_prev) / dt
	_net_position_prev = value
	_net_position_recv_time = now
	net_position = value
var _net_position_prev := Vector3()
var _net_position_recv_time := 0
var _net_velocity_estimate := Vector3()
export var lag_compensation_max_extrapolation := 0.25
export var lag_compensation_enabled := true
puppet var net_rotation_y := 0.0
puppet var net_character_rotation_y := 0.0
puppet var net_turnable_rotation_y := 0.0
puppet var net_movement_mode := "idle"
puppet var net_current_skill := "none"
puppet var net_weapons := 0
puppet var net_is_in_combat := false
puppet var net_moving := false
puppet var net_direction := Vector3()
puppet var net_active_lock := ""   # <-- NEW: mirrors getActiveAnimLock() from the master


var _is_pooled_idle := false
var _ready_complete := false

func _ready()->void:
	playerReady()
func playerReady()->void:
	_is_pooled_idle = has_meta("is_pooled_idle")
	entity_ready = false

	if !_is_pooled_idle:
		if entity_name == null or entity_name == "":
			entity_name = Global.selected_player_name
		if isLocalPlayer():
			Global.resetPlayerReady()
			
	smelting_system.hide()
	$character/root/Skeleton/Mesh.hide()
	direction=Vector3.BACK.rotated(Vector3.UP,camera_h.global_transform.basis.get_euler().y)
	initializeAnimationBlends()
	if !_is_pooled_idle and isLocalPlayer():
		loadCharacterData()
		ApplySex()
		_forceLocalCameraCurrent(self)
		banner_system_control.visible = false
	if is_instance_valid(character):
		character.hide()
	yield(get_tree(),"idle_frame")
	equipment.updateEquipment()
	yield(get_tree(),"idle_frame")

	if !_is_pooled_idle and isLocalPlayer():
		call_deferred("loadBoneData")
	yield(get_tree(),"idle_frame")
	_updateInputKeys()
	_cacheToolIcons()
	disableFallDamage()
	water_level_area.connect("area_shape_entered", self, "enterDeepWaters")
	water_level_area.connect("area_shape_exited", self, "exitDeepWaters")
	if !_is_pooled_idle:
		ui_holder.visible = isLocalPlayer()
		if isLocalPlayer():
			Network.connect("connection_lost", self, "_onConnectionLost")
			Network.connect("reconnect_attempt", self, "_onReconnectAttempt")
			Network.connect("reconnected", self, "_onReconnected")
			Network.connect("reconnect_failed", self, "_onReconnectFailedUI")
	reactivateAnimationTree()
	warmupAnimationTreeOnce()
	if !_is_pooled_idle and isLocalPlayer():
		
		yield(get_tree(),"idle_frame")
		yield(get_tree(),"idle_frame")
		Global.markPlayerReady()
		for i in range(30):
			yield(get_tree(),"idle_frame")
	if is_instance_valid(character):
		character.show()
	_ready_complete = true
	if !_is_pooled_idle:
		_markEntityReady()

	registerInGlobal()
	_ready_complete = true
	if !_is_pooled_idle:
		_markEntityReady()
	registerInGlobal()
	setupPlayerCollisionLayer()
	
	
	
var cached_entities: Array = []

func cacheEntities() -> void:
	cached_entities.clear()
	var world = get_parent()
	if !is_instance_valid(world):
		return
	if world.has_method("getCachedEntities"):
		for e in world.getCachedEntities():
			if is_instance_valid(e):
				cached_entities.append(e)
		return
	if world.has_method("getAllEntities"):
		for e in world.getAllEntities():
			if is_instance_valid(e):
				cached_entities.append(e)
func registerInGlobal() -> void:
	if !is_instance_valid(Global):
		return
	var world = get_parent()
	var world_id = world.world_id if is_instance_valid(world) and "world_id" in world else ""
	Global.register(self, world_id)

func _exit_tree() -> void:
	if is_instance_valid(Global):
		Global.unregister(self)
		Global.clearAggroPulseState(self)



func reinitializeForEntity(new_entity_name:String) -> void:
	entity_name = new_entity_name
	entity_ready = false
	_is_pooled_idle = false
	if has_meta("is_pooled_idle"):
		remove_meta("is_pooled_idle")

	if isLocalPlayer():
		data_fully_loaded = false
		visible = false
		set_physics_process(false)
		if is_instance_valid(fullbody_collision): fullbody_collision.disabled = true
		if is_instance_valid(upper_body_collision): upper_body_collision.disabled = true
		if is_instance_valid(lower_body_collision): lower_body_collision.disabled = true
		if is_instance_valid(banner_system_control): banner_system_control.visible = false  
		var quest_system_reset = get_node_or_null("UI/QuestSystem")
		if is_instance_valid(quest_system_reset) and quest_system_reset.has_method("hardResetForPool"):
			quest_system_reset.hardResetForPool()
		if is_instance_valid(inventory) and inventory.has_method("hardResetForPool"):
			inventory.hardResetForPool()
		if is_instance_valid(skillbar) and skillbar.has_method("hardResetForPool"):
			skillbar.hardResetForPool()
		
	while !_ready_complete:
		yield(get_tree(), "idle_frame")

	if isLocalPlayer():
		Global.resetPlayerReady()

	if isLocalPlayer():
		loadCharacterData()
		ApplySex()
		_forceLocalCameraCurrent(self)
		if is_instance_valid(skillbar) and skillbar.has_method("reinitializeAsLocalPlayer"):
			skillbar.reinitializeAsLocalPlayer()
	if is_instance_valid(character):
		character.hide()

	yield(get_tree(),"idle_frame")
	equipment.updateEquipment()

	if isLocalPlayer():
		call_deferred("loadBoneData")

	if is_instance_valid(inventory) and inventory.has_method("reinitializeUI"):
		inventory.reinitializeUI()

	ui_holder.visible = isLocalPlayer()
	if isLocalPlayer():
		if !Network.is_connected("connection_lost", self, "_onConnectionLost"):
			Network.connect("connection_lost", self, "_onConnectionLost")
		if !Network.is_connected("reconnect_attempt", self, "_onReconnectAttempt"):
			Network.connect("reconnect_attempt", self, "_onReconnectAttempt")
		if !Network.is_connected("reconnected", self, "_onReconnected"):
			Network.connect("reconnected", self, "_onReconnected")
		if !Network.is_connected("reconnect_failed", self, "_onReconnectFailedUI"):
			Network.connect("reconnect_failed", self, "_onReconnectFailedUI")

	reactivateAnimationTree()

	if isLocalPlayer():
		yield(get_tree(),"idle_frame")
		yield(get_tree(),"idle_frame")
		Global.markPlayerReady()
		call_deferred("_watchdogForFullLoad")

	if is_instance_valid(character):
		character.show()

	_markEntityReady()


var _last_corpse_state := false
func updateOwnCorpseState() -> void:
	var should_be_corpse = stats.health <= 0
	if should_be_corpse != _last_corpse_state:
		_last_corpse_state = should_be_corpse
const PLAYER_COLLISION_LAYER_BIT: int = 1 << 21
const CORPSE_COLLISION_LAYER_BIT: int = 1 << 20
const MOB_COLLISION_LAYER_BIT: int = 1 << 19

func setupPlayerCollisionLayer() -> void:
	collision_mask = collision_mask & ~collision_layer
	collision_layer = collision_layer | PLAYER_COLLISION_LAYER_BIT
	collision_mask = collision_mask & ~PLAYER_COLLISION_LAYER_BIT
	collision_mask = collision_mask & ~CORPSE_COLLISION_LAYER_BIT
	collision_mask = collision_mask | MOB_COLLISION_LAYER_BIT
# Called directly by _ready() for a freshly-instanced (non-pooled) player,
# and explicitly by Global._doSpawnPlayer() for a pooled node that
# just had its entity_name assigned -- since _ready() itself already ran
# (with entity_name=="") back when the node was pooled and never fires again.
func _initializeAsEntity() -> void:
	if _entity_initialized:
		return
	_entity_initialized = true

	ui_holder.visible = isLocalPlayer()
	if isLocalPlayer():
		_forceLocalCameraCurrent(self)
	else:
		_forceCamerasNotCurrent(self)

	if isLocalPlayer():
		visible = false
		set_physics_process(false)
		if is_instance_valid(fullbody_collision): fullbody_collision.disabled = true
		if is_instance_valid(upper_body_collision): upper_body_collision.disabled = true
		if is_instance_valid(lower_body_collision): lower_body_collision.disabled = true
		data_fully_loaded = false
		Global.resetPlayerReady()

	smelting_system.hide()
	$character/root/Skeleton/Mesh.hide()
	direction=Vector3.BACK.rotated(Vector3.UP,$Camroot/h.global_transform.basis.get_euler().y)
	initializeAnimationBlends()
	if isLocalPlayer():
		loadCharacterData()
		ApplySex()
	else:
		_forceCamerasNotCurrent(self)

	if is_instance_valid(character):
		character.hide()

	yield(get_tree(),"idle_frame")
	equipment.updateEquipment()
	yield(get_tree(),"idle_frame")
	if isLocalPlayer():
		call_deferred("loadBoneData")
	yield(get_tree(),"idle_frame")
	_updateInputKeys()
	_cacheToolIcons()
	disableFallDamage()
	water_level_area.connect("area_shape_entered", self, "enterDeepWaters")
	water_level_area.connect("area_shape_exited", self, "exitDeepWaters")
	if isLocalPlayer():
		if !Network.is_connected("connection_lost", self, "_onConnectionLost"):
			Network.connect("connection_lost", self, "_onConnectionLost")
		if !Network.is_connected("reconnect_attempt", self, "_onReconnectAttempt"):
			Network.connect("reconnect_attempt", self, "_onReconnectAttempt")
		if !Network.is_connected("reconnected", self, "_onReconnected"):
			Network.connect("reconnected", self, "_onReconnected")
		if !Network.is_connected("reconnect_failed", self, "_onReconnectFailedUI"):
			Network.connect("reconnect_failed", self, "_onReconnectFailedUI")
	reactivateAnimationTree()

	if isLocalPlayer():
		yield(get_tree(),"idle_frame")
		yield(get_tree(),"idle_frame")
		Global.markPlayerReady()

	if is_instance_valid(character):
		character.show()

func _revealAfterLoad() -> void:
	if !isLocalPlayer():
		return
	visible = true
	if is_suspended:
		return
	set_physics_process(true)
	if is_instance_valid(fullbody_collision): fullbody_collision.disabled = false
	if is_instance_valid(upper_body_collision): upper_body_collision.disabled = false
	if is_instance_valid(lower_body_collision): lower_body_collision.disabled = false
var is_suspended := false

#func setSuspended(suspended:bool) -> void:
#	is_suspended = suspended
#	if suspended:
#		data_fully_loaded = false
#	visible = !suspended
#	if is_instance_valid(fullbody_collision): fullbody_collision.disabled = suspended
#	if is_instance_valid(upper_body_collision): upper_body_collision.disabled = suspended
#	if is_instance_valid(lower_body_collision): lower_body_collision.disabled = suspended
#	set_physics_process(!suspended)
#	ui_holder.visible = !suspended and isLocalPlayer()

# ===== Player.gd — replace setSuspended() =====
func setSuspended(suspended:bool) -> void:
	is_suspended = suspended

	if suspended:
		data_fully_loaded = false
		visible = false
		if is_instance_valid(fullbody_collision): fullbody_collision.disabled = true
		if is_instance_valid(upper_body_collision): upper_body_collision.disabled = true
		if is_instance_valid(lower_body_collision): lower_body_collision.disabled = true
		set_physics_process(false)
		ui_holder.visible = false
		return

	# UNSUSPENDING: this used to reveal + enable physics IMMEDIATELY here,
	# before any real snapshot (equipment/inventory/skillbar/stats/position)
	# had actually landed on this node. That's the root cause of every
	# symptom reported: physics started ticking (gravity, movement,
	# save-blocking checks) on a blank/pooled node sitting at whatever
	# transform the pool left it at, ran for however many frames it took
	# the snapshot RPC to arrive, and by the time the real data DID land,
	# the player had already fallen/moved away from -- or the saved
	# position write raced against -- the correct spot. Equipment "worked"
	# only because it's also applied authoritatively/synchronously
	# server-side in the same call that spawns the node; nothing else was.
	#
	# Now: for the LOCAL player, staying frozen+invisible is the ONLY
	# state entered here. The ONE place allowed to actually reveal a local
	# player is _revealAfterLoad(), and that only ever runs once real data
	# has been applied (data_fully_loaded == true). Puppets (other
	# players) still reveal immediately as before -- there's no "our own
	# data" race for a puppet, its state streams in continuously anyway.
	if isLocalPlayer():
		data_fully_loaded = false
		visible = false
		if is_instance_valid(fullbody_collision): fullbody_collision.disabled = true
		if is_instance_valid(upper_body_collision): upper_body_collision.disabled = true
		if is_instance_valid(lower_body_collision): lower_body_collision.disabled = true
		set_physics_process(false)
		ui_holder.visible = false
	else:
		visible = true
		if is_instance_valid(fullbody_collision): fullbody_collision.disabled = false
		if is_instance_valid(upper_body_collision): upper_body_collision.disabled = false
		if is_instance_valid(lower_body_collision): lower_body_collision.disabled = false
		set_physics_process(true)
		ui_holder.visible = false


















func applyStateSnapshotAuthority(data:Dictionary) -> void:
	if data.empty():
		return
	_applyStateSnapshotDirect(data)



# Was firing every sync_rate (0.08s) unconditionally per player,
# regardless of whether anything actually changed -- at 100 players
# that's a constant RSET floor even for someone standing still doing
# nothing. Now gated the same way Equipment._syncEquipmentToPuppets()
# already gates its own broadcast: build a signature of everything
# that matters, skip the send if it matches the last one sent.
#
# Continuous fields (position/rotation) use an epsilon tolerance
# instead of exact float equality, since physics jitter means they
# almost never match bit-for-bit even while genuinely stationary.
#
# A heartbeat still forces a full resend periodically regardless of
# the signature, so a peer who connects (or momentarily drops a
# packet) while this player is idle never gets stuck seeing them at
# a stale/default position -- same safety margin
# _broadcastAllPlayersToEveryone()'s force_full and MobSync's
# full_sync_interval already rely on elsewhere in this codebase.
export var puppet_sync_heartbeat_interval := 2.0
var _puppet_sync_heartbeat_timer := 0.0

var _last_synced_pos := Vector3.INF
var _last_synced_rot_y := 0.0
var _last_synced_char_rot_y := 0.0
var _last_synced_turn_rot_y := 0.0
var _last_synced_movement_mode := ""
var _last_synced_skill := ""
var _last_synced_weapons := -1
var _last_synced_in_combat := false
var _last_synced_moving := false
var _last_synced_direction := Vector3.INF
var _last_synced_active_lock := ""
var _last_synced_sex := ""
var _last_synced_camrot_h := 0.0
var _last_synced_camrot_v := 0.0
var _puppet_sync_initialized := false

const PUPPET_POS_EPSILON := 0.01
const PUPPET_ROT_EPSILON := 0.01

func _syncToPuppets(delta) -> void:
	if get_tree().network_peer == null:
		return
	if !isLocalPlayer():
		return
	if get_tree().get_network_connected_peers().empty():
		return
	sync_timer += delta
	if sync_timer < sync_rate:
		return
	sync_timer = 0.0

	var char_rot_y = player_mesh.rotation.y if is_instance_valid(player_mesh) else 0.0
	var turn_rot_y = turnable.rotation.y if is_instance_valid(turnable) else 0.0
	var active_lock = getActiveAnimLock()
	var cam_h = camroot.camrot_h if is_instance_valid(camroot) else 0.0
	var cam_v = camroot.camrot_v if is_instance_valid(camroot) else 0.0

	_puppet_sync_heartbeat_timer += sync_rate
	var force_heartbeat = _puppet_sync_heartbeat_timer >= puppet_sync_heartbeat_interval
	if force_heartbeat:
		_puppet_sync_heartbeat_timer = 0.0

	var changed = force_heartbeat or !_puppet_sync_initialized \
		|| translation.distance_squared_to(_last_synced_pos) > PUPPET_POS_EPSILON * PUPPET_POS_EPSILON \
		|| abs(wrapf(rotation.y - _last_synced_rot_y, -PI, PI)) > PUPPET_ROT_EPSILON \
		|| abs(wrapf(char_rot_y - _last_synced_char_rot_y, -PI, PI)) > PUPPET_ROT_EPSILON \
		|| abs(wrapf(turn_rot_y - _last_synced_turn_rot_y, -PI, PI)) > PUPPET_ROT_EPSILON \
		|| movement_mode != _last_synced_movement_mode \
		|| current_skill != _last_synced_skill \
		|| weapons != _last_synced_weapons \
		|| is_in_combat != _last_synced_in_combat \
		|| moving != _last_synced_moving \
		|| direction.distance_squared_to(_last_synced_direction) > PUPPET_POS_EPSILON * PUPPET_POS_EPSILON \
		|| active_lock != _last_synced_active_lock \
		|| stats.sex != _last_synced_sex \
		|| abs(cam_h - _last_synced_camrot_h) > PUPPET_ROT_EPSILON \
		|| abs(cam_v - _last_synced_camrot_v) > PUPPET_ROT_EPSILON

	if !changed:
		return

	_puppet_sync_initialized = true
	_last_synced_pos = translation
	_last_synced_rot_y = rotation.y
	_last_synced_char_rot_y = char_rot_y
	_last_synced_turn_rot_y = turn_rot_y
	_last_synced_movement_mode = movement_mode
	_last_synced_skill = current_skill
	_last_synced_weapons = weapons
	_last_synced_in_combat = is_in_combat
	_last_synced_moving = moving
	_last_synced_direction = direction
	_last_synced_active_lock = active_lock
	_last_synced_sex = stats.sex
	_last_synced_camrot_h = cam_h
	_last_synced_camrot_v = cam_v

	rset_unreliable("net_position", translation)
	rset_unreliable("net_rotation_y", rotation.y)
	if is_instance_valid(player_mesh):
		rset_unreliable("net_character_rotation_y", char_rot_y)
	if is_instance_valid(turnable):
		rset_unreliable("net_turnable_rotation_y", turn_rot_y)
	rset_unreliable("net_movement_mode", movement_mode)
	rset_unreliable("net_current_skill", current_skill)
	rset_unreliable("net_weapons", weapons)
	rset_unreliable("net_is_in_combat", is_in_combat)
	rset_unreliable("net_moving", moving)
	rset_unreliable("net_direction", direction)
	rset_unreliable("net_active_lock", active_lock)
	rset_unreliable("net_sex", stats.sex)
	if is_instance_valid(camroot):
		rset_unreliable("net_camrot_h", cam_h)
		rset_unreliable("net_camrot_v", cam_v)
#Notes on why it's safe:
#First tick always sends (!_puppet_sync_initialized), so a freshly spawned player is never silently absent from puppets.
#Heartbeat every 2s forces a full resend regardless of the diff, so any peer that connects mid-idle, or drops a packet on the unreliable channel, self-corrects within 2 seconds worst case — same safety margin the rest of the codebase already relies on elsewhere.
#Epsilon, not exact equality, so this doesn't send garbage-diff spam or, worse, never trigger due to float noise while actually idle.
#Every field that was previously always sent is still sent together as one unit when any of them changes — no partial/inconsistent puppet state.
#Nothing about the puppet-receiving side (_applyPuppetState) changes, so this is purely a sender-side optimization with zero behavior change for what puppets end up displaying, just less traffic while idle.



# plus the applyPuppetDownedState() entry point Stats.gd now calls.
# Fixes "standing instead of downed": is_downed was a purely local flag
# only ever set on the SERVER's authoritative copy of a player node
# (inside Stats.getKilled()) -- it never had any sync path to puppets on
# other clients at all, so their render always showed the player idle.
# ============================================================
puppet var net_is_downed := false

#func applyPuppetDownedState(downed:bool) -> void:
#	if isLocalPlayer():
#		return
#	if net_is_downed == downed:
#		return
#	net_is_downed = downed
#	if downed:
#		anim_locks["downed"] = true
#		current_skill = "downed"
#	else:
#		anim_locks["downed"] = false
#		anim_locks["get up"] = true
# ============================================================
# Player.gd — receivePuppetStatsPush's applyPuppetDownedState() no longer
# needs to touch anim_locks/current_skill (that was the inert no-op fix
# from before — getActiveAnimLock() ignores anim_locks for puppets and
# reads net_active_lock only, which now arrives correctly from the real
# owner via the Stats.gd fix above). Keep this only to update the plain
# is_downed flag for any non-animation logic that reads it directly.
# ============================================================

func applyPuppetDownedState(downed:bool) -> void:
	if isLocalPlayer():
		return
	net_is_downed = downed
func _applyPuppetState(delta) -> void:
	if shouldAnimateLocally():
		animation_tree.active = true
	if net_sex != _last_applied_puppet_sex:
		_last_applied_puppet_sex = net_sex
		stats.sex = net_sex
		if shouldAnimateLocally():
			ApplySex()
#	translation = translation.linear_interpolate(net_position, delta * puppet_lerp_speed)
	var extrapolated_position = net_position
	if lag_compensation_enabled and _net_position_recv_time != 0:
		var elapsed = (OS.get_ticks_msec() - _net_position_recv_time) / 1000.0
		elapsed = min(elapsed, lag_compensation_max_extrapolation)
		extrapolated_position = net_position + _net_velocity_estimate * elapsed
	translation = translation.linear_interpolate(extrapolated_position, delta * puppet_lerp_speed)
	
	rotation.y = lerp_angle(rotation.y, net_rotation_y, delta * puppet_lerp_speed)

	if is_instance_valid(player_mesh):
		player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, net_character_rotation_y, delta * puppet_lerp_speed)
	if is_instance_valid(turnable):
		turnable.rotation.y = lerp_angle(turnable.rotation.y, net_turnable_rotation_y, delta * puppet_lerp_speed)

	# Feed the synced camera rotation into this puppet's own Camroot so
	# its Camera node's global_transform (and get_frustum()) actually
	# matches this player's real view -- Camroot.gd applies these fields
	# to the h/v Spatial nodes itself for non-local instances.
	if is_instance_valid(camroot):
		camroot.camrot_h = net_camrot_h
		camroot.camrot_v = net_camrot_v

	movement_mode = net_movement_mode
	current_skill = net_current_skill
	weapons = net_weapons
	is_in_combat = net_is_in_combat
	moving = net_moving
	direction = net_direction
	is_downed = net_is_downed # <-- was never assigned for puppets before
	if is_instance_valid(equipment) and equipment.has_method("_applyPuppetEquipmentIfChanged"):
		equipment._applyPuppetEquipmentIfChanged()
	
	
	
func _onConnectionLost() -> void:
	connection_status_active = true
	chat.sendSystemMessage("Losing connection to server...")
	var label:Label = $UI/ResourceDetectionLabel
	label.visible = true
	label.text = "Losing connection..."
	_forceLocalCameraCurrent(self)

func _onReconnectAttempt(attempt:int) -> void:
	connection_status_active = true
	var label:Label = $UI/ResourceDetectionLabel
	label.visible = true
	label.text = "Reconnecting... (attempt " + str(attempt) + ")"
	_forceLocalCameraCurrent(self)

func _onReconnected() -> void:
	connection_status_active = false
	chat.sendSystemMessage("Reconnected to server")
	var label:Label = $UI/ResourceDetectionLabel
	label.visible = false
	label.text = ""

func _onReconnectFailedUI() -> void:
	chat.sendSystemMessage("Could not reconnect to server")
	var label:Label = $UI/ResourceDetectionLabel
	label.visible = true
	label.text = "Connection lost"
	_giveUpAndReturnToMenu()

func _giveUpAndReturnToMenu() -> void:
	set_physics_process(false)
	visible = false
	if is_instance_valid(fullbody_collision): fullbody_collision.disabled = true
	if is_instance_valid(upper_body_collision): upper_body_collision.disabled = true
	if is_instance_valid(lower_body_collision): lower_body_collision.disabled = true
	ui_holder.visible = false
	if get_tree().network_peer != null:
		get_tree().network_peer = null
	get_tree().change_scene("res://PreCharacterCreation.tscn")
		








func isLocalPlayer() -> bool:
	return entity_name != "" and entity_name == Global.selected_player_name

var weapons:int = WeaponMode.NONE

var current_skill:String = "none"
var anim_locks = { 
	"combo attack":false,

	"guard":false,
	"downed":false,
	"get up":false,
	"die":false,
	"downed die":false,
	"flinch":false,
	"flinch  back":false,
	"knocked back":false,
	"knocked down":false,
	"guard react":false,

#BERSERK SKILLS
	"raze":false,
	"reckless vengeance":false,
	"shoulder bash":false,
	"stone splitter":false,
	"brutal chop":false,
	"fury strike":false,
	"sadistic blow":false,
	"sunder" :false,
	"heart thrust":false,
	"obliteration":false,
	"obliteration charge":false,
	"obliteration start":false,
	"sledge":false,
	

	"death from above":false,
	"flury of blows":false,
	"section":false,
	"perforation trifecta":false,
	"dodge":false,
	"cleave":false,
	"battlecry":false,
	"dash":false,
	"stop_run":false,
	"parry":false,
	"sit":false,
	"stop_sit":false,
	"scream":false,
	"prepare":false,
	"stunned":false,
	"staggered":false}




var interrupt_groups = {
	"hard_interrupt":["dodge","block","parry","guard react"],
	"skills":["section","perforation trifecta","cleave","battlecry","scream","stone splitter"],
	"base_attack":["combo attack"]
}


var skill_animations:Dictionary = {
	
	# ============================================================
	# MAGIC / WARLOCK SKILLS
	# ============================================================
	"shadow bolt":{
		WeaponMode.NONE:"Flinch_OneHanded",
		WeaponMode.SWORD:"Flinch_OneHanded",
		WeaponMode.DUAL:"Flinch_OneHanded",
		WeaponMode.SHIELD:"Flinch_OneHanded",
		WeaponMode.TWO_HANDED:"Flinch_OneHanded",
	},

	"void grasp":{
		WeaponMode.NONE:"Flinch_OneHanded",
		WeaponMode.SWORD:"Flinch_OneHanded",
		WeaponMode.DUAL:"Flinch_OneHanded",
		WeaponMode.SHIELD:"Flinch_OneHanded",
		WeaponMode.TWO_HANDED:"Flinch_OneHanded",
	},

	"cursed flames":{
		WeaponMode.NONE:"Flinch_OneHanded",
		WeaponMode.SWORD:"Flinch_OneHanded",
		WeaponMode.DUAL:"Flinch_OneHanded",
		WeaponMode.SHIELD:"Flinch_OneHanded",
		WeaponMode.TWO_HANDED:"Flinch_OneHanded",
	},
	"subversion":{
		WeaponMode.NONE:"Flinch_OneHanded",
		WeaponMode.SWORD:"Flinch_OneHanded",
		WeaponMode.DUAL:"Flinch_OneHanded",
		WeaponMode.SHIELD:"Flinch_OneHanded",
		WeaponMode.TWO_HANDED:"Flinch_OneHanded",
	},
	
	
	
	
	
	
	
	
	"mine":{
		WeaponMode.NONE:"mine_cycle",
		WeaponMode.SWORD:"mine_cycle",
		WeaponMode.DUAL:"mine_cycle",
		WeaponMode.SHIELD:"mine_cycle",
		WeaponMode.TWO_HANDED:"mine_cycle",
	},
	"chop":{
		WeaponMode.NONE:"chop_cycle",
		WeaponMode.SWORD:"chop_cycle",
		WeaponMode.DUAL:"chop_cycle",
		WeaponMode.SHIELD:"chop_cycle",
		WeaponMode.TWO_HANDED:"chop_cycle",
	},
	"gather":{
		WeaponMode.NONE:"gather",
		WeaponMode.SWORD:"gather",
		WeaponMode.DUAL:"gather",
		WeaponMode.SHIELD:"gather",
		WeaponMode.TWO_HANDED:"gather",
	},
	
	
	"combo attack":{
		WeaponMode.NONE:"ComboATK_Empty_cycle",
		WeaponMode.SWORD:"ComboATK_OneHanded_cycle",
		WeaponMode.DUAL:"ComboATK_Dual",
		WeaponMode.SHIELD:"ComboATK_OneHanded_cycle",
		WeaponMode.TWO_HANDED:"ComboATK_TwoHanded_cycle",
	},
	"penetrating blow":{
		WeaponMode.SWORD:"Basic_Stab_OneHanded",
		WeaponMode.DUAL:"Basic_Stab_OneHanded",
		WeaponMode.SHIELD:"Basic_Stab_OneHanded",
		WeaponMode.TWO_HANDED:"Basic_Stab_TwoHanded",
		#WeaponMode.BOW:"Basic_PenetratingShot",
	},
	"evasion":{
		WeaponMode.NONE:"Roll_Generic",
		WeaponMode.SWORD:"Roll_Generic",
		WeaponMode.DUAL:"Roll_Generic",
		WeaponMode.SHIELD:"Roll_Generic",
		WeaponMode.TWO_HANDED:"Roll_TwoHanded",
	},
	"backstep":{
		WeaponMode.NONE:"Basic_Generic_Backstep",
		WeaponMode.SWORD:"Basic_Generic_Backstep",
		WeaponMode.DUAL:"Basic_Generic_Backstep",
		WeaponMode.SHIELD:"Basic_Generic_Backstep",
		WeaponMode.TWO_HANDED:"Basic_TwoHanded_Backstep",
	},
	"guard":{
		WeaponMode.NONE:"Guard_Unarmed_cycle",
		WeaponMode.SWORD:"Guard_Sword_cycle",
		WeaponMode.DUAL:"Guard_Dual_cycle",
		WeaponMode.SHIELD:"Guard_Shield_cycle",
		WeaponMode.TWO_HANDED:"Guard_Sword_cycle",
	},
	"guard react":{
		WeaponMode.NONE:"Guard_Unarmed_react",
		WeaponMode.SWORD:"Guard_General_react",
		WeaponMode.DUAL:"Guard_Dual_react",
		WeaponMode.SHIELD:"Guard_Shield_react",
		WeaponMode.TWO_HANDED:"Guard_General_react",
	},
	"downed die":{
		WeaponMode.NONE:"DownedDie",
		WeaponMode.SWORD:"DownedDie",
		WeaponMode.DUAL:"DownedDie",
		WeaponMode.SHIELD:"DownedDie",
		WeaponMode.TWO_HANDED:"DownedDie",
	},
	"die":{
		WeaponMode.NONE:"Die",
		WeaponMode.SWORD:"Die",
		WeaponMode.DUAL:"Die",
		WeaponMode.SHIELD:"Die",
		WeaponMode.TWO_HANDED:"Die",
	},
	"get up":{
		WeaponMode.NONE:"DownedEnd",
		WeaponMode.SWORD:"DownedEnd",
		WeaponMode.DUAL:"DownedEnd",
		WeaponMode.SHIELD:"DownedEnd",
		WeaponMode.TWO_HANDED:"DownedEnd",
	},
	"flinch  back":{
		WeaponMode.NONE:"FlinchBack_OneHanded",
		WeaponMode.SWORD:"FlinchBack_OneHanded",
		WeaponMode.DUAL:"FlinchBack_OneHanded",
		WeaponMode.SHIELD:"FlinchBack_OneHanded",
		WeaponMode.TWO_HANDED:"FlinchBack_TwoHanded",
	},
	"flinch":{
		WeaponMode.NONE:"Flinch_OneHanded",
		WeaponMode.SWORD:"Flinch_OneHanded",
		WeaponMode.DUAL:"Flinch_OneHanded",
		WeaponMode.SHIELD:"Flinch_OneHanded",
		WeaponMode.TWO_HANDED:"Flinch_TwoHanded",
	},
	
	"knocked back":{
		WeaponMode.NONE:"FlinchKnockedBack_OneHanded",
		WeaponMode.SWORD:"FlinchKnockedBack_OneHanded",
		WeaponMode.DUAL:"FlinchKnockedBack_OneHanded",
		WeaponMode.SHIELD:"FlinchKnockedBack_OneHanded",
		WeaponMode.TWO_HANDED:"FlinchKnockedBack_TwoHanded",
	},
	"knocked down":{
		WeaponMode.NONE:"KnockedDown_OneHanded",
		WeaponMode.SWORD:"KnockedDown_OneHanded",
		WeaponMode.DUAL:"KnockedDown_OneHanded",
		WeaponMode.SHIELD:"KnockedDown_OneHanded",
		WeaponMode.TWO_HANDED:"KnockedDown_TwoHanded",
	},


#WARDEN SKLLLS
"veiled thrust":{
		WeaponMode.SWORD:"Warden_VeiledThrust_OneHanded",
		WeaponMode.DUAL:"Warden_VeiledThrust_OneHanded",
		WeaponMode.SHIELD:"Warden_VeiledThrust_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_VeiledThrust_TwoHanded",
	},
"shield bash":{
		WeaponMode.NONE:"Warden_Bash_OneHanded",
		WeaponMode.SWORD:"Warden_Bash_OneHanded",
		WeaponMode.DUAL:"Warden_Bash_OneHanded",
		WeaponMode.SHIELD:"Warden_Bash_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_Bash_TwoHanded",
	},
"shield pummel":{
		WeaponMode.NONE:"Warden_ShieldPummel_OneHanded",
		WeaponMode.SWORD:"Warden_ShieldPummel_OneHanded",
		WeaponMode.DUAL:"Warden_ShieldPummel_OneHanded",
		WeaponMode.SHIELD:"Warden_ShieldPummel_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_ShieldPummel_TwoHanded",
	},
"mighty push":{
		WeaponMode.NONE:"Warden_MightyPush_OneHanded",
		WeaponMode.SWORD:"Warden_MightyPush_OneHanded",
		WeaponMode.DUAL:"Warden_MightyPush_OneHanded",
		WeaponMode.SHIELD:"Warden_MightyPush_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_MightyPush_TwoHanded",
	},
"smite":{
		WeaponMode.SWORD:"Warden_Smite_OneHanded",
		WeaponMode.DUAL:"Warden_Smite_OneHanded",
		WeaponMode.SHIELD:"Warden_Smite_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_Smite_TwoHanded",
	},
"aegis":{
		WeaponMode.NONE:"Rally",
		WeaponMode.SWORD:"Rally",
		WeaponMode.DUAL:"Rally",
		WeaponMode.SHIELD:"Rally",
		WeaponMode.TWO_HANDED:"Rally",
	},
"second wind":{
		WeaponMode.NONE:"Scream_OneHanded",
		WeaponMode.SWORD:"Scream_OneHanded",
		WeaponMode.DUAL:"Scream_OneHanded",
		WeaponMode.SHIELD:"Scream_OneHanded",
		WeaponMode.TWO_HANDED:"Scream_TwoHanded",
	},
"counterstrike":{
		WeaponMode.NONE:"Warden_CounterStrike_OneHanded",
		WeaponMode.SWORD:"Warden_CounterStrike_OneHanded",
		WeaponMode.DUAL:"Warden_CounterStrike_OneHanded",
		WeaponMode.SHIELD:"Warden_CounterStrike_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_CounterStrike_TwoHanded",
	},
"intercept":{
		WeaponMode.NONE:"Warden_Intercept_OneHanded",
		WeaponMode.SWORD:"Warden_Intercept_OneHanded",
		WeaponMode.DUAL:"Warden_Intercept_OneHanded",
		WeaponMode.SHIELD:"Warden_Intercept_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_Intercept_TwoHanded",
	},


#DROMEUS SKILLS
"cross draw":{
		WeaponMode.NONE:"Dromeus_CrossDraw_Dual",
		WeaponMode.SWORD:"Dromeus_CrossDraw_Dual",
		WeaponMode.DUAL:"Dromeus_CrossDraw_Dual",
		WeaponMode.SHIELD:"Dromeus_CrossDraw_Dual",
		WeaponMode.TWO_HANDED:"Dromeus_CrossDraw_Dual",
	},
"lunar slash":{
		WeaponMode.NONE:"Dromeus_LunarSlash_Dual",
		WeaponMode.SWORD:"Dromeus_LunarSlash_Dual",
		WeaponMode.DUAL:"Dromeus_LunarSlash_Dual",
		WeaponMode.SHIELD:"Dromeus_LunarSlash_Dual",
		WeaponMode.TWO_HANDED:"Dromeus_LunarSlash_Dual",
	},
"recoil slash":{
		WeaponMode.NONE:"Dromeus_RecoilSlash_OneHanded",
		WeaponMode.SWORD:"Dromeus_RecoilSlash_OneHanded",
		WeaponMode.DUAL:"Dromeus_RecoilSlash_OneHanded",
		WeaponMode.SHIELD:"Dromeus_RecoilSlash_OneHanded",
		WeaponMode.TWO_HANDED:"Dromeus_RecoilSlash_OneHanded",
	},
#BERSERK SKILLS
	"raze":{
		WeaponMode.SWORD:"Berserk_Raze_OneHanded",
		WeaponMode.DUAL:"Berserk_Raze_OneHanded",
		WeaponMode.SHIELD:"Berserk_Raze_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_Raze_TwoHanded",
	},
	"reckless":{
		WeaponMode.NONE:"Buff_OneHanded",
		WeaponMode.SWORD:"Buff_OneHanded",
		WeaponMode.DUAL:"Buff_OneHanded",
		WeaponMode.SHIELD:"Buff_OneHanded",
		WeaponMode.TWO_HANDED:"Buff_TwoHanded",
	},
	"stone splitter":{
		WeaponMode.SWORD:"Berserk_StoneSplitter_OneHanded",
		WeaponMode.DUAL:"Berserk_StoneSplitter_OneHanded",
		WeaponMode.SHIELD:"Berserk_StoneSplitter_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_StoneSplitter_TwoHanded",
	},
	"brutal chop":{
		WeaponMode.SWORD:"Berserk_BrutalChop_OneHanded",
		WeaponMode.DUAL:"Berserk_BrutalChop_OneHanded",
		WeaponMode.SHIELD:"Berserk_BrutalChop_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_BrutalChop_TwoHanded",
	},
	"shoulder bash":{
		WeaponMode.NONE:"Berserk_ShoulderBash_OneHanded",
		WeaponMode.SWORD:"Berserk_ShoulderBash_OneHanded",
		WeaponMode.DUAL:"Berserk_ShoulderBash_OneHanded",
		WeaponMode.SHIELD:"Berserk_ShoulderBash_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_ShoulderBash_TwoHanded",
	},
	
	"fury strike":{
		WeaponMode.SWORD:"Berserk_FuryStrike_OneHanded",
		WeaponMode.DUAL:"Berserk_FuryStrike_OneHanded",
		WeaponMode.SHIELD:"Berserk_FuryStrike_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_FuryStrike_TwoHanded",
	},
	"sadistic blow":{
		WeaponMode.SWORD:"Berserk_SadisticBlow_OneHanded",
		WeaponMode.DUAL:"Berserk_SadisticBlow_OneHanded",
		WeaponMode.SHIELD:"Berserk_SadisticBlow_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_SadisticBlow_TwoHanded",
	},

	"sunder" :{
		WeaponMode.SWORD:"Berserk_Sunder_OneHanded",
		WeaponMode.DUAL:"Berserk_Sunder_OneHanded",
		WeaponMode.SHIELD:"Berserk_Sunder_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_Sunder_TwoHanded",
	},
	"sledge":{
		WeaponMode.SWORD:"Berserk_Sledge_OneHanded",
		WeaponMode.DUAL:"Berserk_Sledge_OneHanded",
		WeaponMode.SHIELD:"Berserk_Sledge_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_Sledge_TwoHanded",
	},
	"heart thrust":{
		WeaponMode.SWORD:"Berserk_HeartThrust_OneHanded",
		WeaponMode.DUAL:"Berserk_HeartThrust_OneHanded",
		WeaponMode.SHIELD:"Berserk_HeartThrust_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_HeartThrust_TwoHanded",
	},
	"obliteration charge":{
		WeaponMode.SWORD:"Berserk_ObliterationCharge_cycle",
		WeaponMode.DUAL:"Berserk_ObliterationCharge_cycle",
		WeaponMode.SHIELD:"Berserk_ObliterationCharge_cycle",
		WeaponMode.TWO_HANDED:"Berserk_ObliterationCharge_cycle",
	},
	"obliteration":{
		WeaponMode.SWORD:"Berserk_SadisticBlow_TwoHanded",
		WeaponMode.DUAL:"Berserk_SadisticBlow_TwoHanded",
		WeaponMode.SHIELD:"Berserk_SadisticBlow_TwoHanded",
		WeaponMode.TWO_HANDED:"Berserk_SadisticBlow_TwoHanded",
	},

	"death from above":{
		WeaponMode.NONE:"ALL_DeathFromAbove",
		WeaponMode.SWORD:"ALL_DeathFromAbove",
		WeaponMode.DUAL:"ALL_DeathFromAbove",
		WeaponMode.SHIELD:"ALL_DeathFromAbove",
		WeaponMode.TWO_HANDED:"ALL_DeathFromAbove",
	},
	"flury of blows":{
		WeaponMode.NONE:"ALL_Guillotine",
		WeaponMode.SWORD:"ALL_Guillotine",
		WeaponMode.DUAL:"ALL_Guillotine",
		WeaponMode.SHIELD:"ALL_Guillotine",
		WeaponMode.TWO_HANDED:"ALL_Guillotine",
	},
	"section":{
		WeaponMode.NONE:"1h_Section",
		WeaponMode.SWORD:"1h_Section",
		WeaponMode.DUAL:"1h_Section",
		WeaponMode.SHIELD:"1h_Section",
		WeaponMode.TWO_HANDED:"1h_Section",
	},
	"perforation trifecta":{
		WeaponMode.NONE:"1h_PerforactionTrifecta",
		WeaponMode.SWORD:"1h_PerforactionTrifecta",
		WeaponMode.DUAL:"1h_PerforactionTrifecta",
		WeaponMode.SHIELD:"1h_PerforactionTrifecta",
		WeaponMode.TWO_HANDED:"1h_PerforactionTrifecta",
	},
	"cleave":{
		WeaponMode.NONE:"1h_Slice",
		WeaponMode.SWORD:"1h_Slice",
		WeaponMode.DUAL:"1h_Slice",
		WeaponMode.SHIELD:"1h_Slice",
		WeaponMode.TWO_HANDED:"1h_Slice",
	},
	"parry":{
		WeaponMode.NONE:"ALL_SwordGuard",
		WeaponMode.SWORD:"ALL_SwordGuard",
		WeaponMode.DUAL:"ALL_SwordGuard",
		WeaponMode.SHIELD:"ALL_SwordGuard",
		WeaponMode.TWO_HANDED:"Backstep",
	},


	"dodge":{
		WeaponMode.NONE:"Basic_Slide_OneHanded",
		WeaponMode.SWORD:"Basic_Slide_OneHanded",
		WeaponMode.DUAL:"Basic_Slide_OneHanded",
		WeaponMode.SHIELD:"Basic_Slide_OneHanded",
		WeaponMode.TWO_HANDED:"Basic_Slide_TwoHanded",
	},
	"downed":{
		WeaponMode.NONE:"DownedStart",
		WeaponMode.SWORD:"DownedStart",
		WeaponMode.DUAL:"DownedStart",
		WeaponMode.SHIELD:"DownedStart",
		WeaponMode.TWO_HANDED:"DownedStart",
	},}
var last_skill_animation:String =""
var guard_react_priority := false

func activateAnimLock(lock_name:String)->void:
	if lock_name=="guard react":
		unlockAnim()
		guard_react_priority=true
		anim_locks.clear()
		anim_locks["guard react"]=true
		current_skill="guard"
		return
	guard_react_priority=false
	if anim_locks["dodge"] and lock_name!="dodge": return
	if lock_name=="dodge":
		unlockAnim();anim_locks["dodge"]=true;current_skill="dodge";return
	if lock_name=="parry":
		unlockAnim();anim_locks["parry"]=true;current_skill="parry";return


	if lock_name == "combo attack":
		for key in anim_locks:
			if anim_locks[key]:
				return

		anim_locks["combo attack"] = true
		current_skill = lock_name
		return

	if lock_name in interrupt_groups["skills"]:
		anim_locks["combo attack"] = false

		for skill in interrupt_groups["skills"]:
			anim_locks[skill] = false

		anim_locks[lock_name] = true
		current_skill = lock_name

func getActiveAnimLock()->String:
	if !isLocalPlayer():
		# Puppets never populate anim_locks (only movement_mode/current_skill/etc.
		# get synced), so without this they'd always read "" here and skill
		# animations (setSkillAnimation) would never trigger for other players.
		return net_active_lock

	var active_locks=[]
	for lock_name in anim_locks:
		if anim_locks[lock_name]:
			active_locks.append(lock_name)
	$UI/Chat/debug.text=", ".join(active_locks)
	if active_locks.size()>0:
		return active_locks[0]
	return ""
"""
Assigns the correct animation for a skill based on the player's current
weapon mode.
If the skill exists but does not have an animation assigned for the
currently equipped weapon type, the skill is cancelled and its resource
cost and cooldown are refunded through skillbar.reimburseSkill().
Parameters:skill_name (String)Name of the skill being activated.
Returns:
	void
"""

var last_active_skill:String = ""
var _skill_hard_deadline_ms:int = -1

func setSkillAnimation(skill_name:String)->void:
	if !skill_animations.has(skill_name):
		return
	var skill_data = skill_animations[skill_name]
	var new_anim:String = ""
	if skill_data.has(weapons):
		new_anim=skill_data[weapons]
	else:
		anim_locks[skill_name] = false
		current_skill = "none"
		if anim_locks["flinch"] == false or anim_locks["knocked back"] == false:
			unlockAnim()
		skillbar.reimburseSkill(skill_name)
		animation_tree.active = true
		_skill_hard_deadline_ms = -1
		return

	if new_anim == "":
		anim_locks[skill_name] = false
		current_skill = "none"
		skillbar.reimburseSkill(skill_name)
		animation_tree.active = true
		_skill_hard_deadline_ms = -1
		return

	if skill_name == last_active_skill:
		return

	# GUARD: never assign an animation name to skill_anim (AnimationNodeAnimation)
	# that the AnimationPlayer doesn't actually have -- that null track pointer
	# is what spams "_process_graph: Condition "!track_pp" is true" every frame.
	var anim_length:float = 1.0
	var has_real_anim := false
	if is_instance_valid(player_mesh):
		var ap = player_mesh.get_node_or_null("AnimationPlayer")
		if is_instance_valid(ap) and ap.has_animation(new_anim):
			has_real_anim = true
			anim_length = ap.get_animation(new_anim).length
	if !has_real_anim:
		anim_locks[skill_name] = false
		current_skill = "none"
		skillbar.reimburseSkill(skill_name)
		animation_tree.active = true
		_skill_hard_deadline_ms = -1
		return

	last_active_skill = skill_name

	skill_anim.animation = new_anim

	# FIX: active=false immediately followed by active=true in the SAME tick
	# never gives the AnimationTree an actual processing pass to flush its
	# internal graph state before it's turned back on -- the deactivate only
	# really "lands" once the tree's own _physics_process runs, which hasn't
	# happened yet between these two lines. On a tree that hasn't recently
	# had real frames pass through it, the reactivate lands on stale
	# internal playback state, causing the new clip to start mid-position or
	# get cut off early (exactly the "first few casts are broken" symptom --
	# nothing was ever actually "warming up", frames were just being forced
	# to elapse through the tree until a deactivate finally landed cleanly).
	# Deferring the reactivate across the frame boundary guarantees the
	# deactivate has actually been processed first, every single time,
	# regardless of how "cold" the tree is.
	animation_tree.active = false
	call_deferred("_reactivateSkillAnimationTree")

	var time_scale:float = max(stats.derived_stats.get("attack_speed", 1.0), 0.01)
	_skill_hard_deadline_ms = OS.get_ticks_msec() + int((anim_length / time_scale) * 1000.0) + 150

func _reactivateSkillAnimationTree() -> void:
	if is_instance_valid(animation_tree):
		animation_tree.active = true







func checkSkillHardDeadline() -> void:
	if _skill_hard_deadline_ms < 0:
		return
	if current_skill == "" or current_skill == "none":
		_skill_hard_deadline_ms = -1
		return
	if OS.get_ticks_msec() >= _skill_hard_deadline_ms:
		_skill_hard_deadline_ms = -1
		anim_calls.unlockAnim()


var movement_blend:float= -1.0
var combat_blend:float= -1.0
var attack_defend_switch:float= 0.0

var movement_type_blend:float= 0.0
var vertical_blend:float= 0.0
var crouch_blend:float= 1.0
var crouch_mode_blend:float= 0.0
var climb_blend:float= 0.0
var water_blend:float = 0.0

var anim_blend_cache := {}

# ------------------------------------------------------------
# setAnimBlend
# Smooths any AnimationTree blend parameter using per-path
# cached interpolation instead of overwriting values directly.
# This prevents flickering caused by competing writes from
# different animation states in the same frame.
# Parameters:
# - path: AnimationTree parameter path
# - target: desired blend value (-1 to 1 or 0 to 1 depending on node)
# - speed: interpolation strength (higher = snappier, lower = smoother)
# - delta: frame delta time
# ------------------------------------------------------------
var flip_blend_timer:float= 0.0
var dodge_cleanup_timer:float= 0.0
var dodge_cleanup_reset:bool= false
var dodge_cleanup_blend_speed:float = 0.4
var blend:float = 1
var downed_blend_speed:float = 6.0
func setAnimBlend(path:String, target:float, speed:float, delta:float) -> void:
	var current:float = 0.0

	if anim_blend_cache.has(path):
		var cached_value = anim_blend_cache[path]
		if cached_value != null:
			current = float(cached_value)
		else:
			#print("Player.gd setAnimBlend(): AnimBlend warning: null cache value for path: ", path)
			current = 0.0
	else:
		var tree_value = animation_tree.get(path)
		if tree_value == null:
			#print("Player.gd setAnimBlend(): AnimBlend warning: missing AnimationTree path: ", path)
			current = 0.0
		else:
			current = float(tree_value)

	current = move_toward(current, target, delta * speed)

	anim_blend_cache[path] = current
	setAnimRaw(path, current)
func initializeAnimationBlends() -> void:
	if !shouldAnimateLocally():
		return
	var blendPaths:Array = [
		"parameters/CombatSwitch/blend_amount",
		"parameters/MeleeSkillSwitch/blend_amount",
		"parameters/Movement/blend_amount",
		"parameters/MovementType/blend_amount",
		"parameters/Vertical/blend_amount",
		"parameters/CrouchOrNot/blend_amount",
		"parameters/CrouchMode/blend_amount",
		"parameters/climbPoint/blend_amount",
		"parameters/Water/blend_amount",
		"parameters/IsInCombat/blend_amount",
		"parameters/SkillBlend/blend_amount"
	]
	anim_blend_cache.clear()
	for path in blendPaths:
		var value = animation_tree.get(path)
		if value == null:
			#print("Player.gd initializeAnimationBlends(): AnimBlend init warning: missing AnimationTree path: ", path)
			value = 0.0
		anim_blend_cache[path] = float(value)

func safeGetBlend(path:String) -> float:
	var value = animation_tree.get(path)
	if value == null:
		return 0.0
	return float(value)



var combat_walk_animations = {
	WeaponMode.NONE:"Walk_cycle",
	WeaponMode.SWORD:"Walk_OneHandedCombat_cycle",
	WeaponMode.DUAL:"Walk_OneHandedCombat_cycle",
	WeaponMode.SHIELD:"Walk_OneHandedCombat_cycle",
	WeaponMode.TWO_HANDED:"Walk_TwoHandedCombat_cycle",
}
var combat_run_animations = {
	WeaponMode.NONE:"Sprint_cycle",
	WeaponMode.SWORD:"Run_OneHandedCombat_cycle",
	WeaponMode.DUAL:"Run_OneHandedCombat_cycle",
	WeaponMode.SHIELD:"Run_OneHandedWithShieldCombat_cycle",
	WeaponMode.TWO_HANDED:"Run_TwoHandedCombat_cycle",
}
var combat_idle_animations = {
	WeaponMode.NONE:"IdleOneHanded_cycle",
	WeaponMode.SWORD:"IdleOneHanded_cycle",
	WeaponMode.DUAL:"IdleOneHanded_cycle",
	WeaponMode.SHIELD:"IdleOneHanded_cycle",
	WeaponMode.TWO_HANDED:"IdleTwoHanded_cycle",
}
onready var combat_idle = animation_tree.tree_root.get_node("CombatIdle")
onready var combat_walk = animation_tree.tree_root.get_node("WalkCombat")
onready var run_node = animation_tree.tree_root.get_node("RunCombat")
onready var combat_idle_skill_smooth = animation_tree.tree_root.get_node("IdleForSkill")
func setCombatIdleAnimation()->void:
	if !combat_idle_animations.has(weapons):
		return
	var anim = combat_idle_animations[weapons]
	if !is_instance_valid(player_mesh):
		return
	var ap = player_mesh.get_node_or_null("AnimationPlayer")
	if !is_instance_valid(ap) or !ap.has_animation(anim):
		return

	combat_idle.animation = anim
	combat_idle_skill_smooth.animation = anim
func setCombatWalkAnimation()->void:
	if !combat_walk_animations.has(weapons):
		return
	var anim = combat_walk_animations[weapons]
	if !is_instance_valid(player_mesh):
		return
	var ap = player_mesh.get_node_or_null("AnimationPlayer")
	if !is_instance_valid(ap) or !ap.has_animation(anim):
		return

	combat_walk.animation = anim
func setRunAnimation()->void:
	if !combat_run_animations.has(weapons):
		return
	var anim = combat_run_animations[weapons]
	if !is_instance_valid(player_mesh):
		return
	var ap = player_mesh.get_node_or_null("AnimationPlayer")
	if !is_instance_valid(ap) or !ap.has_animation(anim):
		return

	run_node.animation = anim
func reactivateAnimationTree() -> void:
	if !is_instance_valid(animation_tree):
		return

	if is_instance_valid(player_mesh):
		var anim_player = player_mesh.get_node_or_null("AnimationPlayer")
		if anim_player:
			var ap_path:NodePath = animation_tree.get_path_to(anim_player)
			if animation_tree.has_method("set_animation_player"):
				animation_tree.call("set_animation_player", ap_path)
			else:
				setAnimRaw("anim_player", ap_path)

	animation_tree.active = false
	animation_tree.active = true






var water:float = -1.0
var land:float = 0.0
var air:float = 1.0
var climbing:float = 0.0
var falling:float = 1.0



func shouldAnimateLocally() -> bool:
	# On a dedicated/headless server, every connected player's Player node
	# exists purely for authoritative bookkeeping (Stats/inventory/etc) --
	# nothing about it is ever rendered, so evaluating a full AnimationTree
	# blend graph for it every physics tick was pure waste and the actual
	# cause of the server CPU spiking under load. Real clients (including
	# a player who is also hosting) still need full animation for every
	# OTHER player they can see -- only the server's own non-rendered
	# copies get skipped here.
	if get_tree().network_peer == null:
		return true # offline, single machine, always render
	if !get_tree().is_network_server():
		return true # we're a client -- every Player node we have exists to be seen
	return isLocalPlayer() 

var _raw_anim_set_cache := {}
func setAnimRaw(path:String, value) -> void:
	if _raw_anim_set_cache.has(path):
		var cached = _raw_anim_set_cache[path]
		if typeof(cached) == typeof(value):
			if cached == value:
				return
	_raw_anim_set_cache[path] = value
	animation_tree.set(path, value)
var _animation_tree_warmed_once := false
func warmupAnimationTreeOnce() -> void:
	if _animation_tree_warmed_once:
		return
	if !is_instance_valid(animation_tree):
		return
	if !shouldAnimateLocally():
		return
	_animation_tree_warmed_once = true
	animation_tree.active = false
	call_deferred("_finishAnimationTreeWarmup")

func _finishAnimationTreeWarmup() -> void:
	if is_instance_valid(animation_tree):
		animation_tree.active = true
var skillExitBlendSpeed:float = 2.0
func animationOrder(delta:float) -> void:
	if stats.debuff_buffs_active.has("stunned") and float(stats.debuff_buffs_active["stunned"].get("duration",0.0)) > 0.0:
		setAnimRaw("parameters/CombatSwitch/blend_amount", 0.0)
		setAnimRaw("parameters/CrouchOrNot/blend_amount", 1.0)
		setAnimRaw("parameters/Movement/blend_amount", -1.0)
		setAnimRaw("parameters/IsInCombat/blend_amount", 0.0)
		animation_tree.active = true
		return
	#leave animation_tree off by default 
	var active_lock:=getActiveAnimLock()
	var now = OS.get_ticks_msec() / 1000.0
	var skill_scale:float =  stats.derived_stats["attack_speed"] 
	if anim_calls.speed_up_combo_until.has(active_lock):
		if now < anim_calls.speed_up_combo_until[active_lock]:
			skill_scale =  stats.derived_stats["attack_speed"] + 3
			#print("[BERSERK] scale applied lock=", active_lock, " scale=", skill_scale, " anim_calls=", anim_calls.get_instance_id())
		else:
			anim_calls.speed_up_combo_until.erase(active_lock)
			#print("[BERSERK] MISS lock=", active_lock, " current_skill=", current_skill, " dict_keys=", anim_calls.speed_up_combo_until.keys(), " anim_calls=", anim_calls.get_instance_id())
	setAnimRaw("parameters/SkillTimeScale/scale", skill_scale)
	
	var speed_factor_walk = max(0.0, stats.walk_speed / 4.0)
	if speed_factor_walk > 1.0:
		speed_factor_walk = 1.0 + sqrt(speed_factor_walk - 1.0) * 0.5
	setAnimRaw("WalkSpeed", speed_factor_walk)
	var speed_factor_run = max(0.0, (stats.run_speed * lerp(1.0, run_max_speed_multiplier, clamp(current_run_time / run_ramp_time, 0.0, 1.0))) / 15.5)
	if speed_factor_run > 1.0:
		speed_factor_run = 1.0 + (speed_factor_run - 1.0) * 0.25
	setAnimRaw("RunSpeed", speed_factor_run)

	updateDownedAnimationBlends(delta)

	# -----------------------------
	# STAGGER / STUN OVERRIDE
	# -----------------------------
	if stats != null and stats.statuses.has("stun"):
		last_active_skill = "staggered"
		current_skill = "staggered"
		skill_anim.animation = "staggered"

		setAnimRaw("parameters/CombatSwitch/blend_amount", 1.0)
		setAnimRaw("parameters/MeleeSkillSwitch/blend_amount",1.0)
		setAnimRaw("parameters/MeleeSkillSwitch/blend_amount", 1.0)
		return

	else:
		anim_locks["stunned"] = false
		anim_locks["staggered"] = false

		# ============================================================
		# SKILL / COMBAT STATE
		# ============================================================
		if active_lock!="" and skill_animations.has(active_lock):
			setSkillAnimation(active_lock)
			setAnimBlend("parameters/SkillBlend/blend_amount",1.0,blend,delta)
			setAnimBlend("parameters/CombatSwitch/blend_amount",1.0,blend,delta)
			setAnimBlend("parameters/MeleeSkillSwitch/blend_amount",1.0,blend,delta)

			if active_lock == "combo attack":
				skill_scale = stats.derived_stats["attack_speed"]

			if anim_calls != null and anim_calls.speed_up_combos.has(active_lock):
				setAnimRaw("parameters/SkillTimeScale/scale", skill_scale)

			return
		# Character returns to movement locomotion state.
		# ============================================================
		last_active_skill=""

		# ------------------------------------------------------------
		# Leave combat state smoothly.
		# ------------------------------------------------------------

		setAnimRaw("parameters/CombatSwitch/blend_amount",0.0)
		setAnimRaw("parameters/MeleeSkillSwitch/blend_amount",0.0)

		# ============================================================
		# TARGET VALUES
		# ============================================================
		var movement_target:float=-1.0
		var movement_type_target:float=0.0
		var vertical_target:float=0.0
		var crouch_target:float=1.0
		var crouch_mode_target:float=0.0
		var climb_target:float=0.0
		var water_target:float=0.0

		# ============================================================
		# AIRBORNE STATE
		# ============================================================
		if is_airborne and !is_climbing and !is_swimming:
			pass

		else:
			setAnimRaw("parameters/WaterLandAir/blend_amount",land)
			setAnimRaw("parameters/ClimbingOrFalling/blend_amount",falling)
			if is_dead == true:
				return
			# ========================================================
			# MOVEMENT STATE MACHINE
			# ========================================================
			match movement_mode:
				# ----------------------------------------------------
				# IDLE
				# ----------------------------------------------------
				"idle":
					if stats.health >0:
						movement_target=-1.0
						if is_in_combat:
							setAnimBlend("parameters/IsInCombat/blend_amount",1.0,blend,delta)
							setCombatIdleAnimation()

						else:
							setAnimBlend("parameters/IsInCombat/blend_amount",0.0,blend,delta)
							setAnimRaw("parameters/WaterLandAir/blend_amount",land)
					else:
						setAnimRaw("parameters/WaterLandAir/blend_amount",land)
				# ----------------------------------------------------
				# WALK
				# ----------------------------------------------------
				"walk":
					movement_target=0.0
					if stats.health >0:
						if is_in_combat == true:
							setAnimRaw("parameters/WalkCombatOrNot/blend_amount",1)
							setAnimRaw("parameters/WaterLandAir/blend_amount",land)
							setCombatWalkAnimation()
						else:
							setAnimRaw("parameters/WalkCombatOrNot/blend_amount",0)
							setAnimRaw("parameters/WaterLandAir/blend_amount",land)
					else:
						setAnimRaw("parameters/WaterLandAir/blend_amount",land)
				# ----------------------------------------------------
				# RUN
				# ----------------------------------------------------
				"run":
					if stats.health >0:
						if is_in_combat == true: 
							setRunAnimation()
							setAnimRaw("parameters/IsInCombatRun/blend_amount",1)
							setAnimRaw("parameters/WaterLandAir/blend_amount",land)
						else:
							setAnimRaw("parameters/IsInCombatRun/blend_amount",0)
							setAnimRaw("parameters/WaterLandAir/blend_amount",land)
						movement_target=1.0
						setAnimRaw("parameters/RunSpeed/scale",0.8+(0.0125*stats.run_speed))
						
				# ----------------------------------------------------
				# CROUCH IDLE
				# ----------------------------------------------------
				"crouch_idle":
					crouch_target=0.0
					crouch_mode_target=0.0
					setAnimRaw("parameters/CrouchMov/blend_amount",0)
					setAnimRaw("parameters/IsInCombatRun/blend_amount",0)
					setAnimRaw("parameters/WaterLandAir/blend_amount",land)
				# ----------------------------------------------------
				# CROUCH MOVEMENT
				# ----------------------------------------------------
				"crouch_moving":
					crouch_target=0.0
					crouch_mode_target=1.0
					setAnimRaw("parameters/CrouchMov/blend_amount",1)
					setAnimRaw("parameters/IsInCombatRun/blend_amount",0)
					setAnimRaw("parameters/WaterLandAir/blend_amount",0)
				# ----------------------------------------------------
				# CLIMB
				# ----------------------------------------------------
				"climb":
					movement_type_target=1.0
					vertical_target=0.0
					climb_target=0.0

				# ----------------------------------------------------
				# VAULT
				# ----------------------------------------------------
				"vault":
					movement_type_target=1.0
					vertical_target=0.0
					climb_target=1.0

				# ----------------------------------------------------
				# SWIMMING
				# ----------------------------------------------------
				"swimming":
					movement_type_target=-1.0
					water_target=1.0
					setAnimRaw("parameters/WaterLandAir/blend_amount",water)
					setAnimRaw("parameters/SwimSpeed/scale",0.97+(0.03*stats.derived_stats["swim_speed"]))

				# ----------------------------------------------------
				# TREADING WATER
				# ----------------------------------------------------
				"treading water":
					setAnimRaw("parameters/WaterLandAir/blend_amount",water)
					movement_type_target=-1.0
					water_target=0.0
		# ============================================================
		# FINAL BLENDING
		# ============================================================
		# All calculated targets are interpolated smoothly.
		# This prevents snapping between animation states.
		# ============================================================
		setAnimBlend("parameters/Movement/blend_amount",movement_target,8.0,delta)
		setAnimBlend("parameters/Vertical/blend_amount",vertical_target,8.0,delta) 

		setAnimBlend("parameters/CrouchOrNot/blend_amount",crouch_target,8.0,delta)
		setAnimBlend("parameters/CrouchMode/blend_amount",crouch_mode_target,8.0,delta)
		setAnimBlend("parameters/climbPoint/blend_amount",climb_target,8.0,delta)
		setAnimBlend("parameters/Water/blend_amount",water_target,8.0,delta)


func updateDownedAnimationBlends(delta:float) -> void:
	var is_alive_target := 1.0 if stats.health > 0 else 0.0
	setAnimBlend("parameters/IsAlive/blend_amount", is_alive_target, downed_blend_speed, delta)

	var downed_target := 0.0
	if stats.health <= 0:
		if anim_locks.get("get up", false):
			downed_target = 1.0
		elif moving and direction.length_squared() > 0.0001:
			downed_target = 0.0
		else:
			downed_target = -1.0
	setAnimBlend("parameters/Downed/blend_amount", downed_target, downed_blend_speed, delta)
export var root_motion_scale:float = 0.01

onready var detection_area:Area = $Turnable/Area

var root_motion_exceptions = [
	"shoulder bash",
	"backstep",
	"evasion",
	"foresight slash",
	"lunar slash"
]
func rootMotion(delta:float)->void:
	if delta <= 0.0:
		return

	if current_skill == "backstep":
		root_motion_scale = 0.01 * stats.attributes["agility"] * 1.25

	var ignore_detection = (
		current_skill in root_motion_exceptions
		or anim_locks["flinch"]
		or anim_locks["knocked back"]
		or anim_locks["knocked down"]
		or anim_locks["dodge"]
	)

	if !ignore_detection:
		for body in detection_area.get_overlapping_bodies():
			if body != self and body.is_in_group("Entity"):
				return

	var motion:Transform = animation_tree.get_root_motion_transform()
	var offset:Vector3 = motion.origin
	offset.y = 0.0

	if offset.length_squared() < 0.000001:
		return

	offset *= root_motion_scale
	offset = player_mesh.global_transform.basis.xform(offset)

	# FIX: `offset` is the FULL root-motion displacement already accumulated
	# by the AnimationTree for the entire elapsed period this call covers
	# (AnimationTree itself still ticks every physics substep regardless of
	# our own visual-frame gating). move_and_slide() always multiplies
	# whatever velocity we pass by get_physics_process_delta_time() (the
	# FIXED single-frame timestep) — never by `delta`. So the correct
	# velocity to hand it is offset / physics_dt, NOT offset / delta:
	# that makes move_and_slide's own internal `* physics_dt` cancel out
	# and reproduce the exact accumulated `offset` regardless of how many
	# frames were skipped. Dividing by `delta` (the old code) under-shot
	# more and more the lower the FPS got, which is the "gets slower and
	# slower" bug.
	var physics_dt:float = get_physics_process_delta_time()
	if physics_dt <= 0.0:
		return

	move_and_slide(Vector3(offset.x / physics_dt, vertical_velocity.y, offset.z / physics_dt), Vector3.UP)





var unstuckDistance = 15
onready var dodge_check:Area = $Turnable/Cleave

func dodgeMessage()->void:
	var bodies = dodge_check.get_overlapping_bodies()
	for body in bodies:
		if body == self: continue
		if !body.is_in_group("Entity"): continue

		var skill_name = body.get("current_skill") if body.has_method("get") or "current_skill" in body else ""
		if skill_name == "" or skill_name == "none" or !Global.skills.has(skill_name) or Global.support_skills.has(skill_name): continue
		
		var message = "dodged "
		if "entity_name" in body and body.entity_name != "nameless":
			message += body.entity_name
		else:
			message += body.stats.species

		message += " " + skill_name
		chat.sendSystemMessage(message)
					
					
onready var area_check_level_detector = $unstuckCheck

var _collisions_are_enabled := true 

func dodgeCollisions(_delta) -> void:
	var is_dodge_skill = Global.skill_dmg_immunity.has(current_skill)

	if is_dodge_skill:
		if current_skill != last_active_skill:
			dodgeMessage()
		if _collisions_are_enabled:
			anim_calls.disableCollisions()
			_collisions_are_enabled = false

		var should_enable = true
		for body in area_check_level_detector.get_overlapping_bodies():
			if body == self: continue
			if body.is_in_group("Entity") and !body.is_in_group("Player"):
				horizontal_velocity = direction.normalized() * stats.walk_speed
				should_enable = false
				break

		if should_enable and !_collisions_are_enabled:
			anim_calls.enableCollisions()
			_collisions_are_enabled = true
		return

	if !_collisions_are_enabled:
		anim_calls.enableCollisions()
		_collisions_are_enabled = true



var mining_icons = []
var chopping_icons = []
var harvest_key = ""
var loot_key = ""



func _updateInputKeys():
	harvest_key = InputMap.get_action_list("Harvest")[0].as_text().replace(" (Physical)", "").replace(" (physical)", "")

	var loot_keys = []
	for event in InputMap.get_action_list("loot"):
		loot_keys.append(event.as_text().replace(" (Physical)", "").replace(" (physical)", ""))
	loot_key = " / ".join(loot_keys)

func _cacheToolIcons():
	mining_icons.clear()
	chopping_icons.clear()

	for weapon_name in Global.weapons:
		var weapon = Global.weapons[weapon_name]
		var icon = weapon.icon
		if typeof(icon) == TYPE_STRING:
			icon = load(icon)

		if weapon.has("mining power"):
			mining_icons.append(icon)

		if weapon.has("chopping power"):
			chopping_icons.append(icon)


func detectGathering() -> void:
	if connection_status_active:
		return
	if is_downed or stats.health <= 0:
		return
	var label:Label = $UI/ResourceDetectionLabel
	label.visible = false
	label.text = ""
	for body in $"Turnable/Area".get_overlapping_bodies():
		if body == self:
			continue
		if (body.is_in_group("entity") or body.is_in_group("Entity")) and "stats" in body and body.stats.health <= 0:
			if "is_downed" in body and body.is_downed:
				continue
			label.visible = true
			label.text = "Press " + loot_key + " to loot"
			return

	var bash = $"Turnable/Bash"

	for target in bash.get_overlapping_bodies():
		if _handleGatherTarget(target, label):
			return

	for target in bash.get_overlapping_areas():
		if _handleGatherTarget(target, label):
			return
var _cached_has_pickaxe:bool = false
var _cached_has_axe:bool = false
var _tool_cache_dirty:bool = true

func markToolCacheDirty() -> void:
	_tool_cache_dirty = true
onready var inventory_grid = $UI/Inventory/ScrollContainer/GridContainer
func _refreshToolCache() -> void:
	_tool_cache_dirty = false
	var main_hand = $"UI/Equipment/MainHand/Slot".texture

	_cached_has_pickaxe = main_hand in mining_icons
	_cached_has_axe = main_hand in chopping_icons
	if !_cached_has_pickaxe or !_cached_has_axe:
		for child in inventory_grid.get_children():
			var slot = child.get_node("Slot")
			if !slot:
				continue
			if !_cached_has_pickaxe and slot.texture in mining_icons:
				_cached_has_pickaxe = true
			if !_cached_has_axe and slot.texture in chopping_icons:
				_cached_has_axe = true
			if _cached_has_pickaxe and _cached_has_axe:
				break

func _handleGatherTarget(target, label:Label) -> bool:
	if !is_instance_valid(target) or !target.is_in_group("Resource"):
		return false

	if _tool_cache_dirty:
		_refreshToolCache()
	var has_pickaxe = _cached_has_pickaxe
	var has_axe = _cached_has_axe

	var can_harvest=false
	for group in target.get_groups():
		match group.to_lower():
			"plant":
				can_harvest=true
			"rock","iron","gold":
				can_harvest=has_pickaxe
			"tree":
				can_harvest=has_axe
		if can_harvest:
			break

	if can_harvest and current_skill!="mine" and current_skill!="gather" and current_skill!="chop":
		label.visible=true
		label.text="Press "+harvest_key+" to Harvest"

	if !Input.is_action_just_pressed("Harvest"):
		return true

	if !can_harvest:
		return true

	forceRotationTowardsTarget(target)

	for group in target.get_groups():
		match group.to_lower():
			"plant":
				skillbar.castSkill("gather")
				return true
			"rock","iron","gold":
				skillbar.castSkill("mine")
				return true
			"tree":
				skillbar.castSkill("chop")
				return true

	return true
func _isInPortalGroup(node) -> bool:
	for group in node.get_groups():
		if str(group).to_lower() == "portal":
			return true
	return false
onready var smelting_system:Control=$UI/Crafting/Smelting
onready var recipes_book:Control=$UI/Crafting/RecipeeBook
onready var label:Label=$UI/ResourceDetectionLabel
onready var prog_texture:TextureProgress = $UI/ResourceDetectionLabel/ProgTexture


onready var quests_list:Control =  $UI/QuestSystem/QuestList
onready var quest_system:Control = $UI/QuestSystem
func detectObjects()->void:
	if is_downed or stats.health <= 0:
		return
	var key=InputMap.get_action_list("Harvest")[0].as_text().replace(" (Physical)","").replace(" (physical)","")
	for target in $"Turnable/Bash".get_overlapping_bodies()+$"Turnable/Bash".get_overlapping_areas():
		if !is_instance_valid(target):continue
		if target.is_in_group("Fire") and Input.is_action_just_pressed("Harvest"):
			if crafting.current_fire!=target:
				if is_instance_valid(crafting.current_fire):
					crafting.saveSmelter(crafting.current_fire)
				crafting.loadSmelter(target)
			
			smelting_system.visible=!smelting_system.visible
			recipes_book.show()
			inventory.show()
			crafting.show()
			recipes_book.hide()
			return
		
		elif target.is_in_group("QuestGiver") and Input.is_action_just_pressed("Harvest"):
			crafting.hide()
			recipes_book.hide()
			smelting_system.hide()
			quests_list.visible = !quests_list.visible
			quest_system.background.visible = quests_list.visible
			

		
		if _isInPortalGroup(target):
			label.visible=true
			label.text="Press "+key+" to enter portal"
			if Input.is_action_just_pressed("Harvest"):
				get_parent().portal(target)

var being_revived_active := false
var being_revived_progress := 0.0

# Called by whoever is reviving you (player OR bot) every tick while they
# channel the revive, so YOUR OWN screen shows live progress regardless of
# who's doing the reviving.
remote func setBeingRevivedProgress(progress:float, active:bool) -> void:
	if !isLocalPlayer():
		return
	being_revived_active = active
	being_revived_progress = clamp(progress, 0.0, 100.0)

func updateBeingRevivedUI() -> void:
	if !is_downed:
		being_revived_active = false
		return
	if being_revived_active:
		label.visible = true
		label.text = "Being revived... " + str(int(being_revived_progress)) + "%"
		if is_instance_valid(prog_texture):
			prog_texture.visible = true
			prog_texture.value = being_revived_progress
	elif is_instance_valid(prog_texture):
		prog_texture.visible = false





var reviving_target:Node = null
var revive_progress:float = 0.0
export var revive_hold_duration:float = 10  # seconds of holding to reach 100
export var revive_heal_percent:float = 0.3
var reviving_target_active := false
onready var party:Control = $UI/Party  # NEW

func isPartyMember(target:Node) -> bool:  # NEW
	if !is_instance_valid(party) or !("entity_name" in target):
		return false
	for member in party.party_members:
		if member.get("entity_name", "") == target.entity_name:
			return true
	return false

func detectDownedPlayer() -> void:
	if is_downed == true or stats.health <= 0:
		return
	reviving_target_active = false

	var key = InputMap.get_action_list("Harvest")[0].as_text().replace(" (Physical)","").replace(" (physical)","")
	var found_target = null

	for target in $"Turnable/Bash".get_overlapping_bodies():
		if !is_instance_valid(target) or target == self:
			continue
		if !target.is_in_group("Player"):
			continue
		var target_stats = target.stats
		if !is_instance_valid(target_stats):
			continue
		if target_stats.health <= 0:
			found_target = target
			break

	if found_target == null:
		cancelRevive()
		return

	reviving_target_active = true

	if reviving_target != found_target:
		cancelRevive()
		reviving_target = found_target
		reviving_target_active = true

	label.visible = true

	if Input.is_action_pressed("Harvest"):
		prog_texture.visible = true
		label.text = "Reviving..."
		var speed_multiplier = 4.0 if isPartyMember(found_target) else 1.0
		revive_progress = min(revive_progress + get_physics_process_delta_time() * (100.0 / revive_hold_duration) * speed_multiplier, 100.0)
		prog_texture.value = revive_progress

		if revive_progress >= 100.0:
			performRevive(found_target)
	else:
		prog_texture.visible = false
		label.text = "Hold " + key + " to help"
		revive_progress = 0.0
		prog_texture.value = 0.0
func cancelRevive() -> void:
	reviving_target = null
	revive_progress = 0.0
	reviving_target_active = false
	if is_instance_valid(prog_texture):
		prog_texture.value = 0.0
		prog_texture.visible = false
		
	

func performRevive(target:Node) -> void:
	cancelRevive()
	var target_stats = target.get_node_or_null("Stats")
	if is_instance_valid(target_stats):
		target_stats.reviveTarget(revive_heal_percent)









onready var crafting:Control = $UI/Crafting
onready var skill_tree_root:Control = $UI/SkillTreeRoot
onready var banner_system_control:Control = $UI/BannerSystem
onready var auction_house_control:Control =$UI/AuctionHouse
var _last_processed_visual_frame_player:int = -1
var _accumulated_delta_player:float = 0.0
func _physics_process(delta) -> void:
	playerPhyProcess(delta)
var _last_processed_visual_frame_master:int = -1
var _accumulated_delta_master:float = 0.0

func playerPhyProcess(delta)->void: #EXISTS only to profile ms cost
	if isLocalPlayer():
		_accumulated_delta_master += delta
		var visual_frame_m:int = Engine.get_frames_drawn()
		if visual_frame_m == _last_processed_visual_frame_master:
			return
		_last_processed_visual_frame_master = visual_frame_m
		var frame_delta:float = _accumulated_delta_master
		_accumulated_delta_master = 0.0

		physicsProcessMaster(frame_delta)
		if shouldAnimateLocally():
			animationOrder(frame_delta)
	else:
		_physics_process_puppet(delta)
		_accumulated_delta_player += delta
		var visual_frame:int = Engine.get_frames_drawn()
		var is_new_visual_frame:bool = visual_frame != _last_processed_visual_frame_player
		_last_processed_visual_frame_player = visual_frame
		if is_new_visual_frame:
			var animation_delta:float = _accumulated_delta_player
			_accumulated_delta_player = 0.0
			if shouldAnimateLocally():
				animationOrder(animation_delta)
	safetyStuff()
	collisionShapesManager()


var frame_scale_smooth_time:float = 0.12
var _last_processed_visual_frame:int = -1
var _accumulated_master_delta:float = 0.0
var _current_frame_scale:float = 1.0
func physicsProcessMaster(delta) -> void:
	if _player_frame_offset == -1:
		_player_frame_offset = int(get_instance_id() % 60)



	buoyancy(delta)
	if current_skill != "" and current_skill != "none":
		rootMotion(delta)
	if anim_locks["stunned"] == false and anim_locks["staggered"] == false and is_dead == false:
		jump()
		movement(delta)
	physics(delta)
	forceMovementAnimUnlock()
	checkSkillHardDeadline()
	checkFall()
	_syncToPuppets(delta)
	detectDownedPlayer()
	var frame:int = Engine.get_physics_frames() + _player_frame_offset
	if !reviving_target_active:
		detectGathering()
		detectObjects()	
	if frame % 6 == 0:
		dodgeCollisions(delta * 6)
		if stats.health <= 0:
			skillbar.combo_queue = 0
			skillbar.continue_combo_atk = false
			anim_locks["combo attack"] = false
	if frame % 18 == 0:
		if is_instance_valid(crossair_inspect) and crossair_inspect.has_method("crossairInspect"):
			crossair_inspect.crossairInspect(self)
	checkGroundedStuck(delta)
	if frame % 35 == 0:
		if loot.visible == true:
			if movement_mode != "idle":
				loot.hide()
				
	if frame % 60 == 0:
		respawnSystem()
		updateBeingRevivedUI()
	if current_skill == "mine" or current_skill == "chop" or current_skill == "gather":
		if !chat.line_edit.has_focus():
			if Input.is_action_pressed("forward") or Input.is_action_pressed("backward") or Input.is_action_pressed("left") or Input.is_action_pressed("right"):
				current_skill = ""
				anim_calls.unlockAnim()

	if Input.is_action_just_pressed("debug"):
		if is_writing == false and is_chatting == false:
			reportAllBotCoordinates()
	if Input.is_action_just_pressed("respawn"):
		world.respawnToNearestGraveyard()
	if Input.is_action_just_pressed("unstuck"):
		unstuckPlayer()
	if Input.is_action_just_pressed("skills"):
		skill_tree_root.visible = !skill_tree_root.visible
		inventory.visible = false
		equipment.visible = false

#previous 
#func physics(delta):
#	if root_motion_active and current_skill != "" and current_skill != "none":
#		if is_in_water:
#			translation.y += vertical_velocity.y * get_physics_process_delta_time()
#
#			movement.x = horizontal_velocity.x
#			movement.y = 0
#			movement.z = horizontal_velocity.z
#
#			move_and_slide(
#				movement,
#				Vector3.ZERO,
#				false,
#				4,
#				PI,
#				false
#			)
#		else:
#			vertical_velocity = move_and_slide(
#				vertical_velocity,
#				Vector3.ZERO,
#				false,
#				4,
#				PI,
#				false
#			)
#		return
#
#	elif root_motion_active:
#		root_motion_active = false
#
#	if is_dashing:
#		dash_time += delta
#		dash_timer -= delta
#
#		var dash_dir = direction.normalized()
#
#		if dash_phase == 0:
#			dash_current_speed = dash_start_speed
#			if dash_time >= dash_start_delay:
#				dash_phase = 1
#				dash_time = 0.0
#
#		elif dash_phase == 1:
#			dash_current_speed = dash_start_speed
#			if dash_time >= 0.05:
#				dash_phase = 2
#				dash_time = 0.0
#
#		elif dash_phase == 2:
#			dash_current_speed = lerp(
#				dash_current_speed,
#				dash_max_power,
#				12.0 * delta
#			)
#
#		horizontal_velocity = dash_dir * dash_current_speed
#
#		if dash_timer <= 0.0:
#			is_dashing = false
#			dash_phase = 0
#			dash_turn_multiplier = 1.0
#
#	else:
#		if direction == Vector3.ZERO:
#			horizontal_velocity = Vector3.ZERO
#		else:
#			horizontal_velocity = horizontal_velocity.linear_interpolate(
#				direction.normalized() * movement_speed,
#				clamp(acceleration * delta, 0.0, 1.0)
#			)
#
#	# ---- GRAVITY ----
#	# This was missing entirely. Without a downward vertical_velocity
#	# constantly pushing the body into the floor collider, is_on_floor()
#	# never reliably returns true, which is why jump() (which requires
#	# is_on_floor() == true) never fired.
#	if is_on_floor():
#		if vertical_velocity.y <= 0.0:
#			vertical_velocity.y = -1.0  # re-press into floor only when NOT mid-jump this frame
#	else:
#		vertical_velocity.y -= gravity * delta
#
#	movement.x = horizontal_velocity.x
#	movement.y = vertical_velocity.y
#	movement.z = horizontal_velocity.z
#
#	if on_platform and is_instance_valid(platform):
#		var basis = platform.global_transform.basis
#		var local_move = Vector3(horizontal_velocity.dot(basis.x),0,-horizontal_velocity.dot(basis.z)) * delta
#		platform_local.origin += local_move
#		if !is_in_water:
#			platform_local.origin.y += vertical_velocity.y * delta
#		global_transform = platform.global_transform * platform_local
#		var plat_result = move_and_slide(Vector3(0, movement.y, 0),Vector3.UP)
#		vertical_velocity.y = plat_result.y
#		platform_local.origin.y = platform.to_local(global_transform.origin).y
#		if !is_on_floor():
#			on_platform = false
#			platform = null
#		return
#	if is_in_water:
#		translation.y += vertical_velocity.y * get_physics_process_delta_time()
#		movement.x = horizontal_velocity.x
#		movement.y = 0
#		movement.z = horizontal_velocity.z
#		move_and_slide(movement,Vector3.ZERO,false,4,PI,false)
#	else:
#		movement = move_and_slide(Vector3(horizontal_velocity.x,vertical_velocity.y,horizontal_velocity.z),Vector3.UP,true, 4,PI/4,true)
#		vertical_velocity.y = movement.y
#
func physics(delta):
	var physics_dt:float = get_physics_process_delta_time()
	var move_scale:float = (delta / physics_dt) if physics_dt > 0.0 else 1.0

	if root_motion_active and current_skill != "" and current_skill != "none":
		if is_in_water:
			translation.y += vertical_velocity.y * delta

			movement.x = horizontal_velocity.x
			movement.y = 0
			movement.z = horizontal_velocity.z

			move_and_slide(
				movement * move_scale,
				Vector3.ZERO,
				false,
				4,
				PI,
				false
			)
		else:
			var rm_result = move_and_slide(
				vertical_velocity * move_scale,
				Vector3.ZERO,
				false,
				4,
				PI,
				false
			)
			vertical_velocity = (rm_result / move_scale) if move_scale > 0.0 else rm_result
		return

	elif root_motion_active:
		root_motion_active = false

	if is_dashing:
		dash_time += delta
		dash_timer -= delta

		var dash_dir = direction.normalized()

		if dash_phase == 0:
			dash_current_speed = dash_start_speed
			if dash_time >= dash_start_delay:
				dash_phase = 1
				dash_time = 0.0

		elif dash_phase == 1:
			dash_current_speed = dash_start_speed
			if dash_time >= 0.05:
				dash_phase = 2
				dash_time = 0.0

		elif dash_phase == 2:
			dash_current_speed = lerp(
				dash_current_speed,
				dash_max_power,
				12.0 * delta
			)

		horizontal_velocity = dash_dir * dash_current_speed

		if dash_timer <= 0.0:
			is_dashing = false
			dash_phase = 0
			dash_turn_multiplier = 1.0

	else:
		if direction == Vector3.ZERO:
			horizontal_velocity = Vector3.ZERO
		else:
			horizontal_velocity = horizontal_velocity.linear_interpolate(
				direction.normalized() * movement_speed,
				clamp(acceleration * delta, 0.0, 1.0)
			)

	# ---- GRAVITY ----
	if is_on_floor():
		if vertical_velocity.y <= 0.0:
			vertical_velocity.y = -1.0
	else:
		vertical_velocity.y -= gravity * delta

	movement.x = horizontal_velocity.x
	movement.y = vertical_velocity.y
	movement.z = horizontal_velocity.z

	if on_platform and is_instance_valid(platform):
		var basis = platform.global_transform.basis
		var local_move = Vector3(horizontal_velocity.dot(basis.x),0,-horizontal_velocity.dot(basis.z)) * delta
		platform_local.origin += local_move
		if !is_in_water:
			platform_local.origin.y += vertical_velocity.y * delta
		global_transform = platform.global_transform * platform_local
		var plat_result = move_and_slide(Vector3(0, movement.y, 0) * move_scale,Vector3.UP)
		vertical_velocity.y = (plat_result.y / move_scale) if move_scale > 0.0 else plat_result.y
		platform_local.origin.y = platform.to_local(global_transform.origin).y
		if !is_on_floor():
			on_platform = false
			platform = null
		return
	if is_in_water:
		translation.y += vertical_velocity.y * delta
		movement.x = horizontal_velocity.x
		movement.y = 0
		movement.z = horizontal_velocity.z
		move_and_slide(movement * move_scale,Vector3.ZERO,false,4,PI,false)
	else:
		var result = move_and_slide(Vector3(horizontal_velocity.x,vertical_velocity.y,horizontal_velocity.z) * move_scale,Vector3.UP,true, 4,PI/4,true)
		movement = (result / move_scale) if move_scale > 0.0 else result
		vertical_velocity.y = movement.y




func _physics_process_puppet(delta) -> void:
	_applyPuppetState(delta)
	_enforceNonLocalPresentation()
	_enforcePuppetVisibility()
	if (Engine.get_physics_frames() + _player_frame_offset) % 4 == 0:
		 Global.updatePosition(self)
func _enforcePuppetVisibility() -> void:
	if is_suspended:
		return
	if !visible:
		visible = true
	if !is_physics_processing():
		set_physics_process(true)
	if is_instance_valid(fullbody_collision) and fullbody_collision.disabled:
		fullbody_collision.disabled = false
	if is_instance_valid(upper_body_collision) and upper_body_collision.disabled:
		upper_body_collision.disabled = false
	if is_instance_valid(lower_body_collision) and lower_body_collision.disabled:
		lower_body_collision.disabled = false















func _enforceNonLocalPresentation() -> void:
	# Belt-and-suspenders against the race (seen specifically under lag)
	# where a remote player's camera briefly becomes the active viewport
	# camera, or their UI is briefly visible, on someone else's screen.
	# Cheap, and makes the wrong state self-correct within a single frame
	# no matter what caused it.
	if ui_holder.visible:
		ui_holder.visible = false
	if is_instance_valid(camroot):
		var cam = camroot.get_node_or_null("h/v/Camera")
		if is_instance_valid(cam) and cam.current:
			cam.current = false

func _input(event):
	if !isLocalPlayer():
		return
	if event.is_action_pressed("Esc"):
		is_writing = false
		is_chatting = false
		crafting.line_edit.release_focus()
		chat.line_edit.release_focus()







var moving:bool = false
var movement_mode:String = "idle"
var previous_movement_mode:String = "idle"
var effective_turn_speed:float 


	
onready var fullbody_collision=$CollisionShape
onready var upper_body_collision=$CollisionUP
onready var lower_body_collision=$CollisionDown
var _last_crouching_state := false
var _collision_shapes_initialized := false

func collisionShapesManager()->void:
	var crouching = movement_mode=="crouch_idle" or movement_mode=="crouch_moving"

	if _collision_shapes_initialized and crouching == _last_crouching_state:
		return
	_collision_shapes_initialized = true
	_last_crouching_state = crouching

	fullbody_collision.disabled=crouching
	upper_body_collision.disabled=crouching
	lower_body_collision.disabled=!crouching

export var dead_phase_check_interval:int = 15

var dead_phase_entities:Array = []
export var dead_phase_rescan_interval:int = 240 # ~4s @60fps, full rescan, catches late-loaded mobs/players
var _dead_phase_rescan_frame:int = -999999

func rescanDeadPhaseEntities() -> void:
	dead_phase_entities.clear()
	var world = get_parent()
	if !is_instance_valid(world) or !world.has_method("getAllEntities"):
		return
	for e in world.getAllEntities():
		if is_instance_valid(e) and e != self:
			dead_phase_entities.append(e)





var movement_unlock_locks = [
#	"parry",
#	"guard",
]
func clearMovementLocks()->void:
	for lock_name in movement_unlock_locks:
		if anim_locks.has(lock_name):
			anim_locks[lock_name] = false

var animation_almost_finished:bool = false
var is_chatting:bool = false
func forceRotationTowardsTarget(target)->void:
	if !is_instance_valid(self) or !is_instance_valid(player_mesh) or !is_instance_valid(turnable):
		return
	if target==null:
		return

	var pos
	if target is Spatial:
		if !is_instance_valid(target):
			return
		pos=target.global_transform.origin
	elif target is Vector3:
		pos=target
	else:
		return

	var dir=pos-global_transform.origin
	dir.y=0
	if dir.length_squared()==0:
		return

	var rot=atan2(dir.x,dir.z)-rotation.y
	player_mesh.rotation.y=rot
	turnable.rotation.y=rot
var is_writing:bool= false
func movement(delta) -> void:
	if is_writing == true:
		return
	if stats.debuff_buffs_active.has("stunned") and float(stats.debuff_buffs_active["stunned"].get("duration",0.0)) > 0.0:
		return
	if is_chatting == true:
		return 
	if OS.get_ticks_msec() < revive_lock_until_ms:
		movement_mode = "idle"
		moving = false
		direction = Vector3.ZERO
		return
	# ==================================================
	# TURN SPEED HANDLING (combat overrides)
	# ==================================================
	effective_turn_speed = base_turn_speed
	
	# Attacking or guarding slows turn rate (or dash modifies it)
	if guarding or attacking:
		effective_turn_speed = stats.derived_stats["atk_turn_speed"] if !is_dashing else base_turn_speed * stats.derived_stats["dash_turn_speed"]
	elif is_dashing:
		effective_turn_speed = base_turn_speed * stats.derived_stats["dash_turn_speed"] * 20

	# ==================================================
	# RESET / INITIAL STATE
	# ==================================================
	previous_movement_mode = movement_mode
	movement_mode = "idle"
	if previous_movement_mode == "run":
		current_run_time += delta
	else:
		current_run_time = 0.0
	var input_direction = Vector3.ZERO

	# ==================================================
	# INPUT COLLECTION
	# ==================================================
	if can_move or !guarding:
		if Input.is_action_pressed("left") and !is_climbing:
			anim_locks["downed"] = false
			if anim_locks["guard"] == false:
				animation_tree.active = true
				input_direction.x += 1
		elif Input.is_action_pressed("right") and !is_climbing:
			anim_locks["downed"] = false
			if anim_locks["guard"] == false:
				animation_tree.active = true
				input_direction.x -= 1
		if Input.is_action_pressed("forward"):
			anim_locks["downed"] = false
			if anim_locks["guard"] == false:
				animation_tree.active = true
				input_direction.z += 1
			
		elif Input.is_action_pressed("backward"):
			anim_locks["downed"] = false
			if anim_locks["guard"] == false:
				animation_tree.active = true
				input_direction.z -= 1

	var movement_input = input_direction.length() > 0
	if current_skill != "" and current_skill != "none":
		if !Global.canRotateDuringSkill(current_skill):
			input_direction = Vector3.ZERO
			movement_input = false
	var crouching = Input.is_action_pressed("crouch") and inventory.shop.visible == false
	var sprinting = Input.is_action_pressed("sprint") and !crouching
		
	# ==================================================
	# INPUT-BASED ANIM LOCK CLEAR (requested change)
	# ==================================================
	if movement_input:
		# movement cancels these locks immediately
		clearMovementLocks()


	# ==================================================
	# STOP RUN TRIGGER LOGIC
	# ==================================================
#	if anim_locks["stop_run"] and movement_input:
#		activateAnimLock("stop_run")

	# ==================================================
	# GLOBAL LOCK CHECK (prevents movement override)
	# ==================================================
	var locked = false
	for anim_name in anim_locks.keys():
		if anim_name != "stop_run" and anim_locks[anim_name]:
			locked = true
			break

	# ==================================================
	# CAMERA-RELATIVE DIRECTION
	# ==================================================
	var h_rot = camera_v.global_transform.basis.get_euler().y

	movement_speed = 0
	moving = false

	if movement_input:
		direction = input_direction.rotated(Vector3.UP, h_rot).normalized()
	else:
		direction = Vector3.ZERO

	# ==================================================
	# MOVEMENT STATE MACHINE
	# ==================================================
	if !locked:
		if direction != Vector3.ZERO:
			moving = true
			if crouching:
				movement_mode = "crouch_moving"
				movement_speed = stats.walk_speed * 0.5
				is_in_combat = false
				
				animation_tree.active = true

			elif sprinting and !is_in_water and stats.health >0:
				var t = clamp(current_run_time / run_ramp_time, 0.0, 1.0)
				var speed_multiplier = lerp(1.0, run_max_speed_multiplier, t)
				movement_speed = stats.run_speed * speed_multiplier
				movement_mode = "run"
				animation_tree.active = true

			else:
				movement_mode = "walk"
				movement_speed = stats.walk_speed

				# leaving sprint triggers stop_run lock
				if previous_movement_mode == "run":
					pass
					#anim_locks["stop_run"] = true

		else:
			if crouching :
				movement_mode = "crouch_idle"
				animation_tree.active = true
				is_in_combat = false
			else:
				movement_mode = "idle"

			if previous_movement_mode == "run":
				pass
			#	anim_locks["stop_run"] = true

	else:
		moving = false
		movement_mode = "idle"
		movement_speed = 0

	# ==================================================
	# MOVEMENT MODIFIERS
	# ==================================================
	if is_carrying:
		movement_speed *= 0.7

	if is_in_combat:
		movement_speed *= 0.65

	if attacking:
		movement_speed *= 0.38
	if stats.health<=0:
		is_in_combat = false
		movement_speed *= 0.07

	# ==================================================
	# WATER OVERRIDE STATE
	# ==================================================
	if is_in_water == true:
		animation_tree.active = true
		if moving:
			movement_mode = "swimming"
			movement_speed = stats.derived_stats["swim_speed"]
		else:
			movement_mode = "treading water"

	# ==================================================
	# ROTATION HANDLING
	# ==================================================
	var can_rotate = true

	if current_skill != "":
		can_rotate = Global.skill_rotation_allowed.get(current_skill, false)

	if is_instance_valid(player_mesh) and is_instance_valid(turnable):
		if Global.isRanged(current_skill):
			player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, camera_h.rotation.y, delta * angular_acceleration)

		elif can_rotate:
			for anim_name in anim_locks:
				if anim_locks[anim_name] and !Global.skill_rotation_allowed.get(anim_name,false):
					can_rotate=false
					break

			if anim_locks.has("guard") and anim_locks["guard"] or current_skill=="guard" or anim_locks.has("guard react") and anim_locks["guard react"] or current_skill=="guard react":
				pass
			elif can_rotate and !is_climbing and direction!=Vector3.ZERO:
				var target_rot=atan2(direction.x,direction.z)-rotation.y
				player_mesh.rotation.y=lerp_angle(player_mesh.rotation.y,target_rot,delta*angular_acceleration)
				turnable.rotation.y=lerp_angle(turnable.rotation.y,target_rot,delta*angular_acceleration)
func forceMovementAnimUnlock()->void:
	if animation_almost_finished == true:
		if Input.is_action_pressed("sprint"):
			var has_lock = false
			for lock_name in anim_locks:
				if anim_locks[lock_name]:
					has_lock = true
			if has_lock == true:
				anim_calls.unlockAnim()
				animation_almost_finished = false
			else:
				animation_almost_finished = false



var is_dashing:bool = false
var dash_timer:float = 0.0
var dash_duration:float = 0.3
var dash_velocity:Vector3 = Vector3.ZERO
var dash_falloff:float = 12.0
var dash_current_speed:float = 0.0
var dash_max_power:float = 50.0
var dash_accel:float = 10.0
var dash_start_delay:float = 0.06
var dash_time:float = 0.0

var dash_phase:int = 0
# 0 = startup (10%)
# 1 = delay
# 2 = acceleration
var base_turn_speed:float = 4.4
export var run_ramp_time:float = 4.0        # seconds of continuous running to hit max speed
export var run_max_speed_multiplier:float = 1.8  # cap: 1.5x = 50% faster at full ramp
var current_run_time:float = 0.0
var dash_turn_multiplier:float = 10
var dash_start_speed:float = 0.0




var last_dash_input = ""
var last_dash_time = 0.0
var dash_double_press_time = 0.15
func dash()->void:
	if anim_locks.get("get up", false):
		return
	var current_input = ""
	if Input.is_action_just_pressed("forward"):
		current_input = "forward"
	elif Input.is_action_just_pressed("backward"):
		current_input = "backward"
	elif Input.is_action_just_pressed("left"):
		current_input = "left"
	elif Input.is_action_just_pressed("right"):
		current_input = "right"
	if current_input == "":
		return
	var time = OS.get_ticks_msec() / 1000.0
	if current_input == last_dash_input and time - last_dash_time <= dash_double_press_time:
		activateAnimLock("dodge")

		guarding =false
		last_dash_input = ""
		last_dash_time = 0
	else:
		last_dash_input = current_input
		last_dash_time = time


func enableEntityCollisions()->void:
	if cached_entities.empty():
		cacheEntities()
	for body in cached_entities:
		if !is_instance_valid(body) or body == self:
			continue
		remove_collision_exception_with(body)
		body.remove_collision_exception_with(self)

func unlockAnim():
	for key in anim_locks:
		anim_locks[key] = false
	current_skill = ""
	root_motion_active = false
	if !_collisions_are_enabled:
		enableEntityCollisions()
		_collisions_are_enabled = true
	animation_tree.active = false
	last_active_skill = ""
	stats.charged_attack_stacks["obliteration"]["stacks"] = 0


var guarding:bool = false
var attacking:bool = false
var is_in_combat:bool = false
onready var stored_body:KinematicBody = null
var stored_body_timer:int = 15


onready var left_ray:RayCast = $Turnable/Left
onready var right_ray:RayCast = $Turnable/Right
onready var ground_raycast:RayCast = $GroudnCheck
var climbing_is_enabled:bool = true


var is_wall_in_range:bool = false
func checkWallInclination()-> void:
	if get_slide_count() > 0:
		var collision_info = get_slide_collision(0)
		var normal = collision_info.normal
		if normal.length_squared() > 0:
			wall_incline = acos(normal.y)  # Calculate the inclination angle in radians
			wall_incline = rad2deg(wall_incline)  # Convert inclination angle to degrees
			if normal.x < 0:
				wall_incline = -wall_incline
			# Check if the wall inclination is within the specified range 
			is_wall_in_range = (wall_incline >= -60 and wall_incline <= 60)
		else:
			wall_incline = 0  # Set to 0 if the normal is not valid
			is_wall_in_range = false
	else:
		wall_incline = 0  # Set to 0 if there is no collision
		is_wall_in_range = false


func jump()->void:
	var has_lock = false
	for lock_name in anim_locks:
		if anim_locks[lock_name]:
			has_lock = true
			
	if has_lock == false:
		if stats.health >=1:
			if cursor_visible == false:
				if Input.is_action_just_pressed("jump") and is_on_floor():
					vertical_velocity = Vector3.UP * stats.derived_stats["jump_power"]
					setAnimRaw("parameters/WaterLandAir/blend_amount",air)
					setAnimRaw("parameters/ClimbingOrFalling/blend_amount",falling)
					is_in_combat = false
					airborne_delay = 0.0
					is_airborne = true


	
var was_on_floor := true
var max_fall_speed := 0.0
var fall_start_y := 0.0
var is_falling := false
var highest_y:float = 0.0
var is_airborne:bool = false
var airborne_delay := 0.0

export var safe_fall_speed := 28.0
export var fall_damage_multiplier := 4
var fall_damage_grace_period := 0.0
export var fall_damage_grace_time := 15
func disableFallDamage():
	fall_damage_grace_period = fall_damage_grace_time
	is_airborne = false
	was_on_floor = true
	highest_y = global_transform.origin.y
	
	
var airborne_coyote_time := 0.12 # grace window before a single is_on_floor() flicker commits to the fall animation
var airborne_stuck_timer := 0.0
var airborne_stuck_timeout := 1.5 # seconds "airborne" with near-zero vertical speed before we force a landing
var _airborne_confirm_counter:int = 0
var airborne_confirm_frames:int = 12   # must be not-on-floor this many CONSECUTIVE physics ticks before we commit to "falling" -- kills walk/fall flicker on bumpy flat ground
var _spawn_floor_snap_done := false
func checkFall():
	# Unified floor determination used consistently through the whole
	# function -- previously the very first grounded check only trusted
	# ground_raycast, while the debounce logic further down only trusted
	# $DistanceToFloordRay, so a bump/seam that one ray caught and the
	# other missed produced two different answers about whether the
	# player was grounded within the SAME tick. That mismatch is what let
	# a single-frame raycast gap slip past the debounce and flicker the
	# walk/fall animation on otherwise flat ground. Both rays now count
	# as confirmation, computed once, reused everywhere below.
	var on_floor := is_on_floor()
	if !on_floor and vertical_velocity.y <= 0.0:
		if is_instance_valid(ground_raycast) and ground_raycast.is_colliding():
			on_floor = true
		elif is_instance_valid($DistanceToFloordRay) and $DistanceToFloordRay.is_colliding():
			on_floor = true

	if on_floor:
		is_airborne = false
		_airborne_confirm_counter = 0
		setAnimRaw("parameters/WaterLandAir/blend_amount",land)
		setAnimRaw("parameters/ClimbingOrFalling/blend_amount",falling)

	if on_platform and is_instance_valid(platform):
		return
	if fall_damage_grace_period > 0.0:
		fall_damage_grace_period -= get_physics_process_delta_time()
		was_on_floor = on_floor
		_airborne_confirm_counter = 0
		highest_y = global_transform.origin.y
		return
	if is_in_water:
		is_airborne = false
		_airborne_confirm_counter = 0
		airborne_delay = 0.0
		return

	if on_floor:
		_airborne_confirm_counter = 0
	else:
		if _airborne_confirm_counter == 0:
			highest_y = global_transform.origin.y
		_airborne_confirm_counter += 1

	var confirmed_airborne:bool = _airborne_confirm_counter >= airborne_confirm_frames

	# Left ground (debounced -- only commits after sustained not-on-floor)
	if confirmed_airborne and !is_airborne:
		is_in_combat = false

		if Input.is_action_pressed("sprint"):
			airborne_delay = 0.3
			is_airborne = false
		else:
			airborne_delay = 0.0
			is_airborne = true

	if is_airborne and !is_climbing:
		movement_mode = "fall"

	# Track highest point
	if !on_floor:
		highest_y = max(highest_y, global_transform.origin.y)
		animation_tree.active = true

	# Landed
	if !was_on_floor and on_floor:
		airborne_delay = 0.0

		if is_airborne:
			var landing_y = global_transform.origin.y
			var fall_distance = highest_y - landing_y

			if !attacking and (current_skill == "" or current_skill == "none"):
				applyFallDamage(fall_distance)

		is_airborne = false
		_airborne_confirm_counter = 0

	was_on_floor = on_floor

	if is_airborne and abs(vertical_velocity.y) < 0.5 and !is_climbing:
		airborne_stuck_timer += get_physics_process_delta_time()
		if airborne_stuck_timer >= airborne_stuck_timeout:
			is_airborne = false
			airborne_delay = 0.0
			airborne_stuck_timer = 0.0
	else:
		airborne_stuck_timer = 0.0

	if is_airborne == true:
		setAnimRaw("parameters/WaterLandAir/blend_amount",air)
		setAnimRaw("parameters/ClimbingOrFalling/blend_amount",falling)

	checkStuckBetweenCollisions()




var stuck_frame_count:int = 0
var stuck_check_delay:float = 0.0

var stuck_last_y:float = 0.0
var stuck_tracking:bool = false
var max_stuck_frames:int = 30
var floor_transition_count:int = 0
var floor_transition_timer:float = 0.0
var last_on_floor_state:bool = true

func checkStuckBetweenCollisions()->void:
	var delta:float = get_physics_process_delta_time()
	var on_floor := is_on_floor()

	# Track how often the floor state flips — rapid flickering
	# between grounded/airborne means we're wedged between colliders.
	floor_transition_timer += delta
	if on_floor != last_on_floor_state:
		floor_transition_count += 1
		last_on_floor_state = on_floor

	var flickering := false
	if floor_transition_timer >= 1.0:
		flickering = floor_transition_count > 120
		floor_transition_count = 0
		floor_transition_timer = 0.0

	# Track vertical stall while airborne
	if is_airborne and !on_floor and !is_climbing:
		if !stuck_tracking:
			stuck_tracking = true
			stuck_last_y = global_transform.origin.y
			stuck_frame_count = 0
		else:
			if abs(global_transform.origin.y - stuck_last_y) < 0.01:
				stuck_frame_count += 1
			else:
				stuck_frame_count = 0
			stuck_last_y = global_transform.origin.y
	else:
		stuck_tracking = false
		stuck_frame_count = 0

	if stuck_frame_count > max_stuck_frames or flickering:
		unstuckPlayer()

func unstuckPlayer()->void:
	var delta:float = get_physics_process_delta_time()

	translation.y += 2.0
	var back_dir:Vector3 = -player_mesh.global_transform.basis.z.normalized()
	var back_velocity:Vector3 = back_dir * (1.0 / delta)
	move_and_slide(back_velocity, Vector3.UP)

	vertical_velocity.y = 0.0
	stuck_frame_count = 0
	stuck_tracking = false
	floor_transition_count = 0
	floor_transition_timer = 0.0

	var messages = [
		entity_name + " wrenches free from the rocks",
		entity_name + " breaks loose with a grunt",
		entity_name + " shoves free and scrambles clear",
		entity_name + " pulls themselves out of the crevice"
	]
	chat.sendSystemMessage(messages[randi() % messages.size()])

# ===== Player.gd — grounded stuck detection =====
var stuck_grounded_timer := 0.0
export var stuck_grounded_threshold := 0.5      # seconds of held input with no displacement before triggering
export var stuck_grounded_min_move_distance := 0.03
var stuck_grounded_last_pos := Vector3.ZERO
var stuck_grounded_cooldown := 0.0
export var stuck_grounded_cooldown_time := 3.0
export var stuck_grounded_nudge_distance := 1.2

func checkGroundedStuck(delta:float) -> void:
	if !isLocalPlayer():
		return

	if stuck_grounded_cooldown > 0.0:
		stuck_grounded_cooldown -= delta

	if !is_on_floor() or is_airborne or is_climbing or is_in_water:
		stuck_grounded_timer = 0.0
		stuck_grounded_last_pos = global_transform.origin
		return

	if is_on_wall():
		stuck_grounded_timer = 0.0
		stuck_grounded_last_pos = global_transform.origin
		return

	var trying_to_move = moving and direction.length_squared() > 0.01

	if !trying_to_move:
		stuck_grounded_timer = 0.0
		stuck_grounded_last_pos = global_transform.origin
		return

	if global_transform.origin.distance_to(stuck_grounded_last_pos) > stuck_grounded_min_move_distance:
		stuck_grounded_timer = 0.0
		stuck_grounded_last_pos = global_transform.origin
		return

	stuck_grounded_timer += delta

	if stuck_grounded_timer >= stuck_grounded_threshold and stuck_grounded_cooldown <= 0.0:
		_performGroundedUnstuck()
		stuck_grounded_timer = 0.0
		stuck_grounded_last_pos = global_transform.origin
		stuck_grounded_cooldown = stuck_grounded_cooldown_time

func _performGroundedUnstuck() -> void:
	var forward_dir:Vector3 = direction.normalized()
	if forward_dir == Vector3.ZERO and is_instance_valid(player_mesh):
		forward_dir = -player_mesh.global_transform.basis.z.normalized()
	if forward_dir == Vector3.ZERO:
		return

	# tiny lift clears zero-height internal-edge ridges before the push
	translation.y += 0.05
	move_and_collide(forward_dir * stuck_grounded_nudge_distance)
	vertical_velocity.y = 0.0

	if is_instance_valid(chat):
		chat.sendSystemMessage(entity_name + " breaks free from an invisible snag")


onready var chat:Control = $UI/Chat

export var minimum_fall_distance := 3.0
export var base_fall_damage_multiplier := 3
export var base_fall_resistance := 1.0

func applyFallDamage(fall_distance: float):
	if fall_damage_grace_period > 0.0:
		return
	if fall_distance < stats.derived_stats["jump_power"]:
		return

	var damage := int(max(0.0, round(((fall_distance - minimum_fall_distance) * base_fall_damage_multiplier) / (base_fall_resistance + stats.derived_stats["fall_resistance"]) - stats.derived_stats["jump_power"])))

	if damage <= 0:
		return

	stats.applyFallDamage(damage)
	setAnimRaw("parameters/WaterLandAir/blend_amount",0)














var is_in_water:bool = false
var water_areas := []
var platform=null
var platform_local:=Transform()
var on_platform:=false













func isWaterArea(area) -> bool:
	var node = area
	while node:
		if node.is_in_group("Water") or node.is_in_group("water"):
			return true
		if node.name.to_lower() == "water":
			return true
		node = node.get_parent()
	return false

onready var water_level_area:Area = $WaterLevelChest
func enterDeepWaters(area_rid, area, area_shape_index, _local_shape_index):
	if isWaterArea(area):
		if !water_areas.has(area):
			water_areas.append(area)
		is_in_water = true
		is_in_combat = false
		stats.applyBuffDebuff("wrenched", self)


var water_exit_pending := false

func exitDeepWaters(area_rid, area, area_shape_index, _local_shape_index):
	if water_exit_pending:
		return

	water_exit_pending = true
	yield(get_tree().create_timer(2.0), "timeout")
	water_exit_pending = false

	var touching_floor = is_on_floor()

	if is_instance_valid($DistanceToFloordRay):
		touching_floor = touching_floor or $DistanceToFloordRay.is_colliding()

	if touching_floor:
		if water_areas.has(area):
			water_areas.erase(area)

		var valid_water_areas := []
		for water_area in water_areas:
			if is_instance_valid(water_area):
				valid_water_areas.append(water_area)

		water_areas = valid_water_areas
		is_in_water = water_areas.size() > 0


func getWaterSurfaceY(area: Area) -> float:
	var node = area

	while node:
		if node is MeshInstance and node.mesh is CubeMesh:
			var size = node.mesh.size
			return node.global_transform.origin.y + size.y * node.global_transform.basis.get_scale().y * 0.5
		node = node.get_parent()

	return area.global_transform.origin.y

func buoyancy(_delta) -> void:
	var valid_water_areas := []
	for water_area in water_areas:
		if is_instance_valid(water_area):
			valid_water_areas.append(water_area)

	water_areas = valid_water_areas

	if !is_in_water:
		return

	var chest_underwater = false
	for area in water_level_area.get_overlapping_areas():
		if isWaterArea(area):
			chest_underwater = true
			break

	var speed = stats.derived_stats["swim_speed"]
	var surface_offset = 1.35
	var can_go_up = false

	for area in water_areas:
		var water_surface_y = getWaterSurfaceY(area) + surface_offset

		if global_transform.origin.y < water_surface_y:
			can_go_up = true
			break

	# At water surface, jump exits water instead of swimming upward
	if Input.is_action_pressed("jump") and !chest_underwater:
		water_areas.clear()
		is_in_water = false
		return

	if Input.is_action_pressed("crouch"):
		vertical_velocity.y = -speed

	elif Input.is_action_pressed("jump") and can_go_up:
		vertical_velocity.y = speed

	elif chest_underwater and can_go_up:
		vertical_velocity.y = max(vertical_velocity.y, speed * 0.35)

	else:
		vertical_velocity.y = 0.0


var force_water_timer := 0.0

func forceWaterSwitch() -> void:
	if !is_instance_valid(water_level_area):
		return

	var chest_in_water := false

	for area in water_level_area.get_overlapping_areas():
		if isWaterArea(area):
			chest_in_water = true

			if !water_areas.has(area):
				water_areas.append(area)

	if chest_in_water:
		force_water_timer = 0.0
		is_in_water = true
	else:
		force_water_timer += 6.0 / float(Engine.iterations_per_second)

		if force_water_timer >= 1.0:
			if $DistanceToFloordRay.is_colliding():
				water_areas.clear()
				is_in_water = false













var _get_up_sequence_id := 0
var _last_get_up_start_ms := -100000
var downed_elapsed_time:float = 0.0
func startGetUpSequence() -> void:
	if !isLocalPlayer():
		return

	var now_ms := OS.get_ticks_msec()
	if now_ms - _last_get_up_start_ms < 800:
		return
	_last_get_up_start_ms = now_ms

	if current_skill == "get up" and anim_locks.get("get up", false):
		return


	_get_up_sequence_id += 1
	var my_sequence_id = _get_up_sequence_id

	for key in anim_locks:
		anim_locks[key] = false
	anim_locks["get up"] = true
	current_skill = "get up"
	last_active_skill = ""
	root_motion_active = false
	enableEntityCollisions()
	animation_tree.active = true

	var anim_length := 1.5
	if is_instance_valid(player_mesh):
		var anim_player = player_mesh.get_node_or_null("AnimationPlayer")
		if is_instance_valid(anim_player) and anim_player.has_animation("DownedEnd"):
			anim_length = anim_player.get_animation("DownedEnd").length

	var time_scale = 1.0
	if is_instance_valid(stats):
		time_scale = max(stats.derived_stats.get("attack_speed", 1.0), 0.01)

	yield(get_tree().create_timer((anim_length / time_scale) + 0.05), "timeout")

	if !is_instance_valid(self) or my_sequence_id != _get_up_sequence_id:
		return
	if current_skill != "get up":
		return

	anim_locks["get up"] = false
	current_skill = ""
var downed_elapsed_frames:int = 0
onready var world = get_parent()
func respawnSystem() -> void:
	if stats.health > 0:
		downed_elapsed_time = 0.0
		return

	downed_elapsed_time += 1
	var remaining:int = int(ceil(self_downed_autorespawn_time - downed_elapsed_time))
	if remaining < 0:
		remaining = 0

	if is_instance_valid(label):
		label.visible = true
		label.text = "Respawning in " + str(remaining) + "s"

	if downed_elapsed_time >= self_downed_autorespawn_time:
		world.respawnToNearestGraveyard()

	
	
	
func findRespawnCandidates(root=null, results=null) -> Array:
	if root == null: root = self
	if results == null: results = []
	for child in root.get_children():
		if !is_instance_valid(child): continue
		if child is Spatial:
			var n = child.name.to_lower().replace(" ", "").replace("_", "")
			if n.find("graveyard") != -1 or n.find("respawn") != -1:
				results.append(child)
		findRespawnCandidates(child, results)
	return results

func findNearestRespawnNode(from_position:Vector3) -> Spatial:
	var nearest = null
	var nearest_distance = INF
	for node in findRespawnCandidates():
		if !is_instance_valid(node): continue
		var d = from_position.distance_squared_to(node.global_transform.origin)
		if d < nearest_distance:
			nearest_distance = d
			nearest = node
	return nearest


var _respawning_to_graveyard := false




func reviveAfterRespawn() -> void:
	if !isLocalPlayer(): return
	unlockAnim()
	is_downed = false
	is_dead = false
	if is_instance_valid(stats):
		stats.respawnRestore()
	visible = true
	set_physics_process(true)
	if is_instance_valid(fullbody_collision): fullbody_collision.disabled = false
	if is_instance_valid(upper_body_collision): upper_body_collision.disabled = false
	if is_instance_valid(lower_body_collision): lower_body_collision.disabled = false
	if is_instance_valid(animation_tree): animation_tree.active = true












func safetyStuff()->void:
	if stats != null and !stats.statuses.has("stun"):
		if anim_locks["stunned"] or anim_locks["staggered"]:
			anim_locks["stunned"] = false
			anim_locks["staggered"] = false



var male_scene:PackedScene = preload("res://world/player/human/scenes/character_male.tscn")
var female_scene:PackedScene = preload("res://world/player/human/scenes/character_female.tscn")
var kragun_scene:PackedScene = preload("res://world/player/kragun/scenes/character_kragun.tscn")

func getCharacterScene(male:bool, race:String = "human") -> PackedScene:
	if race == "kragun":
		return kragun_scene
	if male:
		return male_scene
	return female_scene
func _on_SexChange_pressed():
	stats.sex="male" if stats.sex=="female" else "female"
	saveSex()
	$UI/Chat/SexChange.text=stats.sex
	ApplySex()
func saveSex():
	var path="user://button_list.save"
	var data={}
	var file=File.new()

	if file.file_exists(path):
		if file.open(path,File.READ)==OK:
			var loaded=file.get_var()
			file.close()
		Global.invalidateButtonListCache()

	if !data.has("buttons") or typeof(data.buttons)!=TYPE_ARRAY:
		data.buttons=[]
	if !data.has("sexes") or typeof(data.sexes)!=TYPE_DICTIONARY:
		data.sexes={}

	if data.buttons.find(entity_name)==-1:
		data.buttons.append(entity_name)

	data.sexes[entity_name]=stats.sex

	if file.open(path,File.WRITE)==OK:
		file.store_var(data)
		file.close()
func ApplySex():
	var packed_scene=getCharacterScene(stats.sex=="male", stats.species)
	if !packed_scene: return

	var old_character=$character
	var previous_transform=Transform()

	if is_instance_valid(old_character):
		previous_transform=old_character.transform
		old_character.get_parent().remove_child(old_character)
		old_character.queue_free()

	var new_character=packed_scene.instance()
	new_character.name="character"
	new_character.transform=previous_transform
	var krogun_scale = Global.krogun_scale
	new_character.scale=Vector3(krogun_scale,krogun_scale,krogun_scale) if stats.species=="kragun" else Vector3.ONE
	add_child(new_character)
	player_mesh=new_character
	character=new_character

	if animation_tree:
		var animation_player=new_character.get_node_or_null("AnimationPlayer")
		var root_bone=new_character.get_node_or_null("root/Skeleton/root")
		if animation_player:
			var ap_path:NodePath = animation_tree.get_path_to(animation_player)
			if animation_tree.has_method("set_animation_player"):
				animation_tree.call("set_animation_player",ap_path)
			else:
				setAnimRaw("anim_player",ap_path)
		if root_bone:
			setAnimRaw("root_motion_track", animation_tree.get_path_to(root_bone))

	equipment.forceReapplyEquipment()
	animation_tree.call_deferred("findAnimPlayer")
	$character/root/Skeleton/Mesh.hide()
	stats.applySpecies()
	stats.resetAttributePoints()
	call_deferred("loadBoneData")
	call_deferred("loadHairData")
	call_deferred("loadBlendShapeData")
	call_deferred("loadEyeData")








func _on_SexChange_mouse_entered():
	 $UI/Chat/SexChange.text = stats.sex
func saveData()->void:
	if !isLocalPlayer(): return
	if !is_instance_valid(self): return
	if !data_fully_loaded:
		return

	var world = get_parent()
	if is_instance_valid(world) and world.has_method("savePlayerStateFor"):
		world.savePlayerStateFor(self, gatherStateSnapshot())

	# button_list.save (sex/appearance) stays local on every machine --
	# it's read by the offline character-select screen (ButtonList.gd),
	# which only ever runs against its own user://.
	var button_list_path = "user://button_list.save"
	var button_data = Global.getButtonListData().duplicate(true)

	if !button_data.has("buttons") or typeof(button_data["buttons"]) != TYPE_ARRAY:
		button_data["buttons"] = []

	if !button_data.has("sexes") or typeof(button_data["sexes"]) != TYPE_DICTIONARY:
		button_data["sexes"] = {}

	if button_data["buttons"].find(entity_name) == -1:
		button_data["buttons"].append(entity_name)

	button_data["sexes"][entity_name] = stats.sex

	writeButtonListAtomic(button_list_path, button_data)
	Global.invalidateButtonListCache()


func writeButtonListAtomic(path:String, data:Dictionary) -> void:
	var tmp_path := path + ".tmp"
	var file := File.new()
	if file.open(tmp_path, File.WRITE) != OK:
		return
	file.store_var(data)
	file.close()

	var dir := Directory.new()
	if dir.file_exists(path):
		if dir.file_exists(path + ".bak"):
			dir.remove(path + ".bak")
		dir.rename(path, path + ".bak")
	dir.rename(tmp_path, path)
func gatherStateSnapshot() -> Dictionary:
	var current_world_id = "world"
	var parent = get_parent()
	if is_instance_valid(parent) and "world_id" in parent:
		current_world_id = parent.world_id

	var data = {
		"position": translation,
		"rotation": rotation,
		"direction": direction,
		"cursor_visible": cursor_visible,
		"which_scene": which_scene,
		"world_id": current_world_id
	}

	if is_instance_valid(character):
		data["character_rotation"] = character.rotation
	if is_instance_valid(turnable):
		data["turnable_rotation"] = turnable.rotation

	if is_instance_valid(camroot):
		data["camera_h_rotation"] = camroot.camrot_h
		data["camera_v_rotation"] = camroot.camrot_v
		var cam = camroot.get_node_or_null("h/v/Camera")
		if is_instance_valid(cam):
			data["camera_translation"] = cam.translation

	return data

# Actual disk write, shared by both the offline path and the server-side
# RPC handler below. Always writes to whatever user:// belongs to the
# machine executing this -- the local computer offline, the server
# computer online.
func _writePlayerDataLocal(char_name:String, data:Dictionary) -> void:
	var save_dir = "user://Characters/" + char_name + "/"
	var save_path = save_dir + "position_data.save"
	var dir = Directory.new()
	if !dir.dir_exists(save_dir):
		dir.make_dir_recursive(save_dir)

	var file = File.new()
	if file.open_encrypted_with_pass(save_path, File.WRITE, save_data_password) == OK:
		file.store_var(data)
		file.close()

# Server-side only: receives the local client's own save data and writes
# it to the SERVER's disk, not the client's.
remote func requestSavePlayerData(char_name:String, data:Dictionary) -> void:
	if !get_tree().is_network_server():
		return
	_writePlayerDataLocal(char_name, data)

# ===== Player.gd — add these new vars/functions (anywhere at top level) =====

var entity_ready := false
var _buffered_snapshot = null
var _buffered_snapshot_has_spawn_pos := false
var _buffered_spawn_pos = null

# The ONLY place that ever writes equipment/inventory/skillbar/stats/
# crafting/friends/state onto this node. If the pooled/reused node's own
# rebuild steps (inventory.reinitializeUI(), skillbar.reinitializeAsLocalPlayer(),
# hardResetForPool(), etc, all run inside reinitializeForEntity()) haven't
# finished yet, applying data now would just get wiped out the instant those
# rebuild steps run afterward -- that's the entire cause of "equipment
# survives (static TextureRects, nothing ever rebuilds them) but inventory/
# skillbar don't (their slot grids get rebuilt/duplicated AFTER data could
# have already landed)". Buffer instead, flush once truly ready.
func applyFullSnapshot(snapshot: Dictionary, has_spawn_pos: bool) -> void:
	if !entity_ready:
		_buffered_snapshot = snapshot
		_buffered_snapshot_has_spawn_pos = has_spawn_pos
		return
	_applyFullSnapshotNow(snapshot, has_spawn_pos)

# Same problem, same fix, for the authoritative spawn position. Setting
# global_transform.origin on a KinematicBody that was just reparented
# (pool -> world) races the physics server's own transform flush; on top
# of that, doing it before reinit has run leaves it vulnerable to being
# silently correct-but-invisible/frozen. Buffer until entity_ready.
func setAuthoritativeSpawnPosition(pos: Vector3) -> void:
	if !entity_ready:
		_buffered_spawn_pos = pos
		return
	global_transform.origin = pos
# ============================================================
# Player.gd — replace _applyFullSnapshotNow() in full
# ============================================================
func _applyFullSnapshotNow(snapshot: Dictionary, has_spawn_pos: bool) -> void:
	if is_instance_valid(equipment):
		equipment.applyOwnEquipmentSnapshot(snapshot.get("equipment", {}))
	if is_instance_valid(inventory):
		inventory.applyOwnInventorySnapshot(snapshot.get("inventory", {}))
	if is_instance_valid(skillbar):
		skillbar.applyOwnSkillbarSnapshot(snapshot.get("skillbar", {}))
	if is_instance_valid(stats) and !snapshot.get("stats", {}).empty():
		stats.applyOwnStatsSnapshot(snapshot["stats"])
	var crafting_node = get_node_or_null("UI/Crafting")
	if is_instance_valid(crafting_node) and !snapshot.get("crafting", {}).empty():
		crafting_node.applyOwnCraftingSnapshot(snapshot["crafting"])
	var friends_node = get_node_or_null("UI/Friends")
	if is_instance_valid(friends_node) and !snapshot.get("friends", {}).empty():
		friends_node.applyOwnFriendsSnapshot(snapshot["friends"])

	var loot_node = get_node_or_null("UI/Loot")
	if is_instance_valid(loot_node) and loot_node.has_method("applyOwnLootSnapshot") and !snapshot.get("loot", {}).empty():
		loot_node.applyOwnLootSnapshot(snapshot["loot"])

	var quest_node = get_node_or_null("UI/QuestSystem")
	if is_instance_valid(quest_node) and quest_node.has_method("applyOwnQuestSnapshot"):
		quest_node.applyOwnQuestSnapshot(snapshot.get("quests", {}))
	var party_node = get_node_or_null("UI/Party")
	if is_instance_valid(party_node) and !snapshot.get("party", {}).empty():
		party_node.applyOwnPartySnapshot(snapshot["party"])
	if !has_spawn_pos:
		applyOwnStateSnapshot(snapshot.get("state", {}))
	data_fully_loaded = true
	_revealAfterLoad()

	if get_tree().network_peer != null and !get_tree().is_network_server():
		Global.rpc_id(1, "reportClientFullyLoaded", entity_name)


remote func applyOwnStateSnapshot(data:Dictionary) -> void:
	if !isLocalPlayer():
		return
	if data.empty():
		return
	_applyStateSnapshotDirect(data)
func _markEntityReady() -> void:
	if entity_ready:
		return
	entity_ready = true
	if _buffered_spawn_pos != null:
		global_transform.origin = _buffered_spawn_pos
		_buffered_spawn_pos = null
	if _buffered_snapshot != null:
		var snap = _buffered_snapshot
		var hsp = _buffered_snapshot_has_spawn_pos
		_buffered_snapshot = null
		_applyFullSnapshotNow(snap, hsp)
func _applyStateSnapshotDirect(data:Dictionary) -> void:
	if data.has("rotation"): rotation = data["rotation"]
	if data.has("which_scene"): which_scene = data["which_scene"]
	if data.has("character_rotation") and is_instance_valid(character):
		character.rotation = data["character_rotation"]
	if data.has("turnable_rotation") and is_instance_valid(turnable):
		turnable.rotation = data["turnable_rotation"]
	if data.has("cursor_visible"): cursor_visible = data["cursor_visible"]
	if data.has("direction"): direction = data["direction"]

	var pos = data.get("position", translation)
	var saved_positions = data.get("positions", {})
	var wid = data.get("world_id", "")
	if typeof(saved_positions) == TYPE_DICTIONARY and wid != "" and saved_positions.has(wid):
		pos = saved_positions[wid]
	translation = pos

	_applyCameraSnapshot(data)


func _applyCameraSnapshot(data:Dictionary) -> void:
	if !is_instance_valid(camroot):
		return
	var h = camroot.get_node_or_null("h")
	if data.has("camera_h_rotation"):
		camroot.camrot_h = data["camera_h_rotation"]
		if is_instance_valid(h):
			h.rotation_degrees.y = camroot.camrot_h
	if data.has("camera_v_rotation") and is_instance_valid(h):
		camroot.camrot_v = data["camera_v_rotation"]
		var v = h.get_node_or_null("v")
		if is_instance_valid(v):
			v.rotation_degrees.x = camroot.camrot_v
			if data.has("camera_translation"):
				var cam = v.get_node_or_null("Camera")
				if is_instance_valid(cam):
					cam.translation = data["camera_translation"]


func switchToSavedWorld(saved_world_id:String, data:Dictionary) -> void:
	if !Global.isKnownWorldId(saved_world_id):
		return
	var target_scene_path = Global.getScenePath(saved_world_id)
	var packed_scene = load(target_scene_path)
	if packed_scene == null:
		return

	var new_world = packed_scene.instance()
	new_world.world_id = saved_world_id
	new_world.skip_offline_autospawn = true

	var old_world = get_parent()
	get_tree().root.add_child(new_world)
	get_tree().current_scene = new_world

	if is_instance_valid(old_world):
		old_world.remove_child(self)
	new_world.add_child(self)

	var pos:Vector3 = data.get("position", Vector3.ZERO)
	var saved_positions = data.get("positions", {})
	if typeof(saved_positions) == TYPE_DICTIONARY and saved_positions.has(saved_world_id):
		pos = saved_positions[saved_world_id]
	translation = pos
	which_scene = saved_world_id

	if data.has("rotation"): rotation = data["rotation"]
	if data.has("character_rotation") and is_instance_valid(character):
		character.rotation = data["character_rotation"]
	if data.has("turnable_rotation") and is_instance_valid(turnable):
		turnable.rotation = data["turnable_rotation"]
	if data.has("cursor_visible"): cursor_visible = data["cursor_visible"]
	if data.has("direction"): direction = data["direction"]

	_applyCameraSnapshot(data)

	if is_instance_valid(old_world):
		get_tree().root.remove_child(old_world)
		old_world.queue_free()

	yield(get_tree(), "physics_frame")
	disableFallDamage()
	ui_holder.visible = isLocalPlayer()
	reactivateAnimationTree()





func _forceLocalCameraCurrent(node) -> void:
	var cam = camroot.get_node_or_null("h/v/Camera")
	if is_instance_valid(cam):
		cam.current = true

func _forceCamerasNotCurrent(node) -> void:
	var cam = camroot.get_node_or_null("h/v/Camera")
	if is_instance_valid(cam):
		cam.current = false

var portal_grace_timer = 10

func loadCharacterData() -> void:
	var data = Global.getButtonListData()
	if data.empty():
		return

	if data.has("sexes") and typeof(data["sexes"]) == TYPE_DICTIONARY:
		var sexes: Dictionary = data["sexes"]
		if sexes.has(entity_name):
			stats.sex = sexes[entity_name]

	if data.has("races") and typeof(data["races"]) == TYPE_DICTIONARY:
		var races: Dictionary = data["races"]
		if races.has(entity_name):
			stats.species = races[entity_name]
		else:
			stats.species = "human"
	else:
		stats.species = "human"

	call_deferred("loadBoneData")
	call_deferred("loadHairData")
	yield(get_tree(), "idle_frame")
	call_deferred("loadBlendShapeData")
	call_deferred("loadEyeData")


var boneDefaultRest = {}

var lastSkeleton = null
func loadBoneData()->void:
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")

	var currentSkeleton:Skeleton = get_node_or_null("character/root/Skeleton")

	if currentSkeleton == null:
		return

	if lastSkeleton != currentSkeleton:
		boneDefaultRest.clear()
		lastSkeleton = currentSkeleton

	var data = Global.getButtonListData()
	if data.empty():
		return
	# ... rest of function continues exactly as before, starting from
	# "if data.has("sexes") ..." — do not change anything after this point.


	if data.has("sexes") and typeof(data["sexes"]) == TYPE_DICTIONARY:
		if data["sexes"].has(entity_name):
			stats.sex = data["sexes"][entity_name]

	if !data.has("bone_scale"):
		return

	if typeof(data["bone_scale"]) != TYPE_DICTIONARY:
		return

	if !data["bone_scale"].has(entity_name):
		return

	var savedBones:Dictionary = data["bone_scale"][entity_name]

	for boneName in savedBones:

		if !is_instance_valid(currentSkeleton):
			return

		var boneIndex = currentSkeleton.find_bone(boneName)

		if boneIndex == -1:
			continue

		if !boneDefaultRest.has(boneName):
			boneDefaultRest[boneName] = currentSkeleton.get_bone_rest(boneIndex)

		var bone = savedBones[boneName]

		if typeof(bone) != TYPE_DICTIONARY:
			bone = {
				"scale":1.0,
				"width":1.0,
				"height":1.0,
				"depth":1.0,
				"rotation":0.0,
				"position":Vector3()
			}

		if !bone.has("scale"):
			bone["scale"] = 1.0
		if !bone.has("width"):
			bone["width"] = 1.0
		if !bone.has("height"):
			bone["height"] = 1.0
		if !bone.has("depth"):
			bone["depth"] = 1.0
		if !bone.has("rotation"):
			bone["rotation"] = 0.0
		if !bone.has("position") or typeof(bone["position"]) != TYPE_VECTOR3:
			bone["position"] = Vector3()

		var position:Vector3 = bone["position"]

		if boneName == "clavicle_l" or boneName == "clavicle_r":
			position.x = -position.x

		var rest:Transform = boneDefaultRest[boneName]

		var basis:Basis = rest.basis

		basis = basis.scaled(Vector3(bone["scale"] * bone["width"],bone["scale"] * bone["height"],bone["scale"] * bone["depth"]))

		basis = basis.rotated(Vector3.UP,deg2rad(bone["rotation"]))

		currentSkeleton.set_bone_rest(boneIndex,Transform(basis,rest.origin + position))


func loadHairData()->void:
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")

	var skeleton:Skeleton=get_node_or_null("character/root/Skeleton")
	if skeleton==null:
		return

	for child in skeleton.get_children():
		if child.name=="Hair" or child.is_in_group("Hair"):
			child.free()

	if stats.species=="kragun":
		return

	var data = Global.getButtonListData()
	if data.empty():
		return

	var style:=0
	if data.has("hair") and typeof(data["hair"])==TYPE_DICTIONARY and data["hair"].has(entity_name):
		style=int(data["hair"][entity_name])

	var textureVariant:=0
	if data.has("hair_texture") and typeof(data["hair_texture"])==TYPE_DICTIONARY and data["hair_texture"].has(entity_name):
		textureVariant=int(data["hair_texture"][entity_name])

	var color:=Color.white
	if data.has("hair_colors") and typeof(data["hair_colors"])==TYPE_DICTIONARY and data["hair_colors"].has(entity_name):
		color=data["hair_colors"][entity_name]

	var paths={
		"male":[
			"res://world/player/human/male/hair/1.tscn",
			"res://world/player/human/male/hair/2.tscn",
			"res://world/player/human/male/hair/3.tscn"],
		"female":[
			"res://world/player/human/female/hair/1.tscn",
			"res://world/player/human/female/hair/2.tscn",
			"res://world/player/human/female/hair/3.tscn"]}

	var textures={
		"male":[#placeholder
			"res://world/player/human/female/hair/textures/hair1fem.png",
			"res://world/player/human/female/hair/textures/hair1fem_dark.png",
			"res://world/player/human/female/hair/textures/hair1fem_darker.png",
			"res://world/player/human/female/hair/textures/hair1fem_darkest.png",
			"res://world/player/human/female/hair/textures/hair2fem.png",
			"res://world/player/human/female/hair/textures/hair2fem_dark.png",
			"res://world/player/human/female/hair/textures/hair2fem_darker.png",
			"res://world/player/human/female/hair/textures/hair2fem_darkest.png",
			"res://world/player/human/female/hair/textures/hair3fem.png",
			"res://world/player/human/female/hair/textures/hair3fem_dark.png",
			"res://world/player/human/female/hair/textures/hair3fem_darker.png",
			"res://world/player/human/female/hair/textures/hair3fem_darkest.png"],
		"female":[
			"res://world/player/human/female/hair/textures/hair1fem.png",
			"res://world/player/human/female/hair/textures/hair1fem_dark.png",
			"res://world/player/human/female/hair/textures/hair1fem_darker.png",
			"res://world/player/human/female/hair/textures/hair1fem_darkest.png",
			"res://world/player/human/female/hair/textures/hair2fem.png",
			"res://world/player/human/female/hair/textures/hair2fem_dark.png",
			"res://world/player/human/female/hair/textures/hair2fem_darker.png",
			"res://world/player/human/female/hair/textures/hair2fem_darkest.png",
			"res://world/player/human/female/hair/textures/hair3fem.png",
			"res://world/player/human/female/hair/textures/hair3fem_dark.png",
			"res://world/player/human/female/hair/textures/hair3fem_darker.png",
			"res://world/player/human/female/hair/textures/hair3fem_darkest.png"]}

	if !paths.has(stats.sex):
		return

	style=clamp(style,0,paths[stats.sex].size()-1)
	textureVariant=clamp(textureVariant,0,3)

	var hair=load(paths[stats.sex][style]).instance()
	hair.name="Hair"
	skeleton.add_child(hair)
	makeHairUnique(hair)
	applyHairTextureRecursive(hair,load(textures[stats.sex][style*4+textureVariant]))
	applyHairColorRecursive(hair,color)


func makeHairUnique(node:Node):
	if node is MeshInstance:
		if node.mesh:
			node.mesh=node.mesh.duplicate()
			for i in range(node.mesh.get_surface_count()):
				var material=node.mesh.surface_get_material(i)
				if material:
					material=material.duplicate()
					node.mesh.surface_set_material(i,material)
					node.set_surface_material(i,material)
		if node.material_override:
			node.material_override=node.material_override.duplicate()
		if node.material_overlay:
			node.material_overlay=node.material_overlay.duplicate()
	for child in node.get_children():
		makeHairUnique(child)


var headInstance=null

var _head_scene_cache:Dictionary = {}
func loadBlendShapeData():
	yield(get_tree(),"idle_frame")
	call_deferred("loadBlendShapeDataDeferred")

func loadBlendShapeDataDeferred():
	var skeleton=$character/root/Skeleton
	if skeleton==null:
		return

	if is_instance_valid(headInstance):
		headInstance.queue_free()
		headInstance=null

	var head_path:String
	if stats.species=="kragun":
		head_path="res://world/player/kragun/unisex/Head0.tscn"
	else:
		head_path="res://world/player/human/"+stats.sex+"/Head0.tscn"

	if !_head_scene_cache.has(head_path):
		if !ResourceLoader.exists(head_path):
			return
		_head_scene_cache[head_path] = load(head_path)

	var head:PackedScene = _head_scene_cache[head_path]
	if head:
		headInstance=head.instance()
		headInstance.name="Head"
		skeleton.add_child(headInstance)

	yield(get_tree(),"idle_frame")

	var data = Global.getButtonListData()
	if data.empty():
		return
	if !data.has("blend_shapes") or !data["blend_shapes"].has(entity_name):
		return


	var shapes=data["blend_shapes"][entity_name]

	if typeof(shapes)!=TYPE_DICTIONARY:
		return

	var meshes=[]
	yield(get_tree(),"idle_frame")
	findBlendMeshes(skeleton,meshes)

	# Build shape_name -> blend_shape_index per mesh ONCE, instead of
	# calling mesh.set("blend_shapes/"+shape, value) which does a string
	# property-path resolve every single call. set_blend_shape_value(idx,v)
	# with a pre-resolved integer index is drastically cheaper.
	var mesh_shape_index_cache:Dictionary = {}
	yield(get_tree(),"idle_frame")
	for mesh in meshes:
		var id = mesh.get_instance_id()
		var index_map := {}
		for i in range(mesh.mesh.get_blend_shape_count()):
			yield(get_tree(),"idle_frame")
			index_map[mesh.mesh.get_blend_shape_name(i)] = i
			yield(get_tree(),"idle_frame")
		mesh_shape_index_cache[id] = index_map
		
	for key in shapes:
		var parts=str(key).split("_",false,1)
		yield(get_tree(),"idle_frame")
		if parts.size()!=2:
			continue

		var bodyPart=parts[0]
		var shape=parts[1]
		var value=float(shapes[key])

		for mesh in meshes:
			var isHead="head" in mesh.name.to_lower()
			yield(get_tree(),"idle_frame")
			if bodyPart=="Head" and !isHead:
				continue
			if bodyPart=="Body" and isHead:
				continue

			var index_map = mesh_shape_index_cache.get(mesh.get_instance_id(), {})
			if index_map.has(shape):
				mesh.set("blend_shapes/" + shape, value)



func findBlendMeshes(node,meshes):
	if node is MeshInstance and node.mesh and node.mesh.get_blend_shape_count()>0:
		meshes.append(node)

	for child in node.get_children():
		findBlendMeshes(child,meshes)


func loadEyeData():
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")

	if !is_instance_valid(headInstance):
		return

	var data = Global.getButtonListData()
	if data.empty():
		return
	if !data.has("eye_colors"):
		return
	if typeof(data["eye_colors"])!=TYPE_DICTIONARY:
		return
	if !data["eye_colors"].has(entity_name):
		return


	var eyes=data["eye_colors"][entity_name]

	if typeof(eyes)!=TYPE_DICTIONARY:
		return

	var mesh:MeshInstance=null

	if headInstance is MeshInstance:
		mesh=headInstance
	else:
		for child in headInstance.get_children():
			if child is MeshInstance:
				mesh=child
				break

	if mesh==null:
		return

	var material_path:String
	if stats.species=="kragun":
		material_path="res://world/player/kragun/mesh/rhino.material"
	else:
		material_path="res://world/player/human/"+stats.sex+"/materials/Head0.tres"
	var material=load(material_path)

	if !(material is ShaderMaterial):
		return

	material=material.duplicate()
	material.set_shader_param("eye_left_color",eyes.get("left",Color.white))
	material.set_shader_param("eye_right_color",eyes.get("right",Color.white))

	for i in range(mesh.get_surface_material_count()):
		mesh.set_surface_material(i,material)





func applyHairColorRecursive(node:Node,color:Color):
	if node is MeshInstance:
		if node.material_override:
			node.material_override=node.material_override.duplicate()
			node.material_override.albedo_color=color

		if node.material_overlay:
			node.material_overlay=node.material_overlay.duplicate()
			node.material_overlay.albedo_color=color

		for i in range(node.mesh.get_surface_count() if node.mesh else 0):
			var material=node.get_surface_material(i)
			if material==null and node.mesh:
				material=node.mesh.surface_get_material(i)
			if material:
				material=material.duplicate()
				material.albedo_color=color
				node.set_surface_material(i,material)
	for child in node.get_children():
		applyHairColorRecursive(child,color)
func applyHairTextureRecursive(node:Node,texture:Texture):
	if node is MeshInstance:
		if node.material_override:
			node.material_override=node.material_override.duplicate()
			node.material_override.albedo_texture=texture

		if node.material_overlay:
			node.material_overlay=node.material_overlay.duplicate()
			node.material_overlay.albedo_texture=texture

		if node.mesh:
			for i in range(node.mesh.get_surface_count()):
				var material=node.get_surface_material(i)
				if material==null:
					material=node.mesh.surface_get_material(i)
				if material:
					material=material.duplicate()
					material.albedo_texture=texture
					node.mesh.surface_set_material(i,material)
					node.set_surface_material(i,material)

	for child in node.get_children():
		applyHairTextureRecursive(child,texture)

func reportAllBotCoordinates() -> void:
	var world = get_parent()
	if !is_instance_valid(world) or !("world_id" in world):
		return
	for node in Global.getActivePlayersInWorld(world.world_id):
		if is_instance_valid(node) and node.is_in_group("BOT") and node.has_method("reportOwnCoordinates"):
			node.reportOwnCoordinates()
