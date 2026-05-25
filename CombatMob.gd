extends Node

onready var parent = $".."

var melee_step = 1
var turn_speed = 0.8
var run_turn_speed = 1.6




var target_history = []
export var target_delay_frames:int = 10
var delayed_target_pos = Vector3.ZERO
var using_delayed_target = false

export var walk_distance:float = 5


var current_cast_skill = ""
var active_cooldowns = {}
var haste = 1.0
var skill_icons = []
var skill_order = []
var current_skill = -1

func _ready():
	skill_icons = Skills.getSpeciesSkills($"../Stats".species)

	skill_order = skill_icons.duplicate()

	skill_order.sort_custom(self,"sortSkills")
func _physics_process(delta)->void:
	for skill in active_cooldowns.keys():
		active_cooldowns[skill] -= delta

		if active_cooldowns[skill] <= 0:
			active_cooldowns.erase(skill)
var play_prepare = true
var attack_phase = false

func sequenceMeleeContinue():
	var anim = parent.animation.current_animation

	if anim.begins_with("atk"):
		return

	if anim == "staggered":
		return

	for lock in parent.anim_locks.values():
		if lock:
			return

	if skill_order.empty():
		parent.lockAnim("prepare")
		return

	if play_prepare:
		play_prepare = false
		attack_phase = true
		parent.lockAnim("prepare")
		return

	if !attack_phase:
		return

	var tries = 0

	while tries < skill_order.size():
		if current_skill >= skill_order.size():
			current_skill = 0

		var skill = skill_order[current_skill]

		if Skills.canUseSkill(skill,active_cooldowns):
			current_cast_skill = skill

			Skills.useSkillName(skill,active_cooldowns,haste,self)

			match Skills.getAnim(skill):
				"atk1":
					parent.lockAnim("atk1")

				"atk2":
					parent.lockAnim("atk2")

				"atk3":
					parent.lockAnim("atk3")

				"atk4":
					parent.lockAnim("atk4")

				_:
					parent.lockAnim("prepare")

			play_prepare = true
			attack_phase = false
			current_skill += 1
			return

		current_skill += 1
		tries += 1

	parent.lockAnim("prepare")
	
	
	
	
func sortSkills(a,b):
	return Skills.getCooldown(a) > Skills.getCooldown(b)

func updateTargetHistory(target):
	target_history.append(target.global_transform.origin)

	if target_history.size() > target_delay_frames:
		delayed_target_pos = target_history.pop_front()
		using_delayed_target = true

#
#func sequenceMeleeContinue():
#	if melee_step > 7:
#		melee_step = 1
#
#	if melee_step % 3 == 0:
#		parent.lockAnim("prepare")
#	elif melee_step % 2 == 0:
#		parent.lockAnim("atk1")
#	elif melee_step == 1:
#		parent.lockAnim("atk2")
#	elif melee_step == 5:
#		parent.lockAnim("atk3")
#	elif melee_step == 7:
#		parent.lockAnim("atk4")
#

func rotateToTarget(speed:float,target_pos:Vector3):
	if parent.animation.current_animation == "prepare":
		parent.turn_anim = ""
		return

	parent.turn_anim = ""

	for lock in parent.anim_locks.values():
		if lock:
			return

	var origin = parent.global_transform.origin

	var direction = target_pos - origin
	direction.y = 0

	if direction.length_squared() <= 0.001:
		return

	direction = direction.normalized()

	var look_pos = origin - direction
	look_pos.y = origin.y

	var target_transform = parent.global_transform.looking_at(look_pos,Vector3.UP)

	var current_turn_speed = turn_speed

	if parent.is_running:
		current_turn_speed = run_turn_speed

	parent.global_transform.basis = parent.global_transform.basis.slerp(target_transform.basis,speed * current_turn_speed)

	var forward = -parent.global_transform.basis.z.normalized()
	forward.y = 0

	var angle = forward.angle_to(direction)

	var yaw = parent.rotation.y
	var delta = wrapf(yaw - parent.last_yaw,-PI,PI)

	if angle > deg2rad(15):
		if delta > 0:
			parent.turn_anim = "turn_l"
		else:
			parent.turn_anim = "turn_r"

	parent.last_yaw = yaw
func rotateToTargetMelee(speed:float,target_pos:Vector3):
	for body in parent.dmg_area.get_overlapping_bodies():
		if body == parent.target:
			parent.turn_anim = ""
			return

	for lock in parent.anim_locks.values():
		if lock:
			parent.turn_anim = ""
			return

	var origin = parent.global_transform.origin

	var direction = target_pos - origin
	direction.y = 0

	if direction.length_squared() <= 0.001:
		parent.turn_anim = ""
		return

	direction = direction.normalized()

	var look_pos = origin - direction
	look_pos.y = origin.y

	var target_transform = parent.global_transform.looking_at(look_pos, Vector3.UP)

	var current_turn_speed = turn_speed
	if parent.is_running:
		current_turn_speed = run_turn_speed

	parent.global_transform.basis = parent.global_transform.basis.slerp(
		target_transform.basis,
		speed * current_turn_speed
	)

	var forward = -parent.global_transform.basis.z.normalized()
	forward.y = 0

	var angle = forward.angle_to(direction)

	var yaw = parent.rotation.y
	var delta = wrapf(yaw - parent.last_yaw, -PI, PI)

	if angle > deg2rad(15):
		if delta > 0:
			parent.turn_anim = "turn_l"
		else:
			parent.turn_anim = "turn_r"
	else:
		parent.turn_anim = ""

	parent.last_yaw = yaw
func combat():
	var target = parent.target

	if !target:
		target_history.clear()
		using_delayed_target = false
		parent.is_walking = false
		parent.is_running = false
		return

	updateTargetHistory(target)

	var origin = parent.global_transform.origin
	var real_target = target.global_transform.origin
	var real_distance = origin.distance_to(real_target)

	var in_melee = real_distance <= parent.melee_distance or (parent.melee_ray.is_colliding() and parent.melee_ray.get_collider() == target)

	var move_target = real_target

	if in_melee:
		using_delayed_target = false

		rotateToTargetMelee(0.1,real_target)

		parent.is_walking = false
		parent.is_running = false

		sequenceMeleeContinue()
		return

	if real_distance > parent.melee_distance and using_delayed_target:
		move_target = delayed_target_pos

		if origin.distance_to(delayed_target_pos) < 1.5:
			using_delayed_target = false
			move_target = real_target
	else:
		move_target = real_target

	var direction = move_target - origin
	direction.y = 0

	if direction.length_squared() <= 0.01:
		parent.is_walking = false
		parent.is_running = false
		return

	direction = direction.normalized()

	rotateToTarget(0.1,move_target)

	parent.set_meta("dir",-direction)

	for lock in parent.anim_locks.values():
		if lock:
			parent.is_walking = false
			parent.is_running = false
			return

	if target.is_in_group("Player"):
		if real_distance <= walk_distance:
			parent.is_walking = true
			parent.is_running = false
			parent.move_and_slide(direction * parent.stats.walk_speed)
		else:
			parent.is_walking = false
			parent.is_running = true
			parent.move_and_slide(direction * parent.stats.run_speed)
	else:
		parent.is_walking = false
		parent.is_running = true
		parent.move_and_slide(direction * parent.stats.run_speed)
