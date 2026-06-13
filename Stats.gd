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


func _physics_process(delta): 
	updateAttributes()
	rebuildOnHitEffects()
	updateStatuses(delta)
	if not parent.is_in_combat:
			health = regenerate(derived_stats["health_regeneration"],health,max_health)
			energy = regenerate(derived_stats["energy_regeneration"],energy,max_energy)
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


func updateStatusGrid(grid:GridContainer, source)->void:
	if grid == null or source == null:
		return

	var template:TextureRect = grid.get_node("Icon1")

	for child in grid.get_children():
		if child != template:
			child.queue_free()

	template.visible = false

	for status_name in source.statuses.keys():

		if !Skills.status_icons.has(status_name):
			continue

		var s = source.statuses[status_name]

		if typeof(s) == TYPE_ARRAY:
			for entry in s:
				var icon = template.duplicate()
				icon.visible = true
				icon.name = "Icon_" + status_name
				icon.texture = Skills.status_icons[status_name]

				var label = icon.get_node("Label")
				if label:
					label.text = str(int(ceil(entry["duration"])))

				var stack_label = icon.get_node("Stack")
				if stack_label:
					var stacks = int(entry.get("stacks",1))
					stack_label.text = "" if stacks <= 1 else str(stacks)

				grid.add_child(icon)
		else:
			var icon = template.duplicate()
			icon.visible = true
			icon.name = "Icon_" + status_name
			icon.texture = Skills.status_icons[status_name]

			var label = icon.get_node("Label")
			if label:
				label.text = str(int(ceil(s["duration"])))

			var stack_label = icon.get_node("Stack")
			if stack_label:
				var stacks = int(s.get("stacks",1))
				stack_label.text = "" if stacks <= 1 else str(stacks)

			grid.add_child(icon)


			
func _process(delta):
	if Input.is_action_just_pressed("7"):
		if parent.is_in_group("Player"):
			parent.current_skill = "base attack"
			for status_name in Skills.status_effects[parent.current_skill]:
					parent.get_node("Stats").applyStatus(status_name,parent,parent.current_skill)
	
	
	if is_instance_valid($"../StatusesLabel"):
		var label =  $"../StatusesLabel"

		if statuses.empty():
			label.text = ""
			return

		var text := ""

		for status_name in statuses.keys():
			var s = statuses[status_name]

			if typeof(s) == TYPE_ARRAY:
				for entry in s:
					if typeof(entry) != TYPE_DICTIONARY:
						continue
					text += status_name + " (" + str(ceil(entry.get("duration", 0.0))) + ")\n"
			else:
				text += status_name + " (" + str(ceil(s.get("duration", 0.0))) + ")\n"
		label.text = text.strip_edges()
var statuses = {}
func applyStatus(status_name:String, applier:Node = null, current_skill:String = "")->void:
	if !Skills.status_effects.has(current_skill):
		return
	if !Skills.status_effects[current_skill].has(status_name):
		return

	var data = Skills.status_effects[current_skill][status_name]

	var stackable:bool = data.get("can_stack", false)
	var final_duration:float = data.get("duration", 0.0)
	var tick_damage:float = data.get("base_damage", 0.0)
	var affects:Array = data.get("affects", [])
	var tick_interval:float = data.get("tick_timer", 1.0)

	var applier_name:String = ""
	if applier != null and is_instance_valid(applier):
		applier_name = applier.name

	if !stackable:
		if statuses.has(status_name):
			var s = statuses[status_name]
			if typeof(s) == TYPE_DICTIONARY:
				s["duration"] = max(s.get("duration", 0.0), final_duration)
				return
			else:
				statuses.erase(status_name)

		statuses[status_name] = {
			"duration": final_duration,
			"tick_timer": tick_interval,
			"tick_interval": tick_interval,
			"skill": current_skill,
			"applier_name": applier_name,
			"tick_damage": tick_damage,
			"power": data.get("power", 0.0),
			"affects": affects,
			"stacks": 1
		}
		return

	if !statuses.has(status_name):
		statuses[status_name] = []
	elif typeof(statuses[status_name]) != TYPE_ARRAY:
		var old = statuses[status_name]
		statuses[status_name] = []
		if typeof(old) == TYPE_DICTIONARY:
			statuses[status_name].append(old)

	var list = statuses[status_name]
	var merged := false

	for i in range(list.size()):
		var entry = list[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		if entry.get("applier_name", "") == applier_name and entry.get("skill","") == current_skill:
			var new_stacks = int(entry.get("stacks", 1)) + 1

			if data.has("max_stacks"):
				new_stacks = min(new_stacks, int(data["max_stacks"]))

			entry["stacks"] = new_stacks
			entry["duration"] = max(entry.get("duration", 0.0), final_duration)
			entry["tick_damage"] = tick_damage * entry["stacks"]
			entry["power"] = data.get("power", 0.0) * entry["stacks"]
			entry["affects"] = affects

			merged = true
			break

	if !merged:
		list.append({
			"duration": final_duration,
			"tick_timer": tick_interval,
			"tick_interval": tick_interval,
			"skill": current_skill,
			"applier_name": applier_name,
			"tick_damage": tick_damage,
			"power": data.get("power", 0.0),
			"affects": affects,
			"stacks": 1
		})


func updateStatuses(delta:float)->void:
	var statuses_to_remove=[]

	for status_name in statuses.keys():
		var status_data=statuses[status_name]

		if typeof(status_data)==TYPE_ARRAY:
			for i in range(status_data.size()-1,-1,-1):
				var entry=status_data[i]
				if typeof(entry)!=TYPE_DICTIONARY:
					continue

				entry["duration"]-=delta
				entry["tick_timer"]-=delta

				var applier=entry.get("applier",null)
				var power=float(entry.get("power",0.0))
				var tick_interval=float(entry.get("tick_interval",1.0))

				if status_name=="bleed" and entry["tick_timer"]<=0.0:
					getHit(applier if applier!=null else self,{damage_type.bleed:entry.get("tick_damage",power)},false,0.0,false)
					entry["tick_timer"]=tick_interval

				elif status_name.begins_with("heal") and entry["tick_timer"]<=0.0:
					getHeal(applier if applier!=null else self,power)
					entry["tick_timer"]=tick_interval

				if entry["duration"]<=0.0:
					status_data.remove(i)

			if status_data.size()==0:
				statuses_to_remove.append(status_name)

		else:
			var entry=status_data

			if typeof(entry)!=TYPE_DICTIONARY:
				statuses_to_remove.append(status_name)
				continue

			entry["duration"]-=delta
			entry["tick_timer"]-=delta

			var applier=entry.get("applier",null)
			var power=float(entry.get("power",0.0))
			var tick_interval=float(entry.get("tick_interval",1.0))

			if status_name=="bleed" and entry["tick_timer"]<=0.0:
				getHit(applier if applier!=null else self,{damage_type.bleed:entry.get("tick_damage",power)},false,0.0,false)
				entry["tick_timer"]=tick_interval

			elif status_name.begins_with("heal") and entry["tick_timer"]<=0.0:
				getHeal(applier if applier!=null else self,power)
				entry["tick_timer"]=tick_interval

			if entry["duration"]<=0.0:
				statuses_to_remove.append(status_name)

	for status_name in statuses_to_remove:
		removeStatus(status_name)

	updateStatusGrid(player_status_grid,self)

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
	
	
	
func getTotalAttribute(name:String)->float:
	var base = attributes.get(name,1.0) + equipment_attributes.get(name,0.0)

	if name == "agility" and statuses.has("slow"):
		var slow_total := 0.0

		var s = statuses["slow"]
		if typeof(s) == TYPE_ARRAY:
			for e in s:
				slow_total += float(e.get("power", 0.0))
		else:
			slow_total = float(s.get("power", 0.0))

		var mult = 1.0 - slow_total
		if mult < 0.01:
			mult = 0.01

		return base * mult

	return base








func updateAttributes():
	max_arcane = 100 + getTotalAttribute("wisdom") * 10
	max_health = base_max_health +getTotalAttribute("vitality") * 20
	walk_speed = base_walk_speed + getTotalAttribute("agility") * 0.2
	run_speed = base_run_speed + getTotalAttribute("agility") * 0.4

	for k in defences:
		defences[k] = getTotalAttribute("toughness") * 2.0

	derived_stats["attack_speed"] = getTotalAttribute("dexterity")

	derived_stats["cooldown_reduction"] = (getTotalAttribute("haste") * 0.85 +getTotalAttribute("instinct") * 0.10 +getTotalAttribute("wisdom") * 0.05)

	derived_stats["climb_speed"] = 1.0 + getTotalAttribute("dexterity") * 0.20 + getTotalAttribute("strength") * 0.80
	derived_stats["swim_speed"] = 1.0 + getTotalAttribute("strength") * 0.55 + getTotalAttribute("agility") * 0.45

	derived_stats["run_speed"] = 16.0 * (getTotalAttribute("haste") + getTotalAttribute("agility") * 0.45)

	derived_stats["fall_resistance"] = getTotalAttribute("toughness") * 0.75 + getTotalAttribute("agility") * 0.25

	derived_stats["turn_speed"] = 4.0 + getTotalAttribute("agility")
	derived_stats["atk_turn_speed"] = 0.15 + getTotalAttribute("agility") * 0.3
	derived_stats["dash_turn_speed"] = 7.0 + getTotalAttribute("agility") * 3.0

	derived_stats["jump_power"] = 1.0 + getTotalAttribute("power") * 3.6 + getTotalAttribute("agility") * 3.6

	derived_stats["crit_chance"] = 0.05 + getTotalAttribute("instinct") * 0.02
	derived_stats["penetrating_hit_chance"] = 0.05 + getTotalAttribute("wisdom") * 0.02
	derived_stats["penetration_power"] = 0.1 * getTotalAttribute("power") * 0.25 + getTotalAttribute("strength") * 0.25
	derived_stats["crit_damage"] = 2.0 + getTotalAttribute("power") * 0.05

	derived_stats["detection_range"] = 10.0 + getTotalAttribute("perception") * 2.0
	derived_stats["energy_regeneration"] = 1.0 + getTotalAttribute("toughness") 
	derived_stats["health_regeneration"] = 0 + (getTotalAttribute("vitality") * 0.1)
	derived_stats["threat"] = getTotalAttribute("authority")

	health = min(health, max_health)
	arcane = min(arcane, max_arcane)

	updateCombatAttributes()
	
	var slow :float = 1.0

	if statuses.has("slow"):
		var s = statuses["slow"]
		var power :float = 0.0

		if typeof(s) == TYPE_ARRAY:
			for e in s:
				power += float(e.get("power", 0.0))
		else:
			power = float(s.get("power", 0.0))

		slow = clamp(1.0 - power, 0.01, 1.0)

	walk_speed *= slow
	run_speed *= slow
	derived_stats["run_speed"] *= slow
	derived_stats["swim_speed"] *= slow
	derived_stats["climb_speed"] *= slow



func updateCombatAttributes():
	var toughness_total=getTotalAttribute("toughness")
	var toughness_bonus=(toughness_total-1.0)*50.0
	# 1. base values
	var base_slash = defences[damage_type.slash] + toughness_bonus + equipment_defence_bonus[damage_type.slash]
	var base_blunt = defences[damage_type.blunt] + toughness_bonus + equipment_defence_bonus[damage_type.blunt]
	var base_pierce = defences[damage_type.pierce] + toughness_bonus + equipment_defence_bonus[damage_type.pierce]
	var base_sonic = defences[damage_type.sonic] + toughness_bonus + equipment_defence_bonus[damage_type.sonic]
	var base_heat = defences[damage_type.heat] + toughness_bonus + equipment_defence_bonus[damage_type.heat]
	var base_cold = defences[damage_type.cold] + toughness_bonus + equipment_defence_bonus[damage_type.cold]
	var base_jolt = defences[damage_type.jolt] + toughness_bonus + equipment_defence_bonus[damage_type.jolt]
	var base_toxic = defences[damage_type.toxic] + toughness_bonus + equipment_defence_bonus[damage_type.toxic]
	var base_acid = defences[damage_type.acid] + toughness_bonus + equipment_defence_bonus[damage_type.acid]
	var base_arcane = defences[damage_type.arcane] + toughness_bonus + equipment_defence_bonus[damage_type.arcane]
	var base_bleed = defences[damage_type.bleed] + toughness_bonus + equipment_defence_bonus[damage_type.bleed]
	var base_radiant = defences[damage_type.radiant] + toughness_bonus + equipment_defence_bonus[damage_type.radiant]

	# 2. apply armor_break (multiplicative, fully safe)
	if statuses.has("armor_break") and typeof(statuses["armor_break"]) == TYPE_ARRAY:

		var armor_break_instances = statuses["armor_break"]
		var armor_break_power = 0.0
		var affects = []

		for entry in armor_break_instances:

			if typeof(entry) != TYPE_DICTIONARY:
				continue

			armor_break_power += float(entry.get("power", 0.0))

			if affects.size() == 0:
				var a = entry.get("affects", [])
				if typeof(a) == TYPE_ARRAY:
					affects = a

		armor_break_power = clamp(armor_break_power, 0.0, 1.0)

		for stat in affects:
			match stat:
				"slash_defence": base_slash *= (1.0 - armor_break_power)
				"blunt_defence": base_blunt *= (1.0 - armor_break_power)
				"pierce_defence": base_pierce *= (1.0 - armor_break_power)
				"sonic_defence": base_sonic *= (1.0 - armor_break_power)
				"heat_defence": base_heat *= (1.0 - armor_break_power)
				"cold_defence": base_cold *= (1.0 - armor_break_power)
				"jolt_defence": base_jolt *= (1.0 - armor_break_power)
				"toxic_defence": base_toxic *= (1.0 - armor_break_power)
				"acid_defence": base_acid *= (1.0 - armor_break_power)
				"arcane_defence": base_arcane *= (1.0 - armor_break_power)
				"bleed_defence": base_bleed *= (1.0 - armor_break_power)
				"radiant_defence": base_radiant *= (1.0 - armor_break_power)


	# 3. apply decrease_armor (flat, fully safe)
	if statuses.has("decrease_armor") and typeof(statuses["decrease_armor"]) == TYPE_ARRAY:

		var decrease_instances = statuses["decrease_armor"]
		var decrease_amount = 0.0
		var affects = []

		for entry in decrease_instances:

			if typeof(entry) != TYPE_DICTIONARY:
				continue

			decrease_amount += float(entry.get("power", 0.0))

			if affects.size() == 0:
				var a = entry.get("affects", [])
				if typeof(a) == TYPE_ARRAY:
					affects = a

		for stat in affects:
			match stat:
				"cold_defence":
					base_cold = max(base_cold - decrease_amount, 0.0)

	# 4. assign final values
	slash_defence = base_slash
	blunt_defence = base_blunt
	pierce_defence = base_pierce
	sonic_defence = base_sonic
	heat_defence = base_heat
	cold_defence = base_cold
	jolt_defence = base_jolt
	toxic_defence = base_toxic
	acid_defence = base_acid
	arcane_defence = base_arcane
	bleed_defence = base_bleed
	radiant_defence = base_radiant
	
	
	var strength_total=getTotalAttribute("strength")
	var power_total=getTotalAttribute("power")
	

	var strength_bonus=strength_total-1.0
	var power_bonus=power_total-1.0
	
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

		for skill in Skills.skills:

			if Skills.skills[skill] == null:
				continue

			if Skills.skills[skill].resource_path != texture_path:
				continue

			if skill != skill_name:
				break

			if "skill_level" in child:
				return int(child.skill_level)

			return 0

	return 0


func getSkillLevelMultiplier(skill_name:String) -> float:
	return Skills.getDamageMultiplier(
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
	var area:Area = null

	if parent.is_in_group("Player") or parent.is_in_group("player"):
		area = $"../character/root/Skeleton/WeaponR/Short"
	else:
		area = $"../AreaDamage"

	if area == null:
		return

	var damages = {}

	var skill_name:String = ""
	var skill_level_mult:float = 1.0

	if parent.is_in_group("Player") or parent.is_in_group("player"):
		skill_name = parent.current_skill
		skill_level_mult = getSkillLevelMultiplier(skill_name)

		var skill_damages = Skills.getDamages(skill_name)

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

	var total_damage:float= 0.0
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
			other_stats.getHit(parent, damages, is_penetrating_hit, 0.0, is_crit)
			for status_name in Skills.status_effects[skill_name]:
				other_stats.applyStatus(status_name,parent,skill_name)
			var skillbar = $"../UI/Skillbar"
			if parent.is_in_group("Player") or parent.is_in_group("player"):
				Skills.applyOnHitEffects(skill_name,active_on_hit_effects,skillbar.active_cooldowns,my_stats,total_damage)



func getHit(attacker:Node,damages:Dictionary,is_penetrating_hit:bool,extra_threat:float,is_crit:bool=false)->void:
	parent.is_in_combat == true
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
		if attacker != null:
			if attacker.is_in_group("Entity"):
				var instigatorAggro=parent.get_or_create_aggro_target(attacker)
				instigatorAggro.aggro+=((total_damage*attacker.stats.derived_stats["threat"]))

	health-=total_damage
	
	if attacker != null and attacker.is_in_group("Entity"):
		if parent.stats.health>0:
			attacker.stored_body=parent
		else:
			attacker.stored_body=null

	if is_instance_valid($"../UI/Menu/CharacterBar"):
		$"../UI/Menu/CharacterBar".updateBars()

	spawnDamageText(final_damages,is_crit,is_penetrating_hit)


func getHeal(source:Node, heal_amount:float)->void:
	var total_heal:float = heal_amount
	if source != null and source.is_in_group("Entity") and source.has_node("Stats"):
		var vitality = getTotalAttribute("vitality")
		total_heal *= 1.0 + (vitality * 0.05)

	health += total_heal

	if health > max_health:
		health = max_health

	if is_instance_valid($"../UI/Menu/CharacterBar"):
		$"../UI/Menu/CharacterBar".updateBars()

	spawnHealText({ "heal": total_heal })




func spawnDamageText(damages: Dictionary,is_crit: bool = false,is_penetrating_hit: bool = false) -> void:
	var text := ""
	if is_crit:
		text += "CRITICAL!\n"
	if is_penetrating_hit:
		text += "PENETRATING!\n"
	for dmg_type in damages:
		text += (str(round(damages[dmg_type]))+ " "+ damageTypeToString(dmg_type)+ "\n")
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
		floating_res.world_position = camera.unproject_position(parent.global_transform.origin + Vector3.UP * 2.0)
	get_tree().root.add_child(floating_res)

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
		return Skills.getArcaneCost(skill)

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
		
func serializeStatuses(statuses:Dictionary)->Dictionary:
	var out = {}

	for status_name in statuses.keys():
		var s = statuses[status_name]

		if typeof(s) == TYPE_ARRAY:
			out[status_name] = []

			for entry in s:
				if typeof(entry) != TYPE_DICTIONARY:
					continue

				out[status_name].append({
					"duration": entry.get("duration", 0.0),
					"tick_timer": entry.get("tick_timer", 1.0),
					"tick_damage": entry.get("tick_damage", 0.0),
					"power": entry.get("power", 0.0),
					"stacks": entry.get("stacks", 1)
				})

		elif typeof(s) == TYPE_DICTIONARY:
			out[status_name] = {
				"duration": s.get("duration", 0.0),
				"tick_timer": s.get("tick_timer", 1.0),
				"tick_damage": s.get("tick_damage", 0.0),
				"power": s.get("power", 0.0),
				"stacks": s.get("stacks", 1)
			}

	return out
func deserializeStatuses(data:Dictionary)->Dictionary:
	var out = {}

	for status_name in data.keys():
		var s = data[status_name]

		if typeof(s) == TYPE_ARRAY:
			out[status_name] = []

			for entry in s:
				if typeof(entry) != TYPE_DICTIONARY:
					continue

				out[status_name].append({
					"duration": entry.get("duration", 0.0),
					"tick_timer": entry.get("tick_timer", 1.0),
					"applier": null,
					"tick_damage": entry.get("tick_damage", 0.0),
					"power": entry.get("power", 0.0),
					"stacks": entry.get("stacks", 1)
				})

		elif typeof(s) == TYPE_DICTIONARY:
			out[status_name] = {
				"duration": s.get("duration", 0.0),
				"tick_timer": s.get("tick_timer", 1.0),
				"applier": null,
				"tick_damage": s.get("tick_damage", 0.0),
				"power": s.get("power", 0.0),
				"stacks": s.get("stacks", 1)
			}
	return out

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
