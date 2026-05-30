extends Control

onready var player = $"../.."
onready var skeleton = $"../../character/Armature/Skeleton"
onready var close_button = $Close

onready var slot_torso = $Torso/Slot
onready var slot_hands = $Hands/Slot
onready var slot_feet = $Feet/Slot
onready var slot_mainhand = $MainHand/Slot
onready var slot_offhand = $OffHand/Slot

const SAVE_DIR = "user://characters/"

var current_species = ""
var current_sex = ""

var current_torso_id = -1
var current_hands_id = -1
var current_feet_id = -1

var current_torso_node = null
var current_hands_node = null
var current_feet_node = null

const TORSO_0 = preload("res://world/player/human/male/Torso0.tscn")
const TORSO_1 = preload("res://world/player/human/male/Torso1.tscn")
const TORSO_2 = preload("res://world/player/human/male/Torso2.tscn")

const HANDS_0 = preload("res://world/player/human/male/Hands0.tscn")
const HANDS_1 = preload("res://world/player/human/male/Hands1.tscn")
const HANDS_2 = preload("res://world/player/human/male/Hands2.tscn")

const FEET_0 = preload("res://world/player/human/male/Feet0.tscn")
const FEET_1 = preload("res://world/player/human/male/Feet1.tscn")


func _ready():
	close_button.connect("pressed", self, "collapse")
	loadData()


func collapse()->void:
	hide()


func updateEquipment()->void:
	var stats = $"../../Stats"
	var species = stats.species
	var sex = stats.sex

	if species != "human":
		return

	if sex != "male":
		return

	# TORSO

	var torso_id = 0
	var torso_scene = TORSO_0

	if slot_torso.texture == Items.armors["torso1"]:
		torso_id = 1
		torso_scene = TORSO_1
	elif slot_torso.texture == Items.armors["torso2"]:
		torso_id = 2
		torso_scene = TORSO_2

	# HANDS

	var hands_id = 0
	var hands_scene = HANDS_0

	if slot_hands.texture == Items.armors["hands1"]:
		hands_id = 1
		hands_scene = HANDS_1
	elif slot_hands.texture == Items.armors["hands2"]:
		hands_id = 2
		hands_scene = HANDS_2

	# FEET

	var feet_id = 0
	var feet_scene = FEET_0

	if slot_feet.texture == Items.armors["feet1"]:
		feet_id = 1
		feet_scene = FEET_1

	# nothing changed

	if (
		species == current_species
		and sex == current_sex
		and torso_id == current_torso_id
		and hands_id == current_hands_id
		and feet_id == current_feet_id
	):
		return

	current_species = species
	current_sex = sex

	current_torso_id = torso_id
	current_hands_id = hands_id
	current_feet_id = feet_id

	# replace torso

	if is_instance_valid(current_torso_node):
		current_torso_node.queue_free()

	current_torso_node = torso_scene.instance()
	skeleton.add_child(current_torso_node)

	# replace hands

	if is_instance_valid(current_hands_node):
		current_hands_node.queue_free()

	current_hands_node = hands_scene.instance()
	skeleton.add_child(current_hands_node)

	# replace feet

	if is_instance_valid(current_feet_node):
		current_feet_node.queue_free()

	current_feet_node = feet_scene.instance()
	skeleton.add_child(current_feet_node)


func saveData() -> void:
	var dir = Directory.new()

	if !dir.dir_exists(SAVE_DIR):
		dir.make_dir_recursive(SAVE_DIR)

	var file = File.new()
	var path = SAVE_DIR + player.entity_name + ".save"

	var data = {
		"visible": visible,
		"Torso": _get_texture_path(slot_torso),
		"Hands": _get_texture_path(slot_hands),
		"Feet": _get_texture_path(slot_feet),
		"MainHand": _get_texture_path(slot_mainhand),
		"OffHand": _get_texture_path(slot_offhand)
	}

	if file.open(path, File.WRITE) == OK:
		file.store_var(data)
		file.close()


func loadData() -> void:
	var path = SAVE_DIR + player.entity_name + ".save"
	var file = File.new()

	# first character creation

	if !file.file_exists(path):
		slot_torso.texture = Items.armors["torso1"]
		slot_hands.texture = Items.armors["hands1"]
		slot_feet.texture = Items.armors["feet1"]

		slot_mainhand.texture = null
		slot_offhand.texture = null

		updateEquipment()
		saveData()
		return

	# failed load

	if file.open(path, File.READ) != OK:
		slot_torso.texture = Items.armors["torso1"]
		slot_hands.texture = Items.armors["hands1"]
		slot_feet.texture = Items.armors["feet1"]

		slot_mainhand.texture = null
		slot_offhand.texture = null

		updateEquipment()
		saveData()
		return

	var data = file.get_var()
	file.close()

	# corrupted save

	if typeof(data) != TYPE_DICTIONARY:
		slot_torso.texture = Items.armors["torso1"]
		slot_hands.texture = Items.armors["hands1"]
		slot_feet.texture = Items.armors["feet1"]

		slot_mainhand.texture = null
		slot_offhand.texture = null

		updateEquipment()
		saveData()
		return

	visible = data.get("visible", visible)

	_load_texture(slot_torso, data.get("Torso", ""))
	_load_texture(slot_hands, data.get("Hands", ""))
	_load_texture(slot_feet, data.get("Feet", ""))
	_load_texture(slot_mainhand, data.get("MainHand", ""))
	_load_texture(slot_offhand, data.get("OffHand", ""))

	updateEquipment()


func _get_texture_path(slot: TextureRect) -> String:
	if !slot:
		return ""

	if !slot.texture:
		return ""

	return slot.texture.resource_path


func _load_texture(slot: TextureRect, texture_path: String) -> void:
	if !slot:
		return

	if texture_path == "":
		slot.texture = null
		return

	if !ResourceLoader.exists(texture_path):
		slot.texture = null
		return

	slot.texture = load(texture_path)
