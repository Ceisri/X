extends Node



var species_data = {}


func _ready():
	var f=File.new()
	if f.file_exists("res://world/json/species.json"):
		f.open("res://world/json/species.json",File.READ)
		species_data=parse_json(f.get_as_text())
		f.close()
		_apply_species()
		rebuildOnHitEffects()

func _apply_species():
	var s=species_data.get(species,null)
	if s==null:return
	if s.has("male") or s.has("female"):
		s=s.get(sex,s)
	base_max_health=s.get("base_max_health",base_max_health)
	base_walk_speed=s.get("base_walk_speed",base_walk_speed)
	base_run_speed=s.get("base_run_speed",base_run_speed)
	var a=s.get("attributes",{})
	for k in a:
		attributes[k]=a[k]

onready var parent = $".."
# Signals
signal health_changed
signal arcane_changed


# Exported variables
export var is_civilised: bool = false
export var is_tense: bool = false
export var species: String = "species"
export var sex: String = "male"

export var food_chain: int = 1
export var is_predator: bool = false
export var hunt_radius = 50

export var weight = 10

export var energy  =100
export var max_energy = 100 

export var max_health = 100 
export var health = 100 

export var arcane = 100 
export var max_arcane = 100 



export var walk_speed = 2.5
export var run_speed = 6

export var attack_range: float = 3
export var can_be_moved: bool = true


# Stats
var agility = 1
var power = 1
var charisma = 1
var vitality = 1


var parry_chance = 0.6
var last_health = -1
var last_damage_time = 0
var damage_check_window = 3000


# Survival
var nutrition = 60
var hydration = 100
var nutrition_loss_tick = 10


# Progression
var skill_points = 100
var used_skill_points = 0


# State
var is_finished: bool = false
var Name = ""


# Misc
var Names = [
	"Storm",
	"Shadow",
	"Blaze",
	"Thunder",
	"Spirit",
	"Comet",
	"Ash",
	"Dusty",
	"Midnight",
	"River",
	"Vaelor"
]



var base_max_health = 100
var base_walk_speed = 3
var base_run_speed = 7





var available_attribute_points:int = 0
var attributes = {
	"strength": 1,
	"power": 1,
	"agility": 1,
	"dexterity": 1,
	"vitality": 1,
	"toughness": 1,
	"instinct": 1,
	"perception": 1,
	"intelligence": 1,
	"wisdom": 1,
	"haste": 1,
	"charisma": 1,
	"authority": 1
}

var derived_stats = {
	"attack_speed": 1.0,
	"climb_speed": 1.0,
	"swim_speed": 1.0,
	"run_speed": 15.0,
	"jump_power": 1.0,
	"fall_resistance": 0.0,
	
	"atk_turn_speed": 0.15,
	"dash_turn_speed": 7.0,
	"turn_speed": 4.0,


	"carry_weight": 10.0,
	"crit_chance": 0.05,
	"crit_damage": 1.5,
	
	"penetrating_hit_chance": 0.0,
	"penetration_power": 0.5,
	
	
	"detection_range": 10.0,
	"energy_regeneration": 1.0,
	"health_regeneration": 0.0,
	"cooldown_reduction": 0.0,
	"threat": 1.0
}



func updateAttributes():
	max_health = base_max_health + get_total_attribute("vitality")* 20
	# Primary stats
	max_health = base_max_health + get_total_attribute("vitality") * 20

	walk_speed = base_walk_speed + get_total_attribute("agility") * 0.2
	run_speed = base_run_speed + get_total_attribute("agility") * 0.4

	max_arcane = 100 + get_total_attribute("wisdom") * 10

	for k in defences:
		defences[k] = get_total_attribute("toughness") * 2.0

	derived_stats["attack_speed"] = get_total_attribute("dexterity")

	derived_stats["cooldown_reduction"] = (
		get_total_attribute("haste") * 0.85 +
		get_total_attribute("instinct") * 0.10 +
		get_total_attribute("wisdom") * 0.05
	)

	derived_stats["climb_speed"] = 1.0 + get_total_attribute("dexterity") * 0.20 + get_total_attribute("strength") * 0.80
	derived_stats["swim_speed"] = 1.0 + get_total_attribute("strength") * 0.55 + get_total_attribute("agility") * 0.45

	derived_stats["run_speed"] = 16.0 * (get_total_attribute("haste") + get_total_attribute("agility") * 0.45)

	derived_stats["fall_resistance"] = get_total_attribute("toughness") * 0.75 + get_total_attribute("agility") * 0.25

	derived_stats["turn_speed"] = 4.0 + get_total_attribute("agility")
	derived_stats["atk_turn_speed"] = 0.15 + get_total_attribute("agility") * 0.3
	derived_stats["dash_turn_speed"] = 7.0 + get_total_attribute("agility") * 3.0

	derived_stats["jump_power"] = 1.0 + get_total_attribute("power") * 3.6 + get_total_attribute("agility") * 3.6

	derived_stats["crit_chance"] = 0.05 + get_total_attribute("instinct") * 0.02
	derived_stats["penetrating_hit_chance"] = 0.05 + get_total_attribute("wisdom") * 0.02
	derived_stats["penetration_power"] = 0.1 * get_total_attribute("power") * 0.25 + get_total_attribute("strength") * 0.25
	derived_stats["crit_damage"] = 2.0 + get_total_attribute("power") * 0.05

	derived_stats["detection_range"] = 10.0 + get_total_attribute("perception") * 2.0
	derived_stats["energy_regeneration"] = 1.0 + get_total_attribute("toughness") * 0.2
	derived_stats["health_regeneration"] = 1.0 + get_total_attribute("vitality")
	derived_stats["threat"] = get_total_attribute("authority")

	health = min(health, max_health)
	arcane = min(arcane, max_arcane)

	updateCombatAttributes()
	
func get_total_attribute(name:String)->float:
	return attributes.get(name,1.0)+equipment_attributes.get(name,0.0)
func updateCombatAttributes():
	var strength_total=get_total_attribute("strength")
	var power_total=get_total_attribute("power")
	var toughness_total=get_total_attribute("toughness")

	var strength_bonus=strength_total-1.0
	var power_bonus=power_total-1.0
	var toughness_bonus=(toughness_total-1.0)*50.0

	slash_defence=defences[damage_type.slash]+toughness_bonus+equipment_defence_bonus[damage_type.slash]
	blunt_defence=defences[damage_type.blunt]+toughness_bonus+equipment_defence_bonus[damage_type.blunt]
	pierce_defence=defences[damage_type.pierce]+toughness_bonus+equipment_defence_bonus[damage_type.pierce]
	sonic_defence=defences[damage_type.sonic]+toughness_bonus+equipment_defence_bonus[damage_type.sonic]
	heat_defence=defences[damage_type.heat]+toughness_bonus+equipment_defence_bonus[damage_type.heat]
	cold_defence=defences[damage_type.cold]+toughness_bonus+equipment_defence_bonus[damage_type.cold]
	jolt_defence=defences[damage_type.jolt]+toughness_bonus+equipment_defence_bonus[damage_type.jolt]
	toxic_defence=defences[damage_type.toxic]+toughness_bonus+equipment_defence_bonus[damage_type.toxic]
	acid_defence=defences[damage_type.acid]+toughness_bonus+equipment_defence_bonus[damage_type.acid]
	arcane_defence=defences[damage_type.arcane]+toughness_bonus+equipment_defence_bonus[damage_type.arcane]
	bleed_defence=defences[damage_type.bleed]+toughness_bonus+equipment_defence_bonus[damage_type.bleed]
	radiant_defence=defences[damage_type.radiant]+toughness_bonus+equipment_defence_bonus[damage_type.radiant]

	slash_multiplier=1.0+strength_bonus+equipment_damage_bonus[damage_type.slash]
	blunt_multiplier=1.0+strength_bonus+equipment_damage_bonus[damage_type.blunt]
	pierce_multiplier=1.0+strength_bonus+equipment_damage_bonus[damage_type.pierce]
	bleed_multiplier=1.0+strength_bonus+equipment_damage_bonus[damage_type.bleed]

	sonic_multiplier=1.0+power_bonus+equipment_damage_bonus[damage_type.sonic]
	heat_multiplier=1.0+power_bonus+equipment_damage_bonus[damage_type.heat]
	cold_multiplier=1.0+power_bonus+equipment_damage_bonus[damage_type.cold]
	jolt_multiplier=1.0+power_bonus+equipment_damage_bonus[damage_type.jolt]
	toxic_multiplier=1.0+power_bonus+equipment_damage_bonus[damage_type.toxic]
	acid_multiplier=1.0+power_bonus+equipment_damage_bonus[damage_type.acid]
	arcane_multiplier=1.0+power_bonus+equipment_damage_bonus[damage_type.arcane]
	radiant_multiplier=1.0+power_bonus+equipment_damage_bonus[damage_type.radiant]


var selected_attribute := "vitality"
var equipment_damage_bonus={
	damage_type.slash:0.0,
	damage_type.blunt:0.0,
	damage_type.pierce:0.0,
	damage_type.sonic:0.0,
	damage_type.heat:0.0,
	damage_type.cold:0.0,
	damage_type.jolt:0.0,
	damage_type.toxic:0.0,
	damage_type.acid:0.0,
	damage_type.arcane:0.0,
	damage_type.bleed:0.0,
	damage_type.radiant:0.0
}

var equipment_defence_bonus={
	damage_type.slash:0.0,
	damage_type.blunt:0.0,
	damage_type.pierce:0.0,
	damage_type.sonic:0.0,
	damage_type.heat:0.0,
	damage_type.cold:0.0,
	damage_type.jolt:0.0,
	damage_type.toxic:0.0,
	damage_type.acid:0.0,
	damage_type.arcane:0.0,
	damage_type.bleed:0.0,
	damage_type.radiant:0.0
}
var equipment_attributes={
	"strength":0.0,
	"power":0.0,
	"agility":0.0,
	"dexterity":0.0,
	"vitality":0.0,
	"toughness":0.0,
	"instinct":0.0,
	"perception":0.0,
	"intelligence":0.0,
	"wisdom":0.0,
	"haste":0.0,
	"charisma":0.0,
	"authority":0.0
}

func _physics_process(delta): 
	updateAttributes()
	rebuildOnHitEffects()
	updateStatuses(delta)
	if Input.is_action_just_pressed("debug_attributes"):
		var uistats = $"../UI/Equipment/UIStats"
		if is_instance_valid(uistats):
			uistats.updateUI()
		increaseAttribute(selected_attribute)
		updateAttributes()
		var label = $"../Label"
		if is_instance_valid(label):
			label.text = (
		selected_attribute
		+ ": "
		+ str(stepify(attributes[selected_attribute], 0.01))
	)
	if Input.is_action_pressed("give_att"):
		var uistats = $"../UI/Equipment/UIStats"
		if is_instance_valid(uistats):
			uistats.updateUI()
		available_attribute_points += 10
		updateAttributes()
		energy += max_energy/2
		acid_multiplier+=100.0
		bleed_defence += 3
		debugDamage()

const ATTRIBUTE_STEP := 0.05
const MIN_ATTRIBUTE := 0.25



var attribute_points_spent = {
	"strength": 0,
	"power": 0,
	"agility": 0,
	"dexterity": 0,
	"vitality": 0,
	"toughness": 0,
	"instinct": 0,
	"perception": 0,
	"intelligence": 0,
	"wisdom": 0,
	"haste": 0,
	"charisma": 0,
	"authority": 0
}
func getAttributeValue(points:int) -> float:
	var value = 1.0

	var remaining = abs(points)
	var tier_size = 10

	var gain = 0.025
	var minimum_gain = 0.01

	while remaining > 0:
		var used = min(remaining, tier_size)

		if points > 0:
			value += used * gain
		else:
			value -= used * gain

		remaining -= used

		gain *= 0.5
		gain = max(gain, minimum_gain)

	return max(MIN_ATTRIBUTE, value)
func increaseAttribute(attribute_name:String) -> void:

	if !attributes.has(attribute_name):
		return

	if available_attribute_points < 1:
		return

	attribute_points_spent[attribute_name] += 1
	available_attribute_points -= 1

	attributes[attribute_name] = getAttributeValue(
		attribute_points_spent[attribute_name]
	)

	updateAttributes()


func decreaseAttribute(attribute_name:String) -> void:

	if !attributes.has(attribute_name):
		return

	var current_value = getAttributeValue(
		attribute_points_spent[attribute_name]
	)

	var next_value = getAttributeValue(
		attribute_points_spent[attribute_name] - 1
	)

	if current_value <= MIN_ATTRIBUTE:
		return

	if next_value < MIN_ATTRIBUTE:
		return

	attribute_points_spent[attribute_name] -= 1
	available_attribute_points += 1

	attributes[attribute_name] = next_value

	updateAttributes()


var weapon_damages = {
	damage_type.slash: 100,
	damage_type.blunt: 100,
	damage_type.pierce: 100,
	damage_type.sonic: 100,
	damage_type.heat: 100,
	damage_type.cold: 100,
	damage_type.jolt:100,
	damage_type.toxic: 100,
	damage_type.acid:100,
	damage_type.arcane: 100,
	damage_type.bleed: 100,
	damage_type.radiant:100,
}
var defences = {
	damage_type.slash: 3000,
	damage_type.blunt: 0,
	damage_type.pierce: 0,
	damage_type.sonic: 0,
	damage_type.heat: 0,
	damage_type.cold: 0,
	damage_type.jolt: 0,
	damage_type.toxic: 0,
	damage_type.acid: 3000,
	damage_type.arcane: 0,
	damage_type.bleed: 0,
	damage_type.radiant: 0
}

enum damage_type {
	slash,
	blunt,
	pierce,
	sonic,
	heat,
	cold,
	jolt,
	toxic,
	acid,
	arcane,
	bleed,
	radiant
}

var slash_multiplier:float=1.0
var blunt_multiplier:float=1.0
var pierce_multiplier:float=1.0
var sonic_multiplier:float=1.0
var heat_multiplier:float=1.0
var cold_multiplier:float=1.0
var jolt_multiplier:float=1.0
var toxic_multiplier:float=1.0
var acid_multiplier:float=1.0
var arcane_multiplier:float=1.0
var bleed_multiplier:float=1.0
var radiant_multiplier:float=1.0

var slash_defence:float=0.0
var blunt_defence:float=0.0
var pierce_defence:float=0.0
var sonic_defence:float=0.0
var heat_defence:float=0.0
var cold_defence:float=0.0
var jolt_defence:float=0.0
var toxic_defence:float=0.0
var acid_defence:float=100.0
var arcane_defence:float=0.0
var bleed_defence:float=0.0
var radiant_defence:float=0.0


onready var mob_status_grid:GridContainer=$"../UI/CrossairInspect/MobStatusGrid"
onready var player_status_grid:GridContainer=$"../UI/Menu/CharacterBar/PlayerStatusGrid"
onready var player_example_icon:TextureRect = $"../UI/Menu/CharacterBar/PlayerStatusGrid/Icon1"
onready var mob_example_icon:TextureRect = $"../UI/CrossairInspect/GridContainer/Icon1"
func updateStatusUI():
	_updateStatusGrid(player_status_grid, self)
func _updateStatusGrid(grid:GridContainer, source)->void:
	if grid == null or source == null:
		return

	var template := grid.get_node("Icon1")

	for child in grid.get_children():
		if child != template:
			child.queue_free()

	template.visible = false

	for status_name in source.statuses.keys():

		if !PlayerSkills.status_icons.has(status_name):
			continue

		var s = source.statuses[status_name]

		if typeof(s) == TYPE_ARRAY:
			for entry in s:
				var icon = template.duplicate()
				icon.visible = true
				icon.name = "Icon_" + status_name
				icon.texture = PlayerSkills.status_icons[status_name]

				var label = icon.get_node("Label")
				if label:
					label.text = str(int(ceil(entry["duration"])))

				grid.add_child(icon)
		else:
			var icon = template.duplicate()
			icon.visible = true
			icon.name = "Icon_" + status_name
			icon.texture = PlayerSkills.status_icons[status_name]

			var label = icon.get_node("Label")
			if label:
				label.text = str(int(ceil(s["duration"])))

			grid.add_child(icon)
func _process(delta):
	if is_instance_valid($"../StatusesLabel"):
		var label =  $"../StatusesLabel"

		if statuses.empty():
			label.text = ""
			return

		var text := ""

		for status_name in statuses.keys():
			var s = statuses[status_name]
			text += status_name + " (" + str(ceil(s["duration"])) + ")\n"

		label.text = text.strip_edges()
var statuses = {}
var StatusDB = {
	"bleed": {
		"base_tick_damage": 2.0,
		"duration": 5.0,
		"can_stack": true,
		"bleed_multiplier": true
	},

	"stun": {
		"disable_actions": true,
		"duration": 2.0,
		"can_stack": false
	},

	"slow": {
		"agility_mult": 0.5,
		"duration": 3.0,
		"can_stack": false
	},

	"armor_break": {
		"defense_mult": 0.7,
		"duration": 4.0,
		"can_stack": false
	}
}

func applyStatus(status_name:String, applier:Node = null,current_skill:String = "")->void:
	if !StatusDB.has(status_name):
		return

	var data = StatusDB[status_name]
	var stackable = data.get("can_stack", false)

	var final_duration = data.get("duration", 0.0)
	var tick_damage = data.get("tick_damage", 0.0)

	if status_name == "bleed":
		var bleed = getBleedData(current_skill)

		final_duration = bleed["duration"]
		tick_damage = bleed["tick_damage"]
		stackable = bleed["can_stack"]

	if !stackable and statuses.has(status_name):
		statuses[status_name]["duration"] = max(
			statuses[status_name]["duration"],
			final_duration
		)
		updateStatusUI()
		return

	if stackable:
		if !statuses.has(status_name):
			statuses[status_name] = []

		statuses[status_name].append({
			"duration": final_duration,
			"tick_timer": 1.0,
			"applier": applier,
			"tick_damage": tick_damage
		})
	else:
		statuses[status_name] = {
			"duration": final_duration,
			"tick_timer": 1.0,
			"applier": applier,
			"tick_damage": tick_damage
		}

	_applyStatusEffects(status_name, applier)
	updateStatusUI()
func getBleedData(skill:String)->Dictionary:

	if !PlayerSkills.status_debuffs.has(skill):
		return {
			"tick_damage":2.0,
			"duration":3.0,
			"can_stack":false
		}

	var bleed = PlayerSkills.status_debuffs[skill]["bleed"]

	return {
		"tick_damage":bleed["base_damage"] * bleed_multiplier,
		"duration":bleed["duration"],
		"can_stack":bleed["can_stack"]
	}
func _applyStatusEffects(status_name:String, applier:Node)->void:
	if !StatusDB.has(status_name):
		return

	var data = StatusDB[status_name]

	match status_name:
		"stun":
			get_parent().anim_locks["stunned"] = true

			if applier != null and applier.has_node("Stats") and parent.has_method("get_or_create_aggro_target"):
				var inst = parent.get_or_create_aggro_target(applier)
				inst.aggro += applier.stats.derived_stats["threat"]

		"slow":
			if derived_stats.has("agility_mult"):
				derived_stats["agility_mult"] *= data["agility_mult"]

		"armor_break":
			if derived_stats.has("defense_mult"):
				derived_stats["defense_mult"] *= data["defense_mult"]
	updateStatusUI()

func updateStatuses(delta:float)->void:
	var to_remove = []

	for status_name in statuses.keys():
		var s = statuses[status_name]

		# STACKED STATUS (Array)
		if typeof(s) == TYPE_ARRAY:
			for i in range(s.size() - 1, -1, -1):
				var entry = s[i]

				entry["duration"] -= delta
				entry["tick_timer"] -= delta

				if entry["tick_timer"] <= 0.0:
					getHit(entry.get("applier", self), {damage_type.bleed: entry["tick_damage"]}, false, 0.0, false)
					entry["tick_timer"] = 1.0

				if entry["duration"] <= 0.0:
					s.remove(i)

			if s.size() == 0:
				to_remove.append(status_name)

		# SINGLE STATUS (Dictionary)
		else:
			var applier = s.get("applier", null)

			s["duration"] -= delta
			s["tick_timer"] -= delta

			if status_name == "bleed" and s["tick_timer"] <= 0.0:
				getHit(applier if applier != null else self, {damage_type.bleed: s["tick_damage"]}, false, 0.0, false)
				s["tick_timer"] = 1.0

			if s["duration"] <= 0.0:
				to_remove.append(status_name)

	for r in to_remove:
		_removeStatus(r)

	updateStatusUI()
	
	
	
	
func _removeStatus(status_name:String)->void:
	if !statuses.has(status_name):
		return

	# reverse effects if needed
	match status_name:
		"stun":
			if parent.has_method("setAnimLock"):
				parent.setAnimLock("stunned", false)
				parent.setAnimLock("staggered", false)
				parent.anim_locks["stunned"] = false
				parent.anim_locks["staggered"] = false

				parent.unlockAnim()

		"slow":
			pass # no need if multiplicative stats used

		"armor_break":
			pass

	statuses.erase(status_name)
	updateStatusUI()












onready var skill_tree_holder = $"../UI/SkillTreeRoot/SkillsTreeHolder/Control"

func getSkillLevel(skill_name:String) -> int:

	if skill_tree_holder == null:
		return 0

	for child in skill_tree_holder.get_children():

		if child == null:
			continue

		if !child.name.begins_with("SkillButton"):
			continue

		var slot = child.get_node_or_null("Slot")

		if slot == null or slot.texture == null:
			continue

		var texture_path = slot.texture.resource_path

		for skill in PlayerSkills.skills:

			if PlayerSkills.skills[skill] == null:
				continue

			if PlayerSkills.skills[skill].resource_path != texture_path:
				continue

			if skill != skill_name:
				break

			if "skill_level" in child:
				return int(child.skill_level)

			return 0

	return 0


func getSkillLevelMultiplier(skill_name:String) -> float:
	return PlayerSkills.getDamageMultiplier(
		skill_name,
		max(0,getSkillLevel(skill_name)-1)
	)





var active_on_hit_effects = {}
func rebuildOnHitEffects()->void:

	active_on_hit_effects.clear()

	active_on_hit_effects["base attack"] = {
		"energy_restore":7.0
	}

	if getSkillLevel("base attack") >= 5:

		active_on_hit_effects["base attack"]["reduce_cooldowns"] = {
			"cleave":0.25,
			"section":0.25,
			"perforation trifecta":1.25
		}

	if getSkillLevel("base attack") >= 10:
		active_on_hit_effects["base attack"]["lifesteal_flat"] = 300

	# Glyph system example for later:
	#
	# if hasGlyph("bloodthirst"):
	# 	active_on_hit_effects["base attack"]["lifesteal_percent"] = 0.05
	#
	# if hasGlyph("combat_focus"):
	#
	# 	if !active_on_hit_effects["base attack"].has("reduce_cooldowns"):
	# 		active_on_hit_effects["base attack"]["reduce_cooldowns"] = {}
	#
	# 	active_on_hit_effects["base attack"]["reduce_cooldowns"]["overhead strike"] = 0.25

	if !active_on_hit_effects["base attack"].has("lifesteal_flat"):
		active_on_hit_effects["base attack"]["lifesteal_flat"] = 0.0

	if !active_on_hit_effects["base attack"].has("lifesteal_percent"):
		active_on_hit_effects["base attack"]["lifesteal_percent"] = 0.0
		
		
func dealDamage():
	var area = null

	if parent.is_in_group("Player") or parent.is_in_group("player"):
		area = $"../character/root/Skeleton/WeaponR/Short"
	else:
		area = $"../AreaDamage"

	if area == null:
		return

	var damages = {}

	var skill_name = ""
	var skill_level_mult = 1.0

	if parent.is_in_group("Player") or parent.is_in_group("player"):
		skill_name = parent.current_skill
		skill_level_mult = getSkillLevelMultiplier(skill_name)

		var skill_damages = PlayerSkills.getDamages(skill_name)

		for dmg_type in skill_damages:

			var mult = 1.0

			match dmg_type:
				DamageTypes.Type.slash: mult = slash_multiplier
				DamageTypes.Type.blunt: mult = blunt_multiplier
				DamageTypes.Type.pierce: mult = pierce_multiplier
				DamageTypes.Type.sonic: mult = sonic_multiplier
				DamageTypes.Type.heat: mult = heat_multiplier
				DamageTypes.Type.cold: mult = cold_multiplier
				DamageTypes.Type.jolt: mult = jolt_multiplier
				DamageTypes.Type.toxic: mult = toxic_multiplier
				DamageTypes.Type.acid: mult = acid_multiplier
				DamageTypes.Type.arcane: mult = arcane_multiplier
				DamageTypes.Type.bleed: mult = bleed_multiplier
				DamageTypes.Type.radiant: mult = radiant_multiplier

			damages[dmg_type] = skill_damages[dmg_type] * mult * skill_level_mult

	else:

		if parent.has_node("Combat"):
			skill_name = parent.get_node("Combat").current_cast_skill
			var mob_damages = MobSkills.getDamages(skill_name)

			executeSpell()

			for damage_name in mob_damages:
				if damage_type.has(damage_name):
					var dmg_type = damage_type[damage_name]
					damages[dmg_type] = mob_damages[damage_name]

	if damages.size() == 0:
		return

	var my_stats = parent.get_node_or_null("Stats")
	var my_species = my_stats.species if my_stats != null else ""

	var is_crit = my_stats != null and randf() <= my_stats.derived_stats["crit_chance"]

	if is_crit:
		for dmg_type in damages:
			damages[dmg_type] *= my_stats.derived_stats["crit_damage"]

	var total_damage := 0.0
	for v in damages.values():
		total_damage += v

	var is_penetrating_hit = my_stats != null and randf() <= my_stats.derived_stats["penetrating_hit_chance"]

	for body in area.get_overlapping_bodies():

		if body == parent:
			continue

		if !(body.is_in_group("Entity") or body.is_in_group("Player") or body.is_in_group("player")):
			continue

		var other_stats = body.get_node_or_null("Stats")

		if other_stats != null and my_species != "" and other_stats.species == my_species:
			continue

		if body.has_node("Stats"):
			body.get_node("Stats").getHit(parent, damages, is_penetrating_hit, 0.0, is_crit)
			body.get_node("Stats").applyStatus("bleed", parent,skill_name)
			var skillbar = $"../UI/Skillbar"
			if parent.is_in_group("Player") or parent.is_in_group("player"):
				PlayerSkills.applyOnHitEffects(skill_name,active_on_hit_effects,skillbar.active_cooldowns,my_stats,total_damage)




func getHit(attacker:Node,damages:Dictionary,is_penetrating_hit:bool,extra_threat:float,is_crit:bool=false)->void:
	var total_damage:=0.0
	var final_damages={}

	for dmg_type in damages:

		var damage=damages[dmg_type]
		var defence:=0.0

		match dmg_type:
			damage_type.slash: defence=slash_defence
			damage_type.blunt: defence=blunt_defence
			damage_type.pierce: defence=pierce_defence
			damage_type.sonic: defence=sonic_defence
			damage_type.heat: defence=heat_defence
			damage_type.cold: defence=cold_defence
			damage_type.jolt: defence=jolt_defence
			damage_type.toxic: defence=toxic_defence
			damage_type.acid: defence=acid_defence
			damage_type.arcane: defence=arcane_defence
			damage_type.bleed: defence=bleed_defence
			damage_type.radiant: defence=radiant_defence

		var mitigation=defence/(defence+45.0)
		if is_penetrating_hit:
			mitigation*=1.0-attacker.stats.derived_stats["penetration_power"]

		

		var final_damage=damage*(1.0-mitigation)

		final_damages[dmg_type]=final_damage
		total_damage+=final_damage

	if !(parent.is_in_group("Player") or parent.is_in_group("player")):

		var instigatorAggro=parent.get_or_create_aggro_target(attacker)
		instigatorAggro.aggro+=((total_damage*attacker.stats.derived_stats["threat"]))

	health-=total_damage

	if parent.stats.health>0:
		if attacker!=parent:
			attacker.stored_body=parent
	else:
		attacker.stored_body=null

	if is_instance_valid($"../UI/Menu/CharacterBar"):
		$"../UI/Menu/CharacterBar".updateBars()

	spawnDamageText(final_damages,is_crit,is_penetrating_hit)









func debugDamage(amount: float = 10.0) -> void:

	var damages = {damage_type.bleed: amount}
	if parent.is_in_group("Player"):
		getHit(
			parent,
			damages,
			false,
			0.0,
			false
		)

func spawnDamageText(
	damages: Dictionary,
	is_crit: bool = false,
	is_penetrating_hit: bool = false
) -> void:

	var text := ""

	if is_crit:
		text += "CRITICAL!\n"

	if is_penetrating_hit:
		text += "PENETRATING!\n"

	for dmg_type in damages:
		text += (
			str(round(damages[dmg_type]))
			+ " "
			+ damageTypeToString(dmg_type)
			+ "\n"
		)

	var floating_res = CommonBehaviours.FloatingResScene.instance()
	floating_res.text = text.strip_edges()

	# Player got hit
	if parent.is_in_group("Player") or parent.is_in_group("player"):

		floating_res.use_screen_center = false

		var menu =  $"../UI/Menu/CharacterBar/Control"

		if is_instance_valid(menu):
			menu.add_child(floating_res)
			return

	# Mob got hit
	floating_res.use_screen_center = false

	var camera = get_viewport().get_camera()

	if camera:
		floating_res.world_position = camera.unproject_position(
			parent.global_transform.origin + Vector3.UP * 2.0
		)

	get_tree().root.add_child(floating_res)



func damageTypeToString(dmg_type: int) -> String:
	match dmg_type:
		damage_type.slash: return "Slash"
		damage_type.blunt: return "Blunt"
		damage_type.pierce: return "Pierce"
		damage_type.sonic: return "Sonic"
		damage_type.heat: return "Heat"
		damage_type.cold: return "Cold"
		damage_type.jolt: return "Jolt"
		damage_type.toxic: return "Toxic"
		damage_type.acid: return "Acid"
		damage_type.arcane: return "Arcane"
		damage_type.bleed: return "Bleed"
		damage_type.radiant: return "Radiant"
		_: return "Unknown"


func executeSpell() -> void:
	var skill = parent.combat.current_cast_skill

	if skill == "":
		return

	if !MobSkills.isAttack(skill):
		return

	for body in parent.dmg_area.get_overlapping_bodies():

		if body == parent:
			continue

		# stun
		if MobSkills.isStun(skill):
			pass

		# lifesteal
		if MobSkills.isLifesteal(skill):

			var total_damage = 0

			for damage_name in MobSkills.getDamages(skill):
				total_damage += MobSkills.getDamages(skill)[damage_name]

			var heal = (
				total_damage
				* MobSkills.getLifestealPower(skill)
			)

			health += heal

		# cooldown reduction
		if MobSkills.isCooldownReduce(skill):

			var reduction = (
				MobSkills.getCooldownReducePower(skill)
			)

			for cd_skill in parent.combat.active_cooldowns.keys():

				parent.combat.active_cooldowns[cd_skill] *= (
					1.0 - reduction
				)

				if parent.combat.active_cooldowns[cd_skill] <= 0:
					parent.combat.active_cooldowns.erase(cd_skill)


func getSkillArcaneCost(skill:String) -> float:

	# Players
	if owner.is_in_group("Player") or owner.is_in_group("player"):
		return PlayerSkills.getArcaneCost(skill)

	# Mobs / NPCs
	if owner.is_in_group("Entity"):
		return MobSkills.getArcaneCost(skill)

	return 0.0


func canUseSkill(skill:String) -> bool:
	return arcane >= getSkillArcaneCost(skill)


func consumeSkillArcane(skill:String) -> bool:

	var cost = getSkillArcaneCost(skill)

	if cost <= 0:
		return true

	if arcane < cost:
		return false

	arcane -= cost

	return true


func regenerate(value, resource, max_resource):
	return min(resource + value, max_resource)
		
