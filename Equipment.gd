extends Control

onready var player = $"../.."
onready var skeleton =$"../../character/root/Skeleton"
onready var close_button = $Close

onready var slot_torso:TextureRect = $Torso/Slot
onready var slot_hands:TextureRect = $Hands/Slot
onready var slot_feet:TextureRect = $Feet/Slot
onready var slot_mainhand:TextureRect = $MainHand/Slot
onready var slot_offhand:TextureRect = $OffHand/Slot
onready var slot_shield:TextureRect = $Shield/Slot

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

func _physics_process(delta):
	if Input.is_action_just_pressed("up"):
		move_bone("HipHolder.l", 0, 0, -5)
		move_bone("inverted.l", 0, 0, -5)
		move_bone("HipHolder.r", 0, 0, 5)
		move_bone("inverted.r", 0, 0, 5)
	if Input.is_action_just_pressed("down"):
		move_bone("HipHolder.l", 0, 0, 5)
		move_bone("HipHolder.r", 0, 0, -5)


func collapse() -> void:
	hide()


func get_equipment_stats():
	var s=$"../../Stats"

	for k in s.equipment_attributes: s.equipment_attributes[k]=0.0
	for k in s.equipment_defence_bonus: s.equipment_defence_bonus[k]=0.0
	for k in s.equipment_damage_bonus: s.equipment_damage_bonus[k]=0.0

	applyArmorStats(slot_torso,Items.armors,s)
	applyArmorStats(slot_hands,Items.armors,s)
	applyArmorStats(slot_feet,Items.armors,s)

	applyWeaponStats(slot_mainhand,Items.weapons,s)
	applyWeaponStats(slot_offhand,Items.weapons,s)

	s.updateAttributes()


func applyArmorStats(slot,armor_table,s):
	if !slot.texture: return

	for k in armor_table:
		var a=armor_table[k]
		if a["icon"]!=slot.texture: continue

		s.max_health+=a.get("max_health",0)

		for i in s.equipment_attributes:
			s.equipment_attributes[i]+=a.get(i,0.0)

		if a.has("defences"):
			for d in a["defences"]:
				var t=s.damage_type[d]
				s.equipment_defence_bonus[t]+=a["defences"][d]
		break
func applyWeaponStats(slot,weapon_table,s):
	if !slot.texture: return

	for k in weapon_table:
		var w=weapon_table[k]
		if w["icon"]!=slot.texture: continue

		for i in s.equipment_attributes:
			s.equipment_attributes[i]+=w.get(i,0.0)

		if w.has("damages"):
			for d in w["damages"]:
				var t=s.damage_type[d]
				s.equipment_damage_bonus[t]+=w["damages"][d]
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
	var stats=$"../../Stats"
	updateArmorCache(stats.species,stats.sex)

	var changed=equipmentChanged()

	if changed:
		updateEquipmentCache()
		updateTorso()
		updateHands()
		updateFeet()

	updateWeapons()
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



var weapon_mode
var current_main_weapon_node = null
var current_offhand_weapon_node = null
var current_shield_node = null
onready var bone_holder_right:BoneAttachment = $"../../character/root/Skeleton/WeaponR"
onready var bone_holder_left:BoneAttachment = $"../../character/root/Skeleton/WeaponL"
onready var bone_holder_hipL:BoneAttachment = $"../../character/root/Skeleton/HipR"
onready var bone_holder_hipR:BoneAttachment = $"../../character/root/Skeleton/HipL"
onready var bone_holder_backUP:BoneAttachment = $"../../character/root/Skeleton/BackUp"#For greatsword at rest
onready var bone_holder_backLow:BoneAttachment = $"../../character/root/Skeleton/BackLow"#For greataxe at rest

onready var bone_holder_back_shield:BoneAttachment = $"../../character/root/Skeleton/ShieldBack"
onready var bone_holder_shield:BoneAttachment =  $"../../character/root/Skeleton/Shield"
onready var bone_holer_hips_invertedL:BoneAttachment =$"../../character/root/Skeleton/IvR"
onready var bone_holer_hips_invertedR:BoneAttachment = $"../../character/root/Skeleton/IvL"


func updateWeapons() -> void:
	reset_bone_transform("weapon_r")
	var inventory_grid:GridContainer = $"../Inventory/ScrollContainer/GridContainer"
	var inventory:Control = $"../Inventory"

	for node in [current_main_weapon_node, current_offhand_weapon_node, current_shield_node]:
		if is_instance_valid(node):
			node.queue_free()

	current_main_weapon_node = null
	current_offhand_weapon_node = null
	current_shield_node = null

	player.weapons = player.WeaponMode.NONE

	if !slot_mainhand.texture:
		slot_offhand.get_parent().visible = false

		if slot_offhand.texture:
			var returned_weapon = _find_weapon_from_icon(slot_offhand.texture)

			if !returned_weapon.empty():
				CommonBehaviours.addNotStackableItem(
					inventory_grid,
					returned_weapon,
					inventory
				)

			slot_offhand.texture = null

		return

	var main_weapon = _find_weapon_from_icon(slot_mainhand.texture)
	if main_weapon.empty():
		return

	var two_handed = main_weapon.get("two handed", false)

	var shield_weapon = _find_weapon_from_icon(slot_shield.texture)

	# prevent non-weapons in shield slot
	if !shield_weapon.empty() and shield_weapon.get("carry", "") != "shield":
		CommonBehaviours.addNotStackableItem(inventory_grid, shield_weapon, inventory)
		slot_shield.texture = null
		shield_weapon = {}

	# shield disables offhand slot (but NOT two-handed weapon)
	if !shield_weapon.empty():
		slot_offhand.get_parent().visible = false

		if slot_offhand.texture:
			var returned_weapon = _find_weapon_from_icon(slot_offhand.texture)
			if !returned_weapon.empty():
				CommonBehaviours.addNotStackableItem(inventory_grid, returned_weapon, inventory)
			slot_offhand.texture = null
	else:
		slot_offhand.get_parent().visible = !two_handed

		if two_handed and slot_offhand.texture:
			var returned_weapon = _find_weapon_from_icon(slot_offhand.texture)
			if !returned_weapon.empty():
				CommonBehaviours.addNotStackableItem(inventory_grid, returned_weapon, inventory)
			slot_offhand.texture = null

	var offhand_weapon = _find_weapon_from_icon(slot_offhand.texture)

	var main_holder:Node
	var offhand_holder:Node

	if player.is_in_combat:
		main_holder = bone_holder_right
		offhand_holder = bone_holder_left
	else:
		match main_weapon.get("carry", "hips"):
			"hips":
				main_holder = bone_holder_hipR

			"hips inverted":
				main_holder = bone_holer_hips_invertedR

			"back up":
				main_holder = bone_holder_backUP

			"back low":
				main_holder = bone_holder_backLow

			_:
				main_holder = bone_holder_hipR

		if !offhand_weapon.empty():
			match offhand_weapon.get("carry", "hips"):
				"hips":
					offhand_holder = bone_holder_hipL

				"hips inverted":
					offhand_holder = bone_holer_hips_invertedL

				"back up":
					offhand_holder = bone_holder_backUP

				"back low":
					offhand_holder = bone_holder_backLow

				_:
					offhand_holder = bone_holder_hipL
		else:
			offhand_holder = bone_holder_hipL

	current_main_weapon_node = _spawn_weapon(main_weapon, main_holder)
	if !player.is_in_combat:

		var carry_type = main_weapon.get("carry", "")

#		if carry_type == "hips inverted":
#			# greataxes
#			rotate_bone("inverted.r", 0,180,0)
#			rotate_bone("inverted.l",  0,180,0)
#
#		elif carry_type == "back low":
#			# greataxes on back
#			rotate_bone("weapon_r", 0, 0,0)
#
#		elif carry_type == "back up":
#			# greatswords on back
#			rotate_bone("weapon_r", 0, 0, 0)
#
#		else:
#			rotate_bone("weapon_r", 0, 0, 0)
	if !offhand_weapon.empty():
		current_offhand_weapon_node = _spawn_weapon(offhand_weapon, offhand_holder)

	if !shield_weapon.empty():
		current_shield_node = shield_weapon["scene"].instance()

		_remove_materials(current_shield_node)
		setUnshaded(current_shield_node)

		var shield_holder:Node = bone_holder_shield if player.is_in_combat else bone_holder_back_shield
		shield_holder.add_child(current_shield_node)


	# force shield mode if a shield node actually exists
	if is_instance_valid(current_shield_node):
		player.weapons = player.WeaponMode.SHIELD

	elif two_handed:
		player.weapons = player.WeaponMode.TWO_HANDED

	elif !offhand_weapon.empty():
		player.weapons = player.WeaponMode.DUAL

	elif !main_weapon.empty():
		player.weapons = player.WeaponMode.SWORD

	else:
		player.weapons = player.WeaponMode.NONE

	var mode_name = "NONE"

	match player.weapons:
		player.WeaponMode.NONE:
			mode_name = "NONE"

		player.WeaponMode.SWORD:
			mode_name = "SWORD"

		player.WeaponMode.DUAL:
			mode_name = "DUAL"

		player.WeaponMode.SHIELD:
			mode_name = "SHIELD"

		player.WeaponMode.TWO_HANDED:
			mode_name = "TWO_HANDED"

	$"../../Label".text = mode_name

	
	
	
	

var bone_default_rest = {}

func cache_bone_rest(bone_name:String) -> void:
	if bone_default_rest.has(bone_name):
		return

	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return

	bone_default_rest[bone_name] = skeleton.get_bone_rest(bone_idx)

func rotate_bone(bone_name:String,x_degrees:float = 0.0,y_degrees:float = 0.0,z_degrees:float = 0.0) -> void:
	if skeleton == null:
		return
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return
	cache_bone_rest(bone_name)
	var rest = bone_default_rest[bone_name]
	var rot_basis = Basis()
	rot_basis = rot_basis.rotated(Vector3.RIGHT, deg2rad(x_degrees))
	rot_basis = rot_basis.rotated(Vector3.UP, deg2rad(y_degrees))
	rot_basis = rot_basis.rotated(Vector3.FORWARD, deg2rad(z_degrees))
	var new_transform = Transform(rest.basis * rot_basis,rest.origin)
	skeleton.set_bone_rest(bone_idx, new_transform)



func reset_bone_transform(bone_name:String) -> void:
	if skeleton == null:
		return

	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return

	if !bone_default_rest.has(bone_name):
		return

	skeleton.set_bone_rest(bone_idx, bone_default_rest[bone_name])




func move_bone(bone_name:String,x_offset:float = 0.0,y_offset:float = 0.0,z_offset:float = 0.0) -> void:
	if skeleton == null:
		return
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return
	cache_bone_rest(bone_name)
	var rest = bone_default_rest[bone_name]
	var new_transform = Transform(rest.basis,rest.origin + Vector3(x_offset, y_offset, z_offset))
	skeleton.set_bone_rest(bone_idx, new_transform)

func reset_bone_position(bone_name:String) -> void:
	if skeleton == null:
		return
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return
	if !bone_default_rest.has(bone_name):
		return
	skeleton.set_bone_rest(bone_idx, bone_default_rest[bone_name])
	
	
	
	
	
	
	
	
	
	
	
	
	
func _find_weapon_from_icon(icon:Texture) -> Dictionary:
	for weapon in Items.weapons.values():
		if weapon["icon"] == icon:
			return weapon
	return {}

func _spawn_weapon(weapon_data:Dictionary, parent:Node) -> Node:
	if weapon_data.empty():
		return null

	var weapon_node = weapon_data["scene"].instance()

	_remove_materials(weapon_node)
	setUnshaded(weapon_node)

	parent.add_child(weapon_node)

	return weapon_node


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
		"OffHand": _get_texture_path(slot_offhand),
		"Shield": _get_texture_path(slot_shield)
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
		slot_shield.texture = null

		updateEquipment()
		saveData()
		return

	if file.open(path, File.READ) != OK:
		slot_torso.texture = Items.armors["torso1"]["icon"]
		slot_hands.texture = Items.armors["hands1"]["icon"]
		slot_feet.texture = Items.armors["feet1"]["icon"]

		slot_mainhand.texture = null
		slot_offhand.texture = null
		slot_shield.texture = null

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
		slot_shield.texture = null

		updateEquipment()
		saveData()
		return

	visible = data.get("visible", visible)

	_load_texture(slot_torso, data.get("Torso", ""))
	_load_texture(slot_hands, data.get("Hands", ""))
	_load_texture(slot_feet, data.get("Feet", ""))

	_load_texture(slot_mainhand, data.get("MainHand", ""))
	_load_texture(slot_offhand, data.get("OffHand", ""))
	_load_texture(slot_shield, data.get("Shield", ""))

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
