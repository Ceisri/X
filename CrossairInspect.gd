extends Control

onready var crossair_inspect_tween:Tween = $Tween
var fade_duration:float = 0.3

onready var health_label:Label = $Health
onready var name_label:Label = $Name
onready var rich_text_label = $Debug
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

	var hp = max(0, body.stats.health)
	var ep = max(0, body.stats.energy)

	stats.updateStatusGrid(stats.mob_status_grid, body.get_node("Stats"))

	health_label.text = str(int(hp)) + "/" + str(int(body.stats.max_health))
	energy_label.text = str(int(ep)) + "/" + str(int(body.stats.max_energy))

	var s = ""
	for k in body.stats.attributes:
		s += str(k) + ":" + str(body.stats.attributes[k]) + "\n"
	name_label.text = str(body.stats.Name) + "/\n" + s.trim_suffix("\n")

	hp_bar.value = body.stats.health
	ap_bar.value = body.stats.energy
	hp_bar.max_value = body.stats.max_health
	ap_bar.max_value = body.stats.max_energy

	crossair_inspect_tween.stop_all()
	crossair_inspect_tween.interpolate_property(hp_bar,"value",hp_bar.value,hp,0.3,Tween.TRANS_SINE,Tween.EASE_OUT)
	crossair_inspect_tween.interpolate_property(ap_bar,"value",ap_bar.value,ep,0.3,Tween.TRANS_SINE,Tween.EASE_OUT)
	crossair_inspect_tween.start()

	updateEnemySkills(body)

	enemy_defenses_label.text = \
	"Slash: " + str(body.stats.slash_defence) + "\n" + \
	"Blunt: " + str(body.stats.blunt_defence) + "\n" + \
	"Pierce: " + str(body.stats.pierce_defence) + "\n" + \
	"Sonic: " + str(body.stats.sonic_defence) + "\n" + \
	"Heat: " + str(body.stats.heat_defence) + "\n" + \
	"Cold: " + str(body.stats.cold_defence) + "\n" + \
	"Jolt: " + str(body.stats.jolt_defence) + "\n" + \
	"Toxic: " + str(body.stats.toxic_defence) + "\n" + \
	"Acid: " + str(body.stats.acid_defence) + "\n" + \
	"Arcane: " + str(body.stats.arcane_defence) + "\n" + \
	"Bleed: " + str(body.stats.bleed_defence) + "\n" + \
	"Radiant: " + str(body.stats.radiant_defence)


func updateEnemySkills(body):
	for child in enemy_skill_grid.get_children():
		if child != skill_template:
			child.queue_free()

	skill_template.visible = false

	var skills = MobSkills.getSpeciesSkills(body.stats.species)

	for i in range(skills.size()):
		var skill = skills[i]

		var icon = skill_template.duplicate()
		icon.visible = true
		icon.texture = load(MobSkills.getSkillPath(skill))

		var label = icon.get_node("Label")

		if body.combat.active_cooldowns.has(skill):
			label.text = str(int(ceil(body.combat.active_cooldowns[skill])))
			label.visible = true
		else:
			label.visible = false

		enemy_skill_grid.add_child(icon)
