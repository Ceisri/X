extends Node#Stats script, on a node called Stats, direct child of every npc and every player








const species_data= {
	"human": {
		"male": { "base_max_health":100,"base_max_energy":100,"base_max_arcane":100,"base_walk_speed":4,"base_run_speed":8,
			"attributes":{"strength":1.0,"power":1.0,"impact":1.1,"balance":1.0,"agility":1.0,"dexterity":1.02,"vitality":1.0,"toughness":1.0,"instinct":1.0,"perception":1.0,"intelligence":1.0,"wisdom":1.0,"haste":1.0,"charisma":1.0,"authority":1.0},
			"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":0,"radiant":0},
			"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
			"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":0,"radiant":0},
			"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1}
		},
		"female": { "base_max_health":100,"base_max_energy":100,"base_max_arcane":100,"base_walk_speed":4,"base_run_speed":10,
			"attributes":{"strength":1.0,"power":1.0,"impact":0.95,"balance":1.05,"agility":1.1,"dexterity":1.0,"vitality":1.0,"toughness":0.95,"instinct":0.85,"perception":0.85,"intelligence":1.0,"wisdom":1.0,"haste":1.00,"charisma":1.2,"authority":1.0},
			"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":0,"radiant":0},
			"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
			"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":0,"radiant":0},
			"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1}
		}
	},
"kragun": { "base_max_health":250,"base_max_energy":110,"base_max_arcane":80,"base_walk_speed":3.3,"base_run_speed":7.5,
	"attributes":{"strength":1.08,"power":1.0,"impact":1.08,"balance":1.1,"agility":0.92,"dexterity":0.92,"vitality":1.08,"toughness":1.1,"instinct":1.0,"perception":0.92,"intelligence":0.95,"wisdom":0.95,"haste":0.9,"charisma":0.9,"authority":1.05},
	"flat_defence_bonus":{"slash":25,"blunt":85,"pierce":20,"sonic":-5,"heat":0,"cold":10,"jolt":0,"toxic":5,"acid":5,"arcane":0,"bleed":30,"radiant":0},
	"defence_mult":{"slash":1.15,"blunt":1.35,"pierce":1.1,"sonic":1.1,"heat":1,"cold":1.05,"jolt":1,"toxic":1.05,"acid":1.05,"arcane":1,"bleed":1.25,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":5,"pierce":10,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":8,"radiant":0},
	"damage_mult":{"slash":1.1,"blunt":1.25,"pierce":1.35,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1.15,"radiant":1}
},
	
	
"mudclaw": { "base_max_health":600,"base_max_energy":80,"base_max_arcane":0,"base_walk_speed":2.2,"base_run_speed":4.7,
	"attributes":{"strength":0.95,"power":1.08,"impact":1,"balance":1,"agility":1,"dexterity":1.0,"vitality":1.0,"toughness":0.95,"instinct":1.08,"perception":1.05,"intelligence":1.05,"wisdom":1.08,"haste":1.0,"charisma":1.0,"authority":0.95},
	"flat_defence_bonus":{"slash":30,"blunt":30,"pierce":30,"sonic":15,"heat":-35,"cold":5,"jolt":-25,"toxic":5,"acid":5,"arcane":-15,"bleed":5,"radiant":400},
	"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":0,"radiant":0},
	"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1}
},
	
"plantera": { "base_max_health":85,"base_max_energy":180,"base_max_arcane":220,"base_walk_speed":3.6,"base_run_speed":7.5,
	"attributes":{"strength":0.95,"power":1.08,"impact":0.95,"balance":0.95,"agility":1.05,"dexterity":1.0,"vitality":1.0,"toughness":0.95,"instinct":1.08,"perception":1.05,"intelligence":1.05,"wisdom":1.08,"haste":1.0,"charisma":1.0,"authority":0.95},
	"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":15,"heat":-35,"cold":-25,"jolt":0,"toxic":80,"acid":50,"arcane":15,"bleed":40,"radiant":100},
	"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":5,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":20,"acid":0,"arcane":0,"bleed":0,"radiant":0},
	"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1}
},

"rosatera": { "base_max_health":90,"base_max_energy":185,"base_max_arcane":210,"base_walk_speed":3.6,"base_run_speed":6,
	"attributes":{"strength":0.95,"power":1.06,"impact":0.95,"balance":0.95,"agility":1.06,"dexterity":1.02,"vitality":1.02,"toughness":0.95,"instinct":1.08,"perception":1.04,"intelligence":1.05,"wisdom":1.06,"haste":1.02,"charisma":1.06,"authority":0.95},
	"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":5,"heat":-30,"cold":-20,"jolt":0,"toxic":90,"acid":55,"arcane":10,"bleed":45,"radiant":90},
	"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":5,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":25,"acid":5,"arcane":0,"bleed":0,"radiant":0},
	"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1}
},

"azultera": { "base_max_health":85,"base_max_energy":175,"base_max_arcane":235,"base_walk_speed":3.5,"base_run_speed":6,
	"attributes":{"strength":0.94,"power":1.09,"impact":0.94,"balance":0.96,"agility":1.04,"dexterity":1.0,"vitality":0.98,"toughness":0.96,"instinct":1.05,"perception":1.06,"intelligence":1.07,"wisdom":1.1,"haste":0.98,"charisma":0.98,"authority":0.96},
	"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":1,"heat":-20,"cold":15,"jolt":5,"toxic":70,"acid":45,"arcane":30,"bleed":35,"radiant":100},
	"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":5,"sonic":0,"heat":0,"cold":0,"jolt":5,"toxic":15,"acid":0,"arcane":10,"bleed":0,"radiant":0},
	"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1}
},

"embertera": { "base_max_health":90,"base_max_energy":175,"base_max_arcane":210,"base_walk_speed":3.7,"base_run_speed":6,
	"attributes":{"strength":1.0,"power":1.05,"impact":1.0,"balance":0.96,"agility":1.05,"dexterity":1.0,"vitality":1.04,"toughness":1.0,"instinct":1.07,"perception":1.02,"intelligence":1.02,"wisdom":1.04,"haste":1.02,"charisma":1.0,"authority":0.96},
	"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":5,"heat":25,"cold":-45,"jolt":0,"toxic":75,"acid":55,"arcane":10,"bleed":40,"radiant":80},
	"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":5,"sonic":0,"heat":10,"cold":0,"jolt":0,"toxic":20,"acid":5,"arcane":0,"bleed":0,"radiant":0},
	"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1}
},

"virelia": { "base_max_health":135,"base_max_energy":500,"base_max_arcane":230,"base_walk_speed":3.5,"base_run_speed":6,
	"attributes":{"strength":0.94,"power":1.09,"impact":0.94,"balance":0.94,"agility":1.03,"dexterity":1.02,"vitality":0.98,"toughness":0.94,"instinct":1.1,"perception":1.06,"intelligence":1.08,"wisdom":1.09,"haste":1.0,"charisma":1.02,"authority":0.96},
	"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":10,"heat":0,"cold":0,"jolt":5,"toxic":200,"acid":70,"arcane":25,"bleed":40,"radiant":200},
	"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":5,"sonic":0,"heat":0,"cold":0,"jolt":5,"toxic":30,"acid":15,"arcane":10,"bleed":0,"radiant":0},
	"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1}
},

	
"forest spider": { "base_max_health":120,"base_max_energy":300,"base_max_arcane":100,"base_walk_speed":2.6,"base_run_speed":8,
	"attributes":{"strength":1.0,"power":1.0,"impact":1.9,"balance":3.3,"agility":0.9,"dexterity":1.1,"vitality":1.8,"toughness":1.7,"instinct":1.5,"perception":1.3,"intelligence":0.4,"wisdom":0.3,"haste":1.1,"charisma":0.1,"authority":0.2},
	"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":2,"acid":2,"arcane":0,"bleed":0,"radiant":0},
	"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.2,"acid":1.2,"arcane":1,"bleed":1,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":2,"acid":2,"arcane":0,"bleed":1,"radiant":0},
	"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.25,"acid":1.25,"arcane":1,"bleed":1.1,"radiant":1}
},
"spiderling": { "base_max_health":75,"base_max_energy":1000,"base_max_arcane":100,"base_walk_speed":2,"base_run_speed":12,
	"attributes":{"strength":1.0,"power":1.0,"impact":0.4,"balance":1.0,"agility":2.6,"dexterity":1.5,"vitality":0.6,"toughness":0.5,"instinct":5.0,"perception":1.3,"intelligence":0.2,"wisdom":0.0,"haste":1.6,"charisma":0.0,"authority":0.0},
	"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":1,"acid":1,"arcane":0,"bleed":0,"radiant":0},
	"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.1,"acid":1.1,"arcane":1,"bleed":1,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":1,"acid":1,"arcane":0,"bleed":0,"radiant":0},
	"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.15,"acid":1.15,"arcane":1,"bleed":1,"radiant":1}
},
"mole spider": { "base_max_health":150,"base_max_energy":90,"base_max_arcane":100,"base_walk_speed":2.6,"base_run_speed":7,
	"attributes":{"strength":1.0,"power":1.0,"impact":5.4,"balance":1.0,"agility":1.0,"dexterity":1.5,"vitality":1.0,"toughness":1.0,"instinct":2.4,"perception":1.8,"intelligence":0.5,"wisdom":0.3,"haste":3.66,"charisma":0.0,"authority":0.4},
	"flat_defence_bonus":{"slash":0,"blunt":30,"pierce":0.3,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0.5,"acid":0.2,"arcane":0,"bleed":0,"radiant":0},
	"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.15,"acid":1.15,"arcane":1,"bleed":1,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":6,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":6,"acid":2,"arcane":0,"bleed":1,"radiant":0},
	"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.2,"acid":1.2,"arcane":1,"bleed":1.1,"radiant":1}
},
"sea spider": { "base_max_health":110,"base_max_energy":150,"base_max_arcane":100,"base_walk_speed":2.6,"base_run_speed":9,
	"attributes":{"strength":1.0,"power":1.5,"impact":1.4,"balance":1.0,"agility":1.2,"dexterity":1.5,"vitality":1.0,"toughness":1.0,"instinct":3.4,"perception":1.8,"intelligence":1,"wisdom":1,"haste":1,"charisma":0.2,"authority":0.4},
	"flat_defence_bonus":{"slash":10,"blunt":30,"pierce":10,"sonic":10,"heat":0,"cold":50,"jolt":-15,"toxic":0,"acid":0.0,"arcane":0,"bleed":30,"radiant":30},
	"defence_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":3,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":12,"acid":2,"arcane":0,"bleed":1,"radiant":0},
	"damage_mult":{"slash":1,"blunt":1,"pierce":1,"sonic":1,"heat":1,"cold":1,"jolt":1,"toxic":1.2,"acid":1.2,"arcane":1,"bleed":1.1,"radiant":1}
},
"wyvern": { "base_max_health":850,"base_max_energy":1000,"base_max_arcane":1000,"base_walk_speed":5.8,"base_run_speed":6,
	"attributes":{"strength":1.4,"power":1.4,"impact":1.5,"balance":1.0,"agility":1.0,"dexterity":1.0,"vitality":1.3,"toughness":1.3,"instinct":1.0,"perception":1.0,"intelligence":1.0,"wisdom":1.0,"haste":1.0,"charisma":0.8,"authority":1.2},
	"flat_defence_bonus":{"slash":8,"blunt":6,"pierce":8,"sonic":0,"heat":120,"cold":2,"jolt":0,"toxic":3,"acid":3,"arcane":0,"bleed":4,"radiant":0},
	"defence_mult":{"slash":1.1,"blunt":1.05,"pierce":1.1,"sonic":1,"heat":1.3,"cold":1,"jolt":1,"toxic":1.1,"acid":1.1,"arcane":1,"bleed":1.05,"radiant":1},
	"flat_damage_bonus":{"slash":20,"blunt":12,"pierce":18,"sonic":0,"heat":5,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":8,"radiant":0},
	"damage_mult":{"slash":1.15,"blunt":1.1,"pierce":1.15,"sonic":1,"heat":1.35,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1.1,"radiant":1}
},
"mountain wyvern": { "base_max_health":1250,"base_max_energy":2000,"base_max_arcane":2000,"base_walk_speed":6.8,"base_run_speed":6,
	"attributes":{"strength":1.4,"power":1.4,"impact":1.5,"balance":1.2,"agility":1.0,"dexterity":1.2,"vitality":1.5,"toughness":1.3,"instinct":1.0,"perception":1.0,"intelligence":1.0,"wisdom":1.0,"haste":1.0,"charisma":0.8,"authority":1.2},
	"flat_defence_bonus":{"slash":8,"blunt":6,"pierce":8,"sonic":0,"heat":30,"cold":350,"jolt":0,"toxic":3,"acid":3,"arcane":0,"bleed":4,"radiant":0},
	"defence_mult":{"slash":1.1,"blunt":1.05,"pierce":1.1,"sonic":1,"heat":1.3,"cold":1.5,"jolt":1,"toxic":1.1,"acid":1.1,"arcane":1,"bleed":1.05,"radiant":1},
	"flat_damage_bonus":{"slash":20,"blunt":12,"pierce":18,"sonic":0,"heat":0,"cold":15,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":8,"radiant":0},
	"damage_mult":{"slash":1.15,"blunt":1.1,"pierce":1.15,"sonic":1,"heat":1.35,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1.1,"radiant":1}
},
"behemoth toad": { "base_max_health":125,"base_max_energy":55,"base_max_arcane":100,"base_walk_speed":2,"base_run_speed":3.8,
	"attributes":{"strength":0.5,"power":1.0,"impact":1,"balance":0.8,"agility":1.0,"dexterity":1.0,"vitality":1,"toughness":1,"instinct":1.0,"perception":1.0,"intelligence":1.0,"wisdom":1.0,"haste":1.0,"charisma":0.0,"authority":0.0},
	"flat_defence_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":100,"acid":0,"arcane":0,"bleed":0,"radiant":0},
	"defence_mult":{"slash":0.5,"blunt":0.5,"pierce":0.25,"sonic":0,"heat":1,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1,"radiant":1},
	"flat_damage_bonus":{"slash":0,"blunt":0,"pierce":0,"sonic":0,"heat":0,"cold":0,"jolt":0,"toxic":0,"acid":0,"arcane":0,"bleed":0,"radiant":0},
	"damage_mult":{"slash":1.0,"blunt":1.0,"pierce":1.0,"sonic":1.0,"heat":1.0,"cold":1,"jolt":1,"toxic":1,"acid":1,"arcane":1,"bleed":1.1,"radiant":1.0}
}
}
export var weight:int = 100
export var max_energy:int  = 9999999999
var energy:int = 9999999999

export var max_health:int = 9999999999
var health:int = 9999999999

var max_arcane:int = 9999999999
var arcane:int = max_arcane
var _last_regen_ms:int = 0
export var max_regen_catchup_seconds:float = 600.0

# ============================================================
# NETWORKING
# Stats exists on every peer for every Player and every NPC, same
# as today. But only the entity's network master may compute
# combat, buffs, and regen -- everyone else just mirrors the
# numbers the master broadcasts. This mirrors exactly how
# Player.gd already splits movement into master/puppet.
# ============================================================
#func isAuthority() -> bool:
#	if isParentPlayer():
#		return get_tree().network_peer == null or get_tree().is_network_server()
#	return parent.is_network_master()
func isAuthority() -> bool:
	if get_tree().network_peer == null:
		return true # no multiplayer session running -> everyone is authoritative, players and mobs alike
	if isParentPlayer():
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
	experience_points = net_experience_points
	level = net_level
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

	# walk_speed/run_speed/attack multipliers/defence values are never
	# part of the net_* sync payload -- they're pure functions of
	# `attributes` (just synced above) plus the species/equipment tables
	# that are already correct locally on every peer. Recompute them here
	# so a client's own puppet copy of itself actually reflects its species,
	# instead of sitting on class defaults.
	for dmg_type in defences:
		defences[dmg_type] = getTotalAttribute("toughness") * 2.0
	updateCombatAttributes()


func _ready():
	applySpecies()
	rebuildOnHitEffects()
	if isParentPlayer():
		loadData()
		if parent.is_in_group("BOT"):
			_last_regen_ms = OS.get_ticks_msec()
	else:
		call_deferred("_deferredLoadMobStatsStaggered")

func _deferredLoadMobStatsStaggered() -> void:
	while !Global.canLoadMobStatsThisFrame():
		yield(get_tree(), "idle_frame")
	if !is_instance_valid(self):
		return
	loadData()
	_deferredInitialUpdateAttributes()



func _deferredInitialUpdateAttributes() -> void:
	updateAttributes()




var species_attributes := {}
#applySpecies() must run before
#loadData()/_applyStatsSnapshotInternal()
# populate species_attributes — that's already the existing 
#call order (_ready(): applySpecies() → loadData(); ApplySex(): stats.applySpecies()
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
	species_attributes.clear()
	for k in a:
		species_attributes[k] = float(a[k])
		attributes[k] = species_attributes[k]

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



var _is_parent_player_cached := false
var _parent_group_cache_valid := false
func isParentPlayer() -> bool:
	if !_parent_group_cache_valid:
		_is_parent_player_cached = parent.is_in_group("Player")
		_parent_group_cache_valid = true
	return _is_parent_player_cached




onready var parent = $".."


# Exported variables
export var species: String = "species"
export var mob_type:String = "default"
export var sex: String = "male"








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
	"arcane_regeneration": 1.0,
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

func regenerations(dt:float=1.0)->void:
	if get_tree().network_peer != null and !isAuthority():
		return
	if parent.is_in_group("BOT"):
		regenerationsBot()
	else:
		if health > (max_health * 0.15):
			health = regenerate(derived_stats["health_regeneration"]*dt,health,max_health)
			energy = regenerate(derived_stats["energy_regeneration"]*dt,energy,max_energy)
			arcane = regenerate(derived_stats.get("arcane_regeneration",1.0)*dt,arcane,max_arcane)
			
func regenerationsBot()->void:
	if get_tree().network_peer != null and !isAuthority():
		return
	var now_ms:int = OS.get_ticks_msec()
	if _last_regen_ms == 0:
		_last_regen_ms = now_ms
		return
	var elapsed_seconds:float = float(now_ms - _last_regen_ms) / 1000.0
	_last_regen_ms = now_ms
	if elapsed_seconds <= 0.0:
		return
	elapsed_seconds = min(elapsed_seconds, max_regen_catchup_seconds)

	health = regenerateRealTime(derived_stats["health_regeneration"],health,max_health,elapsed_seconds)
	energy = regenerateRealTime(derived_stats["energy_regeneration"],energy,max_energy,elapsed_seconds)
	arcane = regenerateRealTime(derived_stats.get("arcane_regeneration",1.0),arcane,max_arcane,elapsed_seconds)
	
	
func regenerateRealTime(rate_per_second, resource, max_resource, elapsed_seconds) -> float:
	return min(resource + rate_per_second * elapsed_seconds, max_resource)





const ATTRIBUTE_STEP:float = 0.05
const MIN_ATTRIBUTE:float = 0.25
func getSaveDirectory() -> String:
	if isParentPlayer():
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
		"skill_points": skill_points,
		"used_skill_points": used_skill_points,
	}



var _stats_stable := true # kept for MobSync's stats_stable check; always true now

func reapplyLoadedStatsAfterDelay() -> void:
	var last_max_health = max_health
	var last_max_energy = max_energy
	var last_max_arcane = max_arcane
	for wait_time in [1.0, 2.0, 3.0, 5.0, 8.0, 12.0]:
		yield(get_tree().create_timer(wait_time), "timeout")
		if !is_instance_valid(self) or _post_load_snapshot.empty():
			_stats_stable = true
			return
		forceReapplySnapshot(last_max_health, last_max_energy, last_max_arcane)
		last_max_health = max_health
		last_max_energy = max_energy
		last_max_arcane = max_arcane
	_post_load_guard = false
	_stats_stable = true

func forceReapplySnapshot(prev_max_health:float, prev_max_energy:float, prev_max_arcane:float) -> void:
	# Only rescale if max_health/energy/arcane actually changed since the
	# last tick (equipment/attributes just finished settling). If nothing
	# changed, this is a no-op -- it must NEVER reimpose the original
	# save-file ratio, or any healing/damage that happened since load gets
	# silently undone (this was the "heals up, then drops 2-3 times" bug).
	if is_equal_approx(max_health, prev_max_health) and is_equal_approx(max_energy, prev_max_energy) and is_equal_approx(max_arcane, prev_max_arcane):
		return

	var health_ratio = health / prev_max_health if prev_max_health > 0 else 1.0
	var energy_ratio = energy / prev_max_energy if prev_max_energy > 0 else 1.0
	var arcane_ratio = arcane / prev_max_arcane if prev_max_arcane > 0 else 1.0

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

	if isParentPlayer():
		var bar = get_node("../UI/Menu/CharacterBar")
		if is_instance_valid(bar):
			bar.updateBars()

	

func applyStatsSnapshotAuthority(data: Dictionary) -> void:
	_applyStatsSnapshotInternal(data)
	_resetRestoredBuffTimers()
	_post_load_snapshot = data.duplicate(true)
	_post_load_guard = true
	_stats_stable = false
	reapplyLoadedStatsAfterDelay()

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
	reapplyLoadedStatsAfterDelay()

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


func wakeMobIfNeeded() -> void:
	if parent == null or !is_instance_valid(parent):
		return
	if "sleeping" in parent:
		parent.sleeping = false
	if "_is_relevant" in parent and !parent._is_relevant:
		parent._is_relevant = true
		if is_instance_valid(Global):
			Global.markActive(parent)
	if "is_frozen" in parent and parent.is_frozen and parent.has_method("unfreezeMob"):
		parent.unfreezeMob()
	if "animation_tree" in parent and is_instance_valid(parent.animation_tree) and !parent.animation_tree.active and !("is_dead" in parent and parent.is_dead):
		parent.animation_tree.active = true

var _statsUpdateOffset:int = -1

func _physics_process(_delta)->void:
	statsPhyProcess()
	
	
var stats_proximity_check_range:float = 15.0
func statsPhyProcess()->void:
	var frame:int = Engine.get_physics_frames()
	if frame == _last_processed_visual_frame:
		return
	_last_processed_visual_frame = frame

	if !isParentPlayer() and !parent.is_in_combat:
		if (frame + _statsUpdateOffset) % 30 == 0:
			if !isPlayerNearby():
				return
	if _statsUpdateOffset == -1:
		_statsUpdateOffset = int(get_instance_id() % 60)
	if !isParentPlayer() and isAuthority() and parent.has_method("isRelevantForSync") and !parent.isRelevantForSync():
		return
	if get_tree().network_peer != null and !isAuthority():
		_applyPuppetStats()
		if (frame + _statsUpdateOffset) % 30 == 0 and isParentPlayer() and isLocalOwner():
			updateStatusGridIfChanged(player_status_grid, self)
		if (frame + _statsUpdateOffset) % 60 == 0 and isParentPlayer() and !parent.is_in_group("BOT") and isLocalOwner() and is_instance_valid(bar):
			bar.updateBars()
		return
	if (frame + _statsUpdateOffset) % 30 == 0 and isParentPlayer() and isLocalOwner():
		updateStatusGridIfChanged(player_status_grid, self)
	if (frame + _statsUpdateOffset) % 60 == 0:
		var had_buffs: bool = !debuff_buffs_active.empty()
		if had_buffs:
			tickBuffsDebuffs()
		var buffs_changed_now: bool = had_buffs != (not debuff_buffs_active.empty())
		if _stats_dirty or buffs_changed_now:
			updateBuffDebuffs()
			updateAttributes()
			_stats_dirty = false
		if health <= 0:
			purify()
			exhaust()
		else:
			if !parent.is_in_combat:
				regenerations()
		_pushStatsToOwner()
		if isParentPlayer() and !parent.is_in_group("BOT") and isLocalOwner() and is_instance_valid(bar):
			bar.updateBars()
	_syncStatsToPuppets(get_physics_process_delta_time())






var _last_processed_visual_frame:int = -1
var _cachedStatsWorld: Node = null
func getCachedStatsWorld() -> Node:
	if _cachedStatsWorld != null and is_instance_valid(_cachedStatsWorld):
		return _cachedStatsWorld
	var node = parent.get_parent()
	while node:
		if "world_id" in node:
			_cachedStatsWorld = node
			return node
		node = node.get_parent()
	return null

func isPlayerNearby() -> bool:
	if !("global_transform" in parent):
		return false
	var world = getCachedStatsWorld()
	if !is_instance_valid(world):
		return false
	for node in Global.queryRadius(world.world_id, parent.global_transform.origin, stats_proximity_check_range):
		if is_instance_valid(node) and node.is_in_group("Player"):
			return true
	return false











# BUG AT SCALE: puppet_payload was rpc_id'd to EVERY connected peer,
# for EVERY player's Stats node, once per second. That's O(players^2)
# RPCs/sec -- at 100 players that's 9900 RPCs every single second just
# for puppet HP ticks, regardless of who's actually near who. This is
# the single biggest thing that will not scale past a handful of players.
#
# FIX: only push to peers whose own player is in the SAME world AND
# within stats_push_aoi_radius of this player. Distant/other-world
# peers don't need your HP number updated every second.

export var stats_push_aoi_radius := 100.0
func _pushStatsToOwner() -> void:
	if !isParentPlayer():
		return
	if get_tree().network_peer == null or !get_tree().is_network_server():
		return

	net_health = health
	net_max_health = max_health
	net_energy = energy
	net_max_energy = max_energy
	net_arcane = arcane
	net_max_arcane = max_arcane
	net_is_dead = ("is_dead" in parent) and parent.is_dead
	net_statuses = statuses.duplicate(true)
	net_debuff_buffs_active = debuff_buffs_active.duplicate(true)
	net_attributes = attributes.duplicate(true)
	net_derived_stats = derived_stats.duplicate(true)
	net_available_attribute_points = available_attribute_points

	var is_downed_now = ("is_downed" in parent) and parent.is_downed
	var owner_peer = parent.get_network_master()

	var puppet_payload := {
		"health": health, "max_health": max_health,
		"energy": energy, "max_energy": max_energy,
		"arcane": arcane, "max_arcane": max_arcane,
		"is_dead": net_is_dead,
		"is_downed": is_downed_now,
		"statuses": net_statuses,
		"debuff_buffs_active": net_debuff_buffs_active,
	}

	var my_world_id := ""
	var w = parent.get_parent()
	if is_instance_valid(w) and "world_id" in w:
		my_world_id = w.world_id
	var origin = parent.global_transform.origin

	if my_world_id != "":
		var notified := {}
		for node in Global.queryRadius(my_world_id, origin, stats_push_aoi_radius):
			if !is_instance_valid(node) or !node.is_in_group("Player") or node.is_in_group("BOT") or node == parent:
				continue
			var other_peer = node.get_network_master()
			if other_peer == owner_peer or notified.has(other_peer):
				continue
			notified[other_peer] = true
			rpc_id(other_peer, "receivePuppetStatsPush", puppet_payload)

	if owner_peer == get_tree().get_network_unique_id():
		return

	rpc_id(owner_peer, "receiveStatsPush", {
		"health": health, "max_health": max_health,
		"energy": energy, "max_energy": max_energy,
		"arcane": arcane, "max_arcane": max_arcane,
		"attributes": attributes.duplicate(true),
		"attribute_points_spent": attribute_points_spent.duplicate(true),
		"available_attribute_points": available_attribute_points,
		"derived_stats": derived_stats.duplicate(true),
		"is_dead": net_is_dead,
		"is_downed": is_downed_now,
		"statuses": net_statuses,
		"debuff_buffs_active": net_debuff_buffs_active,
	})
# New: puppet-side receiver for the broadcast above. Never touches
# attributes/derived_stats (owner-only, full-fidelity data) -- only the
# subset other clients need to render this player correctly.
remote func receivePuppetStatsPush(data:Dictionary) -> void:
	if parent.has_method("isLocalPlayer") and parent.isLocalPlayer():
		return # this is the owner's own copy, receiveStatsPush handles it
	net_health = data.get("health", net_health)
	net_max_health = data.get("max_health", net_max_health)
	net_energy = data.get("energy", net_energy)
	net_max_energy = data.get("max_energy", net_max_energy)
	net_arcane = data.get("arcane", net_arcane)
	net_max_arcane = data.get("max_arcane", net_max_arcane)
	net_is_dead = data.get("is_dead", net_is_dead)
	net_statuses = data.get("statuses", net_statuses)
	net_debuff_buffs_active = data.get("debuff_buffs_active", net_debuff_buffs_active)
	_has_received_stats_sync = true

	if parent.has_method("applyPuppetDownedState"):
		parent.applyPuppetDownedState(bool(data.get("is_downed", false)))
var _pending_ratio_reassert := {}
export var ratio_reassert_max_frames := 300   # ~5s hard cap fallback
export var ratio_reassert_settle_frames := 30 # keep correcting this long after equipment looks ready
var _ratio_reassert_elapsed := 0
var _equipment_ready_streak := 0





func _isEquipmentReady() -> bool:
	if !isParentPlayer():
		return true
	var equipment = parent.get_node("UI/Equipment")
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

	if isParentPlayer():
		if is_instance_valid(bar):
			bar.updateBars()

	var done = _equipment_ready_streak >= ratio_reassert_settle_frames or _ratio_reassert_elapsed >= ratio_reassert_max_frames
	if done:
		_pending_ratio_reassert = {}
		_stats_stable = true









onready var bar = get_node_or_null("../UI/Menu/CharacterBar")
remote func receiveStatsPush(data:Dictionary) -> void:
	if !parent.has_method("isLocalPlayer") or !parent.isLocalPlayer():
		return
	health = data.get("health", health)
	max_health = data.get("max_health", max_health)
	energy = data.get("energy", energy)
	max_energy = data.get("max_energy", max_energy)
	arcane = data.get("arcane", arcane)
	max_arcane = data.get("max_arcane", max_arcane)
	if data.has("attributes"):
		for k in attributes.keys():
			if data["attributes"].has(k):
				attributes[k] = float(data["attributes"][k])
	if data.has("attribute_points_spent"):
		for k in attribute_points_spent.keys():
			if data["attribute_points_spent"].has(k):
				attribute_points_spent[k] = int(data["attribute_points_spent"][k])
	if data.has("available_attribute_points"):
		available_attribute_points = data["available_attribute_points"]
	if data.has("derived_stats"):
		derived_stats = data["derived_stats"].duplicate(true)
	if data.has("statuses"):
		statuses = data["statuses"].duplicate(true)
	if data.has("debuff_buffs_active"):
		debuff_buffs_active = data["debuff_buffs_active"].duplicate(true)
	if "is_dead" in parent and data.has("is_dead"):
		parent.is_dead = data["is_dead"]

	# Clear EVERY other lock before setting downed -- otherwise whichever
	# lock (guard, combo attack, etc.) happened to still be true at the
	# moment of death wins the dict-order scan in getActiveAnimLock()
	# over "downed", since it iterates and returns the first true key.
	# That's what caused freezing mid-animation or reverting to downed
	# unpredictably depending on what the player was doing when they died.
	if data.has("is_downed") and "anim_locks" in parent:
		var now_downed = bool(data["is_downed"])
		var was_downed = bool(parent.anim_locks.get("downed", false))
		if now_downed and !was_downed:
			for key in parent.anim_locks.keys():
				parent.anim_locks[key] = false
			parent.anim_locks["downed"] = true
			parent.current_skill = "downed"
			if "last_active_skill" in parent:
				parent.last_active_skill = ""
			if "root_motion_active" in parent:
				parent.root_motion_active = false
			if "is_downed" in parent:
				parent.is_downed = true
		elif !now_downed and was_downed:
			parent.anim_locks["downed"] = false
			if "is_downed" in parent:
				parent.is_downed = false
			if "revive_lock_until_ms" in parent:
				parent.revive_lock_until_ms = OS.get_ticks_msec() + 3000
			if parent.has_method("startGetUpSequence"):
				parent.startGetUpSequence()

	net_health = health
	net_max_health = max_health
	net_energy = energy
	net_max_energy = max_energy
	net_arcane = arcane
	net_max_arcane = max_arcane
	net_is_dead = ("is_dead" in parent) and parent.is_dead
	net_statuses = statuses.duplicate(true)
	net_debuff_buffs_active = debuff_buffs_active.duplicate(true)
	net_attributes = attributes.duplicate(true)
	net_derived_stats = derived_stats.duplicate(true)
	net_attribute_points_spent = attribute_points_spent.duplicate(true)
	net_available_attribute_points = available_attribute_points

	markAttributeCacheDirty()
	_has_received_stats_sync = true
	if is_instance_valid(bar):
		bar.updateBars()
	updateStatusGridIfChanged(player_status_grid, self)



func _applyStatsSnapshotInternal(data: Dictionary) -> void:
	if data.empty():
		return

	var saved_max_health = float(data.get("max_health", max_health))
	var saved_max_energy = float(data.get("max_energy", max_energy))
	var saved_max_arcane = float(data.get("max_arcane", max_arcane))
	var health_ratio = float(data.get("health", health)) / saved_max_health if saved_max_health > 0 else 1.0
	var energy_ratio = float(data.get("energy", energy)) / saved_max_energy if saved_max_energy > 0 else 1.0
	var arcane_ratio = float(data.get("arcane", arcane)) / saved_max_arcane if saved_max_arcane > 0 else 1.0

	if data.has("experience_points"): experience_points = data["experience_points"]
	if data.has("level"): level = data["level"]
	if data.has("available_attribute_points"): available_attribute_points = data["available_attribute_points"]
	if data.has("skill_points"): skill_points = data["skill_points"]
	if data.has("used_skill_points"): used_skill_points = data["used_skill_points"]

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
				attributes[attribute_name] = getAttributeValue(attribute_name, attribute_points_spent[attribute_name])
	if data.has("statuses"): statuses = data["statuses"].duplicate(true)
	if data.has("debuff_buffs_active"): debuff_buffs_active = data["debuff_buffs_active"].duplicate(true)

	markAttributeCacheDirty()
	updateAttributes()

	health = clamp(health_ratio * max_health, 0.0, max_health)
	energy = clamp(energy_ratio * max_energy, 0.0, max_energy)
	arcane = clamp(arcane_ratio * max_arcane, 0.0, max_arcane)















remote func requestSelfSaveStats() -> void:
	if !parent.has_method("isLocalPlayer") or !parent.isLocalPlayer():
		return
	if "data_fully_loaded" in parent and !parent.data_fully_loaded:
		return
	saveData()

func saveData():
	if _post_load_guard:
		return
	if isParentPlayer():
		if "data_fully_loaded" in parent and !parent.data_fully_loaded:
			return
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








func _writeStatsDataLocal(saveDirectory:String, data:Dictionary) -> void:
	# FIX: this ran once per mob (up to ~150 times, spread 1/frame by
	# World.gd's save queue, but each one was still a synchronous
	# File.open()/store_var()/close() on the main thread). Route through
	# the World's background write thread instead, same as every other
	# save path in the game -- removes 150 potential main-thread stall
	# points that could each tip physics catch-up into a runaway spiral.
	var world = getCachedStatsWorld()
	if is_instance_valid(world) and world.has_method("queueFileWrite"):
		world.queueFileWrite(saveDirectory + "stats.save", data)
		return

	# Fallback: only reached if this Stats node has no reachable World
	# (shouldn't happen in practice) -- keeps the save from being lost.
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
	if isParentPlayer():
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
				attributes[attribute_name] = getAttributeValue(attribute_name, attribute_points_spent[attribute_name])
	statuses = data.get("statuses", {}).duplicate(true)
	debuff_buffs_active = data.get("debuff_buffs_active", {}).duplicate(true)
	markAttributeCacheDirty()
	_syncLoadedAttributesToServer()








































func _syncLoadedAttributesToServer() -> void:
	# The server is combat authority for players but never runs loadData()
	# for them (isLocalOwner() blocks it) -- without this, whatever points
	# a player already spent in a previous session are invisible to the
	# server, which keeps computing combat off untouched defaults.
	if get_tree().network_peer == null or !isParentPlayer() or get_tree().is_network_server():
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




func getAttributeValue(attribute_name:String, points:int) -> float:
	var base = species_attributes.get(attribute_name, 1.0)
	var delta = 0.0

	var remaining = abs(points)
	var tier_size = 10

	var gain = 0.025
	var minimum_gain = 0.01

	while remaining > 0:
		var used = min(remaining, tier_size)

		if points > 0:
			delta += used * gain
		else:
			delta -= used * gain

		remaining -= used

		gain *= 0.5
		gain = max(gain, minimum_gain)

	return max(MIN_ATTRIBUTE, base + delta)
func increaseAttribute(attribute_name:String) -> void:
	if !attributes.has(attribute_name):
		return
	if _shouldRouteThroughAuthority():
		_increaseAttributeLocal(attribute_name) # instant UI feedback; server will correct us if it disagrees
		rpc_id(_authorityId(), "requestIncreaseAttribute", attribute_name)
		return
	_increaseAttributeLocal(attribute_name)

func decreaseAttribute(attribute_name:String) -> void:
	if !attributes.has(attribute_name):
		return
	if _shouldRouteThroughAuthority():
		_decreaseAttributeLocal(attribute_name)
		rpc_id(_authorityId(), "requestDecreaseAttribute", attribute_name)
		return
	_decreaseAttributeLocal(attribute_name)

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
	attributes[attribute_name] = getAttributeValue(attribute_name, attribute_points_spent[attribute_name])
	markAttributeCacheDirty()
	updateAttributes()
	_pushStatsToOwner()


remote func requestDecreaseAttribute(attribute_name:String) -> void:
	if !get_tree().is_network_server():
		return
	_decreaseAttributeLocal(attribute_name)
func _decreaseAttributeLocal(attribute_name:String) -> void:
	if !attributes.has(attribute_name):
		return
	var current_value = getAttributeValue(attribute_name, attribute_points_spent[attribute_name])
	var next_value = getAttributeValue(attribute_name, attribute_points_spent[attribute_name] - 1)
	if current_value <= MIN_ATTRIBUTE:
		return
	if next_value < MIN_ATTRIBUTE:
		return
	attribute_points_spent[attribute_name] -= 1
	available_attribute_points += 1
	attributes[attribute_name] = next_value
	markAttributeCacheDirty()
	updateAttributes()
	_pushStatsToOwner()
	
	
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
func shouldUpdateStatusGridLocally() -> bool:
	# Mirrors Player.gd's shouldAnimateLocally(). On a dedicated server,
	# every connected player's Stats node exists purely for authoritative
	# bookkeeping -- updateStatusGrid() duplicates/instances real Control
	# nodes under UI/CrossairInspect and UI/Menu/CharacterBar every ~0.5s,
	# for EVERY player, on a machine with nothing to render it on. Any
	# real client still needs this for every player it can see.
	if get_tree().network_peer == null:
		return true
	if !get_tree().is_network_server():
		return true
	return parent.has_method("isLocalPlayer") and parent.isLocalPlayer()
var _last_status_grid_signature := {}
func updateStatusGridIfChanged(grid:GridContainer, source) -> void:
	if grid == null or source == null:
		return
	var sig := ""
	for status_name in source.statuses.keys():
		var v = source.statuses[status_name]
		if typeof(v) == TYPE_DICTIONARY:
			sig += status_name + ":" + str(int(ceil(float(v.get("duration",0.0))))) + ":" + str(int(v.get("stacks",1))) + "|"
		elif typeof(v) == TYPE_ARRAY:
			sig += status_name + ":" + str(v.size()) + "|"
	for buff_name in source.debuff_buffs_active.keys():
		var b = source.debuff_buffs_active[buff_name]
		sig += buff_name + ":" + str(int(ceil(float(b.get("duration",0.0))))) + ":" + str(int(b.get("stacks",1))) + "|"

	var key = grid.get_instance_id()
	if _last_status_grid_signature.get(key,"") == sig:
		return
	_last_status_grid_signature[key] = sig
	updateStatusGrid(grid, source)

var _status_ui_lookup_attempted := false

func updateStatusGrid(grid:GridContainer, source)->void:
	if !isParentPlayer():
		return

	if !_status_ui_lookup_attempted:
		_status_ui_lookup_attempted = true
		# get_node_or_null instead of $ -- bots have no UI subtree at all,
		# so this must fail silently instead of erroring, and it must only
		# ever be attempted ONCE per Stats node instead of on every single
		# buff/debuff/status call. Retrying a failed $ lookup every combat
		# tick for every bot is what was spamming the editor console and
		# causing the "random slideshow" freezes (invisible to the profiler
		# because the stall is in the editor's own console I/O, not in any
		# measured script/physics time).
		mob_status_grid = get_node_or_null("../UI/CrossairInspect/MobStatusGrid")
		player_status_grid = get_node_or_null("../UI/Menu/CharacterBar/PlayerStatusGrid")
		player_example_icon = get_node_or_null("../UI/Menu/CharacterBar/PlayerStatusGrid/Icon1")
		mob_example_icon = get_node_or_null("../UI/CrossairInspect/GridContainer/Icon1")

	if grid == null:
		return

	if source == null:
		return

	var template:TextureRect = grid.get_node("Icon1")

	for child in grid.get_children():
		if child != template:
			child.queue_free()

	template.visible = false

	var status_value
	var icon_instance:TextureRect
	var duration_label
	var stack_label
	var stack_value:int
	var category

	for status_name in source.statuses.keys():
		status_value = source.statuses[status_name]

		if typeof(status_value) == TYPE_ARRAY:
			for status_entry in status_value:
				if typeof(status_entry) != TYPE_DICTIONARY:
					continue

				if !Global.status_icons.has(status_name):
					if Global.Global.has(status_name):
						Global.status_icons[status_name] = Global.skills[status_name]
					else:
						for category_name in ["flasks","weapons","armors"]:
							category = Global.get(category_name)
							if category != null and category.has(status_name):
								Global.status_icons[status_name] = category[status_name]["icon"]
								break
					if !Global.status_icons.has(status_name):
						continue

				icon_instance = template.duplicate()
				icon_instance.visible = true
				icon_instance.texture = load(Global.status_icons[status_name]) if Global.status_icons[status_name] is String else Global.status_icons[status_name]

				duration_label = icon_instance.get_node("Label")
				if duration_label:
					duration_label.text = str(int(ceil(status_entry.get("duration",0.0))))

				stack_label = icon_instance.get_node("Stack")
				if stack_label:
					stack_value = 0
					for entry in status_value:
						if typeof(entry) == TYPE_DICTIONARY:
							stack_value += int(entry.get("stacks",1))
					stack_label.text = "" if stack_value <= 1 else str(stack_value)

				grid.add_child(icon_instance)

		elif typeof(status_value) == TYPE_DICTIONARY:
			if !Global.status_icons.has(status_name):
				if Global.skills.has(status_name):
					Global.status_icons[status_name] = Global.skills[status_name]
				else:
					for category_name in ["flasks","weapons","armors"]:
						category = Global.get(category_name)
						if category != null and category.has(status_name):
							Global.status_icons[status_name] = category[status_name]["icon"]
							break
				if !Global.status_icons.has(status_name):
					continue

			icon_instance = template.duplicate()
			icon_instance.visible = true
			icon_instance.texture = load(Global.status_icons[status_name]) if Global.status_icons[status_name] is String else Global.status_icons[status_name]

			duration_label = icon_instance.get_node("Label")
			if duration_label:
				duration_label.text = str(int(ceil(status_value.get("duration",0.0))))

			stack_label = icon_instance.get_node("Stack")
			if stack_label:
				stack_value = int(status_value.get("stacks",1))
				stack_label.text = "" if stack_value <= 1 else str(stack_value)

			grid.add_child(icon_instance)

	for icon_key in source.debuff_buffs_active.keys():
		status_value = source.debuff_buffs_active[icon_key]

		if !Global.status_icons.has(icon_key):
			if Global.skills.has(icon_key):
				Global.status_icons[icon_key] = Global.skills[icon_key]
			else:
				for category_name in ["flasks","weapons","armors"]:
					category = Global.get(category_name)
					if category != null and category.has(icon_key):
						Global.status_icons[icon_key] = category[icon_key]["icon"]
						break
			if !Global.status_icons.has(icon_key):
				continue

		icon_instance = template.duplicate()
		icon_instance.visible = true
		icon_instance.texture = load(Global.status_icons[icon_key]) if Global.status_icons[icon_key] is String else Global.status_icons[icon_key]

		duration_label = icon_instance.get_node("Label")
		if duration_label:
			duration_label.text = str(int(ceil(status_value.get("duration",0.0))))

		stack_label = icon_instance.get_node("Stack")
		if stack_label:
			if status_value.has("stackable") and !status_value["stackable"]:
				stack_label.text = ""
			else:
				stack_value = int(status_value.get("stacks",1))
				stack_label.text = "" if stack_value <= 1 else str(stack_value)

		grid.add_child(icon_instance)

var _last_buff_tick_ms:int = 0

func tickBuffsDebuffs()->void:
	var now_ms:int=OS.get_ticks_msec()
	var elapsed_seconds:float=1.0
	if _last_buff_tick_ms!=0:
		elapsed_seconds=float(now_ms-_last_buff_tick_ms)/1000.0
		if elapsed_seconds<=0.0:elapsed_seconds=1.0
		elapsed_seconds=min(elapsed_seconds,30.0) # cap so one freak stall can't insta-wipe every buff
	_last_buff_tick_ms=now_ms

	var buff_keys=debuff_buffs_active.keys()

	for buff_name in buff_keys:
		if !debuff_buffs_active.has(buff_name):continue

		var buff_data=debuff_buffs_active[buff_name]
		if typeof(buff_data)!=TYPE_DICTIONARY:continue

		var source_id=int(buff_data.get("source_id",0))
		var source=instance_from_id(source_id) if source_id!=0 else parent

		var duration=float(buff_data.get("duration",0.0))-elapsed_seconds
		buff_data["duration"]=duration
		buff_data["regen_timer"]=float(buff_data.get("regen_timer",1.0))-elapsed_seconds

		if duration<=0.0:
			debuff_buffs_active.erase(buff_name)
			continue

		var damage_type=buff_data.get("damage type",null)
		var damage_amount=float(buff_data.get("damage ammount",0.0))
		var dot_interval=float(buff_data.get("dot timer",1.0))
		if dot_interval<=0.0:dot_interval=1.0

		if damage_type!=null and damage_amount>0.0:
			var dot_timer=float(buff_data.get("dot_timer",dot_interval))-elapsed_seconds
			buff_data["dot_timer"]=dot_timer

			while dot_timer<=0.0:
				dot_timer+=dot_interval
				getDamagedFromDebuff(source,buff_name,{damage_type:damage_amount})

			buff_data["dot_timer"]=dot_timer

		var heal=float(buff_data.get("regen health",0.0))
		if heal>0.0:getHeal(parent,heal*elapsed_seconds)

		var energy_reg=float(buff_data.get("regen energy",0.0))
		if energy_reg>0.0:
			energy+=energy_reg*elapsed_seconds
			if energy>max_energy:energy=max_energy
		var arcane_reg=float(buff_data.get("regen arcane",0.0))
		if arcane_reg>0.0:
			arcane+=arcane_reg*elapsed_seconds
			if arcane>max_arcane:arcane=max_arcane
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
	for skill_name in Global.status_effects:
		if Global.status_effects[skill_name].has(status_name):
			if !bool(Global.status_effects[skill_name][status_name].get("malus",false)):
				return true
	return false
func applyBuffDebuff(buff_name:String, source:Node)->void:
	if !Global.debuffs_buffs.has(buff_name):return
	if source==null:source=parent
	if _shouldRouteThroughAuthority():
		rpc_id(_authorityId(), "requestApplyBuffDebuff", buff_name, source.get_path())
		return
	_applyBuffDebuffLocal(buff_name, source)
func _authorityId() -> int:
	return 1 #combat authority is always the server, for players and mobs alike
#func _authorityId() -> int:
#	if isParentPlayer():
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
	if !Global.debuffs_buffs.has(buff_name):return
	if source==null:source=parent

	var buff_data=Global.debuffs_buffs[buff_name]
	var stackable=bool(buff_data.get("stackable",false))
	var raw_duration=float(buff_data.get("duration",0.0))
	var tenacity=float(derived_stats.get("tenacity",1.0))
	var is_malus=bool(buff_data.get("malus",false))

	if is_malus:
		raw_duration/=tenacity
		if raw_duration<1.0:raw_duration=1.0
	else:
		var buff_multiplier=lerp(0.25,1.5,inverse_lerp(0.25,2.0,tenacity))
		raw_duration*=buff_multiplier

	# FIX: _last_buff_tick_ms only advances inside tickBuffsDebuffs(), which
	# only runs while debuff_buffs_active is non-empty. If no buff has been
	# active for a while, that clock goes stale. Applying a brand new buff
	# after such a gap meant the very next tick computed elapsed_seconds as
	# the ENTIRE stale gap (capped at 30s) and subtracted that from the
	# fresh duration in one shot -- instantly killing a 15s buff. Resetting
	# the clock here, exactly when going from no-buffs to having one,
	# makes the first real tick see ~0 elapsed instead.
	if debuff_buffs_active.empty():
		_last_buff_tick_ms = OS.get_ticks_msec()

	if debuff_buffs_active.has(buff_name):
		debuff_buffs_active[buff_name]["duration"]=raw_duration
		if stackable:
			debuff_buffs_active[buff_name]["stacks"]=int(debuff_buffs_active[buff_name].get("stacks",1))+1
		updateStatusGrid(player_status_grid, self)
		if isParentPlayer() and is_instance_valid(bar):
			bar.updateBars()
		_pushStatsToOwner()
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

	markAttributeCacheDirty()
	updateBuffDebuffs()
	updateAttributes()
	updateStatusGrid(player_status_grid, self)
	if isParentPlayer() and is_instance_valid(bar):
		bar.updateBars()
	_pushStatsToOwner()

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
	dmgMultByType = [slash_multiplier, blunt_multiplier, pierce_multiplier, sonic_multiplier, heat_multiplier, cold_multiplier, jolt_multiplier, toxic_multiplier, acid_multiplier, arcane_multiplier, bleed_multiplier, radiant_multiplier]



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
	derived_stats["jump_power"] = 1.0 + getTotalAttribute("power") * 1.25 + getTotalAttribute("agility") * 1.25
	derived_stats["crit_chance"] = 0.05 + getTotalAttribute("instinct") * 0.02
	derived_stats["penetrating_hit_chance"] = 0.05 + getTotalAttribute("wisdom") * 0.02
	derived_stats["penetration_power"] = 0.1 * getTotalAttribute("power") * 0.25 + getTotalAttribute("strength") * 0.25
	derived_stats["crit_damage"] = 2.0 + getTotalAttribute("power") * 0.05
	derived_stats["detection_range"] = 10.0 + getTotalAttribute("perception") * 2.0
	derived_stats["energy_regeneration"] = 1.0 + getTotalAttribute("endurance")
	derived_stats["arcane_regeneration"] = 1.0 + getTotalAttribute("wisdom")
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
		if Global.debuffs_buffs.has(buff_name) and bool(Global.debuffs_buffs[buff_name].get("malus",false)):
			debuff_buffs_active.erase(buff_name)

	for status_name in statuses.keys():
		var remove=false

		for skill_name in Global.status_effects:
			if Global.status_effects[skill_name].has(status_name):
				if bool(Global.status_effects[skill_name][status_name].get("malus",false)):
					remove=true
					break

		if remove:
			removeStatus(status_name)

func cleanse()->void:
	var target_type=""
	var target_name=""
	var target_duration=-1.0

	for buff_name in debuff_buffs_active:
		if !Global.debuffs_buffs.has(buff_name):continue
		if !bool(Global.debuffs_buffs[buff_name].get("malus",false)):continue

		var duration=float(debuff_buffs_active[buff_name].get("duration",0.0))
		if duration>target_duration:
			target_duration=duration
			target_type="buff"
			target_name=buff_name

	for status_name in statuses:
		var harmful=false
		for skill_name in Global.status_effects:
			if Global.status_effects[skill_name].has(status_name):
				if bool(Global.status_effects[skill_name][status_name].get("malus",false)):
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
	if isParentPlayer() and !parent.is_in_group("BOT"):
		var chat=parent.chat
		if chat and chat.has_method("sendSystemMessage"):
			chat.sendSystemMessage(parent.entity_name+" got cleansed off: "+target_name)

func dispell()->void:
	var target_type=""
	var target_name=""
	var target_duration=-1.0

	for buff_name in debuff_buffs_active:
		if !Global.debuffs_buffs.has(buff_name):continue
		if bool(Global.debuffs_buffs[buff_name].get("malus",false)):continue

		var duration=float(debuff_buffs_active[buff_name].get("duration",0.0))
		if duration>target_duration:
			target_duration=duration
			target_type="buff"
			target_name=buff_name

	for status_name in statuses:
		var beneficial=false
		for skill_name in Global.status_effects:
			if Global.status_effects[skill_name].has(status_name):
				if !bool(Global.status_effects[skill_name][status_name].get("malus",false)):
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
	if isParentPlayer() and !parent.is_in_group("BOT"):
		var chat=parent.chat
		if chat and chat.has_method("sendSystemMessage"):
			chat.sendSystemMessage(parent.entity_name+" got dispelled: "+target_name)

func exhaust()->void:
	for buff_name in debuff_buffs_active.keys():
		if Global.debuffs_buffs.has(buff_name) and !bool(Global.debuffs_buffs[buff_name].get("malus",false)):
			debuff_buffs_active.erase(buff_name)

	for status_name in statuses.keys():
		var remove=false

		for skill_name in Global.status_effects:
			if Global.status_effects[skill_name].has(status_name):
				if !bool(Global.status_effects[skill_name][status_name].get("malus",false)):
					remove=true
					break

		if remove:
			removeStatus(status_name)


var _attribute_total_cache := {}
var _attribute_cache_dirty := true
var _stats_dirty := true   # forces one real recompute on startup, then only on real changes

func markAttributeCacheDirty() -> void:
	_attribute_cache_dirty = true
	_stats_dirty = true

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

	if !Global.status_effects.has(skill):
		return {"tick_damage":0.0,"duration":0.0,"can_stack":false}

	if !Global.status_effects[skill].has("bleed"):
		return {"tick_damage":0.0,"duration":0.0,"can_stack":false}

	var bleed = Global.status_effects[skill]["bleed"]

	return {
		"tick_damage":bleed.get("base_damage",0.0) * bleed_multiplier,
		"duration":bleed.get("duration",0.0),
		"can_stack":bleed.get("can_stack",false)
	}




func getSkillLevel(skill_name:String) -> int:
	if skill_level_cache.has(skill_name):
		return skill_level_cache[skill_name]
	var level_found = computeSkillLevelUncached(skill_name)
	skill_level_cache[skill_name] = level_found
	return level_found

func computeSkillLevelUncached(skill_name:String) -> int:
	var root = get_node_or_null("../UI/SkillTreeRoot")
	if root == null:
		return 0

	var skill_texture = Global.skills.get(skill_name,null)
	if skill_texture == null:
		return 0

	var control =  $"../UI/SkillTreeRoot/SkillTree/Control/MoveThis"
	for child in control.get_children():
		if !(child is TextureButton):
			continue
		if !child.has_node("Slot"):
			continue

		var slot = child.get_node("Slot")
		if slot.texture == skill_texture:
			return child.skill_level

	return 0

func invalidateSkillLevelCache(skill_name:String = "") -> void:
	if skill_name == "":
		skill_level_cache.clear()
	else:
		skill_level_cache.erase(skill_name)
	rebuildOnHitEffects()


func getSkillLevelMultiplier(skill_name:String) -> float:
	return Global.getDamageMultiplier(skill_name,max(0,getSkillLevel(skill_name)-1))





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
var skill_level_cache := {}
var dmgMultByType := []
const DMG_TYPE_NAMES = ["slash","blunt","pierce","sonic","heat","cold","jolt","toxic","acid","arcane","bleed","radiant"]
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
var _skill_damage_cache: Dictionary = {} # "skillname|charge_stacks" -> Dictionary


func dealDamage():
	if parent.is_in_group("Entity") and "is_in_combat" in parent:
		parent.is_in_combat = true
	var area: Area = null
	var skill = parent.current_skill.to_lower()
	if isParentPlayer():
		if areas_to_use.has(skill):
			area = get_node_or_null(areas_to_use[skill])
		else:
			if parent.weapons==parent.WeaponMode.SWORD:
				area = get_node_or_null("../character/root/Skeleton/WeaponR/Short")
			elif parent.weapons==parent.WeaponMode.TWO_HANDED:
				area = get_node_or_null("../character/root/Skeleton/WeaponR/Long")
			elif parent.weapons==parent.WeaponMode.DUAL or parent.weapons==parent.WeaponMode.SHIELD:
				area = get_node_or_null("../character/root/Skeleton/WeaponR/Short")
				if !is_instance_valid(area):
					area = get_node_or_null("../character/root/Skeleton/WeaponL/Short")
		if !is_instance_valid(area):
			area = get_node_or_null("../Turnable/CleaveSmall")
	elif parent.is_in_group("Detached"):
		area = get_node("Area")
	elif parent.is_in_group("Entity"):
		area = $"../AreaDamage"
	else:
		area = $"../AreaDamage"

	if area == null:
		return

	var bodies = area.get_overlapping_bodies()
	if bodies.empty():
		for attack_name in charged_attack_stacks:
			charged_attack_stacks[attack_name]["stacks"] = 0
		return

	var skill_name:String = parent.current_skill



	var skill_level_mult:float = getSkillLevelMultiplier(skill_name)
	var charge_stacks:int = 0
	if charged_attack_stacks.has(skill_name):
		charge_stacks = int(charged_attack_stacks[skill_name].stacks)

	var cache_key = skill_name + "|" + str(charge_stacks)
	var skill_damages:Dictionary
	if _skill_damage_cache.has(cache_key):
		skill_damages = _skill_damage_cache[cache_key].duplicate()
	else:
		skill_damages = Global.getDamages(skill_name)
		if charged_attack_stacks.has(skill_name) and charge_stacks > 0:
			var data = charged_attack_stacks[skill_name]
			for dmg_type in skill_damages:
				skill_damages[dmg_type] += skill_damages[dmg_type] * (charge_stacks * data.multiplier)
		_skill_damage_cache[cache_key] = skill_damages.duplicate()

	var my_stats = parent.get_node("Stats")
	var my_species = my_stats.species if my_stats != null else ""

	var base_pen_chance = my_stats.derived_stats.get("penetrating_hit_chance",0.0)
	var is_penetrating_hit = randf() <= clamp(base_pen_chance + Global.skill_penetration_chance.get(skill_name.to_lower(),0.0),0.0,1.0)

	var is_crit = my_stats != null and randf() <= my_stats.derived_stats["crit_chance"]

	var total_damage:int = 0

	var can_chat = !parent.is_in_group("BOT") and isParentPlayer() and Global.canSendCombatChatMessage(parent.get_network_master())

	for body in bodies:
		if !body.is_in_group("Entity"):
			continue
		if !Global.canHitEnemy(parent,body):
			continue
		if Global.skill_dmg_immunity.has(body.current_skill):
			continue

		var other_stats = body.stats

		# Target-based special effects are calculated separately for each target.
		var special_mult:float = Global.getSpecialDamageMultiplier(skill_name,self,other_stats)
		var special_flat_damage:float = Global.getSpecialFlatDamage(skill_name,other_stats)

		var damages = {}

		for dmg_type in skill_damages:
			var type_index:int = int(dmg_type)
			var mult = dmgMultByType[type_index] if type_index < dmgMultByType.size() else 1.0
			var type_name = DMG_TYPE_NAMES[type_index] if type_index < DMG_TYPE_NAMES.size() else ""
			var flat_add = flat_damage_bonus.get(type_name,0.0) + damage_flat_modifier.get(type_name,0.0)

			damages[dmg_type] = (skill_damages[dmg_type] * mult * skill_level_mult * special_mult) + flat_add + special_flat_damage

		if isParentPlayer():
			if parent.weapons==parent.WeaponMode.NONE and skill_name=="combo attack":
				var total=0.0
				for t in damages:
					total+=damages[t]
				damages={Global.Type.blunt:total}

		if isParentPlayer() and parent.weapons==parent.WeaponMode.DUAL:
			for dmg_type in damages:
				if parent.current_skill == "combo attack" or parent.WeaponMode.NONE:
					damages[dmg_type] *= 0.5

		if is_crit:
			for dmg_type in damages:
				damages[dmg_type] *= my_stats.derived_stats["crit_damage"]

		var target_total_damage:int = 0
		for v in damages.values():
			target_total_damage += int(v)
		total_damage += target_total_damage

		if is_instance_valid(other_stats) and Global.debuffs_buffs.has(skill_name):
			if Global.debuffs_buffs[skill_name].get("malus",true):
				other_stats.applyBuffDebuff(skill_name,parent)
			else:
				applyBuffDebuff(skill_name,parent)

		if other_stats != null:
			var extra_threat = Global.skill_extra_aggro.get(skill_name.to_lower(),0.0)
			var extra_treat_amplified = extra_threat * derived_stats["threat"]

			other_stats.getHit(parent,damages,is_penetrating_hit,extra_treat_amplified,is_crit)
			Global.applyImpactEffects(skill_name,body,parent)

		if isParentPlayer():
			if body==parent:
				continue

			if !can_chat:
				continue

			var victim_name=body.entity_name if "entity_name" in body else ""
			if victim_name=="" or victim_name==" " or victim_name=="nameless" or victim_name==" ":
				if other_stats and other_stats.species!="":
					victim_name=other_stats.species

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

			var chat = parent.chat
			var hit = body.get_meta("last_hit_data") if body.has_meta("last_hit_data") else null

			var formatted_damage = ""
			if hit and hit.has("damages"):
				for dmg_type in hit.damages:
					var value = int(hit.damages[dmg_type])
					formatted_damage += str(value) + " " + damageTypeToString(int(dmg_type)) + " "
				formatted_damage = formatted_damage.strip_edges()
			else:
				formatted_damage = str(target_total_damage)

			if skill_name == "none":
				chat.sendSystemMessage(attacker_name + " dealt " + formatted_damage + " damage to " + victim_name + tag)
			else:
				chat.sendSystemMessage(attacker_name + " dealt " + formatted_damage + " damage to " + victim_name + " " + skill_name + tag)

	for attack_name in charged_attack_stacks:
		charged_attack_stacks[attack_name]["stacks"] = 0

	if !parent.is_in_group("BOT") and isParentPlayer():
		if is_instance_valid(parent.skillbar) and "active_cooldowns" in parent.skillbar:
			Global.applyOnHitEffects(parent.current_skill,active_on_hit_effects,parent.skillbar.active_cooldowns,self,total_damage)

	if "active_cooldowns" in parent:
		Global.applyOnHitEffects(parent.current_skill,Global.on_hit_effects,parent.active_cooldowns,self,total_damage)
	elif "skill_cooldowns" in parent:
		Global.applyOnHitEffects(parent.current_skill,Global.on_hit_effects,parent.skill_cooldowns,self,total_damage)


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

	applyHit(attacker,damages,is_penetrating_hit,extra_threat,is_crit)

	if "sleeping" in parent:
		parent.sleeping = false
	if "_is_relevant" in parent and !parent._is_relevant:
		parent._is_relevant = true
		if is_instance_valid(Global):
			Global.markActive(parent)
	if "animation_tree" in parent and is_instance_valid(parent.animation_tree) and !parent.animation_tree.active and !parent.is_dead:
		parent.animation_tree.active = true


remote func requestGetHit(attacker_path:NodePath, damages:Dictionary, is_penetrating_hit:bool, extra_threat:float, is_crit:bool) -> void:
	if !get_tree().is_network_server():
		return
	var attacker = get_node_or_null(attacker_path)
	if attacker == null:
		return
	applyHit(attacker,damages,is_penetrating_hit,extra_threat,is_crit)
func applyHit(attacker:Node,damages:Dictionary,is_penetrating_hit:bool = false,extra_threat:float = 0.0,is_crit:bool=false)->void:
	if attacker != null and !is_instance_valid(attacker):
		attacker = null
	if attacker and (attacker.name=="Stats" or attacker.get_class()=="Node"):
		attacker=attacker.get_parent()
	if attacker != null and !is_instance_valid(attacker):
		attacker = null
	wakeMobIfNeeded()
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
		if Global.skill_dmg_immunity.has(parent.current_skill):
			return

		if Global.skill_dmg_reduction.has(parent.current_skill):
			final_damage *= Global.skill_dmg_reduction[parent.current_skill]
		if statuses.has("berserk_buff"):
			final_damage *= 1.8
		
		var is_flank_or_back = isFacingSelf(attacker, 0.0)

		if parent.current_skill == "guard" and not is_flank_or_back:
			var block = 1.0


			parent.stats.energy = min(parent.stats.energy + 10, parent.stats.max_energy)

			if isParentPlayer():
				if !parent.is_in_group("BOT") :
					var main_texture = $"../UI/Equipment/MainHand/Slot".texture
					var off_texture = $"../UI/Equipment/OffHand/Slot".texture
					parent.anim_locks["guard"] = false
					parent.anim_locks["guard react"] = true

					for weapon_name in Global.weapons:
						var weapon = Global.weapons[weapon_name]

						if Global.sameIcon(weapon.get("icon"),main_texture):
							block *= weapon.get("block",1.0)

						if Global.sameIcon(weapon.get("icon"),off_texture):
							block *= weapon.get("block",1.0)
				else:
					block = 1.5
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
	if isParentPlayer() and !parent.is_in_group("BOT"):
		var chat=parent.chat
		var victim_name=parent.entity_name
		if victim_name=="" or victim_name==" " or victim_name=="nameless" or victim_name.strip_edges()=="":
			var stats=parent.stats
			if stats and stats.species!="": victim_name=stats.species
			else: victim_name="unknown"

		var attacker_name=attacker.entity_name if attacker else "null"
		if attacker:
			if attacker_name=="" or attacker_name==" " or attacker_name=="nameless" or attacker_name.strip_edges()=="":
				var astats=attacker.stats
				if astats and astats.species!="": attacker_name=astats.species
				else: attacker_name="unknown"
		if Global.canSendCombatChatMessage(parent.get_network_master()):
			var tag=""
			if facing_multiplier==backstab_dmg_multiplier: tag=" backstab"
			elif facing_multiplier==flank_dmg_multiplier: tag=" flank"
			var msg
			var skill_name=attacker.current_skill if attacker else "none"
			if skill_name=="none":
				msg="%s took %s damage from %s%s"%[victim_name,dmgText(total_damage),attacker_name,tag]
			else:
				msg="%s took %s damage from %s %s%s"%[victim_name,dmgText(total_damage),attacker_name,skill_name,tag]
			chat.sendSystemMessage(msg)
	
	
	if is_instance_valid(parent):
		if !isParentPlayer():
			if attacker != null and is_instance_valid(attacker):
				if attacker.is_in_group("Entity") and attacker.has_node("Stats"):
					var instigatorAggro = parent.getAggro(attacker)
					if instigatorAggro != null:
						var threat_multiplier:float = 1.0
						if attacker.stats != null:
							if attacker.stats.derived_stats.has("threat"):
								threat_multiplier = float(attacker.stats.derived_stats["threat"])
						var threat:float = (total_damage * threat_multiplier) + extra_threat
						if instigatorAggro != null:
							instigatorAggro.aggro += threat
					if is_instance_valid(parent):
						parent.shareAggro(parent.creator)
						if parent.spawned_bodies != null:
							for children in parent.spawned_bodies:
								if is_instance_valid(children):
									parent.shareAggro(children)
									parent.getAggroFromOtherMob(children)
			parent.shareAggro(parent.creator)
			for children in parent.spawned_bodies:
				parent.shareAggro(children)
				parent.getAggroFromOtherMob(children)

			# ONLINE AGGRO FIX: this used to only ever wake the mob up and
			# assign `target` when getHit() ran the hit LOCALLY (offline, or
			# when the attacker happened to also be the server). Every real
			# networked hit instead comes in through requestGetHit()'s RPC,
			# which called _applyHit() directly and skipped all of that --
			# so the mob's aggro list got an entry, but the mob itself never
			# got marked relevant, never got unfrozen, and `target` was
			# never actually set, so it just sat there ignoring the hit
			# until something else unrelated happened to wake it up. Doing
			# it here instead of in getHit()/requestGetHit() means BOTH
			# paths (local and RPC) always wake the mob and assign target
			# the instant a hit lands, online or offline, without touching
			# any of the freeze/LOD/relevance systems elsewhere.
			if "sleeping" in parent:
				parent.sleeping = false
			if "_is_relevant" in parent and !parent._is_relevant:
				parent._is_relevant = true
				if is_instance_valid(Global):
					Global.markActive(parent)
			if parent.has_method("unfreezeMob") and ("is_frozen" in parent) and parent.is_frozen:
				parent.unfreezeMob()
			if "animation_tree" in parent and is_instance_valid(parent.animation_tree) and !parent.animation_tree.active and !("is_dead" in parent and parent.is_dead):
				parent.animation_tree.active = true
			if parent.has_method("findHighestAggro") and "target" in parent:
				var highestAggroNow = parent.findHighestAggro()
				if highestAggroNow != null and highestAggroNow.aggro > 0:
					parent.target = highestAggroNow.target_entity
	
	if attacker != null:
		var attacker_id = attacker.get_instance_id()
		if !damage_meter.has(attacker_id):
			damage_meter[attacker_id] = {"attacker":attacker,"damage":0.0}
		damage_meter[attacker_id].damage += total_damage
	if isParentPlayer() and !parent.is_in_group("BOT"):
		parent.character_bars.updateBars()
	updateBuffDebuffs()
	
	broadcastDamageText(final_damages, is_crit, is_penetrating_hit, attacker)

	health -= total_damage
	getKilled(attacker)
	parent.set_meta("last_hit_data", {
	"damage": total_damage,
	"damages": final_damages,
	"flank": facing_multiplier == flank_dmg_multiplier,
	"backstab": facing_multiplier == backstab_dmg_multiplier,
	"victim": parent,
	"attacker": attacker
})
	_pushStatsToOwner()




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
	if attacker != null and !is_instance_valid(attacker):
		attacker = null
	if attacker and (attacker.name=="Stats" or attacker.get_class()=="Node"):attacker=attacker.get_parent()
	if attacker != null and !is_instance_valid(attacker):
		attacker = null
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
		if Global.skill_dmg_immunity.has(parent.current_skill):return
		var final_damage=damage*(1.0-mitigation)*facing_multiplier
		final_damages[dmg_type]=final_damage
		total_damage+=final_damage
	if !(isParentPlayer() or isParentPlayer()) and attacker and attacker.is_in_group("Entity") and attacker.has_node("Stats"):
		var instigatorAggro=parent.getAggro(attacker)
		var threat=total_damage*attacker.stats.derived_stats["threat"]+extra_threat
		instigatorAggro.aggro+=threat
		parent.shareAggro(parent.creator)
		for child in parent.spawned_bodies:
			parent.shareAggro(child)
			parent.getAggroFromOtherMob(child)
	var damage_multiplier=1.0
	if parent.current_skill=="flinch" or Global.getAnimLock(parent,"knocked back") or Global.getAnimLock(parent,"knocked down"):damage_multiplier=2.0
	elif (parent.current_skill=="guard" or Global.getAnimLock(parent,"guard")) and facing_multiplier==1.0:
		damage_multiplier=0.3
		Global.setAnimLock(parent,"guard react",true)
	total_damage=0.0
	for dmg_type in final_damages:
		final_damages[dmg_type]*=damage_multiplier
		total_damage+=final_damages[dmg_type]
	if attacker and "stored_body" in attacker:
		if parent and "stats" in parent and parent.stats.health>0:attacker.stored_body=parent
		else:attacker.stored_body=null
	broadcastDamageText(final_damages, is_crit, is_penetrating_hit, attacker)
	if isParentPlayer() and !parent.is_in_group("BOT") and parent.get_parent() is KinematicBody and "entity_name" in parent.get_parent():
		var body=parent.get_parent()
		var chat=parent.chat
		var victim_name=body.entity_name
		if victim_name.strip_edges()=="":
			var stats=body.get_node_or_null("Stats")
			victim_name=stats.species if stats and stats.species!="" else ""
		var attacker_name=attacker.entity_name if attacker and "entity_name" in attacker else "null"
		if attacker and attacker_name.strip_edges()=="":
			var astats=attacker.get_node_or_null("Stats")
			attacker_name=astats.species if astats and astats.species!="" else "debuff"
		if chat and chat.has_method("sendSystemMessage"):
			chat.sendSystemMessage("%s took %s damage from %s %s"%[victim_name,dmgText(total_damage),attacker_name,debuff_name])
	if is_instance_valid($"../UI/Menu/CharacterBar"):$"../UI/Menu/CharacterBar".updateBars()
	updateBuffDebuffs()
	health-=total_damage
	getKilled(attacker)
	if attacker:
		var attacker_id=attacker.get_instance_id()
		if !damage_meter.has(attacker_id):damage_meter[attacker_id]={"attacker":attacker,"damage":0.0}
		damage_meter[attacker_id].damage+=total_damage
	parent.set_meta("last_hit_data",{"damage":total_damage,"flank":facing_multiplier==flank_dmg_multiplier,"backstab":facing_multiplier==backstab_dmg_multiplier,"victim":parent,"attacker":attacker})
	_pushStatsToOwner()



func isAttackerInFront(attacker):
	if attacker==null:return false
	var direction=(attacker.global_transform.origin-parent.global_transform.origin).normalized()
	var facing:Vector3
	if isParentPlayer():
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

	if isParentPlayer():
		if direction_control:facing_direction=-direction_control.global_transform.basis.z.normalized()
		else:facing_direction=-parent.global_transform.basis.z.normalized()
	else:
		facing_direction=-parent.global_transform.basis.z.normalized()

	return -facing_direction.dot(direction_to_self)>=threshold





func applyFallDamage(damage:int) -> void:
	if _shouldRouteThroughAuthority():
		rpc_id(_authorityId(), "requestApplyFallDamage", damage)
		return
	_applyFallDamageLocal(damage)

remote func requestApplyFallDamage(damage:int) -> void:
	if !get_tree().is_network_server():
		return
	_applyFallDamageLocal(damage)

func _applyFallDamageLocal(damage:int) -> void:
	health -= damage
	parent.is_in_combat = false
	if isParentPlayer() and parent.is_in_group("BOT"):
		var chat = parent.chat
		if chat and chat.has_method("sendSystemMessage"):
			chat.sendSystemMessage(parent.entity_name + " took " + str(damage) + " fall damage")
	getKilled(parent)
	_pushStatsToOwner()


func reviveTarget(heal_percent:float) -> void:
	if _shouldRouteThroughAuthority():
		rpc_id(_authorityId(), "requestRevive", heal_percent)
		return
	applyRevive(heal_percent)

remote func requestRevive(heal_percent:float) -> void:
	if !get_tree().is_network_server():
		return
	applyRevive(heal_percent)

func applyRevive(heal_percent:float) -> void:
	if health > 0:
		return
	health = max(1.0, ceil(max_health * heal_percent))
	energy = max(1.0, ceil(max_energy * heal_percent))
	arcane = max(1.0, ceil(max_arcane * heal_percent))
	net_health = health
	net_max_health = max_health
	net_energy = energy
	net_max_energy = max_energy
	net_arcane = arcane
	net_max_arcane = max_arcane
	purify()
	updateBuffDebuffs()
	Global.setCorpseCollisionState(parent,false)
	if isParentPlayer():
		updateStatusGrid(player_status_grid, self)
		if parent.has_method("startGetUpSequence"):
			parent.startGetUpSequence()
		if parent.is_downed:
			if "anim_locks" in parent and typeof(parent.anim_locks) == TYPE_DICTIONARY:
				parent.anim_locks["downed"] = false
			if "current_skill" in parent and parent.current_skill == "downed":
				parent.current_skill = ""
			parent.is_downed = false
		parent.is_dead = false
		if "revive_lock_until_ms" in parent:
			parent.revive_lock_until_ms = OS.get_ticks_msec() + 3000
	_pushStatsToOwner()

func applyRespawnRestore() -> void:
	health = max(1.0, ceil(max_health * 0.01))
	energy = max(1.0, ceil(max_energy * 0.01))
	arcane = max(1.0, ceil(max_arcane * 0.01))

	purify()
	updateBuffDebuffs()
	updateStatusGrid(player_status_grid, self)

	net_health = health
	net_max_health = max_health
	net_energy = energy
	net_max_energy = max_energy
	net_arcane = arcane
	net_max_arcane = max_arcane
	net_statuses = statuses.duplicate(true)
	net_debuff_buffs_active = debuff_buffs_active.duplicate(true)
	_pushStatsToOwner()

func respawnRestore() -> void:
	if _shouldRouteThroughAuthority():
		rpc_id(_authorityId(), "requestRespawnRestore")
		return
	applyRespawnRestore()

remote func requestRespawnRestore() -> void:
	if !get_tree().is_network_server():
		return
	applyRespawnRestore()


















func dmgText(v): return str(int(round(v)))





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
				



func getHeal(source:Node,heal_amount:float)->void:
	if _shouldRouteThroughAuthority():
		rpc_id(_authorityId(), "requestGetHeal", source.get_path() if source else NodePath(), heal_amount)
		return

	applyHeal(source, heal_amount)



remote func requestGetHeal(source_path:NodePath, heal_amount:float) -> void:
	if !get_tree().is_network_server():
		return
	var source = get_node_or_null(source_path) if source_path != NodePath() else null
	applyHeal(source, heal_amount)
func applyHeal(source:Node,heal_amount:float)->void:
	var total_heal=heal_amount
	if source and source.is_in_group("Entity") and source.has_node("Stats"):
		total_heal*=1.0+(getTotalAttribute("vitality")*0.05)

	if isParentPlayer():
		if parent.movement_mode=="crawling":
			health+=total_heal*0.3
			parent.is_downed=false
			parent.is_dead=false
		elif parent.is_downed:
			health+=total_heal*0.3
			if parent.has_method("startGetUpSequence"):
				parent.startGetUpSequence()
			parent.animation_tree.active=true
			parent.is_downed=false
			parent.is_dead=false
		else:
			health+=total_heal
	else:
		health+=total_heal

	if health>max_health: health=max_health

	var is_self=(source==parent)

	if isParentPlayer():
		# Only the victim (if a real player, not a bot) or the real player
		# who caused the heal ever see floating heal text. A bot healing
		# itself must never show text on anyone's screen -- this used to
		# always route to parent's own network_master, which for a bot is
		# the server (peer 1), so a self-hosting player saw every bot's
		# self-heals.
		if !parent.is_in_group("BOT"):
			broadcastHealText({"heal":total_heal})

		if is_instance_valid(source) and source != parent and source.is_in_group("Player") and !source.is_in_group("BOT"):
			var source_stats = source.get_node_or_null("Stats")
			if is_instance_valid(source_stats):
				source_stats._sendHealTextToPeer(source.get_network_master(), {"heal":total_heal})

		if !parent.is_in_group("BOT"):
			var chat= parent.chat
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
		if !parent.is_in_group("BOT"):
			if is_instance_valid(parent.character):
				parent.character_bars.updateBars()
	elif source and source.is_in_group("Player") and !source.is_in_group("BOT"):
		var floating_res=Global.FloatingResScene.instance()
		if floating_res:
			floating_res.text="HEAL\n"+str(int(round(total_heal)))
			floating_res.use_screen_center=false
			var crosshair=$"../UI/CrossairInspect"
			if is_instance_valid(crosshair):
				crosshair.add_child(floating_res)
	_pushStatsToOwner()
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
	Global.setAnimLock(parent,"flinch",false)
	Global.setAnimLock(parent,"knocked down",false)
	Global.setAnimLock(parent,"knocked back",false)
	parent.has_anim_lock = false


func selfBuff():
	var skill_name = parent.current_skill
	if Global != null and Global.status_effects is Dictionary and Global.status_effects.has(skill_name):
		if Global.status_effects[skill_name] is Dictionary:
			for status_name in Global.status_effects[skill_name]:
				if isBeneficialStatus(skill_name):
					applyBuffDebuff(skill_name,parent)
						
						
						
var loot_owner_names := [] # entity_names allowed to loot this corpse (killer + killer's party)

var _death_xp_granted := false
func getKilled(attacker:Node = null) -> void:
	if health <= 0:
		purify()
		exhaust()
		Global.setCorpseCollisionState(parent, true)
		if isParentPlayer():
			if health <= 0:
				if parent.is_dead == false:
					if "anim_locks" in parent and typeof(parent.anim_locks) == TYPE_DICTIONARY:
						for key in parent.anim_locks.keys():
							parent.anim_locks[key] = false
							parent.current_skill = ""
					if "current_skill" in parent:
						parent.current_skill = "none"
					if "last_active_skill" in parent:
						parent.last_active_skill = ""
					if "root_motion_active" in parent:
						parent.root_motion_active = false
					Global.setAnimLock(parent, "downed", true)
					parent.is_downed = true
		else:
			if loot_owner_names.empty():
				loot_owner_names = Global.computeLootOwners(attacker)
			grantKillExperience(attacker)

func grantKillExperience(attacker:Node) -> void:
	if _death_xp_granted:
		return
	if attacker == null or !is_instance_valid(attacker):
		return
	if !attacker.is_in_group("Player"):
		return

	var attacker_stats = attacker.get_node_or_null("Stats")
	if !is_instance_valid(attacker_stats):
		return

	_death_xp_granted = true

	var reward = computeMobKillExperience(level, attacker_stats.level)
	if reward > 0:
		attacker_stats.getExperience(reward)

	_notifyQuestKill(attacker)



func _notifyQuestKill(attacker:Node) -> void:
	var groups = parent.get_groups() # the mob that just died, not the attacker

	if get_tree().network_peer == null:
		var quest_system = attacker.get_node_or_null("UI/QuestSystem")
		if is_instance_valid(quest_system) and quest_system.has_method("registerKill"):
			quest_system.registerKill(groups)
		return

	var peer_id = attacker.get_network_master() if attacker.has_method("get_network_master") else 0
	if peer_id == get_tree().get_network_unique_id():
		var quest_system = attacker.get_node_or_null("UI/QuestSystem")
		if is_instance_valid(quest_system) and quest_system.has_method("registerKill"):
			quest_system.registerKill(groups)
	else:
		rpc_id(peer_id, "clientRegisterQuestKill", attacker.get_path(), groups)

	shareQuestKillWithParty(attacker, groups)
func shareExperienceWithParty(experienceToGain:int) -> void:
	if get_tree().network_peer != null and !get_tree().is_network_server():
		return
	if !("entity_name" in parent) or parent.entity_name == "":
		return

	if parent.is_in_group("BOT"):
		var shared_bot := int(ceil(experienceToGain * 0.7))
		if shared_bot <= 0:
			return
		for owner_name in Global.findPartyOwnersOfMember(parent.entity_name):
			if owner_name == parent.entity_name:
				continue
			var owner_node = Global.findEntityNodeByName(owner_name)
			if !is_instance_valid(owner_node):
				continue
			var owner_stats = owner_node.stats
			if is_instance_valid(owner_stats):
				owner_stats._grantExperienceDirect(shared_bot)
		return

	var roster = Global.party_rosters.get(parent.entity_name, [])
	if roster.empty():
		return

	var shared_amount = int(ceil(experienceToGain * 0.7))
	if shared_amount <= 0:
		return

	for member in roster:
		var member_name = str(member.get("entity_name",""))
		if member_name == "" or member_name == parent.entity_name:
			continue
		var member_node = Global.findEntityNodeByName(member_name)
		if !is_instance_valid(member_node):
			continue
		var member_stats = member_node.get_node_or_null("Stats")
		if !is_instance_valid(member_stats):
			continue
		member_stats._grantExperienceDirect(shared_amount)

func shareQuestKillWithParty(attacker:Node, groups:Array) -> void:
	if !get_tree().is_network_server():
		return # party_rosters only lives/authoritative server-side
	if !("entity_name" in attacker) or attacker.entity_name == "":
		return

	var roster = Global.party_rosters.get(attacker.entity_name, [])
	if roster.empty():
		return

	for member in roster:
		var member_name = str(member.get("entity_name",""))
		if member_name == "" or member_name == attacker.entity_name:
			continue # attacker already credited above

		var member_node = Global.getPlayerNode(member_name)
		if !is_instance_valid(member_node):
			continue

		var member_peer = member_node.get_network_master()
		if member_peer == get_tree().get_network_unique_id():
			var quest_system = member_node.get_node_or_null("UI/QuestSystem")
			if is_instance_valid(quest_system) and quest_system.has_method("registerKill"):
				quest_system.registerKill(groups)
		else:
			rpc_id(member_peer, "clientRegisterQuestKill", member_node.get_path(), groups)


remote func clientRegisterQuestKill(attacker_path:NodePath, groups:Array) -> void:
	var attacker = get_node_or_null(attacker_path)
	if !is_instance_valid(attacker) or !attacker.has_method("isLocalPlayer") or !attacker.isLocalPlayer():
		return
	var quest_system = attacker.get_node_or_null("UI/QuestSystem")
	if is_instance_valid(quest_system) and quest_system.has_method("registerKill"):
		quest_system.registerKill(groups)







func computeMobKillExperience(mob_level:int, player_level:int) -> int:
	var xp_to_next_level = 250.0 * (1.0 + pow(float(max(player_level, 0)) / 10.0, 1.5))
	var diff = mob_level - player_level # positive: mob is higher level
	var percent = 0.0

	if player_level <= 5:
		if diff >= 0:
			percent = 0.03
		elif diff == -1:
			percent = 0.03
		elif diff == -2:
			percent = 0.02
		elif diff == -3:
			percent = 0.01
		elif diff == -4:
			percent = 0.005
		else:
			percent = 0.0
	else:
		var base = 0.0085
		if diff >= 0:
			percent = base * (1.0 + 0.5 * diff)
		else:
			percent = base * max(0.0, 1.0 + 0.5 * diff)

	return int(round(xp_to_next_level * percent))









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
export var level:int = 0
puppet var net_experience_points:int = 0
puppet var net_level:int = 0
func levelingSystem():
	if get_tree().network_peer != null and !isAuthority():
		return
	while experience_points>=250*(1.0+pow(level/10.0,1.5)):
		experience_points-=int(round(250.0*(1.0+pow(level/10.0,1.5))))
		level+=1
		available_attribute_points+=1
		skill_points += 1


func getExperience(experienceToGain:int):
	if _shouldRouteThroughAuthority():
		rpc_id(_authorityId(), "requestGetExperience", experienceToGain)
		return
	_applyExperience(experienceToGain)

remote func requestGetExperience(experienceToGain:int) -> void:
	if !get_tree().is_network_server():
		return
	_applyExperience(experienceToGain)

#  the one place XP is ever actually
# applied (getExperience() already routes every caller here through
# _shouldRouteThroughAuthority(), so this only ever runs once, server-side).
# Now also fans 70% (rounded up) out to party members, and pushes the new
# totals to the owning client immediately instead of waiting on MobSync.
func _applyExperience(experienceToGain:int) -> void:
	experience_points += experienceToGain
	levelingSystem()
	net_experience_points = experience_points
	net_level = level
	net_available_attribute_points = available_attribute_points
	_broadcastExperienceMessage(experienceToGain)
	_pushExperienceToOwner()

	if isParentPlayer():
		shareExperienceWithParty(experienceToGain)

	if isParentPlayer() and !parent.is_in_group("BOT") and isLocalOwner() and is_instance_valid(bar):
		bar.updateBars()




# Applies XP to THIS entity only -- deliberately does NOT call
# shareExperienceWithParty(). If it did, a mutual party (A has B in
# their roster and B has A in theirs, the normal case) would bounce every
# gain back and forth forever: A shares to B, B's grant shares back to A,
# and so on -- decaying by 0.7 each hop but never actually stopping.
# Direct grants are a dead end by design: exactly one hop, no cascade.
func _grantExperienceDirect(amount:int) -> void:
	experience_points += amount
	levelingSystem()
	net_experience_points = experience_points
	net_level = level
	net_available_attribute_points = available_attribute_points
	_broadcastExperienceMessage(amount)
	_pushExperienceToOwner()

	if isParentPlayer() and !parent.is_in_group("BOT") and isLocalOwner() and is_instance_valid(bar):
		bar.updateBars()


# Pushes the freshly-updated totals straight to the entity's owning
# client instead of waiting for MobSync's next periodic full-sync tick
# (up to ~1s away -- see MobSync.gd, xp/level removed from that payload
# entirely now that this exists). If the owner IS the server (hosting
# your own player), nothing needs sending -- experience_points is already
# the live authoritative value on that same node.
func _pushExperienceToOwner() -> void:
	if !isParentPlayer():
		return
	if get_tree().network_peer == null or !get_tree().is_network_server():
		return
	var peer_id = parent.get_network_master()
	if peer_id == get_tree().get_network_unique_id():
		return
	rpc_id(peer_id, "receiveExperienceSync", experience_points, level, available_attribute_points)

remote func receiveExperienceSync(experience:int, lvl:int, avail_points:int) -> void:
	if !parent.has_method("isLocalPlayer") or !parent.isLocalPlayer():
		return
	net_experience_points = experience
	net_level = lvl
	net_available_attribute_points = avail_points
	_has_received_stats_sync = true # _applyPuppetStats() picks these up next physics frame







func _broadcastExperienceMessage(amount:int) -> void:
	if !isParentPlayer():
		return
	if parent.is_in_group("BOT"):
		return
	var peer_id = parent.get_network_master()
	if get_tree().network_peer == null or peer_id == get_tree().get_network_unique_id():
		if is_instance_valid(parent.chat):
			parent.chat.sendSystemMessage("gained " + str(amount) + " experience")
	else:
		rpc_id(peer_id, "clientShowExperienceMessage", amount)

remote func clientShowExperienceMessage(amount:int) -> void:
	if is_instance_valid(parent) and is_instance_valid(parent.chat):
		parent.chat.sendSystemMessage("gained " + str(amount) + " experience")








var available_attribute_points:int = 10

func resetAttributePoints():
	available_attribute_points=10+level
	for key in attribute_points_spent:
		attribute_points_spent[key]=0

func regenerate(value, resource, max_resource):
	return min(resource + value, max_resource)
		

func _sendHealTextToPeer(peer_id:int, heals:Dictionary) -> void:
	if get_tree().network_peer == null or peer_id == get_tree().get_network_unique_id():
		spawnHealText(heals)
	else:
		rpc_id(peer_id, "clientShowHealText", heals)
func spawnHealText(heals: Dictionary) -> void:
	var text := "HEAL\n"

	for k in heals:
		text += str(int(round(heals[k]))) + "\n"

	var floating_res = Global.FloatingResScene.instance()
	floating_res.text = text.strip_edges()

	if isParentPlayer():
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
func broadcastHealText(heals:Dictionary) -> void:
	if isParentPlayer():
		_sendHealTextToPeer(parent.get_network_master(), heals)

remote func clientShowHealText(heals:Dictionary) -> void:
	spawnHealText(heals)
func broadcastDamageText(damages:Dictionary, is_crit:bool, is_penetrating_hit:bool, attacker:Node) -> void:
	# Damage DEALT: shown only to the attacking player, and only if the
	# attacker is a real player (never bots, never mob-on-mob/mob-on-bot).
	if is_instance_valid(attacker) and attacker.is_in_group("Player") and !attacker.is_in_group("BOT"):
		sendDamageTextToPeer(attacker.get_network_master(), damages, is_crit, is_penetrating_hit)

	# Damage TAKEN: shown to the victim (this Stats node's own parent),
	# and only if the victim is a real player (never bots, never mobs).
	if isParentPlayer() and !parent.is_in_group("BOT"):
		var victim_peer = parent.get_network_master()
		var attacker_already_sent = is_instance_valid(attacker) and attacker.is_in_group("Player") and !attacker.is_in_group("BOT") and attacker.get_network_master() == victim_peer
		if !attacker_already_sent:
			sendDamageTextToPeer(victim_peer, damages, is_crit, is_penetrating_hit)



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

	var floating_res=Global.FloatingResScene.instance()
	if floating_res==null:return

	floating_res.text=text.strip_edges()

	if isParentPlayer():
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

func sendDamageTextToPeer(peer_id:int, damages:Dictionary, is_crit:bool, is_penetrating_hit:bool) -> void:
	if get_tree().network_peer == null or peer_id == get_tree().get_network_unique_id():
		spawnDamageText(damages, is_crit, is_penetrating_hit)
	else:
		rpc_id(peer_id, "clientShowDamageText", damages, is_crit, is_penetrating_hit)
