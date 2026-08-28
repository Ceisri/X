extends Node #animationCalls.gd for mobs, the functions here are called inside the animation tracks
onready var parent = get_parent()
func dealDMG():
	var parent = get_parent()
	var stats = parent.get_node("Stats")
	if !stats.isAuthority():
		return # animation call tracks replay on puppets too — only the authority deals damage
	stats.dealDamage()

func applyBuff():
	var parent = get_parent()
	var stats:Node = parent.get_node("Stats")
	if !stats.isAuthority():
		return
	var spell:String = parent.current_skill
	stats.applyBuffDebuff(spell,parent)

func spawnScene()->void:
	var parent:KinematicBody=get_parent()
	var stats=parent.get_node("Stats")
	if !stats.isAuthority():
		return

	var species:String=stats.species

	if parent.current_skill=="web shot" or parent.current_skill=="poison shot" or parent.current_skill=="toad spit" or parent.current_skill=="poison spit":
		var xform = parent.global_transform
		xform.origin -= xform.basis.z * 4.0
		xform.origin.y = parent.get_node("RayDown").global_transform.origin.y


		var node_name = "projectile_" + str(OS.get_unix_time()) + "_" + str(randi())
		var scene_path:String = Global.projectiles["elemental"].resource_path


		Global.spawnProjectile(scene_path, parent, xform)
		return

	if !Global.egg_spawners.has(species):return

	if parent.current_skill=="spawn spiderlings":
		var spawn_positions=[]
		for spawn_index in range(3):
			var spawn_pos=parent.global_transform.origin
			for _attempt in range(20):
				spawn_pos=parent.global_transform.origin+Vector3(rand_range(-5,5),0,rand_range(-5,5))
				var valid=true
				for existing_pos in spawn_positions:
					if spawn_pos.distance_to(existing_pos)<2.5:
						valid=false
						break
				if valid:
					break
			spawn_positions.append(spawn_pos)

#			var node_name = "eggspawner_" + str(OS.get_unix_time()) + "_" + str(randi()) + "_" + str(spawn_index)
#			var xform = Transform(Basis(), spawn_pos)
#			var scene_path:String = Global.egg_spawners[species].resource_path
#
#			EffectSpawner.spawn(scene_path, node_name, parent.get_parent(), xform, {"creator": parent.get_path(), "timer": 180})
#		return



func waitStopTree():
	call_deferred("stopTree")
func stopTree():
	var parent=get_parent()
	parent.current_skill="none"
	parent.last_active_skill=""
	parent.animation_tree.active=false
	parent.has_anim_lock=false
	parent.can_move = true
func unlockAnim():
	var parent=get_parent()
	var stats=parent.get_node("Stats")
	if stats.health<=0 and parent.is_dead:
		if parent.has_method("freezeAtDeathPose"):
			parent.freezeAtDeathPose()
		else:
			parent.animation_tree.active=false
	if typeof(parent.anim_locks) == TYPE_ARRAY:
		for i in range(parent.anim_locks.size()):
			parent.anim_locks[i]=false
	else:
		for key in parent.anim_locks:
			parent.anim_locks[key]=false
	if stats.health<=0:
		parent.is_dead = true
		if parent.has_method("freezeAtDeathPose"):
			parent.freezeAtDeathPose()
		else:
			parent.animation_tree.active=false
	else:
		parent.current_skill="none"
		parent.last_active_skill=""
		parent.animation_tree.active=false
		parent.has_anim_lock=false
		parent.can_move = true
	stats.resetChargedStacks()

		
func disableCollisions()->void:
	if parent.cached_entities.empty():
		parent.cacheEntities()
	for body in parent.cached_entities:
		if !is_instance_valid(body) or body == parent:
			continue
		parent.add_collision_exception_with(body)
		body.add_collision_exception_with(parent)

func enableCollisions()->void:
	if parent.cached_entities.empty():
		parent.cacheEntities()
	for body in parent.cached_entities:
		if !is_instance_valid(body) or body == parent:
			continue
		parent.remove_collision_exception_with(body)
		body.remove_collision_exception_with(parent)
