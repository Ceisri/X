#TODO CREATE A LIST OF ANIM_LOCKS, PREFERABLY A BOOL DIRECTLY IN PLAYERSKILLS TO SELECT WHICH SKILL LOCKS OR NOT ROTATION

extends KinematicBody
onready var player_mesh = $character
onready var animation =  $character/AnimationPlayer
onready var anim_calls = $AnimationCalls
onready var character = $character
onready var equipment =$UI/Equipment
onready var skeleton = $character/root/Skeleton
onready var stats =$Stats
onready var camroot = $Camroot
onready var camera_v = $Camroot/h/v
onready var camera_h = $Camroot/h
onready var skillbar = $UI/Skillbar
onready var loot = $UI/Loot
onready var inventory = $UI/Inventory
onready var turnable:Spatial = $Turnable
var save_id = "player"
var entity_name = "Victor"
export var gravity = 9.8 
export var walk_speed = 6
export var dash_power = 50 
# Physics values
var direction = Vector3()
var horizontal_velocity = Vector3()
var aim_turn = float()
var movement = Vector3()
var vertical_velocity = Vector3()
var movement_speed = int()
var angular_acceleration:int = 5
var acceleration = int()
var can_move= true
var is_carrying = false
var cursor_visible = false
var is_swimming:bool = false
var wall_incline
var is_on_stairs: bool = false
var wall_hanging:bool = false
onready var head_ray = $Turnable/Vault
onready var climb_ray = $Turnable/MidRay
onready var stair_check: RayCast = $Turnable/Stairs
onready var root_bone = skeleton.find_bone("ik_foot_root")
var root_motion_active := false
var last_root_pos := Vector3.ZERO
var root_motion_velocity := Vector3.ZERO
var _last_root_motion_pos := Vector3.ZERO
var is_climbing := false
onready var animation_tree:AnimationTree = $AnimationTree
enum WeaponMode {
	NONE,
	SWORD,
	DUAL,
	SHIELD,
	TWO_HANDED
}
var weapons:int = WeaponMode.NONE


var rotation_disabled_anims = [
	"battlecry",
	"block_react",
	"staggered",
	"die"
]

func _ready():
	for child in $UI/Skillbar/GridContainer.get_children():
		child.get_node("Slot").player=self
		child.get_node("TextureButton").parent=self
		child.get_node("Slot").loadData()

	direction=Vector3.BACK.rotated(Vector3.UP,$Camroot/h.global_transform.basis.get_euler().y)


var interrupt_groups = {
	"hard_interrupt":["dodge","block","parry"],
	"skills":["section","perforation trifecta","cleave","battlecry","scream","overhead strike"],
	"base_attack":["base attack"]
}
func activateAnimLock(lock_name:String)->void:
	if !anim_locks.has(lock_name):
		return

	# Hard interrupts
	if lock_name in interrupt_groups["hard_interrupt"]:
		unlockAnim()
		anim_locks[lock_name] = true
		current_skill = lock_name
		return

	# Skills
	if lock_name in interrupt_groups["skills"]:
		anim_locks["base attack"] = false

		for skill in interrupt_groups["skills"]:
			anim_locks[skill] = false

		anim_locks[lock_name] = true
		current_skill = lock_name
		return

	# Base attack
	if lock_name == "base attack":

		# Cannot start while a skill is active
		for skill in interrupt_groups["skills"]:
			if anim_locks[skill]:
				return

		# Cannot start while a hard interrupt is active
		for interrupt in interrupt_groups["hard_interrupt"]:
			if anim_locks[interrupt]:
				return

		anim_locks["base attack"] = true
		current_skill = lock_name

var anim_locks = { #This becomes faster and more modular and automatic if all anim locks match name with skills from PlayerSkills.gd
	"base attack":false,
	"overhead strike":false,
	"section":false,
	"perforation trifecta":false,
	"block":false,
	"block_react":false,
	"dodge":false,
	"cleave":false,
	"cleave_con":false,
	"battlecry":false,
	"dash":false,
	"stop_run":false,
	"parry":false,
	"sit":false,
	"stop_sit":false,
	"scream":false,
	"die":false,
	"prepare":false,
	"staggered":false}
var current_skill:String = "none"




var skill_animations = {
	"base attack":{
		WeaponMode.NONE:["punch1","punch2","punch3"],
		WeaponMode.SWORD:["1h_Baseatk1","1h_Baseatk2","1h_Baseatk3"],
		WeaponMode.DUAL:["1h_Baseatk1","1h_Baseatk2","1h_Baseatk3"],
		WeaponMode.SHIELD:["1h_Baseatk1","1h_Baseatk2","1h_Baseatk3"],
		WeaponMode.TWO_HANDED:["2h_Baseatk1","2h_Baseatk2","2h_Baseatk3"],
	},
	"overhead strike":{
		WeaponMode.NONE:"1h_OverheadStrike",
		WeaponMode.SWORD:"1h_OverheadStrike",
		WeaponMode.DUAL:"1h_OverheadStrike",
		WeaponMode.SHIELD:"1h_OverheadStrike",
		WeaponMode.TWO_HANDED:"1h_OverheadStrike",
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
		WeaponMode.NONE:"ALL_SwordGuard_cycle",
		WeaponMode.SWORD:"ALL_SwordGuard_cycle",
		WeaponMode.DUAL:"ALL_SwordGuard_cycle",
		WeaponMode.SHIELD:"ALL_SwordGuard_cycle",
		WeaponMode.TWO_HANDED:"ALL_SwordGuard_cycle",
	},
}

var last_skill_animation=""
onready var skill_anim = animation_tree.tree_root.get_node("Skill")

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

var last_active_skill := ""

func setSkillAnimation(skill_name:String)->void:
	if !skill_animations.has(skill_name):
		return

	var skill_data = skill_animations[skill_name]
	var new_anim = ""

	if skill_data.has(weapons):

		if skill_name == "base attack":
			var combo_anims = skill_data[weapons]

			match combo_sequence:
				1:new_anim = combo_anims[0]
				2:new_anim = combo_anims[1]
				3:new_anim = combo_anims[2]
				_:new_anim = combo_anims[0]
		else:
			new_anim = skill_data[weapons]

	else:
		anim_locks[skill_name] = false
		current_skill = "none"
		skillbar.reimburseSkill(skill_name)
		return

	if new_anim == "":
		anim_locks[skill_name] = false
		current_skill = "none"
		skillbar.reimburseSkill(skill_name)
		return

	# Same skill still active this frame.
	# Do nothing.
	if skill_name == last_active_skill:
		return

	last_active_skill = skill_name

	skill_anim.animation = new_anim

	animation_tree.active = false
	animation_tree.active = true






func get_active_anim_lock()->String:
	for lock_name in anim_locks:
		if anim_locks[lock_name]:
			return lock_name
	return ""
	

var movement_blend := -1.0
var combat_blend := -1.0
var attack_defend_switch := 0.0

var movement_type_blend := 0.0
var vertical_blend := 0.0
var crouch_blend := 1.0
var crouch_mode_blend := 0.0
var climb_blend := 0.0
var water_blend := 0.0

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
func setAnimBlend(path:String, target:float, speed:float, delta:float)->void:
	var current := 0.0

	if anim_blend_cache.has(path):
		current = anim_blend_cache[path]

	current = move_toward(current, target, delta * speed)
	anim_blend_cache[path] = current

	animation_tree.set(path, current)


# ------------------------------------------------------------
# animationOrder
# Central animation state resolver.
# Handles:
# - Combat vs movement blending
# - Skill activation blending
# - Base attack combo sequencing
# - Movement state transition
# Base attack behavior:
# - Treated as a 3-step combo sequence
# - combo_sequence (1 → 2 → 3) selects which animation slot
#   inside the Base Attack skill animation list is played
# - All transitions between combo steps are driven by
#   AnimationTree blend parameter "BaseATKSwitch"
# - Attack speed scales playback via SkillTimeScale
# Smoothing control:
# - Combat and movement use separate interpolation speeds
# - Increasing speed = more responsive but sharper transitions
# - Lower speed = smoother but more delayed transitions
# ------------------------------------------------------------
func animationOrder()->void:
	animation_tree.active = true

	var delta := get_process_delta_time()
	var active_lock := get_active_anim_lock()

	# --------------------------------------------------------
	# COMBAT / SKILL STATE
	# --------------------------------------------------------
	if active_lock != "" and skill_animations.has(active_lock):

		setSkillAnimation(active_lock)

		# Enter combat state smoothly
		setAnimBlend("parameters/CombatSwitch/blend_amount", 1.0, 10.0, delta)
		setAnimBlend("parameters/MeleeSkillSwitch/blend_amount", 1.0, 10.0, delta)

		# ----------------------------------------------------
		# BASE ATTACK COMBO SYSTEM
		# ----------------------------------------------------
		# Base attack is a chained sequence of 3 animations:
		#
		# combo_sequence = 1 → first attack animation
		# combo_sequence = 2 → second attack animation
		# combo_sequence = 3 → finisher attack animation
		#
		# The AnimationTree uses a BlendSpace/StateSwitch node
		# ("BaseATKSwitch") to transition between these phases.
		#
		# This value should NOT snap instantly in gameplay logic;
		# instead it is smoothed here to avoid visual stepping.
		#
		if active_lock == "base attack":
			animation_tree.set("parameters/SkillTimeScale/scale",stats.derived_stats["attack_speed"])

			var combo_target := 0.0

			match combo_sequence:
				1: combo_target = -1.0
				2: combo_target = 0.0
				3: combo_target = 1.0

			# Separate smoothing control for combo transitions
			# Lower speed = heavier, slower-feeling combo chaining
			# Higher speed = snappy responsive combos
			setAnimBlend("parameters/BaseATKSwitch/blend_amount", combo_target,8, delta)

	else:
		last_active_skill = ""
		# Exit combat state smoothly
		setAnimBlend("parameters/CombatSwitch/blend_amount", 0.0, 10.0, delta)
		setAnimBlend("parameters/MeleeSkillSwitch/blend_amount", 0.0, 10.0, delta)
		
		# --------------------------------------------------------
		# MOVEMENT TARGET STATE RESOLUTION
		# --------------------------------------------------------
		var movement_target := -1.0
		var movement_type_target := 0.0
		var vertical_target := 0.0
		var crouch_target := 1.0
		var crouch_mode_target := 0.0
		var climb_target := 0.0
		var water_target := 0.0

		if is_airborne and !is_climbing and !is_swimming:
			movement_type_target = 1.0
			vertical_target = 1.0
		else:
			match movement_mode:
				"idle":
					if !Input.is_action_just_pressed("click") or !Input.is_action_pressed("click") or current_skill == "none" or current_skill == "":
						movement_target = -1.0

						if is_in_combat:
							setAnimBlend("parameters/IsInCombat/blend_amount", 1.0, 10.0, delta)
						else:
							setAnimBlend("parameters/IsInCombat/blend_amount", 0.0, 10.0, delta)

				"walk":
					movement_target = 0.0

				"run":
					movement_target = 1.0
					animation_tree.set("parameters/RunSpeed/scale",0.8 + (0.0125 * stats.derived_stats["run_speed"]))
				"crouch_idle":
					crouch_target = 0.0
					crouch_mode_target = 0.0

				"crouch_moving":
					crouch_target = 0.0
					crouch_mode_target = 1.0

				"climb":
					movement_type_target = 1.0
					vertical_target = 0.0
					climb_target = 0.0

				"vault":
					movement_type_target = 1.0
					vertical_target = 0.0
					climb_target = 1.0

				"swimming":
					movement_type_target = -1.0
					water_target = 1.0
					animation_tree.set("parameters/SwimSpeed/scale",0.97 + (0.03 * stats.derived_stats["swim_speed"]))
				"treading water":
					movement_type_target = -1.0
					water_target = 0.0

		# --------------------------------------------------------
		# MOVEMENT BLENDING (all interpolated)
		# --------------------------------------------------------
		setAnimBlend("parameters/Movement/blend_amount", movement_target, 8.0, delta)
		setAnimBlend("parameters/MovementType/blend_amount", movement_type_target, 8.0, delta)
		setAnimBlend("parameters/Vertical/blend_amount", vertical_target, 8.0, delta)

		setAnimBlend("parameters/CrouchOrNot/blend_amount", crouch_target, 8.0, delta)
		setAnimBlend("parameters/CrouchMode/blend_amount", crouch_mode_target, 8.0, delta)
		setAnimBlend("parameters/climbPoint/blend_amount", climb_target, 8.0, delta)
		setAnimBlend("parameters/Water/blend_amount", water_target, 8.0, delta)


var combo_sequence:int = 1
var combo_timer:float = 60.0
func combatInputs()->void:
	if anim_locks["base attack"] == false:
		combo_timer = max(combo_timer - 1.0, 0.0)
	if anim_locks["parry"] == true:
		guarding = true
		

export var root_motion_scale:float = 0.01
func rootMotion(delta)->void:
	var motion:Transform = animation_tree.get_root_motion_transform()
	var offset:Vector3 = motion.origin
	offset.y = 0.0
	if offset.length_squared() < 0.000001:
		return
	offset *= root_motion_scale
	offset = player_mesh.global_transform.basis.xform(offset)
	move_and_slide(Vector3(offset.x / delta, vertical_velocity.y, offset.z / delta),Vector3.UP)

func physics(delta):
	if root_motion_active:
		vertical_velocity += Vector3.DOWN * gravity * delta
		move_and_slide(vertical_velocity, Vector3.UP)
		return
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
		elif dash_phase == 2:dash_current_speed = lerp(dash_current_speed,dash_max_power,12.0 * delta)
		horizontal_velocity = dash_dir * dash_current_speed
		if dash_timer <= 0.0:
			is_dashing = false
			dash_phase = 0
			dash_turn_multiplier = 1.0
	else:horizontal_velocity = horizontal_velocity.linear_interpolate(direction.normalized() * movement_speed,acceleration * delta)
	movement.z = horizontal_velocity.z + vertical_velocity.z
	movement.x = horizontal_velocity.x + vertical_velocity.x
	movement.y = vertical_velocity.y
	move_and_slide(movement, Vector3.UP)


func _process(delta):
	animationOrder()

func _physics_process(delta):
	if Input.is_action_just_pressed("0"):
		$character/root/Skeleton/Mesh.visible = !$character/root/Skeleton/Mesh.visible
	$Label.text = """
active_lock=%s
current_skill=%s

base_attack=%s
cleave=%s
section=%s
perforation=%s
parry=%s

combo_seq=%s
combo_timer=%s

CombatSwitch=%s
MeleeSkillSwitch=%s
BaseATKSwitch=%s

movement_mode=%s
current_anim=%s
""" % [
	get_active_anim_lock(),
	current_skill,

	anim_locks["base attack"],
	anim_locks["cleave"],
	anim_locks["section"],
	anim_locks["perforation trifecta"],
	anim_locks["parry"],

	combo_sequence,
	combo_timer,

	animation_tree.get("parameters/CombatSwitch/blend_amount"),
	animation_tree.get("parameters/MeleeSkillSwitch/blend_amount"),
	animation_tree.get("parameters/BaseATKSwitch/blend_amount"),

	movement_mode,
	animation.current_animation
]
	if stored_body != null:
		is_in_combat = true
	rootMotion(delta)
	jump()
	movement(delta)
	climb()
	physics(delta)
	collisionShapesManager()
	if cursor_visible == false:
		combatInputs()
		dash()

	if !movement_mode == "idle":
		loot.closeLoot()
	if Input.is_action_just_pressed("entity_debug"):
		$UI/CrossairInspect/Debug.visible = !$UI/CrossairInspect/Debug.visible 
	if Input.is_action_just_pressed("character"):
		equipment.visible = !equipment.visible
	if Engine.get_physics_frames() % 3 == 0:
		equipment.updateEquipment()
	if Engine.get_physics_frames() % 35 == 0:
		if inventory.visible: if inventory.has_method("updateInventory"):inventory.updateInventory()
	if Engine.get_physics_frames() % 60 == 0:
		leaveCombatAutomatically()
		$UI/CrossairInspect.crossairInspect(self)
		$UI/Menu/CharacterBar.updateBars()
		stats.health = stats.regenerate(stats.derived_stats["health_regeneration"],stats.health,stats.max_health)
	if Engine.get_physics_frames() % 120 == 0:
		equipment.updateEquipment()
	if Engine.get_physics_frames() % 1200 == 0:
		stored_body == null
	var on_floor = is_on_floor() # State control for is jumping/falling/landing
	
	movement_speed = 0
	acceleration = 15

	if not is_on_floor(): vertical_velocity += Vector3.DOWN * gravity * 2 * delta
	else: vertical_velocity = -get_floor_normal() * gravity / 3
	checkFall()

var moving:bool = false
var movement_mode:String = "idle"
var previous_movement_mode:String = "idle"
var effective_turn_speed:float 

func is_rotation_locked() -> bool:
	for anim_name in rotation_disabled_anims:
		if anim_locks.has(anim_name) and anim_locks[anim_name]:
			return true
	return false
	
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
]
func clearMovementLocks()->void:
	for lock_name in movement_unlock_locks:
		if anim_locks.has(lock_name):
			anim_locks[lock_name] = false
func movement(delta) -> void:
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

	var input_direction = Vector3.ZERO

	# ==================================================
	# INPUT COLLECTION
	# ==================================================
	if can_move or !guarding:
		if Input.is_action_pressed("left") and !is_climbing:
			input_direction.x += 1
		elif Input.is_action_pressed("right") and !is_climbing:
			input_direction.x -= 1

		if Input.is_action_pressed("forward"):
			input_direction.z += 1
		elif Input.is_action_pressed("backward"):
			input_direction.z -= 1

	var movement_input = input_direction.length() > 0
	var crouching = Input.is_action_pressed("crouch")
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
				movement_speed = walk_speed * 0.5

			elif sprinting and !is_in_water:
				movement_speed = stats.derived_stats["run_speed"]
				movement_mode = "run"

			else:
				movement_mode = "walk"
				movement_speed = walk_speed

				# leaving sprint triggers stop_run lock
				if previous_movement_mode == "run":
					pass
					#anim_locks["stop_run"] = true

		else:
			if crouching:
				movement_mode = "crouch_idle"
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

	# ==================================================
	# WATER OVERRIDE STATE
	# ==================================================
	if is_in_water:
		if moving:
			movement_mode = "swimming"
			movement_speed = stats.derived_stats["swim_speed"]
		else:
			movement_mode = "treading water"

	# ==================================================
	# ROTATION HANDLING
	# ==================================================
	if !is_rotation_locked():
		if !is_climbing and direction != Vector3.ZERO and (!is_on_wall()
			or (climb_ray.is_colliding() and climb_ray.get_collider().is_in_group("Entity")
			or left_ray.is_colliding() or right_ray.is_colliding())):

			var target_rot = atan2(direction.x, direction.z) - rotation.y
			player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, target_rot, delta * angular_acceleration)
			turnable.rotation.y = lerp_angle(turnable.rotation.y, target_rot, delta * angular_acceleration)

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
var dash_turn_multiplier:float = 10
var dash_start_speed:float = 0.0
func propulsion(power):
	# Get the direction the mesh is looking
	direction = player_mesh.global_transform.basis.z
	direction.y = 0
	direction = direction.normalized()
	is_dashing = true
	dash_timer = dash_duration
	dash_time = 0.0
	dash_max_power = power
	dash_phase = 0
	dash_start_speed = power * 0.1
	dash_current_speed = dash_start_speed
	# TURN SPEED BOOST BASED ON POWER
	dash_turn_multiplier = 1.0 + (power / dash_power) * 1.5



var last_dash_input = ""
var last_dash_time = 0.0
var dash_double_press_time = 0.25
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
		propulsion(dash_power)
		guarding =false
		last_dash_input = ""
		last_dash_time = 0
	else:
		last_dash_input = current_input
		last_dash_time = time


func unlockAnim():
	for key in anim_locks:
		anim_locks[key] = false
	current_skill = ""



var guarding:bool = false
var attacking:bool = false
var is_in_combat:bool = false
onready var stored_body:KinematicBody = null
var stored_body_timer:int = 15
var combat_timer:int =0
func leaveCombatAutomatically()->void:
	if stored_body == null:
		if combat_timer > 0:
			combat_timer -= 1
			is_in_combat = true
		if combat_timer <= 0:
			is_in_combat = false


onready var left_ray:RayCast = $Turnable/Left
onready var right_ray:RayCast = $Turnable/Right
func climb() -> void:
	is_climbing = false
	var floor_hit = $RayCast.is_colliding()
	var climb_hit = climb_ray.is_colliding()
	var head_hit = head_ray.is_colliding()
	var left_hit = $Turnable/Left.is_colliding()
	var right_hit = $Turnable/Right.is_colliding()
	if is_in_combat:
		return
	if !floor_hit:
		if is_on_wall() and !head_hit and !is_on_floor() and !left_hit and !right_hit:
			var wall_normal = climb_ray.get_collision_normal()
			if wall_normal.y <= cos(deg2rad(85)):
				direction = -wall_normal
				player_mesh.rotation.y = atan2(direction.x, direction.z)
				turnable.rotation.y = player_mesh.rotation.y
				movement_mode = "vault"
				is_airborne = false
				horizontal_velocity = -wall_normal * walk_speed * stats.derived_stats["climb_speed"] 
				vertical_velocity = Vector3.UP * stats.derived_stats["climb_speed"] 
				return
		if is_on_wall() and climb_hit and head_hit and !left_hit and !right_hit and !is_on_floor():
			if Input.is_action_pressed("forward") or Input.is_action_pressed("left") or Input.is_action_pressed("right") or Input.is_action_pressed("back"):
				is_climbing = true
				is_airborne = false
				movement_mode = "climb"
				var wall_normal = climb_ray.get_collision_normal()
				var wall_right = wall_normal.cross(Vector3.UP).normalized()
				direction = -wall_normal
				player_mesh.rotation.y = atan2(direction.x, direction.z)
				turnable.rotation.y = player_mesh.rotation.y
				horizontal_velocity = Vector3.ZERO
				vertical_velocity = Vector3.UP * stats.derived_stats["climb_speed"]
		return


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
	if cursor_visible == false:
		if Input.is_action_just_pressed("jump") and is_on_floor():
			vertical_velocity = Vector3.UP * stats.derived_stats["jump_power"]
			unlockAnim()
			attacking = false
			guarding =false


func applyFallDamage(fall_distance: float):
	if fall_distance < 3.0:
		return
	var damage = (fall_distance - 3.0) * 5.0
	damage /= (1.0 + stats.derived_stats["fall_resistance"])
	stats.getHit(self,{stats.damage_type.blunt: damage},false,0.0,false)

var was_on_floor := true
var max_fall_speed := 0.0
var fall_start_y := 0.0
var is_falling := false
var highest_y:float = 0.0
var is_airborne:bool= false
export var safe_fall_speed := 12.0
export var fall_damage_multiplier := 2.0
func checkFall():
	if is_airborne and !is_climbing:
		movement_mode = "fall"
		
	var on_floor = is_on_floor()
	# Left ground
	if was_on_floor and !on_floor:
		is_airborne = true
		highest_y = global_transform.origin.y
	# Track highest point reached while is_airborne
	if is_airborne:
		highest_y = max(highest_y, global_transform.origin.y)
	# Landed
	if !was_on_floor and on_floor and is_airborne:
		var landing_y = global_transform.origin.y
		var fall_distance = highest_y - landing_y
		applyFallDamage(fall_distance)
		is_airborne = false
	was_on_floor = on_floor


var is_in_water:bool = false
var water_areas := []
func isWaterArea(area)->bool:
	var node = area
	while node:
		if node.is_in_group("Water") or node.is_in_group("water"):
			return true
		if node.name.to_lower() == "water":
			return true
		node = node.get_parent()
	return false

func _on_WaterLevelChest_area_shape_entered(area_rid, area, area_shape_index, local_shape_index):
	if isWaterArea(area):
		if !water_areas.has(area):
			water_areas.append(area)
		is_in_water = true

func _on_WaterLevelChest_area_shape_exited(area_rid, area, area_shape_index, local_shape_index):
	if water_areas.has(area):
		water_areas.erase(area)
	is_in_water = water_areas.size() > 0
