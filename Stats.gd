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
var base_max_energy = 100
var base_max_arcane = 100
var base_walk_speed = 3
var base_run_speed = 7





var available_attribute_points:int = 0
var attributes = {
	"strength": 1,
	"power": 1,
	"impact": 1,
	"agility": 1,
	"dexterity": 1,
	"balance": 1,
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
	"run_speed": 7.0,
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
	attributes[attribute_name] = getAttributeValue(attribute_points_spent[attribute_name])

	updateAttributes()
func decreaseAttribute(attribute_name:String) -> void:
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
	updateAttributes()
func regenerations()->void:
	if parent.is_in_group("Entity"):
		if parent.is_in_combat == false:
			if health >0:
				health = regenerate(derived_stats["health_regeneration"],health,max_health)
				energy = regenerate(derived_stats["energy_regeneration"],energy,max_energy)
func _physics_process(delta):
	if Engine.get_physics_frames() % 60 == 0:
		regenerations()
		updateBuffDebuffs()
		if health <=0:
			purify()
			exhaust()
	updateAttributes()
	rebuildOnHitEffects()
	updateStatuses(delta)
	if Input.is_action_just_pressed("up"):
		cleanse()
	if Input.is_action_just_pressed("down"):
		dispell()
	if Input.is_action_just_pressed("ui_left"):
		purify()
	if Input.is_action_just_pressed("ui_right"):
		exhaust()
	if Input.is_action_just_pressed("debug_attributes"):
		dispell()
		energy = 0 
		var uistats = $"../UI/Equipment/UIStats"
		if is_instance_valid(uistats):
			uistats.updateUI()
		increaseAttribute(selected_attribute)
		updateAttributes()
		var label = $"../Label"
		if is_instance_valid(label):label.text = (selected_attribute+ ": "+ str(stepify(attributes[selected_attribute], 0.01)))
	if Input.is_action_pressed("give_att"):
		var uistats = $"../UI/Equipment/UIStats"
		if is_instance_valid(uistats):uistats.updateUI()
		available_attribute_points += 10
		updateAttributes()
		energy += max_energy/2
		if Engine.get_physics_frames() % 120 == 0:
			debugDamage()

const ATTRIBUTE_STEP := 0.05
const MIN_ATTRIBUTE := 0.25



var attribute_points_spent = {
	"strength": 0,
	"power": 0,
	"impact": 0,
	"agility": 0,
	"dexterity": 0,
	"balance": 0,
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


func updateStatusGrid(grid:GridContainer,source)->void:
	if grid==null or source==null:return
	var template:TextureRect=grid.get_node("Icon1")
	for child in grid.get_children():
		if child!=template:child.queue_free()
	template.visible=false

	var status_value
	var icon_instance:TextureRect
	var duration_label
	var stack_label
	var stack_value:int

	for status_name in source.statuses.keys():

		status_value=source.statuses[status_name]

		if typeof(status_value)==TYPE_ARRAY:
			for status_entry in status_value:
				if typeof(status_entry)!=TYPE_DICTIONARY:continue
				if !Skills.status_icons.has(status_name):
					for category_name in ["flasks","consumables","materials","weapons","armors","accessories"]:
						if Items.get(category_name).has(status_name):
							Skills.status_icons[status_name]=Items.get(category_name)[status_name]["icon"]
							break
					if !Skills.status_icons.has(status_name):continue

				icon_instance=template.duplicate()
				icon_instance.visible=true
				icon_instance.name="Icon_"+status_name
				icon_instance.texture=Skills.status_icons[status_name]

				duration_label=icon_instance.get_node("Label")
				if duration_label:duration_label.text=str(int(ceil(status_entry.get("duration",0.0))))

				stack_label=icon_instance.get_node("Stack")
				if stack_label:
					stack_value=0
					for entry in status_value:
						if typeof(entry)!=TYPE_DICTIONARY:continue
						stack_value+=int(entry.get("stacks",1))
					stack_label.text="" if stack_value<=1 else str(stack_value)

				grid.add_child(icon_instance)

		elif typeof(status_value)==TYPE_DICTIONARY:
			if !Skills.status_icons.has(status_name):
				for category_name in ["flasks","consumables","materials","weapons","armors","accessories"]:
					if Items.get(category_name).has(status_name):
						Skills.status_icons[status_name]=Items.get(category_name)[status_name]["icon"]
						break
				if !Skills.status_icons.has(status_name):continue

			icon_instance=template.duplicate()
			icon_instance.visible=true
			icon_instance.name="Icon_"+status_name
			icon_instance.texture=Skills.status_icons[status_name]

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
			for category_name in ["flasks","consumables","materials","weapons","armors","accessories"]:
				if Items.get(category_name).has(icon_key):
					Skills.status_icons[icon_key]=Items.get(category_name)[icon_key]["icon"]
					break
			if !Skills.status_icons.has(icon_key):continue

		icon_instance=template.duplicate()
		icon_instance.visible=true
		icon_instance.name="Icon_"+icon_key
		icon_instance.texture=Skills.status_icons[icon_key]

		duration_label=icon_instance.get_node("Label")
		if duration_label:duration_label.text=str(int(ceil(status_value.get("duration",0.0))))

		stack_label=icon_instance.get_node("Stack")
		if stack_label:
			if status_value.has("stackable") and status_value["stackable"]==false:
				stack_label.text=""
			else:
				stack_value=int(status_value.get("stacks",1))
				stack_label.text="" if stack_value<=1 else str(stack_value)

		grid.add_child(icon_instance)

var statuses={}
var status_attribute_modifiers={}
var debuff_buffs_active={}
func serializeBuffDebuffs()->Dictionary:
	var out={}
	for buff_name in debuff_buffs_active.keys():
		var b=debuff_buffs_active[buff_name]
		out[buff_name]={
	"duration":b.get("duration",0.0),
	"stacks":b.get("stacks",1),
	"stackable":b.get("stackable",false),
	"regen_timer":b.get("regen_timer",1.0),
	"dot_timer":b.get("dot_timer",0.0),
	"dot timer":b.get("dot timer",0.0),
	"damage ammount":b.get("damage ammount",0.0),
	"damage type":b.get("damage type",null)
}
		var a=b.get("attributes",{})
		if typeof(a)==TYPE_DICTIONARY:out[buff_name]["attributes"]=a
	return out
func deserializeBuffDebuffs(data:Dictionary)->Dictionary:
	var out={}
	for k in data.keys():
		var b=data[k]
		out[k]={
	"duration":b.get("duration",0.0),
	"stackable":b.get("stackable",false),
	"stacks":b.get("stacks",1),
	"regen_timer":b.get("regen_timer",1.0),
	"dot_timer":b.get("dot_timer",0.0),
	"dot timer":b.get("dot timer",0.0),
	"damage ammount":b.get("damage ammount",0.0),
	"damage type":b.get("damage type",null),
	"attributes":b.get("attributes",{})
}
	return out
	
	
var attributes_buff={
	"strength":0,"power":0,"impact":0,"agility":0,"dexterity":0,"balance":0,"vitality":0,
	"toughness":0,"instinct":0,"perception":0,"intelligence":0,
	"wisdom":0,"haste":0,"charisma":0,"authority":0
}


func applyBuffDebuff(buff_name:String)->void:
	if !Skills.debuffs_buffs.has(buff_name):return

	var buff_data=Skills.debuffs_buffs[buff_name]
	var stackable=bool(buff_data.get("stackable",false))

	if debuff_buffs_active.has(buff_name):
		debuff_buffs_active[buff_name]["duration"]=float(buff_data.get("duration",0.0))

		if stackable:
			debuff_buffs_active[buff_name]["stacks"]=int(debuff_buffs_active[buff_name].get("stacks",1))+1

			var applied_attributes={}
			var stacks=debuff_buffs_active[buff_name]["stacks"]

			for attribute_name in attributes_buff.keys():
				applied_attributes[attribute_name]=float(buff_data.get(attribute_name,0.0))*stacks

			debuff_buffs_active[buff_name]["attributes"]=applied_attributes

		return

	var applied_attributes={}

	for attribute_name in attributes_buff.keys():
		applied_attributes[attribute_name]=float(buff_data.get(attribute_name,0.0))

	var buff_instance={
	"duration":float(buff_data.get("duration",0.0)),
	"attributes":applied_attributes,
	"stacks":1,
	"stackable":stackable,
	"regen_timer":1.0,
	"dot_timer":float(buff_data.get("dot timer",1.0)),
	"dot timer":float(buff_data.get("dot timer",1.0)),
	"damage ammount":float(buff_data.get("damage ammount",0.0)),
	"damage type":buff_data.get("damage type",null)
}

	for key in buff_data:
		if key.begins_with("regen ") or key.begins_with("instant regen "):
			buff_instance[key]=buff_data[key]

	debuff_buffs_active[buff_name]=buff_instance

	for key in buff_data:
		if !key.begins_with("instant regen "):continue

		var stat_name=key.replace("instant regen ","")
		var value=float(buff_data[key])

		match stat_name:
			"health":
				health=min(health+value,max_health)
			"energy":
				energy=min(energy+value,max_energy)

	if !Skills.status_icons.has(buff_name):
		for category_name in ["flasks","consumables","materials","weapons","armors","accessories"]:
			if Items.get(category_name).has(buff_name):
				Skills.status_icons[buff_name]=Items.get(category_name)[buff_name]["icon"]
				break





func updateBuffDebuffs()->void:
	for buff_name in debuff_buffs_active.keys():
		if !debuff_buffs_active.has(buff_name):
			continue

		var buff_data=debuff_buffs_active[buff_name]

		if typeof(buff_data)!=TYPE_DICTIONARY:
			continue

		buff_data["duration"]=float(buff_data.get("duration",0.0))-1.0
		buff_data["regen_timer"]=float(buff_data.get("regen_timer",1.0))-1.0

		if buff_data.get("damage type",null)!=null and buff_data.get("damage ammount",0.0)>0.0 and buff_data.has("dot timer") and buff_data.has("dot_timer"):
			buff_data["dot_timer"]-=1.0

			while buff_data["dot_timer"]<=0.0:
				buff_data["dot_timer"]+=float(buff_data["dot timer"])

				var damage_type_value=buff_data.get("damage type",null)

				if damage_type_value!=null:
					getHit(self,{damage_type_value:float(buff_data.get("damage ammount",0.0))},false,0.0,false)

		while float(buff_data.get("regen_timer",0.0))<=0.0:
			buff_data["regen_timer"]+=1.0

			for key in buff_data.keys():
				if !String(key).begins_with("regen "):
					continue

				var stat_name=String(key).replace("regen ","")
				var value=float(buff_data[key])

				match stat_name:
					"health":
						health=min(health+value,max_health)
					"energy":
						energy=min(energy+value,max_energy)

		if float(buff_data.get("duration",0.0))<=0.0:
			debuff_buffs_active.erase(buff_name)

	if debuff_buffs_active.empty():
		for attribute_name in attributes_buff.keys():
			attributes_buff[attribute_name]=0.0
		return

	for attribute_name in attributes_buff.keys():
		attributes_buff[attribute_name]=0.0

	for buff_name in debuff_buffs_active.keys():
		var buff_data=debuff_buffs_active.get(buff_name,null)

		if typeof(buff_data)!=TYPE_DICTIONARY:
			continue

		var attribute_data=buff_data.get("attributes",{})

		if typeof(attribute_data)!=TYPE_DICTIONARY:
			continue

		for attribute_name in attributes_buff.keys():
			attributes_buff[attribute_name]+=float(attribute_data.get(attribute_name,0.0))
			
			
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

	if target_name=="":return

	if target_type=="buff":
		debuff_buffs_active.erase(target_name)
	else:
		removeStatus(target_name)

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

	if target_name=="":return

	if target_type=="buff":
		debuff_buffs_active.erase(target_name)
	else:
		removeStatus(target_name)

func exhaust()->void:
	print("removing")
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


func isBeneficialStatus(status_name:String)->bool:
	for skill_name in Skills.status_effects:
		if Skills.status_effects[skill_name].has(status_name):
			if !bool(Skills.status_effects[skill_name][status_name].get("malus",false)):
				return true
	return false


func getTotalAttribute(name:String)->float:
	return attributes.get(name,1.0)+equipment_attributes.get(name,0.0)+attributes_buff.get(name,0.0)





func applyStatus(status_name:String,applier:Node=null,current_skill:String="")->void:
	if !Skills.status_effects.has(current_skill):return
	if !Skills.status_effects[current_skill].has(status_name):return
	var data=Skills.status_effects[current_skill][status_name]
	var stackable=bool(data.get("can_stack",false))
	var duration=float(data.get("duration",0.0))
	var tick=float(data.get("tick_timer",1.0))
	var dmg=float(data.get("base_damage",0.0))
	var affects=data.get("affects",[])
	var applier_name=applier.name if applier and is_instance_valid(applier) else ""

	if !stackable:
		if statuses.has(status_name):
			if typeof(statuses[status_name])==TYPE_DICTIONARY:
				statuses[status_name]["duration"]=duration
			return
		statuses[status_name]={
			"duration":duration,"tick_timer":tick,"tick_interval":tick,
			"skill":current_skill,"applier_name":applier_name,
			"tick_damage":dmg,"power":data.get("power",0.0),
			"power2":data.get("power2",0.0),"affects":affects,"stacks":1
		}
		return

	if !statuses.has(status_name):statuses[status_name]=[]
	elif typeof(statuses[status_name])!=TYPE_ARRAY:
		var o=statuses[status_name]
		statuses[status_name]=[]
		if typeof(o)==TYPE_DICTIONARY:statuses[status_name].append(o)

	var list=statuses[status_name]
	for i in range(list.size()):
		var e=list[i]
		if typeof(e)!=TYPE_DICTIONARY:continue
		if e.get("applier_name","")==applier_name and e.get("skill","")==current_skill:
			var st=int(e.get("stacks",1))+1
			if data.has("max_stacks"):st=min(st,int(data["max_stacks"]))
			e["stacks"]=st
			e["duration"]=duration
			e["tick_damage"]=dmg*st
			e["power"]=float(data.get("power",0.0))*st
			e["power2"]=float(data.get("power2",0.0))*st
			e["affects"]=affects
			return

	list.append({
		"duration":duration,"tick_timer":tick,"tick_interval":tick,
		"skill":current_skill,"applier_name":applier_name,
		"tick_damage":dmg,"power":data.get("power",0.0),
		"power2":data.get("power2",0.0),"affects":affects,"stacks":1
	})
func updateStatuses(delta:float)->void:
	var to_remove=[]

	for status_name in statuses.keys():
		var data=statuses[status_name]

		if typeof(data)==TYPE_ARRAY:
			for i in range(data.size()-1,-1,-1):
				var e=data[i]
				if typeof(e)!=TYPE_DICTIONARY:
					continue

				e["duration"]=float(e.get("duration",0.0))-delta
				e["tick_timer"]=float(e.get("tick_timer",1.0))-delta

				var applier=e.get("applier",null)
				var power=float(e.get("power",0.0))
				var tick=float(e.get("tick_interval",1.0))

				if status_name=="bleed" and e["tick_timer"]<=0.0:
					getHit(applier if applier!=null else self,{damage_type.bleed:e.get("tick_damage",power)},false,0.0,false)
					e["tick_timer"]=tick

				elif status_name.begins_with("heal") and e["tick_timer"]<=0.0:
					getHeal(applier if applier!=null else self,power)
					e["tick_timer"]=tick

				if e["duration"]<=0.0:
					data.remove(i)

			if data.size()==0:
				to_remove.append(status_name)

		elif typeof(data)==TYPE_DICTIONARY:
			var e=data

			var d=float(e.get("duration",0.0))-delta
			var t=float(e.get("tick_timer",1.0))-delta

			e["duration"]=d
			e["tick_timer"]=t

			var applier=e.get("applier",null)
			var power=float(e.get("power",0.0))
			var tick=float(e.get("tick_interval",1.0))

			if status_name=="bleed" and t<=0.0:
				getHit(applier if applier!=null else self,{damage_type.bleed:e.get("tick_damage",power)},false,0.0,false)
				e["tick_timer"]=tick

			elif status_name.begins_with("heal") and t<=0.0:
				getHeal(applier if applier!=null else self,power)
				e["tick_timer"]=tick

			if d<=0.0:
				to_remove.append(status_name)

	for k in status_attribute_modifiers.keys():
		status_attribute_modifiers[k]["duration"] -= delta
		if status_attribute_modifiers[k]["duration"] <= 0.0:
			status_attribute_modifiers.erase(k)

	for s in to_remove:
		removeStatus(s)

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
	


func updateAttributes():
	max_arcane =  base_max_arcane * (getTotalAttribute("wisdom") + ( 10 * (getTotalAttribute("toughness") * 0.5)))
	max_health = base_max_health +getTotalAttribute("vitality") * 20
	max_energy = base_max_energy * (getTotalAttribute("vitality") + (getTotalAttribute("agility") *2)) * (getTotalAttribute("instinct"))
	walk_speed = base_walk_speed + getTotalAttribute("agility") * 0.2
	run_speed = base_run_speed + getTotalAttribute("agility") * 0.4
	if parent.is_in_group("Entity"):
		if parent.is_in_combat == true:
			walk_speed *= 0.6
			run_speed *= 0.6

	for k in defences:
		defences[k] = getTotalAttribute("toughness") * 2.0

	derived_stats["attack_speed"] = getTotalAttribute("dexterity")

	derived_stats["cooldown_reduction"] = (getTotalAttribute("haste") * 0.85 +getTotalAttribute("instinct") * 0.10 +getTotalAttribute("wisdom") * 0.05)

	derived_stats["climb_speed"] = 1.0 + getTotalAttribute("dexterity") * 0.20 + getTotalAttribute("strength") * 0.80
	derived_stats["swim_speed"] = 1.0 + getTotalAttribute("strength") * 0.55 + getTotalAttribute("agility") * 0.45

	derived_stats["run_speed"] = 16.0 * (getTotalAttribute("haste") + getTotalAttribute("agility") * 0.45)

	derived_stats["fall_resistance"] = getTotalAttribute("toughness") * 0.75 + getTotalAttribute("agility") * 0.25

	derived_stats["stagger"] = getTotalAttribute("impact") * 0.75 + getTotalAttribute("power") * 0.25
	derived_stats["tenacity"] = getTotalAttribute("balance") * 0.95 + getTotalAttribute("agility") * 0.05 + getTotalAttribute("toughness") * 0.05






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
	
	var berserk_speed_mult := 1.0

	if statuses.has("berserk_buff"):
		var s = statuses["berserk_buff"]
		var power :float = 0.0

		if typeof(s) == TYPE_ARRAY:
			for e in s:
				power += float(e.get("power", 0.0))
		else:
			power = float(s.get("power", 0.0))

		berserk_speed_mult = max(0.01, 1.0 - power)
	walk_speed *= berserk_speed_mult
	run_speed *= berserk_speed_mult
	
	derived_stats["run_speed"] *= berserk_speed_mult
	derived_stats["swim_speed"] *= berserk_speed_mult
	derived_stats["climb_speed"] *= berserk_speed_mult
	derived_stats["attack_speed"] *= berserk_speed_mult



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

	var berserk_damage_bonus :float = 0.0
	
	if statuses.has("berserk_buff"):
		var s = statuses["berserk_buff"]

		if typeof(s) == TYPE_ARRAY:
			for e in s:
				berserk_damage_bonus += float(e.get("power2", 0.0))
		else:
			berserk_damage_bonus = float(s.get("power2", 0.0))
	var berserk_mult := 1.0 + berserk_damage_bonus
	slash_multiplier *= berserk_mult
	blunt_multiplier *= berserk_mult
	pierce_multiplier *= berserk_mult
	bleed_multiplier *= berserk_mult

	sonic_multiplier *= berserk_mult
	heat_multiplier *= berserk_mult
	cold_multiplier *= berserk_mult
	jolt_multiplier *= berserk_mult
	toxic_multiplier *= berserk_mult
	acid_multiplier *= berserk_mult
	arcane_multiplier *= berserk_mult
	radiant_multiplier *= berserk_mult


	
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





func getSkillLevel(skill_name:String) -> int:

	var root = get_node_or_null("../UI/SkillTreeRoot")
	if root == null:
		return 0

	var holders = []
	for i in range(1, 10):
		var holder = root.get_node_or_null("SkillsTreeHolder" + ("" if i == 1 else str(i)))
		if holder == null:
			break
		holders.append(holder)

	var skill_res = Skills.skills.get(skill_name, null)
	if skill_res == null:
		return 0

	for holder in holders:
		if holder == null:
			continue

		for child in holder.get_children():

			if child == null:
				continue

			if !child.name.begins_with("SkillButton"):
				continue

			var slot = child.get_node_or_null("Slot")
			if slot == null or slot.texture == null:
				continue

			if skill_res.resource_path != slot.texture.resource_path:
				continue

			if "skill_level" in child:
				return int(child.skill_level)

	return 0
func getSkillLevelMultiplier(skill_name:String) -> float:
	return Skills.getDamageMultiplier(
		skill_name,
		max(0,getSkillLevel(skill_name)-1)
	)





var active_on_hit_effects = {}
func rebuildOnHitEffects()->void:

	active_on_hit_effects.clear()

	active_on_hit_effects["combo attack"] = {
		"energy_restore":10.0
	}

	if getSkillLevel("combo attack") >= 5:

		active_on_hit_effects["combo attack"]["reduce_cooldowns"] = {
			"cleave":0.25,
			"section":0.25,
			"perforation trifecta":1.25
		}

	if getSkillLevel("combo attack") >= 10:
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


var areas_to_use = {
	"raze": NodePath("../Cleave"),
	"sledge": NodePath("../Cleave"),
	"shoulder bash": NodePath("../Bash"),
	"sadistic blow": NodePath("../Bash")
}



var charged_attack_stacks = {
	"obliteration": {
		"stacks": 0,
		"multiplier": 1.5
	}
}
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

func dealDamage():
	selfBuff()
	if parent.is_in_group("Entity") and "is_in_combat" in parent:
		parent.is_in_combat = true
	var area: Area = null

	if parent.is_in_group("Player") or parent.is_in_group("player"):
		var skill = parent.current_skill.to_lower()

		if areas_to_use.has(skill):
			area = get_node(areas_to_use[skill])
		else:
			if parent.WeaponMode.SWORD:
				area = $"../character/root/Skeleton/WeaponR/Short"
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


	var my_stats = parent.get_node("Stats")
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
		var other_stats = body.get_node("Stats")

		if other_stats != null and my_species != "" and other_stats.species == my_species:
			continue

		if body.has_node("Stats"):
			other_stats.getHit(parent, damages, is_penetrating_hit, 0.0, is_crit)
			Skills.applyImpactEffects(skill_name,body,parent)
			if Skills != null and Skills.status_effects is Dictionary and Skills.status_effects.has(skill_name):
				if Skills.status_effects[skill_name] is Dictionary:
					for status_name in Skills.status_effects[skill_name]:
						other_stats.applyStatus(status_name, parent, skill_name)
		
		var skillbar = $"../UI/Skillbar"
		if Skills != null and Skills.has_method("applyOnHitEffects"):
			if parent.is_in_group("Entity"):
				if parent.is_in_group("Player"):
					Skills.applyOnHitEffects(skill_name, active_on_hit_effects, skillbar.active_cooldowns,self, total_damage)
				else:
					Skills.applyOnHitEffects(skill_name,Skills.on_hit_effects, parent.skill_cooldowns,self, total_damage)

	for attack_name in charged_attack_stacks:charged_attack_stacks[attack_name]["stacks"] = 0


func getHit(attacker:Node,damages:Dictionary,is_penetrating_hit:bool,extra_threat:float,is_crit:bool=false)->void:
	if attacker and (attacker.name=="Stats" or attacker.get_class()=="Node"):
		attacker=attacker.get_parent()
	parent.is_in_combat=true
	var facing_multiplier = 1.0

	if attacker != null:
		if isFacingSelf(attacker,0.7):
			facing_multiplier = 1.5
		elif isFacingSelf(attacker,0.0):
			facing_multiplier = 1.25
	
	
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

		

		var final_damage = damage * (1.0 - mitigation) * facing_multiplier

		if statuses.has("berserk_buff"):
			final_damage *= 1.8
		
		
		if parent.current_skill=="guard" and attacker!=null and isFacingSelf(attacker,-0.5):
			var block=1.0
			var eq= $"../UI/Equipment"
			var mh=eq.slot_mainhand.texture
			var sh=eq.slot_shield.texture
			var w=Items.weapons
			for k in w:
				if w[k]["icon"]==mh: block*=w[k].get("block",1.0)
				if w[k]["icon"]==sh: block*=w[k].get("block",1.0)
			final_damage/=max(block,1.0)
			parent.anim_locks["guard"]=false
			parent.anim_locks["guard react"]=true
			parent.stats.energy = min(parent.stats.energy + 10, parent.stats.max_energy)




		final_damages[dmg_type] = final_damage
		total_damage += final_damage
				
		
		
	if !(parent.is_in_group("Player") or parent.is_in_group("player")):
		if attacker != null:
			if attacker.is_in_group("Entity"):
				var instigatorAggro=parent.getAggro(attacker)
				instigatorAggro.aggro+=((total_damage*attacker.stats.derived_stats["threat"]))
	var damage_multiplier = 1.0

	if (parent.current_skill == "guard" or parent.anim_locks["guard"] == true) and attacker != null and isFacingSelf(attacker,-0.5):
		damage_multiplier = 0.3
		parent.anim_locks["guard react"] = true
	elif (parent.current_skill == "parry" or parent.anim_locks["parry"] == true) and attacker != null and isFacingSelf(attacker,-0.5):
		damage_multiplier = 0.0
		
	total_damage = 0.0
	for dmg_type in final_damages:
		final_damages[dmg_type] *= damage_multiplier
		total_damage += final_damages[dmg_type]
	
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
			
	if parent.is_in_group("Player") or parent.is_in_group("player") or (attacker!=null and attacker.is_in_group("Player")):spawnDamageText(final_damages,is_crit,is_penetrating_hit)
	if is_instance_valid($"../UI/Menu/CharacterBar"):$"../UI/Menu/CharacterBar".updateBars()
	health -= total_damage
	getKilled()
	if attacker != null:
		var attacker_id = attacker.get_instance_id()
		if !damage_meter.has(attacker_id):
			damage_meter[attacker_id] = {"attacker":attacker,"damage":0.0}
		damage_meter[attacker_id].damage += total_damage



func isFacingSelf(attacker:Node,threshold:float)->bool:
	#TODO CHANGE works fine enough but can be improved to ensure enemies can backstab me too
	if attacker==null:return false

	var direction_to_attacker=(attacker.global_transform.origin-parent.global_transform.origin).normalized()

	var facing_direction:Vector3
	var direction_control=parent.get_node_or_null("character")

	if direction_control and parent.is_in_group("Player"):
		facing_direction= -direction_control.global_transform.basis.z.normalized()
	else:
		facing_direction=parent.global_transform.basis.z.normalized()

	return -facing_direction.dot(direction_to_attacker)>=threshold











func spawnDamageText(damages:Dictionary,is_crit:bool=false,is_penetrating_hit:bool=false)->void:
	var text=""

	if is_crit:text+="CRITICAL!\n"
	if is_penetrating_hit:text+="PENETRATING!\n"

	for dmg_type in damages:
		if dmg_type==null:continue
		text+=str(round(float(damages[dmg_type])))+" "+damageTypeToString(int(dmg_type))+"\n"

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



func getReleased()->void:
	parent.anim_locks["flinch"] = false
	parent.anim_locks["knocked down"] = false
	parent.anim_locks["knocked back"] = false
	parent.has_anim_lock = false


func selfBuff():
	var skill_name = parent.current_skill
	if Skills != null and Skills.status_effects is Dictionary and Skills.status_effects.has(skill_name):
				if Skills.status_effects[skill_name] is Dictionary:
					for status_name in Skills.status_effects[skill_name]:
						applyStatus(status_name, parent,skill_name)

func getHeal(source:Node, heal_amount:float)->void:
	var total_heal:float = heal_amount
	if source != null and source.is_in_group("Entity") and source.has_node("Stats"):
		var vitality = getTotalAttribute("vitality")
		total_heal *= 1.0 + (vitality * 0.05)

	if parent.is_in_group("Player"):
		if parent.movement_mode == "crawling":
			health += total_heal * 0.3
			parent.is_downed = false
			parent.is_dead = false
		elif parent.is_downed ==true:
			health += total_heal * 0.3
			parent.anim_locks["get up"] = true
			parent.is_downed = false
			parent.is_dead = false
		else:
			health += total_heal 
	else:
		health += total_heal 
	if health > max_health:
		health = max_health
	
		
	
	if is_instance_valid($"../UI/Menu/CharacterBar"):
		$"../UI/Menu/CharacterBar".updateBars()

	spawnHealText({ "heal": total_heal })


func getKilled():
	if health <=0:
		purify()
		exhaust()
		if parent.is_in_group("Entity"):
			if parent.is_in_group("Player"):
				if health <=0:
					if parent.is_dead == false:
						parent.anim_locks["downed"] = true
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
	if cost <= 0:return true
	if arcane < cost:return false
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
				if typeof(entry) != TYPE_DICTIONARY:continue
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
				if typeof(entry) != TYPE_DICTIONARY:continue
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
		getHit(parent,damages,false,0.0,false)
