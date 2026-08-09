extends Node

var descriptions = {
"combo attack":"""Hits all enemies in front of you. Successful hits restore energy.""",

#BERSERK_______________________________________________________________________
"stone splitter":"""
Very slow slamming attack, sped up by the end of [combo attack]
and most berserk skills.

Deals double damage to staggered, downed or stunned enemies.
""",

"reckless":"""
Enter a blood frenzy state, taking 80% more damage from all sources. While berserk,
100% of damage received is reflected back to the attacker, and this reflected damage ignores all defenses, resistances, and damage reduction effects.
Movement speed and attack speed are reduced by 11%, but all attacks deal 55% more damage.
Resets [Raze] and reduces the cooldown of all berserk skills by 5 seconds.
""",

#MOBS__________________________________________________________________________
"bite":"""Basic bite attack. Successful hits restore energy, heal the user, and reduce cooldowns of all mob skills by 3 seconds."""
}
var egg_spawners = {
	"forest spider":preload("res://world/mobs/eggs_skills_spawnables/EggSpawner.tscn"),
}
var projectiles = {"elemental":preload("res://world/mobs/eggs_skills_spawnables/MagicElementalProjectile.tscn"),
}


var fallback=load("res://world/interface/assets/interface_elements/MapIcon_XmarkRed.png")
#________________________________________________________________________________________________________________________
var skills = {
"combo attack":preload("res://world/interface/assets/icons/Combat_icons/Basic_skills_icons/combo_attack.png"),
"penetrating blow":preload("res://world/interface/assets/icons/Combat_icons/Basic_skills_icons/Skill_ThousandBlows.png"),
"guard":preload("res://world/interface/assets/icons/Combat_icons/Basic_skills_icons/guard.png"),
"backstep":preload("res://world/interface/assets/icons/Combat_icons/Basic_skills_icons/backstep.png"),
"evasion":preload("res://world/interface/assets/icons/Combat_icons/Basic_skills_icons/evasion.png"),


"mine":preload("res://world/interface/assets/icons/non_combat_skills/mining.png"),
"chop":preload("res://world/interface/assets/icons/non_combat_skills/chop_wood.png"),
"gather":preload("res://world/interface/assets/icons/non_combat_skills/harvest.png"),
#DROMEUS
"cross draw":preload("res://world/interface/assets/icons/Combat_icons/Assasin_skill_icons/pendulum_slash.png"),
"lunar slash":preload("res://world/interface/assets/icons/Combat_icons/Assasin_skill_icons/death_from_above.png"),
"recoil slash":preload("res://world/interface/assets/icons/Combat_icons/Assasin_skill_icons/ambush.png"),

#"":preload(),
#"":preload(),
#"":preload(),
#"":preload(),
#WARDEN_______________________________________________________________________
"veiled thrust":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/veiled_thrust.png"),
"shield bash":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/shield_bash.png"),
"shield pummel":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/shield_pummel.png"),
"mighty push":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/mighty_push.png"),
"smite":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/smite.png"),
"counterstrike":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/counterstrike.png"),

"aegis":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/Druideskill_41_armord.png"),
"intercept":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/intercept.png"),
"second wind":preload("res://world/interface/assets/icons/Combat_icons/Warden_skill_icons/second_wind.png"),


#BERSERK_______________________________________________________________________
"raze":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/raze.png"),
"reckless":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/reckless.png"),

"shoulder bash":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/shouler_bash.png"),
"stone splitter":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/stone_splitter.png"),

"brutal chop":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/brutal_chop.png"),
"sadistic blow":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/sadistic_blow.png"),
"fury strike":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/fury_strike.png"),
"obliteration charge":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/obliteration.png"),
"obliteration":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/obliteration.png"),

"heart thrust":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/heart_thrust.png"),
"sunder":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/sunder.png"),
"sledge":preload("res://world/interface/assets/icons/Combat_icons/Berserk_skill_icons/sledge.png"),
#____________________________________ANIMALS/MOB SKILLS_________________________

"toad spit":load("res://world/interface/assets/icons/Combat_icons/Generic_skills/Aura_Filth.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Generic_skills/Aura_Filth.png") else fallback,

"bite":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/bite.png") else fallback,
"infected bite":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/infected_bite.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/infected_bite.png") else fallback,
"slam":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/slam.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/slam.png") else fallback,
"claw strike":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/clawstrike.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/clawstrike.png") else fallback,
"laceration":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/claw_srtrike3.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/claw_srtrike3.png") else fallback,
"lifeline":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/lifeline.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/lifeline.png") else fallback,
"pounce":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/pounce.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/pounce.png") else fallback,
"wall breaker":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/wall_breaker.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/generic_mob_skills/wall_breaker.png") else fallback,


"surge":load("res://world/interface/assets/icons/Combat_icons/Generic_skills/Druideskill_02_compund.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Generic_skills/Druideskill_02_compund.png") else fallback,
"unbreakable":load("res://world/interface/assets/icons/Combat_icons/Generic_skills/Aura_Exile.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Generic_skills/Aura_Exile.png") else fallback,



"web shot":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/web_shot.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/web_shot.png") else fallback,
"poison shot":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/poison_shot.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/poison_shot.png") else fallback,
"burrow":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/burrow.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/burrow.png") else fallback,
"spawn spiderlings":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/spawn.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/spawn.png") else fallback,
"poisonous hairs":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/poison.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/poison.png") else fallback,
"venomous fangs":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/venomous_fangs.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Spider_skills/venomous_fangs.png") else fallback,

"ice breath":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/ice_breath.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/ice_breath.png") else fallback,
"fire breath":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/fire_breath.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/fire_breath.png") else fallback,
"cocytus breath":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/cocytus_breath.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/cocytus_breath.png") else fallback,
"infernal breath":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/infernal_breath.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/infernal_breath.png") else fallback,
"frost bombardment":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/frost_bombardment.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/frost_bombardment.png") else fallback,
"fire bombardment":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/fire_bombardment.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/fire_bombardment.png") else fallback,
"scorched earth":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/scorched_earth.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/scorched_earth.png") else fallback,
"frozen earth":load("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/frozen_earth.png") if ResourceLoader.exists("res://world/interface/assets/icons/Combat_icons/Mob_skills/Wyvern_skills/frozen_earth.png") else fallback
}


func _ready():
	for skill_name in skills:
		var resource = skills[skill_name]
		if resource == null or resource.resource_path == "" or not ResourceLoader.exists(resource.resource_path):
			print(skill_name)


var skill_dmg_immunity = [
	"evasion",
	"backstep",
	"recoil slash",
]
var skill_collision_ingnored = [
	"evasion",
	"backstep",
	"recoil slash",
	"dodge",
	"slide",
]


var skill_dmg_reduction = {
	"veiled thrust": 0.9,
	"counterstrike":0.75,
	"shield pummel":0.5,
	"shield bash":0.35,
	"obliteration": 0.65,
	"mighty push":0.5,
	"smite":0.1,
	"aegis":0.95,
	"second wind":0.5,
		
	"raze": 0.3,
}

var skill_aether_cost={
"second wind":15,
}



var skill_energy_cost={
"combo attack":0,
"penetrating blow":1,
"guard":0,
"backstep":0,


#Warden
"veiled thrust":15,
"shield pummel":12,
"shield bash":10,
"mighty push":15,
"smite":25,
"aegis":45,
#Dromeus
"cross draw":5,
"lunar slash":10,
"recoil slash":20,
#Berserk
"raze":24,
"reckless":25,
"shoulder bash":11,
"stone splitter":24,
"brutal chop":12,
"sadistic blow":14,
"fury strike":10,
"obliteration charge":7,
"heart thrust":35,
"sunder":11,
"sledge":5,

"laceration":12,
"bite":0,
"infected bite":10,
"lifeline":47,
"pounce":17,
"wall breaker":45,
"web shot":15,
"poison shot":22,
"burrow":15,
"spawn spiderlings":15,
"poisonous hairs":30,
"venomous fangs":10,

"unbreakable":45,
"surge":15,

"claw strike":0,
"slam":12,
"infernal breath":18,
"cocytus breath":18,
"fire breath":24,
"ice breath":24,
"fire bombardment":30,
"frost bombardment":30,
"scorched earth":36,
"frozen earth":36,
}
var support_skills=["lifeline","unbreakable", "surge"]
var skills_by_species = {
#NPC animations are named atk1 thru atk8+ 
#associate a skill to the attack animation by following an index order
#if an atk animation is missing the mob will default to atk1 animation

"human":[
"combo attack", # atk1
"shoulder bash",# atk2	
"laceration",   # atk3
"bite",         # atk4
"lifeline",     # atk5
"pounce",       # atk6
"sunder",       # atk7
		],
#__________________________
	"generic":[
"combo attack", # atk1
"laceration",   # atk2
"bite",         # atk3
"lifeline",     # atk4
"pounce",       # atk5
	],
"behemoth toad":[
"toad spit",    # atk1
"slam",         # atk2
"surge",        # atk3
],

#__________SPIDERS___________
"mole spider":[
"bite",                 # atk1
"infected bite",        # atk2
"web shot",             # atk3
"wall breaker",         # atk4
"burrow",               # atk5
],
"sea spider":[
"bite",                 # atk1
"infected bite",        # atk2
"web shot",             # atk3
"venomous fangs",       # atk4
"poison shot",          # atk5
"unbreakable",          # atk6
"surge",                # atk7
],
"forest spider":[
"bite",                 # atk1
"venomous fangs",       # atk2
"web shot",             # atk3
"spawn spiderlings",    # atk4
"poison shot",          # atk5
],
"spiderling":[
"bite",                 # atk1
"venomous fangs",       # atk2
"poisonous hairs",		# atk3
"burrow",               # atk4
],

"wyvern":[
"claw strike",          # atk1
"infernal breath",      # atk2
"fire breath",          # atk3
"scorched earth",       # atk4
"slam",                 # atk5
"fire bombardment",     # atk6
"laceration",           # atk7
],
"mountain wyvern":[
"claw strike",          # atk1
"cocytus breath",       # atk2
"ice breath",           # atk3
"frozen earth",         # atk4
"slam",                 # atk5
"frost bombardment",    # atk6
"laceration",           # atk7
],
#__________________________
}
var skill_penetration_chance = {
	"penetrating blow":1.0
}
var skill_damages = {
"combo attack":{DamageTypes.Type.slash:10},
"penetrating blow":{DamageTypes.Type.pierce:15},

#Warden
"veiled thrust":{DamageTypes.Type.pierce:45},
"shield pummel":{DamageTypes.Type.blunt:25},#hits twice
"shield bash":{DamageTypes.Type.blunt:20},
"mighty push":{DamageTypes.Type.blunt:33},
"smite":{DamageTypes.Type.slash:25,DamageTypes.Type.blunt:25},
"counterstrike":{DamageTypes.Type.slash:15,DamageTypes.Type.blunt:10},


#Dromeus
"cross draw":{DamageTypes.Type.slash:15},
"recoil slash":{DamageTypes.Type.slash:15},
"lunar slash":{DamageTypes.Type.slash:45},
#Berserk
"raze":{DamageTypes.Type.slash:40},#hits twice
"stone splitter":{DamageTypes.Type.slash:25,DamageTypes.Type.blunt:10},
"brutal chop":{DamageTypes.Type.slash:10,DamageTypes.Type.blunt:10},
"shoulder bash":{DamageTypes.Type.blunt:18},
"heart thrust":{DamageTypes.Type.pierce:125},
"fury strike":{DamageTypes.Type.slash:40},
"sadistic blow":{DamageTypes.Type.slash:25},
"sunder":{DamageTypes.Type.slash:15,DamageTypes.Type.blunt:15},
"sledge":{DamageTypes.Type.slash:15,DamageTypes.Type.blunt:15},
"obliteration":{DamageTypes.Type.slash:35},

"bite":{DamageTypes.Type.pierce:15},
"infected bite":{DamageTypes.Type.pierce:15,DamageTypes.Type.toxic:17},
"wall breaker":{DamageTypes.Type.blunt:35},

"poisonous hairs":{DamageTypes.Type.toxic:7},
"poison shot":{DamageTypes.Type.toxic:15},
"web shot":{DamageTypes.Type.blunt:10},
"venomous fangs":{DamageTypes.Type.pierce:5,DamageTypes.Type.blunt:3,DamageTypes.Type.toxic:20},

"claw strike":{DamageTypes.Type.slash:17},
"slam":{DamageTypes.Type.blunt:28},
"infernal breath":{DamageTypes.Type.heat:8},
"fire breath":{DamageTypes.Type.heat:8},
"cocytus breath":{DamageTypes.Type.cold:5},
"ice breath":{DamageTypes.Type.cold:5},
"fire bombardment":{DamageTypes.Type.heat:24,DamageTypes.Type.blunt:10},
"frost bombardment":{DamageTypes.Type.cold:24},
"scorched earth":{DamageTypes.Type.heat:12},
"frozen earth":{DamageTypes.Type.cold:12},

"laceration":{DamageTypes.Type.pierce:14,DamageTypes.Type.bleed:10},
"pounce":{DamageTypes.Type.blunt:12,DamageTypes.Type.pierce:6},

"toad spit":{DamageTypes.Type.blunt:12},
}
var skill_extra_aggro = {
	"penetrating blow":50,
	
	"shield bash":50,
	"shield pummel":75,
	"counterstrike":125,
	"mighty push":150,
	"intercept":200,
	"smite":50,
}

var cooldowns = {
#STARTER________________________________________________________________________
skills["combo attack"].resource_path:0.0,
skills["penetrating blow"].resource_path:3.0,

skills["guard"].resource_path:0.0,
skills["backstep"].resource_path:2.0,
skills["evasion"].resource_path:4.0,
skills["mine"].resource_path:1.0,
skills["chop"].resource_path:1.0,
skills["gather"].resource_path:1.0,
#WARDEN
skills["veiled thrust"].resource_path:12.0,
skills["shield pummel"].resource_path:6.0,
skills["shield bash"].resource_path:3.0,
skills["mighty push"].resource_path:13.0,
skills["smite"].resource_path:8.0,
skills["aegis"].resource_path:3.0,
skills["counterstrike"].resource_path:10.0,#reset after getting hit
skills["intercept"].resource_path:6.0,
skills["second wind"].resource_path:65.0,
#DROMEUS 
skills["cross draw"].resource_path:8,
skills["recoil slash"].resource_path:15,
skills["lunar slash"].resource_path:7,

#BERSERK_______________________________________________________________________
skills["raze"].resource_path:16,
skills["shoulder bash"].resource_path:7,
skills["stone splitter"].resource_path:8,
skills["brutal chop"].resource_path:4,
skills["fury strike"].resource_path:9,
skills["sunder"].resource_path:15,
skills["sadistic blow"].resource_path:5,
skills["heart thrust"].resource_path:21,
skills["obliteration charge"].resource_path:3,
skills["obliteration"].resource_path:3,
skills["sledge"].resource_path:12,
skills["reckless"].resource_path:32,

#MOBS__________________________________________________________________________

#mobs generic
skills["toad spit"].resource_path:1.0,
skills["bite"].resource_path:1,
skills["infected bite"].resource_path:9,
skills["wall breaker"].resource_path:22,
skills["laceration"].resource_path:5,
skills["lifeline"].resource_path:35,
skills["pounce"].resource_path:15,
#spiders and spiderlings
skills["spawn spiderlings"].resource_path:30,
skills["poisonous hairs"].resource_path:23,
skills["poison shot"].resource_path:20,
skills["web shot"].resource_path:7,
skills["burrow"].resource_path:31,
skills["venomous fangs"].resource_path:18,
#wyverns 
skills["claw strike"].resource_path:1,
skills["slam"].resource_path:8,
skills["infernal breath"].resource_path:12,
skills["fire breath"].resource_path:18,
skills["cocytus breath"].resource_path:12,
skills["ice breath"].resource_path:18,
skills["fire bombardment"].resource_path:24,
skills["frost bombardment"].resource_path:24,
skills["scorched earth"].resource_path:30,
skills["frozen earth"].resource_path:30,

skills["unbreakable"].resource_path:45,
skills["surge"].resource_path:60,
}
var cooldown_effects = {
#BERSERK_______________________________________________________________________
#	"reckless":{
#		"reduce_cooldowns":{
#			"reset_skills":{
#				"raze":1.0,
#				"heart thrust":1.0,
#			},
#		},
#		"stone splitter":{
#			"self_reset_chance":0.5,
#		},
#	},

#MOBS__________________________________________________________________________
	"bite":{
		"reduce_cooldowns":{
			"laceration":3,
			"pounce":3,
			"infected bite":3,
			"wall breaker":3,
			"lifeline":3,
			"spawn spiderlings":3,
			"poisonous hairs":3,
			"poison shot":3,
			"web shot":3,
			"burrow":3,
			"venomous fangs":3,
		},
	},
}






var on_hit_effects = {
	"combo attack":{
		"energy_flat":10.0,
		"lifesteal_flat":0.0,
		"lifesteal_percent":0.0,
	},
	"penetrating blow":{
		"energy_flat":2.0,
	},
	
	"smite":{
		"energy_flat":20.0,
	},
	
	
	
	
	"toad spit":{
		"energy_flat":5.0,
		"lifesteal_flat":0.0,
		"lifesteal_percent":0.0,
	},
	"bite":{
		"energy_flat":5.0,
		"lifesteal_flat":5.0,
		"lifesteal_percent":1.0,
	},
	"claw strike":{
		"energy_flat":15.0,
		"lifesteal_flat":0.0,
		"lifesteal_percent":0.0,
	},
	"slam":{"energy_flat":14.0,},
	

	
}












var status_icons = {

	"wrenched":preload("res://world/interface/assets/icons/Combat_icons/Effects_buffs_debuffs/Shamanskill_18.png"),
	"stunned":preload("res://world/interface/assets/icons/Combat_icons/Status/hypnosis.png"),

}


var debuffs_buffs = {
	"stunned": {
		"duration": 2,
		"malus": true
	},
	"second wind": {
		"stackable": false,
		"duration": 3,
		"regen health": 30,
		"regen energy": 10,
		"instant regen health": 80,
		"dot timer": 1,
		"malus": false
	},
	
	
	"aegis": {
		"stackable": true,
		"duration": 16,
		"def": 125,
		"def modified": ["blunt","slash","pierce","sonic","heat","cold","jolt","toxic","acid","arcane","bleed","radiant"],
		"balance": 0.25,
		"toughness": 0.15,
		"malus": false
	},
	
	
	"unbreakable": {
		"stackable": true,
		"duration": 6,
		"def": 8,
		"def modified": ["blunt", "slash", "pierce","cold","acid","heat","jolt","radiant"],
		"balance": 0.15,
		"malus": false
	},
	"surge": {
		"stackable": false,
		"duration": 5,
		"vitality": 0.15,
		"regen health": 25,
		"regen energy": 15,
		"dot timer": 1,
		"malus": false
	},
	"wrenched": {
		"stackable": false,
		"duration": 40,
		"def": -30,
		"def modified": ["jolt", "cold"],
		"balance": -0.05,
		"agility": -0.01,
		"mov speed": 0.95,
		"malus": true
	},
	"shoulder bash": {
		"stackable": true,
		"duration": 1600,
		"def": -7,
		"def modified": ["blunt", "slash", "pierce","cold","acid"],
		"atk":-0.1,
		"atk modified": ["blunt"],
		"balance": -0.05,
		"malus": true
	},
	"medicine potion": {
		"stackable": false,
		"duration": 8,
		"regen health": 5,
		"instant regen health": 25,
		"dot timer": 1,
		"malus": false
	},
	"energy potion": {
		"stackable": false,
		"duration": 16,
		"regen energy": 10,
		"instant regen energy": 10,
		"dot timer": 1,
		"malus": false
	},

	"poison potion": {
		"stackable": false,
		"duration": 8,
		"damage type": DamageTypes.Type.toxic,
		"damage ammount": 15,
		"dot timer": 1,
		"malus": true
	},

	"infected bite": {
		"stackable": false,
		"duration": 15,
		"damage type": DamageTypes.Type.toxic,
		"damage ammount": 7,
		"dot timer": 1,
		"malus": true
	},

	"poison shot": {
		"stackable": false,
		"duration": 15,
		"damage type": DamageTypes.Type.toxic,
		"damage ammount": 5,
		"dot timer": 3,
		"toughness": -0.5,
		"def": -15,
		"def modified": ["acid","toxic"],
		"malus": true
	},

	"web shot": {
		"stackable": false,
		"duration": 16,
		"dexterity": -0.05,
		"balance": -0.05,
		"mov speed": 0.25,
		"malus": true
	},

	"power potion": {
		"stackable": false,
		"duration": 160,
		"strength": 0.15,
		"agility": 0.03,
		"dexterity": 0.05,
		"malus": false
	},

	"reckless": {
		"stackable": false,
		"duration": 11,
		"strength": 0.35,
		"impact": 0.35,
		"agility": 0.035,
		"dexterity": 0.05,
		"def": -20,
		"mov speed": 1.5,
		"def modified": ["blunt"],
		"regen energy": 15,
		"dot timer": 1,
		"malus": false
	},

	"lifeline": {
		"stackable": false,
		"duration": 9,
		"regen health": 5,
		"regen energy": 12,
		"instant regen health": 15,
		"malus": false
	},

"infernal breath":{
	"stackable":true,
	"duration":8,
	"damage type":DamageTypes.Type.heat,
	"damage ammount":10,
	"def": -5,
	"def modified": ["heat","slash","blunt","frost"],
	"dot timer":1,
	"malus":true
},

"fire breath":{
	"stackable":false,
	"duration":12,
	"damage type":DamageTypes.Type.heat,
	"damage ammount":16,
	"dot timer":1,
	"malus":true
},
"ice breath":{
	"stackable":false,
	"duration":12,
	"damage type":DamageTypes.Type.cold,
	"damage ammount":16,
	"mov speed": 0.4,
	"dot timer":1,
	"malus":true
},
"cocytus breath":{
	"stackable":false,
	"duration":8,
	"damage type":DamageTypes.Type.cold,
	"damage ammount":10,
	"mov speed": 0.4,
	"dot timer":1,
	"malus":true
},



"fire bombardment":{
	"stackable":false,
	"duration":10,
	"damage type":DamageTypes.Type.heat,
	"damage ammount":12,
	"dot timer":1,
	"malus":true
},

"frost bombardment":{
	"stackable":false,
	"duration":10,
	"damage type":DamageTypes.Type.cold,
	"damage ammount":12,
	"mov speed": 0.4,
	"dot timer":1,
	"malus":true
},

"scorched earth":{
	"stackable":false,
	"duration":15,
	"damage type":DamageTypes.Type.heat,
	"damage ammount":14,
	"dot timer":1,
	"malus":true
},

"frozen earth":{
	"stackable":false,
	"duration":15,
	"damage type":DamageTypes.Type.cold,
	"damage ammount":14,
	"mov speed": 0.4,
	"dot timer":1,
	"malus":true
},
}

var status_effects = {}

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
				active_cooldowns[path]=max(0.0,active_cooldowns[path]-reduction)
				if active_cooldowns[path]<=0:
					active_cooldowns.erase(path)

var chargeable_skills = [
	"obliteration charge"
]
var skill_rotation_allowed = {
	"none":true,
	"":true,
	"penetrating blow":true,
	"combo attack":true,
	
	"raze":true,
	"downed":true,
}
var skill_damage_level_multiplier = {
	"combo attack": 0.10,
	"sledge": 0.15,
	"stone splitter": 0.20,
	"shoulder bash":0.33,
}
func getDamageMultiplier(skill_name:String, skill_level:int) -> float:
	return 1.0 + skill_level * skill_damage_level_multiplier.get(skill_name, 0.0)

func canRotateDuringSkill(skill:String)->bool:
	return skill_rotation_allowed.get(skill,true)
func getSpeciesSkills(species):
	return skills_by_species.get(species,[])


func getDamages(skill_name:String, weapon_mult:float = 1.0) -> Dictionary:
	var base = skill_damages.get(skill_name, {}).duplicate(true)
	for k in base.keys():
		base[k] *= weapon_mult
	return base
func getEnergyCost(skill:String) -> float:
	return skill_energy_cost.get(skill, 0)


var unbreakable_skills=[
"raze",
"sledge",
"stone splitter",

"burrow",
"web shot",

"obliteration",
"obliteration charge",

"infernal breath",     
"fire breath",         
"scorched earth",     
"slam",                
"fire bombardment",          
"cocytus breath",     
"ice breath",        
"frozen earth",    
"frost bombardment"]



# Works whether target.anim_locks is:
# - an old-style Dictionary keyed by string ("flinch", "knocked down", ...)
# - a new-style Array indexed by a Lock enum defined on the target's script
const LOCK_KEY_MAP := {
	"atk1": "ATK1",
	"atk2": "ATK2",
	"atk3": "ATK3",
	"atk4": "ATK4",
	"atk5": "ATK5",
	"atk6": "ATK6",
	"atk7": "ATK7",
	"guard": "GUARD",
	"guard react": "GUARD_REACT",
	"parry": "PARRY",
	"die": "DIE",
	"flinch": "FLINCH",
	"flinch back": "FLINCH_BACK",
	"knocked down": "KNOCKED_DOWN",
	"knocked back": "KNOCKED_BACK",
	"downed": "DOWNED",
}

func getAnimLock(target, key:String) -> bool:
	if typeof(target.anim_locks) == TYPE_ARRAY:
		if !("Lock" in target) or !target.Lock.has(LOCK_KEY_MAP.get(key,"")):
			return false
		var enum_val = target.Lock[LOCK_KEY_MAP[key]]
		if enum_val < 0 or enum_val >= target.anim_locks.size():
			return false
		return target.anim_locks[enum_val]
	else:
		return target.anim_locks.get(key, false)

func setAnimLock(target, key:String, value:bool) -> void:
	if typeof(target.anim_locks) == TYPE_ARRAY:
		if !("Lock" in target) or !target.Lock.has(LOCK_KEY_MAP.get(key,"")):
			return
		var enum_val = target.Lock[LOCK_KEY_MAP[key]]
		if enum_val < 0 or enum_val >= target.anim_locks.size():
			return
		target.anim_locks[enum_val] = value
	else:
		target.anim_locks[key] = value

var impact_effects = {
	"debuffer debugging stuff":{
		"flinch_chance":0.0,
		"knockback_chance":100.0,
		"knockdown_chance":0.0,
	},
	"combo attack":{
		"flinch_chance":33.5,
		"knockback_chance":5.0,
		"knockdown_chance":3.0,
	},
	"penetrating blow":{
		"flinch_chance":100,
	},
	"shoulder bash":{
		"flinch_chance":5.5,
		"knockback_chance":100.0,
		"knockdown_chance":1.25,
	},
	"raze":{
		"flinch_chance":50.5,
		"knockback_chance":90.0,
		"knockdown_chance":50.0,
	},
	"sledge":{"knockdown_chance":100.0,},
	
	
	"stone splitter":{"flinch_chance":100.0},
	"brutal chop":{"flinch_chance":75.0},
	"heart thrust":{"flinch_chance":75.0},
	"fury strike":{"flinch_chance":75.0},
	"sadistic blow":{"flinch_chance":75.0},
	"sunder":{"flinch_chance":75.0},
	"obliteration":{"flinch_chance":75.0},

#WARDEN
"mighty push":{"knockback_chance":100.0},
"smite":{"flinch_chance":100.0},




	"laceration":{"flinch_chance":75.0},
	"bite":{"flinch_chance":100.0},
	"infected bite":{"flinch_chance":75.0},
	"lifeline":{"flinch_chance":75.0},
	"pounce":{"flinch_chance":75.0},
	"poison shot":{"flinch_chance":100.0},
	"web shot":{"flinch_chance":100.0},
	
	
	"wall breaker":{"knockdown_chance":100.0,},


#Wyvern____________________________________________________________________________________________________
	"claw strike":{"flinch_chance":75.0},
	"slam":{"knockdown_chance":100.0,},
	"infernal breath":{"flinch_chance":100.0},
	"fire breath":{"flinch_chance":100.0,"knockback_chance":100.0},
	"cocytus breath":{"flinch_chance":100.0},
	"ice breath":{"flinch_chance":100.0,"knockback_chance":100.0},
	"fire bombardment":{"knockback_chance":100.0,"knockdown_chance":35.0},
	"frost bombardment":{"knockback_chance":100.0,"knockdown_chance":35.0},
	"scorched earth":{"knockdown_chance":100.0,},
	"frozen earth":{"knockdown_chance":100.0,},
}
export var overpower_dampening:float = 0.5
export var tenacity_dampening:float = 0.863
export var impact_icd_ms:float = 800.0
export var impact_cleanup_interval_ms:float = 30000.0  # prune stale entries every 30s

var last_impact_time := {}
var last_cleanup_time := 0

func applyImpactEffects(skill_name:String,target,attacker)->void:
	if !is_instance_valid(target) or !impact_effects.has(skill_name):
		return
	if target.current_skill in unbreakable_skills:return
	if target.current_skill in skill_dmg_immunity:return

	var now = OS.get_ticks_msec()

	cleanupStaleImpactEntries(now)

	if last_impact_time.has(target):
		if now - last_impact_time[target] < impact_icd_ms:
			return

	var stagger = attacker.stats.derived_stats.get("stagger", 1.0)
	var tenacity = target.stats.derived_stats.get("tenacity", 1.0)
#________________________________________________________________________________
# RESISTANCE PHASE
#
# If tenacity exceeds stagger, the target gains a chance to fully
# ignore all impact effects this hit. Even on a failed full-resist
# roll, the tenacity lead still partially reduces the odds of any
# effect landing, instead of tenacity doing nothing unless the
# full-resist roll succeeds.
#
# raw_ratio now divides by the attacker's true stagger (not
# clamped to a 1.0 floor), so sub-1.0 stat scales behave correctly.
#________________________________________________________________________________
	var effect_chance_multiplier = 1.0
	if tenacity > stagger:
		var raw_ratio = (tenacity - stagger) / max(stagger, 0.01)
		var resist_power = pow(raw_ratio, tenacity_dampening)
		var resist_chance = resist_power * 100.0

		if randf() * 100.0 <= resist_chance:
			return

		# Failed the full-resist roll, but tenacity still softens the hit.
		effect_chance_multiplier = 1.0 / (1.0 + resist_power)
#________________________________________________________________________________
# OVERPOWER PHASE
#
# If stagger exceeds tenacity, impact effects become more likely.
# No cap. Extremely large stat advantages can still guarantee CC,
# it just takes a much bigger lead to get there.
#________________________________________________________________________________
	elif stagger > tenacity:
		var raw_ratio = stagger / max(tenacity, 0.01)
		effect_chance_multiplier = pow(raw_ratio, overpower_dampening)

	var effect = impact_effects[skill_name]
	if target.stats.health <= 0:
		return
	if getAnimLock(target,"downed") or getAnimLock(target,"die"):
		return
	if target.is_dead:
		return
	if getAnimLock(target,"guard"):
		return
	if getAnimLock(target,"guard react"):
		return
#________________________________________________________________________________
# IMPACT EFFECT APPLICATION
#
# Final chance = Base Chance × Multiplier
#________________________________________________________________________________
	if !getAnimLock(target,"flinch") or !getAnimLock(target,"knocked back") or !getAnimLock(target,"knocked down"):
			var knockback_chance = effect.get("knockback_chance", 0.0)
			var knockdown_chance = effect.get("knockdown_chance", 0.0)
			var flinch_chance = effect.get("flinch_chance", 0.0)
			var applied = false
			var knockdown_resisted = false

			if randf() * 100.0 <= knockback_chance * effect_chance_multiplier:
				target.anim_calls.unlockAnim()
				setAnimLock(target,"knocked back",true)
				target.animation_tree.active = true
				applied = true

			if knockdown_chance > 0.0:
				if randf() * 100.0 <= knockdown_chance * effect_chance_multiplier:
					target.anim_calls.unlockAnim()
					setAnimLock(target,"knocked down",true)
					target.animation_tree.active = true
					applied = true

			if randf() * 100.0 <= flinch_chance * effect_chance_multiplier:
				target.anim_calls.unlockAnim()
				setAnimLock(target,"flinch",true)
				target.animation_tree.active = true
				applied = true
			if applied:
				last_impact_time[target] = now


func cleanupStaleImpactEntries(now:int)->void:
	if now - last_cleanup_time < impact_cleanup_interval_ms:
		return
	last_cleanup_time = now

	var stale_keys = []
	for key in last_impact_time.keys():
		if !is_instance_valid(key):
			stale_keys.append(key)
	for key in stale_keys:
		last_impact_time.erase(key)













func getCooldown(path)->float:
	if cooldowns.has(path):
		return cooldowns[path]
	return 0.0
	
func applyOnHitEffects(skill_name:String,effects:Dictionary,active_cooldowns:Dictionary,stats,damage_dealt:float)->void:
	if !effects.has(skill_name):
		return

	var effect=effects[skill_name]

	if effect.has("energy_flat") or effect.has("energy"):
		var energy_gain=effect.get("energy_flat",effect.get("energy",0.0))
		stats.energy=min(stats.max_energy,stats.energy+energy_gain)

	if effect.has("energy_percentage"):
		stats.energy=min(stats.max_energy,stats.energy+stats.max_energy*effect["energy_percentage"]/100.0)

	if effect.has("lifesteal_flat") or effect.has("lifesteal"):
		var life_gain=effect.get("lifesteal_flat",effect.get("lifesteal",0.0))
		stats.health=min(stats.max_health,stats.health+life_gain)

	if effect.has("lifesteal_percent"):
		stats.health=min(stats.max_health,stats.health+damage_dealt*effect["lifesteal_percent"])

	if effect.has("reduce_cooldowns"):
		for target_skill in effect["reduce_cooldowns"]:
			if !skills.has(target_skill):
				continue
			var reduction=effect["reduce_cooldowns"][target_skill]
			var path=skills[target_skill].resource_path
			if !active_cooldowns.has(path):
				continue
			active_cooldowns[path]=max(0.0,active_cooldowns[path]-reduction)
			if active_cooldowns[path]<=0.0:
				active_cooldowns.erase(path)

	if stats.health>stats.max_health:
		stats.health=stats.max_health
