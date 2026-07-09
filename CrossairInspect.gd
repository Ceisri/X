extends Control

onready var crossair_inspect_tween:Tween = $Tween
var fade_duration:float = 0.3

onready var health_label:Label = $Health
onready var name_label:Label = $Name
onready var rich_text_label =  $"../Chat/RichTextLabel3"
onready var crossair = $"../Crossair"

onready var stats:Node = $"../../Stats"
onready var enemy_defenses_label:Label = $EnemyDefenses

onready var area:Area = $"../../Camroot/h/v/Camera/Area"
onready var player:KinematicBody = $"../.."

onready var enemy_skill_grid = $GridContainer
onready var skill_template = $GridContainer/Icon1

onready var ap_bar = $EPbar
onready var hp_bar = $HPbar
onready var energy_label = $Energy
var current_target = null
var last_target_time:float = 0.0
var persist_time:float = 10.0
var last_switch_time:float = 0.0
var last_seen_time:float = 0.0

var out_of_combat_time:float = 10.0
var combat_grace_time:float = 30.0

func _onready()->void:
	visible = true

func crossairInspect(player):
	var target = _get_closest_non_player_body()

	var now = OS.get_ticks_msec() * 0.001

	if target != null:
		if target != current_target:
			current_target = target
			last_switch_time = now

		last_seen_time = now

	if current_target == null or !is_instance_valid(current_target) or !current_target.is_in_group("Entity"):
		current_target = null
		_fade_out()
		return

	var in_area = _is_in_area(current_target)

	if player.is_in_combat:
		if in_area:
			last_seen_time = now

		var time_ok = (now - last_seen_time) <= combat_grace_time

		if !time_ok:
			current_target = null
			_fade_out()
			return

	else:
		var time_ok = (now - last_switch_time) <= out_of_combat_time

		if !time_ok:
			current_target = null
			_fade_out()
			return

	entityInfo(current_target)
	crossair.visible = true
	modulate.a = 1.0


func _is_in_area(body):
	if area == null:
		return false

	for b in area.get_overlapping_bodies():
		if b == body:
			return true
	return false


func _fade_out():
	crossair_inspect_tween.interpolate_property(self,"modulate:a",modulate.a,0.0,fade_duration/3,Tween.TRANS_LINEAR,Tween.EASE_IN_OUT)
	crossair_inspect_tween.start()
	crossair.visible = true
func _get_closest_non_player_body():
	var bodies = area.get_overlapping_bodies()
	if bodies.size() == 0:
		return null

	var best = null
	var best_d = INF

	for b in bodies:
		if b == null:
			continue
		if b == player:
			continue
		if !b.is_in_group("Entity"):
			continue

		var d = player.global_transform.origin.distance_to(b.global_transform.origin)
		if d < best_d:
			best_d = d
			best = b

	return best



func entityInfo(body):
	if body == null or !is_instance_valid(body):
		return
	var facing_text = ""
	var direction_to_player = (player.global_transform.origin - body.global_transform.origin).normalized()

	var facing_direction:Vector3
	var direction_control = body.get_node_or_null("DirectionControl")

	if direction_control:
		facing_direction = direction_control.global_transform.basis.z.normalized()
	else:
		facing_direction = body.global_transform.basis.z.normalized()

	var dot = -facing_direction.dot(direction_to_player)

	if dot >= 0.7:
		facing_text = "BEHIND"
	elif dot >= 0.0:
		facing_text = "FLANKING"
	else:
		facing_text = "FACING"

	var creator_text="Creator: None\n"
	if body.creator!=null and is_instance_valid(body.creator):
		creator_text="Creator: "+body.creator.entity_name+"\n"

	var spawned_text="Spawned Bodies:\n"
	for spawned_body in body.spawned_bodies:
		if !is_instance_valid(spawned_body):continue
		spawned_text+="• "+spawned_body.entity_name+"\n"

	rich_text_label.text=body.movement_mode+"\n"+\
	facing_text+"\n"+\
	body.current_skill+"\n"+\
	"Pos: "+str(body.was_stuck_there.position)+"\n"+\
	"Time: "+str(body.was_stuck_there.time)+"\n"+\
	"Death: "+str(body.respawn_id)+"\n"+\
	"Damage:\n"+body.stats.displayDMGMeter()+"\n"+\
	str(body.entity_name)+"\n"+\
	creator_text+\
	spawned_text+\
	str(body.animation_tree.get("parameters/Interraction/blend_amount"))+"\n"+\
	str(body.animation_tree.get("parameters/IsAlive/blend_amount"))


	body.displayAggro($"../Chat/RichTextLabel3")
	body.displayAnimLocks($"../Chat/RichTextLabel3")
	
	
	var hp = max(0, body.stats.health)
	var ep = max(0, body.stats.energy)

	stats.updateStatusGrid(stats.mob_status_grid, body.get_node("Stats"))
	health_label.text = str(int(hp)) + "/" + str(int(body.stats.max_health))
	energy_label.text = str(int(ep)) + "/" + str(int(body.stats.max_energy))

	var s = ""
	for k in body.stats.attributes:
		s += str(k) + ":" + str(body.stats.attributes[k]) + "\n"

	hp_bar.value = body.stats.health
	ap_bar.value = body.stats.energy
	hp_bar.max_value = body.stats.max_health
	ap_bar.max_value = body.stats.max_energy

	crossair_inspect_tween.stop_all()
	crossair_inspect_tween.interpolate_property(hp_bar,"value",hp_bar.value,hp,0.3,Tween.TRANS_SINE,Tween.EASE_OUT)
	crossair_inspect_tween.interpolate_property(ap_bar,"value",ap_bar.value,ep,0.3,Tween.TRANS_SINE,Tween.EASE_OUT)
	crossair_inspect_tween.start()
	$Name.text = body.stats.species + ": level "+ str(body.stats.level)
	updateEnemySkills(body)
	enemy_defenses_label.text = \
"Slash: " + str(stats.mitPercent(body.stats.slash_defence)) + "%  | ATK: " + str(body.stats.slash_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("slash",0.0) + body.stats.damage_flat_modifier.get("slash",0.0)) + "\n" + \
"Blunt: " + str(stats.mitPercent(body.stats.blunt_defence)) + "%  | ATK: " + str(body.stats.blunt_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("blunt",0.0) + body.stats.damage_flat_modifier.get("blunt",0.0)) + "\n" + \
"Pierce: " + str(stats.mitPercent(body.stats.pierce_defence)) + "%  | ATK: " + str(body.stats.pierce_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("pierce",0.0) + body.stats.damage_flat_modifier.get("pierce",0.0)) + "\n" + \
"Sonic: " + str(stats.mitPercent(body.stats.sonic_defence)) + "%  | ATK: " + str(body.stats.sonic_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("sonic",0.0) + body.stats.damage_flat_modifier.get("sonic",0.0)) + "\n" + \
"Heat: " + str(stats.mitPercent(body.stats.heat_defence)) + "%  | ATK: " + str(body.stats.heat_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("heat",0.0) + body.stats.damage_flat_modifier.get("heat",0.0)) + "\n" + \
"Cold: " + str(stats.mitPercent(body.stats.cold_defence)) + "%  | ATK: " + str(body.stats.cold_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("cold",0.0) + body.stats.damage_flat_modifier.get("cold",0.0)) + "\n" + \
"Jolt: " + str(stats.mitPercent(body.stats.jolt_defence)) + "%  | ATK: " + str(body.stats.jolt_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("jolt",0.0) + body.stats.damage_flat_modifier.get("jolt",0.0)) + "\n" + \
"Toxic: " + str(stats.mitPercent(body.stats.toxic_defence)) + "%  | ATK: " + str(body.stats.toxic_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("toxic",0.0) + body.stats.damage_flat_modifier.get("toxic",0.0)) + "\n" + \
"Acid: " + str(stats.mitPercent(body.stats.acid_defence)) + "%  | ATK: " + str(body.stats.acid_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("acid",0.0) + body.stats.damage_flat_modifier.get("acid",0.0)) + "\n" + \
"Arcane: " + str(stats.mitPercent(body.stats.arcane_defence)) + "%  | ATK: " + str(body.stats.arcane_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("arcane",0.0) + body.stats.damage_flat_modifier.get("arcane",0.0)) + "\n" + \
"Bleed: " + str(stats.mitPercent(body.stats.bleed_defence)) + "%  | ATK: " + str(body.stats.bleed_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("bleed",0.0) + body.stats.damage_flat_modifier.get("bleed",0.0)) + "\n" + \
"Radiant: " + str(stats.mitPercent(body.stats.radiant_defence)) + "%  | ATK: " + str(body.stats.radiant_multiplier * 100.0) + "%  | Flat: " + str(body.stats.flat_damage_bonus.get("radiant",0.0) + body.stats.damage_flat_modifier.get("radiant",0.0))
	

func updateEnemySkills(body):
	for child in enemy_skill_grid.get_children():
		if child != skill_template:
			child.queue_free()
	skill_template.visible = false
	var skills_list = Skills.getSpeciesSkills(body.stats.species)
	for i in range(skills_list.size()):
		var skill_name = skills_list[i]
		if !Skills.skills.has(skill_name):
			continue
		var icon = skill_template.duplicate()
		icon.visible = true
		icon.texture = Skills.skills[skill_name]
		var label = icon.get_node("Label")
		var cd_path = Skills.skills[skill_name].resource_path

		if body != null and body.has_method("get") and "skill_cooldowns" in body and body.skill_cooldowns != null:
			if body.skill_cooldowns.has(cd_path):
				label.text = str(int(ceil(body.skill_cooldowns[cd_path])))
				label.visible = true
			else:
				label.visible = false
		else:
			label.visible = false
		enemy_skill_grid.add_child(icon)
