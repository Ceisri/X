extends Node

var skills = {
	"base attack":preload("res://world/interface/assets/icons/skills/sword/base_sword1.png"),
	"section":preload("res://world/interface/assets/icons/skills/sword/Critical_strike3.png"),
	"perforation trifecta":preload("res://world/interface/assets/icons/skills/sword/Skill_BladeMaster.png"),
	"parry":preload("res://world/interface/assets/icons/skills/sword/Skill_MeleeBlockAttack.png"),
	"cleave":preload("res://world/interface/assets/icons/skills/sword/Warriorskill_21_blades.png"),
	"overhead strike":preload("res://world/interface/assets/icons/skills/sword/Holy_power.png"),
	"battlecry":preload("res://world/interface/assets/icons/skills/unarmed/skill_189.png"),
	"dodge":preload("res://world/interface/assets/icons/skills/unarmed/Aura_Jump.png")}



var descriptions = {
	"base attack":"Hits all enemies in front of you.",
	"cleave":"Hits all enemies in front of you.",
	"battlecry":"Increases combat effectiveness.",
	"dodge":"Avoid the next attack."}
var cooldowns = {
	skills["cleave"].resource_path:3.0,
	skills["perforation trifecta"].resource_path:4.5,
	skills["section"].resource_path:6,
	skills["overhead strike"].resource_path:1.5,
	skills["battlecry"].resource_path:6.0,
	skills["dodge"].resource_path:0.0,
	skills["base attack"].resource_path:0.0}
var cooldown_effects = {

	# 25% chance to completely reset its own cooldown
	"section":{
		"self_reset_chance":0.25
	},

	# 40% chance to reset Cleave
	"perforation trifecta":{
		"reset_skills":{
			"cleave":0.40
		}
	},

	# Reduce Section cooldown by 2 seconds
	"battlecry":{
		"reduce_cooldowns":{
			"section":2.0
		}
	},

	# Multiple effects can exist together
	"overhead strike":{
		"self_reset_chance":0.8,
		"reduce_cooldowns":{
			"section":2.0,
			"cleave":2.5
		},
		"reset_skills":{
			"perforation trifecta":0.10
		}
	}
}
func applyCooldownEffects(casted_skill:String,active_cooldowns:Dictionary)->void:

	if !cooldown_effects.has(casted_skill):
		return

	var effects=cooldown_effects[casted_skill]

	# ---------------------------------------
	# SELF RESET
	# ---------------------------------------
	if effects.has("self_reset_chance"):
		if randf()<=effects["self_reset_chance"]:

			var texture=skills[casted_skill]
			active_cooldowns[texture.resource_path] = 0.01

	# ---------------------------------------
	# RESET OTHER SKILLS
	# ---------------------------------------
	if effects.has("reset_skills"):

		for target_skill in effects["reset_skills"]:

			var chance=effects["reset_skills"][target_skill]

			if randf()<=chance:

				var texture=skills[target_skill]
				active_cooldowns.erase(texture.resource_path)

	# ---------------------------------------
	# REDUCE OTHER COOLDOWNS
	# ---------------------------------------
	if effects.has("reduce_cooldowns"):

		for target_skill in effects["reduce_cooldowns"]:

			var reduction=effects["reduce_cooldowns"][target_skill]

			var texture=skills[target_skill]
			var path=texture.resource_path

			if active_cooldowns.has(path):
				active_cooldowns[path]=max(
					0.0,
					active_cooldowns[path]-reduction
				)

				if active_cooldowns[path]<=0:
					active_cooldowns.erase(path)

func getCooldown(path)->float:
	if cooldowns.has(path):
		return cooldowns[path]
	return 0.0

var skill_damages = {
	"cleave": {
		DamageTypes.Type.slash: 5,
		DamageTypes.Type.blunt: 5
	},

	"base attack": {
		DamageTypes.Type.slash: 2,
		DamageTypes.Type.blunt: 2,
		DamageTypes.Type.acid: 10,
	},

	"perforation trifecta": {
		DamageTypes.Type.pierce: 7,
		DamageTypes.Type.slash: 3
	},

	"section": {
		DamageTypes.Type.slash: 21
	}
}

func getDamages(skill_name:String, weapon_mult:float = 1.0) -> Dictionary:
	var base = skill_damages.get(skill_name, {}).duplicate(true)
	for k in base.keys():
		base[k] *= weapon_mult
	return base
var skill_energy_cost = {
	"cleave": 3,
	"section": 9,
	"perforation trifecta": 7,
	"battlecry": 15,
}

func getEnergyCost(skill:String) -> float:
	return skill_energy_cost.get(skill, 0)
