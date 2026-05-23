extends KinematicBody


var save_id = "player"
onready var stats =$Stats
onready var camroot = $Camroot



# Allows to pick your animation tree from the inspector
export (NodePath) var PlayerAnimationTree 
export onready var animation_tree = get_node(PlayerAnimationTree)

onready var player_mesh = $character
onready var character = $character

# Gamplay mechanics and Inspector tweakables
export var gravity = 9.8
export var jump_force = 9
export var walk_speed = 6
export var run_speed = 18
export var dash_power = 30 # Controls roll and big attack speed boosts

# Animation node names
var roll_node_name = "Roll"
var idle_node_name = "Idle"
var walk_node_name = "Walk"
var run_node_name = "Run"
var jump_node_name = "Jump"
var attack1_node_name = "Attack1"
var attack2_node_name = "Attack2"
var bigattack_node_name = "BigAttack"

# Condition States
var is_attacking = bool()
var is_rolling = bool()
var is_walking = bool()
var is_running = bool()
var is_moving = bool()

# Physics values
var direction = Vector3()
var horizontal_velocity = Vector3()
var aim_turn = float()
var movement = Vector3()
var vertical_velocity = Vector3()
var movement_speed = int()
var angular_acceleration = int()
var acceleration = int()

func _ready(): # Camera based Rotation
	direction = Vector3.BACK.rotated(Vector3.UP, $Camroot/h.global_transform.basis.get_euler().y)

func _input(event): # All major mouse and button input events
	if event is InputEventMouseMotion:
		aim_turn = -event.relative.x * 0.015 # animates player with mouse movement while aiming 
	
#	if event.is_action_pressed("aim"): # Aim button triggers a strafe walk and camera mechanic
#		direction = $Camroot/h.global_transform.basis.z
	if event.is_action_pressed("attack"):
		attack()

func callAnimAllLock()->void:
	for key in anim_locks:
		anim_locks[key] = false
		
		
var anim_locks = {
	"stop_run":false,
	"parry":false,
	"scream":false
}

func _physics_process(delta):
	if Engine.get_physics_frames() % 3 == 0:
		$UI.crossairInspect(self)
		attack()
	
	
	var animation_player
	if is_instance_valid($character):
		animation_player = $character/AnimationPlayer
		animation_player.animationOrder(self,stats)

	var on_floor = is_on_floor() # State control for is jumping/falling/landing
	var h_rot = $Camroot/h.global_transform.basis.get_euler().y
	
	movement_speed = 0
	angular_acceleration = 10
	acceleration = 15

	# Gravity mechanics and prevent slope-sliding
	if not is_on_floor(): 
		vertical_velocity += Vector3.DOWN * gravity * 2 * delta
	else: 
		vertical_velocity = -get_floor_normal() * gravity / 3

#	Jump input and Mechanics
	if Input.is_action_just_pressed("jump") and ((is_attacking != true) and (is_rolling != true)) and is_on_floor():
		vertical_velocity = Vector3.UP * jump_force
		
	if (Input.is_action_pressed("forward") || Input.is_action_pressed("backward") || Input.is_action_pressed("left") || Input.is_action_pressed("right")):

		direction = Vector3(
			Input.get_action_strength("left") - Input.get_action_strength("right"),
			0,
			Input.get_action_strength("forward") - Input.get_action_strength("backward")
		)

		direction = direction.rotated(Vector3.UP,h_rot).normalized()

		is_walking = true
		is_moving = true

		if Input.is_action_pressed("sprint") and is_walking == true:

			movement_speed = run_speed
			is_running = true
			is_moving = true

		else:

			if is_running:
				anim_locks["stop_run"] = true

			movement_speed = walk_speed
			is_running = false

	else:

		if is_running:
			anim_locks["stop_run"] = true

		is_walking = false
		is_running = false
		is_moving = false
		
	if Input.is_action_pressed("aim"):  # Aim/Strafe input and  mechanics
		player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, $Camroot/h.rotation.y, delta * angular_acceleration)

	else: # Normal turn movement mechanics
		player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, atan2(direction.x, direction.z) - rotation.y, delta * angular_acceleration)
	
	# Movment mechanics with limitations during rolls/attacks
	if ((is_attacking == true) or (is_rolling == true)): 
		horizontal_velocity = horizontal_velocity.linear_interpolate(direction.normalized() * .01 , acceleration * delta)
	else: # Movement mechanics without limitations 
		horizontal_velocity = horizontal_velocity.linear_interpolate(direction.normalized() * movement_speed, acceleration * delta)
	
	# The Physics Sauce. Movement, gravity and velocity in a perfect dance.
	movement.z = horizontal_velocity.z + vertical_velocity.z
	movement.x = horizontal_velocity.x + vertical_velocity.x
	movement.y = vertical_velocity.y
	move_and_slide(movement, Vector3.UP)


onready var ray = $Camroot/h/v/Camera/RayCast
func attack():
	if Input.is_action_just_pressed("click"):
		if ray.is_colliding():
			var body = ray.get_collider()
			if body.is_in_group("Entity") and body != self:
				body.getHit(self,7)
				body.anim_locks["staggered"] = true
				body.stats.nutrition -= 10 
		
