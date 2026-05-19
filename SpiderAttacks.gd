extends Spatial

onready var mob = $".."
onready var animation_player = $"../AnimationPlayer"
onready var base_atk_area = $base_atk
onready var aim = $Aim
onready var stats = $"../Stats"
var blend = 0.15
onready var tween = $Tween
onready var debug = $Debug
var target = null



func combat()->void:
	combatAnimations()
	target = null
	var highest_aggro = 0
	for aggro_target in mob.targets:
		if is_instance_valid(aggro_target.target_entity):
			if aggro_target.aggro > highest_aggro:
				highest_aggro = aggro_target.aggro
				target = aggro_target.target_entity
	var distance = -1
	if target:
		distance = mob.global_transform.origin.distance_to(target.global_transform.origin)
		if distance <= base_atk_dist:
			sequenceMelee(target)
		elif distance <= range_atk1_dist:
			base_wait_unlock = false
			if !range_used:
				melee_step = 0
				rangeAttack(target)
				lookTarget()
			else:
				CommonBehaviours.followTarget(self)
		else:
			range_fired = false
			base_wait_unlock = false
			melee_step = 0
			CommonBehaviours.followTarget(self)
	else:
		melee_step = 0
		animation_player.play("idle_cycle")
	updateDebug(distance)



var base_atk_dist = 1.8
var range_atk1_dist = 7
var aoe_atk1_dist = 3.5


var range_fired = false
var base_wait_unlock = false
var melee_step = 0
var can_move:bool = true
var anim_locks = {
	"atk1":false,
	"atk2":false,
	"atk3":false,
	"atk4":false,
	"atk5":false,
	"range1":false,
	"range2":false,
	"aoe1":false,
	"parry":false,
	"scream":false
}

var self_buff_used:bool = false
func sequenceMelee(target):
	if target.is_moving:
		base_wait_unlock = false
		melee_step = 0
	if stats.health <= stats.max_health / 2:
		if !self_buff_used:
			if animation_player.has_animation("scream"):
				lockAnim("scream")
		else:
			sequenceMeleeContinue()
	else:
		sequenceMeleeContinue()

func sequenceMeleeContinue()->void:
	match mob.stats.species:
		"spider":
			spiderMeleeSec()
		"horse":
			horseSec()


func spiderMeleeSec()->void:
	if !base_wait_unlock:
		if melee_step % 2 == 0:
			if CommonBehaviours.checkHealth(mob):
				if randf() <= mob.stats.parry_chance:
					lockAnim("parry")
				else:
					lockAnim("atk1")
			else:
				lockAnim("atk1")
			base_wait_unlock = true
		elif melee_step == 1:
			lockAnim("atk2")
			base_wait_unlock = true

		elif melee_step == 3:
			lockAnim("atk3")
			base_wait_unlock = true

		elif melee_step == 5:
			lockAnim("atk4")
			base_wait_unlock = true

		elif melee_step == 7:
			lockAnim("atk5")
			base_wait_unlock = true



func horseSec()->void:
	if !base_wait_unlock:
		if melee_step % 2 == 0:
			lockAnim("atk1")
			base_wait_unlock = true
		elif melee_step == 1:
			lockAnim("atk2")
			base_wait_unlock = true
		elif melee_step == 3:
			lockAnim("atk3")
			base_wait_unlock = true


func combatAnimations()->void:
	if anim_locks["atk1"]:
		animation_player.play("atk1",blend,1.3)
	elif anim_locks["atk2"]:
		animation_player.play("atk2",blend,1.4)
	elif anim_locks["atk3"]:
		animation_player.play("atk3",blend,1.5)
	elif anim_locks["atk4"]:
		animation_player.play("atk1",blend,3)
	elif anim_locks["atk5"]:
		animation_player.play("atk5",blend,1.6)
	elif anim_locks["range1"]:
		animation_player.play("range1",blend,1.3)
	elif anim_locks["range2"]:
		animation_player.play("range2",blend)
	elif anim_locks["aoe1"]:
		animation_player.play("aoe1",blend)
	elif anim_locks["parry"]:
		animation_player.play("parry",blend)
	elif anim_locks["scream"]:
		animation_player.play("scream",blend)
	else:
		if mob.is_moving:
			can_move = true
			animation_player.play("run_cycle")
		else:
			animation_player.play("idle_cycle")

var range_atk1_wait = 1.5
var range_casting = false
var range_cast_start = 0
var range_used = false
func rangeAttack(target):
	if aim.is_colliding():
		if aim.get_collider() == target:
			if !anim_locks["range1"]:
				lockAnim("range1")
		else:
			CommonBehaviours.followTarget(self)
	else:
		CommonBehaviours.followTarget(self)








var dash_power = 0.0
var dash_direction = Vector3.ZERO

func dashForward(dash_distance:float):
	var power = dash_distance
	if base_atk_area.get_overlapping_bodies().has(target):
		power = dash_distance * 0.3
	else:
		power = dash_distance
	dash_direction = mob.global_transform.basis.z.normalized()
	tween.stop_all()
	tween.interpolate_method(self,"updateDash",power,0.0,0.15,Tween.TRANS_QUAD,Tween.EASE_OUT)
	tween.start()

func updateDash(power):
	var delta_power = power + dash_power
	dash_power = power
	mob.move_and_slide(dash_direction * delta_power * Engine.iterations_per_second)
	if power <= 0:
		dash_power = 0


func lookTarget()->void:
	if target:
		var target_pos = mob.global_transform.origin - (target.global_transform.origin - mob.global_transform.origin)
		target_pos.y = mob.global_transform.origin.y
		var target_transform = mob.global_transform.looking_at(target_pos,Vector3.UP)
		mob.global_transform.basis = mob.global_transform.basis.slerp(target_transform.basis,0.1)

func rotateToTarget(speed:float):
	if target:
		if !base_atk_area.get_overlapping_bodies().has(target):
			var direction = (target.global_transform.origin - mob.global_transform.origin).normalized()
			direction.y = 0

			if direction.length_squared() > 0.0001:
				var current_direction = mob.global_transform.basis.z.normalized()
				var target_rotation = current_direction.linear_interpolate(direction,speed)

				var look_at_rotation = Basis()
				look_at_rotation = look_at_rotation.rotated(Vector3.UP,atan2(target_rotation.x,target_rotation.z))

				mob.global_transform.basis = look_at_rotation

func updateDebug(distance):
	var locked = []
	var unlocked = []
	for key in anim_locks:
		if anim_locks[key]:
			locked.append(key)
		else:
			unlocked.append(key)
	debug.text = (
		"Distance: " + str(stepify(distance,0.01)) +
		"\nAnimation: " + animation_player.current_animation +
		"\nSecquence: " + str(melee_step)+
		"\nLocked: " + str(locked) +
		"\nUnlocked: " + str(unlocked))


func lockMov()->void:
	can_move = false
func unlockMov()->void:
	can_move = true 
func lockAnim(anim_name):
	for key in anim_locks:
		anim_locks[key] = false
	anim_locks[anim_name] = true
func callAnimLock(anim_name):
	anim_locks[anim_name] = false
	base_wait_unlock = false
func callAnimAllLock()->void:
	for key in anim_locks:
		anim_locks[key] = false
	base_wait_unlock = false
func callAnimRangeUse()->void:
	range_used = true
	
func callConsumeSelfBuff()->void:
	self_buff_used = true

func callAnimMeleeSeqUP()->void:
	melee_step += 1
	if melee_step > 7:
		melee_step = 0

func base_atk()->void:
	for body in base_atk_area.get_overlapping_bodies():
		if body.is_in_group("Entity"):
			if body.stats.species != mob.stats.species:
				if body.has_method("get_hit"):
					body.get_hit(mob,10)
