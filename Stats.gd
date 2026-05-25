extends Node

export var is_civilised:bool = false
export var is_tense:bool = false
export var species:String = "species"


export var food_chain: int = 1
export var is_predator:bool = false
export var hunt_radius = 50

export var weight = 10


var nutrition = 60
var hydration = 100



var health = 100
export var max_health = 200
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
		
	






func _ready():
	switchPalette()

onready var mesh = $"../Armature/Skeleton/Mesh"
export var palette:String = "forest"

func switchPalette():
	var found_species = ""

	var dir = Directory.new()

	if dir.open("res://world") != OK:
		print("Missing world folder")
		return

	dir.list_dir_begin(true, true)

	var folder = dir.get_next()

	while folder != "":
		if dir.current_is_dir() and folder.to_lower() == species.to_lower():
			found_species = folder
			break

		folder = dir.get_next()

	dir.list_dir_end()

	if found_species == "":
		print("Species folder not found: ", species)
		return

	var texture_folder = "res://world/%s/texture/" % found_species

	if dir.open(texture_folder) != OK:
		print("Texture folder missing: ", texture_folder)
		return

	var palettes = {}

	dir.list_dir_begin(true, true)

	var file = dir.get_next()

	while file != "":
		if file.ends_with(".png"):
			var palette_name = file.get_basename()
			palettes[palette_name] = texture_folder + file

		file = dir.get_next()

	dir.list_dir_end()

	if !palettes.has(palette):
		print("Palette missing: ", palette)
		return

	var tex = load(palettes[palette])

	var mat = SpatialMaterial.new()
	mat.flags_unshaded = true
	mat.albedo_texture = tex

	mesh.material_override = mat
	
func die():
	#call this at the end of every die animation, with add track  > stats from animation player
	is_finished = true
	
	

