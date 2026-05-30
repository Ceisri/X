extends Node


#__________________________________Entitygraphical interface________________________________________
onready var entity_graphic_interface = $CrossairInspect
onready var crossair = $Crossair
onready var ray = $"../Camroot/h/v/Camera/RayCast"
onready var crossair_inspect_tween = $"../Camroot/h/v/Camera/RayCast/Tween"
var fade_duration = 0.3
onready var health_label = $CrossairInspect/Health
onready var energy_label = $CrossairInspect/Energy
onready var name_label = $CrossairInspect/Name


func crossairInspect(player):
	if ray.is_colliding():
		var body = ray.get_collider()
		if body.is_in_group("Entity") and body != player:
			entityInfo(body)
			body.debug($CrossairInspect/Debug)
			# Instantly turn alpha to maximum
			entity_graphic_interface.modulate.a = 1.0
		else:
			# Start tween to fade out
			crossair_inspect_tween.interpolate_property(entity_graphic_interface, "modulate:a", entity_graphic_interface.modulate.a, 0.0, fade_duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
			crossair_inspect_tween.start()
	else:
		# Start tween to fade out
		crossair_inspect_tween.interpolate_property(entity_graphic_interface, "modulate:a", entity_graphic_interface.modulate.a, 0.0,fade_duration/3, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		crossair_inspect_tween.start()
		#print(str(fade_duration))

onready var enemy_skill_grid = $CrossairInspect/GridContainer
onready var skill_template = $CrossairInspect/GridContainer/Icon1

func entityInfo(body):
	health_label.text = str(body.stats.health)
	name_label.text = str(body.stats.Name)

	updateEnemySkills(body)

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
