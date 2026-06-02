extends Node

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



var weapon_damages = {
	damage_type.slash: 0,
	damage_type.blunt: 0,
	damage_type.pierce: 0,
	damage_type.sonic: 0,
	damage_type.heat: 0,
	damage_type.cold: 0,
	damage_type.jolt: 0,
	damage_type.toxic: 0,
	damage_type.acid: 0,
	damage_type.arcane: 0,
	damage_type.bleed: 0,
	damage_type.radiant: 0
}
var defences = {
	damage_type.slash: 0,
	damage_type.blunt: 0,
	damage_type.pierce: 0,
	damage_type.sonic: 0,
	damage_type.heat: 0,
	damage_type.cold: 0,
	damage_type.jolt: 0,
	damage_type.toxic: 0,
	damage_type.acid: 0,
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
	"jump_power": 1.0,
	"carry_weight": 10.0,
	"crit_chance": 0.05,
	"crit_damage": 1.5,
	"detection_range": 10.0,
	"energy_regeneration": 1.0,
	"health_regeneration": 0.0,
	"cooldown_reduction": 0.0,
	"threat": 1.0
}



func updateAttributes():

	# Primary stats
	max_health = base_max_health + attributes["vitality"] * 20

	walk_speed = base_walk_speed + attributes["agility"] * 0.2
	run_speed = base_run_speed + attributes["agility"] * 0.4

	max_arcane = 100 + attributes["wisdom"] * 10

	for dmg_type in defences:
		defences[dmg_type] = attributes["toughness"] * 2

	# Derived stats
	derived_stats["attack_speed"] = (attributes["dexterity"])
	derived_stats["cooldown_reduction"] = (attributes["haste"] * 0.85 + attributes["instinct"] * 0.10 + attributes["wisdom"] * 0.05 )
	derived_stats["climb_speed"] = (1.0+ attributes["dexterity"] * 0.20+ attributes["strength"] * 0.80)

	derived_stats["swim_speed"] = (1.0+ attributes["strength"] * 0.55+ attributes["agility"] * 0.45)

	derived_stats["jump_power"] = (1.0+ attributes["power"] * 0.55+ attributes["agility"] * 0.45)

	derived_stats["crit_chance"] = (0.05+ attributes["instinct"] * 0.02)

	derived_stats["crit_damage"] = (1.5+ attributes["power"] * 0.05)
	derived_stats["detection_range"] = (10+ attributes["perception"] * 2)
	derived_stats["energy_regeneration"] = (1+ attributes["toughness"] * 0.2)

	derived_stats["health_regeneration"] = (1 + attributes["vitality"])
	derived_stats["threat"] = (1.0* attributes["authority"])

	health = min(health, max_health)
	arcane = min(arcane, max_arcane)

var selected_attribute := "vitality"



#func _physics_process(delta):
#	updateAttributes()
#	if Input.is_action_just_pressed("debug_attributes"):
#		increaseAttribute(selected_attribute)
#		updateAttributes()
#		var label = $"../Label"
#		if is_instance_valid(label):
#			label.text = (
#		selected_attribute
#		+ ": "
#		+ str(stepify(attributes[selected_attribute], 0.01))
#	)
#	if Input.is_action_just_pressed("give_att"):
#		available_attribute_points += 10
#		updateAttributes()
#		energy += max_energy/2

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
	var gain = 0.05

	while remaining > 0:
		var used = min(remaining, tier_size)

		if points > 0:
			value += used * gain
		else:
			value -= used * gain

		remaining -= used
		gain *= 0.5

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



var skill_damages = {
	"cleave": {
		damage_type.bleed: 2
		
	},

	"base_atk": {
		damage_type.slash: 1
	},

	"battlecry": {
		damage_type.sonic: 3
	},

	"dodge": {
		damage_type.blunt: 3
	},

	"flame_slash": {
		damage_type.slash: 10,
		damage_type.heat: 8
	},

	"holy_strike": {
		damage_type.blunt: 6,
		damage_type.radiant: 12
	}
}


func getHit(attacker: Node, damages: Dictionary, extra_penetrate_chance: float, extra_threat: float) -> void:
	var total_damage := 0.0
	var final_damages := {}

	for dmg_type in damages:
		var damage = damages[dmg_type]
		var defence = defences.get(dmg_type, 0.0)
		var mitigation = defence / (defence + 100.0)
		mitigation = clamp(mitigation - extra_penetrate_chance,0.0,0.95)
		var final_damage = damage * (1.0 - mitigation)
		final_damages[dmg_type] = final_damage
		total_damage += final_damage

	if not (parent.is_in_group("Player") or parent.is_in_group("player")):
		var instigatorAggro = parent.get_or_create_aggro_target(attacker)
		instigatorAggro.aggro += total_damage + extra_threat * attacker.stats.derived_stats["threat"]

	health -= total_damage
	if is_instance_valid($"../UI/Menu/CharacterBar"):
		$"../UI/Menu/CharacterBar".updateBars()
	spawnDamageText(final_damages)


func dealDamage():

	var area = null

	if parent.is_in_group("Player") or parent.is_in_group("player"):
		area = $"../Area/Melee"
	else:
		area = $"../AreaDamage"

	if area == null:
		return

	var damages = {}
	# PLAYER DAMAGE
	if parent.is_in_group("Player") or parent.is_in_group("player"):
		var skill = parent.current_skill
		if skill_damages.has(skill):
			for dmg_type in skill_damages[skill]:
				damages[dmg_type] = damages.get(dmg_type, 0) + skill_damages[skill][dmg_type]
		for dmg_type in weapon_damages:
			var damage = weapon_damages[dmg_type]
			if damage > 0:
				damages[dmg_type] = damages.get(dmg_type, 0) + damage
	# MOB DAMAGE
	else:
		if parent.has_node("Combat"):

			var combat = parent.get_node("Combat")
			var skill_name = combat.current_cast_skill

			var mob_damages = MobSkills.getDamages(skill_name)

			executeSpell()

			for damage_name in mob_damages:
				if damage_type.has(damage_name):
					var dmg_type = damage_type[damage_name]
					damages[dmg_type] = damages.get(dmg_type, 0) + mob_damages[damage_name]

	if damages.size() == 0:
		return

	var my_stats = parent.get_node_or_null("Stats")
	var my_species = ""
	if my_stats != null:
		my_species = my_stats.species

	for body in area.get_overlapping_bodies():

		if body == parent:
			continue

		if not (
			body.is_in_group("Entity")
			or body.is_in_group("Player")
			or body.is_in_group("player")
		):
			continue

		var other_stats = body.get_node_or_null("Stats")
		if other_stats != null:
			if my_species != "" and other_stats.species == my_species:
				continue

		if body.has_node("Stats"):
			body.get_node("Stats").getHit(
				parent,
				damages,
				0.0,
				0.0
			)

func spawnDamageText(damages: Dictionary) -> void:
	var text := ""

	for dmg_type in damages:
		text += str(round(damages[dmg_type])) + " " + damageTypeToString(dmg_type) + "\n"

	var floating_res = CommonBehaviours.FloatingResScene.instance()
	floating_res.text = text.strip_edges()
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
		
