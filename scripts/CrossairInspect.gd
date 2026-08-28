extends Control #Crossair inspect, allows me to see the stats of other players and mobs
class TextHolder:
	var text := ""
onready var distance_label =$"../Crossair/Distance"
onready var crossair_inspect_tween:Tween = $Tween
var fade_duration:float = 0.3

onready var aggro_label:Label = $Aggro_label
onready var anim_label:Label = $Anim_Label
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
var _last_entity_info_signature := ""
var _last_entity_info_target = null
var _warned_missing_more_info := false
var _more_info_toggled := false

func _onready()->void:
	visible = true
var _last_processed_visual_frame:int = -1
func _physics_process(_delta:float) -> void:
	if !player.isLocalPlayer():
		return

	var visual_frame:int = Engine.get_frames_drawn()
	var is_new_visual_frame:bool = visual_frame != _last_processed_visual_frame
	if visual_frame == _last_processed_visual_frame:
		return
	_last_processed_visual_frame = visual_frame
	if !InputMap.has_action("more_info"):
		if !_warned_missing_more_info:
			_warned_missing_more_info = true
			push_error("CrossairInspect.gd: input action 'more_info' is not defined in Project Settings > Input Map -- the toggle can never fire until it's added.")
		return
	if Input.is_action_just_pressed("more_info"):
		_more_info_toggled = !_more_info_toggled

var _crossair_inspect_frame:int = -1
func crossairInspect(player):
	var frame_now:int = Engine.get_physics_frames()
	if frame_now == _crossair_inspect_frame:
		return
	_crossair_inspect_frame = frame_now
	var target = getTarget()

	var now = OS.get_ticks_msec() * 0.001

	if target != null:
		if target != current_target:
			current_target = target
			last_switch_time = now

		last_seen_time = now

	if current_target == null or !is_instance_valid(current_target) or !current_target.is_in_group("Entity"):
		current_target = null
		_fade_out()
		distance_label.visible = false
		return

	var in_area = _is_in_area(current_target)

	if player.is_in_combat:
		if in_area:
			last_seen_time = now

		var time_ok = (now - last_seen_time) <= combat_grace_time

		if !time_ok:
			current_target = null
			_fade_out()
			distance_label.visible = false
			return

	else:
		var time_ok = (now - last_switch_time) <= out_of_combat_time

		if !time_ok:
			current_target = null
			_fade_out()
			distance_label.visible = false
			return
	forceUnfreezeMob(current_target)
	entityInfo(current_target)
	crossair.visible = true
	modulate.a = 1.0

	if in_area:
		var dist = (player.global_transform.origin.distance_to(current_target.global_transform.origin)) * 0.5
		distance_label.text = str(stepify(dist, 0.1)) + "m"
		distance_label.visible = true
	else:
		distance_label.visible = false


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
func getTarget():
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


var _entity_info_frame:int = -1
func entityInfo(body):
	if body == null or !is_instance_valid(body):
		return
	var frame_now2:int = Engine.get_physics_frames()
	if frame_now2 == _entity_info_frame:
		return
	_entity_info_frame = frame_now2
	var sig := str(body.get_instance_id()) + "|" + str(body.get("movement_mode")) + "|" + str(body.get("current_skill")) \
		+ "|" + str(body.get("respawn_id")) + "|" + str(_more_info_toggled)
	var entity_stats_check = body.get_node_or_null("Stats")
	if is_instance_valid(entity_stats_check):
		sig += "|" + str(int(entity_stats_check.health)) + "|" + str(int(entity_stats_check.energy))
	if sig == _last_entity_info_signature and _last_entity_info_target == body:
		return
	_last_entity_info_signature = sig
	_last_entity_info_target = body
	var facing_text = ""
	if !is_instance_valid(player):
		return

	var show_more_info = _more_info_toggled

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

	var creator_text = "Creator: None\n"
	if "creator" in body and body.creator != null and is_instance_valid(body.creator) and "entity_name" in body.creator:
		creator_text = "Creator: " + str(body.creator.entity_name) + "\n"

	var spawned_text = "Spawned Bodies:\n"
	if !body.is_in_group("Player"):
		#body.sleeping = false
		if "spawned_bodies" in body and body.spawned_bodies != null:
			for spawned_body in body.spawned_bodies:
				if !is_instance_valid(spawned_body):
					continue
				if "entity_name" in spawned_body:
					spawned_text += "• " + str(spawned_body.entity_name) + "\n"


	var movement_mode_text = str(body.movement_mode) if "movement_mode" in body else "?"
	var current_skill_text = str(body.current_skill) if "current_skill" in body else "?"
	var respawn_id_text = str(body.respawn_id) if "respawn_id" in body else "?"

	var stuck_pos_text = "N/A"
	var stuck_time_text = "N/A"
	if "was_stuck_there" in body and body.was_stuck_there != null:
		var stuck_data = body.was_stuck_there
		if typeof(stuck_data) == TYPE_DICTIONARY:
			stuck_pos_text = str(stuck_data.get("position", "N/A"))
			stuck_time_text = str(stuck_data.get("time", "N/A"))
		elif "position" in stuck_data and "time" in stuck_data:
			stuck_pos_text = str(stuck_data.position)
			stuck_time_text = str(stuck_data.time)

	var entity_stats = body.get_node_or_null("Stats")

	var dmg_meter_text = "N/A"
	if is_instance_valid(entity_stats) and entity_stats.has_method("displayDMGMeter"):
		dmg_meter_text = str(entity_stats.displayDMGMeter())

	var entity_name_text = str(body.entity_name) if "entity_name" in body else ""

	var interaction_blend_text = "N/A"
	var is_alive_blend_text = "N/A"
	if "animation_tree" in body and is_instance_valid(body.animation_tree):
		interaction_blend_text = str(body.animation_tree.get("parameters/Interraction/blend_amount"))
		is_alive_blend_text = str(body.animation_tree.get("parameters/IsAlive/blend_amount"))

	# Build the general info block first.
	var combined_text = movement_mode_text + "\n" + \
		facing_text + "\n" + \
		current_skill_text + "\n" + \
		"Pos: " + stuck_pos_text + "\n" + \
		"Time: " + stuck_time_text + "\n" + \
		"Death: " + respawn_id_text + "\n" + \
		"Damage:\n" + dmg_meter_text + "\n" + \
		entity_name_text + "\n" + \
		creator_text + \
		spawned_text + \
		interaction_blend_text + "\n" + \
		is_alive_blend_text
	
	if !body.is_in_group("Player"):
		if body.has_method("displayAggro") and is_instance_valid(aggro_label):
			body.displayAggro(aggro_label)
			if aggro_label.text.strip_edges() != "":
				combined_text += "\n\nAggro:\n" + aggro_label.text

	if body.has_method("displayAnimLocks"):

		body.displayAnimLocks(anim_label)
		if anim_label.text.strip_edges() != "":
			combined_text += "\n\nAnim Locks:\n" + anim_label.text



	if is_instance_valid(rich_text_label):
		rich_text_label.text = combined_text

	if !is_instance_valid(entity_stats):
		return # nothing below this point is safe without a Stats node

	var hp = max(0, entity_stats.health) if "health" in entity_stats else 0
	var ep = max(0, entity_stats.energy) if "energy" in entity_stats else 0
	var max_hp = entity_stats.max_health if "max_health" in entity_stats else 1
	var max_ep = entity_stats.max_energy if "max_energy" in entity_stats else 1

	if is_instance_valid(stats) and stats.has_method("updateStatusGrid") and "mob_status_grid" in stats:
		stats.updateStatusGrid(stats.mob_status_grid, entity_stats)

	if is_instance_valid(health_label):
		health_label.text = str(int(hp)) + "/" + str(int(max_hp))
	if is_instance_valid(energy_label):
		energy_label.text = str(int(ep)) + "/" + str(int(max_ep))

	if is_instance_valid(hp_bar):
		hp_bar.max_value = max_hp
	if is_instance_valid(ap_bar):
		ap_bar.max_value = max_ep

	if is_instance_valid(crossair_inspect_tween) and is_instance_valid(hp_bar) and is_instance_valid(ap_bar):
		crossair_inspect_tween.stop_all()
		crossair_inspect_tween.interpolate_property(hp_bar, "value", hp_bar.value, hp, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT)
		crossair_inspect_tween.interpolate_property(ap_bar, "value", ap_bar.value, ep, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT)
		crossair_inspect_tween.start()

	var name_label = get_node_or_null("Name")
	if is_instance_valid(name_label):
		if body.is_in_group("Player"):
			name_label.text = entity_name_text
		else:
			var species_text = str(entity_stats.species) if "species" in entity_stats else "?"
			var level_text = str(entity_stats.level) if "level" in entity_stats else "?"
			name_label.text = species_text + ": level " + level_text

	if show_more_info:
		if !body.is_in_group("Player"):
			if has_method("updateEnemySkills"):
				updateEnemySkills(body)
			if is_instance_valid(enemy_skill_grid):
				enemy_skill_grid.visible = true

			if is_instance_valid(enemy_defenses_label):
				enemy_defenses_label.text = _buildDefensesText(entity_stats)
				enemy_defenses_label.visible = true
		else:
			if is_instance_valid(enemy_skill_grid):
				enemy_skill_grid.visible = false
			if is_instance_valid(enemy_defenses_label):
				enemy_defenses_label.visible = false
	else:
		if is_instance_valid(enemy_skill_grid):
			enemy_skill_grid.visible = false
		if is_instance_valid(enemy_defenses_label):
			enemy_defenses_label.visible = false





func _buildDefensesText(entity_stats) -> String:
	var damage_types = ["slash","blunt","pierce","sonic","heat","cold","jolt","toxic","acid","arcane","bleed","radiant"]
	var lines := []

	for dmg_type in damage_types:
		var defence_key = dmg_type + "_defence"
		var multiplier_key = dmg_type + "_multiplier"

		var defence_pct = "N/A"
		if defence_key in entity_stats and is_instance_valid(stats) and stats.has_method("mitPercent"):
			defence_pct = str(stats.mitPercent(entity_stats.get(defence_key)))

		var atk_pct = "N/A"
		if multiplier_key in entity_stats:
			atk_pct = str(entity_stats.get(multiplier_key) * 100.0)

		var flat_bonus = 0.0
		if "flat_damage_bonus" in entity_stats and entity_stats.flat_damage_bonus != null:
			flat_bonus += float(entity_stats.flat_damage_bonus.get(dmg_type, 0.0))
		if "damage_flat_modifier" in entity_stats and entity_stats.damage_flat_modifier != null:
			flat_bonus += float(entity_stats.damage_flat_modifier.get(dmg_type, 0.0))

		var label_name = dmg_type.capitalize()
		lines.append(label_name + ": " + defence_pct + "%  | ATK: " + atk_pct + "%  | Flat: " + str(flat_bonus))

	return "\n".join(lines)

var _warned_missing_skill_label := false

func updateEnemySkills(body):
	for child in enemy_skill_grid.get_children():
		if child != skill_template:
			child.queue_free()
	skill_template.visible = false
	var skills_list = Global.getSpeciesSkills(body.stats.species)
	for i in range(skills_list.size()):
		var skill_name = skills_list[i]
		if !Global.skills.has(skill_name):
			continue
		var icon = skill_template.duplicate()
		icon.visible = true
		icon.texture = Global.skills[skill_name]
		var cd_path = Global.skills[skill_name].resource_path

		# Was `icon.get_node("Label")` -- if the child under Icon1 isn't
		# actually named "Label" this throws and silently drops the
		# cooldown number for every skill with no visible error in-game.
		# get_node_or_null + a one-time warning makes that failure visible
		# instead of just "cooldowns don't show".
		var label = icon.get_node_or_null("Label")
		if label == null:
			if !_warned_missing_skill_label:
				_warned_missing_skill_label = true
				push_error("CrossairInspect.gd: skill_template (GridContainer/Icon1) has no child node named 'Label' -- cooldown numbers can't be displayed until that node exists.")
			enemy_skill_grid.add_child(icon)
			continue

		if body != null and "skill_cooldowns" in body and body.skill_cooldowns != null and body.skill_cooldowns.has(cd_path):
			label.text = str(int(ceil(body.skill_cooldowns[cd_path])))
			label.visible = true
		else:
			label.visible = false

		enemy_skill_grid.add_child(icon)



func forceUnfreezeMob(body) -> void:
	# Safety net: whatever's going on with a mob's own relevance/sleep
	# state, if the player is actively inspecting it via the crosshair,
	# it should never sit there frozen. This directly clears the mob's
	# sleep flag and marks it relevant so its AI/animation resumes
	# immediately instead of waiting for its own periodic recheck.
	if body == null or !is_instance_valid(body):
		return
	if body.is_in_group("Player"):
		return
	if "sleeping" in body:
		body.sleeping = false
	if "_is_relevant" in body and !body._is_relevant:
		body._is_relevant = true
		Global.markActive(body)
	if "animation_tree" in body and is_instance_valid(body.animation_tree) and !body.animation_tree.active and !body.is_dead:
		body.animation_tree.active = true
