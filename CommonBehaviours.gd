extends Node




func gravity(mob):
	var gravity = mob.stats.weight
	if mob.ray_down:
		var ray = mob.ray_down
		if !mob.is_on_floor():
			if !ray.is_colliding():
				mob.move_and_slide(Vector3.DOWN * gravity)
			else:
				var collider = ray.get_collider()
				if collider != mob:
					if collider.is_in_group("Entity"):
						mob.move_and_slide(Vector3.DOWN * gravity)

func floor_slope(mob):
	if Engine.get_physics_frames() % 3 == 0:
		if mob:
			if mob.ray_down:
				var ray = mob.ray_down
				if ray.is_colliding():
					var collider = ray.get_collider()
					if collider != mob:
						if !collider.is_in_group("Entity"):
							var normal = ray.get_collision_normal()
							var slope = rad2deg(acos(normal.dot(Vector3.UP)))
							return slope
	return 0
#_______________________________________________________________________________
func checkHealth(mob)->bool:
	if mob.stats.last_health == -1:
		mob.stats.last_health = mob.stats.health

	if mob.stats.health < mob.stats.last_health:
		mob.stats.last_damage_time = OS.get_ticks_msec()

	mob.stats.last_health = mob.stats.health

	if (OS.get_ticks_msec() - mob.stats.last_damage_time) <= mob.stats.damage_check_window:
		return true

	return false
#_______________________________________________________________________________
func updateAnimation(mob):
	var animation_player = mob.get_node("AnimationPlayer")
	var stats = mob.get_node("Stats")
	var is_finished = stats.is_finished
	if mob.get_meta("state"):
		var state = mob.get_meta("state")
		match state:
			"wander":
				if mob.has_meta("is_stopped") and mob.get_meta("is_stopped"):
					animation_player.play("idle_cycle")
				else:
					animation_player.play("walk_cycle")
			"dying":
				animation_player.play("die")
			"dead":
				animation_player.play("dead")
			"chase":
				animation_player.play("run_cycle")
			"fight":
				if mob.attacks:
					mob.attacks.combat()
#_______________________________________________________________________________
func getAvoidDirection(mob):
	return (mob.global_transform.basis.z + mob.global_transform.basis.x).normalized()

func moveforwardAvoid(mob):
	var dir = mob.get_meta("avoid_dir") if mob.has_meta("avoid_dir") else Vector3.ZERO

	if dir == Vector3.ZERO:
		return

	mob.move_and_slide(-dir * mob.stats.walk_speed)

func rotateAvoid(mob):
	var dir = mob.get_meta("avoid_dir") if mob.has_meta("avoid_dir") else Vector3.ZERO

	if dir == Vector3.ZERO:
		return

	var target_pos = mob.global_transform.origin + dir
	target_pos.y = mob.global_transform.origin.y

	var target_transform = mob.global_transform.looking_at(target_pos,Vector3.UP)

	mob.global_transform.basis = mob.global_transform.basis.slerp(target_transform.basis,0.1)
#_______________________________________________________________________________
# Duration of avoidance mode in milliseconds.
# While active the mob keeps following the avoidance direction instead of
# returning to normal target/wander movement.
# Example:
# 1000 = 1 second avoidance
# 2000 = 2 seconds avoidance
# Higher values = wider detours, lower values = more reactive behavior.
var avoid_time = 2500


# Number of consecutive collision detections required before the mob is
# considered stuck.
#
# Example with value = 3:
# collision -> free -> collision -> free
# = NOT stuck (mob is progressing)
#
# collision -> collision -> collision
# = STUCK
#
# Once stuck:
# - move backwards
# - swap avoidance side (left <-> right)
# - retry pathing
#
# Lower = faster unstuck reaction
# Higher = more tolerance before recovery.
var avoid_stuck_hits = 3


# Strength of the lateral offset applied during avoidance.
#
# Controls how aggressively the mob sidesteps obstacles.
#
# Examples:
# 0.5 = slight diagonal correction
# 1.0 = balanced diagonal
# 2.0 = strong sideways bias
#
# Affects:
# - initial left/right avoidance choice
# - side swap after unstuck
var avoid_side_strength = 1.4


# Strength of backward movement when the mob enters unstuck mode.
#
# Triggered only after avoid_stuck_hits is reached.
#
# Examples:
# 0.5 = small retreat
# 1.0 = normal retreat
# 2.0 = strong backwards escape
#
# Higher values help escape corners but may create wider path resets.
var avoid_back_strength = 1.0
func obstacleAvoid(mob,target = null):
	if mob.ray_forward.is_colliding():
		var collider = mob.ray_forward.get_collider()

		if collider != mob:
			if target:
				if collider == target:
					return false

			var hits = mob.get_meta("avoid_hits") if mob.has_meta("avoid_hits") else 0

			hits += 1

			mob.set_meta("avoid_hits",hits)

			if !mob.has_meta("avoiding"):
				var side = "left" if randf() < 0.5 else "right"

				mob.set_meta("avoid_side",side)
				mob.set_meta("avoiding",true)

				var dir = mob.get_meta("dir") if mob.has_meta("dir") else Vector3.ZERO

				if dir != Vector3.ZERO:
					if side == "left":
						dir = (dir + (mob.global_transform.basis.x * avoid_side_strength)).normalized()
					else:
						dir = (dir - (mob.global_transform.basis.x * avoid_side_strength)).normalized()

				mob.set_meta("dir",dir)

			if hits >= avoid_stuck_hits:
				var side = mob.get_meta("avoid_side")

				var dir = (-mob.global_transform.basis.z * avoid_back_strength)

				if side == "left":
					dir = (dir - (mob.global_transform.basis.x * avoid_side_strength)).normalized()
					mob.set_meta("avoid_side","right")
				else:
					dir = (dir + (mob.global_transform.basis.x * avoid_side_strength)).normalized()
					mob.set_meta("avoid_side","left")

				mob.set_meta("dir",dir)
				mob.set_meta("avoid_hits",0)

			mob.set_meta("avoid_start",OS.get_ticks_msec())

			return true

	var hits = mob.get_meta("avoid_hits") if mob.has_meta("avoid_hits") else 0

	if hits > 0:
		mob.set_meta("avoid_hits",0)

	var avoid_start = mob.get_meta("avoid_start") if mob.has_meta("avoid_start") else 0

	if avoid_start > 0:
		if (OS.get_ticks_msec() - avoid_start) < avoid_time:
			return true

		mob.remove_meta("avoiding")
		mob.remove_meta("avoid_side")

		mob.set_meta("avoid_start",0)

	return false
#_______________________________________________________________________________



func followTarget(node:Node):
	if node.can_move:
		if node.target:
			if obstacleAvoid(node.get_parent(),node.target):
				moveforward(node.get_parent())
				rotate(node.get_parent())
				node.get_parent().is_moving = true
			else:
				node.lookTarget()

				var direction = (node.target.global_transform.origin - node.get_parent().global_transform.origin).normalized()
				var distance = node.get_parent().global_transform.origin.distance_to(node.target.global_transform.origin)

				if distance > node.base_atk_dist:
					node.get_parent().move_and_slide(direction * node.get_parent().stats.run_speed)
					node.get_parent().is_moving = true
func wander(mob):
	updateState(mob)

	if mob.get_meta("is_stopped"):
		return

	if obstacleAvoid(mob):
		moveforward(mob)
		rotate(mob)
	else:
		switchDirection(mob)
		moveforward(mob)
		rotate(mob)
func moveforward(mob):
	var dir = mob.get_meta("dir") if mob.has_meta("dir") else Vector3.ZERO
	mob.move_and_slide(-dir * mob.stats.walk_speed)
func rotate(mob):
	var dir = mob.get_meta("dir") if mob.has_meta("dir") else Vector3.ZERO
	if dir == Vector3.ZERO:
		return
	var target_pos = mob.global_transform.origin + (dir)
	target_pos.y = mob.global_transform.origin.y
	var target_transform = mob.global_transform.looking_at(target_pos, Vector3.UP)
	mob.global_transform.basis = mob.global_transform.basis.slerp(target_transform.basis, 0.1)




func updateState(mob):
	var frames = Engine.get_physics_frames()

	if !mob.has_meta("state_next"):
		mob.set_meta("state_next", frames + int(rand_range(120,600)))
		mob.set_meta("is_stopped", false)
		mob.set_meta("is_moving", true)
		return

	if frames >= mob.get_meta("state_next"):
		var stopped = !mob.get_meta("is_stopped")

		mob.set_meta("is_stopped", stopped)
		mob.set_meta("is_moving", !stopped)

		mob.set_meta("state_next", frames + int(rand_range(120,600)))

func switchDirection(mob):
	var frames = Engine.get_physics_frames()
	var next = mob.get_meta("next_switch") if mob.has_meta("next_switch") else 0

	if frames >= next:
		mob.set_meta("next_switch", frames + int(rand_range(100,4000)))
		mob.set_meta("dir", Vector3(rand_range(-1,1),0,rand_range(-1,1)).normalized())

