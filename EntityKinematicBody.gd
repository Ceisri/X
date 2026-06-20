extends KinematicBody

onready var stats = $Stats
onready var combat = $Combat

onready var ray_forward =$RayForward
onready var ray_left = $RayFrontLeft
onready var ray_right = $RayFrontRight

onready var ray_wall_check = $RayWall
onready var ray_height_check = $RayHeight

onready var ray_down =$RayDown
onready var melee_ray =$RayMelee
onready var animation =$AnimationPlayer
onready var dmg_area = $AreaDamage

var stored_body:KinematicBody = null
var nav_path = []
var nav_index = 0
var wander_target = Vector3.ZERO

onready var nav = get_parent().get_node("Terrain")


var is_propelled:bool = false
var propulsion_timer:float = 0.0
var propulsion_duration:float = 0.25
var propulsion_velocity:Vector3 = Vector3.ZERO
var is_walking:bool = true
var is_running:bool = false
var is_sitting:bool = false
var is_swimming:bool = false
var is_dead:bool = false
var on_guard:bool = false 
var is_being_carried = false
var target: Node = null
var targets = []

class AggroTarget:
	var target_entity : Node
	var aggro : int
	
var melee_step = 1
var can_move:bool = true
var is_in_combat:bool = false
var current_skill:String = "combo attack"
var anim_locks = { 
	"combo attack":false,
	"downed":true,
	"get up":false,
	"downed die":false,
	"flinch":false,
	"knocked back":false,
	"atk1":false,
	"atk2":false,
	"atk3":false,
	"atk4":false,
	"atk5":false,
	"atk6":false,
	"dodge":false,
	"stop_run":false,
	"parry":false,
	"sit":false,
	"stop_sit":false,
	"scream":false,
	"die":false,
	"prepare":false,
	"staggered":false,
	
}





func _ready()->void:
	ignoreMobBodies()

func _physics_process(delta):
	animations()
	if is_being_carried == false:
		if Engine.get_physics_frames() % 2 == 0:
			CommonBehaviours.gravity(self)
			switchState()
func propulsion(power:float)->void:
	if !has_meta("dir"):
		return

	is_propelled = true
	propulsion_timer = propulsion_duration

	var dir = get_meta("dir")
	if dir == Vector3.ZERO:
		return

	propulsion_velocity = dir.normalized() * power

func ignoreMobBodies():
	for body in get_tree().get_nodes_in_group("Entity"):
		if body == self:
			continue

		if body.is_in_group("Player") or body.is_in_group("Boss"):
			continue

		if is_in_group("Player") or is_in_group("Boss"):
			continue

		add_collision_exception_with(body)
		body.add_collision_exception_with(self)
			
func switchState():
	if stats.health > 0:
		is_dead = false
		anim_locks["die"] = false

		var highest = find_highest_aggro_target()

		if highest:
			target = highest.target_entity
		else:
			target = null

		if target == null:
			wander()
		else:
			combat.combat()
			
	else:
		can_move = false
		target = null

		if !is_dead:
			is_dead = true
			anim_locks["die"] = true
		
export var melee_distance:float = 2.0
var pack_slots = {}



#_______________________________________________________________________________
func wander():
	updateState()
	if can_move == true:
		if get_meta("is_stopped"):
			is_walking = false
			is_running = false
			sitStateSwitch()
			return
		if is_sitting and !anim_locks["stop_sit"]:
			is_sitting = false
		movementStateSwitch()
		if CommonBehaviours.obstacleAvoid(self):
			moveforward()
			rotateMob()
		else:
			switchDirection()
			moveforward()
			rotateMob()
func sitStateSwitch():
	if target == null:
		if animation.has_animation("sit") and animation.has_animation("idle_sit")and animation.has_animation("stop_sit"):
			if !get_meta("is_stopped"):
				return
			if anim_locks["stop_sit"]:
				return
			var time = OS.get_ticks_msec()
			if !has_meta("sit_next"):
				set_meta("sit_next",time + int(rand_range(3000,12000)))
				return
			if time >= get_meta("sit_next"):
				set_meta("sit_next",time + int(rand_range(8000,30000)))
				if randf() <= 0.5:
					is_sitting = true
					can_move = false
					anim_locks["sit"] = true
	else:
		anim_locks["sit"] = false
#_________________________________Movement______________________________________
func moveforward():
	if can_move == true:
		if !anim_locks["sit"] or is_sitting == true:
			if nav_path.size() <= 0:
				return

			if nav_index >= nav_path.size():
				nav_path.clear()
				nav_index = 0
				return

			var next_pos = nav_path[nav_index]
			var dir = (next_pos - global_transform.origin)
			dir.y = 0

			if dir.length() < 1.0:
				nav_index += 1
				return

			dir = dir.normalized()
			set_meta("dir", -dir)

			# -----------------------------
			# PROPULSION OVERRIDE
			# -----------------------------
			if is_propelled:
				propulsion_timer -= get_physics_process_delta_time()

				move_and_slide(propulsion_velocity)

				if propulsion_timer <= 0.0:
					is_propelled = false

				return

			# -----------------------------
			# NORMAL NAV MOVEMENT
			# -----------------------------
			if is_running:
				move_and_slide(-dir * stats.run_speed)
			elif is_walking:
				move_and_slide(-dir * stats.walk_speed)
func movementStateSwitch():
	var time = OS.get_ticks_msec()
	if !has_meta("move_state_next"):
		set_meta("move_state_next",time + int(rand_range(8000,30000)))
		if randf() <= 0.7:
			is_walking = true
			is_running = false
		else:
			is_running = true
			is_walking = false
		return
	if time >= get_meta("move_state_next"):
		set_meta("move_state_next",time + int(rand_range(8000,30000)))
		if randf() <= 0.7:
			is_walking = true
			is_running = false
		else:
			is_running = true
			is_walking = false
			
			
var last_yaw = 0.0
var turn_anim = ""
var run_turn_anim = ""
func rotateMob():
	var dir = get_meta("dir") if has_meta("dir") else Vector3.ZERO
	if dir == Vector3.ZERO:
		return
	var target_pos = global_transform.origin - dir
	target_pos.y = global_transform.origin.y
	var target_transform = global_transform.looking_at(target_pos,Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_transform.basis,0.1)

	var yaw = rotation.y
	var delta = wrapf(yaw - last_yaw,-PI,PI)

	if !is_walking and !is_running:
		if abs(delta) > 0.02:
			if delta > 0:
				turn_anim = "turn_l"
			else:
				turn_anim = "turn_r"
		else:
			turn_anim = ""

	last_yaw = yaw
func updateState():
	var frames = Engine.get_physics_frames()

	if !has_meta("state_next"):
		set_meta("state_next",frames + int(rand_range(120,600)))
		set_meta("is_stopped",false)
		set_meta("is_moving",true)
		return

	if frames >= get_meta("state_next"):
		var stopped = !get_meta("is_stopped")

		if stopped:
			nav_path.clear()
			nav_index = 0
		else:
			set_meta("next_switch",0)

		set_meta("is_stopped",stopped)
		set_meta("is_moving",!stopped)
		set_meta("state_next",frames + int(rand_range(120,600)))
func switchDirection():
	if nav_path.size() > 0 and nav_index < nav_path.size():
		return
	var frames = Engine.get_physics_frames()
	var next = get_meta("next_switch") if has_meta("next_switch") else 0
	if frames >= next:
		set_meta("next_switch",frames + int(rand_range(30,300)))
		var origin = global_transform.origin
		var random_pos = origin + Vector3(rand_range(-25,25),0,rand_range(-25,25))
		random_pos = nav.get_closest_point(random_pos)
		nav_path = nav.get_simple_path(nav.get_closest_point(origin),random_pos,true)
		nav_index = 0
#________________________________Aggro__________________________________________
func attractPredators():
	var bodies = []
	for body in get_tree().get_nodes_in_group("Entity"):
		if body.global_transform.origin.distance_to(global_transform.origin) < stats.hunt_radius:
			bodies.append(body)
	for body in bodies:
		if body.stats.is_predator:
			if body.stats.species != stats.species:
				if body.stats.food_chain > stats.food_chain:
					var health_factor = 1.0 - (stats.health / stats.max_health)
					var food_chain_factor = 1.0 / max(stats.food_chain,1)
					var aggro = (health_factor * 10.0) + (food_chain_factor * 5.0)
					body.emptyAggro(self,aggro)
func emptyAggro(prey:Node, aggro:float) -> void:
	var instigatorAggro = get_or_create_aggro_target(prey)
	instigatorAggro.aggro += aggro
	
func get_or_create_aggro_target(target_entity: Node) -> AggroTarget:
	for existing_target in targets:
		if existing_target.target_entity == target_entity:
			return existing_target
	var aggro_target = AggroTarget.new()
	aggro_target.target_entity = target_entity
	targets.append(aggro_target)
	return aggro_target
func find_highest_aggro_target() -> AggroTarget:
	var highest_aggro = -1
	var target : AggroTarget = null
	for aggro_target in targets:
		if aggro_target.aggro > highest_aggro:
			target = aggro_target
			highest_aggro = aggro_target.aggro
	return target

func team_aggro():
	var sorted_targets = targets.duplicate()
	sorted_targets.sort_custom(self,"sort_aggro_desc")
	return sorted_targets.slice(0,min(5,sorted_targets.size()))
func sort_aggro_desc(a,b):
	return a.aggro > b.aggro
func display_aggro_player(label):
	var threat_info = []
	for aggro_target in team_aggro():
		if is_instance_valid(aggro_target.target_entity):
			threat_info.append(str(aggro_target.target_entity.name) + " : " + str(round(aggro_target.aggro)))
	label.text = "\n".join(threat_info)
func cleanup_aggro_targets():
	var remaining_targets = []
	for aggro_target in targets:
		if is_instance_valid(aggro_target.target_entity):
			if aggro_target.aggro > 0:
				remaining_targets.append(aggro_target)
	targets = remaining_targets
#_______________________________Debugging_______________________________________
func debug(rich_text_label):
	var dir = get_meta("dir") if has_meta("dir") else Vector3.ZERO
	var state_next = get_meta("state_next") if has_meta("state_next") else 0
	var move_next = get_meta("move_state_next") if has_meta("move_state_next") else 0
	var sit_next = get_meta("sit_next") if has_meta("sit_next") else 0
	var next_switch = get_meta("next_switch") if has_meta("next_switch") else 0
	var anim = animation.current_animation
	var aggro_info = ""
	var lock_info = ""

	for aggro_target in team_aggro():
		if is_instance_valid(aggro_target.target_entity):
			aggro_info += aggro_target.target_entity.name + ":" + str(round(aggro_target.aggro)) + "\n"

	for key in anim_locks:
		if anim_locks[key]:
			lock_info += key + "\n"

	rich_text_label.text = \
	"can move: " + str(can_move) + "\n" + \
	"sequence: " + str(combat.melee_step) + "\n" + \
	"Targets: " + str(targets.size()) + "\n" + \
	"Aggro:\n" + aggro_info + \
	"Anim: " + str(anim) + "\n" + \
	"Locks:\n" + lock_info + \
	"Sitting: " + str(is_sitting) + "\n" + \
	"Sit Next: " + str(sit_next) + "\n" + \
	"Stopped: " + str(get_meta("is_stopped") if has_meta("is_stopped") else false) + "\n" + \
	"Moving: " + str(get_meta("is_moving") if has_meta("is_moving") else false) + "\n" + \
	"Walking: " + str(is_walking) + "\n" + \
	"Running: " + str(is_running) + "\n" + \
	"Dir: " + str(dir) + "\n" + \
	"thirst: " + str(stats.hydration) + "\n" + \
	"Walk Speed: " + str(stats.walk_speed) + "\n" + \
	"Run Speed: " + str(stats.run_speed) + "\n" + \
	"Pos: " + str(global_transform.origin) + "\n" + \
	"Rot: " + str(rotation_degrees) + "\n" + \
	"State Next: " + str(state_next) + "\n" + \
	"Move Next: " + str(move_next) + "\n" + \
	"Dir Switch: " + str(next_switch)
#_______________________________Animation_______________________________________
var blend = 0.25
func playAnim(anim_name:String,anim_blend:float = blend):
	if animation.current_animation != anim_name:
		animation.play(anim_name,anim_blend)

func playDeath()->bool:
	if stats.health > 0:
		return false

	if anim_locks["die"]:
		playAnim("die")
	else:
		playAnim("dead")

	return true

var turn_break_counter = 0
var turn_break_limit = 2
func playTurn()->bool:
	if turn_anim == "" or is_walking or is_running:
		turn_break_counter = 0
		return false

	if !target:
		turn_break_counter = 0
		return false

	var distance = global_transform.origin.distance_to(target.global_transform.origin)

	if distance > melee_distance:
		turn_break_counter = 0
		return false

	turn_break_counter += 1

	if turn_break_counter >= turn_break_limit:
		turn_break_counter = 0

		for key in anim_locks:
			anim_locks[key] = false

		can_move = true

	playAnim(turn_anim)

	return true

func playLocks()->bool:
	if anim_locks["staggered"]:
		playAnim("staggered")
		return true

	if anim_locks["atk1"]:
		playAnim("atk1")
		return true

	if anim_locks["atk2"]:
		playAnim("atk2")
		return true

	if anim_locks["atk3"]:
		playAnim("atk3")
		return true

	if anim_locks["prepare"]:
		playAnim("prepare")
		return true
	if anim_locks["dodge"]:
		playAnim("dodge" if animation.has_animation("dodge") else "dodge")
		return true
	if anim_locks["atk4"]:
		playAnim("atk4" if animation.has_animation("atk4") else "atk1")
		return true

	if anim_locks["atk5"]:
		playAnim("atk5" if animation.has_animation("atk5") else "atk1")
		return true
	if anim_locks["atk6"]:
		playAnim("atk6" if animation.has_animation("atk6") else "atk1")
		return true

	return false

func playRun()->bool:
	if !is_running:
		return false

	if target != null:
		if run_turn_anim != "":
			playAnim(run_turn_anim)
		else:
			playAnim("run_cycle")

		return true

	if animation.has_animation("trot_cycle"):
		playAnim("trot_cycle")
	else:
		playAnim("run_cycle")

	return true

func playWalk()->bool:
	if !is_walking:
		return false

	playAnim("walk_cycle")

	return true

func playSit()->bool:
	if !is_sitting:
		return false

	if anim_locks["sit"]:
		if animation.has_animation("sit"):
			playAnim("sit")
		else:
			playAnim("idle_sit")

		return true

	if anim_locks["stop_sit"]:
		if animation.has_animation("stop_sit"):
			playAnim("stop_sit",0.5)
		else:
			playAnim("idle_cycle")

		return true

	playAnim("idle_sit")

	return true

func animations()->void:
	if playDeath():
		return
	if playTurn():
		return
	if playLocks():
		return
	if playRun():
		return
	if playWalk():
		return
	if playSit():
		return
	playAnim("idle_cycle",0.4)
	if stats.health <= 0:
		if anim_locks["die"]:
			animation.play("die",blend)
		else:
			animation.play("dead")
		return
	if turn_anim != "" and !is_walking and !is_running:
		for key in anim_locks:
			anim_locks[key] = false
		can_move = true
		animation.play(turn_anim,blend)
		return
	if anim_locks["staggered"]:
		animation.play("staggered",blend)
	elif anim_locks["atk1"]:
		animation.play("atk1",blend)
	elif anim_locks["atk2"]:
		animation.play("atk2",blend)
	elif anim_locks["atk3"]:
		animation.play("atk3",blend)
	elif anim_locks["prepare"]:
		animation.play("prepare",blend)
	elif anim_locks["dodge"]:
		animation.play("dodge",blend)
	elif anim_locks["atk4"]:
		animation.play("atk4",blend)
	elif anim_locks["atk5"]:
		animation.play("atk5",blend)
	elif anim_locks["atk6"]:
		animation.play("atk6",blend)
	elif is_running:
		if target != null and run_turn_anim != "":
			animation.play(run_turn_anim,blend)
		elif target != null:
			animation.play("run_cycle")
		elif animation.has_animation("trot_cycle"):
			animation.play("trot_cycle")
		else:
			animation.play("run_cycle")
	elif is_walking:
		animation.play("walk_cycle")
	elif is_sitting:
		if anim_locks["sit"]:
			if animation.has_animation("sit"):
				animation.play("sit",blend)
			else:
				animation.play("idle_sit",blend)
		elif anim_locks["stop_sit"]:
			if animation.has_animation("stop_sit"):
				animation.play("stop_sit",0.5)
			else:
				animation.play("idle_cycle",blend)
		else:
			animation.play("idle_sit",blend)
	else:
		animation.play("idle_cycle",0.4)

	if stats.health <= 0:
		if anim_locks["die"]:
			animation.play("die",blend)
		else:
			animation.play("dead")
		return

	if turn_anim != "" and !is_walking and !is_running:
		for key in anim_locks:
			anim_locks[key] = false

		can_move = true
		animation.play(turn_anim,blend)
		return


func lockAnim(anim_name):
	for key in anim_locks:
		anim_locks[key] = false

	if anim_locks.has(anim_name):
		anim_locks[anim_name] = true
