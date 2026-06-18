extends Node

var skills = {
	"combo attack":preload("res://world/interface/assets/icons/Combat_icons/Generic_skills/combo_attack.png"),
	"guard":preload("res://world/interface/assets/icons/Combat_icons/Generic_skills/Skill_Defence.png"),
	"backstep":preload("res://world/interface/assets/icons/Combat_icons/unarmed/Aura_Jump.png"),
	
	
	
	"section":preload("res://world/interface/assets/icons/Combat_icons/Generic_skills/axe1.png"),
	"perforation trifecta":preload("res://world/interface/assets/icons/Combat_icons/Scout_skill_icons/carve.png"),
	"parry":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/Skill_Parry.png"),

	
#BERSERK_______________________________________________________________________
	"raze":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/raze.png"),
	"reckless vengeance":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/reckless venguance.png"),
	
	"shoulder bash":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/charge.png"),
	"stone splitter":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/stone_splitter.png"),
	
	"brutal chop":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/brutal chop.png"),
	"sadistic blow":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/sadistic blow.png"),
	"fury strike":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/fury strike.png"),
	"obliteration charge":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/obliteration.png"),
	"obliteration":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/obliteration.png"),
	
	"heart thrust":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/heart thrust.png"),
	"sunder":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/sunder.png"),
	"sledge":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/sledge.png"),

}

var skill_damages = {
#STARTER________________________________________________________________________
	"combo attack": {
		DamageTypes.Type.slash: 40,
	},
#BERSERK_______________________________________________________________________
	"raze": {
		DamageTypes.Type.slash: 100, #hits twice per skill
	},
	"stone splitter": {
		DamageTypes.Type.slash: 75,
		DamageTypes.Type.blunt: 75,
	},
	"brutal chop": {
		DamageTypes.Type.slash: 45,
		DamageTypes.Type.blunt: 45,
	},
	"shoulder bash": {
		DamageTypes.Type.blunt: 75,
	},
	"heart thrust": {
		DamageTypes.Type.pierce: 148,
	},
	"fury strike": {
		DamageTypes.Type.slash: 70,
	},
	"sadistic blow": {
		DamageTypes.Type.slash: 78,
	},
	"sunder": {
		DamageTypes.Type.slash: 85,
		DamageTypes.Type.blunt: 75,
	},
	"sledge": {
		DamageTypes.Type.slash: 85,
		DamageTypes.Type.blunt: 125,
	},
	"obliteration": {
		DamageTypes.Type.slash: 85,
	},
}	
	

var descriptions = {
	"combo attack":"""Hits all enemies in front of you.""",

#BERSERK_______________________________________________________________________
	"stone splitter":"""
Very slow slamming attack, sped up by the end of [combo attack]
and [perforation trifecta].

Deals double damage to staggered, downed or stunned enemies.
""",

"reckless vengeance":"""
Enter a blood frenzy state, taking 80% more damage from all sources. While berserk, 
100% of damage received is reflected back to the attacker, and this reflected damage ignores all defenses, resistances, and damage reduction effects.
Movement speed and attack speed are reduced by 11%, but all attacks deal 55% more damage.
Resets [Raze] and reduces the cooldown of all berserk skills by 5 seconds.
"""
}


var chargeable_skills = [
	"obliteration charge"
]
var skill_rotation_allowed = {
	"combo attack":true,
	"parry":false,
	"guard":false,
	"sledge":false,
	"stone splitter":false,
	"raze":true,
}

func canRotateDuringSkill(skill:String)->bool:
	return skill_rotation_allowed.get(skill,true)
var cooldowns = {
#STARTER________________________________________________________________________
	skills["combo attack"].resource_path:0.0,
#BERSERK_______________________________________________________________________
	skills["raze"].resource_path:14,
	skills["shoulder bash"].resource_path:7,
	skills["stone splitter"].resource_path:8,
	skills["brutal chop"].resource_path:4,
	skills["fury strike"].resource_path:9,
	skills["sunder"].resource_path:15,
	skills["sadistic blow"].resource_path:5,
	skills["heart thrust"].resource_path:18,
	skills["obliteration charge"].resource_path:7,
	skills["sledge"].resource_path: 4,
	skills["reckless vengeance"].resource_path: 30,

	}
var berserk_reckless_gamble_cd_reduce:float = 5
var cooldown_effects = {
#BERSERK_______________________________________________________________________
	# Multiple effects can exist together
	"reckless vengeance":{
		"reduce_cooldowns":{
			"sadistic blow":berserk_reckless_gamble_cd_reduce,
			"shoulder bash":berserk_reckless_gamble_cd_reduce,
			"fury strike":berserk_reckless_gamble_cd_reduce,
			"sunder":berserk_reckless_gamble_cd_reduce,
			"stone splitter":berserk_reckless_gamble_cd_reduce,
			"brutal chop":berserk_reckless_gamble_cd_reduce,

			
		},
		"reset_skills":{
			"raze":1.0,
			"heart thrust":1.0,
			
		}
	},
#	"pass":{
#		"reduce_cooldowns":{
#			"section":2.0,
#
#		},
#		"reset_skills":{
#			"perforation trifecta":0.10
#		}
#	},

	"stone splitter":{
		"self_reset_chance":0.5
	},

}



var skill_damage_level_multiplier = {
	"combo attack": 0.10,
	"sledge": 0.15,
	
	"stone splitter": 0.20,
	"shoulder bash":0.33,
	
	
}
func getDamageMultiplier(skill_name:String, skill_level:int) -> float:
	return 1.0 + skill_level * skill_damage_level_multiplier.get(skill_name, 0.0)

func getDamages(skill_name:String, weapon_mult:float = 1.0) -> Dictionary:
	var base = skill_damages.get(skill_name, {}).duplicate(true)
	for k in base.keys():
		base[k] *= weapon_mult
	return base
	
var on_hit_effects = {
	"combo attack":{
		"energy_restore":1.0,
		"lifesteal_flat":0.0,
		"lifesteal_percent":0.0,
		"reduce_cooldowns":{
			"stone splitter":0.35,
			"shoulder bash":0.5
		}
	},
}

var skill_energy_cost = {
	"combo attack": 0,
	"stone splitter": 12,
	"shoulder bash": 7,
	"reckless vengeance": 25,
	"obliteration charge": 7,
	"sledge": 17,

}


var status_icons = {
	"bleed": preload("res://world/interface/assets/icons/Combat_icons/Status/wound.png"),
	"stun": preload("res://world/interface/assets/icons/Combat_icons/Status/Skill_BoneBreak.png"),
	"staggered": preload("res://world/interface/assets/icons/Combat_icons/Status/Aura_DeathKnight.png"),
	"slow": preload("res://world/interface/assets/icons/Combat_icons/Status/Archerskill_20_jump.png"),
	"armor_break": preload("res://world/interface/assets/icons/Combat_icons/Status/hypnosis.png"),
	"decrease_armor": preload("res://world/interface/assets/icons/Combat_icons/Status/Engineerskill_29.png"),
	"burn": preload("res://world/interface/assets/icons/Combat_icons/Status/Aura_Water.png"),
	"freeze": preload("res://world/interface/assets/icons/Combat_icons/Status/Mageskill_28_nova.png"),
	"heal_flat": preload("res://world/interface/assets/icons/Combat_icons/Status/skill_134_heal.png"),
	"heal_percent_max": preload("res://world/interface/assets/icons/Combat_icons/Status/skill_132.png"),
	"berserk_buff": preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/reckless venguance.png"),
}
var status_effects = {
	"reckless vengeance": {
		"berserk_buff": {
			"duration": 15.0,
			"power": 0.10,
			"power2": 0.55,
			"can_stack": false,
			"affects": []
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



	"stone splitter": {
		"stun": {
			"duration": 2.0,
			"can_stack": false
		},
		"staggered": {
			"duration": 2.0,
			"can_stack": false
		}
	},
#	"combo attack": {
#		"bleed": {
#			"duration": 10.0,
#			"base_damage": 1.0,
#			"can_stack": true,
#			"max_stacks": 10,
#			"tick_timer":2,
#			"affects": []
#		},
#		"slow": {
#			"duration": 2.0,
#			"power": 0.25,
#			"can_stack": false,
#			"affects": []
#		},
#		"armor_break": {
#			"duration": 6.0,
#			"power": 0.99,
#			"can_stack": true,
#			"affects": ["slash_defence","blunt_defence","pierce_defence"]
#		},
#		"decrease_armor": {
#			"duration": 6.0,
#			"power": 33,
#			"can_stack": true,
#			"affects": ["cold_defence"]
#		}
#	},
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
func getEnergyCost(skill:String) -> float:
	return skill_energy_cost.get(skill, 0)
