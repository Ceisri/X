extends Control #Equipment.gd for the equipment node 

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
# ONLINE ADDITION — equipment sync
var net_torso_path := ""
var net_hands_path := ""
var net_feet_path := ""
var net_mainhand_path := ""
var net_offhand_path := ""
var net_necklace_path := ""
var net_ring_paths := ["", "", "", "", "", "", "", ""]

var _last_sent_equipment_signature := ""
export var equip_sync_rate := 0.2
var equip_sync_timer := 0.0
var _last_applied_equipment_signature := ""



# Equipment.gd — _ready(), replace the local-player branch
func _ready():
	current_species=$"../../Stats".species
	current_sex=$"../../Stats".sex
	current_torso_scene=torso_scene
	current_hands_scene=hands_scene
	current_feet_scene=feet_scene
	close_button.connect("pressed", self, "collapse")
	if player.isLocalPlayer():
		if get_tree().network_peer == null:
			call_deferred("loadOfflineEquipment")
		elif !Global.pending_equipment_snapshot.empty(): 
			call_deferred("_applyPendingEquipmentSnapshot")






func applyEquipmentSnapshotAuthority(data: Dictionary) -> void:
	# Called by the server directly on its own copy of Equipment, regardless
	# of who owns the player -- same effect as applyOwnEquipmentSnapshot but
	# without the isLocalPlayer gate.
	_applyEquipmentSnapshotInternal(data)

remote func applyOwnEquipmentSnapshot(data: Dictionary) -> void:
	if !player.isLocalPlayer():
		return
	_applyEquipmentSnapshotInternal(data)
var _equipment_data_ready := false # true once THIS client has real equipment loaded locally

# ===== Equipment.gd =====

func _applyEquipmentSnapshotInternal(data: Dictionary) -> void:
	loadTexture(slot_torso, data.get("torso",""))
	loadTexture(slot_hands, data.get("hands",""))
	loadTexture(slot_feet, data.get("feet",""))
	loadTexture(slot_mainhand, data.get("mainhand",""))
	loadTexture(slot_offhand, data.get("offhand",""))
	loadTexture($Necklace/Slot, data.get("necklace",""))
	var rings = data.get("rings", ["","","","","","","",""])
	loadTexture(ring.get_node("Slot"), rings[0])
	loadTexture(ring2.get_node("Slot"), rings[1])
	loadTexture(ring3.get_node("Slot"), rings[2])
	loadTexture(ring4.get_node("Slot"), rings[3])
	loadTexture(ring5.get_node("Slot"), rings[4])
	loadTexture(ring6.get_node("Slot"), rings[5])
	loadTexture(ring7.get_node("Slot"), rings[6])
	loadTexture(ring8.get_node("Slot"), rings[7])
	_equipment_data_ready = true

	# FIX (equipment loading working only ~1/3 of the time): this can land
	# mid ApplySex()/reinitializeForEntity() rebuild -- character node
	# briefly invalid (queue_free'd old, new one not added yet) or skeleton
	# not yet resolved. updateEquipment() already no-ops safely when that
	# happens, but nothing ever retried afterward, so the gear silently
	# never got attached. Retry for a few frames until it actually sticks.
	_retryUpdateEquipmentUntilReady()

var _equipment_retry_count := 0
func _retryUpdateEquipmentUntilReady() -> void:
	_equipment_retry_count = 0
	_doRetryEquipment()

func _doRetryEquipment() -> void:
	updateEquipment()
	get_equipment_stats()
	var c = $"../../character"
	if (!is_instance_valid(c) or !equipment_initialized) and _equipment_retry_count < 30:
		_equipment_retry_count += 1
		yield(get_tree(), "idle_frame")
		_doRetryEquipment()



var _equip_frame_offset:int = -1
var _last_equip_update_in_combat := false
var _last_equip_detect_signature := ""

func _buildEquipDetectSignature() -> String:
	return getTexturePath(slot_torso) + "|" + getTexturePath(slot_hands) + "|" + getTexturePath(slot_feet) + "|" \
		+ getTexturePath(slot_mainhand) + "|" + getTexturePath(slot_offhand) + "|" + getTexturePath($Necklace/Slot) + "|" \
		+ getTexturePath(ring.get_node("Slot")) + "," + getTexturePath(ring2.get_node("Slot")) + "," \
		+ getTexturePath(ring3.get_node("Slot")) + "," + getTexturePath(ring4.get_node("Slot")) + "," \
		+ getTexturePath(ring5.get_node("Slot")) + "," + getTexturePath(ring6.get_node("Slot")) + "," \
		+ getTexturePath(ring7.get_node("Slot")) + "," + getTexturePath(ring8.get_node("Slot"))

func _physics_process(delta):
	if player.isLocalPlayer():
		var in_combat_now:bool = player.is_in_combat
		var current_sig:String = _buildEquipDetectSignature()
		if in_combat_now != _last_equip_update_in_combat or current_sig != _last_equip_detect_signature:
			_last_equip_update_in_combat = in_combat_now
			_last_equip_detect_signature = current_sig
			player_name_label.text = player.entity_name + ": "+ $"../../Stats".sex
			updateEquipment()
		_syncEquipmentToPuppets(delta)
		if Input.is_action_just_pressed("equipment"):
			visible = !visible 
		if Input.is_action_just_pressed("up"):
			move_bone("HipHolder.l", 0, 0, -5)
			move_bone("inverted.l", 0, 0, -5)
			move_bone("HipHolder.r", 0, 0, 5)
			move_bone("inverted.r", 0, 0, 5)
		if Input.is_action_just_pressed("down"):
			move_bone("HipHolder.l", 0, 0, 5)
			move_bone("HipHolder.r", 0, 0, -5)
	else:
		_applyPuppetEquipmentIfChanged()


var _peer_equipment_signatures := {} # peer_id -> last signature actually sent to that peer

func _syncEquipmentToPuppets(delta)->void:
	if get_tree().network_peer == null:
		return
	if !_equipment_data_ready:
		return
	equip_sync_timer += delta
	if equip_sync_timer < equip_sync_rate:
		return
	equip_sync_timer = 0.0

	var snap := _buildSnapshot()
	Global.rpc_id(1, "reportEquipment", snap)

	var signature := str(snap)
	_last_sent_equipment_signature = signature

	var current_peers := _getWorldPeers()
	var known_peer_ids := {}
	var my_id := get_tree().get_network_unique_id()

	for peer_id in current_peers:
		known_peer_ids[peer_id] = true
		if peer_id == my_id:
			continue

		var already_sent = _peer_equipment_signatures.has(peer_id)
		var same_signature = already_sent and _peer_equipment_signatures[peer_id] == signature

		if same_signature:
			continue

		_peer_equipment_signatures[peer_id] = signature

		if already_sent:
			# routine update to a peer already caught up -- fine on the
			# unreliable channel, a dropped packet just gets superseded
			# by the next 0.2s tick.
			rpc_unreliable_id(peer_id, "receiveEquipmentSync", snap)
		else:
			# first-ever send to this peer (they just entered this world,
			# or reconnected). This MUST land -- with the old signature-
			# only gate, if this packet dropped or if the peer joined
			# after the signature had already stabilized, that peer would
			# see this player naked for the rest of the session with no
			# way to self-correct, since nothing would ever trigger a
			# resend to them specifically.
			rpc_id(peer_id, "receiveEquipmentSync", snap)

	# Prune peers no longer in this world -- if they leave and rejoin
	# (or portal back in), they're treated as new again and get a fresh
	# guaranteed send instead of being silently skipped forever.
	for peer_id in _peer_equipment_signatures.keys():
		if !known_peer_ids.has(peer_id):
			_peer_equipment_signatures.erase(peer_id)
# Mirrors Global._findWorldOf -- scope the broadcast to peers
# actually standing in the same world, not every connected peer server-wide.
func _findMyWorld() -> Node:
	var n = get_parent()
	while n:
		if "world_id" in n:
			return n
		n = n.get_parent()
	return null

func _getWorldPeers() -> Array:
	var result := []
	var world = _findMyWorld()
	var my_world_id = (world.world_id if is_instance_valid(world) and "world_id" in world else "")
	for peer_id in Global.spawned_players.keys():
		if Global.spawned_players[peer_id].get("world_id","") == my_world_id:
			result.append(peer_id)
	return result
remote func receiveEquipmentSync(data:Dictionary) -> void:
	if player.isLocalPlayer():
		return
	net_torso_path = data.torso
	net_hands_path = data.hands
	net_feet_path = data.feet
	net_mainhand_path = data.mainhand
	net_offhand_path = data.offhand
	net_necklace_path = data.necklace
	net_ring_paths = data.rings
	_applyPuppetEquipmentIfChanged()
func _applyPuppetEquipmentIfChanged()->void:
	var signature := (
		net_torso_path + "|" + net_hands_path + "|" + net_feet_path + "|" +
		net_mainhand_path + "|" + net_offhand_path + "|" + net_necklace_path + "|" +
		String(net_ring_paths) + "|" + str(player.is_in_combat)
	)
	if signature == _last_applied_equipment_signature:
		return

	var c=$"../../character"
	if !c or !is_instance_valid(c):
		return  # don't cache — retry next physics frame

	loadTexture(slot_torso, net_torso_path)
	loadTexture(slot_hands, net_hands_path)
	loadTexture(slot_feet, net_feet_path)
	loadTexture(slot_mainhand, net_mainhand_path)
	loadTexture(slot_offhand, net_offhand_path)
	loadTexture($Necklace/Slot, net_necklace_path)
	loadTexture(ring.get_node("Slot"), net_ring_paths[0])
	loadTexture(ring2.get_node("Slot"), net_ring_paths[1])
	loadTexture(ring3.get_node("Slot"), net_ring_paths[2])
	loadTexture(ring4.get_node("Slot"), net_ring_paths[3])
	loadTexture(ring5.get_node("Slot"), net_ring_paths[4])
	loadTexture(ring6.get_node("Slot"), net_ring_paths[5])
	loadTexture(ring7.get_node("Slot"), net_ring_paths[6])
	loadTexture(ring8.get_node("Slot"), net_ring_paths[7])

	updateEquipment()
	_last_applied_equipment_signature = signature   # only cache on success




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

	applyArmorStats(slot_torso,Global.armors,stats)
	applyArmorStats(slot_hands,Global.armors,stats)
	applyArmorStats(slot_feet,Global.armors,stats)

	applyRingStats(ring,Global.rings,stats)
	applyRingStats(ring2,Global.rings,stats)
	applyRingStats(ring3,Global.rings,stats)
	applyRingStats(ring4,Global.rings,stats)
	applyRingStats(ring5,Global.rings,stats)
	applyRingStats(ring6,Global.rings,stats)
	applyRingStats(ring7,Global.rings,stats)
	applyRingStats(ring8,Global.rings,stats)
	applyNecklaceStats($Necklace,Global.necklaces,stats)
	applyWeaponStats(slot_mainhand,Global.weapons,stats)
	applyWeaponStats(slot_offhand,Global.weapons,stats)

	stats.markAttributeCacheDirty()
	# Only the entity that actually owns combat authority (server, for
	# players and mobs alike) is allowed to recompute health/max_health/etc
	# from formula. Calling updateAttributes() here unconditionally used to
	# let the CLIENT's own puppet Stats node recompute and clamp its own
	# health every ~0.2s regardless of what the server had just told it via
	# net_health -- stomping the correct value one tick after it arrived.
	# The puppet path (_applyPuppetStats, fed by MobSync/snapshot RPCs) is
	# the only thing that should ever set health/max_health on a non-
	# authoritative Stats node.
	if stats.isAuthority():
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

# NOTE: added "kragun" -> "unisex" default entry so kragun characters have
# a base torso/hands/feet to fall back on. Previously kragun had no entry
# here at all, so updateArmorCache() bailed out via `if !defaults: return`
# and kragun equipment never got initialized.
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
	},
	"kragun":{
		"unisex":{
			"torso":preload("res://world/player/kragun/unisex/KragunTorso0.tscn"),
			"hands":preload("res://world/player/kragun/unisex/Hands0.tscn"),
			"feet":preload("res://world/player/kragun/unisex/Feet0.tscn")
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




func equipmentChanged()->bool:
	return !(
		current_species==$"../../Stats".species
		and current_sex==$"../../Stats".sex
		and current_torso_scene==torso_scene
		and current_hands_scene==hands_scene
		and current_feet_scene==feet_scene)

func forceReapplyEquipment() -> void:
	# Called after the character's skeleton itself has been rebuilt (sex swap).
	# equipmentChanged() only detects whether equipped ITEMS differ -- it has
	# no way to know the skeleton underneath is a brand new node, so if the
	# item set matches what was cached, it silently skips updateTorso/Hands/
	# Feet. The old nodes were already freed along with the old skeleton, so
	# skipping means the new skeleton ends up with nothing attached. Resetting
	# equipment_initialized forces updateEquipment() down its unconditional
	# "first init" path instead of trusting the diff.
	equipment_initialized = false
	current_torso_node = null
	current_hands_node = null
	current_feet_node = null
	updateEquipment()



func updateEquipmentCache()->void:
	current_species=$"../../Stats".species
	current_sex=$"../../Stats".sex
	current_torso_scene=torso_scene
	current_hands_scene=hands_scene
	current_feet_scene=feet_scene


var equipment_initialized=false
func updateEquipment() -> void:
	var stats = $"../../Stats"
	var c = $"../../character"
	if !c or !is_instance_valid(c):
		return

	skeleton = c.get_node_or_null("root/Skeleton")
	if !skeleton:
		return

	if !player.has_method("_shouldAnimateLocally") or player._shouldAnimateLocally():
		bone_holder_right = skeleton.get_node_or_null("WeaponR")
		bone_holder_left = skeleton.get_node_or_null("WeaponL")
		bone_holder_hipL = skeleton.get_node_or_null("HipR")
		bone_holder_hipR = skeleton.get_node_or_null("HipL")
		bone_holder_backUP = skeleton.get_node_or_null("BackUp")
		bone_holder_backLow = skeleton.get_node_or_null("BackLow")
		bone_holder_back_shield = skeleton.get_node_or_null("ShieldBack")
		bone_holder_shield = skeleton.get_node_or_null("Shield")
		bone_holer_hips_invertedL = skeleton.get_node_or_null("IvR")
		bone_holer_hips_invertedR = skeleton.get_node_or_null("IvL")

		updateArmorCache(stats.species, stats.sex)

		if !equipment_initialized:
			current_species = stats.species
			current_sex = stats.sex
			current_torso_scene = torso_scene
			current_hands_scene = hands_scene
			current_feet_scene = feet_scene
			updateTorso()
			updateHands()
			updateFeet()
			equipment_initialized = true
		else:
			if equipmentChanged():
				updateEquipmentCache()
				updateTorso()
				updateHands()
				updateFeet()
	
		updateWeapons()
		player.markToolCacheDirty()
	get_equipment_stats()






# Cheap, instant weapon-carry-position fix. Does ONLY a reparent of the
# already-instanced weapon nodes -- no re-instancing, no full
# updateWeaponVisuals() rebuild. Safe to call every time is_in_combat
# flips, guarantees the weapon is in combat-hand the same frame combat
# starts instead of waiting for Equipment's own polling _physics_process.
func instantWeaponCarryUpdate() -> void:
	if !slot_mainhand.texture:
		return
	var main_weapon = findWeaponFromIcon(slot_mainhand.texture)
	if main_weapon.empty():
		return

	var main_holder:Node
	var offhand_holder:Node

	if player.is_in_combat and player.current_skill != "gather":
		main_holder = bone_holder_right
		offhand_holder = bone_holder_left
	else:
		match main_weapon.get("carry","hips"):
			"hips": main_holder = bone_holder_hipR
			"hips inverted": main_holder = bone_holer_hips_invertedR
			"back up": main_holder = bone_holder_backUP
			"back low": main_holder = bone_holder_backLow
			_: main_holder = bone_holder_hipR
		offhand_holder = bone_holder_hipL

	if is_instance_valid(current_main_weapon_node) and is_instance_valid(main_holder):
		var cur_parent = current_main_weapon_node.get_parent()
		if cur_parent != main_holder:
			cur_parent.remove_child(current_main_weapon_node)
			main_holder.add_child(current_main_weapon_node)

	if is_instance_valid(current_shield_node):
		var shield_holder = bone_holder_shield if player.is_in_combat else bone_holder_back_shield
		if is_instance_valid(shield_holder):
			var cs_parent = current_shield_node.get_parent()
			if cs_parent != shield_holder:
				cs_parent.remove_child(current_shield_node)
				shield_holder.add_child(current_shield_node)
	elif is_instance_valid(current_offhand_weapon_node) and is_instance_valid(offhand_holder):
		var co_parent = current_offhand_weapon_node.get_parent()
		if co_parent != offhand_holder:
			co_parent.remove_child(current_offhand_weapon_node)
			offhand_holder.add_child(current_offhand_weapon_node)







# UPDATED: species/sex lookup now falls back to a "unisex" scene entry
# instead of a hard "if species == kragun" special case. This means:
#   - an armor can define scene = { "kragun": { "unisex": <scene> } }
#     and it'll be picked up for kragun regardless of `sex`
#   - an armor can define scene = { "unisex": { "unisex": <scene> } }
#     (top-level, no species key) and it'll apply to ANY species/sex
#     that doesn't have a more specific entry -- useful for armors that
#     genuinely look the same on everyone.
# `sex` passed in is already normalized to "unisex" for kragun by
# updateArmorCache(), so species-specific unisex entries resolve via the
# normal `sex in armor.scene[species]` check without special-casing.
func findArmorScene(icon: Texture, slot: TextureRect, slot_type: String, default_scene: PackedScene, species: String, sex: String) -> PackedScene:
	if icon == null:
		return default_scene

	for armor in Global.armors.values():
		if !sameIcon(armor.icon, icon):
			continue
		if armor.get("type", "") != slot_type:
			Global.addNotStackableItem($"../Inventory/ScrollContainer/GridContainer", armor, $"../Inventory")
			slot.texture = null
			return default_scene

		# exact species + sex match
		if species in armor.scene and sex in armor.scene[species]:
			return armor.scene[species][sex]

		# species defined but only has a unisex variant
		if species in armor.scene and "unisex" in armor.scene[species]:
			return armor.scene[species]["unisex"]

		# armor defines a single scene shared by every species/sex
		if "unisex" in armor.scene:
			if sex in armor.scene["unisex"]:
				return armor.scene["unisex"][sex]
			if "unisex" in armor.scene["unisex"]:
				return armor.scene["unisex"]["unisex"]

		return default_scene

	var weapon = findWeaponFromIcon(icon)
	if !weapon.empty():
		Global.addNotStackableItem($"../Inventory/ScrollContainer/GridContainer", weapon, $"../Inventory")

	slot.texture = null
	return default_scene

# UPDATED: no longer short-circuits kragun to null scenes. Normalizes sex
# to "unisex" for kragun (or any future unisex-only species you add to
# default_scenes with a "unisex" key instead of "male"/"female") and then
# runs the normal default-scene + per-armor lookup, same as human.
func updateArmorCache(species: String, sex: String):
	var sex_key = sex
	var defaults = default_scenes.get(species, null)
	if defaults and defaults.has("unisex") and !defaults.has(sex):
		sex_key = "unisex"

	if !defaults:
		return

	var sex_defaults = defaults.get(sex_key, null)
	if !sex_defaults:
		return

	var is_full_armor = false

	if slot_torso.texture:
		for armor in Global.armors.values():
			if !sameIcon(armor.icon, slot_torso.texture):
				continue

			if armor.get("full", false):
				is_full_armor = true
			break

	torso_scene = findArmorScene(slot_torso.texture, slot_torso, "torso", sex_defaults.torso, species, sex_key)

	if is_full_armor:
		hands_scene = null
		feet_scene = null
	else:
		hands_scene = findArmorScene(slot_hands.texture, slot_hands, "hands", sex_defaults.hands, species, sex_key)
		feet_scene = findArmorScene(slot_feet.texture, slot_feet, "feet", sex_defaults.feet, species, sex_key)


const SKIN_MATERIAL = preload("res://world/player/human/mesh/Torso0.material")

func replaceEquipmentNode(current_node,scene):
	if scene==null:
		if is_instance_valid(current_node):
			current_node.queue_free()
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
	player.loadCharacterData()
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

	# Already holding correct tool: remove offhand anyway
	if !current.empty() and current.has(skill+" power"):
		if slot_offhand.texture:
			var offhand=findWeaponFromIcon(slot_offhand.texture)
			if !offhand.empty():
				Global.addNotStackableItem(inven,offhand,self)
			slot_offhand.texture=null

		active_tool_skill=skill
		return

	active_tool_skill=skill
	skill_original_slots=[]

	# Store main hand
	if slot_mainhand.texture:
		for slot in inven.get_children():
			var icon=slot.get_node_or_null("Slot")
			if icon and !icon.texture:
				icon.texture=slot_mainhand.texture
				skill_original_slots.append({"hand":0,"slot":icon})
				slot_mainhand.texture=null
				break

	# Store offhand
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
			Global.addNotStackableItem(inven,tool,self)
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

func swapSkillTool(skill,inven)->void:
	var tools=[]

	for key in Global.weapons:
		var weapon=Global.weapons[key]
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
				Global.addNotStackableItem(inventory_grid,returned_weapon,floating_parent)
			slot_offhand.texture=null
		return

	var main_weapon=findWeaponFromIcon(slot_mainhand.texture)

	if main_weapon.get("carry","")=="shield":
		Global.addNotStackableItem(inventory_grid,main_weapon,floating_parent)
		slot_mainhand.texture=null
		return

	if main_weapon.empty():
		return

	var two_handed=main_weapon.get("two handed",false)
	slot_offhand.get_parent().visible=!two_handed

	if two_handed and slot_offhand.texture:
		var returned_weapon=findWeaponFromIcon(slot_offhand.texture)
		if !returned_weapon.empty():
			Global.addNotStackableItem(inventory_grid,returned_weapon,floating_parent)
		slot_offhand.texture=null

	var offhand_item=findWeaponFromIcon(slot_offhand.texture)
	var offhand_weapon={}
	var shield_weapon={}

	if !offhand_item.empty():
		if offhand_item.get("two handed",false):
			Global.addNotStackableItem(inventory_grid,offhand_item,floating_parent)
			slot_offhand.texture=null
		elif offhand_item.get("carry","")=="shield":
			shield_weapon=offhand_item
		else:
			offhand_weapon=offhand_item

	var main_holder:Node
	var offhand_holder:Node

	if player.is_in_combat and player.current_skill != "gather":
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
func rotate_bone(bone_name:String,x_degrees:float=0.0,y_degrees:float=0.0,z_degrees:float=0.0)->void:
	if skeleton==null or !is_instance_valid(skeleton):return
	var bone_idx=skeleton.find_bone(bone_name)
	if bone_idx==-1:return
	cache_bone_rest(bone_name)
	if bone_default_rest==null or !bone_default_rest.has(bone_name):return
	var rest=bone_default_rest[bone_name]
	if rest==null:return
	var rot_basis=Basis()
	rot_basis=rot_basis.rotated(Vector3.RIGHT,deg2rad(x_degrees))
	rot_basis=rot_basis.rotated(Vector3.UP,deg2rad(y_degrees))
	rot_basis=rot_basis.rotated(Vector3.FORWARD,deg2rad(z_degrees))
	var new_transform=Transform(rest.basis*rot_basis,rest.origin)
	if skeleton is Skeleton:skeleton.set_bone_rest(bone_idx,new_transform)
func reset_bone_transform(bone_name:String)->void:
	if skeleton==null or !is_instance_valid(skeleton):return
	var bone_idx=skeleton.find_bone(bone_name)
	if bone_idx==-1:return
	if bone_default_rest==null or !bone_default_rest.has(bone_name):return
	var rest=bone_default_rest[bone_name]
	if rest==null:return
	if skeleton is Skeleton:skeleton.set_bone_rest(bone_idx,rest)
func move_bone(bone_name:String,x_offset:float=0.0,y_offset:float=0.0,z_offset:float=0.0)->void:
	if skeleton==null or !is_instance_valid(skeleton):return
	var bone_idx=skeleton.find_bone(bone_name)
	if bone_idx==-1:return
	cache_bone_rest(bone_name)
	if bone_default_rest==null or !bone_default_rest.has(bone_name):return
	var rest=bone_default_rest[bone_name]
	if rest==null:return
	var new_transform=Transform(rest.basis,rest.origin+Vector3(x_offset,y_offset,z_offset))
	if skeleton is Skeleton:skeleton.set_bone_rest(bone_idx,new_transform)
func reset_bone_position(bone_name:String)->void:
	if skeleton==null or !is_instance_valid(skeleton):return
	var bone_idx=skeleton.find_bone(bone_name)
	if bone_idx==-1:return
	if bone_default_rest==null or !bone_default_rest.has(bone_name):return
	var rest=bone_default_rest[bone_name]
	if rest==null:return
	if skeleton is Skeleton:skeleton.set_bone_rest(bone_idx,rest)
	
	
	
	
	
	
	
	
	
	
	
	
	
func findWeaponFromIcon(icon:Texture)->Dictionary:
	for weapon in Global.weapons.values():
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

func _onPeerConnectedResync(new_peer_id:int) -> void:
	if player.isLocalPlayer():
		rpc_id(new_peer_id, "receiveEquipmentSnapshot", _buildSnapshot())

func _buildSnapshot() -> Dictionary:
	return {
		"torso": getTexturePath(slot_torso), "hands": getTexturePath(slot_hands),
		"feet": getTexturePath(slot_feet), "mainhand": getTexturePath(slot_mainhand),
		"offhand": getTexturePath(slot_offhand), "necklace": getTexturePath($Necklace/Slot),
		"rings": [getTexturePath(ring.get_node("Slot")), getTexturePath(ring2.get_node("Slot")),
			getTexturePath(ring3.get_node("Slot")), getTexturePath(ring4.get_node("Slot")),
			getTexturePath(ring5.get_node("Slot")), getTexturePath(ring6.get_node("Slot")),
			getTexturePath(ring7.get_node("Slot")), getTexturePath(ring8.get_node("Slot"))]
	}

remote func receiveEquipmentSnapshot(data:Dictionary) -> void:
	if player.isLocalPlayer():
		return
	net_torso_path = data.torso; net_hands_path = data.hands; net_feet_path = data.feet
	net_mainhand_path = data.mainhand; net_offhand_path = data.offhand; net_necklace_path = data.necklace
	net_ring_paths = data.rings
	_applyPuppetEquipmentIfChanged()

func loadTexture(slot,path:String)->void:
	if !slot:return
	if slot.has_node("Slot"):
		slot=slot.get_node("Slot")
	slot.texture=null
	if path!="" and ResourceLoader.exists(path):
		slot.texture=load(path)
		
		
func resetEquipment():
	if is_instance_valid(slot_torso):
		var icon=Global.armors["torso1"]["icon"]
		slot_torso.texture=load(icon) if typeof(icon)==TYPE_STRING else icon
	if is_instance_valid(slot_hands):
		var icon=Global.armors["hands1"]["icon"]
		slot_hands.texture=load(icon) if typeof(icon)==TYPE_STRING else icon
	if is_instance_valid(slot_feet):
		var icon=Global.armors["feet1"]["icon"]
		slot_feet.texture=load(icon) if typeof(icon)==TYPE_STRING else icon
	if is_instance_valid(slot_mainhand): slot_mainhand.texture=null
	if is_instance_valid(slot_offhand): slot_offhand.texture=null
	_equipment_data_ready = true      
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
