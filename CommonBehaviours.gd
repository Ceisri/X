extends Node

var FloatingResScene: PackedScene = preload("res://world/player/modules/Interface/scenes/FloatingRes.tscn")

func addNotStackableItem(inventory_grid, item_data):
	for child in inventory_grid.get_children():
		var slot = child.get_node("Slot")

		if slot.texture == null:
			slot.texture = item_data["icon"]
			child.stackable = false
			child.quantity = 1
			child.max_quantity = 1
			return
func addStackableItem(inventory_grid,item_data,quantity:int=1):
	for child in inventory_grid.get_children():
		var slot = child.get_node("Slot")

		if slot.texture == item_data.icon and child.stackable:
			child.quantity += quantity
			return

	for child in inventory_grid.get_children():
		var slot = child.get_node("Slot")

		if slot.texture == null:
			slot.texture = item_data.icon
			child.stackable = true
			child.quantity = quantity
			child.max_quantity = 9999999999
			return
func spawn(controller,scene,position = null,mobName = "",nutrition = 100,health = 100,finished = false):
	var RESPAWN_TIME = 10.0
	var SPAWN_RANGE = 10.0
	var mob = scene.instance()
	if position == null:
		var offsetX = rand_range(-SPAWN_RANGE,SPAWN_RANGE)
		var offsetZ = rand_range(-SPAWN_RANGE,SPAWN_RANGE)
		mob.translation = Vector3(controller.global_transform.origin.x + offsetX,controller.global_transform.origin.y,controller.global_transform.origin.z + offsetZ)
	else:
		mob.translation = position
	var stats = mob.get_node("Stats")
	if mobName == "":
		mobName = stats.Names[randi() % stats.Names.size()]
	stats.Name = mobName
	stats.nutrition = nutrition
	stats.health = health
	stats.is_finished = finished
	mob.set_meta("state","wander")
	controller.add_child(mob)
	return mob









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

func obstacleAvoid(mob,target = null):
	pass
#	var dir = mob.get_meta("dir") if mob.has_meta("dir") else Vector3.ZERO
#
#	if dir == Vector3.ZERO:
#		return false
#
#	var forward = !mob.ray_forward.is_colliding()
#	var left = !mob.ray_left.is_colliding()
#	var right = !mob.ray_right.is_colliding()
#
#	if forward:
#		return false
#
#	if left and right:
#		if randf() < 0.5:
#			dir = (dir + mob.global_transform.basis.x).normalized()
#		else:
#			dir = (dir - mob.global_transform.basis.x).normalized()
#
#	elif left:
#		dir = (dir + mob.global_transform.basis.x).normalized()
#
#	elif right:
#		dir = (dir - mob.global_transform.basis.x).normalized()
#
#	else:
#		dir = -dir
#		mob.rotation.y += PI
#
#	mob.set_meta("dir",dir)
#
#	return true
