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
var angular_acceleration = int()
var acceleration = int()
var can_move= true


var anim_locks = {
	"cleave":false,
	"battlecry":false,
	"dodge":false,
	
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



func _physics_process(delta):
	if !movement_mode == "idle":
		loot.closeLoot()
	animationOrder()
	jump()
	movement(delta)
	dig()
	attack()
	dash()
	if Input.is_action_just_pressed("character"):
		equipment.visible = !equipment.visible
		stats.health -= 10
		stats.arcane -= 4
	if Engine.get_physics_frames() % 4000 == 0:
		saveInventoryData()
	if Engine.get_physics_frames() % 3 == 0:
		equipment.updateEquipment()
		$UI.crossairInspect(self)
	if Engine.get_physics_frames() % 120 == 0:
		equipment.updateEquipment()
	mouseMode()
	var on_floor = is_on_floor() # State control for is jumping/falling/landing
	
	movement_speed = 0
	angular_acceleration = 10
	acceleration = 15

	if not is_on_floor(): vertical_velocity += Vector3.DOWN * gravity * 2 * delta
	else: vertical_velocity = -get_floor_normal() * gravity / 3


var moving:bool = false
var movement_mode:String = "idle"
var previous_movement_mode:String = "idle"

func movement(delta)->void:
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

	if !locked:
		if movement_input:
			direction = input_direction.rotated(Vector3.UP,h_rot).normalized()

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

		if Input.is_action_pressed("aim"):
			player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y,$Camroot/h.rotation.y,delta * angular_acceleration)
		elif direction != Vector3.ZERO:
			player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y,atan2(direction.x,direction.z) - rotation.y,delta * angular_acceleration)
	else:
		moving = false
		movement_mode = "idle"
		direction = Vector3.ZERO

	horizontal_velocity = horizontal_velocity.linear_interpolate(direction.normalized() * movement_speed,acceleration * delta)

	movement.z = horizontal_velocity.z + vertical_velocity.z
	movement.x = horizontal_velocity.x + vertical_velocity.x
	movement.y = vertical_velocity.y

	move_and_slide(movement,Vector3.UP)



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

		last_dash_input = ""
		last_dash_time = 0

	else:
		last_dash_input = current_input
		last_dash_time = time


func propulsion(power):
	horizontal_velocity = direction * power







var blend = 0.125
func animationOrder()->void:
	for anim_name in anim_locks.keys():
		if anim_locks[anim_name]:
			if animation.current_animation != anim_name:
				if animation.has_animation(anim_name):
					animation.play(anim_name,blend)
				else:
					print("Missing animation: ",anim_name)
					animation.play("land",blend)
			return
	if !is_on_floor():
		animation.play("fall",blend)
	elif moving:
		if movement_mode == "run":
			animation.play("run_cycle",0,stats.agility)
		elif movement_mode == "walk":
			animation.play("walk_cycle")
	else:
		animation.play("idle_cycle",blend)
		
		
		
































func jump()->void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		vertical_velocity = Vector3.UP * jump_force
		anim_locks["jump"] = true












onready var ray = $Camroot/h/v/Camera/RayCast
func attack():
	if Input.is_action_just_pressed("click"):
		if ray.is_colliding():
			var body = ray.get_collider()
			if body.is_in_group("Entity") and body != self:
				body.getHit(self,7)
				body.anim_locks["staggered"] = true
				body.stats.nutrition -= 10 
func dig():
	var cut = $Camroot/h/v/Camera/RayCast/cut
	if Input.is_action_just_pressed("rclick") and ray.is_colliding():
		var hit_pos = ray.get_collision_point()
		var normal = ray.get_collision_normal()
		var body = ray.get_collider()
		if body is CSGMesh:
			var instance = cut.duplicate()
			body.sub.add_child(instance)
			instance.visible = true
			instance.scale = cut.scale/body.scale
			instance.material = body.material
			instance.global_transform.origin = hit_pos-normal*cut.width*cut.scale.x*0.5
			instance.look_at(hit_pos+normal,Vector3.UP)

func getHit(attacker: Node, damage: float) -> void:
	stats.health -= damage
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
