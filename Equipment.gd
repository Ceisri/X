extends Control

onready var player = $"../.."
onready var skeleton =$"../../character/root/Skeleton"
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


var current_mainhand_id = -1
var current_offhand_id = -1

var current_mainhand_node = null
var current_offhand_node = null

func _ready():
	close_button.connect("pressed", self, "collapse")
	loadData()


func collapse() -> void:
	hide()



func get_equipment_stats():
	var stats_node = $"../../Stats"

	for dmg_type in stats_node.weapon_damages:
		stats_node.weapon_damages[dmg_type] = 0

	for dmg_type in stats_node.defences:
		stats_node.defences[dmg_type] = 0

	stats_node.max_health = 100

	applyArmorStats(slot_torso, Items.armors, stats_node)
	applyArmorStats(slot_hands, Items.armors, stats_node)
	applyArmorStats(slot_feet, Items.armors, stats_node)

	applyWeaponStats(slot_mainhand, Items.weapons, stats_node)
	applyWeaponStats(slot_offhand, Items.weapons, stats_node)

	return stats_node

func applyArmorStats(slot, armor_table, stats_node):
	if slot.texture == null:
		return

	for armor_id in armor_table:
		var armor = armor_table[armor_id]

		if armor["icon"] != slot.texture:
			continue

		stats_node.max_health += armor.get("max_health", 0)

		if armor.has("defences"):
			for defence_name in armor["defences"]:
				var dmg_type = stats_node.damage_type[defence_name]

				stats_node.defences[dmg_type] += armor["defences"][defence_name]

		break
func applyWeaponStats(slot, weapon_table, stats_node):
	if slot.texture == null:
		return

	for weapon_id in weapon_table:
		var weapon = weapon_table[weapon_id]

		if weapon.get("icon") != slot.texture:
			continue

		if weapon.has("damages"):

			for damage_name in weapon["damages"].keys():

				if typeof(damage_name) == TYPE_STRING and stats_node.damage_type.has(damage_name):
					var dmg_type = stats_node.damage_type[damage_name]
					stats_node.weapon_damages[dmg_type] += weapon["damages"][damage_name]

		break









func _load_scene(path: String) -> PackedScene:
	if !ResourceLoader.exists(path):
		return null

	var scene = load(path)

	if scene is PackedScene:
		return scene

	return null


func _remove_materials(node: Node) -> void:
	if node is MeshInstance:
		node.material_override = null

		for i in range(node.get_surface_material_count()):
			node.set_surface_material(i, null)

	for child in node.get_children():
		_remove_materials(child)


func _instance_without_material(path: String) -> Node:
	var scene = _load_scene(path)

	if !scene:
		return null

	var instance = scene.instance()

	if instance:
		_remove_materials(instance)

	return instance


const TORSO0_SCENE = preload("res://world/player/human/male/Torso0.tscn")
const TORSO1_SCENE = preload("res://world/player/human/male/Torso1.tscn")
const TORSO2_SCENE = preload("res://world/player/human/male/Torso2.tscn")

const HANDS0_SCENE = preload("res://world/player/human/male/Hands0.tscn")
const HANDS1_SCENE = preload("res://world/player/human/male/Hands1.tscn")
const HANDS2_SCENE = preload("res://world/player/human/male/Hands2.tscn")

const FEET0_SCENE = preload("res://world/player/human/male/Feet0.tscn")
const FEET1_SCENE = preload("res://world/player/human/male/Feet1.tscn")


func updateEquipment() -> void:
	pass
	var stats = $"../../Stats"

	if stats.species != "human":
		return

	if stats.sex != "male":
		return

	updateArmorCache(stats.species, stats.sex)

	var changed = equipmentChanged()

	if changed:
		updateEquipmentCache()
		updateTorso()
		updateHands()
		updateFeet()


	updateWeapons()

	if changed:
		get_equipment_stats()



var torso_id
var torso_scene

var hands_id
var hands_scene

var feet_id
var feet_scene

func updateArmorCache(species:String, sex:String) -> void:
	torso_id = 0
	torso_scene = TORSO0_SCENE

	if slot_torso.texture == Items.armors["torso1"]["icon"]:
		torso_id = 1
		torso_scene = TORSO1_SCENE
	elif slot_torso.texture == Items.armors["torso2"]["icon"]:
		torso_id = 2
		torso_scene = TORSO2_SCENE

	hands_id = 0
	hands_scene = HANDS0_SCENE

	if slot_hands.texture == Items.armors["hands1"]["icon"]:
		hands_id = 1
		hands_scene = HANDS1_SCENE
	elif slot_hands.texture == Items.armors["hands2"]["icon"]:
		hands_id = 2
		hands_scene = HANDS2_SCENE

	feet_id = 0
	feet_scene = FEET0_SCENE

	if slot_feet.texture == Items.armors["feet1"]["icon"]:
		feet_id = 1
		feet_scene = FEET1_SCENE

func equipmentChanged() -> bool:
	return !(
		current_species == $"../../Stats".species
		and current_sex == $"../../Stats".sex
		and current_torso_id == torso_id
		and current_hands_id == hands_id
		and current_feet_id == feet_id)


func updateEquipmentCache() -> void:
	current_species = $"../../Stats".species
	current_sex = $"../../Stats".sex
	current_torso_id = torso_id
	current_hands_id = hands_id
	current_feet_id = feet_id

func replaceEquipmentNode(current_node, scene):
	if is_instance_valid(current_node):
		current_node.queue_free()
	var node = scene.instance()
	_remove_materials(node)
	setUnshaded(node)
	skeleton.add_child(node) 
	return node

func updateTorso() -> void:
	current_torso_node = replaceEquipmentNode(current_torso_node,torso_scene)

func updateHands() -> void:
	current_hands_node = replaceEquipmentNode(current_hands_node,hands_scene)
func updateFeet() -> void:
	current_feet_node = replaceEquipmentNode(current_feet_node,feet_scene)

const SWORD_SCENE = preload("res://world/weapons/scenes/sword1.tscn")
const FORK_SCENE = preload("res://world/weapons/scenes/fork1.tscn")
const SHIELD_SCENE = preload("res://world/player/weapons/Shield.tscn")


var weapon_mode
var current_main_weapon_node = null
var current_offhand_weapon_node = null
onready var bone_holder_right:BoneAttachment = $"../../character/root/Skeleton/WeaponR"
onready var bone_holder_left:BoneAttachment = $"../../character/root/Skeleton/WeaponL"
func updateWeapons() -> void:
	var inventory_grid:GridContainer=$"../Inventory/ScrollContainer/GridContainer"
	var inventory:Control=$"../Inventory"

	for n in [current_main_weapon_node,current_offhand_weapon_node]:
		if is_instance_valid(n):
			n.queue_free()

	current_main_weapon_node=null
	current_offhand_weapon_node=null
	player.weapons= player.WeaponMode.NONE

	if !slot_mainhand.texture:
		slot_offhand.get_parent().visible=false

		if slot_offhand.texture:
			for w in Items.weapons.values():
				if w["icon"]==slot_offhand.texture:
					CommonBehaviours.addNotStackableItem(inventory_grid,w,inventory)
					break

			slot_offhand.texture=null

		return

	var two_handed=false

	for w in Items.weapons.values():
		if w["icon"]==slot_mainhand.texture:
			two_handed=w.get("two handed",false)
			break

	slot_offhand.get_parent().visible=!two_handed

	if two_handed and slot_offhand.texture:
		for w in Items.weapons.values():
			if w["icon"]==slot_offhand.texture:
				CommonBehaviours.addNotStackableItem(inventory_grid,w,inventory)
				break

		slot_offhand.texture=null

	var sword=Items.weapons["sword"]["icon"].resource_path
	var fork=Items.weapons["fork"]["icon"].resource_path
	var shield=Items.weapons["shield"]["icon"].resource_path

	var mh=slot_mainhand.texture.resource_path if slot_mainhand.texture else ""
	var oh=slot_offhand.texture.resource_path if slot_offhand.texture else ""

	if mh==sword:
		current_main_weapon_node=SWORD_SCENE.instance()
		_remove_materials(current_main_weapon_node)
		setUnshaded(current_main_weapon_node)
		bone_holder_right.add_child(current_main_weapon_node)

	elif mh==fork:
		current_main_weapon_node=FORK_SCENE.instance()
		_remove_materials(current_main_weapon_node)
		setUnshaded(current_main_weapon_node)
		bone_holder_right.add_child(current_main_weapon_node)

	if oh==sword:
		current_offhand_weapon_node=SWORD_SCENE.instance()
		_remove_materials(current_offhand_weapon_node)
		setUnshaded(current_offhand_weapon_node)
		bone_holder_left.add_child(current_offhand_weapon_node)

	elif oh==fork:
		current_offhand_weapon_node=FORK_SCENE.instance()
		_remove_materials(current_offhand_weapon_node)
		setUnshaded(current_offhand_weapon_node)
		bone_holder_left.add_child(current_offhand_weapon_node)

	elif oh==shield:
		current_offhand_weapon_node=SHIELD_SCENE.instance()
		_remove_materials(current_offhand_weapon_node)
		setUnshaded(current_offhand_weapon_node)

		var shield_slot=$Shield/Slot
		if shield_slot:
			bone_holder_left.add_child(shield_slot)

		skeleton.add_child(current_offhand_weapon_node)

	if mh==fork:
		player.weapons=player.WeaponMode.TWO_HANDED
	elif mh==sword and oh==sword:
		player.weapons=player.WeaponMode.DUAL
	elif mh==sword and oh==shield:
		player.weapons=player.WeaponMode.SHIELD
	elif mh==sword:
		player.weapons=player.WeaponMode.SWORD
	else:
		player.weapons=player.WeaponMode.NONE





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

	if !file.file_exists(path):
		slot_torso.texture = Items.armors["torso1"]["icon"]
		slot_hands.texture = Items.armors["hands1"]["icon"]
		slot_feet.texture = Items.armors["feet1"]["icon"]

		slot_mainhand.texture = null
		slot_offhand.texture = null

		updateEquipment()
		saveData()
		return

	if file.open(path, File.READ) != OK:
		slot_torso.texture = Items.armors["torso1"]["icon"]
		slot_hands.texture = Items.armors["hands1"]["icon"]
		slot_feet.texture = Items.armors["feet1"]["icon"]

		slot_mainhand.texture = null
		slot_offhand.texture = null

		updateEquipment()
		saveData()
		return

	var data = file.get_var()
	file.close()

	if typeof(data) != TYPE_DICTIONARY:
		slot_torso.texture = Items.armors["torso1"]["icon"]
		slot_hands.texture = Items.armors["hands1"]["icon"]
		slot_feet.texture = Items.armors["feet1"]["icon"]

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
	get_equipment_stats()


func _get_texture_path(slot: TextureRect) -> String:
	if !slot:
		return ""

	if !slot.texture:
		return ""

	return slot.texture.resource_path


func setUnshaded(node: Node) -> void:
	if node is MeshInstance:
		if node.material_override:
			if node.material_override is SpatialMaterial:
				node.material_override.flags_unshaded = true

		for i in range(node.get_surface_material_count()):
			var mat = node.get_surface_material(i)

			if mat and mat is SpatialMaterial:
				mat.flags_unshaded = true

	for child in node.get_children():
		setUnshaded(child)
		
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
