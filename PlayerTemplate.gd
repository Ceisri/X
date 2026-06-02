extends KinematicBody
onready var player_mesh = $character
onready var animation = $character/AnimationPlayer
onready var character = $character
onready var equipment =$UI/Equipment
onready var stats =$Stats
onready var camroot = $Camroot
onready var camera_v = $Camroot/h/v
onready var skillbar = $UI/Skillbar
onready var loot = $UI/Loot

var save_id = "player"
var entity_name = "Victor"

export var gravity = 9.8 
export var jump_force = 9
export var walk_speed = 6
export var run_speed = 18
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

var cursor_visible = false

func _ready(): # Camera based Rotation
	for child in $UI/Skillbar/GridContainer.get_children():
		child.get_node("Slot").player = self
		child.parent = self 
		child.get_node("Slot").loadData()
	direction = Vector3.BACK.rotated(Vector3.UP, $Camroot/h.global_transform.basis.get_euler().y)
	
func _physics_process(delta):
	if cursor_visible == false:
		combatInputs()
		jump()
		movement(delta)
		dash()
		
	if !movement_mode == "idle":
		loot.closeLoot()
	animationOrder()
	
	
	
	if Input.is_action_just_pressed("entity_debug"):
		$UI/CrossairInspect/Debug.visible = !$UI/CrossairInspect/Debug.visible 
	if Input.is_action_just_pressed("character"):
		equipment.visible = !equipment.visible
	if Engine.get_physics_frames() % 3 == 0:
		equipment.updateEquipment()
	if Engine.get_physics_frames() % 60 == 0:
		$UI/CrossairInspect.crossairInspect(self)
		$UI/Menu/CharacterBar.updateBars()
		stats.health = stats.regenerate(stats.derived_stats["health_regeneration"],stats.health,stats.max_health)
	if Engine.get_physics_frames() % 120 == 0:
		equipment.updateEquipment()
	var on_floor = is_on_floor() # State control for is jumping/falling/landing
	
	movement_speed = 0
	acceleration = 15

	if not is_on_floor(): vertical_velocity += Vector3.DOWN * gravity * 2 * delta
	else: vertical_velocity = -get_floor_normal() * gravity / 3


var moving:bool = false
var movement_mode:String = "idle"
var previous_movement_mode:String = "idle"

var effective_turn_speed:float 
func movement(delta)->void:
	effective_turn_speed = base_turn_speed

	# slow during attack
	if anim_locks["base_atk"]:
		if is_dashing:
			effective_turn_speed *= dash_turn_multiplier
		else:
			effective_turn_speed *= 0.3

	# faster during dash (scaled by power)
	if is_dashing:
		effective_turn_speed *= dash_turn_multiplier
		
	previous_movement_mode = movement_mode
	movement_mode = "idle"

	var input_direction = Vector3(
		Input.get_action_strength("left") - Input.get_action_strength("right"),
		0,
		Input.get_action_strength("forward") - Input.get_action_strength("backward")
	)

	var movement_input = input_direction.length() > 0

	if anim_locks["stop_run"] and movement_input:
		anim_locks["stop_run"] = false

	var locked = false

	for anim_name in anim_locks.keys():
		if anim_name == "jump" or anim_name == "stop_run":
			continue

		if anim_locks[anim_name]:
			locked = true
			break

	var h_rot = camera_v.global_transform.basis.get_euler().y

	movement_speed = 0
	moving = false


	# ----------------------------
	if movement_input:
		direction = input_direction.rotated(Vector3.UP, h_rot).normalized()
	else:
		if !locked:
			direction = Vector3.ZERO

	if !locked:
		if movement_input:
			moving = true
			movement_mode = "walk"

			if Input.is_action_pressed("sprint"):
				movement_speed = run_speed
				movement_mode = "run"
			else:
				if previous_movement_mode == "run":
					anim_locks["stop_run"] = true

				movement_speed = walk_speed
		else:
			if previous_movement_mode == "run":
				anim_locks["stop_run"] = true

			moving = false
			movement_mode = "idle"
			direction = Vector3.ZERO
	else:
		moving = false
		movement_mode = "idle"
		movement_speed = 0

	# ----------------------------
	# ROTATION (uses updated direction)
	# ----------------------------
	if anim_locks["base_atk"] or !locked:
		if Input.is_action_pressed("aim"):
			player_mesh.rotation.y = lerp_angle(
				player_mesh.rotation.y,
				$Camroot/h.rotation.y,
				delta * effective_turn_speed
			)
		elif direction != Vector3.ZERO:
			player_mesh.rotation.y = lerp_angle(
				player_mesh.rotation.y,
				atan2(direction.x, direction.z) - rotation.y,
				delta * effective_turn_speed
			)
			$Area.rotation.y = player_mesh.rotation.y

	physics(delta)



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




func physics(delta)->void:

	if is_dashing:

		dash_time += delta
		dash_timer -= delta

		var dash_dir = direction.normalized()

		# -------------------------
		# PHASE 0: STARTUP (10%)
		# -------------------------
		if dash_phase == 0:
			dash_current_speed = dash_start_speed

			if dash_time >= dash_start_delay:
				dash_phase = 1
				dash_time = 0.0

		# -------------------------
		# PHASE 1: SHORT DELAY (hold speed)
		# -------------------------
		elif dash_phase == 1:
			dash_current_speed = dash_start_speed

			if dash_time >= 0.05:
				dash_phase = 2
				dash_time = 0.0

		# -------------------------
		# PHASE 2: FAST ACCELERATION TO FULL POWER
		# -------------------------
		elif dash_phase == 2:
			dash_current_speed = lerp(
				dash_current_speed,
				dash_max_power,
				12.0 * delta
			)

		# apply movement
		horizontal_velocity = dash_dir * dash_current_speed

		if dash_timer <= 0.0:
			is_dashing = false
			dash_phase = 0
			dash_turn_multiplier = 1.0

	else:
		horizontal_velocity = horizontal_velocity.linear_interpolate(
			direction.normalized() * movement_speed,
			acceleration * delta
		)

	movement.z = horizontal_velocity.z + vertical_velocity.z
	movement.x = horizontal_velocity.x + vertical_velocity.x
	movement.y = vertical_velocity.y

	move_and_slide(movement, Vector3.UP)
	
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
		
		anim_locks["dodge"] = true
		propulsion(dash_power)
		guarding =false

		last_dash_input = ""
		last_dash_time = 0

	else:
		last_dash_input = current_input
		last_dash_time = time


var weapons:String = "none"
var anim_locks = {
	"base_atk":false,
	"block":false,
	"block_react":false,
	"dodge":false,
	"cleave":false,
	"cleave_con":false,
	"battlecry":false,
	"dash":false,
	"jump":false,
	"stop_run":false,
	"parry":false,
	"sit":false,
	"stop_sit":false,
	"scream":false,
	"die":false,
	"prepare":false,
	"staggered":false}
func unlockAnim():
	for key in anim_locks:
		anim_locks[key] = false
	current_skill = ""



var guarding:bool = false
func combatInputs()->void:
	if Input.is_action_pressed("rclick"):
		unlockAnim()
		guarding =true
	elif Input.is_action_pressed("click"):
		guarding = false
		anim_locks["base_atk"] =true
	else:
		guarding = false

var can_cleav_cont:bool = false


var blend = 0.125

var anim_lock_exceptions = {
	"cleave": "cleave_1h",
	"cleave_con": "cleave_continue_1h",
}
var current_skill = ""

func animationOrder() -> void:
	var attack_speed = stats.derived_stats["attack_speed"]
	if !is_on_floor():
		animation.play("idle_fall", blend)
	else:
		if anim_locks["dodge"] == true:
			animation.play("slide", blend)	
		elif anim_locks["block_react"] == true:
			animation.play("block_react", blend)
		elif anim_locks["cleave"] == true:
			current_skill = "cleave"
			match weapons:
				"none":
					animation.play("Tpose", blend)
				"two handed":
					animation.play("cleave_2h", blend,attack_speed)
				"one handed":
					animation.play("cleave_1h", blend,attack_speed)
		elif anim_locks["battlecry"]:
			current_skill = "battlecry"
			animation.play("battlecry", blend)
		elif guarding == true:
			animation.play("idle_block", blend)
			current_skill = "block"
		elif anim_locks["base_atk"] == true:
			current_skill = "base_atk"
			match weapons:
				"none":
					animation.play("Tpose", blend)
				"two handed":
					animation.play("cleave_2h", blend,attack_speed)
				"one handed":
					animation.play("cleave_1h", blend,attack_speed)
		
		elif moving:
			current_skill = "none"
			if movement_mode == "run":
				camroot.updateCameraRunShake(get_physics_process_delta_time())
				animation.play("run_cycle", 0, stats.agility)
			elif movement_mode == "walk":
				animation.play("walk_cycle")
		else:
			animation.play("idle_cycle", blend)
			current_skill = "none"


func jump()->void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		vertical_velocity = Vector3.UP * jump_force
		unlockAnim()
		anim_locks["jump"] = true
		
		guarding =false


