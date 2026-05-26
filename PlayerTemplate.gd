extends KinematicBody
export (NodePath) var PlayerAnimationTree 
onready var player_mesh = $character
onready var animation = $character/AnimationPlayer
onready var character = $character
onready var stats =$Stats
onready var camroot = $Camroot
onready var skillbar = $UI/Skillbar
var save_id = "player"
var entity_name = "Victor"

export var gravity = 9.8
export var jump_force = 9
export var walk_speed = 6
export var run_speed = 18
export var dash_power = 30 


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
var can_move= true



var anim_locks = {
	"cleave":false,
	"battlecry":false,
	"dodge":false,
	
	
	"stop_run":false,
	"parry":false,
	"sit":false,
	"stop_sit":false,
	"scream":false,
	"die":false,
	"prepare":false,
	"staggered":false
}



func saveInventoryData():
	# Call savedata() function on each child of inventory_grid that belongs to the group "Inventory"
	for child in $UI/Skillbar/GridContainer.get_children():
		if child.get_node("Slot").has_method("saveData"):
				child.get_node("Slot").saveData()
				


func _ready(): # Camera based Rotation
	for child in $UI/Skillbar/GridContainer.get_children():
		child.get_node("Slot").player = self
		child.parent = self 
		child.get_node("Slot").loadData()
	$Label3D.text = str(stats.health)
	direction = Vector3.BACK.rotated(Vector3.UP, $Camroot/h.global_transform.basis.get_euler().y)
	
func _input(event): # All major mouse and button input events
	if event is InputEventMouseMotion:
		aim_turn = -event.relative.x * 0.015 # animates player with mouse movement while aiming 
	
#	if event.is_action_pressed("aim"): # Aim button triggers a strafe walk and camera mechanic
#		direction = $Camroot/h.global_transform.basis.z
	if event.is_action_pressed("attack"):
		attack()

		
var cursor_visible = false
func mouseMode()-> void:
	if Input.is_action_just_pressed("ESC"):	# Toggle mouse mode
		cursor_visible =!cursor_visible
	if !cursor_visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	if Engine.get_physics_frames() % 60 == 0:
		saveInventoryData()
	if Engine.get_physics_frames() % 3 == 0:
		$UI.crossairInspect(self)
		attack()
	mouseMode()
	animation.animationOrder(self,stats)
	
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
				body.skillbar.anim_locks["staggered"] = true
				body.stats.nutrition -= 10 
		
		
func getHit(attacker: Node, damage: float) -> void:
	stats.health -= damage
	$Label3D.text = str(stats.health)
