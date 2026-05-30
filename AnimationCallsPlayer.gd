extends Node

onready var parent = $".."
onready var animation = $"../character/AnimationPlayer"
onready var tween = $"../Tween"
onready var dmg_area = $"../AreaDamage"
onready var stats = $"../Stats"

func _ready():
	cleanCallTracks()
	connectUnlockAnimLastFrames()
	loadAnimations()

func lockMov():
	parent.can_move = false

func canMove():
	parent.can_move = true

func unlockAnim():
	for key in parent.anim_locks:
		parent.anim_locks[key] = false


func excecutespell()->void:
	var skill = parent.combat.current_cast_skill

	if skill == "":
		return

	if !MobSkills.isAttack(skill):
		return

	var damage = MobSkills.getDamage(skill)

	for body in parent.dmg_area.get_overlapping_bodies():
		if body == parent:
			continue

		if body.has_method("getHit"):
			body.getHit(parent,damage)

			if MobSkills.isStun(skill):
				pass

			if MobSkills.isLifesteal(skill):
				var heal = damage * MobSkills.getLifestealPower(skill)

				parent.stats.health += heal
			
			if MobSkills.isCooldownReduce(skill):
				var reduction = MobSkills.getCooldownReducePower(skill)

				for cd_skill in parent.combat.active_cooldowns.keys():
					parent.combat.active_cooldowns[cd_skill] *= (1.0 - reduction)

					if parent.combat.active_cooldowns[cd_skill] <= 0:
						parent.combat.active_cooldowns.erase(cd_skill)

var dash_power = 0.0
var dash_direction = Vector3.ZERO

func dashForward(dash_distance:float):
	dash_power = dash_distance
	dash_direction = -parent.global_transform.basis.z.normalized()

	tween.stop_all()

	tween.interpolate_method(
		self,
		"updateDash",
		dash_power,
		0.0,
		0.18,
		Tween.TRANS_CUBIC,
		Tween.EASE_OUT
	)

	tween.start()

func updateDash(power:float):
	var step = dash_direction * power * get_physics_process_delta_time()

	parent.move_and_collide(step)

	pushTarget(power)

func pushTarget(power:float):
	for body in parent.dmg_area.get_overlapping_bodies():
		if body == parent:
			continue

		if body is KinematicBody:
			if body.has_node("Stats"):
				var stats = body.stats

				if stats and "can_be_moved" in stats:
					if !stats.can_be_moved:
						continue

			var push_dir = (
				body.global_transform.origin
				- parent.global_transform.origin
			).normalized()

			push_dir.y = 0

			body.move_and_slide(push_dir * power * 6.0)

func die()->void:
	parent.is_dead = true

func connectUnlockAnimLastFrames():
	var save_path = "res://world/player/human/animations/"

	var dir = Directory.new()

	if !dir.dir_exists(save_path):
		dir.make_dir_recursive(save_path)

	for anim_name in animation.get_animation_list():
		if !(anim_name in parent.anim_locks):
			continue

		var anim = animation.get_animation(anim_name)

		if anim == null:
			continue

		for i in range(anim.get_track_count() - 1,-1,-1):
			if anim.track_get_type(i) == Animation.TYPE_METHOD:
				anim.remove_track(i)

		var unlock_track = anim.add_track(Animation.TYPE_METHOD)

		anim.track_set_path(
	unlock_track,
	NodePath("../AnimationCalls")
)

		anim.track_insert_key(
			unlock_track,
			anim.length,
			{
				"method":"unlockAnim",
				"args":[]
			}
		)

		ResourceSaver.save(
			"%s%s.tres" % [save_path,anim_name],
			anim
		)

func cleanCallTracks():
	var save_path = "res://world/player/human/animations/"

	var dir = Directory.new()

	if !dir.dir_exists(save_path):
		return

	for anim_name in animation.get_animation_list():
		if !(anim_name in parent.anim_locks):
			continue

		var anim = animation.get_animation(anim_name)

		if anim == null:
			continue

		for i in range(anim.get_track_count() - 1,-1,-1):
			if anim.track_get_type(i) == Animation.TYPE_METHOD:
				anim.remove_track(i)

		ResourceSaver.save(
			"%s%s.tres" % [save_path,anim_name],
			anim
		)

func loadAnimations():
	var save_path = "res://world/player/human/animations/"

	var dir = Directory.new()

	if dir.open(save_path) != OK:
		return

	dir.list_dir_begin(true,true)

	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var anim_name = file_name.get_basename()

			var anim = load("%s%s" % [save_path,file_name])

			if anim:
				if animation.has_animation(anim_name):
					animation.remove_animation(anim_name)

				animation.add_animation(anim_name,anim)

		file_name = dir.get_next()

	dir.list_dir_end()
