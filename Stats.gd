extends Node



export var is_civilised:bool = false
export var is_tense:bool = false
export var species:String = "species"
export var sex:String = "male"

export var food_chain: int = 1
export var is_predator:bool = false
export var hunt_radius = 50

export var weight = 10

var skill_points = 100
var used_skill_points = 0

var nutrition = 60
var hydration = 100



signal health_changed
signal arcane_changed

export var health = 100 setget setHealth
export var arcane = 100 setget setArcane

export var max_health = 100 setget setMaxHealth
export var max_arcane = 100 setget setMaxArcane


func setHealth(value):
	health = clamp(value, 0, max_health)
	emit_signal("health_changed")


func setArcane(value):
	arcane = clamp(value, 0, max_arcane)
	emit_signal("arcane_changed")


func setMaxHealth(value):
	max_health = max(1, value)

	if health > max_health:
		health = max_health

	emit_signal("health_changed")


func setMaxArcane(value):
	max_arcane = max(1, value)

	if arcane > max_arcane:
		arcane = max_arcane

	emit_signal("arcane_changed")
	
export var walk_speed = 3
export var run_speed = 7
var last_health = -1
var last_damage_time = 0
var damage_check_window = 3000
var parry_chance = 0.6
var nutrition_loss_tick = 10 
export var attack_range:float = 3
export var can_be_moved:bool = true
var is_finished: bool = false
var Name = ""

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



var agility = 1
var power = 1 
var charisma = 1 
var vitality = 1






func _physics_process(delta)->void:
	if Engine.get_physics_frames() % 180 == 0:
		hydration -= 1
		
	

func die():
	#call this at the end of every die animation, with add track  > stats from animation player
	is_finished = true
	
	

