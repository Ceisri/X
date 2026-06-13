extends Node

var skills = {
	"base attack":preload("res://world/interface/assets/icons/skills/sword/base_sword1.png"),
	"section":preload("res://world/interface/assets/icons/skills/sword/Critical_strike3.png"),
	"perforation trifecta":preload("res://world/interface/assets/icons/skills/sword/Skill_BladeMaster.png"),
	"parry":preload("res://world/interface/assets/icons/skills/sword/Skill_MeleeBlockAttack.png"),
	"cleave":preload("res://world/interface/assets/icons/skills/sword/Warriorskill_21_blades.png"),
	"overhead strike":preload("res://world/interface/assets/icons/skills/sword/Holy_power.png"),
	"battlecry":preload("res://world/interface/assets/icons/skills/unarmed/skill_189.png"),
	"death from above":preload("res://world/interface/assets/icons/skills/assasin/vortex2.png"),
	"flury of blows":preload("res://world/interface/assets/icons/skills/assasin/vortex.png"),
	"dodge":preload("res://world/interface/assets/icons/skills/unarmed/Aura_Jump.png")}

var skill_damages = {
	"cleave": {
		DamageTypes.Type.slash: 5,
		DamageTypes.Type.blunt: 5
	},
	"overhead strike": {
		DamageTypes.Type.slash: 15,
	},
	"death from above": {
		DamageTypes.Type.slash: 25,
	},
	"flury of blows": {
		DamageTypes.Type.slash: 11,
	},
	"base attack": {
		DamageTypes.Type.slash: 1000,
	},

	"perforation trifecta": {
		DamageTypes.Type.pierce: 7,
		DamageTypes.Type.slash: 3
	},

	"section": {
		DamageTypes.Type.slash: 21
	}
}


var descriptions = {
	"base attack":"Hits all enemies in front of you.",
	"cleave":"Hits all enemies in front of you.",
	"battlecry":"Increases combat effectiveness.",
	"dodge":"Avoid the next attack."}
	
var skill_rotation_allowed = {
	"base attack":true,
	"section":true,
	"death from above":false,
	"perforation trifecta":true,
	"flury of blows":false,
	"parry":false,
	"cleave":true,
	"overhead strike":false,
	"battlecry":false,
	"dodge":true
}

func canRotateDuringSkill(skill:String)->bool:
	return skill_rotation_allowed.get(skill,true)
var cooldowns = {
	skills["cleave"].resource_path:3.0,
	skills["perforation trifecta"].resource_path:33,
	skills["section"].resource_path:6,
	skills["overhead strike"].resource_path:1.5,
	skills["flury of blows"].resource_path:33.0,
	skills["death from above"].resource_path:8.0,
	skills["battlecry"].resource_path:6.0,
	skills["dodge"].resource_path:2.3,
	skills["base attack"].resource_path:0.0}
	
var cooldown_effects = {
	# 40% chance to reset Cleave
	"base attack":{
		"reset_skills":{
			"flury of blows":0.3
		}
	},
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


var skill_damage_level_multiplier = {
	"base attack": 0.10,
	"cleave": 0.15,
	"overhead strike": 0.20,
	"death from above": 0.25,
	"flury of blows": 0.10,
	"perforation trifecta": 0.15,
	"section": 0.20
}
func getDamageMultiplier(skill_name:String, skill_level:int) -> float:
	return 1.0 + skill_level * skill_damage_level_multiplier.get(skill_name, 0.0)

func getDamages(skill_name:String, weapon_mult:float = 1.0) -> Dictionary:
	var base = skill_damages.get(skill_name, {}).duplicate(true)
	for k in base.keys():
		base[k] *= weapon_mult
	return base
	
var on_hit_effects = {
	"base attack":{
		"energy_restore":1.0,
		"lifesteal_flat":0.0,
		"lifesteal_percent":0.0,
		"reduce_cooldowns":{
			"cleave":0.25,
			"section":0.25,
			"perforation trifecta":0.25,
			"overhead strike":0.35
		}
	},
}
func applyOnHitEffects(skill_name:String,effects:Dictionary,active_cooldowns:Dictionary,stats,damage_dealt:float)->void:

	if !effects.has(skill_name):
		return

	var effect = effects[skill_name]

	# ----------------------------------
	# ENERGY
	# ----------------------------------
	if effect.has("energy_restore"):
		stats.energy = min(stats.max_energy,stats.energy + effect["energy_restore"])

	# ----------------------------------
	# FLAT LIFESTEAL
	# ----------------------------------

	if effect.has("lifesteal_flat"):
		stats.health = min(stats.max_health,stats.health + effect["lifesteal_flat"])

	# ----------------------------------
	# PERCENT LIFESTEAL
	# ----------------------------------

	if effect.has("lifesteal_percent"):
		stats.health = min(stats.max_health,stats.health + damage_dealt * effect["lifesteal_percent"])
	# ----------------------------------
	# COOLDOWN REDUCTION
	# ----------------------------------

	if effect.has("reduce_cooldowns"):

		for target_skill in effect["reduce_cooldowns"]:

			if !skills.has(target_skill):
				continue

			var reduction = effect["reduce_cooldowns"][target_skill]

			var path = skills[target_skill].resource_path

			if !active_cooldowns.has(path):
				continue

			active_cooldowns[path] = max(
				0.0,
				active_cooldowns[path] - reduction
			)

			if active_cooldowns[path] <= 0.0:
				active_cooldowns.erase(path)

	if stats.health > stats.max_health:
		stats.health = stats.max_health

var skill_energy_cost = {
	"cleave": 3,
	"section": 9,
	"perforation trifecta": 7,
	"battlecry": 15,
}

func getEnergyCost(skill:String) -> float:
	return skill_energy_cost.get(skill, 0)

var status_icons = {
	"bleed": preload("res://world/interface/assets/icons/skills/assasin/cut.png"),
	"stun": preload("res://world/interface/assets/icons/skills/assasin/Skill_286.png"),
	"staggered": preload("res://world/interface/assets/icons/skills/assasin/Escape.png"),
	"slow": preload("res://world/interface/assets/icons/skills/assasin/Skill_Backstab.png"),
	"armor_break": preload("res://world/interface/assets/icons/skills/assasin/Skill_Blind.png"),
	"decrease_armor": preload("res://world/interface/assets/icons/skills/unarmed/Warriorskill_05_strong.png"),
	"burn": preload("res://world/interface/assets/icons/skills/assasin/Skill_Hostage.png"),
	"freeze": preload("res://world/interface/assets/icons/skills/assasin/Skill_HideInForest.png"),
	"heal_flat": preload("res://world/interface/assets/interface_elements/MapIcon_DotBigGreen.png"),
	"heal_percent_max": preload("res://world/interface/assets/interface_elements/MapIcon_FlagBlack.png"),
}
var status_effects = {
	"base attack": {
		"bleed": {
			"duration": 30.0,
			"base_damage": 1.0,
			"can_stack": true,
			"max_stacks": 10,
			"tick_timer":0.1,
			"affects": []
		},
		"slow": {
			"duration": 2.0,
			"power": 0.25,
			"can_stack": false,
			"affects": []
		},
		"armor_break": {
			"duration": 6.0,
			"power": 0.99,
			"can_stack": true,
			"affects": ["slash_defence","blunt_defence","pierce_defence"]
		},
		"decrease_armor": {
			"duration": 6.0,
			"power": 33,
			"can_stack": true,
			"affects": ["cold_defence"]
		}
	},

	"generic_spell_1": {
		"heal_flat": {
			"duration": 5.0,
			"power": 7.0,
			"can_stack": true,
			"tick_timer":2.5,
			"affects": []
		}
	},

	"generic_spell_2": {
		"heal_percent_max": {
			"duration": 10.0,
			"power": 0.4,
			"can_stack": false,
			"tick_timer":2.5,
			"affects": []
		}
	},





	"section": {
		"bleed": {
			"duration": 3.0,
			"base_damage": 1.0,
			"can_stack": true
		},
		"armor_break": {
			"duration": 4.0,
			"can_stack": false
		}
	},

	"cleave": {
		"bleed": {
			"duration": 4.0,
			"base_damage": 2.0,
			"can_stack": true
		},
		"staggered": {
			"duration": 1.5,
			"can_stack": false
		}
	},

	"perforation trifecta": {
		"bleed": {
			"duration": 6.0,
			"base_damage": 2.5,
			"can_stack": true
		},
		"armor_break": {
			"duration": 5.0,
			"can_stack": false
		}
	},

	"overhead strike": {
		"stun": {
			"duration": 2.0,
			"can_stack": false
		},
		"staggered": {
			"duration": 2.0,
			"can_stack": false
		}
	},

	"death from above": {
		"stun": {
			"duration": 1.5,
			"can_stack": false
		},
		"bleed": {
			"duration": 3.0,
			"base_damage": 1.5,
			"can_stack": true
		},
		"armor_break": {
			"duration": 3.0,
			"can_stack": false
		}
	},

	"flury of blows": {
		"bleed": {
			"duration": 2.0,
			"base_damage": 1.0,
			"can_stack": true
		},
		"slow": {
			"duration": 2.0,
			"power": 0.25,
			"can_stack": false
		}
	},
}
