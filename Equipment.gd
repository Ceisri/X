extends Control

onready var player = $"../.."
onready var skeleton =$"../../character/root/Skeleton"
onready var close_button = $Close

onready var slot_torso:TextureRect = $Torso/Slot
onready var slot_hands:TextureRect = $Hands/Slot
onready var slot_feet:TextureRect = $Feet/Slot
onready var slot_mainhand:TextureRect = $MainHand/Slot
onready var slot_offhand:TextureRect = $OffHand/Slot

onready var player_name_label:Label = $NameLabel
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
var torso_scene:PackedScene=preload("res://world/player/human/male/Torso0.tscn")
var hands_scene:PackedScene=preload("res://world/player/human/male/Hands0.tscn")
var feet_scene:PackedScene=preload("res://world/player/human/male/Feet0.tscn")
func _ready():
	current_species=$"../../Stats".species
	current_sex=$"../../Stats".sex
	current_torso_scene=torso_scene
	current_hands_scene=hands_scene
	current_feet_scene=feet_scene
	close_button.connect("pressed", self, "collapse")
	call_deferred("loadData")
	player_name_label.text = player.entity_name
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

func get_skeleton():
	var character=$"../../character"
	if character==null or !is_instance_valid(character):
		return null
	return character.get_node_or_null("root/Skeleton")
	

func get_equipment_stats():
	var stats = $"../../Stats"

	for attribute_name in stats.equipment_attributes: stats.equipment_attributes[attribute_name] = 0.0
	for damage_type in stats.equipment_defence_bonus: stats.equipment_defence_bonus[damage_type] = 0.0
	for damage_type in stats.equipment_damage_bonus: stats.equipment_damage_bonus[damage_type] = 0.0

	stats.equipment_max_health = 0.0
	stats.equipment_max_arcane = 0.0
	stats.equipment_max_energy = 0.0
	stats.equipment_movement_speed = 1.0
	stats.equipment_derived_stats.clear()

	applyArmorStats(slot_torso,Items.armors,stats)
	applyArmorStats(slot_hands,Items.armors,stats)
	applyArmorStats(slot_feet,Items.armors,stats)

	applyRingStats(ring,Items.rings,stats)
	applyRingStats(ring2,Items.rings,stats)
	applyRingStats(ring3,Items.rings,stats)
	applyRingStats(ring4,Items.rings,stats)
	applyRingStats(ring5,Items.rings,stats)
	applyRingStats(ring6,Items.rings,stats)
	applyRingStats(ring7,Items.rings,stats)
	applyRingStats(ring8,Items.rings,stats)
	applyNecklaceStats($Necklace,Items.necklaces,stats)
	applyWeaponStats(slot_mainhand,Items.weapons,stats)
	applyWeaponStats(slot_offhand,Items.weapons,stats)

	stats.updateAttributes()


func applyRingStats(slot,ring_table,stats):
	var slot_texture=slot.get_node("Slot").texture
	if !slot_texture: return

	for ring_name in ring_table:
		var ring_data=ring_table[ring_name]
		if !sameIcon(ring_data["icon"],slot_texture): continue

		stats.equipment_max_health+=ring_data.get("max_health",0)
		stats.equipment_max_arcane+=ring_data.get("max_arcane",0)
		stats.equipment_max_energy+=ring_data.get("max_energy",0)
		stats.equipment_movement_speed+=ring_data.get("mov_speed",0)*0.01

		for attribute_name in stats.equipment_attributes:
			stats.equipment_attributes[attribute_name]+=ring_data.get(attribute_name,0.0)

		if ring_data.has("derived_stats"):
			for stat_name in ring_data["derived_stats"]:
				stats.equipment_derived_stats[stat_name]=stats.equipment_derived_stats.get(stat_name,0.0)+ring_data["derived_stats"][stat_name]
		break
func applyNecklaceStats(slot,necklace_table,stats):
	var slot_texture=slot.get_node("Slot").texture
	if !slot_texture:return

	for necklace_name in necklace_table:
		var necklace_data=necklace_table[necklace_name]
		if !sameIcon(necklace_data["icon"],slot_texture):continue

		stats.equipment_max_health+=necklace_data.get("max_health",0)
		stats.equipment_max_arcane+=necklace_data.get("max_arcane",0)
		stats.equipment_max_energy+=necklace_data.get("max_energy",0)
		stats.equipment_movement_speed+=necklace_data.get("mov_speed",0)*0.01

		for attribute_name in stats.equipment_attributes:
			stats.equipment_attributes[attribute_name]+=necklace_data.get(attribute_name,0.0)

		if necklace_data.has("derived_stats"):
			for stat_name in necklace_data["derived_stats"]:
				stats.equipment_derived_stats[stat_name]=stats.equipment_derived_stats.get(stat_name,0.0)+necklace_data["derived_stats"][stat_name]

		if necklace_data.has("defences"):
			for damage_name in necklace_data["defences"]:
				stats.equipment_defence_bonus[stats.damage_type[damage_name]]+=necklace_data["defences"][damage_name]

		break
func applyArmorStats(slot,armor_table,stats):
	if !slot.texture: return

	for armor_name in armor_table:
		var armor_data=armor_table[armor_name]
		if !sameIcon(armor_data["icon"],slot.texture): continue

		stats.equipment_max_health+=armor_data.get("max_health",0)
		stats.equipment_max_arcane+=armor_data.get("max_arcane",0)
		stats.equipment_max_energy+=armor_data.get("max_energy",0)
		stats.equipment_movement_speed+=armor_data.get("mov_speed",0)*0.01

		for attribute_name in stats.equipment_attributes:
			stats.equipment_attributes[attribute_name]+=armor_data.get(attribute_name,0.0)

		if armor_data.has("derived_stats"):
			for stat_name in armor_data["derived_stats"]:
				stats.equipment_derived_stats[stat_name]=stats.equipment_derived_stats.get(stat_name,0.0)+armor_data["derived_stats"][stat_name]

		if armor_data.has("defences"):
			for damage_name in armor_data["defences"]:
				stats.equipment_defence_bonus[stats.damage_type[damage_name]]+=armor_data["defences"][damage_name]
		break

func applyWeaponStats(slot,weapon_table,stats):
	if !slot.texture: return

	for weapon_name in weapon_table:
		var weapon_data = weapon_table[weapon_name]
		if !sameIcon(weapon_data["icon"],slot.texture): continue

		stats.equipment_max_health += weapon_data.get("max_health",0)
		stats.equipment_max_arcane += weapon_data.get("max_arcane",0)
		stats.equipment_max_energy += weapon_data.get("max_energy",0)
		stats.equipment_movement_speed += weapon_data.get("mov_speed",0) * 0.01

		for attribute_name in stats.equipment_attributes:
			stats.equipment_attributes[attribute_name] += weapon_data.get(attribute_name,0.0)

		if weapon_data.has("derived_stats"):
			for stat_name in weapon_data["derived_stats"]:
				stats.equipment_derived_stats[stat_name] = stats.equipment_derived_stats.get(stat_name,0.0) + weapon_data["derived_stats"][stat_name]

		if weapon_data.has("damages"):
			for damage_name in weapon_data["damages"]:
				stats.equipment_damage_bonus[stats.damage_type[damage_name]] += weapon_data["damages"][damage_name]
		break





func _load_scene(path: String) -> PackedScene:
	if !ResourceLoader.exists(path):
		return null

	var scene = load(path)

	if scene is PackedScene:
		return scene

	return null

var default_scenes={
	"human":{
		"male":{
			"torso":preload("res://world/player/human/male/Torso0.tscn"),
			"hands":preload("res://world/player/human/male/Hands0.tscn"),
			"feet":preload("res://world/player/human/male/Feet0.tscn")
		},
		"female":{
			"torso":preload("res://world/player/human/female/Torso0.tscn"),
			"hands":preload("res://world/player/human/female/Hands0.tscn"),
			"feet":preload("res://world/player/human/female/Feet0.tscn")
		}
	}
}

var current_torso_scene:PackedScene
var current_hands_scene:PackedScene
var current_feet_scene:PackedScene


func sameIcon(icon,texture)->bool:
	if !texture: return false
	if icon is String:
		return icon == texture.resource_path
	return icon.resource_path == texture.resource_path

func findArmorScene(icon:Texture,slot:TextureRect,slot_type:String,default_scene:PackedScene,species:String,sex:String)->PackedScene:
	if icon==null:
		return default_scene

	for armor in Items.armors.values():
		if !sameIcon(armor.icon,icon): continue
		if armor.get("type","")!=slot_type:
			CommonBehaviours.addNotStackableItem($"../Inventory/ScrollContainer/GridContainer",armor,$"../Inventory")
			slot.texture=null
			return default_scene

		if species in armor.scene and sex in armor.scene[species]:
			return armor.scene[species][sex]

		return default_scene

	var weapon=findWeaponFromIcon(icon)
	if !weapon.empty():
		CommonBehaviours.addNotStackableItem($"../Inventory/ScrollContainer/GridContainer",weapon,$"../Inventory")

	slot.texture=null
	return default_scene
	
	
func updateArmorCache(species:String,sex):
	var defaults=default_scenes.get(species,null)
	if !defaults:
		return

	var sex_defaults=defaults.get(sex,null)
	if !sex_defaults:
		return

	torso_scene=findArmorScene(slot_torso.texture,slot_torso,"torso",sex_defaults.get("torso",null),species,sex)
	hands_scene=findArmorScene(slot_hands.texture,slot_hands,"hands",sex_defaults.get("hands",null),species,sex)
	feet_scene=findArmorScene(slot_feet.texture,slot_feet,"feet",sex_defaults.get("feet",null),species,sex)
	
func equipmentChanged()->bool:
	return !(
		current_species==$"../../Stats".species
		and current_sex==$"../../Stats".sex
		and current_torso_scene==torso_scene
		and current_hands_scene==hands_scene
		and current_feet_scene==feet_scene)

func updateEquipmentCache()->void:
	current_species=$"../../Stats".species
	current_sex=$"../../Stats".sex
	current_torso_scene=torso_scene
	current_hands_scene=hands_scene
	current_feet_scene=feet_scene


var equipment_initialized=false
func updateEquipment()->void:
	var stats=$"../../Stats"
	var c=$"../../character"
	if !c or !is_instance_valid(c): return

	skeleton=c.get_node_or_null("root/Skeleton")
	if !skeleton: return

	bone_holder_right=skeleton.get_node_or_null("WeaponR")
	bone_holder_left=skeleton.get_node_or_null("WeaponL")
	bone_holder_hipL=skeleton.get_node_or_null("HipR")
	bone_holder_hipR=skeleton.get_node_or_null("HipL")
	bone_holder_backUP=skeleton.get_node_or_null("BackUp")
	bone_holder_backLow=skeleton.get_node_or_null("BackLow")
	bone_holder_back_shield=skeleton.get_node_or_null("ShieldBack")
	bone_holder_shield=skeleton.get_node_or_null("Shield")
	bone_holer_hips_invertedL=skeleton.get_node_or_null("IvR")
	bone_holer_hips_invertedR=skeleton.get_node_or_null("IvL")

	updateArmorCache(stats.species,stats.sex)

	if !equipment_initialized:
		current_species=stats.species
		current_sex=stats.sex
		current_torso_scene=torso_scene
		current_hands_scene=hands_scene
		current_feet_scene=feet_scene
		updateTorso()
		updateHands()
		updateFeet()
		equipment_initialized=true
	else:
		if equipmentChanged():
			updateEquipmentCache()
			updateTorso()
			updateHands()
			updateFeet()

	updateWeapons()
	get_equipment_stats()






const SKIN_MATERIAL = preload("res://world/player/human/mesh/Torso0.material")

func replaceEquipmentNode(current_node,scene):
	if scene==null:
		return null

	var c=$"../../character"
	if c==null or !is_instance_valid(c):
		return null

	var sk=c.get_node_or_null("root/Skeleton")
	if sk==null:
		return null

	if is_instance_valid(current_node):
		current_node.queue_free()

	var node=scene.instance()
	if node==null:
		return null

	for mesh_instance in node.get_children():
		if mesh_instance is MeshInstance and SKIN_MATERIAL!=null:
			mesh_instance.set_surface_material(0,SKIN_MATERIAL)

	setUnshaded(node)

	sk.add_child(node)
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




var was_mining=false


func updateWeapons()->void:
	var inventory_grid:GridContainer=$"../Inventory/ScrollContainer/GridContainer"
	var inventory:Control=$"../Inventory"
	var floating_parent:Control=$"../Menu/CharacterBar"

	if player.current_skill=="mine":
		startToolSkill("mining",inventory_grid)
		inventory.updateInventory()
	elif player.current_skill=="chop":
		startToolSkill("chopping",inventory_grid)
		inventory.updateInventory()
	elif active_tool_skill!="":
		stopToolSkill(inventory_grid)
		inventory.updateInventory()


	updateWeaponVisuals(inventory_grid,floating_parent)


var skill_original_weapon=null
var skill_original_offhand=null
var skill_original_slots=[]
var skill_took_tool=false
var active_tool_skill=""
func startToolSkill(skill,inven)->void:
	if active_tool_skill==skill:
		return

	if active_tool_skill!="":
		stopToolSkill(inven)

	var current=findWeaponFromIcon(slot_mainhand.texture)
	if !current.empty() and current.has(skill+" power"):
		active_tool_skill=skill
		return

	active_tool_skill=skill
	skill_original_slots=[]

	if slot_mainhand.texture:
		for slot in inven.get_children():
			var icon=slot.get_node_or_null("Slot")
			if icon and !icon.texture:
				icon.texture=slot_mainhand.texture
				skill_original_slots.append({"hand":0,"slot":icon})
				slot_mainhand.texture=null
				break

	if slot_offhand.texture:
		for slot in inven.get_children():
			var icon=slot.get_node_or_null("Slot")
			if icon and !icon.texture:
				icon.texture=slot_offhand.texture
				skill_original_slots.append({"hand":1,"slot":icon})
				slot_offhand.texture=null
				break

	skill_took_tool=false
	swapSkillTool(skill,inven)


func stopToolSkill(inven)->void:
	if active_tool_skill=="":
		return

	if skill_took_tool and slot_mainhand.texture:
		var tool=findWeaponFromIcon(slot_mainhand.texture)
		if !tool.empty():
			CommonBehaviours.addNotStackableItem(inven,tool,self)
		slot_mainhand.texture=null

	for data in skill_original_slots:
		var icon=data["slot"]
		if !is_instance_valid(icon):
			continue

		if data["hand"]==0 and !slot_mainhand.texture:
			slot_mainhand.texture=icon.texture
			icon.texture=null
		elif data["hand"]==1 and !slot_offhand.texture:
			slot_offhand.texture=icon.texture
			icon.texture=null

	skill_original_slots=[]
	skill_took_tool=false
	active_tool_skill=""

#func stopToolSkill(inven)->void:
#	if active_tool_skill=="":
#		return
#
#	if skill_took_tool and slot_mainhand.texture:
#		var tool=findWeaponFromIcon(slot_mainhand.texture)
#		if !tool.empty():
#			CommonBehaviours.addNotStackableItem(inven,tool,self)
#
#	slot_mainhand.texture=null
#	slot_offhand.texture=null
#
#	for data in skill_original_slots:
#		var icon=data["slot"]
#		if !is_instance_valid(icon):
#			continue
#
#		if data["hand"]==0:
#			slot_mainhand.texture=icon.texture
#		else:
#			slot_offhand.texture=icon.texture
#
#		icon.texture=null
#
#	skill_original_slots=[]
#	skill_took_tool=false
#	active_tool_skill=""








func swapSkillTool(skill,inven)->void:
	var tools=[]

	for key in Items.weapons:
		var weapon=Items.weapons[key]
		if weapon.has(skill+" power"):
			tools.append(weapon)

	tools.sort_custom(self,"sortTools")

	for utensil in tools:
		var icon=utensil["icon"]
		if typeof(icon)==TYPE_STRING:
			icon=load(icon)

		for slot in inven.get_children():
			var slot_icon=slot.get_node_or_null("Slot")
			if slot_icon and slot_icon.texture==icon:
				slot_icon.texture=null
				slot_mainhand.texture=icon
				skill_took_tool=true
				return




func sortTools(a,b):
	return a.get("mining power",a.get("chopping power",0))>b.get("mining power",b.get("chopping power",0))



func updateWeaponVisuals(inventory_grid,floating_parent)->void:
	reset_bone_transform("weapon_r")

	for node in [current_main_weapon_node,current_offhand_weapon_node,current_shield_node]:
		if is_instance_valid(node):
			node.queue_free()

	current_main_weapon_node=null
	current_offhand_weapon_node=null
	current_shield_node=null
	player.weapons=player.WeaponMode.NONE

	if !slot_mainhand.texture:
		slot_offhand.get_parent().visible=false
		if slot_offhand.texture:
			var returned_weapon=findWeaponFromIcon(slot_offhand.texture)
			if !returned_weapon.empty():
				CommonBehaviours.addNotStackableItem(inventory_grid,returned_weapon,floating_parent)
			slot_offhand.texture=null
		return

	var main_weapon=findWeaponFromIcon(slot_mainhand.texture)

	if main_weapon.get("carry","")=="shield":
		CommonBehaviours.addNotStackableItem(inventory_grid,main_weapon,floating_parent)
		slot_mainhand.texture=null
		return

	if main_weapon.empty():
		return

	var two_handed=main_weapon.get("two handed",false)
	slot_offhand.get_parent().visible=!two_handed

	if two_handed and slot_offhand.texture and !was_mining:
		var returned_weapon=findWeaponFromIcon(slot_offhand.texture)
		if !returned_weapon.empty():
			CommonBehaviours.addNotStackableItem(inventory_grid,returned_weapon,floating_parent)
		slot_offhand.texture=null

	var offhand_item=findWeaponFromIcon(slot_offhand.texture)
	var offhand_weapon={}
	var shield_weapon={}

	if !offhand_item.empty():
		if offhand_item.get("two handed",false) and !was_mining:
			CommonBehaviours.addNotStackableItem(inventory_grid,offhand_item,floating_parent)
			slot_offhand.texture=null
		elif offhand_item.get("carry","")=="shield":
			shield_weapon=offhand_item
		else:
			offhand_weapon=offhand_item

	var main_holder:Node
	var offhand_holder:Node

	if player.is_in_combat:
		main_holder=bone_holder_right
		offhand_holder=bone_holder_left
	else:
		match main_weapon.get("carry","hips"):
			"hips": main_holder=bone_holder_hipR
			"hips inverted": main_holder=bone_holer_hips_invertedR
			"back up": main_holder=bone_holder_backUP
			"back low": main_holder=bone_holder_backLow
			_: main_holder=bone_holder_hipR

		if !offhand_weapon.empty():
			match offhand_weapon.get("carry","hips"):
				"hips": offhand_holder=bone_holder_hipL
				"hips inverted": offhand_holder=bone_holer_hips_invertedL
				"back up": offhand_holder=bone_holder_backUP
				"back low": offhand_holder=bone_holder_backLow
				_: offhand_holder=bone_holder_hipL
		else:
			offhand_holder=bone_holder_hipL

	current_main_weapon_node=_spawn_weapon(main_weapon,main_holder)

	if !shield_weapon.empty():
		current_shield_node=shield_weapon.scene.instance()
		var shield_holder=bone_holder_shield if player.is_in_combat else bone_holder_back_shield
		shield_holder.add_child(current_shield_node)
	elif !offhand_weapon.empty():
		current_offhand_weapon_node=_spawn_weapon(offhand_weapon,offhand_holder)

	if !shield_weapon.empty():
		player.weapons=player.WeaponMode.SHIELD
	elif two_handed:
		player.weapons=player.WeaponMode.TWO_HANDED
	elif !offhand_weapon.empty():
		player.weapons=player.WeaponMode.DUAL
	else:
		player.weapons=player.WeaponMode.SWORD












var bone_default_rest = {}

func cache_bone_rest(bone_name:String) -> void:
	if bone_default_rest.has(bone_name):
		return

	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return

	bone_default_rest[bone_name] = skeleton.get_bone_rest(bone_idx)
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
func rotate_bone(bone_name:String,x_degrees:float=0.0,y_degrees:float=0.0,z_degrees:float=0.0)->void:
	if skeleton==null or !is_instance_valid(skeleton):
		return

	var bone_idx=skeleton.find_bone(bone_name)
	if bone_idx==-1:
		return

	cache_bone_rest(bone_name)

	if bone_default_rest==null or !bone_default_rest.has(bone_name):
		return

	var rest=bone_default_rest[bone_name]
	if rest==null:
		return

	var rot_basis=Basis()
	rot_basis=rot_basis.rotated(Vector3.RIGHT,deg2rad(x_degrees))
	rot_basis=rot_basis.rotated(Vector3.UP,deg2rad(y_degrees))
	rot_basis=rot_basis.rotated(Vector3.FORWARD,deg2rad(z_degrees))

	var new_transform=Transform(rest.basis*rot_basis,rest.origin)

	if skeleton is Skeleton:
		skeleton.set_bone_rest(bone_idx,new_transform)



func reset_bone_transform(bone_name:String)->void:
	if skeleton==null or !is_instance_valid(skeleton):
		return

	var bone_idx=skeleton.find_bone(bone_name)
	if bone_idx==-1:
		return

	if bone_default_rest==null or !bone_default_rest.has(bone_name):
		return

	var rest=bone_default_rest[bone_name]
	if rest==null:
		return

	if skeleton is Skeleton:
		skeleton.set_bone_rest(bone_idx,rest)




func move_bone(bone_name:String,x_offset:float=0.0,y_offset:float=0.0,z_offset:float=0.0)->void:
	if skeleton==null or !is_instance_valid(skeleton):
		return

	var bone_idx=skeleton.find_bone(bone_name)
	if bone_idx==-1:
		return

	cache_bone_rest(bone_name)

	if bone_default_rest==null or !bone_default_rest.has(bone_name):
		return

	var rest=bone_default_rest[bone_name]
	if rest==null:
		return

	var new_transform=Transform(rest.basis,rest.origin+Vector3(x_offset,y_offset,z_offset))

	if skeleton is Skeleton:
		skeleton.set_bone_rest(bone_idx,new_transform)


func reset_bone_position(bone_name:String)->void:
	if skeleton==null or !is_instance_valid(skeleton):
		return

	var bone_idx=skeleton.find_bone(bone_name)
	if bone_idx==-1:
		return

	if bone_default_rest==null or !bone_default_rest.has(bone_name):
		return

	var rest=bone_default_rest[bone_name]
	if rest==null:
		return

	if skeleton is Skeleton:
		skeleton.set_bone_rest(bone_idx,rest)
	
	
	
	
	
	
	
	
	
	
	
	
	
func findWeaponFromIcon(icon:Texture)->Dictionary:
	for weapon in Items.weapons.values():
		if sameIcon(weapon["icon"],icon):
			var result=weapon.duplicate()
			result["icon"]=load(result["icon"]) if result["icon"] is String else result["icon"]
			return result
	return {}

func _spawn_weapon(weapon_data:Dictionary,parent:Node)->Node:
	if weapon_data.empty():
		return null
	if parent==null or !is_instance_valid(parent):
		return null

	var scene=weapon_data.get("scene",null)
	if !(scene is PackedScene):
		return null

	var node=scene.instance()
	if node==null:
		return null

	setUnshaded(node)
	parent.add_child(node)
	return node


onready var ring = $Ring
onready var ring2 = $Ring2
onready var ring3 = $Ring3
onready var ring4 = $Ring4
onready var ring5 = $Ring5
onready var ring6 = $Ring6
onready var ring7 = $Ring7
onready var ring8 = $Ring8
func saveData() -> void:
	var dir=Directory.new()
	if !dir.dir_exists(SAVE_DIR):
		dir.make_dir_recursive(SAVE_DIR)

	var file=File.new()
	var path=SAVE_DIR+player.entity_name+".save"

	var data={
		"visible":visible,
		"Torso":getTexturePath(slot_torso),
		"Hands":getTexturePath(slot_hands),
		"Feet":getTexturePath(slot_feet),
		"MainHand":getTexturePath(slot_mainhand),
		"OffHand":getTexturePath(slot_offhand),
		"Necklace":getTexturePath($Necklace/Slot),
		"Ring":getTexturePath(ring.get_node_or_null("Slot")),
		"Ring2":getTexturePath(ring2.get_node_or_null("Slot")),
		"Ring3":getTexturePath(ring3.get_node_or_null("Slot")),
		"Ring4":getTexturePath(ring4.get_node_or_null("Slot")),
		"Ring5":getTexturePath(ring5.get_node_or_null("Slot")),
		"Ring6":getTexturePath(ring6.get_node_or_null("Slot")),
		"Ring7":getTexturePath(ring7.get_node_or_null("Slot")),
		"Ring8":getTexturePath(ring8.get_node_or_null("Slot"))
	}

	if file.open(path,File.WRITE)==OK:
		file.store_var(data)
		file.close()

func loadData() -> void:
	yield(get_tree(),"idle_frame")

	var path=SAVE_DIR+player.entity_name+".save"
	var file=File.new()

	var function_reset_equipment=funcref(self,"resetEquipment")

	if !file.file_exists(path):
		function_reset_equipment.call_func()
		return

	if file.open(path,File.READ)!=OK:
		function_reset_equipment.call_func()
		return

	var data=file.get_var()
	file.close()

	if typeof(data)!=TYPE_DICTIONARY:
		function_reset_equipment.call_func()
		return

	visible=data.get("visible",visible)

	loadTexture(slot_torso,data.get("Torso",""))
	loadTexture(slot_hands,data.get("Hands",""))
	loadTexture(slot_feet,data.get("Feet",""))
	loadTexture(slot_mainhand,data.get("MainHand",""))
	loadTexture(slot_offhand,data.get("OffHand",""))
	loadTexture($Necklace/Slot,data.get("Necklace",""))
	loadTexture(ring.get_node("Slot"),data.get("Ring",""))
	loadTexture(ring2.get_node("Slot"),data.get("Ring2",""))
	loadTexture(ring3.get_node("Slot"),data.get("Ring3",""))
	loadTexture(ring4.get_node("Slot"),data.get("Ring4",""))
	loadTexture(ring5.get_node("Slot"),data.get("Ring5",""))
	loadTexture(ring6.get_node("Slot"),data.get("Ring6",""))
	loadTexture(ring7.get_node("Slot"),data.get("Ring7",""))
	loadTexture(ring8.get_node("Slot"),data.get("Ring8",""))

	updateEquipment()
	get_equipment_stats()


func loadTexture(slot,path:String)->void:
	if !slot:return
	if slot.has_node("Slot"):
		slot=slot.get_node("Slot")
	slot.texture=null
	if path!="" and ResourceLoader.exists(path):
		slot.texture=load(path)
		
		
func resetEquipment():
	if is_instance_valid(slot_torso):
		var icon=Items.armors["torso1"]["icon"]
		slot_torso.texture=load(icon) if typeof(icon)==TYPE_STRING else icon

	if is_instance_valid(slot_hands):
		var icon=Items.armors["hands1"]["icon"]
		slot_hands.texture=load(icon) if typeof(icon)==TYPE_STRING else icon

	if is_instance_valid(slot_feet):
		var icon=Items.armors["feet1"]["icon"]
		slot_feet.texture=load(icon) if typeof(icon)==TYPE_STRING else icon

	if is_instance_valid(slot_mainhand): slot_mainhand.texture=null
	if is_instance_valid(slot_offhand): slot_offhand.texture=null

	updateEquipment()
	
func getTexturePath(slot:TextureRect)->String:
	if !slot or !slot.texture: return ""
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
		

