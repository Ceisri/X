# ============================================================
# projectile.gd — FULL FILE REPLACEMENT
# ============================================================
extends KinematicBody
#projectile script — now poolable (never queue_free'd, returned to Global's pool)

export var shooter_path:NodePath
var shooter:KinematicBody
export var speed := 20.0
var velocity := Vector3.ZERO

var scene_path:String = ""
var aim_direction:Vector3 = Vector3.ZERO
var use_aim_direction:bool = false

# FIX: snapshot of shooter.current_skill taken at spawn time. Reading
# shooter.current_skill live inside dealDamage() was the bug -- by the
# time a projectile actually reaches a distant target, the skill's anim
# lock has already timed out and unlockAnim() reset current_skill to ""
# well before travel time caught up, so Global.getDamages("") returned
# an empty dict (0 damage) even though crit/penetrating rolls still fired
# and showed their headers. Distance-independent now.
var cached_skill_name:String = ""

func _isAuthority() -> bool:
	return get_tree().network_peer == null or get_tree().is_network_server()

func setPoolInfo(path:String) -> void:
	scene_path = path

func _ready():
	if get_tree().network_peer != null:
		set_network_master(1, true)

func activate(new_shooter:Node, spawn_transform:Transform, new_aim_direction:Vector3 = Vector3.ZERO, use_aim:bool = false) -> void:
	shooter = new_shooter
	aim_direction = new_aim_direction
	use_aim_direction = use_aim
	global_transform = spawn_transform

	# Snapshot the skill NOW, at spawn -- this is what dealDamage() will
	# use later regardless of how long the projectile takes to travel.
	cached_skill_name = shooter.current_skill if is_instance_valid(shooter) and "current_skill" in shooter else ""

	visible = true
	set_physics_process(true)
	velocity = Vector3.ZERO

	_snapped_once = false
	_has_received_position_sync = false
	_net_position_recv_time = 0
	_position_sync_timer = 0.0
	net_velocity = Vector3.ZERO
	net_position = Vector3.ZERO

	if get_tree().network_peer != null:
		set_network_master(1, true)

	if !_isAuthority():
		return

	if !is_instance_valid(shooter):
		push_error("Projectile.gd: activate() called with no valid shooter on authority -- returning to pool")
		call_deferred("returnToPool")
		return

	if use_aim_direction and aim_direction.length_squared() > 0.0001:
		velocity = aim_direction.normalized() * speed
		look_at(global_transform.origin + velocity, Vector3.UP)
	elif shooter.is_in_group("Player"):
		velocity = shooter.direction.normalized() * speed
		look_at(global_transform.origin + velocity, Vector3.UP)
	else:
		global_transform.basis = shooter.global_transform.basis
		velocity = shooter.global_transform.basis.z.normalized() * speed

	if get_tree().network_peer != null:
		rset("net_velocity", velocity)
		rset("net_position", global_transform.origin)

func returnToPool() -> void:
	set_physics_process(false)
	visible = false
	velocity = Vector3.ZERO
	shooter = null
	cached_skill_name = ""
	if is_instance_valid(Global):
		Global.releaseProjectile(self, scene_path)



# ---- sync / lag compensation ----
puppet var net_velocity := Vector3() setget _set_net_velocity
puppet var net_position := Vector3() setget _set_net_position
var _net_position_recv_time := 0
var _has_received_position_sync := false
var _snapped_once := false
export var lag_compensation_max_extrapolation := 0.3
export var position_sync_rate := 0.1
var _position_sync_timer := 0.0

func _set_net_velocity(value):
	net_velocity = value
	velocity = value

func _set_net_position(value):
	_has_received_position_sync = true
	_net_position_recv_time = OS.get_ticks_msec()
	net_position = value
	if !_snapped_once:
		_snapped_once = true
		global_transform.origin = value


func _physics_process(delta):
	if get_tree().network_peer != null and !_isAuthority():
		if velocity != Vector3.ZERO:
			global_transform.origin += velocity * delta
		if _has_received_position_sync:
			var elapsed = (OS.get_ticks_msec() - _net_position_recv_time) / 1000.0
			elapsed = min(elapsed, lag_compensation_max_extrapolation)
			var extrapolated = net_position + net_velocity * elapsed
			global_transform.origin = global_transform.origin.linear_interpolate(extrapolated, 0.35)
	else:
		move_and_slide(velocity)
		if get_tree().network_peer != null:
			_position_sync_timer += delta
			if _position_sync_timer >= position_sync_rate:
				_position_sync_timer = 0.0
				rset_unreliable("net_position", global_transform.origin)

	if Engine.get_physics_frames() % 600 == 0:
		returnToPool()

func _on_Area_body_entered(body):
	if !_isAuthority():
		return
	if !is_instance_valid(shooter):
		return
	if body==shooter: return
	if "shooter" in body and body.shooter==shooter: return
	if !Global.canHitEnemy(shooter,body): return
	dealDamage()

func dealDamage():
	if !is_instance_valid(shooter):
		return

	if shooter.is_in_group("Entity") and "is_in_combat" in shooter:
		shooter.is_in_combat = true

	var area:Area = $Area
	if !is_instance_valid(area):
		return

	var bodies = area.get_overlapping_bodies()
	var my_stats = shooter.get_node_or_null("Stats")
	if !is_instance_valid(my_stats):
		return

	var skill_name:String = cached_skill_name
	var skill_level_mult:float = my_stats.getSkillLevelMultiplier(skill_name) if my_stats.has_method("getSkillLevelMultiplier") else 1.0
	var charge_stacks:int = int(my_stats.charged_attack_stacks[skill_name].stacks) if my_stats.charged_attack_stacks.has(skill_name) else 0
	var skill_damages:Dictionary = Global.getDamages(skill_name)

	if my_stats.charged_attack_stacks.has(skill_name) and charge_stacks > 0:
		var data = my_stats.charged_attack_stacks[skill_name]
		for dmg_type in skill_damages:
			skill_damages[dmg_type] += skill_damages[dmg_type] * (charge_stacks * data.multiplier)

	var base_pen_chance:float = my_stats.derived_stats.get("penetrating_hit_chance",0.0)
	var is_penetrating_hit:bool = randf() <= clamp(base_pen_chance + Global.skill_penetration_chance.get(skill_name.to_lower(),0.0),0.0,1.0)
	var is_crit:bool = randf() <= my_stats.derived_stats.get("crit_chance",0.0)
	var total_damage:int = 0

	if bodies.empty():
		for attack_name in my_stats.charged_attack_stacks:
			my_stats.charged_attack_stacks[attack_name]["stacks"] = 0
		return

	for body in bodies:
		if !is_instance_valid(body) or !body.is_in_group("Entity"):
			continue
		if body == shooter:
			continue
		if "shooter" in body and body.shooter == shooter:
			continue
		if !Global.canHitEnemy(shooter,body):
			continue
		if "current_skill" in body and Global.skill_dmg_immunity.has(body.current_skill):
			continue

		var other_stats = body.stats if "stats" in body else body.get_node_or_null("Stats")
		if !is_instance_valid(other_stats):
			continue

		var special_mult:float = Global.getSpecialDamageMultiplier(skill_name,my_stats,other_stats)
		var special_flat_damage:float = Global.getSpecialFlatDamage(skill_name,other_stats)
		var damages:Dictionary = {}

		for dmg_type in skill_damages:
			var type_index:int = int(dmg_type)
			var mult:float = my_stats.dmgMultByType[type_index] if type_index < my_stats.dmgMultByType.size() else 1.0
			var type_name:String = my_stats.DMG_TYPE_NAMES[type_index] if type_index < my_stats.DMG_TYPE_NAMES.size() else ""
			var flat_add:float = my_stats.flat_damage_bonus.get(type_name,0.0) + my_stats.damage_flat_modifier.get(type_name,0.0)
			damages[dmg_type] = (skill_damages[dmg_type] * mult * skill_level_mult * special_mult) + flat_add + special_flat_damage

		if shooter.is_in_group("Player") and shooter.weapons == shooter.WeaponMode.NONE and skill_name == "combo attack":
			var combo_total:float = 0.0
			for dmg_type in damages:
				combo_total += damages[dmg_type]
			damages = {Global.Type.blunt:combo_total}

		if shooter.is_in_group("Player") and shooter.weapons == shooter.WeaponMode.DUAL:
			for dmg_type in damages:
				if skill_name == "combo attack" or shooter.WeaponMode.NONE:
					damages[dmg_type] *= 0.5

		if is_crit:
			for dmg_type in damages:
				damages[dmg_type] *= my_stats.derived_stats.get("crit_damage",1.0)

		var target_total_damage:int = 0
		for v in damages.values():
			target_total_damage += int(v)
		total_damage += target_total_damage

		if Global.debuffs_buffs.has(skill_name):
			if Global.debuffs_buffs[skill_name].get("malus",true):
				other_stats.applyBuffDebuff(skill_name,shooter)
			else:
				my_stats.applyBuffDebuff(skill_name,shooter)

		var extra_threat:float = Global.skill_extra_aggro.get(skill_name.to_lower(),0.0)
		var extra_threat_amplified:float = extra_threat * my_stats.derived_stats.get("threat",1.0)

		other_stats.getHit(shooter,damages,is_penetrating_hit,extra_threat_amplified,is_crit)
		Global.applyImpactEffects(skill_name,body,shooter)

		if Global.status_effects is Dictionary and Global.status_effects.has(skill_name) and Global.status_effects[skill_name] is Dictionary:
			for status_name in Global.status_effects[skill_name]:
				other_stats.applyStatus(status_name,shooter,skill_name)

	for attack_name in my_stats.charged_attack_stacks:
		my_stats.charged_attack_stacks[attack_name]["stacks"] = 0

	if shooter.is_in_group("Player") and is_instance_valid(shooter.skillbar) and "active_cooldowns" in shooter.skillbar:
		Global.applyOnHitEffects(skill_name,my_stats.active_on_hit_effects,shooter.skillbar.active_cooldowns,my_stats,total_damage)
	elif "active_cooldowns" in shooter:
		Global.applyOnHitEffects(skill_name,Global.on_hit_effects,shooter.active_cooldowns,my_stats,total_damage)
	elif "skill_cooldowns" in shooter:
		Global.applyOnHitEffects(skill_name,Global.on_hit_effects,shooter.skill_cooldowns,my_stats,total_damage)
