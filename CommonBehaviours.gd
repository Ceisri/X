extends Node

var FloatingResScene: PackedScene = preload("res://world/player/modules/Interface/scenes/FloatingRes.tscn")

func addNotStackableItem(inventory_grid, item_data, floating_parent):
	for child in inventory_grid.get_children():
		var slot = child.get_node("Slot")

		if slot.texture == null:
			slot.texture = item_data["icon"]
			child.stackable = false
			child.quantity = 1
			child.max_quantity = 1
			showFloatingItem(floating_parent, item_data, 1)
			return


func addStackableItem(inventory_grid, item_data, floating_parent, quantity:int = 1):
	for child in inventory_grid.get_children():
		var slot = child.get_node("Slot")
		if slot.texture == item_data["icon"] and child.stackable:
			child.quantity += quantity
			return
	for child in inventory_grid.get_children():
		var slot = child.get_node("Slot")

		if slot.texture == null:
			slot.texture = item_data["icon"]
			child.stackable = true
			child.quantity = quantity
			child.max_quantity = 9999999999

			return

func removeItemByTexture(texture, inventory_grid) -> bool:
	if texture == null:
		return false

	for child in inventory_grid.get_children():
		var slot = child.get_node("Slot")

		if slot.texture == texture:
			child.quantity -= 1

			if child.quantity <= 0:
				child.quantity = 0
				slot.texture = null

			if child.has_method("displayQuantity"):
				child.displayQuantity()

			return true

	return false

func inventoryHasItem(texture, inventory_grid) -> bool:
	if texture == null:
		return false

	for child in inventory_grid.get_children():
		var slot = child.get_node("Slot")

		if slot.texture == texture and child.quantity > 0:
			return true

	return false

func showFloatingItem(parent_node, item_data, quantity:int = 1):
	var floating = FloatingResScene.instance()

	floating.text = "+" + str(quantity)
	floating.icon = item_data["icon"]
	floating.use_screen_center = false
	floating.world_position = Vector2.ZERO

	parent_node.add_child(floating)


func useItem(button,inventory_grid,stats,floating_text_parent=null)->bool:
	if button==null:
		return false

	var slot=button.get_node_or_null("Slot")

	if slot==null and button.get_parent()!=null:
		slot=button.get_parent().get_node_or_null("Slot")

	if slot==null:
		return false

	var texture=slot.texture

	if texture==null:
		return false

	var consumed=false

	if texture==Items.flasks["medicine"]["icon"]:
		if stats.health>=stats.max_health:
			return false
		stats.health=min(stats.health + (stats.max_health * 0.1),stats.max_health)
		consumed=true

	elif texture==Items.flasks["energy"]["icon"]:
		if stats.energy>=stats.max_energy:
			return false
		stats.energy=min(stats.energy+10,stats.max_energy)
		consumed=true

	elif texture==Items.flasks["power"]["icon"]:
		consumed=true

	elif texture==Items.flasks["poison"]["icon"]:
		consumed=true

	if !consumed:
		return false

	addStackableItem(
		inventory_grid,
		Items.flasks["empty"],
		floating_text_parent
	)

	return true



func spawn(controller, scene, position=null, mob_name="", nutrition=100, health=-1, finished=false):
	var mob = scene.instance()

	var spawn_position = position if position != null else Vector3(
		controller.global_transform.origin.x + rand_range(-10, 10),
		controller.global_transform.origin.y,
		controller.global_transform.origin.z + rand_range(-10, 10)
	)

	mob.translation = spawn_position

	var stats = mob.get_node("Stats")

	if mob_name == "":
		mob_name = stats.Names[randi() % stats.Names.size()]

	stats.Name = mob_name
	stats.nutrition = nutrition

	if health == -1:
		stats.health = stats.max_health
	else:
		stats.health = health

	stats.is_finished = finished

	mob.set_meta("state", "wander")
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
