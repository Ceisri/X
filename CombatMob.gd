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
	skill_icons = MobSkills.getSpeciesSkills($"../Stats".species)
	skill_order = skill_icons.duplicate()
	skill_order.sort_custom(self,"sortSkills")
	
	
	
func _physics_process(delta)->void:
	if parent.animation.current_animation == "prepare":
		if Engine.get_physics_frames() % 60 == 0:
			parent.stats.energy = parent.stats.regenerate(parent.stats.derived_stats["energy_regeneration"],parent.stats.energy,parent.stats.max_energy)
		if Engine.get_physics_frames() % 120 == 0:
			parent.stats.health = parent.stats.regenerate(parent.stats.derived_stats["health_regeneration"],parent.stats.health,parent.stats.max_health)
	for skill in active_cooldowns.keys():
		active_cooldowns[skill] -= delta

		if active_cooldowns[skill] <= 0:
			active_cooldowns.erase(skill)

var play_prepare = true
var attack_phase = false

var skill_step_index: int = 0
var last_anim: String = ""
var skill_lock: bool = false


func _process(delta):
	var anim = parent.animation.current_animation

	# detect animation transition
	if anim != last_anim:
		last_anim = anim

		# unlock ONLY when fully leaving attack anims
		if !anim.begins_with("atk") and anim != "prepare":
			skill_lock = false
	# -------------------------------
	# energy REGEN DURING PREPARE
	# -------------------------------
func sequenceMeleeContinue():
	var anim = parent.animation.current_animation

	# hard stop while anim is playing
	if anim.begins_with("atk") or anim == "staggered":
		return

	for lock in parent.anim_locks.values():
		if lock:
			return

	# prevent re-entry during same decision window
	if skill_lock:
		return

	if skill_order.size() == 0:
		parent.lockAnim("atk1")
		return

	skill_lock = true

	var has_energy: bool = false

	if parent.stats != null:
		has_energy = parent.stats.energy > 0

	# --------------------------------------------------
	# NO energy -> PREPARE
	# --------------------------------------------------
	if !has_energy:
		parent.lockAnim("prepare")
		return

	# --------------------------------------------------
	# LOW energy -> chance to PREPARE
	# --------------------------------------------------
	var energy_ratio: float = 0.0

	if parent.stats.max_energy > 0:
		energy_ratio = float(parent.stats.energy) / float(parent.stats.max_energy)

	if energy_ratio < 0.5:

		var prepare_chance: float = (0.5 - energy_ratio) * 2.0

		if randf() < prepare_chance:
			parent.lockAnim("prepare")
			return

	# --------------------------------------------------
	# ROTATION PATTERN
	# 0 -> last -> 1 -> last-1 -> 2 -> last-2 ...
	# --------------------------------------------------
	var n: int = skill_order.size()

	var layer: int = int(skill_step_index / 2)
	var use_last: bool = (skill_step_index % 2 == 1)

	var idx: int = 0

	if use_last:
		idx = n - 1 - layer
	else:
		idx = layer

	# clamp safety
	if idx < 0 or idx >= n:
		skill_step_index = 0
		skill_lock = false
		return

	var skill: String = skill_order[idx]
	var anim_name: String = MobSkills.getAnim(skill)

	# advance step for NEXT call
	skill_step_index += 1

	if skill_step_index >= n * 2:
		skill_step_index = 0

	# --------------------------------------------------
	# BASIC ATTACKS
	# --------------------------------------------------
	if anim_name == "atk1":
		parent.lockAnim("atk1")
		return

	# --------------------------------------------------
	# energy CHECK
	# --------------------------------------------------
	var cost: float = MobSkills.getEnergyCost(skill)

	if parent.stats.energy < cost:

		energy_ratio = 0.0

		if parent.stats.max_energy > 0:
			energy_ratio = float(parent.stats.energy) / float(parent.stats.max_energy)

		var prepare_chance: float = clamp(
			(0.5 - energy_ratio) * 2.0,
			0.0,
			1.0
		)

		if randf() < prepare_chance:
			parent.lockAnim("prepare")
		else:
			parent.lockAnim("atk1")

		return

	# --------------------------------------------------
	# COOLDOWN CHECK
	# --------------------------------------------------
	if !MobSkills.canUseSkill(skill, active_cooldowns):
		parent.lockAnim("atk1")
		return

	# consume ONCE at cast time
	parent.stats.energy -= cost

	MobSkills.useSkillName(
		skill,
		active_cooldowns,
		haste,
		self
	)

	current_cast_skill = skill

	parent.lockAnim(anim_name)

	
	
func sortSkills(a,b):
	return MobSkills.getCooldown(a) > MobSkills.getCooldown(b)

func updateTargetHistory(target):
	target_history.append(target.global_transform.origin)

	if target_history.size() > target_delay_frames:
		delayed_target_pos = target_history.pop_front()
		using_delayed_target = true


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

	parent.global_transform.basis = parent.global_transform.basis.slerp(target_transform.basis,speed * current_turn_speed)

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
