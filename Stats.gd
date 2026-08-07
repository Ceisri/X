extends Node#Stats script, on a node called Stats, direct child of every npc and every player



const species_data= {
	"human": {
		"male": { "base_max_health":100,"base_max_energy":100,"base_max_arcane":100,"base_walk_speed":4,"base_run_speed":16,
			"attributes":{"strength":1.0,"power":1.0,"impact":1.1,"balance":1.0,"agility":1.0,"dexterity":1.02,"vitality":1.0,"toughness":1.0,"instinct":1.0,"perception":1.0,"intelligence":1.0,"wisdom":1.0,"haste":1.0,"charisma":1.0,"authority":1.0},
			"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":0,"radiant":0},
			"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
			"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":0,"radiant":0},
			"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1}
		},
		"female": { "base_max_health":100,"base_max_energy":100,"base_max_arcane":100,"base_walk_speed":4,"base_run_speed":15,
			"attributes":{"strength":1.0,"power":1.0,"impact":0.95,"balance":1.05,"agility":1.1,"dexterity":1.0,"vitality":1.0,"toughness":0.95,"instinct":0.85,"perception":0.85,"intelligence":1.0,"wisdom":1.0,"haste":1.00,"charisma":1.2,"authority":1.0},
			"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":0,"radiant":0},
			"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
			"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":0,"radiant":0},
			"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1}
		}
	},
	"forest spider": { "base_max_health":120,"base_max_energy":300,"base_max_arcane":100,"base_walk_speed":2.6,"base_run_speed":10.5,
		"attributes":{"strength":1.0,"power":1.0,"impact":1.9,"balance":3.3,"agility":0.9,"dexterity":1.1,"vitality":1.8,"toughness":1.7,"instinct":1.5,"perception":1.3,"intelligence":0.4,"wisdom":0.3,"haste":1.1,"charisma":0.1,"authority":0.2},
		"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":2,"acid":2,"arcane":0,"bleed":0,"radiant":0},
		"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.2,"acid":1.2,"arcane":1,"bleed":1,"radiant":1},
		"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":2,"acid":2,"arcane":0,"bleed":1,"radiant":0},
		"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.25,"acid":1.25,"arcane":1,"bleed":1.1,"radiant":1}
	},
	"spiderling": { "base_max_health":75,"base_max_energy":1000,"base_max_arcane":100,"base_walk_speed":2,"base_run_speed":15.5,
		"attributes":{"strength":1.0,"power":1.0,"impact":0.4,"balance":1.0,"agility":2.6,"dexterity":1.5,"vitality":0.6,"toughness":0.5,"instinct":5.0,"perception":1.3,"intelligence":0.2,"wisdom":0.0,"haste":1.6,"charisma":0.0,"authority":0.0},
		"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":1,"acid":1,"arcane":0,"bleed":0,"radiant":0},
		"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.1,"acid":1.1,"arcane":1,"bleed":1,"radiant":1},
		"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":1,"acid":1,"arcane":0,"bleed":0,"radiant":0},
		"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.15,"acid":1.15,"arcane":1,"bleed":1,"radiant":1}
	},
	"mole spider": { "base_max_health":150,"base_max_energy":90,"base_max_arcane":100,"base_walk_speed":2.6,"base_run_speed":14.8,
		"attributes":{"strength":1.0,"power":1.0,"impact":5.4,"balance":1.0,"agility":1.0,"dexterity":1.5,"vitality":1.0,"toughness":1.0,"instinct":2.4,"perception":1.8,"intelligence":0.5,"wisdom":0.3,"haste":3.66,"charisma":0.0,"authority":0.4},
		"flat_defence_bonus":{"slash":0,"blunt":30,"pierce":0.3,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0.5,"acid":0.2,"arcane":0,"bleed":0,"radiant":0},
		"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.15,"acid":1.15,"arcane":1,"bleed":1,"radiant":1},
		"flat_damage_bonus":{"slash":0,"blunt":6,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":6,"acid":2,"arcane":0,"bleed":1,"radiant":0},
		"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.2,"acid":1.2,"arcane":1,"bleed":1.1,"radiant":1}
	},
	"sea spider": { "base_max_health":110,"base_max_energy":150,"base_max_arcane":100,"base_walk_speed":2.6,"base_run_speed":15.8,
		"attributes":{"strength":1.0,"power":1.5,"impact":1.4,"balance":1.0,"agility":1.2,"dexterity":1.5,"vitality":1.0,"toughness":1.0,"instinct":3.4,"perception":1.8,"intelligence":1,"wisdom":1,"haste":1,"charisma":0.2,"authority":0.4},
		"flat_defence_bonus":{"slash":10,"blunt":30,"pierce":10,"sonic":10,"heat":0,"cold":50,"jolt":-15,"toxic":0,"acid":0.0,"arcane":0,"bleed":30,"radiant":30},
		"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.15,"acid":1.15,"arcane":1,"bleed":1,"radiant":1},
		"flat_damage_bonus":{"slash":0,"blunt":3,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":120,"acid":2,"arcane":0,"bleed":1,"radiant":0},
		"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.2,"acid":1.2,"arcane":1,"bleed":1.1,"radiant":1}
	},
	"wyvern": { "base_max_health":850,"base_max_energy":1000,"base_max_arcane":1000,"base_walk_speed":5.8,"base_run_speed":17.5,
		"attributes":{"strength":1.4,"power":1.4,"impact":1.5,"balance":1.0,"agility":1.0,"dexterity":1.0,"vitality":1.3,"toughness":1.3,"instinct":1.0,"perception":1.0,"intelligence":1.0,"wisdom":1.0,"haste":1.0,"charisma":0.8,"authority":1.2},
		"flat_defence_bonus":{"slash":8,"blunt":6,"pierce":8,"sonic":0,"heat":120,"cold":2,"jolt":0,"toxic":3,"acid":3,"arcane":0,"bleed":4,"radiant":0},
		"defence_mult":{"slash":1.1,"blunt":1.05,"pierce":1.1,"sonic":1,"heat":1.3,"cold":1,"jolt":1,"toxic":1.1,"acid":1.1,"arcane":1,"bleed":1.05,"radiant":1},
		"flat_damage_bonus":{"slash":20,"blunt":12,"pierce":18,"sonic":0,"heat":5,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":8,"radiant":0},
		"damage_mult":{"slash":1.15,"blunt":1.1,"pierce":1.15,"sonic":1,"heat":1.35,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1.1,"radiant":1}
	},
	"mountain wyvern": { "base_max_health":1250,"base_max_energy":2000,"base_max_arcane":2000,"base_walk_speed":6.8,"base_run_speed":15.5,
		"attributes":{"strength":1.4,"power":1.4,"impact":1.5,"balance":1.2,"agility":1.0,"dexterity":1.2,"vitality":1.5,"toughness":1.3,"instinct":1.0,"perception":1.0,"intelligence":1.0,"wisdom":1.0,"haste":1.0,"charisma":0.8,"authority":1.2},
		"flat_defence_bonus":{"slash":8,"blunt":6,"pierce":8,"sonic":0,"heat":30,"cold":350,"jolt":0,"toxic":3,"acid":3,"arcane":0,"bleed":4,"radiant":0},
		"defence_mult":{"slash":1.1,"blunt":1.05,"pierce":1.1,"sonic":1,"heat":1.3,"cold":1.5,"jolt":1,"toxic":1.1,"acid":1.1,"arcane":1,"bleed":1.05,"radiant":1},
		"flat_damage_bonus":{"slash":20,"blunt":12,"pierce":18,"sonic":0,"heat":0,"cold":15,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":8,"radiant":0},
		"damage_mult":{"slash":1.15,"blunt":1.1,"pierce":1.15,"sonic":1,"heat":1.35,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1.1,"radiant":1}
	},
	"behemoth toad": { "base_max_health":125,"base_max_energy":70,"base_max_arcane":100,"base_walk_speed":3.8,"base_run_speed":12.5,
		"attributes":{"strength":0.5,"power":1.0,"impact":1,"balance":0.8,"agility":1.0,"dexterity":1.0,"vitality":1,"toughness":1,"instinct":1.0,"perception":1.0,"intelligence":1.0,"wisdom":1.0,"haste":1.0,"charisma":0.0,"authority":0.0},
		"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":100,"acid":0,"arcane":0,"bleed":0,"radiant":0},
		"defence_mult":{"slash":0.5,"blunt":0.5,"pierce":0.25,"sonic":0,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
		"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":0,"radiant":0},
		"damage_mult":{"slash":1.0,"blunt":1.0,"pierce":1.0,"sonic":1.0,"heat":1.0,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1.1,"radiant":1.0}
	}
}

export var max_energy:int  = 9999999999
var energy:int = 9999999999

export var max_health:int = 9999999999
var health:int = 9999999999

var max_arcane:int = 9999999999
var arcane:int = max_arcane


# ============================================================
# NETWORKING
# Stats exists on every peer for every Player and every NPC, same
# as today. But only the entity's network master may compute
# combat, buffs, and regen -- everyone else just mirrors the
# numbers the master broadcasts. This mirrors exactly how
# Player.gd already splits movement into master/puppet.
# ============================================================
#func isAuthority() -> bool:
#	if parent.is_in_group("Player"):
#		return get_tree().network_peer == null or get_tree().is_network_server()
#	return parent.is_network_master()
func isAuthority() -> bool:
	if get_tree().network_peer == null:
		return true # no multiplayer session running -> everyone is authoritative, players and mobs alike
	if parent.is_in_group("Player"):
		return get_tree().is_network_server()
	return parent.is_network_master()
	
	
# saveData()/loadData() must stay on the owning client -- the server has no
# access to that client's user:// directory. Combat authority and save
# ownership are two different things now, so they get two different checks.
func isLocalOwner() -> bool:
	if get_tree().network_peer == null:
		return true
	return parent.is_network_master()
func _shouldRouteThroughAuthority() -> bool:
	return get_tree().network_peer != null and !isAuthority()
puppet var net_health:int = 9999999999 setget _set_net_health
puppet var net_max_health:int = 9999999999
puppet var net_energy:int = 9999999999
puppet var net_max_energy:int = 9999999999
puppet var net_arcane:int = 9999999999
puppet var net_max_arcane:int = 9999999999
puppet var net_is_dead:bool = false
puppet var net_statuses := {}
puppet var net_debuff_buffs_active := {}

export var stats_sync_rate := 0.1
var _stats_sync_timer := 0.0
func _syncStatsToPuppets(delta:float) -> void:
	pass # replaced by MobSync — rset_id here targeted mismatched node
		  # names between server/client trees and was never reliable
var _has_received_stats_sync := false

func _set_net_health(value):
	_has_received_stats_sync = true
	net_health = value

puppet var net_attributes := {}
puppet var net_derived_stats := {}
puppet var net_available_attribute_points:int = 10
puppet var net_attribute_points_spent := {}

func _applyPuppetStats() -> void:
	if !_has_received_stats_sync:
		return
	health = net_health
	max_health = net_max_health
	energy = net_energy
	max_energy = net_max_energy
	arcane = net_arcane
	max_arcane = net_max_arcane
	statuses = net_statuses
	debuff_buffs_active = net_debuff_buffs_active
	if !net_attributes.empty():
		attributes = net_attributes.duplicate(true)
		markAttributeCacheDirty()
	if !net_derived_stats.empty():
		derived_stats = net_derived_stats.duplicate(true)
	if !net_attribute_points_spent.empty():
		for k in attribute_points_spent.keys():
			if net_attribute_points_spent.has(k):
				attribute_points_spent[k] = int(net_attribute_points_spent[k])
	available_attribute_points = net_available_attribute_points
	if "is_dead" in parent:
		parent.is_dead = net_is_dead


func _ready():
	applySpecies()
	rebuildOnHitEffects()
	loadData()
	if !parent.is_in_group("Player"):
		call_deferred("_deferredInitialUpdateAttributes")

func _deferredInitialUpdateAttributes() -> void:
	if get_tree().network_peer == null or isAuthority():
		updateAttributes()




func applySpecies():
	if typeof(species_data) != TYPE_DICTIONARY:
		return
	var s = species_data.get(species, null)
	if s == null:
		return

	if s.has("male") or s.has("female"):
		s = s.get(sex, s)

	base_max_health = s.get("base_max_health", base_max_health)
	base_max_energy = s.get("base_max_energy", base_max_energy)
	base_max_arcane = s.get("base_max_arcane", base_max_arcane)
	base_walk_speed = s.get("base_walk_speed", base_walk_speed)
	base_run_speed = float(s.get("base_run_speed",base_run_speed))
	
	
	var a = s.get("attributes", {})
	for k in a:
		attributes[k] = a[k]

	flat_defence_bonus = {}
	var raw_flat_defence = s.get("flat_defence_bonus", {})
	for k in raw_flat_defence:
		flat_defence_bonus[str(k)] = float(raw_flat_defence[k])

	base_flat_damage_bonus = {}
	var raw_flat_damage = s.get("flat_damage_bonus", {})
	for k in raw_flat_damage:
		base_flat_damage_bonus[str(k)] = float(raw_flat_damage[k])

	flat_damage_bonus = base_flat_damage_bonus.duplicate()

	defence_mult = {}
	var raw_def_mult = s.get("defence_mult", {})
	for k in raw_def_mult:
		defence_mult[str(k)] = float(raw_def_mult[k])

	damage_mult = {}
	var raw_dmg_mult = s.get("damage_mult", {})
	for k in raw_dmg_mult:
		damage_mult[str(k)] = float(raw_dmg_mult[k])
	markAttributeCacheDirty()
	#call_deferred("loadData")

onready var parent = $".."


# Exported variables
export var is_civilised: bool = false
export var is_tense: bool = false
export var species: String = "species"
export var mob_type:String = "default"
export var sex: String = "male"

export var food_chain: int = 1
export var is_predator: bool = false
export var hunt_radius = 50

export var weight := 10.0







export var walk_speed = 2.5
export var run_speed = 6

export var attack_range: float = 3
export var can_be_moved: bool = true


# Stats
var agility = 1
var power = 1
var charisma = 1
var vitality = 1

var last_health = -1
var last_damage_time = 0
var damage_check_window = 3000


# Survival
var nutrition:int  = 60
var hydration:int  = 100
var nutrition_loss_tick:int  = 10


# Progression
var skill_points:int  = 1
var used_skill_points:int  = 0


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



var base_max_health:int  = 100
var base_max_energy:int  = 100
var base_max_arcane:int  = 100
var base_walk_speed = 3
var base_run_speed = 10





var attributes = {
	"strength": 1,
	"power": 1,
	"impact": 1,
	"agility": 1,
	"dexterity": 1,
	"balance": 1,
	"vitality": 1,
	"toughness": 1,
	"endurance": 1,
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
	"fall_resistance": 0.0,
	
	"atk_turn_speed": 0.15,
	"dash_turn_speed": 7.0,
	"turn_speed": 4.0,

	"stagger": 1.0,
	"tenacity": 1.0,


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

var selected_attribute:String= "vitality"
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
	"endurance":0.0,
	"instinct":0.0,
	"perception":0.0,
	"intelligence":0.0,
	"wisdom":0.0,
	"haste":0.0,
	"charisma":0.0,
	"authority":0.0
}

func regenerations()->void:#mobs call this on wander() in NPC.gd
	if get_tree().network_peer != null and !isAuthority():
		return
	if health > (max_health * 0.15):
		health = regenerate(derived_stats["health_regeneration"],health,max_health)
		energy = regenerate(derived_stats["energy_regeneration"],energy,max_energy)








const ATTRIBUTE_STEP:float = 0.05
const MIN_ATTRIBUTE:float = 0.25
func getSaveDirectory() -> String:
	if parent.is_in_group("Player"):
		return "user://Characters/" + parent.entity_name + "/"

	var current_node = parent.get_parent()
	var world_id = ""
	while current_node:
		if current_node.get("world_id") != null:
			world_id = str(current_node.get("world_id"))
			break
		current_node = current_node.get_parent()

	return "user://" + world_id + "/" + parent.name + parent.entity_name + "/"


var _post_load_snapshot := {}
var _post_load_guard := false
func saveData():
	if _post_load_guard:
		return
	if parent.is_in_group("Player"):
		var world = parent.get_parent()
		if is_instance_valid(world) and world.has_method("saveStatsFor") and parent.has_method("isLocalPlayer") and parent.isLocalPlayer():
			world.saveStatsFor(parent, gatherStatsSnapshot())
		return

	var saveDirectory = getSaveDirectory()
	var data = {
		"experience_points": experience_points,
		"level": level,
		"available_attribute_points": available_attribute_points,
		"attribute_points_spent": attribute_points_spent.duplicate(true),
		"attributes": attributes.duplicate(true),
		"statuses": statuses.duplicate(true),
		"debuff_buffs_active": debuff_buffs_active.duplicate(true),
	}

	if get_tree().network_peer == null:
		_writeStatsDataLocal(saveDirectory, data)
		return

	if get_tree().is_network_server():
		_writeStatsDataLocal(saveDirectory, data)




# ---------- player stats save/load, routed through World.gd ----------

func gatherStatsSnapshot() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"energy": energy,
		"max_energy": max_energy,
		"arcane": arcane,
		"max_arcane": max_arcane,
		"experience_points": experience_points,
		"level": level,
		"available_attribute_points": available_attribute_points,
		"attribute_points_spent": attribute_points_spent.duplicate(true),
		"attributes": attributes.duplicate(true),
		"statuses": statuses.duplicate(true),
		"debuff_buffs_active": debuff_buffs_active.duplicate(true),
	}





# ===== Stats.gd — replace the entire reassert block with this =====
# No more loop, no more equipment_initialized/skeleton dependency. Equipment
# is now applied synchronously BEFORE stats in World.gd's loadPlayerData(),
# so max_health is already correct the instant this runs. Compute the ratio
# once and stop -- there is nothing left to "wait" for, and the old 5-second
# loop was itself the source of the drift (see explanation above).

var _stats_stable := true # kept for MobSync's stats_stable check; always true now

func _reapplyLoadedStatsAfterDelay() -> void:
	for wait_time in [1.0, 2.0, 3.0, 5.0, 8.0, 12.0]:
		yield(get_tree().create_timer(wait_time), "timeout")
		if !is_instance_valid(self) or _post_load_snapshot.empty():
			_stats_stable = true
			return
		_forceReapplySnapshot()
	_post_load_guard = false
	_stats_stable = true

func _forceReapplySnapshot() -> void:
	var data = _post_load_snapshot
	var saved_max_health = float(data.get("max_health", max_health))
	var saved_max_energy = float(data.get("max_energy", max_energy))
	var saved_max_arcane = float(data.get("max_arcane", max_arcane))
	var health_ratio = float(data.get("health", health)) / saved_max_health if saved_max_health > 0 else 1.0
	var energy_ratio = float(data.get("energy", energy)) / saved_max_energy if saved_max_energy > 0 else 1.0
	var arcane_ratio = float(data.get("arcane", arcane)) / saved_max_arcane if saved_max_arcane > 0 else 1.0

	health = clamp(health_ratio * max_health, 0.0, max_health)
	energy = clamp(energy_ratio * max_energy, 0.0, max_energy)
	arcane = clamp(arcane_ratio * max_arcane, 0.0, max_arcane)

	net_health = health
	net_max_health = max_health
	net_energy = energy
	net_max_energy = max_energy
	net_arcane = arcane
	net_max_arcane = max_arcane
	_has_received_stats_sync = true

	if parent.is_in_group("Player"):
		var bar = get_node_or_null("../UI/Menu/CharacterBar")
		if is_instance_valid(bar):
			bar.updateBars()
			

func applyStatsSnapshotAuthority(data: Dictionary) -> void:
	_applyStatsSnapshotInternal(data)
	_resetRestoredBuffTimers()
	_post_load_snapshot = data.duplicate(true)
	_post_load_guard = true
	_stats_stable = false
	_reapplyLoadedStatsAfterDelay()

#remote func applyOwnStatsSnapshot(data: Dictionary) -> void:
#	if !parent.has_method("isLocalPlayer") or !parent.isLocalPlayer():
#		return
#	_applyStatsSnapshotInternal(data)
#	_resetRestoredBuffTimers()
#	_syncLoadedAttributesToServer()
#
#	net_health = health
#	net_max_health = max_health
#	net_energy = energy
#	net_max_energy = max_energy
#	net_arcane = arcane
#	net_max_arcane = max_arcane
#	net_is_dead = ("is_dead" in parent) and parent.is_dead
#	net_statuses = statuses.duplicate(true)
#	net_debuff_buffs_active = debuff_buffs_active.duplicate(true)
#	_has_received_stats_sync = true
#
#	_post_load_snapshot = data.duplicate(true)
#	_post_load_guard = true
#	_reapplyLoadedStatsAfterDelay()
remote func applyOwnStatsSnapshot(data: Dictionary) -> void:
	if !parent.has_method("isLocalPlayer") or !parent.isLocalPlayer():
		return
	_applyStatsSnapshotInternal(data)
	_resetRestoredBuffTimers()
	_syncLoadedAttributesToServer()

	net_health = health
	net_max_health = max_health
	net_energy = energy
	net_max_energy = max_energy
	net_arcane = arcane
	net_max_arcane = max_arcane
	net_is_dead = ("is_dead" in parent) and parent.is_dead
	net_statuses = statuses.duplicate(true)
	net_debuff_buffs_active = debuff_buffs_active.duplicate(true)
	_has_received_stats_sync = true

	_post_load_snapshot = data.duplicate(true)
	_post_load_guard = true
	_stats_stable = false
	_reapplyLoadedStatsAfterDelay()

func _resetRestoredBuffTimers() -> void:
	for buff_name in debuff_buffs_active.keys():
		var buff_data = debuff_buffs_active[buff_name]
		if typeof(buff_data) != TYPE_DICTIONARY:
			continue
		var dot_interval = float(buff_data.get("dot_interval", buff_data.get("dot timer", 1.0)))
		if dot_interval <= 0.0:
			dot_interval = 1.0
		buff_data["dot_timer"] = dot_interval
		buff_data["regen_timer"] = 1.0






# Stats.gd — _physics_process(), puppet branch: drop the periodic local
# updateAttributes() call. It recomputes max_health from whatever this
# client's OWN Equipment node currently has cached and then clamps health
# against it -- exactly the "should never happen on a non-authority Stats
# node" case called out in Equipment.gd's get_equipment_stats() comment.
# health/max_health/energy/arcane/attributes/derived_stats all already
# arrive correctly through _applyPuppetStats() every frame via net_* vars
# (fed by MobSync or the direct applyOwnStatsSnapshot RPC) -- this second
# recompute was pure risk with no benefit.
func _physics_process(_delta):
	if !parent.is_in_group("Player") and isAuthority() and parent.has_method("isRelevantForSync") and !parent.isRelevantForSync():
		return

	if get_tree().network_peer != null and !isAuthority():
		_applyPuppetStats()
		if Engine.get_physics_frames() % 30 == 0 and parent.is_in_group("Player") and isLocalOwner():
			updateStatusGrid(player_status_grid, self)
		return

	if Engine.get_physics_frames() % 30 == 0 and parent.is_in_group("Player"):
		updateStatusGrid(player_status_grid, self)
	if Engine.get_physics_frames() % 60 == 0:
		tickBuffsDebuffs()
		updateBuffDebuffs()
		updateAttributes()
		rebuildOnHitEffects()
		if health <= 0:
			purify()
			exhaust()

	_syncStatsToPuppets(get_physics_process_delta_time())

var _pending_ratio_reassert := {}
export var ratio_reassert_max_frames := 300   # ~5s hard cap fallback
export var ratio_reassert_settle_frames := 30 # keep correcting this long after equipment looks ready
var _ratio_reassert_elapsed := 0
var _equipment_ready_streak := 0





func _isEquipmentReady() -> bool:
	if !parent.is_in_group("Player"):
		return true
	var equipment = parent.get_node_or_null("UI/Equipment")
	if !is_instance_valid(equipment):
		return false
	return bool(equipment.get("equipment_initialized"))


func _reassertPendingRatio() -> void:
	if _pending_ratio_reassert.empty():
		return

	_ratio_reassert_elapsed += 1

	if _isEquipmentReady():
		_equipment_ready_streak += 1
	else:
		_equipment_ready_streak = 0

	var data = _pending_ratio_reassert

	var saved_max_health = float(data.get("max_health", max_health))
	var saved_max_energy = float(data.get("max_energy", max_energy))
	var saved_max_arcane = float(data.get("max_arcane", max_arcane))
	var health_ratio = float(data.get("health", health)) / saved_max_health if saved_max_health > 0 else 1.0
	var energy_ratio = float(data.get("energy", energy)) / saved_max_energy if saved_max_energy > 0 else 1.0
	var arcane_ratio = float(data.get("arcane", arcane)) / saved_max_arcane if saved_max_arcane > 0 else 1.0

	health = clamp(health_ratio * max_health, 0.0, max_health)
	energy = clamp(energy_ratio * max_energy, 0.0, max_energy)
	arcane = clamp(arcane_ratio * max_arcane, 0.0, max_arcane)

	net_health = health
	net_max_health = max_health
	net_energy = energy
	net_max_energy = max_energy
	net_arcane = arcane
	net_max_arcane = max_arcane
	_has_received_stats_sync = true

	if parent.is_in_group("Player"):
		var bar = get_node_or_null("../UI/Menu/CharacterBar")
		if is_instance_valid(bar):
			bar.updateBars()

	var done = _equipment_ready_streak >= ratio_reassert_settle_frames or _ratio_reassert_elapsed >= ratio_reassert_max_frames
	if done:
		_pending_ratio_reassert = {}
		_stats_stable = true






















func _applyStatsSnapshotInternal(data: Dictionary) -> void:
	if data.empty():
		return

	# Preserve ratios instead of absolute values. If equipment_max_health/etc
	# haven't been applied yet when this runs (Equipment.updateEquipment()
	# requires a valid character node and can silently defer), updateAttributes()
	# below will compute a temporarily-wrong max_health -- clamping the saved
	# absolute health against that wrong max is what causes the snap-to-30%.
	# Scaling by ratio keeps "full" showing as full regardless.
	var saved_max_health = float(data.get("max_health", max_health))
	var saved_max_energy = float(data.get("max_energy", max_energy))
	var saved_max_arcane = float(data.get("max_arcane", max_arcane))
	var health_ratio = float(data.get("health", health)) / saved_max_health if saved_max_health > 0 else 1.0
	var energy_ratio = float(data.get("energy", energy)) / saved_max_energy if saved_max_energy > 0 else 1.0
	var arcane_ratio = float(data.get("arcane", arcane)) / saved_max_arcane if saved_max_arcane > 0 else 1.0

	if data.has("experience_points"): experience_points = data["experience_points"]
	if data.has("level"): level = data["level"]
	if data.has("available_attribute_points"): available_attribute_points = data["available_attribute_points"]

	var loadedAttributePoints = data.get("attribute_points_spent", {})
	if loadedAttributePoints is Dictionary:
		for attribute_name in attribute_points_spent.keys():
			if loadedAttributePoints.has(attribute_name):
				attribute_points_spent[attribute_name] = int(loadedAttributePoints[attribute_name])

	var loadedAttributes = data.get("attributes", {})
	if loadedAttributes is Dictionary:
		for attribute_name in attributes.keys():
			if loadedAttributes.has(attribute_name):
				attributes[attribute_name] = float(loadedAttributes[attribute_name])
			else:
				attributes[attribute_name] = getAttributeValue(attribute_points_spent[attribute_name])

	if data.has("statuses"): statuses = data["statuses"].duplicate(true)
	if data.has("debuff_buffs_active"): debuff_buffs_active = data["debuff_buffs_active"].duplicate(true)

	markAttributeCacheDirty()
	updateAttributes()

	health = clamp(health_ratio * max_health, 0.0, max_health)
	energy = clamp(energy_ratio * max_energy, 0.0, max_energy)
	arcane = clamp(arcane_ratio * max_arcane, 0.0, max_arcane)
















	
	
# server calls this on the owning client during periodic autosave for remote players
remote func requestSelfSaveStats() -> void:
	if !parent.has_method("isLocalPlayer") or !parent.isLocalPlayer():
		return
	saveData()











func _writeStatsDataLocal(saveDirectory:String, data:Dictionary) -> void:
	var savePath = saveDirectory + "stats.save"
	var dir = Directory.new()
	if !dir.dir_exists(saveDirectory):
		dir.make_dir_recursive(saveDirectory)
	var file = File.new()
	if file.open(savePath, File.WRITE) != OK:
		return
	file.store_var(data, true)
	file.close()

remote func requestSaveStatsData(saveDirectory:String, data:Dictionary) -> void:
	if !get_tree().is_network_server():
		return
	_writeStatsDataLocal(saveDirectory, data)





func loadData():
	if parent.is_in_group("Player"):
		return

	if !isAuthority():
		return
	var savePath = getSaveDirectory() + "stats.save"
	var file = File.new()
	if !file.file_exists(savePath):
		_syncLoadedAttributesToServer()
		return
	if file.open(savePath, File.READ) != OK:
		_syncLoadedAttributesToServer()
		return
	var data = file.get_var()
	file.close()
	experience_points = data.get("experience_points", experience_points)
	level = data.get("level", level)
	available_attribute_points = data.get("available_attribute_points", available_attribute_points)
	var loadedAttributePoints = data.get("attribute_points_spent", {})
	if loadedAttributePoints is Dictionary:
		for attribute_name in attribute_points_spent.keys():
			if loadedAttributePoints.has(attribute_name):
				attribute_points_spent[attribute_name] = int(loadedAttributePoints[attribute_name])
	var loadedAttributes = data.get("attributes", {})
	if loadedAttributes is Dictionary:
		for attribute_name in attributes.keys():
			if loadedAttributes.has(attribute_name):
				attributes[attribute_name] = float(loadedAttributes[attribute_name])
			else:
				attributes[attribute_name] = getAttributeValue(attribute_points_spent[attribute_name])
	statuses = data.get("statuses", {}).duplicate(true)
	debuff_buffs_active = data.get("debuff_buffs_active", {}).duplicate(true)
	markAttributeCacheDirty()
	_syncLoadedAttributesToServer()








































func _syncLoadedAttributesToServer() -> void:
	# The server is combat authority for players but never runs loadData()
	# for them (isLocalOwner() blocks it) -- without this, whatever points
	# a player already spent in a previous session are invisible to the
	# server, which keeps computing combat off untouched defaults.
	if get_tree().network_peer == null or !parent.is_in_group("Player") or get_tree().is_network_server():
		return
	rpc_id(1, "requestSyncLoadedAttributes", attribute_points_spent.duplicate(true), attributes.duplicate(true), available_attribute_points, experience_points, level)

remote func requestSyncLoadedAttributes(points_spent:Dictionary, loaded_attributes:Dictionary, avail_points:int, experience:int, lvl:int) -> void:
	if !get_tree().is_network_server():
		return
	for k in attribute_points_spent.keys():
		if points_spent.has(k):
			attribute_points_spent[k] = int(points_spent[k])
	for k in attributes.keys():
		if loaded_attributes.has(k):
			attributes[k] = float(loaded_attributes[k])
	available_attribute_points = avail_points
	experience_points = experience
	level = lvl
	markAttributeCacheDirty()
	updateAttributes()




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
	if _shouldRouteThroughAuthority():
		rpc_id(_authorityId(), "requestIncreaseAttribute", attribute_name)
		return
	_increaseAttributeLocal(attribute_name)

remote func requestIncreaseAttribute(attribute_name:String) -> void:
	if !get_tree().is_network_server():
		return
	_increaseAttributeLocal(attribute_name)

func _increaseAttributeLocal(attribute_name:String) -> void:
	if !attributes.has(attribute_name):
		return
	if available_attribute_points < 1:
		return
	attribute_points_spent[attribute_name] += 1
	available_attribute_points -= 1
	attributes[attribute_name] = getAttributeValue(attribute_points_spent[attribute_name])
	markAttributeCacheDirty()
	updateAttributes()

func decreaseAttribute(attribute_name:String) -> void:
	if !attributes.has(attribute_name):
		return
	if _shouldRouteThroughAuthority():
		rpc_id(_authorityId(), "requestDecreaseAttribute", attribute_name)
		return
	_decreaseAttributeLocal(attribute_name)

remote func requestDecreaseAttribute(attribute_name:String) -> void:
	if !get_tree().is_network_server():
		return
	_decreaseAttributeLocal(attribute_name)

func _decreaseAttributeLocal(attribute_name:String) -> void:
	if !attributes.has(attribute_name):
		return
	var current_value = getAttributeValue(attribute_points_spent[attribute_name])
	var next_value = getAttributeValue(attribute_points_spent[attribute_name] - 1)
	if current_value <= MIN_ATTRIBUTE:
		return
	if next_value < MIN_ATTRIBUTE:
		return
	attribute_points_spent[attribute_name] -= 1
	available_attribute_points += 1
	attributes[attribute_name] = next_value
	markAttributeCacheDirty()
	updateAttributes()
	
	
	
var attribute_points_spent = {
	"strength": 0,
	"power": 0,
	"impact": 0,
	"agility": 0,
	"dexterity": 0,
	"balance": 0,
	"vitality": 0,
	"toughness": 0,
	"endurance":0,
	"instinct": 0,
	"perception": 0,
	"intelligence": 0,
	"wisdom": 0,
	"haste": 0,
	"charisma": 0,
	"authority": 0
}



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


onready var mob_status_grid:GridContainer
onready var player_status_grid:GridContainer
onready var player_example_icon:TextureRect
onready var mob_example_icon:TextureRect

func updateStatusGrid(grid:GridContainer, source)->void:
	if !parent.is_in_group("Player"):return

	mob_status_grid=$"../UI/CrossairInspect/MobStatusGrid"
	player_status_grid=$"../UI/Menu/CharacterBar/PlayerStatusGrid"
	player_example_icon=$"../UI/Menu/CharacterBar/PlayerStatusGrid/Icon1"
	mob_example_icon=$"../UI/CrossairInspect/GridContainer/Icon1"

	if grid==null:return

	var template:TextureRect=grid.get_node("Icon1")

	for child in grid.get_children():
		if child!=template:child.queue_free()

	template.visible=false

	if source==null:return

	var status_value
	var icon_instance:TextureRect
	var duration_label
	var stack_label
	var stack_value:int
	var category

	for status_name in source.statuses.keys():
		status_value=source.statuses[status_name]

		if typeof(status_value)==TYPE_ARRAY:
			for status_entry in status_value:
				if typeof(status_entry)!=TYPE_DICTIONARY:continue

				if !Skills.status_icons.has(status_name):
					if Skills.skills.has(status_name):
						Skills.status_icons[status_name]=Skills.skills[status_name]
					else:
						for category_name in ["flasks","weapons","armors"]:
							category=Items.get(category_name)
							if category!=null and category.has(status_name):
								Skills.status_icons[status_name]=category[status_name]["icon"]
								break
					if !Skills.status_icons.has(status_name):continue

				icon_instance=template.duplicate()
				icon_instance.visible=true
				icon_instance.texture=load(Skills.status_icons[status_name]) if Skills.status_icons[status_name] is String else Skills.status_icons[status_name]

				duration_label=icon_instance.get_node("Label")
				if duration_label:duration_label.text=str(int(ceil(status_entry.get("duration",0.0))))

				stack_label=icon_instance.get_node("Stack")
				if stack_label:
					stack_value=0
					for entry in status_value:
						if typeof(entry)==TYPE_DICTIONARY:
							stack_value+=int(entry.get("stacks",1))
					stack_label.text="" if stack_value<=1 else str(stack_value)

				grid.add_child(icon_instance)

		elif typeof(status_value)==TYPE_DICTIONARY:
			if !Skills.status_icons.has(status_name):
				if Skills.skills.has(status_name):
					Skills.status_icons[status_name]=Skills.skills[status_name]
				else:
					for category_name in ["flasks","weapons","armors"]:
						category=Items.get(category_name)
						if category!=null and category.has(status_name):
							Skills.status_icons[status_name]=category[status_name]["icon"]
							break
				if !Skills.status_icons.has(status_name):continue

			icon_instance=template.duplicate()
			icon_instance.visible=true
			icon_instance.texture=load(Skills.status_icons[status_name]) if Skills.status_icons[status_name] is String else Skills.status_icons[status_name]

			duration_label=icon_instance.get_node("Label")
			if duration_label:duration_label.text=str(int(ceil(status_value.get("duration",0.0))))

			stack_label=icon_instance.get_node("Stack")
			if stack_label:
				stack_value=int(status_value.get("stacks",1))
				stack_label.text="" if stack_value<=1 else str(stack_value)

			grid.add_child(icon_instance)

	for icon_key in source.debuff_buffs_active.keys():
		status_value=source.debuff_buffs_active[icon_key]

		if !Skills.status_icons.has(icon_key):
			if Skills.skills.has(icon_key):
				Skills.status_icons[icon_key]=Skills.skills[icon_key]
			else:
				for category_name in ["flasks","weapons","armors"]:
					category=Items.get(category_name)
					if category!=null and category.has(icon_key):
						Skills.status_icons[icon_key]=category[icon_key]["icon"]
						break
			if !Skills.status_icons.has(icon_key):continue

		icon_instance=template.duplicate()
		icon_instance.visible=true
		icon_instance.texture=load(Skills.status_icons[icon_key]) if Skills.status_icons[icon_key] is String else Skills.status_icons[icon_key]

		duration_label=icon_instance.get_node("Label")
		if duration_label:duration_label.text=str(int(ceil(status_value.get("duration",0.0))))

		stack_label=icon_instance.get_node("Stack")
		if stack_label:
			if status_value.has("stackable") and !status_value["stackable"]:
				stack_label.text=""
			else:
				stack_value=int(status_value.get("stacks",1))
				stack_label.text="" if stack_value<=1 else str(stack_value)

		grid.add_child(icon_instance)


func tickBuffsDebuffs()->void:
	var buff_keys=debuff_buffs_active.keys()

	for buff_name in buff_keys:
		if !debuff_buffs_active.has(buff_name):continue

		var buff_data=debuff_buffs_active[buff_name]
		if typeof(buff_data)!=TYPE_DICTIONARY:continue

		var source_id=int(buff_data.get("source_id",0))
		var source=instance_from_id(source_id) if source_id!=0 else parent

		var duration=float(buff_data.get("duration",0.0))-1.0
		buff_data["duration"]=duration
		buff_data["regen_timer"]=float(buff_data.get("regen_timer",1.0))-1.0

		if duration<=0.0:
			debuff_buffs_active.erase(buff_name)
			continue

		var damage_type=buff_data.get("damage type",null)
		var damage_amount=float(buff_data.get("damage ammount",0.0))
		var dot_interval=float(buff_data.get("dot timer",1.0))
		if dot_interval<=0.0:dot_interval=1.0

		if damage_type!=null and damage_amount>0.0:
			var dot_timer=float(buff_data.get("dot_timer",dot_interval))-1.0
			buff_data["dot_timer"]=dot_timer

			while dot_timer<=0.0:
				dot_timer+=dot_interval
				getDamagedFromDebuff(source,buff_name,{damage_type:damage_amount})

			buff_data["dot_timer"]=dot_timer

		var heal=float(buff_data.get("regen health",0.0))
		if heal>0.0:getHeal(parent,heal)

		var energy_reg=float(buff_data.get("regen energy",0.0))
		if energy_reg>0.0:
			self.energy+=energy_reg
			if self.energy>self.max_energy:self.energy=self.max_energy

		var inst_h=float(buff_data.get("instant regen health",0.0))
		if inst_h>0.0:
			getHeal(parent,inst_h)
			buff_data["instant regen health"]=0.0

		var inst_e=float(buff_data.get("instant regen energy",0.0))
		if inst_e>0.0:
			self.energy+=inst_e
			if self.energy>self.max_energy:self.energy=self.max_energy
			buff_data["instant regen energy"]=0.0





func isBeneficialStatus(status_name:String)->bool:
	for skill_name in Skills.status_effects:
		if Skills.status_effects[skill_name].has(status_name):
			if !bool(Skills.status_effects[skill_name][status_name].get("malus",false)):
				return true
	return false
func applyBuffDebuff(buff_name:String, source:Node)->void:
	if !Skills.debuffs_buffs.has(buff_name):return
	if source==null:source=parent
	if _shouldRouteThroughAuthority():
		rpc_id(_authorityId(), "requestApplyBuffDebuff", buff_name, source.get_path())
		return
	_applyBuffDebuffLocal(buff_name, source)
func _authorityId() -> int:
	return 1 #combat authority is always the server, for players and mobs alike
#func _authorityId() -> int:
#	if parent.is_in_group("Player"):
#		return get_network_master()
#	return 1
#master func requestApplyBuffDebuff(buff_name:String, source_path:NodePath) -> void:
#	var source = get_node_or_null(source_path)
#	if source == null:
#		return
#	_applyBuffDebuffLocal(buff_name, source)
remote func requestApplyBuffDebuff(buff_name:String, source_path:NodePath) -> void:
	if !get_tree().is_network_server():
		return
	var source = get_node_or_null(source_path)
	if source == null:
		return
	_applyBuffDebuffLocal(buff_name, source)
	
	
	
	
func _applyBuffDebuffLocal(buff_name:String, source:Node)->void:
	if !Skills.debuffs_buffs.has(buff_name):return
	if source==null:source=parent

	var buff_data=Skills.debuffs_buffs[buff_name]
	var stackable=bool(buff_data.get("stackable",false))
	var raw_duration=float(buff_data.get("duration",0.0))
	var tenacity=float(derived_stats.get("tenacity",1.0))
	var is_malus=bool(buff_data.get("malus",false))

	if is_malus:
		raw_duration/=tenacity
		if raw_duration<1.0:raw_duration=1.0
	else:
		# 0.25 tenacity = 25% duration
		# 2.0 tenacity = 150% duration
		var buff_multiplier=lerp(0.25,1.5,inverse_lerp(0.25,2.0,tenacity))
		raw_duration*=buff_multiplier

	if debuff_buffs_active.has(buff_name):
		debuff_buffs_active[buff_name]["duration"]=raw_duration
		if stackable:
			debuff_buffs_active[buff_name]["stacks"]=int(debuff_buffs_active[buff_name].get("stacks",1))+1
		return

	var applied_attributes={}
	for attribute_name in attributes_buff.keys():
		applied_attributes[attribute_name]=float(buff_data.get(attribute_name,0.0))

	var dot_interval=float(buff_data.get("dot timer",1.0))
	if dot_interval<=0.0:dot_interval=1.0

	debuff_buffs_active[buff_name]={
		"duration":raw_duration,
		"attributes":applied_attributes,
		"stacks":1,
		"stackable":stackable,
		"regen_timer":1.0,
		"dot_timer":dot_interval,
		"dot_interval":dot_interval,
		"damage ammount":float(buff_data.get("damage ammount",0.0)),
		"damage type":buff_data.get("damage type",null),
		"def":float(buff_data.get("def",0.0)),
		"def modified":buff_data.get("def modified",[]),
		"atk":float(buff_data.get("atk",0.0)),
		"atk modified":buff_data.get("atk modified",[]),
		"mov speed":float(buff_data.get("mov speed",1.0)),
		"source_id":source.get_instance_id() if source else 0
	}

	for key in buff_data:
		if key.begins_with("regen ") or key.begins_with("instant regen "):
			debuff_buffs_active[buff_name][key]=buff_data[key]

	updateStatusGrid(player_status_grid, self)




var statuses={}
var status_attribute_modifiers={}
var debuff_buffs_active={}
var attributes_buff = {
	"strength":0,"power":0,"impact":0,"agility":0,"dexterity":0,"balance":0,"vitality":0,
	"toughness":0,"endurance":0,"instinct":0,"perception":0,"intelligence":0,
	"wisdom":0,"haste":0,"charisma":0,"authority":0
}
var flat_defence_bonus = {}
var flat_damage_bonus = {}
var defence_mult = {}
var damage_mult = {}
var defence_flat_modifier = {}
var damage_flat_modifier = {}
var movement_speed_modifier = 1.0
var equipment_max_health = 0.0
var equipment_max_arcane = 0.0
var equipment_max_energy = 0.0
var equipment_movement_speed = 1.0
var equipment_derived_stats = {}

func updateCombatAttributes():
	max_arcane = base_max_arcane * getTotalAttribute("wisdom") + equipment_max_arcane
	max_health = base_max_health * getTotalAttribute("vitality") + equipment_max_health

	if getTotalAttribute("endurance") >= 1.0:
		max_energy = base_max_energy + ((getTotalAttribute("endurance") - 1.0) * 500)
	else:
		max_energy = base_max_energy + ((getTotalAttribute("endurance") - 1.0) * 125)
	max_energy = max(0.0,max_energy + equipment_max_energy)

	walk_speed = max(0.0,base_walk_speed * movement_speed_modifier * equipment_movement_speed) * getTotalAttribute("agility")
	run_speed = max(0.0,base_run_speed * movement_speed_modifier * equipment_movement_speed) * getTotalAttribute("agility")

	if parent.is_in_group("Entity") and parent.is_in_combat:
		walk_speed *= 0.9
		run_speed *= 0.9

	var toughness_bonus = (getTotalAttribute("toughness") - 1.0) * 50.0

	var base_defence = {
		"slash": defences[damage_type.slash],
		"blunt": defences[damage_type.blunt],
		"pierce": defences[damage_type.pierce],
		"sonic": defences[damage_type.sonic],
		"heat": defences[damage_type.heat],
		"cold": defences[damage_type.cold],
		"jolt": defences[damage_type.jolt],
		"toxic": defences[damage_type.toxic],
		"acid": defences[damage_type.acid],
		"arcane": defences[damage_type.arcane],
		"bleed": defences[damage_type.bleed],
		"radiant": defences[damage_type.radiant]
	}

	for damage_name in base_defence:
		base_defence[damage_name] += toughness_bonus
		base_defence[damage_name] += equipment_defence_bonus[damage_type[damage_name]]
		base_defence[damage_name] += flat_defence_bonus.get(damage_name,0.0)
		base_defence[damage_name] += defence_flat_modifier.get(damage_name,0.0)

	slash_defence = base_defence["slash"] * defence_mult.get("slash",1.0)
	blunt_defence = base_defence["blunt"] * defence_mult.get("blunt",1.0)
	pierce_defence = base_defence["pierce"] * defence_mult.get("pierce",1.0)
	sonic_defence = base_defence["sonic"] * defence_mult.get("sonic",1.0)
	heat_defence = base_defence["heat"] * defence_mult.get("heat",1.0)
	cold_defence = base_defence["cold"] * defence_mult.get("cold",1.0)
	jolt_defence = base_defence["jolt"] * defence_mult.get("jolt",1.0)
	toxic_defence = base_defence["toxic"] * defence_mult.get("toxic",1.0)
	acid_defence = base_defence["acid"] * defence_mult.get("acid",1.0)
	arcane_defence = base_defence["arcane"] * defence_mult.get("arcane",1.0)
	bleed_defence = base_defence["bleed"] * defence_mult.get("bleed",1.0)
	radiant_defence = base_defence["radiant"] * defence_mult.get("radiant",1.0)

	var strength = max(getTotalAttribute("strength"),0.1)
	var power = max(getTotalAttribute("power"),0.1)

	slash_multiplier = (strength + equipment_damage_bonus[damage_type.slash]) * damage_mult.get("slash",1.0)
	blunt_multiplier = (strength + equipment_damage_bonus[damage_type.blunt]) * damage_mult.get("blunt",1.0)
	pierce_multiplier = (strength + equipment_damage_bonus[damage_type.pierce]) * damage_mult.get("pierce",1.0)
	bleed_multiplier = (strength + equipment_damage_bonus[damage_type.bleed]) * damage_mult.get("bleed",1.0)

	sonic_multiplier = (power + equipment_damage_bonus[damage_type.sonic]) * damage_mult.get("sonic",1.0)
	heat_multiplier = (power + equipment_damage_bonus[damage_type.heat]) * damage_mult.get("heat",1.0)
	cold_multiplier = (power + equipment_damage_bonus[damage_type.cold]) * damage_mult.get("cold",1.0)
	jolt_multiplier = (power + equipment_damage_bonus[damage_type.jolt]) * damage_mult.get("jolt",1.0)
	toxic_multiplier = (power + equipment_damage_bonus[damage_type.toxic]) * damage_mult.get("toxic",1.0)
	acid_multiplier = (power + equipment_damage_bonus[damage_type.acid]) * damage_mult.get("acid",1.0)
	arcane_multiplier = (power + equipment_damage_bonus[damage_type.arcane]) * damage_mult.get("arcane",1.0)
	radiant_multiplier = (power + equipment_damage_bonus[damage_type.radiant]) * damage_mult.get("radiant",1.0)




func updateAttributes():
	for damage_type in defences:
		defences[damage_type] = getTotalAttribute("toughness") * 2.0

	derived_stats["attack_speed"] = getTotalAttribute("dexterity")
	derived_stats["cooldown_reduction"] = getTotalAttribute("haste") * 0.85 + getTotalAttribute("instinct") * 0.10 + getTotalAttribute("wisdom") * 0.05
	derived_stats["climb_speed"] = 1.0 + getTotalAttribute("dexterity") * 0.20 + getTotalAttribute("strength") * 0.80
	derived_stats["swim_speed"] = 1.0 + getTotalAttribute("strength") * 0.55 + getTotalAttribute("agility") * 0.45
	derived_stats["fall_resistance"] = getTotalAttribute("toughness") * 0.75 + getTotalAttribute("agility") * 0.25
	derived_stats["stagger"] = getTotalAttribute("impact") * 0.75 + getTotalAttribute("power") * 0.25
	derived_stats["tenacity"] = getTotalAttribute("balance") * 0.95 + getTotalAttribute("agility") * 0.05 + getTotalAttribute("toughness") * 0.05
	derived_stats["turn_speed"] = 7.5 + getTotalAttribute("agility")
	derived_stats["atk_turn_speed"] = 0.1 + getTotalAttribute("agility") * 0.3
	derived_stats["dash_turn_speed"] = 10.0 + getTotalAttribute("agility") * 3.0
	derived_stats["jump_power"] = 1.0 + getTotalAttribute("power") * 3.6 + getTotalAttribute("agility") * 3.6
	derived_stats["crit_chance"] = 0.05 + getTotalAttribute("instinct") * 0.02
	derived_stats["penetrating_hit_chance"] = 0.05 + getTotalAttribute("wisdom") * 0.02
	derived_stats["penetration_power"] = 0.1 * getTotalAttribute("power") * 0.25 + getTotalAttribute("strength") * 0.25
	derived_stats["crit_damage"] = 2.0 + getTotalAttribute("power") * 0.05
	derived_stats["detection_range"] = 10.0 + getTotalAttribute("perception") * 2.0
	derived_stats["energy_regeneration"] = 1.0 + getTotalAttribute("endurance")
	derived_stats["health_regeneration"] = getTotalAttribute("vitality") 
	derived_stats["threat"] = getTotalAttribute("authority")

	for stat_name in equipment_derived_stats:
		derived_stats[stat_name] = derived_stats.get(stat_name,0.0) + equipment_derived_stats[stat_name]

	updateCombatAttributes()

	health = min(health,max_health)
	arcane = min(arcane,max_arcane)
	energy = min(energy,max_energy)
	markAttributeCacheDirty()


var base_flat_damage_bonus = {}
func updateBuffDebuffs()->void:
	var buff_keys = debuff_buffs_active.keys()

	for buff_name in buff_keys:
		if !debuff_buffs_active.has(buff_name):
			continue

		var buff_data = debuff_buffs_active[buff_name]
		if typeof(buff_data) != TYPE_DICTIONARY:
			continue

		var duration = float(buff_data.get("duration", 0.0))
		if duration <= 0.0:
			debuff_buffs_active.erase(buff_name)
			continue

		if !buff_data.has("attributes"):
			buff_data["attributes"] = {}

		if !buff_data.has("def modified"):
			buff_data["def modified"] = []

		if !buff_data.has("atk modified"):
			buff_data["atk modified"] = []

	for k in attributes_buff.keys():
		attributes_buff[k] = 0.0

	defence_flat_modifier.clear()

	flat_damage_bonus = base_flat_damage_bonus.duplicate()

	movement_speed_modifier = 1.0

	for buff_name in debuff_buffs_active.keys():
		var buff_data = debuff_buffs_active[buff_name]
		if typeof(buff_data) != TYPE_DICTIONARY:
			continue

		var stacks = int(buff_data.get("stacks", 1))
		var attribute_data = buff_data.get("attributes", {})

		if typeof(attribute_data) == TYPE_DICTIONARY:
			for attr in attributes_buff.keys():
				attributes_buff[attr] += float(attribute_data.get(attr, 0.0)) * stacks

		var def_val = float(buff_data.get("def", 0.0)) * stacks
		for def_name in buff_data.get("def modified", []):
			def_name = str(def_name)
			defence_flat_modifier[def_name] = defence_flat_modifier.get(def_name, 0.0) + def_val

		var atk_val = float(buff_data.get("atk", 0.0)) * stacks
		for dmg_name in buff_data.get("atk modified", []):
			dmg_name = str(dmg_name)
			flat_damage_bonus[dmg_name] = flat_damage_bonus.get(dmg_name, 0.0) + atk_val

		movement_speed_modifier *= pow(float(buff_data.get("mov speed", 1.0)), stacks)










func purify()->void:
	for buff_name in debuff_buffs_active.keys():
		if Skills.debuffs_buffs.has(buff_name) and bool(Skills.debuffs_buffs[buff_name].get("malus",false)):
			debuff_buffs_active.erase(buff_name)

	for status_name in statuses.keys():
		var remove=false

		for skill_name in Skills.status_effects:
			if Skills.status_effects[skill_name].has(status_name):
				if bool(Skills.status_effects[skill_name][status_name].get("malus",false)):
					remove=true
					break

		if remove:
			removeStatus(status_name)

func cleanse()->void:
	var target_type=""
	var target_name=""
	var target_duration=-1.0

	for buff_name in debuff_buffs_active:
		if !Skills.debuffs_buffs.has(buff_name):continue
		if !bool(Skills.debuffs_buffs[buff_name].get("malus",false)):continue

		var duration=float(debuff_buffs_active[buff_name].get("duration",0.0))
		if duration>target_duration:
			target_duration=duration
			target_type="buff"
			target_name=buff_name

	for status_name in statuses:
		var harmful=false
		for skill_name in Skills.status_effects:
			if Skills.status_effects[skill_name].has(status_name):
				if bool(Skills.status_effects[skill_name][status_name].get("malus",false)):
					harmful=true
					break
		if !harmful:continue

		var duration=0.0
		if typeof(statuses[status_name])==TYPE_DICTIONARY:
			duration=float(statuses[status_name].get("duration",0.0))
		elif typeof(statuses[status_name])==TYPE_ARRAY:
			for entry in statuses[status_name]:
				if typeof(entry)!=TYPE_DICTIONARY:continue
				duration=max(duration,float(entry.get("duration",0.0)))

		if duration>target_duration:
			target_duration=duration
			target_type="status"
			target_name=status_name

	if target_name=="":
		return

	if target_type=="buff":
		debuff_buffs_active.erase(target_name)
	else:
		removeStatus(target_name)

	var chat=get_node_or_null("../UI/Chat")
	if chat and chat.has_method("sendSystemMessage"):
		chat.sendSystemMessage(parent.entity_name+" got cleansed off: "+target_name)

func dispell()->void:
	var target_type=""
	var target_name=""
	var target_duration=-1.0

	for buff_name in debuff_buffs_active:
		if !Skills.debuffs_buffs.has(buff_name):continue
		if bool(Skills.debuffs_buffs[buff_name].get("malus",false)):continue

		var duration=float(debuff_buffs_active[buff_name].get("duration",0.0))
		if duration>target_duration:
			target_duration=duration
			target_type="buff"
			target_name=buff_name

	for status_name in statuses:
		var beneficial=false
		for skill_name in Skills.status_effects:
			if Skills.status_effects[skill_name].has(status_name):
				if !bool(Skills.status_effects[skill_name][status_name].get("malus",false)):
					beneficial=true
					break

		if !beneficial:continue

		var duration=0.0
		if typeof(statuses[status_name])==TYPE_DICTIONARY:
			duration=float(statuses[status_name].get("duration",0.0))
		elif typeof(statuses[status_name])==TYPE_ARRAY:
			for entry in statuses[status_name]:
				if typeof(entry)!=TYPE_DICTIONARY:continue
				duration=max(duration,float(entry.get("duration",0.0)))

		if duration>target_duration:
			target_duration=duration
			target_type="status"
			target_name=status_name

	if target_name=="":
		return

	if target_type=="buff":
		debuff_buffs_active.erase(target_name)
	else:
		removeStatus(target_name)

	var chat=get_node_or_null("../UI/Chat")
	if chat and chat.has_method("sendSystemMessage"):
		chat.sendSystemMessage(parent.entity_name+" got dispelled: "+target_name)

func exhaust()->void:
	for buff_name in debuff_buffs_active.keys():
		if Skills.debuffs_buffs.has(buff_name) and !bool(Skills.debuffs_buffs[buff_name].get("malus",false)):
			debuff_buffs_active.erase(buff_name)

	for status_name in statuses.keys():
		var remove=false

		for skill_name in Skills.status_effects:
			if Skills.status_effects[skill_name].has(status_name):
				if !bool(Skills.status_effects[skill_name][status_name].get("malus",false)):
					remove=true
					break

		if remove:
			removeStatus(status_name)


var _attribute_total_cache := {}
var _attribute_cache_dirty := true

func markAttributeCacheDirty() -> void:
	_attribute_cache_dirty = true

func getTotalAttribute(name:String)->float: # called thousands of times per second
	if _attribute_cache_dirty:
		_rebuildAttributeTotalCache()
	return _attribute_total_cache.get(name, 1.0)

func _rebuildAttributeTotalCache() -> void:
	_attribute_total_cache.clear()
	for key in attributes:
		_attribute_total_cache[key] = attributes.get(key,1.0) + equipment_attributes.get(key,0.0) + attributes_buff.get(key,0.0)
	_attribute_cache_dirty = false

func removeStatus(status_name:String)->void:
	if !statuses.has(status_name):
		return

	if status_name == "stun":
		if parent.has_method("setAnimLock"):
			parent.setAnimLock("stunned", false)
			parent.setAnimLock("staggered", false)
			parent.anim_locks["stunned"] = false
			parent.anim_locks["staggered"] = false
			parent.unlockAnim()

	statuses.erase(status_name)
	updateStatusGrid(player_status_grid, self)
	





func getBleedData(skill:String)->Dictionary:

	if !Skills.status_effects.has(skill):
		return {"tick_damage":0.0,"duration":0.0,"can_stack":false}

	if !Skills.status_effects[skill].has("bleed"):
		return {"tick_damage":0.0,"duration":0.0,"can_stack":false}

	var bleed = Skills.status_effects[skill]["bleed"]

	return {
		"tick_damage":bleed.get("base_damage",0.0) * bleed_multiplier,
		"duration":bleed.get("duration",0.0),
		"can_stack":bleed.get("can_stack",false)
	}





func getSkillLevel(skill_name:String)->int:
	var root = get_node_or_null("../UI/SkillTreeRoot")
	if root == null:
		return 0

	var skill_texture = Skills.skills.get(skill_name,null)
	if skill_texture == null:
		return 0

	for index in range(1,10):
		var control = root.get_node_or_null("SkillsTreeHolder"+str(index)+"/Control")
		if control == null:
			continue

		for child in control.get_children():
			if !(child is TextureButton):
				continue
			if !child.has_node("Slot"):
				continue

			var slot = child.get_node("Slot")
			if slot.texture == skill_texture:
				return child.skill_level

	return 0
func getSkillLevelMultiplier(skill_name:String) -> float:
	return Skills.getDamageMultiplier(skill_name,max(0,getSkillLevel(skill_name)-1))





var active_on_hit_effects = {}
func rebuildOnHitEffects()->void:

	active_on_hit_effects.clear()

	active_on_hit_effects["combo attack"] = {
		"energy_flat":10.0
	}

	if getSkillLevel("combo attack") >= 5:

		active_on_hit_effects["combo attack"]["reduce_cooldowns"] = {
			"cleave":0.25,
			"section":0.25,
			"perforation trifecta":1.25
		}

	if getSkillLevel("combo attack") >= 2:
		active_on_hit_effects["combo attack"]["lifesteal_flat"] = 300

	# Glyph system example for later:
	#
	# if hasGlyph("bloodthirst"):
	# 	active_on_hit_effects["combo attack"]["lifesteal_percent"] = 0.05
	#
	# if hasGlyph("combat_focus"):
	#
	# 	if !active_on_hit_effects["combo attack"].has("reduce_cooldowns"):
	# 		active_on_hit_effects["combo attack"]["reduce_cooldowns"] = {}
	#
	# 	active_on_hit_effects["combo attack"]["reduce_cooldowns"]["overhead strike"] = 0.25

	if !active_on_hit_effects["combo attack"].has("lifesteal_flat"):
		active_on_hit_effects["combo attack"]["lifesteal_flat"] = 0.0

	if !active_on_hit_effects["combo attack"].has("lifesteal_percent"):
		active_on_hit_effects["combo attack"]["lifesteal_percent"] = 0.0



func resetChargedStacks()->void:
	for attack_name in charged_attack_stacks:charged_attack_stacks[attack_name]["stacks"] = 0


var damage_meter = {}

func displayDMGMeter()->String:
	var text=""
	for attacker_id in damage_meter:
		var entry=damage_meter[attacker_id]
		var attacker=entry.attacker
		if is_instance_valid(attacker):
			text+=attacker.name+" "+attacker.entity_name+": "+str(round(entry.damage))+"\n"
	return text.strip_edges()


var areas_to_use = {
	"combo attack": NodePath("../Turnable/CleaveSmall"),
	
	
	"cross draw": NodePath("../Turnable/CleaveSmall"),
	"recoil slash": NodePath("../Turnable/CleaveSmall"),
	"lunar slash": NodePath("../Turnable/CleaveSmall"),
	
	
	"raze": NodePath("../Turnable/Cleave"),
	"sledge": NodePath("../Turnable/Cleave"),
	"shoulder bash": NodePath("../Turnable/Bash"),
	"sadistic blow": NodePath("../Turnable/Bash"),
	
	
	"shield bash": NodePath("../Turnable/Bash"),
	"shield pummel": NodePath("../Turnable/Bash"),
	"mighty push": NodePath("../Turnable/Bash"),
	"smite": NodePath("../Turnable/Bash"),
	"counterstrike": NodePath("../Turnable/Bash"),
	"intercept": NodePath("../Turnable/Bash"),
	
	
	
	"slam": NodePath("../SlamArea"),
	"wall breaker": NodePath("../SlamArea"),
	"poisonous hairs": NodePath("../AreaAOE"),
	"web shot": NodePath("../AreaRanged"),
	
	
	
	
	"infernal breath": NodePath("../character/Skeleton/BoneAttachment/AreaFirebreath"),
	"cocytus breath": NodePath("../character/Skeleton/BoneAttachment/AreaFirebreath"),
	"fire breath": NodePath("../character/Skeleton/BoneAttachment/AreaFirebreath"),
	"ice breath": NodePath("../character/Skeleton/BoneAttachment/AreaFirebreath"),
	"fire bombardment": NodePath("../character/Skeleton/BoneAttachment/AreaFirebreath"),
	"frost bombardment": NodePath("../character/Skeleton/BoneAttachment/AreaFirebreath"),
	"scorched earth": NodePath("../character/Skeleton/BoneAttachment/AreaFirebreath"),
	"frozen earth": NodePath("../character/Skeleton/BoneAttachment/AreaFirebreath"),

}

var charged_attack_stacks = {
	"obliteration": {
		"stacks": 0,
		"multiplier": 1.5
	}
}
func dealDamage():
	if parent.is_in_group("Entity") and "is_in_combat" in parent:
		parent.is_in_combat = true
	var area: Area = null

	if parent.is_in_group("Player") or parent.is_in_group("player"):
		var skill = parent.current_skill.to_lower()

		if areas_to_use.has(skill):
			area = get_node(areas_to_use[skill])
		else:
			if parent.WeaponMode.SWORD:
				area =  $"../character/root/Skeleton/WeaponR/Short"
			elif parent.WeaponMode.TWO_HANDED:
					area = $"../character/root/Skeleton/WeaponR/Long"
	elif parent.is_in_group("Detached"):
		area = get_node("Area")
	elif parent.is_in_group("Entity"):
		area = $"../AreaDamage"
	else:
		area = $"../AreaDamage"

	if area == null:
		return

	var damages = {}

	var skill_name:String = ""
	var skill_level_mult:float = 1.0

	skill_name = parent.current_skill
	skill_level_mult = getSkillLevelMultiplier(skill_name)

	var skill_damages = Skills.getDamages(skill_name)
#CHARGED ATTACKS____________________________________________________________________________________
	if charged_attack_stacks.has(skill_name):
		var data = charged_attack_stacks[skill_name]
		if data.stacks > 0:
			for dmg_type in skill_damages:
				skill_damages[dmg_type] += skill_damages[dmg_type] * (data.stacks * data.multiplier)
#___________________________________________________________________________________________________

	for dmg_type in skill_damages:
		var mult = 1.0
		var flat_add = 0.0

		match dmg_type:
			DamageTypes.Type.slash:
				mult = slash_multiplier
				flat_add = flat_damage_bonus.get("slash",0.0) + damage_flat_modifier.get("slash",0.0)

			DamageTypes.Type.blunt:
				mult = blunt_multiplier
				flat_add = flat_damage_bonus.get("blunt",0.0) + damage_flat_modifier.get("blunt",0.0)

			DamageTypes.Type.pierce:
				mult = pierce_multiplier
				flat_add = flat_damage_bonus.get("pierce",0.0) + damage_flat_modifier.get("pierce",0.0)

			DamageTypes.Type.bleed:
				mult = bleed_multiplier
				flat_add = flat_damage_bonus.get("bleed",0.0) + damage_flat_modifier.get("bleed",0.0)

			DamageTypes.Type.sonic:
				mult = sonic_multiplier
				flat_add = flat_damage_bonus.get("sonic",0.0) + damage_flat_modifier.get("sonic",0.0)

			DamageTypes.Type.heat:
				mult = heat_multiplier
				flat_add = flat_damage_bonus.get("heat",0.0) + damage_flat_modifier.get("heat",0.0)

			DamageTypes.Type.cold:
				mult = cold_multiplier
				flat_add = flat_damage_bonus.get("cold",0.0) + damage_flat_modifier.get("cold",0.0)

			DamageTypes.Type.jolt:
				mult = jolt_multiplier
				flat_add = flat_damage_bonus.get("jolt",0.0) + damage_flat_modifier.get("jolt",0.0)

			DamageTypes.Type.toxic:
				mult = toxic_multiplier
				flat_add = flat_damage_bonus.get("toxic",0.0) + damage_flat_modifier.get("toxic",0.0)

			DamageTypes.Type.acid:
				mult = acid_multiplier
				flat_add = flat_damage_bonus.get("acid",0.0) + damage_flat_modifier.get("acid",0.0)

			DamageTypes.Type.arcane:
				mult = arcane_multiplier
				flat_add = flat_damage_bonus.get("arcane",0.0) + damage_flat_modifier.get("arcane",0.0)

			DamageTypes.Type.radiant:
				mult = radiant_multiplier
				flat_add = flat_damage_bonus.get("radiant",0.0) + damage_flat_modifier.get("radiant",0.0)

		damages[dmg_type] = (skill_damages[dmg_type] * mult * skill_level_mult) + flat_add
		if parent.is_in_group("Player"):
			if parent.weapons==parent.WeaponMode.NONE and skill_name=="combo attack":
				var total=0.0
				for t in damages: total+=damages[t]
				damages={DamageTypes.Type.blunt:total}
				
				
	if parent.is_in_group("Player") and parent.weapons==parent.WeaponMode.DUAL:
		for dmg_type in damages:
			if parent.current_skill == "combo attack" or parent.WeaponMode.NONE:
				damages[dmg_type] *= 0.5

#_____________
	var my_stats = parent.get_node("Stats")
	var my_species = my_stats.species if my_stats != null else ""
	
	var base_pen_chance = my_stats.derived_stats.get("penetrating_hit_chance", 0.0)
	var is_penetrating_hit = randf() <= clamp(base_pen_chance + Skills.skill_penetration_chance.get(skill_name.to_lower(), 0.0), 0.0, 1.0)
	
	
	var is_crit = my_stats != null and randf() <= my_stats.derived_stats["crit_chance"]
	if is_crit:for dmg_type in damages:damages[dmg_type] *= my_stats.derived_stats["crit_damage"]

	var total_damage:int= 0
	for v in damages.values():
		total_damage += v
	for body in area.get_overlapping_bodies():
		if !CommonBehaviours.canHitEnemy(parent,body):
			continue

		var other_stats = body.get_node_or_null("Stats")
		if is_instance_valid(other_stats) and Skills.debuffs_buffs.has(skill_name):
			if Skills.debuffs_buffs[skill_name].get("malus", true):
				other_stats.applyBuffDebuff(skill_name, parent)
			else:
				applyBuffDebuff(skill_name, parent)
				
		if other_stats != null:
			var extra_threat = Skills.skill_extra_aggro.get(skill_name.to_lower(),0.0)
			var extra_treat_amplified = extra_threat * derived_stats["threat"] 
			
			other_stats.getHit(parent,damages,is_penetrating_hit,extra_treat_amplified,is_crit)
			Skills.applyImpactEffects(skill_name,body,parent)
		
		
		if parent.is_in_group("Player"):
			if body==parent:
				continue

			var stats=body.get_node_or_null("Stats")

			var victim_name=body.entity_name if "entity_name" in body else ""
			if victim_name=="" or victim_name==" " or victim_name=="nameless" or victim_name==" ":
				if stats and stats.species!="":
					victim_name=stats.species

			if victim_name=="" or victim_name==" " or victim_name=="nameless" or victim_name==" " or victim_name=="unknown":
				continue



			var attacker_name=parent.entity_name
			if attacker_name=="" or attacker_name==" " or attacker_name=="nameless":
				if my_stats and my_stats.species!="":
					attacker_name=my_stats.species

			var tag = ""
			if body.has_meta("last_hit_data"):
				var hit = body.get_meta("last_hit_data")
				if hit.attacker != parent:
					continue
				if hit.backstab:
					tag = " backstab"
				elif hit.flank:
					tag = " flank"

			var chat = get_node_or_null("../UI/Chat")
			if chat and chat.has_method("sendSystemMessage"):
				var hit = body.get_meta("last_hit_data") if body.has_meta("last_hit_data") else null

				var formatted_damage = ""

				if hit and hit.has("damages"):
					for dmg_type in hit.damages:
						var value = int(hit.damages[dmg_type])
						formatted_damage += str(value) + " " + damageTypeToString(int(dmg_type)) + " "

					formatted_damage = formatted_damage.strip_edges()
				else:
					formatted_damage = str(int(total_damage))

				if skill_name == "none":
					chat.sendSystemMessage(attacker_name + " dealt " + formatted_damage + " damage to " + victim_name + tag)
				else:
					chat.sendSystemMessage(attacker_name + " dealt " + formatted_damage + " damage to " + victim_name + " " + skill_name + tag)


	for attack_name in charged_attack_stacks:charged_attack_stacks[attack_name]["stacks"] = 0

	if parent.is_in_group("Player"):
		var skillbar = $"../UI/Skillbar"
		Skills.applyOnHitEffects(parent.current_skill, active_on_hit_effects, skillbar.active_cooldowns,self, total_damage)
	else:
		Skills.applyOnHitEffects(parent.current_skill, Skills.on_hit_effects, parent.skill_cooldowns,self, total_damage)



var flank_dmg_multiplier:float = 1.25
var backstab_dmg_multiplier:float = 1.5
func getHit(attacker:Node,damages:Dictionary,is_penetrating_hit:bool = false,extra_threat:float = 0.0,is_crit:bool=false)->void:
	if attacker and (attacker.name=="Stats" or attacker.get_class()=="Node"):
		attacker=attacker.get_parent()

	if _shouldRouteThroughAuthority():
		# We're not this entity's owner (attacking a remote player,
		# or any mob, which is server-owned) -- ask the authority to
		# apply it instead of mutating health locally, which would
		# only be visible to us and desync everyone else.
		rpc_id(_authorityId(), "requestGetHit", attacker.get_path(), damages, is_penetrating_hit, extra_threat, is_crit)
		return

	_applyHit(attacker,damages,is_penetrating_hit,extra_threat,is_crit)

#master func requestGetHit(attacker_path:NodePath, damages:Dictionary, is_penetrating_hit:bool, extra_threat:float, is_crit:bool) -> void:
#	var attacker = get_node_or_null(attacker_path)
#	if attacker == null:
#		return
#	_applyHit(attacker,damages,is_penetrating_hit,extra_threat,is_crit)
remote func requestGetHit(attacker_path:NodePath, damages:Dictionary, is_penetrating_hit:bool, extra_threat:float, is_crit:bool) -> void:
	if !get_tree().is_network_server():
		return
	var attacker = get_node_or_null(attacker_path)
	if attacker == null:
		return
	_applyHit(attacker,damages,is_penetrating_hit,extra_threat,is_crit)
func _applyHit(attacker:Node,damages:Dictionary,is_penetrating_hit:bool = false,extra_threat:float = 0.0,is_crit:bool=false)->void:
	if attacker and (attacker.name=="Stats" or attacker.get_class()=="Node"):
		attacker=attacker.get_parent()
	parent.is_in_combat=true
	var facing_multiplier = 1.0

	if attacker != null:
		if isFacingSelf(attacker,0.7):
			facing_multiplier =  backstab_dmg_multiplier
		elif isFacingSelf(attacker,0.0):
			facing_multiplier = flank_dmg_multiplier
	
	
	var total_damage:int = 0
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

		var mitigation=calcMitigation(defence,attacker,is_penetrating_hit)
		if is_penetrating_hit:
			mitigation*=1.0-attacker.stats.derived_stats["penetration_power"]

		

		var final_damage = damage * (1.0 - mitigation) * facing_multiplier
		if Skills.skill_dmg_immunity.has(parent.current_skill):
			return

		if Skills.skill_dmg_reduction.has(parent.current_skill):
			final_damage *= Skills.skill_dmg_reduction[parent.current_skill]
		if statuses.has("berserk_buff"):
			final_damage *= 1.8
		
		var is_flank_or_back = isFacingSelf(attacker, 0.0)

		if parent.current_skill == "guard" and not is_flank_or_back:
			var block = 1.0

			var main_texture = $"../UI/Equipment/MainHand/Slot".texture
			var off_texture = $"../UI/Equipment/OffHand/Slot".texture

			parent.stats.energy = min(parent.stats.energy + 10, parent.stats.max_energy)

			if parent.is_in_group("Player"):
				parent.anim_locks["guard"] = false
				parent.anim_locks["guard react"] = true

				for weapon_name in Items.weapons:
					var weapon = Items.weapons[weapon_name]

					if CommonBehaviours.sameIcon(weapon.get("icon"),main_texture):
						block *= weapon.get("block",1.0)

					if CommonBehaviours.sameIcon(weapon.get("icon"),off_texture):
						block *= weapon.get("block",1.0)

			else:
				block = 1.5

			final_damage /= max(block, 1.0)

		final_damages[dmg_type] = final_damage
		total_damage += final_damage




	
	# Berserk reflect
	if statuses.has("berserk_buff") and health > 0.0 and attacker != null and is_instance_valid(attacker) and attacker.has_node("Stats"):
		var attacker_stats = attacker.get_node("Stats")
		# reflect 100% of damage actually taken
		attacker_stats.health -= total_damage
		if attacker_stats.health < 0.0:attacker_stats.health = 0.0
	
	
	if attacker != null:
		if !("stored_body" in attacker):pass
		elif parent == null:pass
		elif !("stats" in parent):pass
		elif parent.stats.health > 0:attacker.stored_body = parent
		else:attacker.stored_body = null
			

	# PLAYER TAKES DAMAGE
	if parent.is_in_group("Player") or parent.is_in_group("player"):
		var chat=getChat(attacker)
		var victim_name=parent.entity_name
		if victim_name=="" or victim_name==" " or victim_name=="nameless" or victim_name.strip_edges()=="":
			var stats=parent.get_node_or_null("Stats")
			if stats and stats.species!="": victim_name=stats.species
			else: victim_name="unknown"

		var attacker_name=attacker.entity_name if attacker else "null"
		if attacker:
			if attacker_name=="" or attacker_name==" " or attacker_name=="nameless" or attacker_name.strip_edges()=="":
				var astats=attacker.get_node_or_null("Stats")
				if astats and astats.species!="": attacker_name=astats.species
				else: attacker_name="unknown"

		var tag=""
		if facing_multiplier==backstab_dmg_multiplier: tag=" backstab"
		elif facing_multiplier==flank_dmg_multiplier: tag=" flank"
		var msg
		if chat and chat.has_method("sendSystemMessage"):
			var skill_name=attacker.current_skill if attacker else "none"
			if skill_name=="none":
				msg="%s took %s damage from %s%s"%[victim_name,dmgText(total_damage),attacker_name,tag]
			else:
				msg="%s took %s damage from %s %s%s"%[victim_name,dmgText(total_damage),attacker_name,skill_name,tag]
			chat.sendSystemMessage(msg)
	
	
	if !(parent.is_in_group("Player") or parent.is_in_group("player")):
		if attacker != null and attacker.is_in_group("Entity"):
			var instigatorAggro=parent.getAggro(attacker)
			var threat=((total_damage*attacker.stats.derived_stats["threat"])) + extra_threat
			instigatorAggro.aggro+=threat 
			parent.shareAggro(parent.creator)
			for children in parent.spawned_bodies:
				parent.shareAggro(children)
				parent.getAggroFromOtherMob(children)
	
	if attacker != null:
		var attacker_id = attacker.get_instance_id()
		if !damage_meter.has(attacker_id):
			damage_meter[attacker_id] = {"attacker":attacker,"damage":0.0}
		damage_meter[attacker_id].damage += total_damage
	if parent.is_in_group("Player"):
		var character_bar = $"../UI/Menu/CharacterBar"
		character_bar.updateBars()
	updateBuffDebuffs()


	if parent.is_in_group("Player") or parent.is_in_group("player") or (attacker!=null and attacker.is_in_group("Player")):
		_broadcastDamageText(final_damages, is_crit, is_penetrating_hit, attacker)


	health -= total_damage
	getKilled()
	parent.set_meta("last_hit_data", {
	"damage": total_damage,
	"damages": final_damages,
	"flank": facing_multiplier == flank_dmg_multiplier,
	"backstab": facing_multiplier == backstab_dmg_multiplier,
	"victim": parent,
	"attacker": attacker
})

func spawnDamageText(damages:Dictionary,is_crit:bool=false,is_penetrating_hit:bool=false)->void:
	var text=""

	if is_crit:text+="CRITICAL!\n"
	if is_penetrating_hit:text+="PENETRATING!\n"

	for dmg_type in damages:
		if dmg_type == null:
			continue

		var value = int(damages[dmg_type])
		text += str(value) + " " + damageTypeToString(int(dmg_type)) + "\n"

	if text.strip_edges()=="":
		return

	var floating_res=CommonBehaviours.FloatingResScene.instance()
	if floating_res==null:return

	floating_res.text=text.strip_edges()

	if parent.is_in_group("Player") or parent.is_in_group("player"):
		floating_res.use_screen_center=false
		var menu=$"../UI/Menu/CharacterBar/Control"
		if is_instance_valid(menu):
			menu.add_child(floating_res)
			return

	floating_res.use_screen_center=false
	var camera=get_viewport().get_camera()
	if camera:
		floating_res.world_position=camera.unproject_position(parent.global_transform.origin+Vector3.UP*2.0)

	get_tree().root.add_child(floating_res)
func _sendDamageTextToPeer(peer_id:int, damages:Dictionary, is_crit:bool, is_penetrating_hit:bool) -> void:
	if get_tree().network_peer == null or peer_id == get_tree().get_network_unique_id():
		spawnDamageText(damages, is_crit, is_penetrating_hit)
	else:
		rpc_id(peer_id, "clientShowDamageText", damages, is_crit, is_penetrating_hit)

func _broadcastDamageText(damages:Dictionary, is_crit:bool, is_penetrating_hit:bool, attacker:Node) -> void:
	# _applyHit/_applyDamagedFromDebuff only ever run on the server now (combat
	# authority moved there). spawnDamageText() adds a node to whichever tree calls
	# it -- calling it directly here just puts an invisible node in the server's
	# tree that no player sees. Send it to the peers who actually need to see it.
	var notified_peers := []

	if parent.is_in_group("Player"):
		var victim_peer = parent.get_network_master()
		_sendDamageTextToPeer(victim_peer, damages, is_crit, is_penetrating_hit)
		notified_peers.append(victim_peer)

	if attacker != null and is_instance_valid(attacker) and attacker.is_in_group("Player"):
		var attacker_peer = attacker.get_network_master()
		if !notified_peers.has(attacker_peer):
			_sendDamageTextToPeer(attacker_peer, damages, is_crit, is_penetrating_hit)
func _notifyAttackerDamageText(attacker:Node, damages:Dictionary, is_crit:bool, is_penetrating_hit:bool) -> void:
	if attacker == null or !is_instance_valid(attacker):
		return
	if !attacker.is_in_group("Player"):
		return
	if get_tree().network_peer == null:
		spawnDamageText(damages, is_crit, is_penetrating_hit)
		return

	var attacker_peer = attacker.get_network_master()
	if attacker_peer == get_tree().get_network_unique_id():
		spawnDamageText(damages, is_crit, is_penetrating_hit)
	else:
		rpc_id(attacker_peer, "clientShowDamageText", damages, is_crit, is_penetrating_hit)

remote func clientShowDamageText(damages:Dictionary, is_crit:bool, is_penetrating_hit:bool) -> void:
	spawnDamageText(damages, is_crit, is_penetrating_hit)




















func getDamagedFromDebuff(attacker:Node,debuff_name,damages:Dictionary,is_penetrating_hit:bool=false,extra_threat:float=0.0,is_crit:bool=false)->void:
	if attacker and (attacker.name=="Stats" or attacker.get_class()=="Node"):attacker=attacker.get_parent()

	if _shouldRouteThroughAuthority():
		rpc_id(_authorityId(), "requestGetDamagedFromDebuff", attacker.get_path() if attacker else NodePath(), debuff_name, damages, is_penetrating_hit, extra_threat, is_crit)
		return

	_applyDamagedFromDebuff(attacker,debuff_name,damages,is_penetrating_hit,extra_threat,is_crit)

#master func requestGetDamagedFromDebuff(attacker_path:NodePath, debuff_name, damages:Dictionary, is_penetrating_hit:bool, extra_threat:float, is_crit:bool) -> void:
#	var attacker = get_node_or_null(attacker_path) if attacker_path != NodePath() else null
#	_applyDamagedFromDebuff(attacker,debuff_name,damages,is_penetrating_hit,extra_threat,is_crit)
remote func requestGetDamagedFromDebuff(attacker_path:NodePath, debuff_name, damages:Dictionary, is_penetrating_hit:bool, extra_threat:float, is_crit:bool) -> void:
	if !get_tree().is_network_server():
		return
	var attacker = get_node_or_null(attacker_path) if attacker_path != NodePath() else null
	_applyDamagedFromDebuff(attacker,debuff_name,damages,is_penetrating_hit,extra_threat,is_crit)
func _applyDamagedFromDebuff(attacker:Node,debuff_name,damages:Dictionary,is_penetrating_hit:bool=false,extra_threat:float=0.0,is_crit:bool=false)->void:
	if attacker and (attacker.name=="Stats" or attacker.get_class()=="Node"):attacker=attacker.get_parent()
	parent.is_in_combat=true
	var facing_multiplier=1.0
	var total_damage=0.0
	var final_damages={}
	for dmg_type in damages:
		var damage=damages[dmg_type]
		var defence=0.0
		match dmg_type:
			damage_type.slash:defence=slash_defence
			damage_type.blunt:defence=blunt_defence
			damage_type.pierce:defence=pierce_defence
			damage_type.sonic:defence=sonic_defence
			damage_type.heat:defence=heat_defence
			damage_type.cold:defence=cold_defence
			damage_type.jolt:defence=jolt_defence
			damage_type.toxic:defence=toxic_defence
			damage_type.acid:defence=acid_defence
			damage_type.arcane:defence=arcane_defence
			damage_type.bleed:defence=bleed_defence
			damage_type.radiant:defence=radiant_defence
		var mitigation=calcMitigation(defence,attacker,is_penetrating_hit)
		if is_penetrating_hit:mitigation*=1.0-attacker.stats.derived_stats["penetration_power"]
		if Skills.skill_dmg_immunity.has(parent.current_skill):return
		var final_damage=damage*(1.0-mitigation)*facing_multiplier
		final_damages[dmg_type]=final_damage
		total_damage+=final_damage
	if !(parent.is_in_group("Player") or parent.is_in_group("player")) and attacker and attacker.is_in_group("Entity"):
		var instigatorAggro=parent.getAggro(attacker)
		var threat=total_damage*attacker.stats.derived_stats["threat"]+extra_threat
		instigatorAggro.aggro+=threat
		parent.shareAggro(parent.creator)
		for child in parent.spawned_bodies:
			parent.shareAggro(child)
			parent.getAggroFromOtherMob(child)
	var damage_multiplier=1.0
	if parent.current_skill=="flinch" or parent.anim_locks["knocked back"] or parent.anim_locks["knocked down"]:damage_multiplier=2.0
	elif (parent.current_skill=="guard" or parent.anim_locks["guard"]) and facing_multiplier==1.0:
		damage_multiplier=0.3
		parent.anim_locks["guard react"]=true
	total_damage=0.0
	for dmg_type in final_damages:
		final_damages[dmg_type]*=damage_multiplier
		total_damage+=final_damages[dmg_type]
	if attacker and "stored_body" in attacker:
		if parent and "stats" in parent and parent.stats.health>0:attacker.stored_body=parent
		else:attacker.stored_body=null
	if parent.is_in_group("Player") or (attacker and attacker.is_in_group("Player")):
		_broadcastDamageText(final_damages, is_crit, is_penetrating_hit, attacker)
	if parent.is_in_group("Player"):
		var chat=getChat(attacker)
		var victim_name=parent.entity_name
		if victim_name.strip_edges()=="":victim_name=(parent.get_node_or_null("Stats").species if parent.get_node_or_null("Stats") else "")
		var attacker_name=(attacker.entity_name if attacker else "null")
		if attacker:
			if attacker_name.strip_edges()=="":
				var astats=attacker.get_node_or_null("Stats")
				attacker_name=(astats.species if astats and astats.species!="" else "debuff")
		if chat and chat.has_method("sendSystemMessage"):
			chat.sendSystemMessage("%s took %s damage from %s %s"%[victim_name,dmgText(total_damage),attacker_name,debuff_name])
	if is_instance_valid($"../UI/Menu/CharacterBar"):$"../UI/Menu/CharacterBar".updateBars()
	updateBuffDebuffs()
	health-=total_damage
	getKilled()
	if attacker:
		var attacker_id=attacker.get_instance_id()
		if !damage_meter.has(attacker_id):damage_meter[attacker_id]={"attacker":attacker,"damage":0.0}
		damage_meter[attacker_id].damage+=total_damage
	parent.set_meta("last_hit_data",{"damage":total_damage,"flank":facing_multiplier==flank_dmg_multiplier,"backstab":facing_multiplier==backstab_dmg_multiplier,"victim":parent,"attacker":attacker})


func isAttackerInFront(attacker):
	if attacker==null:return false

	var direction=(attacker.global_transform.origin-parent.global_transform.origin).normalized()
	var facing:Vector3

	if parent.is_in_group("Player") or parent.is_in_group("player"):
		var character=parent.get_node_or_null("character")
		if character:facing=character.global_transform.basis.z.normalized()
		else:facing=parent.global_transform.basis.z.normalized()
	else:
		facing=parent.global_transform.basis.z.normalized()

	return facing.dot(direction)>=0.5

func isFacingSelf(attacker:Node,threshold:float)->bool:
	if attacker==null:return false

	var direction_to_self=(parent.global_transform.origin-attacker.global_transform.origin).normalized()
	var facing_direction:Vector3
	var direction_control=parent.get_node_or_null("character")

	if parent.is_in_group("Player") or parent.is_in_group("player"):
		if direction_control:facing_direction=-direction_control.global_transform.basis.z.normalized()
		else:facing_direction=-parent.global_transform.basis.z.normalized()
	else:
		facing_direction=-parent.global_transform.basis.z.normalized()

	return -facing_direction.dot(direction_to_self)>=threshold



func dmgText(v): return str(int(round(v)))

func getChat(n):
	if not n: return null
	var c=n.get_node_or_null("../UI/Chat")
	if c: return c
	return get_node_or_null("../UI/Chat")





func spreadAggroToFamily(attacker:Node,amount:float)->void:
	if attacker==null: return
	var creator=attacker.get("creator") if attacker.has_method("get") else null
	if is_instance_valid(creator):
		var g=parent.getAggro(creator)
		g.aggro+=amount
	if "spawned_bodies" in attacker:
		for b in attacker.spawned_bodies:
			if is_instance_valid(b):
				var g2=parent.getAggro(b)
				g2.aggro+=amount
				

func spawnHealText(heals: Dictionary) -> void:
	var text := "HEAL\n"

	for k in heals:
		text += str(int(round(heals[k]))) + "\n"

	var floating_res = CommonBehaviours.FloatingResScene.instance()
	floating_res.text = text.strip_edges()

	if parent.is_in_group("Player") or parent.is_in_group("player"):
		floating_res.use_screen_center = false
		var menu = $"../UI/Menu/CharacterBar/Control"
		if is_instance_valid(menu):
			menu.add_child(floating_res)
			return

	floating_res.use_screen_center = false
	var camera = get_viewport().get_camera()
	if camera:
		floating_res.world_position = camera.unproject_position(parent.global_transform.origin + Vector3.UP * 2.0)

	get_tree().root.add_child(floating_res)


func getHeal(source:Node,heal_amount:float)->void:
	if _shouldRouteThroughAuthority():
		rpc_id(_authorityId(), "requestGetHeal", source.get_path() if source else NodePath(), heal_amount)
		return

	_applyHeal(source, heal_amount)
func _sendHealTextToPeer(peer_id:int, heals:Dictionary) -> void:
	if get_tree().network_peer == null or peer_id == get_tree().get_network_unique_id():
		spawnHealText(heals)
	else:
		rpc_id(peer_id, "clientShowHealText", heals)

func _broadcastHealText(heals:Dictionary) -> void:
	if parent.is_in_group("Player"):
		_sendHealTextToPeer(parent.get_network_master(), heals)

remote func clientShowHealText(heals:Dictionary) -> void:
	spawnHealText(heals)
#master func requestGetHeal(source_path:NodePath, heal_amount:float) -> void:
#	var source = get_node_or_null(source_path) if source_path != NodePath() else null
#	_applyHeal(source, heal_amount)
remote func requestGetHeal(source_path:NodePath, heal_amount:float) -> void:
	if !get_tree().is_network_server():
		return
	var source = get_node_or_null(source_path) if source_path != NodePath() else null
	_applyHeal(source, heal_amount)
func _applyHeal(source:Node,heal_amount:float)->void:
	var total_heal=heal_amount
	if source and source.is_in_group("Entity") and source.has_node("Stats"):
		total_heal*=1.0+(getTotalAttribute("vitality")*0.05)

	if parent.is_in_group("Player"):
		if parent.movement_mode=="crawling":
			health+=total_heal*0.3
			parent.is_downed=false
			parent.is_dead=false
		elif parent.is_downed:
			health+=total_heal*0.3
			parent.anim_locks["get up"]=true
			parent.animation_tree.active=true
			parent.is_downed=false
			parent.is_dead=false
		else:
			health+=total_heal
	else:
		health+=total_heal

	if health>max_health: health=max_health

	var is_self=(source==parent)

	if parent.is_in_group("Player"):
		_broadcastHealText({"heal":total_heal})
		var chat=get_node_or_null("../UI/Chat")
		if chat and chat.has_method("sendSystemMessage"):
			var msg=""
			if is_self:
				msg="self healing "+str(int(round(total_heal)))
			else:
				var src="unknown"
				if source:
					src=source.entity_name if "entity_name" in source else "entity"
					if src=="" or src==" " or src=="nameless":
						var sstats=source.get_node_or_null("Stats")
						if sstats and sstats.species!="": src=sstats.species
						else: src="unknown"
				msg=src+" healed "+parent.entity_name+" "+str(int(round(total_heal)))
			chat.sendSystemMessage(msg)
		if is_instance_valid($"../UI/Menu/CharacterBar"):
			$"../UI/Menu/CharacterBar".updateBars()
	elif source and source.is_in_group("Player"):
		var floating_res=CommonBehaviours.FloatingResScene.instance()
		if floating_res:
			floating_res.text="HEAL\n"+str(int(round(total_heal)))
			floating_res.use_screen_center=false
			var crosshair=$"../UI/CrossairInspect"
			if is_instance_valid(crosshair):
				crosshair.add_child(floating_res)


func calcMitigation(defence:float,attacker:Node,is_penetrating_hit:bool)->float:
	var pen=0.0
	if is_penetrating_hit:pen=attacker.stats.derived_stats["penetration_power"]
	defence*=1.0-pen

	if defence>=0.0:
		return defence/(defence+45.0)

	var k=-defence/100.0
	return -k/(k+1.0)

func calcMitigationRaw(defence:float)->float:
	if defence>=0.0:
		return defence/(defence+45.0)
	var k=-defence/100.0
	return -k/(k+1.0)


func mitPercent(defence:float)->float:
	var mit=calcMitigationRaw(defence)*100.0
	return clamp(float(int(mit*100.0))/100.0,-100.0,100.0)






func getReleased()->void:
	Skills.setAnimLock(parent,"flinch",false)
	Skills.setAnimLock(parent,"knocked down",false)
	Skills.setAnimLock(parent,"knocked back",false)
	parent.has_anim_lock = false


func selfBuff():
	var skill_name = parent.current_skill
	if Skills != null and Skills.status_effects is Dictionary and Skills.status_effects.has(skill_name):
		if Skills.status_effects[skill_name] is Dictionary:
			for status_name in Skills.status_effects[skill_name]:
				if isBeneficialStatus(skill_name):
					applyBuffDebuff(skill_name,parent)
						
						
						
					
func getKilled():
	if health <=0:
		purify()
		exhaust()
		if parent.is_in_group("Entity"):
			if parent.is_in_group("Player"):
				if health <=0:
					if parent.is_dead == false:
						Skills.setAnimLock(parent,"downed",true)
						parent.is_downed = true



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





var experience_points:int = 0
var level:int = 0

func levelingSystem():
	if get_tree().network_peer != null and !isAuthority():
		return
	while experience_points>=250*(1.0+pow(level/10.0,1.5)):
		experience_points-=int(round(250.0*(1.0+pow(level/10.0,1.5))))
		level+=1
		available_attribute_points+=1
		skill_points += 1

func getExperience(experienceToGain:int):
	if get_tree().network_peer != null and !isAuthority():
		return
	experience_points+=experienceToGain
	levelingSystem()
	if parent.is_in_group("Player"):
		parent.chat.sendSystemMessage("gained " + str(experienceToGain) + " experience")

var available_attribute_points:int = 10

func resetAttributePoints():
	available_attribute_points=10+level
	for key in attribute_points_spent:
		attribute_points_spent[key]=0

func regenerate(value, resource, max_resource):
	return min(resource + value, max_resource)
		



