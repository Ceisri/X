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






















func followTarget(node:Node):
	if node.can_move:
		if node.target:
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

	switchDirection(mob)
	moveforward(mob)
	rotate(mob)

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
