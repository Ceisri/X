extends KinematicBody #Player.gd 


const save_data_password := "kQ7$mZp2!____vLx9rT&eB4_____^wN8c___are_you_really_trying_to_crack_this_lock?J6#hY3@fD1*sG5%uA0~o_____R"



onready var player_mesh = $character
onready var animation =  $character/AnimationPlayer
onready var anim_calls = $AnimationCalls
onready var character = $character
onready var equipment =$UI/Equipment
onready var skeleton = $character/root/Skeleton

onready var ui_holder:Control = $UI
onready var stats =$Stats
onready var camroot = $Camroot
onready var camera_v = $Camroot/h/v
onready var camera_h = $Camroot/h
onready var skillbar = $UI/Skillbar
onready var loot = $UI/Loot
onready var inventory = $UI/Inventory
onready var turnable:Spatial = $Turnable

var pvp_enabled:bool = false
var respawn_id:int = 0
var entity_name = Global.selected_player_name
export var sex:String = "female"
puppet var net_sex := "male"



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
var acceleration = int()
var can_move= true
var is_carrying = false
var cursor_visible = false
var is_swimming:bool = false
var is_downed:bool = false
var is_dead:bool = false
var wall_incline
var is_on_stairs: bool = false
var wall_hanging:bool = false
onready var head_ray = $Turnable/Vault
onready var climb_ray = $Turnable/MidRay
onready var root_bone = skeleton.find_bone("ik_foot_root")
var root_motion_active:bool= false
var last_root_pos := Vector3.ZERO
var root_motion_velocity := Vector3.ZERO
var _last_root_motion_pos := Vector3.ZERO
var is_climbing:bool= false
onready var animation_tree:AnimationTree = $AnimationTree
onready var _unique_animation_tree_root = _makeAnimationTreeRootUnique()
onready var skill_anim = animation_tree.tree_root.get_node("Skill")

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
		PlayerSpawner.rpc_id(1, "requestOwnFullSnapshot")

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

export var sync_rate := 0.04
var sync_timer := 0.0
export var puppet_lerp_speed := 18.0
var _entity_initialized := false

var _is_pooled_idle := false
var _ready_complete := false
#func _ready():
#	_is_pooled_idle = has_meta("is_pooled_idle")
#
#	if !_is_pooled_idle:
#		if entity_name == null or entity_name == "":
#			entity_name = Global.selected_player_name
#		if isLocalPlayer():
#			Global.resetPlayerReady()
#	$UI/Crafting/Smelting.hide()
#	$character/root/Skeleton/Mesh.hide()
#	direction=Vector3.BACK.rotated(Vector3.UP,$Camroot/h.global_transform.basis.get_euler().y)
#	initializeAnimationBlends()
#	if !_is_pooled_idle and isLocalPlayer():
#		loadCharacterData()
#		ApplySex()
#		_forceLocalCameraCurrent(self)
#	if is_instance_valid(character):
#		character.hide()
#	yield(get_tree(),"idle_frame")
#	equipment.updateEquipment()
#	yield(get_tree(),"idle_frame")
#	for child in $UI/Skillbar/GridContainer.get_children():
#		child.get_node("Slot").player=self
#		child.get_node("TextureButton").parent=self
#		child.get_node("Slot").loadData()
#	if !_is_pooled_idle and isLocalPlayer():
#		call_deferred("loadBoneData")
#	yield(get_tree(),"idle_frame")
#	_updateInputKeys()
#	_cacheToolIcons()
#	disableFallDamage()
#	water_level_area.connect("area_shape_entered", self, "enterDeepWaters")
#	water_level_area.connect("area_shape_exited", self, "exitDeepWaters")
#	if !_is_pooled_idle:
#		ui_holder.visible = isLocalPlayer()
#		if isLocalPlayer():
#			Network.connect("connection_lost", self, "_onConnectionLost")
#			Network.connect("reconnect_attempt", self, "_onReconnectAttempt")
#			Network.connect("reconnected", self, "_onReconnected")
#			Network.connect("reconnect_failed", self, "_onReconnectFailedUI")
#	reactivateAnimationTree()
#	if !_is_pooled_idle and isLocalPlayer():
#		yield(get_tree(),"idle_frame")
#		yield(get_tree(),"idle_frame")
#		Global.markPlayerReady()
#		for i in range(30):
#			yield(get_tree(),"idle_frame")
#	if is_instance_valid(character):
#		character.show()
#	_ready_complete = true
#


# ===== Player.gd — _ready(), add entity_ready = false at top and
# _markEntityReady() call at the very end =====

func _ready():
	_is_pooled_idle = has_meta("is_pooled_idle")
	entity_ready = false

	if !_is_pooled_idle:
		if entity_name == null or entity_name == "":
			entity_name = Global.selected_player_name
		if isLocalPlayer():
			Global.resetPlayerReady()
	$UI/Crafting/Smelting.hide()
	$character/root/Skeleton/Mesh.hide()
	direction=Vector3.BACK.rotated(Vector3.UP,$Camroot/h.global_transform.basis.get_euler().y)
	initializeAnimationBlends()
	if !_is_pooled_idle and isLocalPlayer():
		loadCharacterData()
		ApplySex()
		_forceLocalCameraCurrent(self)
	if is_instance_valid(character):
		character.hide()
	yield(get_tree(),"idle_frame")
	equipment.updateEquipment()
	yield(get_tree(),"idle_frame")
	for child in $UI/Skillbar/GridContainer.get_children():
		child.get_node("Slot").player=self
		child.get_node("TextureButton").parent=self
		child.get_node("Slot").loadData()
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




# Called directly by _ready() for a freshly-instanced (non-pooled) player,
# and explicitly by PlayerSpawner._doSpawnPlayer() for a pooled node that
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

	$UI/Crafting/Smelting.hide()
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
	for child in $UI/Skillbar/GridContainer.get_children():
		child.get_node("Slot").player=self
		child.get_node("TextureButton").parent=self
		child.get_node("Slot").loadData()
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

func _syncToPuppets(delta) -> void:
	if get_tree().network_peer == null:
		return
	if !isLocalPlayer():
		return
	sync_timer += delta
	if sync_timer < sync_rate:
		return
	sync_timer = 0.0

	rset_unreliable("net_position", translation)
	rset_unreliable("net_rotation_y", rotation.y)
	if is_instance_valid(player_mesh):
		rset_unreliable("net_character_rotation_y", player_mesh.rotation.y)
	if is_instance_valid(turnable):
		rset_unreliable("net_turnable_rotation_y", turnable.rotation.y)
	rset_unreliable("net_movement_mode", movement_mode)
	rset_unreliable("net_current_skill", current_skill)
	rset_unreliable("net_weapons", weapons)
	rset_unreliable("net_is_in_combat", is_in_combat)
	rset_unreliable("net_moving", moving)
	rset_unreliable("net_direction", direction)
	rset_unreliable("net_active_lock", getActiveAnimLock())  
	rset_unreliable("net_sex", stats.sex)
	
# ============================================================
# Player.gd — add net_is_downed puppet var + apply it in _applyPuppetState(),
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
	if _shouldAnimateLocally():
		animation_tree.active = true
	if net_sex != _last_applied_puppet_sex:
		_last_applied_puppet_sex = net_sex
		stats.sex = net_sex
		if _shouldAnimateLocally():
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


var skill_animations = {
	
	
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
	},

}
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
		animation_tree.active =true
		return

	if new_anim == "":
		anim_locks[skill_name] = false
		current_skill = "none"
		skillbar.reimburseSkill(skill_name)
		animation_tree.active =true
		return

	# Same skill still active this frame.
	# Do nothing.
	if skill_name == last_active_skill:
		return

	last_active_skill = skill_name

	skill_anim.animation = new_anim
	animation_tree.active = false
	animation_tree.active = true




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
func setAnimBlend(path:String, target:float, speed:float, delta:float) -> void:
	var current:float = 0.0

	if anim_blend_cache.has(path):
		var cached_value = anim_blend_cache[path]
		if cached_value != null:
			current = float(cached_value)
		else:
			print("Player.gd setAnimBlend(): AnimBlend warning: null cache value for path: ", path)
			current = 0.0
	else:
		var tree_value = animation_tree.get(path)
		if tree_value == null:
			print("Player.gd setAnimBlend(): AnimBlend warning: missing AnimationTree path: ", path)
			current = 0.0
		else:
			current = float(tree_value)

	current = move_toward(current, target, delta * speed)

	anim_blend_cache[path] = current
	animation_tree.set(path, current)
func initializeAnimationBlends() -> void:
	if !_shouldAnimateLocally():
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
			print("Player.gd initializeAnimationBlends(): AnimBlend init warning: missing AnimationTree path: ", path)
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

	combat_idle.animation = anim
	combat_idle_skill_smooth.animation = anim
func setCombatWalkAnimation()->void:
	if !combat_walk_animations.has(weapons):
		return
	var anim = combat_walk_animations[weapons]

	combat_walk.animation = anim
func setRunAnimation()->void:
	if !combat_run_animations.has(weapons):
		return
	var anim = combat_run_animations[weapons]
	run_node.animation = anim
func reactivateAnimationTree() -> void:
	if !is_instance_valid(animation_tree):
		return

	if is_instance_valid(player_mesh):
		var anim_player = player_mesh.get_node_or_null("AnimationPlayer")
		if anim_player:
			if animation_tree.has_method("set_animation_player"):
				animation_tree.call("set_animation_player", anim_player.get_path())
			else:
				animation_tree.set("anim_player", anim_player.get_path())

	animation_tree.active = false
	animation_tree.active = true






var water:float = -1.0
var land:float = 0.0
var air:float = 1.0
var climbing:float = 0.0
var falling:float = 1.0



func _shouldAnimateLocally() -> bool:
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
	return isLocalPlayer() # server: only animate its own hosted player, if any


var skillExitBlendSpeed:float = 2.0
func animationOrder() -> void:
	if stats.debuff_buffs_active.has("stunned") and float(stats.debuff_buffs_active["stunned"].get("duration",0.0)) > 0.0:
		animation_tree.set("parameters/CombatSwitch/blend_amount", 0.0)
		animation_tree.set("parameters/CrouchOrNot/blend_amount", 1.0)
		animation_tree.set("parameters/Movement/blend_amount", -1.0)
		animation_tree.set("parameters/IsInCombat/blend_amount", 0.0)
		animation_tree.active = true
		return
	#leave animaiton_tree off by default 
	var delta:float =get_process_delta_time()
	var active_lock:=getActiveAnimLock()
	var now = OS.get_ticks_msec() / 1000.0
	var skill_scale:float =  stats.derived_stats["attack_speed"] 
	if anim_calls.speed_up_combo_until.has(active_lock):
		if now < anim_calls.speed_up_combo_until[active_lock]:
			skill_scale =  stats.derived_stats["attack_speed"] + 3
		else:
			anim_calls.speed_up_combo_until.erase(active_lock)

	animation_tree.set("parameters/SkillTimeScale/scale", skill_scale)
	
	var speed_factor_walk = max(0.0, stats.walk_speed / 4.0)
	if speed_factor_walk > 1.0:
		speed_factor_walk = 1.0 + sqrt(speed_factor_walk - 1.0) * 0.5
	animation_tree.set("WalkSpeed", speed_factor_walk)
	var speed_factor_run = max(0.0, (stats.run_speed * lerp(1.0, run_max_speed_multiplier, clamp(current_run_time / run_ramp_time, 0.0, 1.0))) / 15.5)
	if speed_factor_run > 1.0:
		speed_factor_run = 1.0 + (speed_factor_run - 1.0) * 0.25
	animation_tree.set("RunSpeed", speed_factor_run)
	
	
	# -----------------------------
	# STAGGER / STUN OVERRIDE
	# -----------------------------
	if stats != null and stats.statuses.has("stun"):
		last_active_skill = "staggered"
		current_skill = "staggered"
		skill_anim.animation = "staggered"

		animation_tree.set("parameters/CombatSwitch/blend_amount", 1.0)
		animation_tree.set("parameters/MeleeSkillSwitch/blend_amount",1.0)
		animation_tree.set("parameters/MeleeSkillSwitch/blend_amount", 1.0)
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
				animation_tree.set("parameters/SkillTimeScale/scale", skill_scale)

			return
		# Character returns to movement locomotion state.
		# ============================================================
		last_active_skill=""

		# ------------------------------------------------------------
		# Leave combat state smoothly.
		# ------------------------------------------------------------

		animation_tree.set("parameters/CombatSwitch/blend_amount",0.0)
		animation_tree.set("parameters/MeleeSkillSwitch/blend_amount",0.0)

		# ============================================================
		# TARGET VALUES
		# ============================================================
		# These values are calculated first.
		# Afterward they are interpolated smoothly.
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
			animation_tree.set("parameters/WaterLandAir/blend_amount",land)
			animation_tree.set("parameters/ClimbingOrFalling/blend_amount",falling)
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
						setAnimBlend("parameters/IsAlive/blend_amount",1.0,blend,delta)
						movement_target=-1.0
						if is_in_combat:
							setAnimBlend("parameters/IsInCombat/blend_amount",1.0,blend,delta)
							setCombatIdleAnimation()

						else:
							setAnimBlend("parameters/IsInCombat/blend_amount",0.0,blend,delta)
							animation_tree.set("parameters/WaterLandAir/blend_amount",land)
					else:
						setAnimBlend("parameters/IsAlive/blend_amount",0.0,blend,delta)
						setAnimBlend("parameters/Downed/blend_amount",0.0,blend,delta)
						animation_tree.set("parameters/WaterLandAir/blend_amount",land)
				# ----------------------------------------------------
				# WALK
				# ----------------------------------------------------
				"walk":
					movement_target=0.0
					if stats.health >0:
						setAnimBlend("parameters/IsAlive/blend_amount",1.0,blend,delta)
						if is_in_combat == true:
							animation_tree.set("parameters/WalkCombatOrNot/blend_amount",1)
							animation_tree.set("parameters/WaterLandAir/blend_amount",land)
							setCombatWalkAnimation()
						else:
							animation_tree.set("parameters/WalkCombatOrNot/blend_amount",0)
							animation_tree.set("parameters/WaterLandAir/blend_amount",land)
					else:
						setAnimBlend("parameters/IsAlive/blend_amount",0.0,blend,delta)
						setAnimBlend("parameters/Downed/blend_amount",1.0,blend,delta)
						animation_tree.set("parameters/WaterLandAir/blend_amount",land)
				# ----------------------------------------------------
				# RUN
				# ----------------------------------------------------
				"run":
					if stats.health >0:
						if is_in_combat == true: 
							setRunAnimation()
							animation_tree.set("parameters/IsInCombatRun/blend_amount",1)
							animation_tree.set("parameters/WaterLandAir/blend_amount",land)
						else:
							animation_tree.set("parameters/IsInCombatRun/blend_amount",0)
							animation_tree.set("parameters/WaterLandAir/blend_amount",land)
						movement_target=1.0
						animation_tree.set("parameters/RunSpeed/scale",0.8+(0.0125*stats.run_speed))
						
				# ----------------------------------------------------
				# CROUCH IDLE
				# ----------------------------------------------------
				"crouch_idle":
					crouch_target=0.0
					crouch_mode_target=0.0
					animation_tree.set("parameters/CrouchMov/blend_amount",0)
					animation_tree.set("parameters/IsInCombatRun/blend_amount",0)
					animation_tree.set("parameters/WaterLandAir/blend_amount",land)
				# ----------------------------------------------------
				# CROUCH MOVEMENT
				# ----------------------------------------------------
				"crouch_moving":
					crouch_target=0.0
					crouch_mode_target=1.0
					animation_tree.set("parameters/CrouchMov/blend_amount",1)
					animation_tree.set("parameters/IsInCombatRun/blend_amount",0)
					animation_tree.set("parameters/WaterLandAir/blend_amount",0)
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
					animation_tree.set("parameters/WaterLandAir/blend_amount",water)
					animation_tree.set("parameters/SwimSpeed/scale",0.97+(0.03*stats.derived_stats["swim_speed"]))

				# ----------------------------------------------------
				# TREADING WATER
				# ----------------------------------------------------
				"treading water":
					animation_tree.set("parameters/WaterLandAir/blend_amount",water)
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




		

export var root_motion_scale:float = 0.01

onready var detection_area:Area = $Turnable/Area

var root_motion_exceptions = [
	"shoulder bash",
	"backstep",
	"evasion",
	"foresight slash",
	"lunar slash"
]

func rootMotion(delta)->void:
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

	move_and_slide(Vector3(offset.x / delta, vertical_velocity.y, offset.z / delta), Vector3.UP)








var unstuckDistance = 15
onready var dodge_check:Area = $Turnable/Cleave

func dodgeMessage()->void:
	var bodies = dodge_check.get_overlapping_bodies()
	for body in bodies:
		if body == self: continue
		if !body.is_in_group("Entity"): continue

		var skill_name = body.get("current_skill") if body.has_method("get") or "current_skill" in body else ""
		if skill_name == "" or skill_name == "none" or !Skills.skills.has(skill_name) or Skills.support_skills.has(skill_name): continue
		
		var message = "dodged "
		if "entity_name" in body and body.entity_name != "nameless":
			message += body.entity_name
		else:
			message += body.stats.species

		message += " " + skill_name
		chat.sendSystemMessage(message)
					
					
onready var area_check_level_detector = $unstuckCheck

func dodgeCollisions(_delta) -> void:
	var is_dodge_skill = Skills.skill_dmg_immunity.has(current_skill)

	if is_dodge_skill:
		if current_skill != last_active_skill:
			dodgeMessage()

		anim_calls.disableCollisions()

		var should_enable = true

		for body in area_check_level_detector.get_overlapping_bodies():
			if body == self:
				continue

			if body.is_in_group("Entity") and !body.is_in_group("Player"):
				horizontal_velocity = direction.normalized() * stats.walk_speed
				should_enable = false
				break

		if should_enable:
			anim_calls.enableCollisions()

		return

	anim_calls.enableCollisions()




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

	for weapon_name in Items.weapons:
		var weapon = Items.weapons[weapon_name]
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
	var label:Label = $UI/ResourceDetectionLabel
	label.visible = false
	label.text = ""

	for body in $"Turnable/Area".get_overlapping_bodies():
		if body == self:
			continue
		if (body.is_in_group("entity") or body.is_in_group("Entity")) and "stats" in body and body.stats.health <= 0:
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

func _handleGatherTarget(target, label:Label) -> bool:
	if !is_instance_valid(target) or !target.is_in_group("Resource"):
		return false

	var main_hand=$"UI/Equipment/MainHand/Slot".texture
	var inventory=$UI/Inventory/ScrollContainer/GridContainer
	var has_pickaxe=main_hand in mining_icons
	var has_axe=main_hand in chopping_icons

	if !has_pickaxe or !has_axe:
		for child in inventory.get_children():
			var slot=child.get_node_or_null("Slot")
			if !slot:continue
			if !has_pickaxe and slot.texture in mining_icons:
				has_pickaxe=true
			if !has_axe and slot.texture in chopping_icons:
				has_axe=true
			if has_pickaxe and has_axe:
				break

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
	reviving_target_active = false
	if get_tree().network_peer == null:
		return

	var key = InputMap.get_action_list("Harvest")[0].as_text().replace(" (Physical)","").replace(" (physical)","")
	var found_target = null

	for target in $"Turnable/Bash".get_overlapping_bodies():
		if !is_instance_valid(target) or target == self:
			continue
		if !target.is_in_group("Player"):
			continue
		var target_stats = target.get_node_or_null("Stats")
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
	if is_instance_valid(label):
		label.visible = false
		
	

func performRevive(target:Node) -> void:
	cancelRevive()
	var target_stats = target.get_node_or_null("Stats")
	if is_instance_valid(target_stats):
		target_stats.reviveTarget(revive_heal_percent)









onready var crafting:Control = $UI/Crafting
onready var skill_tree_root:Control = $UI/SkillTreeRoot
func _physics_process(delta) -> void:
	if isLocalPlayer():
		_physics_process_master(delta)
	else:
		_physics_process_puppet(delta)
	if _shouldAnimateLocally():
		animationOrder()
	safetyStuff()
	collisionShapesManager()
func _physics_process_master(delta) -> void:
	dodgeCollisions(delta)
	detectDownedPlayer()
	checkGroundedStuck(delta)
	if !reviving_target_active:
		detectGathering()
		detectObjects()
	if current_skill=="mine" or current_skill=="chop" or current_skill=="gather":
		if !chat.line_edit.has_focus():
			if Input.is_action_pressed("forward") or Input.is_action_pressed("backward") or Input.is_action_pressed("left")or Input.is_action_pressed("right"):
				current_skill=""
				anim_calls.unlockAnim()

	if stats.health <= 0:
		skillbar.combo_queue = 0
		skillbar.continue_combo_atk = false
		anim_locks["combo attack"] = false
		animation_tree.set("parameters/CombatSwitch/blend_amount",0)
		animation_tree.set("parameters/IsAlive/blend_amount",0)
	if anim_locks["guard react"] == true:
		anim_locks["guard"] = false
	if Engine.get_physics_frames() % 12 == 0:
		if is_on_floor():
			water_areas.clear()
			is_in_water = false
	forceMovementAnimUnlock()
	if Input.is_action_just_pressed("unstuck"):
		if is_writing == false and is_chatting == false:
			is_in_combat = !is_in_combat
			unstuckPlayer()
			enableEntityCollisions()
			unlockAnim()
			is_in_water = false
	if Input.is_action_just_pressed("out_of_combat"):
		if is_writing == false and is_chatting == false:
			is_in_combat = !is_in_combat

	if Input.is_action_just_pressed("skills"):
		if is_writing == false and is_chatting == false:
			skill_tree_root.visible = !skill_tree_root.visible
	buoyancy(delta)
	if current_skill != "" and current_skill != "none":
		rootMotion(delta)
	if anim_locks["stunned"] == false and anim_locks["staggered"] == false and is_dead == false:
		jump()
		movement(delta)
	physics(delta)

	if cursor_visible == false:
		dash()

	if !movement_mode == "idle":
		loot.closeLoot()
		inventory.clearCart()
		inventory.shop.hide()
		$UI/Crafting/Smelting.hide()
		if inventory.buy_button.visible == false:
			inventory.restoreBrokerItems()
	if Input.is_action_just_pressed("character"):
		if is_writing == false:
			equipment.visible = !equipment.visible
			inventory.shop.visible =false
			$UI/SkillTreeRoot.visible =false

	crafting.update_crafting()

	if !crafting.visible:
		crafting.returnCraftingItems()
	else:
		if is_writing == false:
			if Input.is_action_just_pressed("help"):
				crafting.recipes_book.visible  = false

	if Engine.get_physics_frames() % 6 == 0:
		forceWaterSwitch()
		$UI/CrossairInspect.crossairInspect(self)
	if Engine.get_physics_frames() % 35 == 0:
		if inventory.visible: if inventory.has_method("updateInventory"):inventory.updateInventory()
	if Engine.get_physics_frames() % 60 == 0:
		replenishHealth()
		$UI/Menu/CharacterBar.updateBars()
	if Engine.get_physics_frames() % 360 == 0:
		saveData()
	if Engine.get_physics_frames() % 12000 == 0:
		if not is_in_combat:
			stored_body == null
	movement_speed = 0
	acceleration = 15

	if !is_in_water:
		if on_platform and is_instance_valid(platform):
			vertical_velocity = Vector3.ZERO
		elif !is_on_floor():
			vertical_velocity += Vector3.DOWN * gravity * 2 * delta
		else:
			vertical_velocity = -get_floor_normal() * gravity / 3
	else:
		vertical_velocity.y = 0
	checkFall()

	_syncToPuppets(delta)

#func _physics_process_puppet(delta) -> void:
#	_applyPuppetState(delta)
#	_enforceNonLocalPresentation()

# ===== Player.gd — add to _physics_process_puppet() =====
func _physics_process_puppet(delta) -> void:
	_applyPuppetState(delta)
	_enforceNonLocalPresentation()
	_enforcePuppetVisibility()

# Belt-and-suspenders: whatever state got this puppet into an invisible/
# frozen/collision-disabled condition (setSuspended(true) never getting
# its matching setSuspended(false), a race in reinitializeForEntity(),
# anything), self-correct every physics frame. A puppet has no "own data
# not loaded yet" race to protect against the way the local player does
# -- there is no reason a puppet should ever be invisible or frozen.
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

func collisionShapesManager()->void:
	var crouching=movement_mode=="crouch_idle" or movement_mode=="crouch_moving"

	fullbody_collision.disabled=crouching
	upper_body_collision.disabled=crouching
	lower_body_collision.disabled=!crouching
	
var movement_unlock_locks = [
	"parry",
	"guard",
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
	if current_skill != "" or current_skill != "none":
		if !Skills.canRotateDuringSkill(current_skill):
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
		can_rotate = Skills.skill_rotation_allowed.get(current_skill, false)

	if is_instance_valid(player_mesh) and is_instance_valid(turnable):
		if can_rotate:
			for anim_name in anim_locks:
				if anim_locks[anim_name] and !Skills.skill_rotation_allowed.get(anim_name,false):
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
	for body in get_tree().get_nodes_in_group("Entity"):
		if body == self:
			continue
		remove_collision_exception_with(body)
		body.remove_collision_exception_with(self)

func unlockAnim():
	for key in anim_locks:
		anim_locks[key] = false
	current_skill = ""
	root_motion_active = false
	enableEntityCollisions()
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
					animation_tree.set("parameters/WaterLandAir/blend_amount",air)
					animation_tree.set("parameters/ClimbingOrFalling/blend_amount",falling)
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
	
	
export var airborne_coyote_time := 0.12 # grace window before a single is_on_floor() flicker commits to the fall animation
var airborne_stuck_timer := 0.0
export var airborne_stuck_timeout := 1.5 # seconds "airborne" with near-zero vertical speed before we force a landing


func checkFall():
	if ground_raycast.is_colliding() and is_on_floor():
		is_airborne = false
		animation_tree.set("parameters/WaterLandAir/blend_amount",land)
		animation_tree.set("parameters/ClimbingOrFalling/blend_amount",falling)
	if on_platform and is_instance_valid(platform):
		return
	if fall_damage_grace_period > 0.0:
		fall_damage_grace_period -= get_physics_process_delta_time()
		was_on_floor = is_on_floor()
		highest_y = global_transform.origin.y
		return
	if is_in_water:
		is_airborne = false
		airborne_delay = 0.0
		return

	var on_floor := is_on_floor()
	if !on_floor and vertical_velocity.y <= 0.0 and is_instance_valid($DistanceToFloordRay) and $DistanceToFloordRay.is_colliding():
		on_floor = true
	# Left ground
	if was_on_floor and !on_floor:
		is_in_combat = false
		highest_y = global_transform.origin.y

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

	was_on_floor = on_floor


	if is_airborne and abs(vertical_velocity.y) < 0.5 and !is_climbing:
		airborne_stuck_timer += get_physics_process_delta_time()
		if airborne_stuck_timer >= airborne_stuck_timeout:
			is_airborne = false
			airborne_delay = 0.0
			airborne_stuck_timer = 0.0
	else:
		airborne_stuck_timer = 0.0
	
	if is_airborne ==true:
		animation_tree.set("parameters/WaterLandAir/blend_amount",air)
		animation_tree.set("parameters/ClimbingOrFalling/blend_amount",falling)
	
	
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
	animation_tree.set("parameters/WaterLandAir/blend_amount",0)














var is_in_water:bool = false
var water_areas := []
var platform=null
var platform_local:=Transform()
var on_platform:=false
"""
Root motion may be enabled by an unknown code path. The exact location
and timing that sets `root_motion_active` to true is currently unknown,
but something does trigger it.

Make sure root motion is explicitly set to false in `unlockanim()`, both
in `animation_calls` and inside this script.

Failing to do so can cause the player to become stuck unexpectedly on rare occasions.
"""
func physics(delta):
	if root_motion_active and current_skill != "" and current_skill != "none":
		if is_in_water:
			translation.y += vertical_velocity.y * get_physics_process_delta_time()
			movement.x = horizontal_velocity.x
			movement.y = 0
			movement.z = horizontal_velocity.z
			move_and_slide(movement,Vector3.ZERO,false,4,PI,false)
		else:
			vertical_velocity = move_and_slide(vertical_velocity,Vector3.ZERO,false,4,PI,false)
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
			dash_current_speed = lerp(dash_current_speed,dash_max_power,12.0*delta)

		horizontal_velocity = dash_dir * dash_current_speed

		if dash_timer <= 0.0:
			is_dashing = false
			dash_phase = 0
			dash_turn_multiplier = 1.0
	else:
		horizontal_velocity = horizontal_velocity.linear_interpolate(direction.normalized() * movement_speed,acceleration * delta)

	if on_platform and is_instance_valid(platform): # platform or ship, same shit, i use this code for both personally
		var basis = platform.global_transform.basis
		var local_move = Vector3(
			horizontal_velocity.dot(basis.x),
			0,
			-horizontal_velocity.dot(basis.z)
		) * delta

		platform_local.origin += local_move

		if !is_in_water:
			platform_local.origin.y += vertical_velocity.y * delta

		global_transform = platform.global_transform * platform_local

		movement.x = horizontal_velocity.x
		movement.z = horizontal_velocity.z
		movement.y = vertical_velocity.y

		move_and_slide(Vector3(0,movement.y,0),Vector3.UP)

		platform_local.origin.y = platform.to_local(global_transform.origin).y

		if !is_on_floor():
			on_platform = false
			platform = null

		return

	movement.x = horizontal_velocity.x + vertical_velocity.x
	movement.y = vertical_velocity.y
	movement.z = horizontal_velocity.z + vertical_velocity.z

	if is_in_water:
		translation.y += vertical_velocity.y * get_physics_process_delta_time()
		movement.x = horizontal_velocity.x
		movement.y = 0
		movement.z = horizontal_velocity.z
		move_and_slide(movement,Vector3.ZERO,false,4,PI,false)
	else:
		movement = move_and_slide(movement,Vector3.UP)


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
















func safetyStuff()->void:
	if stats != null and !stats.statuses.has("stun"):
		anim_locks["stunned"] = false
		anim_locks["staggered"] = false



var male_scene = null
var female_scene = null
func get_character_scene(male:bool)->PackedScene:
	if male:
		if !male_scene: male_scene = load("res://world/player/human/scenes/character_male.tscn")
		return male_scene
	if !female_scene: female_scene = load("res://world/player/human/scenes/character_female.tscn")
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
			if typeof(loaded)==TYPE_DICTIONARY:
				data=loaded

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
	var packed_scene=get_character_scene(stats.sex=="male")
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
	add_child(new_character)
	player_mesh=new_character
	character=new_character   #keep this reference current too

	if animation_tree:
		var animation_player=new_character.get_node_or_null("AnimationPlayer")
		var root_bone=new_character.get_node_or_null("root/Skeleton/root")
		if animation_player and animation_tree.has_method("set_animation_player"):
			animation_tree.call("set_animation_player",animation_player.get_path())
		elif animation_player:
			animation_tree.set("anim_player",animation_player.get_path())
		if root_bone:
			animation_tree.set("root_motion_track",root_bone.get_path())

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
	var button_data = {
		"buttons": [],
		"sexes": {}
	}

	var button_file = File.new()

	if button_file.file_exists(button_list_path):
		if button_file.open(button_list_path, File.READ) == OK:
			var loaded_data = button_file.get_var()
			button_file.close()

			if typeof(loaded_data) == TYPE_DICTIONARY:
				button_data = loaded_data

	if !button_data.has("buttons") or typeof(button_data["buttons"]) != TYPE_ARRAY:
		button_data["buttons"] = []

	if !button_data.has("sexes") or typeof(button_data["sexes"]) != TYPE_DICTIONARY:
		button_data["sexes"] = {}

	if button_data["buttons"].find(entity_name) == -1:
		button_data["buttons"].append(entity_name)

	button_data["sexes"][entity_name] = stats.sex

	if button_file.open(button_list_path, File.WRITE) == OK:
		button_file.store_var(button_data)
		button_file.close()


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

	if !has_spawn_pos:
		applyOwnStateSnapshot(snapshot.get("state", {}))
	data_fully_loaded = true
	_revealAfterLoad()

	if get_tree().network_peer != null and !get_tree().is_network_server():
		PlayerSpawner.rpc_id(1, "reportClientFullyLoaded", entity_name)


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

#func loadData()->void:
#	if !is_inside_tree():
#		return
#	var save_path = "user://Characters/" + entity_name + "/position_data.save"
#	var file = File.new()
#	if !file.file_exists(save_path):
#		if get_tree().network_peer == null:
#			yield(get_tree(), "idle_frame")
#			spawnAtPlayerStart()
#		return
#	if file.open_encrypted_with_pass(save_path, File.READ, save_data_password) != OK:
#		return
#	var data = file.get_var()
#	file.close()
#	if typeof(data) != TYPE_DICTIONARY:
#		return
#
#	var saved_world_id = data.get("world_id", "world")
#	var current_world = get_parent()
#
#	if get_tree().network_peer != null:
#		# Online: never locally reparent into a new World instance --
#		# the server owns world instances; PlayerSpawner places us via RPC
#		# using this same saved_world_id. Only apply position if we're
#		# already in the world PlayerSpawner put us in.
#		if is_instance_valid(current_world) and "world_id" in current_world and current_world.world_id == saved_world_id:
#			if data.has("rotation"): rotation = data["rotation"]
#			if data.has("which_scene"): which_scene = data["which_scene"]
#			if data.has("character_rotation") and is_instance_valid(character): character.rotation = data["character_rotation"]
#			if data.has("turnable_rotation") and is_instance_valid(turnable): turnable.rotation = data["turnable_rotation"]
#			if data.has("cursor_visible"): cursor_visible = data["cursor_visible"]
#			if data.has("direction"): direction = data["direction"]
#			if data.has("position"): translation = data["position"]
#		yield(get_tree(), "physics_frame")
#		disableFallDamage()
#		ui_holder.visible = isLocalPlayer()
#		return
#
#	if is_instance_valid(current_world) and "world_id" in current_world and current_world.world_id != saved_world_id:
#		switchToSavedWorld(saved_world_id, data)
#		return
#
#	if data.has("rotation"): rotation = data["rotation"]
#	if data.has("which_scene"): which_scene = data["which_scene"]
#	if data.has("character_rotation") and is_instance_valid(character): character.rotation = data["character_rotation"]
#	if data.has("turnable_rotation") and is_instance_valid(turnable): turnable.rotation = data["turnable_rotation"]
#	if data.has("cursor_visible"): cursor_visible = data["cursor_visible"]
#	if data.has("direction"): direction = data["direction"]
#	if data.has("position"): translation = data["position"]
#
#	yield(get_tree(), "physics_frame")
#	disableFallDamage()
#	ui_holder.visible = isLocalPlayer()

func switchToSavedWorld(saved_world_id:String, data:Dictionary) -> void:
	if !WorldRegistry.isKnownWorldId(saved_world_id):
		return
	var target_scene_path = WorldRegistry.getScenePath(saved_world_id)
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
	for child in node.get_children():
		if child is Camera:
			child.current = true
		_forceLocalCameraCurrent(child)
func _forceCamerasNotCurrent(node) -> void:
	for child in node.get_children():
		if child is Camera:
			child.current = false
		_forceCamerasNotCurrent(child)

var portal_grace_timer = 10
func loadCharacterData()->void:
	var file = File.new()
	if !file.file_exists("user://button_list.save"):
		return
	if file.open("user://button_list.save", File.READ) != OK:
		return
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("sexes") and typeof(data["sexes"]) == TYPE_DICTIONARY:
		var sexes:Dictionary = data["sexes"]
		if sexes.has(entity_name):
			stats.sex = sexes[entity_name]


	call_deferred("loadBoneData")
	call_deferred("loadHairData")
	yield(get_tree(),"idle_frame")
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

	var file = File.new()

	if !file.file_exists("user://button_list.save"):
		return

	if file.open("user://button_list.save", File.READ) != OK:
		return

	var data = file.get_var()
	file.close()

	if typeof(data) != TYPE_DICTIONARY:
		return

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

		basis = basis.scaled(Vector3(
			bone["scale"] * bone["width"],
			bone["scale"] * bone["height"],
			bone["scale"] * bone["depth"]
		))

		basis = basis.rotated(
			Vector3.UP,
			deg2rad(bone["rotation"])
		)

		currentSkeleton.set_bone_rest(
			boneIndex,
			Transform(
				basis,
				rest.origin + position
			)
		)
func loadHairData()->void:
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")

	var skeleton:Skeleton=get_node_or_null("character/root/Skeleton")
	if skeleton==null:
		return

	var file=File.new()
	if !file.file_exists("user://button_list.save"):
		return
	if file.open("user://button_list.save",File.READ)!=OK:
		return

	var data=file.get_var()
	file.close()

	if typeof(data)!=TYPE_DICTIONARY:
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

	for child in skeleton.get_children():
		if child.name=="Hair" or child.is_in_group("Hair"):
			child.free()

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

func loadBlendShapeData():
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")

	var skeleton=$character/root/Skeleton
	if skeleton==null:
		return

	if is_instance_valid(headInstance):
		headInstance.queue_free()

	var head=load("res://world/player/human/"+stats.sex+"/Head0.tscn")
	if head:
		headInstance=head.instance()
		headInstance.name="Head"
		skeleton.add_child(headInstance)

	yield(get_tree(),"idle_frame")

	var file=File.new()
	if !file.file_exists("user://button_list.save"):
		return

	if file.open("user://button_list.save",File.READ)!=OK:
		return

	var data=file.get_var()
	file.close()

	if typeof(data)!=TYPE_DICTIONARY:
		return

	if !data.has("blend_shapes") or !data["blend_shapes"].has(entity_name):
		return

	var shapes=data["blend_shapes"][entity_name]

	if typeof(shapes)!=TYPE_DICTIONARY:
		return

	var meshes=[]
	findBlendMeshes(skeleton,meshes)

	for key in shapes:
		var parts=str(key).split("_",false,1)

		if parts.size()!=2:
			continue

		var bodyPart=parts[0]
		var shape=parts[1]
		var value=float(shapes[key])

		for mesh in meshes:
			var isHead="head" in mesh.name.to_lower()

			if bodyPart=="Head" and !isHead:
				continue
			if bodyPart=="Body" and isHead:
				continue

			for i in range(mesh.mesh.get_blend_shape_count()):
				if mesh.mesh.get_blend_shape_name(i)==shape:
					mesh.set("blend_shapes/"+shape,value)
					break
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

	var file=File.new()
	if !file.file_exists("user://button_list.save"):
		return
	if file.open("user://button_list.save",File.READ)!=OK:
		return

	var data=file.get_var()
	file.close()

	if typeof(data)!=TYPE_DICTIONARY:
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

	var material_path="res://world/player/human/"+stats.sex+"/materials/Head0.tres"
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


func replenishHealth()->void:
	if is_in_combat == false:
		stats.regenerations()
		if movement_mode == "idle":
			stats.regenerations()
