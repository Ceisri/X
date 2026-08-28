extends KinematicBody
# PlayerBOT.gd — server-authoritative AI stand-in player. 




"""

"this node is in group "Player" "BOT" and "ENTITY" like all things in games it has no shadows
like the rest of the game the animation tree is using physics by default"

"""



onready var player_mesh:Spatial = $character
onready var visual_tween:Tween = $Tween
var visual_smooth_enabled:bool = true
var visual_smooth_max_jump:float = 30.0
onready var animation:AnimationPlayer = $character/AnimationPlayer
onready var anim_calls:Node = $AnimationCalls
onready var character:Spatial = $character
onready var skeleton:Skeleton = $character/root/Skeleton
onready var stats:Node = $Stats
onready var turnable:Spatial = $Turnable
onready var animation_tree:AnimationTree = $AnimationTree
onready var skill_anim = animation_tree.tree_root.get_node("Skill")
onready var combat_idle = animation_tree.tree_root.get_node("CombatIdle")
onready var proxymity_chat_3D_Label:Label3D = $ProximityChat3DLabel
onready var ray_down:RayCast = $DistanceToFloordRay
onready var ground_raycast:RayCast = $GroudnCheck
onready var water_level_area:Area = $WaterLevelChest
onready var visibility_notifier:VisibilityNotifier= $VisibilityNotifier
onready var ray_front:RayCast = $Turnable/RayFront
onready var ray_front_left:RayCast = $Turnable/RayFrontLeft
onready var ray_front_right:RayCast = $Turnable/RayFrontRight
onready var ray_right:RayCast = $Turnable/RayRight
onready var ray_left:RayCast = $Turnable/RayLeft
onready var detection_area = get_node("Turnable/Area")

onready var fullbody_collision:CollisionShape = $CollisionShape
onready var upper_body_collision:CollisionShape = $CollisionUP
onready var lower_body_collision:CollisionShape = $CollisionDown


#  identity 
export var entity_name:String = ""
export var species:String = "human"
export var sex:String = "male"
var _bot_save_data:Dictionary = {}
var which_scene:String = ""
var _last_known_health:float = 9999999999.0
const BOT_SAVE_DIR := "user://BotSaves/"
var creator = null
var spawned_bodies:Array = []
var pvp_enabled:bool = false
var is_dead:bool = false
var is_downed:bool = false
var revive_lock_until_ms:int = 0
var respawn_id:int = 0
var direction:Vector3 = Vector3.ZERO
var separation_radius:float = 1.6
var separation_strength:float = 0.45
var separation_recalc_interval:int = 20
var steeringRecalcInterval:int = 20

enum SteerNavState { STRAIGHT, SIDESTEP, UTURN_RETREAT }
var _nav_state:int = SteerNavState.STRAIGHT
var _nav_state_until_ms:int = 0
var _nav_turn_dir:float = 1.0
var steer_turn_angle_deg:float = 80.0
var steer_sidestep_duration_ms:int = 900
var steer_uturn_retreat_duration_ms:int = 500






var entity_steer_recalc_interval:int = 8
var steer_recheck_interval_ms:int = 2500
var nearestPlayerCheckInterval:int = 60
var is_in_combat:bool = false
var bot_autorespawn_time:float = 50.0
var bot_alone_respawn_delay:float = 8.0
var bot_help_message_interval:float = 15.0
var bot_help_check_radius:float = 90.0
var downed_time_ms:int = 0
var _last_help_message_time_ms:int = 0
var cachedNearestRealPlayerDist:float = INF
var cachedNearestRealPlayerDistFrame:int = -999999

var cachedSteeringDir:Vector3 = Vector3.ZERO
var cachedSteeringFrame:int = -999999
var density_check_radius:float = 20.0
var density_high_threshold:int = 8
var density_interval_scale:float = 1.5
var _cachedDensityCount:int = 0
var _cachedDensityFrame:int = -999999
var density_check_interval:int = 40
var _last_ai_tick_frame:int = -999999
var _current_tick_scale:float = 1.0
var _separation_cache:Vector3 = Vector3.ZERO
var _separation_cache_frame:int = -999999
var _personal_melee_offset := 0.0
var _personal_angle_offset := 0.0
var _offset_initialized := false
var _bot_frame_offset:int = 0
var mobSearchCooldownUntilMs:int = 0
var mobSearchRetryMs:int = 1600
var is_alive_blend:float = 1.0
var is_alive_blend_speed:float = 6.0
var downed_blend:float = -1.0
var downed_blend_speed:float = 4.0
var _cachedNearbyDownedAlly:Node = null
var is_crawling_now:bool = false
var rest_retreat_check_radius:float = 40.0
var rest_retreat_min_distance:float = 30.0
var _visual_smooth_offset:Vector3 = Vector3.ZERO
var visual_smooth_return_speed:float = 18.0
var visual_smooth_max_offset:float = 3.5
var rest_retreat_speed:float = 1.0
var retreat_target_point:Vector3 = Vector3.ZERO
var retreat_recalc_next_ms:int = 0
var bot_fall_stuck_timer:float = 0.0
var bot_fall_stuck_time:float = 4.0
var _last_processed_visual_frame:int = -1
var stare_at_corpse:Node = null
var stare_until_ms:int = 0
var _last_known_health_bot:float = -1.0
var _last_attacked_ms:int = -999999
var attacked_recently_window_ms:int = 4000
var bot_inventory := {} # item_key(String) -> quantity(int)
var bot_coins:int = 0
var sell_when_inventory_count_at_least:int = 5
var potion_buy_target_count:int = 3
var potion_low_health_ratio:float = 0.85
export var trader_arrival_range:float = 3.0
var trader_approach_offset:Vector3 = Vector3.ZERO
var bot_goal:String = "" # "" | "seeking_sell_trader" | "seeking_potion_trader"
var kills_since_last_sell:int = 0
var kills_required_to_sell:int = 0
var target_trader:Node = null
var trader_arrival_time_ms:int = 0
var trader_stall_duration_ms:int = 0
var trader_search_cooldown_until_ms:int = 0
var potion_purchases_made:int = 0

var weapon_purchase_chance:float = 0.85
var _last_carry_combat_state:bool = false
var _substep_scale:float = 1.0
var bot_weapon_key:String = ""
var bot_offhand_key:String = ""
var _bot_weapon_node:Node = null
var _bot_offhand_node:Node = null
var _bot_weapon_carry_combat:bool = false

var bone_holder_right:BoneAttachment
var bone_holder_left:BoneAttachment
var bone_holder_hipR:BoneAttachment
var bone_holder_hipL:BoneAttachment
var bone_holder_backUp:BoneAttachment
var bone_holder_backLow:BoneAttachment
var bone_holder_shield:BoneAttachment
var bone_holder_back_shield:BoneAttachment

var last_combat_position:Vector3 = Vector3.ZERO
var has_last_combat_position:bool = false
var farm_return_min_level:int = 0
var farm_nearer_search_multiplier:float = 1.6
var farm_arrival_distance:float = 3.0
var trader_search_retry_ms:int = 5000







const BOT_HELP_CHAT_LINES := [
	"hey can someone help me up",
	"i'm down, need a hand over here",
	"anyone nearby? kinda need help",
	"ouch, down for the count, help?",
	"could use a revive if anyone's around",
	"a little help would be nice right about now",
]
const BOT_NAME_PREFIXES_MALE := [
	"Alaric", "Ambrose", "Ansel", "Armand", "August", "Augustin",
	"Bellamy", "Bertram", "Casimir", "Constantine", "Corvin", "Cyprian",
	"Demetrius", "Edmund", "Edouard", "Evander", "Ferdinand",
	"Frederick", "Gabriel", "Gaspard", "Gideon",
	"Henri", "Horace", "Leander", "Leontes",
	"Lorenz", "Lucien", "Magnus", "Maximilian",
	"Octavian", "Orpheus", "Percival", "Phineas", "Raphael", "Sebastian",
	"Theodore", "Valerian", "Wilhelm",
	"Aurelius", "Dorian", "Hadrian",
	"Melchior", "Nicander", "Thaddeus", "Xanthos"
]

const BOT_NAME_PREFIXES_FEMALE := [
	"Beatrice", "Cecilia", "Celeste", "Elara", "Elise", "Emilia",
	"Genevieve", "Helena", "Isadora", "Isolde", "Matilda",
	"Octavia", "Seraphine", "Theodora", "Violetta",
	"Althea", "Callista", "Euphemia", "Lyra", "Odette",
	"Rosalind", "Valentina"
]

const BOT_NAME_SUFFIXES := [
	"fang", "claw", "heart", "walker", "hunter",
	"reaver", "arcanist", "blade", "caller", "born",
	"ward", "bane", "thorn", "veil", "sand",
	"wraith", "brand", "gaze", "keeper", "weaver",
	"snow", "song", "crown", "shade", "mark"
]

func randomizeBotName() -> void:
	if entity_name != "":
		return

	var name_pool:Array = BOT_NAME_PREFIXES_MALE if sex == "male" else BOT_NAME_PREFIXES_FEMALE

	var attempt := ""
	for attempt_index in range(50):
		attempt = name_pool[randi() % name_pool.size()]
		if randf() < 0.25:
			attempt += BOT_NAME_SUFFIXES[randi() % BOT_NAME_SUFFIXES.size()].capitalize()
		if !isNameTakenByOtherBot(attempt):
			break

	entity_name = attempt


#  weapon mode / anim lock contract (subset AnimationCalls.gd needs) 
enum WeaponMode {NONE, SWORD, DUAL, SHIELD, TWO_HANDED}
var weapons:int = WeaponMode.NONE
var wants_weapon := false
var current_skill:String = "none"
var last_active_skill:String = ""
var has_anim_lock:bool = false
var can_move:bool = true
var root_motion_active:bool = false
var is_writing:bool = false
var moving:bool = false
var movement_mode:String = "idle"
var _move_dir:Vector3 = Vector3.ZERO
var _move_speed:float = 0.0
var _face_dir:Vector3 = Vector3.ZERO
var _face_turn_speed_mult:float = 1.0
var anim_locks:Dictionary = {
	"combo attack": false,
	"guard": false,
	"guard react": false,
	"evasion": false,
	"backstep": false,
	"flinch": false,
	"knocked back": false,
	"knocked down": false,
	"downed start": false,
	"die": false,
	"get up": false,
	"stunned": false,
	"staggered": false,
}

var skill_animations:Dictionary = {
	"downed start": {
		WeaponMode.NONE: "DownedStart",
		WeaponMode.SWORD: "DownedStart",
	},
	"combo attack":{
		WeaponMode.NONE:"ComboATK_Empty_cycle",
		WeaponMode.SWORD:"ComboATK_OneHanded_cycle",
		WeaponMode.DUAL:"ComboATK_Dual",
		WeaponMode.SHIELD:"ComboATK_OneHanded_cycle",
		WeaponMode.TWO_HANDED:"ComboATK_TwoHanded_cycle",
	},
	"guard": {
		WeaponMode.NONE: "Guard_Unarmed_cycle",
		WeaponMode.SWORD: "Guard_Sword_cycle",
	},
	"guard react": {
		WeaponMode.NONE: "Guard_Unarmed_react",
		WeaponMode.SWORD: "Guard_General_react",
	},
	"evasion": {
		WeaponMode.NONE: "Roll_Generic",
		WeaponMode.SWORD: "Roll_Generic",
	},
	"backstep": {
		WeaponMode.NONE: "Basic_Generic_Backstep",
		WeaponMode.SWORD: "Basic_Generic_Backstep",
	},
	"flinch": {
		WeaponMode.NONE: "Flinch_OneHanded",
		WeaponMode.SWORD: "Flinch_OneHanded",
	},
	"knocked back": {
		WeaponMode.NONE: "FlinchKnockedBack_OneHanded",
		WeaponMode.SWORD: "FlinchKnockedBack_OneHanded",
	},
	"knocked down": {
		WeaponMode.NONE: "KnockedDown_OneHanded",
		WeaponMode.SWORD: "KnockedDown_OneHanded",
	},
	"die": {
		WeaponMode.NONE: "Die",
		WeaponMode.SWORD: "Die",
	},
	"downed die": {
		WeaponMode.NONE: "DownedDie",
		WeaponMode.SWORD: "DownedDie",
	},
	"get up": {
		WeaponMode.NONE: "DownedEnd",
		WeaponMode.SWORD: "DownedEnd",
	},
}

var combat_idle_animations:Dictionary = {
	WeaponMode.NONE: "IdleOneHanded_cycle",
	WeaponMode.SWORD: "IdleOneHanded_cycle",
	WeaponMode.DUAL: "IdleOneHanded_cycle",
	WeaponMode.SHIELD: "IdleOneHanded_cycle",
	WeaponMode.TWO_HANDED: "IdleTwoHanded_cycle",
}


#authority/renderer caching (session-static, avoids get_tree()/is_network_server() every substep) ----
var _authority_cache_valid:bool = false
var _cached_is_bot_authority:bool = true
var _cached_should_animate_locally:bool = true

func isBotAuthority() -> bool:
	if !_authority_cache_valid:
		_cached_is_bot_authority = get_tree().network_peer == null or get_tree().is_network_server()
		_cached_should_animate_locally = get_tree().network_peer == null or !get_tree().is_network_server()
		_authority_cache_valid = true
	return _cached_is_bot_authority

func _shouldAnimateLocally() -> bool:
	if !_authority_cache_valid:
		isBotAuthority()
	return _cached_should_animate_locally
func isLocalPlayer() -> bool:
	return false



#  lifecycle 
var visual_setup_stagger_frames:int = 25
var _startup_delay_frames: int = 0

func _ready() -> void:
	botReady()
	
func botReady()-> void:
	randomizeWeaponMode()
	kills_required_to_sell = int(rand_range(4.0, 7.0)) 
	initAnimLocks()
	_bot_frame_offset = int(get_instance_id() % 60)
	_chat_timer = rand_range(float(chat_interval_min), float(chat_interval_max))

	if get_tree().network_peer != null and !get_tree().is_network_server():
		set_network_master(1, true)

	if is_instance_valid(visibility_notifier):
		visibility_notifier.connect("enter_screen", self, "_onScreenEntered")
		visibility_notifier.connect("exit_screen", self, "_onScreenExited")

	set_physics_process(false)

	var stagger_frames: int = max(int(visual_setup_stagger_frames), 1)
	_startup_delay_frames = int(get_instance_id() % stagger_frames)

	call_deferred("staggeredReady")

func deferredInit() -> void:
	_bot_save_data = loadBotSave()
	if _bot_save_data.has("entity_name") and str(_bot_save_data["entity_name"]) != "":
		entity_name = str(_bot_save_data["entity_name"])
	if _bot_save_data.has("species"):
		species = str(_bot_save_data["species"])
	if _bot_save_data.has("sex"):
		sex = str(_bot_save_data["sex"])
	randomizeBotName()

	setupPlayerCollisionLayer()

	if _bot_save_data.has("position"):
		global_transform.origin = _bot_save_data["position"]
		rotation.y = float(_bot_save_data.get("rotation_y", rotation.y))
	else:
		placeAtPlayerStart()

	yield(get_tree(), "idle_frame")
	registerInGlobal()
	cacheBotWeaponBoneHolders()
	yield(get_tree(), "idle_frame")

	applySavedBotStats()

	setCombatIdleAnimation()
	yield(get_tree(), "idle_frame")
	set_physics_process(true)

	_is_relevant = true
	is_frozen = false

	queueVisualSetup()

const PLAYER_COLLISION_LAYER_BIT: int = 1 << 21
const CORPSE_COLLISION_LAYER_BIT: int = 1 << 20
const MOB_COLLISION_LAYER_BIT: int = 1 << 19

func setupPlayerCollisionLayer() -> void:
	collision_mask = collision_mask & ~collision_layer
	collision_layer = collision_layer | PLAYER_COLLISION_LAYER_BIT
	collision_mask = collision_mask & ~PLAYER_COLLISION_LAYER_BIT
	collision_mask = collision_mask & ~CORPSE_COLLISION_LAYER_BIT
	collision_mask = collision_mask | MOB_COLLISION_LAYER_BIT
	

func staggeredReady() -> void:
	for i in range(_startup_delay_frames):
		yield(get_tree(), "idle_frame")
	deferredInit()
func cacheBotWeaponBoneHolders() -> void:
	if !is_instance_valid(skeleton):
		return
	bone_holder_right = skeleton.get_node("WeaponR")
	bone_holder_left = skeleton.get_node("WeaponL")
	bone_holder_hipR = skeleton.get_node("HipL")
	bone_holder_hipL = skeleton.get_node("HipR")
	bone_holder_backUp = skeleton.get_node("BackUp")
	bone_holder_backLow = skeleton.get_node("BackLow")
	bone_holder_shield = skeleton.get_node("Shield")
	bone_holder_back_shield = skeleton.get_node("ShieldBack")
func isNameTakenByOtherBot(candidate:String) -> bool:
	for b in get_tree().get_nodes_in_group("BOT"):
		if b == self or !is_instance_valid(b):
			continue
		if "entity_name" in b and str(b.entity_name) == candidate:
			return true
	return false



func getBotSavePath() -> String:
	var world = getMyWorld()
	var wid := "world"
	if is_instance_valid(world) and "world_id" in world:
		wid = world.world_id
	return BOT_SAVE_DIR + wid + "/" + name + ".save"

func loadBotSave() -> Dictionary:
	var path := getBotSavePath()
	var file := File.new()
	if !file.file_exists(path):
		return {}
	if file.open(path, File.READ) != OK:
		return {}
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data

func saveData() -> void:
	if !isBotAuthority():
		return
	var path := getBotSavePath()
	var dir_path := path.get_base_dir()
	var dir := Directory.new()
	if !dir.dir_exists(dir_path):
		dir.make_dir_recursive(dir_path)

	var data := {
		"entity_name": entity_name,
		"species": species,
		"sex": sex,
		"level": (stats.level if is_instance_valid(stats) else 0),
		"experience_points": (stats.experience_points if is_instance_valid(stats) else 0),
		"attributes": (stats.attributes.duplicate(true) if is_instance_valid(stats) else {}),
		"attribute_points_spent": (stats.attribute_points_spent.duplicate(true) if is_instance_valid(stats) else {}),
		"available_attribute_points": (stats.available_attribute_points if is_instance_valid(stats) else 10),
		"health": (stats.health if is_instance_valid(stats) else 0),
		"energy": (stats.energy if is_instance_valid(stats) else 0),
		"arcane": (stats.arcane if is_instance_valid(stats) else 0),
		"position": global_transform.origin,
		"rotation_y": rotation.y,
		"bot_weapon_key": bot_weapon_key,
		"bot_offhand_key": bot_offhand_key,
		"bot_coins": bot_coins,
		"bot_inventory": bot_inventory.duplicate(true),
	}

	var file := File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_var(data)
		file.close()
var cached_entities: Array = []

func cacheEntities() -> void:
	cached_entities.clear()
	var world = getMyWorld()
	if !is_instance_valid(world):
		return
	if world.has_method("getCachedEntities"):
		for e in world.getCachedEntities():
			if is_instance_valid(e):
				cached_entities.append(e)
		return
	if world.has_method("getAllEntities"):
		for e in world.getAllEntities():
			if is_instance_valid(e):
				cached_entities.append(e)

func queueVisualSetup() -> void:
	while !Global.isPlayerReady():
		yield(get_tree(), "idle_frame")

	var my_ticket:int = Global.claimBotVisualSetupTicket()
	while Global.bot_visual_setup_served_ticket < my_ticket:
		yield(get_tree(), "idle_frame")

	applyBaseEquipment()
	yield(get_tree(), "idle_frame")

	applyBotEquipmentStats()

	attachHead()
	yield(get_tree(), "idle_frame")

	attachHair()
	yield(get_tree(), "idle_frame")
	Global.bot_visual_setup_served_ticket += 1




func setBotWeaponLoadout(weapon_key:String, offhand_key:String = "") -> void:
	if !Global.weapons.has(weapon_key):
		return
	if is_instance_valid(_bot_weapon_node):
		_bot_weapon_node.queue_free()
		_bot_weapon_node = null
	if is_instance_valid(_bot_offhand_node):
		_bot_offhand_node.queue_free()
		_bot_offhand_node = null

	bot_weapon_key = weapon_key
	bot_offhand_key = offhand_key

	var wdata:Dictionary = Global.weapons[weapon_key]
	var scene = wdata.get("scene", null)
	if !(scene is PackedScene):
		return

	var two_handed:bool = bool(wdata.get("two handed", false))
	if two_handed:
		weapons = WeaponMode.TWO_HANDED
	elif offhand_key == "shield":
		weapons = WeaponMode.SHIELD
	elif offhand_key != "":
		weapons = WeaponMode.DUAL
	else:
		weapons = WeaponMode.SWORD

	wants_weapon = true
	_bot_weapon_carry_combat = is_in_combat

	_bot_weapon_node = scene.instance()
	var holder = getMainWeaponHolder(wdata, is_in_combat)
	if is_instance_valid(holder):
		holder.add_child(_bot_weapon_node)

	if offhand_key == "shield" and Global.weapons.has("shield") and !two_handed:
		var shield_scene = Global.weapons["shield"].get("scene", null)
		if shield_scene is PackedScene:
			_bot_offhand_node = shield_scene.instance()
			var shield_holder = bone_holder_shield if is_in_combat else bone_holder_back_shield
			if is_instance_valid(shield_holder):
				shield_holder.add_child(_bot_offhand_node)

	# NEW: weapon change is a one-off event, not per-frame -- safe to
	# recompute equipment stats and force the currently playing/queued
	# animation to match the new weapon mode immediately.
	applyBotEquipmentStats()
	refreshCurrentAnimationForWeapon()

func refreshCurrentAnimationForWeapon() -> void:
	if is_in_combat and is_instance_valid(combat_idle):
		setCombatIdleAnimation()
	if current_skill != "" and current_skill != "none" and skill_animations.has(current_skill):
		var anim_data:Dictionary = skill_animations[current_skill]
		var new_anim:String = anim_data.get(weapons, anim_data.get(WeaponMode.NONE, ""))
		if new_anim != "" and is_instance_valid(animation) and animation.has_animation(new_anim) and is_instance_valid(skill_anim) and skill_anim.animation != new_anim:
			skill_anim.animation = new_anim

func applyBotEquipmentStats() -> void:
	if !is_instance_valid(stats):
		return

	for attribute_name in stats.equipment_attributes: stats.equipment_attributes[attribute_name] = 0.0
	for dmg_type in stats.equipment_defence_bonus: stats.equipment_defence_bonus[dmg_type] = 0.0
	for dmg_type in stats.equipment_damage_bonus: stats.equipment_damage_bonus[dmg_type] = 0.0
	stats.equipment_max_health = 0.0
	stats.equipment_max_arcane = 0.0
	stats.equipment_max_energy = 0.0
	stats.equipment_movement_speed = 1.0
	stats.equipment_derived_stats.clear()

	_applyBotArmorStats("torso1")
	_applyBotArmorStats("hands1")
	_applyBotArmorStats("feet1")

	if bot_weapon_key != "":
		_applyBotGearStats(bot_weapon_key)
	if bot_offhand_key == "shield" and Global.weapons.has("shield"):
		_applyBotGearStats("shield")
	elif bot_offhand_key != "" and Global.weapons.has(bot_offhand_key):
		_applyBotGearStats(bot_offhand_key)

	stats.markAttributeCacheDirty()
	if stats.isAuthority():
		stats.updateAttributes()

func _applyBotArmorStats(armor_key:String) -> void:
	if !Global.armors.has(armor_key):
		return
	var armor_data:Dictionary = Global.armors[armor_key]
	stats.equipment_max_health += armor_data.get("max_health",0)
	stats.equipment_max_arcane += armor_data.get("max_arcane",0)
	stats.equipment_max_energy += armor_data.get("max_energy",0)
	stats.equipment_movement_speed += armor_data.get("mov_speed",0) * 0.01
	for attribute_name in stats.equipment_attributes:
		stats.equipment_attributes[attribute_name] += armor_data.get(attribute_name, 0.0)
	if armor_data.has("derived_stats"):
		for stat_name in armor_data["derived_stats"]:
			stats.equipment_derived_stats[stat_name] = stats.equipment_derived_stats.get(stat_name,0.0) + armor_data["derived_stats"][stat_name]
	if armor_data.has("defences"):
		for damage_name in armor_data["defences"]:
			stats.equipment_defence_bonus[stats.damage_type[damage_name]] += armor_data["defences"][damage_name]

func _applyBotGearStats(weapon_key:String) -> void:
	if !Global.weapons.has(weapon_key):
		return
	var weapon_data:Dictionary = Global.weapons[weapon_key]
	stats.equipment_max_health += weapon_data.get("max_health",0)
	stats.equipment_max_arcane += weapon_data.get("max_arcane",0)
	stats.equipment_max_energy += weapon_data.get("max_energy",0)
	stats.equipment_movement_speed += weapon_data.get("mov_speed",0) * 0.01
	for attribute_name in stats.equipment_attributes:
		stats.equipment_attributes[attribute_name] += weapon_data.get(attribute_name, 0.0)
	if weapon_data.has("derived_stats"):
		for stat_name in weapon_data["derived_stats"]:
			stats.equipment_derived_stats[stat_name] = stats.equipment_derived_stats.get(stat_name,0.0) + weapon_data["derived_stats"][stat_name]
	if weapon_data.has("damages"):
		for damage_name in weapon_data["damages"]:
			stats.equipment_damage_bonus[stats.damage_type[damage_name]] += weapon_data["damages"][damage_name]


# Applies everything restored from the bot's save file (level/xp,
# attributes, health, coins, inventory, weapon loadout) onto the live
# node. Called once during deferredInit(), never per-frame.
func applySavedBotStats() -> void:
	if !is_instance_valid(stats) or _bot_save_data.empty():
		return

	if _bot_save_data.has("attributes") and typeof(_bot_save_data["attributes"]) == TYPE_DICTIONARY:
		for k in stats.attributes.keys():
			if _bot_save_data["attributes"].has(k):
				stats.attributes[k] = float(_bot_save_data["attributes"][k])
	if _bot_save_data.has("attribute_points_spent") and typeof(_bot_save_data["attribute_points_spent"]) == TYPE_DICTIONARY:
		for k in stats.attribute_points_spent.keys():
			if _bot_save_data["attribute_points_spent"].has(k):
				stats.attribute_points_spent[k] = int(_bot_save_data["attribute_points_spent"][k])
	if _bot_save_data.has("available_attribute_points"):
		stats.available_attribute_points = int(_bot_save_data["available_attribute_points"])
	if _bot_save_data.has("level"):
		stats.level = int(_bot_save_data["level"])
	if _bot_save_data.has("experience_points"):
		stats.experience_points = int(_bot_save_data["experience_points"])

	stats.markAttributeCacheDirty()
	stats.updateAttributes()

	if _bot_save_data.has("health"):
		stats.health = clamp(float(_bot_save_data["health"]), 1.0, stats.max_health)
	if _bot_save_data.has("energy"):
		stats.energy = clamp(float(_bot_save_data["energy"]), 0.0, stats.max_energy)
	if _bot_save_data.has("arcane"):
		stats.arcane = clamp(float(_bot_save_data["arcane"]), 0.0, stats.max_arcane)

	bot_coins = int(_bot_save_data.get("bot_coins", bot_coins))
	if typeof(_bot_save_data.get("bot_inventory", null)) == TYPE_DICTIONARY:
		bot_inventory = _bot_save_data["bot_inventory"].duplicate(true)

	var saved_weapon:String = str(_bot_save_data.get("bot_weapon_key",""))
	if saved_weapon != "":
		var saved_offhand:String = str(_bot_save_data.get("bot_offhand_key",""))
		setBotWeaponLoadout(saved_weapon, saved_offhand) # this also calls applyBotEquipmentStats()
func getMainWeaponHolder(wdata:Dictionary, in_combat:bool) -> Node:
	if in_combat:
		return bone_holder_right
	match str(wdata.get("carry","hips")):
		"hips": return bone_holder_hipR
		"back up": return bone_holder_backUp
		"back low": return bone_holder_backLow
		_: return bone_holder_hipR

func updateWeaponState() -> void:
	if !wants_weapon or bot_weapon_key == "" or !is_instance_valid(_bot_weapon_node):
		return
	var want_drawn:bool = is_in_combat and movement_mode != "run"
	if want_drawn == _bot_weapon_carry_combat:
		return
	_bot_weapon_carry_combat = want_drawn
	reapplyWeaponHolders()

func reapplyWeaponHolders() -> void:
	if !is_instance_valid(_bot_weapon_node) or !Global.weapons.has(bot_weapon_key):
		return
	var wdata:Dictionary = Global.weapons[bot_weapon_key]
	var new_holder = getMainWeaponHolder(wdata, _bot_weapon_carry_combat)
	if is_instance_valid(new_holder):
		var cur_parent = _bot_weapon_node.get_parent()
		if cur_parent != new_holder:
			if is_instance_valid(cur_parent):
				cur_parent.remove_child(_bot_weapon_node)
			new_holder.add_child(_bot_weapon_node)

	if is_instance_valid(_bot_offhand_node):
		var shield_holder = bone_holder_shield if _bot_weapon_carry_combat else bone_holder_back_shield
		if is_instance_valid(shield_holder):
			var cur_shield_parent = _bot_offhand_node.get_parent()
			if cur_shield_parent != shield_holder:
				if is_instance_valid(cur_shield_parent):
					cur_shield_parent.remove_child(_bot_offhand_node)
				shield_holder.add_child(_bot_offhand_node)

	
	
	
	
	
func randomizeWeaponMode() -> void:
	weapons = WeaponMode.NONE
	wants_weapon = false

func initAnimLocks() -> void:
	for key in anim_locks.keys():
		anim_locks[key] = false

func _exit_tree() -> void:
	if is_instance_valid(Global):
		Global.unregister(self)
		Global.clearAggroPulseState(self)

func registerInGlobal() -> void:
	if !is_instance_valid(Global):
		return
	var world = getMyWorld()
	var world_id:String = world.world_id if is_instance_valid(world) and "world_id" in world else ""
	Global.register(self, world_id)

var cachedWorld:Node = null

func getMyWorld() -> Node:
	if cachedWorld != null and is_instance_valid(cachedWorld):
		return cachedWorld
	var node = get_parent()
	while node:
		if "world_id" in node:
			cachedWorld = node
			return node
		node = node.get_parent()
	return null

func placeAtPlayerStart() -> void:
	var world = getMyWorld()
	if !is_instance_valid(world):
		return
	if world.has_method("getPlayerStartPosition"):
		global_transform.origin = world.getPlayerStartPosition()
	which_scene = world.world_id if "world_id" in world else ""


#  base equipment 
const SKIN_MATERIAL = preload("res://world/player/human/mesh/Torso0.material")

func applyBaseEquipment() -> void:
	if !is_instance_valid(skeleton):
		return
	attachArmorPiece("torso1")
	attachArmorPiece("hands1")
	attachArmorPiece("feet1")

func attachArmorPiece(armor_key:String) -> void:
	if !Global.armors.has(armor_key):
		return
	var armor = Global.armors[armor_key]
	var scene_table = armor.get("scene", {})
	var species_table = scene_table.get(species, null)
	if species_table == null:
		return
	var sex_key = sex
	if !species_table.has(sex_key) and species_table.has("unisex"):
		sex_key = "unisex"
	var packed_scene:PackedScene = species_table.get(sex_key, null)
	if packed_scene == null:
		return
	var node = packed_scene.instance()
	for mesh_instance in node.get_children():
		yield(get_tree(), "idle_frame")
		if mesh_instance is MeshInstance and SKIN_MATERIAL != null:
			yield(get_tree(), "idle_frame")
			mesh_instance.set_surface_material(0, SKIN_MATERIAL)
	yield(get_tree(), "idle_frame")
	skeleton.add_child(node)



#  head + hair (no per-bot recoloring/duplication  bots never need it) 
func attachHead() -> void:
	if !is_instance_valid(skeleton):
		return
	var head_path:String
	if species == "kragun":
		head_path = "res://world/player/kragun/unisex/Head0.tscn"
	else:
		var sex_key = sex if (sex == "male" or sex == "female") else "male"
		head_path = "res://world/player/human/" + sex_key + "/Head0.tscn"

	if !ResourceLoader.exists(head_path):
		return
	var head_scene = load(head_path)
	if head_scene == null:
		return
	var head_node = head_scene.instance()
	head_node.name = "Head"
	yield(get_tree(), "idle_frame")
	skeleton.add_child(head_node)

func attachHair() -> void:
	if !is_instance_valid(skeleton) or species == "kragun":
		return
	var sex_key = sex if (sex == "male" or sex == "female") else "male"
	var style_index = randi() % 3
	var hair_path = "res://world/player/human/" + sex_key + "/hair/" + str(style_index + 1) + ".tscn"
	if !ResourceLoader.exists(hair_path):
		return
	var hair_scene = load(hair_path)
	if hair_scene == null:
		return
	var hair_node = hair_scene.instance()
	hair_node.name = "Hair"
	skeleton.add_child(hair_node)


#  relevance / freeze (visual-only halt) + distance-scaled tick rate 
var bot_relevance_range:float = 550.0
var relevance_check_interval:int = 30
var full_rate_range:float = 20.0
var interval_growth_per_meter:float = 25.0
var max_ai_interval:int = 60 

var _relevance_stagger:int = 0
var _is_relevant:bool = true
var is_frozen:bool = false
var _nearby_downed_ally_cached := false
var _currently_on_screen := true

func _onScreenEntered() -> void:
	_currently_on_screen = true
	_is_relevant = true
	unfreezeBot()



func _onScreenExited() -> void:
	_currently_on_screen = false
	if is_in_combat or hasActiveSkillLock() or is_instance_valid(target_mob) or is_instance_valid(reviving_ally) or is_downed:
		return
	_is_relevant = false
	freezeBot()

func nearestRealPlayerDistance() -> float:
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return INF
	var nearest = INF
	for p in Global.getActivePlayersInWorld(world.world_id):
		if !is_instance_valid(p) or p == self or p.is_in_group("BOT"):
			continue
		var d = global_transform.origin.distance_to(p.global_transform.origin)
		if d < nearest:
			nearest = d
	return nearest

func nearestRealPlayerDistanceCached() -> float:
	var frame:int = Engine.get_physics_frames()
	if frame - cachedNearestRealPlayerDistFrame < nearestPlayerCheckInterval:
		return cachedNearestRealPlayerDist
	cachedNearestRealPlayerDistFrame = frame
	cachedNearestRealPlayerDist = nearestRealPlayerDistance()
	return cachedNearestRealPlayerDist
func getLocalDensityCached() -> int:
	var frame:int = Engine.get_physics_frames()
	if frame - _cachedDensityFrame < density_check_interval:
		return _cachedDensityCount
	_cachedDensityFrame = frame
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		_cachedDensityCount = 0
		return 0
	_cachedDensityCount = Global.countNearby(world.world_id, global_transform.origin, density_check_radius)
	return _cachedDensityCount
func getAiTickInterval() -> int:
	var dist:float = float(nearestRealPlayerDistanceCached())
	var fullRange:float = float(full_rate_range)
	var growth:float = float(interval_growth_per_meter)
	var minInterval:int = 2
	var maxInterval:int = 6
	var interval:int
	if dist <= fullRange:
		interval = minInterval
	elif is_inf(dist):
		interval = maxInterval
	else:
		if growth < 1.0:
			growth = 1.0
		interval = minInterval + int((dist - fullRange) / growth)
	if interval < minInterval:
		interval = minInterval
	if interval > maxInterval:
		interval = maxInterval
	return interval
func getMovementSpeed(base_speed:float) -> float:
	return base_speed * _current_tick_scale

var _stats_frozen := false
func setStatsFrozen(freeze:bool) -> void:
	if freeze == _stats_frozen:
		return
	_stats_frozen = freeze
	if is_instance_valid(stats):
		stats.set_physics_process(!freeze)
		stats.set_process(!freeze)

























func isVisibleToAnyPlayer() -> bool:
	for player in Global.getAllActivePlayers():
		if !is_instance_valid(player) or player == self:
			continue
		if player.is_in_group("BOT"):
			continue
		if global_transform.origin.distance_to(player.global_transform.origin) > bot_relevance_range:
			continue
		var camroot = player.get_node("Camroot")
		if !is_instance_valid(camroot):
			continue
		var cam = camroot.get_node("h/v/Camera")
		if !is_instance_valid(cam):
			continue
		var frustum = cam.get_frustum()
		if frustum.empty():
			continue
		var origin = global_transform.origin + Vector3.UP * 1.0
		var in_view = true
		for plane in frustum:
			if plane.distance_to(origin) > 0.0:
				in_view = false
				break
		if in_view:
			return true
	return false
var frozen_check_interval:int = 45

func findAttackingMob() -> Node:
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return null
	for node in Global.queryRadius(world.world_id, global_transform.origin, mob_seek_range):
		if !is_instance_valid(node) or node == self:
			continue
		if node.is_in_group("Player"):
			continue
		if "target" in node and node.target == self:
			return node
	return null





var _descendant_cache: Array = []
var _descendant_cache_built := false


var _has_any_anim_lock_cache_bot:bool = false
var _has_any_anim_lock_frame_bot:int = -1

func hasAnyAnimLockBot() -> bool:
	var frame:int = Engine.get_frames_drawn()
	if frame == _has_any_anim_lock_frame_bot:
		return _has_any_anim_lock_cache_bot
	_has_any_anim_lock_frame_bot = frame
	_has_any_anim_lock_cache_bot = current_skill != "" and current_skill != "none"
	return _has_any_anim_lock_cache_bot


#  chat 
var chat_interval_min:float = 20.0
var chat_interval_max:float = 55.0
var _chat_timer:float = 30.0

const BOT_CHAT_LINES := [
	"lfg",
	"grinding levels, brb",
	"this place is crawling with mobs today",
	"finally got a clean kill streak going",
	"does anyone actually sell decent armor",
	"watch out over there, it's rough",
	"just vibing and killing stuff",
	"need better gear honestly",
]

func updateChat() -> void:
	_chat_timer -= 1
	if _chat_timer > 0.0:
		return
	_chat_timer = rand_range(chat_interval_min, chat_interval_max)
	broadcastBotChatMessage(BOT_CHAT_LINES[randi() % BOT_CHAT_LINES.size()])

func broadcastBotChatMessage(message:String) -> void:
	if get_tree().network_peer == null:
		deliverBotChatLocally(message)
		return
	if get_tree().is_network_server():
		rpc("receiveBotChatMessage", entity_name, message)
		deliverBotChatLocally(message)

remote func receiveBotChatMessage(sender_name:String, message:String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	deliverBotChatToUIs(sender_name, message)

func deliverBotChatLocally(message:String) -> void:
	deliverBotChatToUIs(entity_name, message)

func deliverBotChatToUIs(sender_name:String, message:String) -> void:
	for chat_ui in get_tree().get_nodes_in_group("ChatUI"):
		if !is_instance_valid(chat_ui) or !("chatbox" in chat_ui):
			continue
		chat_ui.chatbox.append_bbcode("[b]%s:[/b] %s\n" % [sender_name, message])


#  obstacle / cliff avoidance via the 5 angled rays 

# Classifies what a given angled ray is reporting:
#  - CLIFF: ray doesn't hit anything  since these rays point forward
#    AND down, "no hit" means no ground under that direction, i.e. a
#    pit/ledge, not open space.
#  - MOB: ray hits a body that's an Entity but not a Player  a mob.
#    Always treated as an obstacle regardless of distance, so bots give
#    mobs a wide berth instead of brushing past them.
#  - WALL: ray hits terrain/geometry close by (under 55% of cast length).
#  - NONE: hit something far away, or nothing relevant  path is clear.
enum RayObstacle { NONE, CLIFF, WALL, MOB, PLAYER }

func getRayObstacle(ray:RayCast) -> int:
	if !is_instance_valid(ray):
		return RayObstacle.NONE
	if !ray.is_colliding():
		return RayObstacle.CLIFF

	var collider = ray.get_collider()
	if is_instance_valid(collider) and collider != self:
		if collider.is_in_group("Entity"):
			if collider.is_in_group("Player"):
				return RayObstacle.PLAYER
			return RayObstacle.MOB
		if collider.is_in_group("Merchant") or collider.is_in_group("broker") or collider.is_in_group("Broker"):
			return RayObstacle.WALL

	var cast_length = ray.cast_to.length()
	if cast_length <= 0.001:
		return RayObstacle.NONE

	var hit_distance = ray.global_transform.origin.distance_to(ray.get_collision_point())
	# was 0.55  too tight, let bots walk right up to wide static obstacles
	# (trader stalls, walls) before ever registering them as blocking.
	if hit_distance < cast_length * 0.8:
		return RayObstacle.WALL

	return RayObstacle.NONE


# Steering with a COMMITTED bias: once the bot decides to go left/right
# around an obstacle, it keeps going that way (steer_bias_min_hold_ms
# minimum) instead of re-deciding every frame, which is what caused the
# flickering. It only lets go of the bias once the path ahead has been
# genuinely clear for that whole hold window, or after steer_bias_max_ms
# of fighting the same obstacle (at which point trackMovementForStuckDetection
# will eventually trigger an emergency evasion if it's truly stuck).
var _steer_bias:int = 0
var _steer_bias_started_ms:int = 0
var steer_bias_min_hold_ms:int = 300
var steer_bias_max_ms:int = 3000
# Entities move, so committing to a steering bias for as long as a static
# wall needs makes bots lag behind an obstacle that's already stepped
# aside. Much shorter hold when what's actually blocking is a mob/player.
var entity_steer_bias_min_hold_ms:int = 80
var entity_steer_bias_max_ms:int = 900
var _last_steer_was_entity:bool = false

var _stuck_check_pos:Vector3 = Vector3.ZERO
var _stuck_check_time_ms:int = 0
var stuck_detection_window_ms:int = 2000
var stuck_detection_min_distance:float = 1.0
var stuck_emergency_cooldown_ms:int = 4000
var _last_emergency_evasion_ms:int = -999999

var _steer_bias_dir:Vector3 = Vector3.ZERO
func pickOpenSide() -> float:
	# returns 1.0 (right), -1.0 (left), or 0.0 if both sides are blocked
	var left_clear = isRayClear(ray_left)
	var right_clear = isRayClear(ray_right)
	var front_left_clear = isRayClear(ray_front_left)
	var front_right_clear = isRayClear(ray_front_right)

	if front_right_clear and !front_left_clear:
		return 1.0
	if front_left_clear and !front_right_clear:
		return -1.0
	if right_clear and !left_clear:
		return 1.0
	if left_clear and !right_clear:
		return -1.0
	if front_right_clear or right_clear:
		return 1.0
	if front_left_clear or left_clear:
		return -1.0
	return 0.0

func getEntityBlockage(desired_dir:Vector3) -> int:
	var forward:Vector3 = desired_dir
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return 0
	forward = forward.normalized()
	var right:Vector3 = forward.cross(Vector3.UP)
	var origin:Vector3 = global_transform.origin

	if is_instance_valid(detection_area):
		for body in detection_area.get_overlapping_bodies():
			if body == self or !is_instance_valid(body):
				continue
			if !body.is_in_group("Entity"):
				continue
			var offset:Vector3 = body.global_transform.origin - origin
			offset.y = 0.0
			var dist_sq:float = offset.length_squared()
			if dist_sq < 0.0001 or dist_sq > 9.0:
				continue
			offset = offset.normalized()
			if forward.dot(offset) < 0.55:
				continue
			return 1 if offset.dot(right) > 0.0 else -1

	var world = getMyWorld()
	if is_instance_valid(world) and "world_id" in world:
		for node in Global.queryRadius(world.world_id, origin, 8.0):
			if !is_instance_valid(node) or node == self:
				continue
			if node == target_trader:
				continue
			if !(node.is_in_group("Merchant") or node.is_in_group("broker") or node.is_in_group("Broker")):
				continue
			var offset2:Vector3 = node.global_transform.origin - origin
			offset2.y = 0.0
			var dist_sq2:float = offset2.length_squared()
			if dist_sq2 < 0.0001 or dist_sq2 > 64.0:
				continue
			offset2 = offset2.normalized()
			if forward.dot(offset2) < 0.3:
				continue
			return 1 if offset2.dot(right) > 0.0 else -1

	return 0




func computeSteeringDirection(desired_dir:Vector3) -> Vector3:
	var now_ms := OS.get_ticks_msec()
	var separation := computeSeparationCached()

	match _nav_state:
		SteerNavState.STRAIGHT:
			var entity_side := getEntityBlockage(desired_dir)
			if entity_side == 0 and isRayClear(ray_front):
				var out := desired_dir
				if separation.length_squared() > 0.0001:
					out = (out + separation).normalized()
				return out

			var side := float(entity_side) if entity_side != 0 else pickOpenSide()
			_last_steer_was_entity = entity_side != 0

			if side == 0.0:
				_nav_turn_dir = 1.0 if (randi() % 2 == 0) else -1.0
				_nav_state = SteerNavState.UTURN_RETREAT
				_nav_state_until_ms = now_ms + steer_uturn_retreat_duration_ms
				return -desired_dir

			_nav_turn_dir = side
			_nav_state = SteerNavState.SIDESTEP
			_nav_state_until_ms = now_ms + (entity_steer_bias_min_hold_ms if _last_steer_was_entity else steer_sidestep_duration_ms)
			return desired_dir.rotated(Vector3.UP, deg2rad(steer_turn_angle_deg * _nav_turn_dir))

		SteerNavState.UTURN_RETREAT:
			var clear_now := getEntityBlockage(desired_dir) == 0 and isRayClear(ray_front)
			if now_ms >= _nav_state_until_ms or clear_now:
				_nav_state = SteerNavState.SIDESTEP
				_nav_state_until_ms = now_ms + steer_sidestep_duration_ms
				return desired_dir.rotated(Vector3.UP, deg2rad(steer_turn_angle_deg * _nav_turn_dir))
			return -desired_dir

		SteerNavState.SIDESTEP:
			var still_entity := getEntityBlockage(desired_dir)
			if still_entity == 0 and isRayClear(ray_front):
				_nav_state = SteerNavState.STRAIGHT
				return desired_dir
			if now_ms >= _nav_state_until_ms:
				var side2 := float(still_entity) if still_entity != 0 else pickOpenSide()
				_last_steer_was_entity = still_entity != 0
				if side2 == 0.0:
					_nav_turn_dir = -_nav_turn_dir
					_nav_state = SteerNavState.UTURN_RETREAT
					_nav_state_until_ms = now_ms + steer_uturn_retreat_duration_ms
					return -desired_dir
				_nav_turn_dir = side2
				_nav_state_until_ms = now_ms + (entity_steer_bias_min_hold_ms if _last_steer_was_entity else steer_sidestep_duration_ms)
			var out2 := desired_dir.rotated(Vector3.UP, deg2rad(steer_turn_angle_deg * _nav_turn_dir))
			if separation.length_squared() > 0.0001:
				out2 = (out2 + separation).normalized()
			return out2

	return desired_dir
func isRayClear(ray:RayCast) -> bool:
	if !is_instance_valid(ray):
		return true
	ray.force_raycast_update()
	if !ray.is_colliding():
		return true
	var cast_length = ray.cast_to.length()
	if cast_length <= 0.001:
		return true
	var hit_distance = ray.global_transform.origin.distance_to(ray.get_collision_point())
	return hit_distance >= cast_length * 0.8
func computeSteeringDirectionCached(desiredDir:Vector3) -> Vector3:
	var frame:int = Engine.get_physics_frames() + _bot_frame_offset
	var interval:int = entity_steer_recalc_interval if _last_steer_was_entity else steeringRecalcInterval
	if frame - cachedSteeringFrame < interval:
		return cachedSteeringDir
	cachedSteeringFrame = frame
	cachedSteeringDir = computeSteeringDirection(desiredDir)
	return cachedSteeringDir
func ensurePersonalOffsets() -> void:
	if _offset_initialized:
		return
	_offset_initialized = true
	_personal_melee_offset = rand_range(-0.6, 0.9)
	_personal_angle_offset = rand_range(-0.6, 0.6)

func computeSeparationVector() -> Vector3:
	if cached_entities.empty():
		return Vector3.ZERO
	var origin := global_transform.origin
	var push := Vector3.ZERO
	var radius_sq := separation_radius * separation_radius
	for other in cached_entities:
		if !is_instance_valid(other) or other == self:
			continue
		var d := origin.distance_squared_to(other.global_transform.origin)
		if d >= radius_sq or d < 0.0001:
			continue
		var away = origin - other.global_transform.origin
		away.y = 0.0
		if away.length_squared() < 0.0001:
			away = Vector3(rand_range(-1,1), 0, rand_range(-1,1))
		push += away.normalized() * (1.0 - sqrt(d) / separation_radius)
	if push.length_squared() < 0.0001:
		return Vector3.ZERO
	return push.normalized() * separation_strength
func computeSeparationCached() -> Vector3:
	var frame:int = Engine.get_physics_frames() + _bot_frame_offset
	if frame - _separation_cache_frame < separation_recalc_interval:
		return _separation_cache
	_separation_cache_frame = frame

	var result:Vector3 = Vector3.ZERO
	var origin:Vector3 = global_transform.origin
	var world:Node = getMyWorld()
	if is_instance_valid(world) and "world_id" in world:
		for node in Global.queryRadius(world.world_id, origin, separation_radius):
			if node == self or !is_instance_valid(node):
				continue
			if !(node.is_in_group("BOT") or node.is_in_group("Player")):
				continue
			var offset:Vector3 = origin - node.global_transform.origin
			offset.y = 0.0
			var dist:float = offset.length()
			if dist < 0.01:
				offset = Vector3(rand_range(-1.0,1.0), 0.0, rand_range(-1.0,1.0))
				dist = 0.5
			if dist < separation_radius:
				var push := offset.normalized() * ((separation_radius - dist) / separation_radius)
				if node.is_in_group("Player"):
					push *= 1.1
				result += push
	_separation_cache = result * separation_strength
	return _separation_cache

func forceStopAttackAnimation() -> void:
	if is_instance_valid(animation_tree):
		setBotAnimParam("parameters/SkillBlend/blend_amount", 0.0)
		setBotAnimParam("parameters/CombatSwitch/blend_amount", 0.0)
		setBotAnimParam("parameters/MeleeSkillSwitch/blend_amount", 0.0)
		reactivateTree()
	_skill_lock_until_ms = 0


# Call this every tick the bot is actively trying to travel toward a
# goal (chasing a mob, walking to revive someone, retreating). If it
# hasn't covered stuck_detection_min_distance within
# stuck_detection_window_ms, something is wrong (wedged against a mob,
# stuck on geometry the rays didn't catch, circling forever)  fire an
# emergency evasion to phase through and break free, same tool players
# use for i-frames.
func trackMovementForStuckDetection() -> void:
	var now_ms := OS.get_ticks_msec()
	if _stuck_check_time_ms == 0:
		_stuck_check_time_ms = now_ms
		_stuck_check_pos = global_transform.origin
		return
	if now_ms - _stuck_check_time_ms < stuck_detection_window_ms:
		return

	var moved := global_transform.origin.distance_to(_stuck_check_pos)
	_stuck_check_time_ms = now_ms
	_stuck_check_pos = global_transform.origin

	if moved >= stuck_detection_min_distance:
		return
	if now_ms - _last_emergency_evasion_ms < stuck_emergency_cooldown_ms:
		return

	_last_emergency_evasion_ms = now_ms
	triggerEmergencyEvasion()


func resetStuckTracking() -> void:
	_stuck_check_time_ms = 0
	_stuck_check_pos = global_transform.origin


func triggerEmergencyEvasion() -> void:
	if hasAnyAnimLockBot():
		return
	if !Global.skills.has("evasion") or !skill_animations.has("evasion"):
		return
	_steer_bias = 0
	activateSkill("evasion")





#  mob seeking / targeting 
var mob_seek_range:float = 55.0
var mob_vertical_engage_range:float = 3.0
var mob_melee_range:float = 3.0
var target_mob:Node = null

#  revive / rest behavior 
var revive_seek_range:float = 60.0
var revive_range:float = 3.0
var bot_revive_duration:float = 10.0
var bot_revive_heal_percent:float = 0.3
var reviving_ally:Node = null
var revive_hold_progress:float = 0.0

var rest_health_threshold:float = 0.7   # rest if health drops below this % after a kill
var rest_resume_threshold:float = 0.95  # stop resting once regen brings health back up to this %
var is_resting:bool = false
func isMobViable(mob:Node) -> bool:
	if !is_instance_valid(mob) or mob == self:
		return false
	if mob.is_in_group("Player"):
		return false
	if !mob.is_in_group("Entity"):
		return false
	if abs(mob.global_transform.origin.y - global_transform.origin.y) > mob_vertical_engage_range:
		return false
	var mob_stats = mob.stats
	return is_instance_valid(mob_stats) and mob_stats.health > 0

func isMobDeadOrGone(mob:Node) -> bool:
	if !is_instance_valid(mob):
		return true
	var mob_stats = mob.stats
	if !is_instance_valid(mob_stats):
		return true
	return mob_stats.health <= 0
func findMobTarget() -> Node:
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return null
	var wid:String = world.world_id

	var ref_player := getPartyReferenceRealPlayer()
	if is_instance_valid(ref_player):
		var ref_target := findMobTargetingPlayer(ref_player, wid)
		if is_instance_valid(ref_target):
			return ref_target

	var bot_ally_target := getOtherBotPartyMemberTarget()
	if is_instance_valid(bot_ally_target):
		return bot_ally_target

	var party_attacker := findMobAttackingParty(wid)
	if is_instance_valid(party_attacker):
		return party_attacker

	return findWeakestNearestMob(wid)

func mobHasActiveLock(mob:Node) -> bool:
	if !is_instance_valid(mob):
		return false
	if "current_skill" in mob and str(mob.current_skill) != "" and str(mob.current_skill) != "none":
		return true
	if "anim_locks" in mob:
		var locks = mob.anim_locks
		if typeof(locks) == TYPE_ARRAY:
			for state in locks:
				if state:
					return true
		elif typeof(locks) == TYPE_DICTIONARY:
			for key in locks:
				if locks[key]:
					return true
	return false


func clearTargetOnly() -> void:
	target_mob = null
	_offset_initialized = false

func clearSkill() -> void:
	for key in anim_locks.keys():
		anim_locks[key] = false
	current_skill = ""
	has_anim_lock = false
	_skill_lock_until_ms = 0
func updateBotAI(delta:float) -> void:
	if is_dead or stats.health <= 0:
		movement_mode = "idle"
		is_in_combat = false
		is_resting = false
		_move_dir = Vector3.ZERO
		reviving_ally = null
		revive_hold_progress = 0.0
		retreat_target_point = Vector3.ZERO
		return

	updateDangerAwareness()
	if _danger_flag_cached and !hasAnyAnimLockBot():
		_danger_flag_cached = false
		triggerEmergencyEvasion()
		return

	if hasAnyAnimLockBot():
		if !isGuarding() and is_instance_valid(target_mob):
			rotateBotTowards(target_mob.global_transform.origin - global_transform.origin, delta)
		return

	if (Engine.get_physics_frames() + _bot_frame_offset) % 90 == 0:
		cleanupAggrotargets()
	if !isMobViable(target_mob):
		var attacker := findMobAttackingSelfCached()
		if is_instance_valid(attacker):
			target_mob = attacker
	if isMobViable(target_mob):
		if shouldDisengageForRevive(target_mob):
			target_mob = null
		else:
			fightMobTarget(delta)
			return

	target_mob = null

	if is_instance_valid(reviving_ally) and isAllyDownable(reviving_ally):
		is_resting = false
		stare_at_corpse = null
		performBotRevive(delta)
		return
	if is_instance_valid(reviving_ally):
		Global.releaseReviveTarget(reviving_ally, self)
	reviving_ally = null

	var highest_aggro := findHighestAggro()
	if highest_aggro != null and is_instance_valid(highest_aggro.target_entity) and isMobViable(highest_aggro.target_entity):
		stare_at_corpse = null
		if bot_goal != "":
			abandonTraderGoal()
		target_mob = highest_aggro.target_entity
		fightMobTarget(delta)
		return

	var nowMs:int = OS.get_ticks_msec()

	if is_resting:
		updateRestState()
		if is_resting:
			retreatFromMobsWhileResting(delta)
			return
		retreat_target_point = Vector3.ZERO

	if is_instance_valid(stare_at_corpse):
		if nowMs < stare_until_ms:
			movement_mode = "idle"
			is_in_combat = false
			_move_dir = Vector3.ZERO
			rotateBotTowards(stare_at_corpse.global_transform.origin - global_transform.origin, delta)
			return
		lootCorpse(stare_at_corpse)
		stare_at_corpse = null

	var searchedThisTick := false
	if nowMs >= mobSearchCooldownUntilMs:
		if Global.canRunExpensiveSearchThisFrame():
			mobSearchCooldownUntilMs = nowMs + mobSearchRetryMs
			searchedThisTick = true

			var ally = findDownedAlly()
			if is_instance_valid(ally) and Global.claimReviveTarget(ally, self):
				is_resting = false
				reviving_ally = ally
				performBotRevive(delta)
				return
		else:
			mobSearchCooldownUntilMs = nowMs + 30

	if bot_goal != "":
		processBotTraderGoal(delta)
		return

	if searchedThisTick:
		maybeStartTraderGoal(nowMs)
		if bot_goal != "":
			processBotTraderGoal(delta)
			return
		target_mob = findMobTarget()
		if !is_instance_valid(target_mob) and has_last_combat_position:
			if !hasAdequateMobsNearby(mob_seek_range * farm_nearer_search_multiplier):
				goFarmReturn(delta)
				return

	if !is_instance_valid(target_mob):
		movement_mode = "idle"
		is_in_combat = false
		_move_dir = Vector3.ZERO
		return

	fightMobTarget(delta)









func findNearbyAggressiveMobs(radius:float) -> Array:
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return []
	var origin = global_transform.origin
	var result := []
	for node in Global.queryRadius(world.world_id, origin, radius):
		if !is_instance_valid(node) or node == self:
			continue
		if node.is_in_group("Player"):
			continue
		if !node.is_in_group("Entity"):
			continue
		var node_stats = node.get("stats") if "stats" in node else null
		if is_instance_valid(node_stats) and node_stats.health <= 0:
			continue
		result.append(node)
	return result


# Called every AI tick while a bot is resting with nobody to revive.
# Picks a point weighted away from every nearby mob (not just the
# nearest one), walks there at a normal walking pace (never sprints 
# no "sperging"), and only recalculates the target at most twice a
# second or once it's actually reached, so it doesn't twitch direction
# every single frame while surrounded. Once it settles somewhere with
# no mobs within rest_retreat_check_radius, it just stands still.
var _nearby_mobs_resting_cache:Array = []
var _nearby_mobs_resting_cache_ms:int = -999999
var nearby_mobs_resting_cache_interval_ms:int = 500
func retreatFromMobsWhileResting(delta:float) -> void:
	var now_ms := OS.get_ticks_msec()
	if now_ms - _nearby_mobs_resting_cache_ms >= nearby_mobs_resting_cache_interval_ms:
		if Global.canRunExpensiveSearchThisFrame():
			_nearby_mobs_resting_cache_ms = now_ms
			_nearby_mobs_resting_cache = findNearbyAggressiveMobs(rest_retreat_check_radius)

	var nearby_mobs = _nearby_mobs_resting_cache

	if nearby_mobs.empty():
		movement_mode = "idle"
		is_in_combat = false
		_move_dir = Vector3.ZERO
		retreat_target_point = Vector3.ZERO
		resetStuckTracking()
		return

	var origin = global_transform.origin
	var reached_current_target = retreat_target_point == Vector3.ZERO or origin.distance_to(retreat_target_point) <= 2.0

	if reached_current_target or now_ms >= retreat_recalc_next_ms:
		retreat_recalc_next_ms = now_ms + 800

		var away_dir := Vector3.ZERO
		for mob in nearby_mobs:
			if !is_instance_valid(mob):
				continue
			var offset = origin - mob.global_transform.origin
			offset.y = 0.0
			var dist = offset.length()
			if dist < 0.01:
				offset = Vector3(rand_range(-1.0,1.0), 0.0, rand_range(-1.0,1.0))
				dist = offset.length()
			away_dir += offset.normalized() / max(dist, 1.0)

		if away_dir.length_squared() < 0.0001:
			away_dir = Vector3(rand_range(-1.0,1.0), 0.0, rand_range(-1.0,1.0))
		away_dir = away_dir.normalized()

		retreat_target_point = origin + away_dir * (rest_retreat_min_distance + rand_range(0.0, 10.0))
		resetStuckTracking()

	var to_target = retreat_target_point - origin
	to_target.y = 0.0

	if to_target.length_squared() <= 4.0:
		movement_mode = "idle"
		is_in_combat = false
		_move_dir = Vector3.ZERO
		resetStuckTracking()
		return

	is_in_combat = false
	var dir = to_target.normalized()
	var steered = computeSteeringDirectionCached(dir)
	movement_mode = "run"
	_face_dir = steered
	_face_turn_speed_mult = 2.5 if _nav_state != SteerNavState.STRAIGHT else 1.0
	_move_dir = steered
	_move_speed = stats.run_speed
	trackMovementForStuckDetection()
func hasShieldEquipped() -> bool:
	return bot_offhand_key == "shield"

func wantsBackstabPositioning() -> bool:
	return wants_weapon and bot_weapon_key != "" and !hasShieldEquipped()

func isBehindMob(mob:Node) -> bool:
	if !is_instance_valid(mob):
		return false
	var mob_forward:Vector3 = -mob.global_transform.basis.z.normalized()
	var to_bot:Vector3 = (global_transform.origin - mob.global_transform.origin)
	to_bot.y = 0.0
	if to_bot.length_squared() < 0.0001:
		return false
	to_bot = to_bot.normalized()
	return mob_forward.dot(to_bot) < -0.3
# Priority order:
#   1. What a real (non-bot) player in the party is fighting  if there
#      are multiple real players, the party leader's fight takes priority.
#   2. A mob another BOT party member is already fighting.
#   3. A mob currently attacking self or a party member.
#   4. Closest mob with the least health and least defenses.

func getPartyReferenceRealPlayer() -> Node:
	if bot_party_leader_name == "":
		return null
	var leader_node = Global.findEntityNodeByName(bot_party_leader_name)
	if is_instance_valid(leader_node) and !leader_node.is_in_group("BOT"):
		return leader_node
	var roster:Array = Global.party_rosters.get(bot_party_leader_name, [])
	for m in roster:
		var mname:String = str(m.get("entity_name",""))
		if mname == "" or mname == entity_name:
			continue
		var node = Global.findEntityNodeByName(mname)
		if is_instance_valid(node) and !node.is_in_group("BOT"):
			return node
	return null

func findMobTargetingPlayer(target_player:Node, wid:String) -> Node:
	if !is_instance_valid(target_player):
		return null
	var origin:Vector3 = target_player.global_transform.origin
	var best:Node = null
	var best_dist:float = INF
	for node in Global.queryRadius(wid, origin, mob_seek_range):
		if !is_instance_valid(node) or node == self:
			continue
		if node.is_in_group("Player"):
			continue
		if !("target" in node) or node.target != target_player:
			continue
		if !isMobViable(node):
			continue
		var d = origin.distance_squared_to(node.global_transform.origin)
		if d < best_dist:
			best_dist = d
			best = node
	return best

func getOtherBotPartyMemberTarget() -> Node:
	if bot_party_leader_name == "":
		return null
	var roster:Array = Global.party_rosters.get(bot_party_leader_name, [])
	var checked := {}
	var leader_node = Global.findEntityNodeByName(bot_party_leader_name)
	if is_instance_valid(leader_node) and leader_node != self and leader_node.is_in_group("BOT"):
		if "target_mob" in leader_node and isMobViable(leader_node.target_mob):
			return leader_node.target_mob
	for m in roster:
		var mname:String = str(m.get("entity_name",""))
		if mname == "" or mname == entity_name or checked.has(mname):
			continue
		checked[mname] = true
		var node = Global.findEntityNodeByName(mname)
		if is_instance_valid(node) and node != self and node.is_in_group("BOT"):
			if "target_mob" in node and isMobViable(node.target_mob):
				return node.target_mob
	return null

func findMobAttackingParty(wid:String) -> Node:
	if bot_party_leader_name == "":
		return null
	var candidates := []
	var leader_node = Global.findEntityNodeByName(bot_party_leader_name)
	if is_instance_valid(leader_node) and leader_node != self:
		candidates.append(leader_node)
	var roster:Array = Global.party_rosters.get(bot_party_leader_name, [])
	for m in roster:
		var mname:String = str(m.get("entity_name",""))
		if mname == "" or mname == entity_name:
			continue
		var node = Global.findEntityNodeByName(mname)
		if is_instance_valid(node) and node != self and !candidates.has(node):
			candidates.append(node)
	for member in candidates:
		var found = findMobTargetingPlayer(member, wid)
		if is_instance_valid(found):
			return found
	return null

func totalMobDefense(mob_stats) -> float:
	return mob_stats.slash_defence + mob_stats.blunt_defence + mob_stats.pierce_defence \
		+ mob_stats.sonic_defence + mob_stats.heat_defence + mob_stats.cold_defence \
		+ mob_stats.jolt_defence + mob_stats.toxic_defence + mob_stats.acid_defence \
		+ mob_stats.arcane_defence + mob_stats.bleed_defence + mob_stats.radiant_defence

export var weakness_distance_weight:float = 0.6

func findWeakestNearestMob(wid:String) -> Node:
	var origin = global_transform.origin
	var candidates:Array = Global.queryRadius(wid, origin, mob_seek_range)
	if candidates.empty():
		var range_sq = mob_seek_range * mob_seek_range
		for node in get_tree().get_nodes_in_group("Entity"):
			if !is_instance_valid(node) or node == self:
				continue
			if origin.distance_squared_to(node.global_transform.origin) <= range_sq:
				candidates.append(node)

	var best:Node = null
	var best_score:float = INF
	for node in candidates:
		if !isMobViable(node):
			continue
		var mob_stats = node.stats
		var dist = origin.distance_to(node.global_transform.origin)
		var weakness = mob_stats.health + totalMobDefense(mob_stats) * 0.02
		var score = dist + weakness * weakness_distance_weight
		if score < best_score:
			best_score = score
			best = node
	return best




func hasClearLineToTarget(target_node:Node) -> bool:
	if !is_instance_valid(target_node):
		return false
	var space_state = get_world().direct_space_state
	var from:Vector3 = global_transform.origin + Vector3.UP * 1.0
	var to:Vector3 = target_node.global_transform.origin + Vector3.UP * 1.0
	var result = space_state.intersect_ray(from, to, [self, target_node])
	return result.empty()


func fightMobTarget(delta:float) -> void:
	tryUsePotionInCombat()
	tryUsePowerPotionInCombat()
	ensurePersonalOffsets()

	if is_instance_valid(target_mob) and "stats" in target_mob:
		var tmob_stats = target_mob.get_node_or_null("Stats")
		if is_instance_valid(tmob_stats) and "level" in tmob_stats and tmob_stats.level >= stats.level:
			last_combat_position = target_mob.global_transform.origin
			has_last_combat_position = true
			farm_return_min_level = tmob_stats.level

	var origin:Vector3 = global_transform.origin
	var effective_melee_range:float = max(0.9, mob_melee_range + _personal_melee_offset)
	var toTarget:Vector3 = target_mob.global_transform.origin - origin
	toTarget.y = 0.0
	var dist:float = toTarget.length()

	var backstab:bool = wantsBackstabPositioning()

	if dist > effective_melee_range:
		is_in_combat = true
		updateWeaponState()
		var desiredDir:Vector3
		if backstab:
			var mob_forward:Vector3 = -target_mob.global_transform.basis.z.normalized()
			var behind_point:Vector3 = target_mob.global_transform.origin - mob_forward * (effective_melee_range * 0.85)
			var toBehind:Vector3 = behind_point - origin
			toBehind.y = 0.0
			if toBehind.length_squared() > 0.04:
				desiredDir = toBehind.normalized().rotated(Vector3.UP, _personal_angle_offset)
			else:
				desiredDir = toTarget.normalized().rotated(Vector3.UP, _personal_angle_offset)
		else:
			desiredDir = toTarget.normalized().rotated(Vector3.UP, _personal_angle_offset)

		var separation:Vector3 = computeSeparationCached()
		var blendedDir:Vector3 = desiredDir
		if separation.length_squared() > 0.0001:
			blendedDir = (desiredDir + separation).normalized()
		var steeredDir:Vector3 = computeSteeringDirectionCached(blendedDir)
		var turn_mult:float = 2.5 if _nav_state != SteerNavState.STRAIGHT else 1.0
		rotateBotTowards(steeredDir, delta, turn_mult)
		movement_mode = "run"
		move_and_slide_with_snap(steeredDir * getMovementSpeed(stats.run_speed) + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)
		_moved_this_tick = true
		trackMovementForStuckDetection()
	else:
		# Blocked by something between us and the target (trader, crate,
		# scenery) even though we're within straight-line melee range 
		# steer around it instead of standing still swinging at air/it.
		if getRayObstacle(ray_front) == RayObstacle.WALL or !hasClearLineToTarget(target_mob):
			is_in_combat = true
			var steeredDir2:Vector3 = computeSteeringDirectionCached(toTarget.normalized())
			rotateBotTowards(steeredDir2, delta)
			movement_mode = "run"
			move_and_slide_with_snap(steeredDir2 * getMovementSpeed(stats.run_speed) + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)
			_moved_this_tick = true
			trackMovementForStuckDetection()
			return
		is_in_combat = true
		movement_mode = "idle"
		resetStuckTracking()
		rotateBotTowards(toTarget, delta)
		chooseCombatAction()
func findMobAttackingSelf() -> Node:
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return null
	var origin:Vector3 = global_transform.origin
	for node in Global.queryRadius(world.world_id, origin, mob_seek_range):
		if !is_instance_valid(node) or node == self:
			continue
		if node.is_in_group("Player"):
			continue
		if "target" in node and node.target == self and isMobViable(node):
			return node
	return null
var _cachedAttackerSelf:Node = null
var _cachedAttackerSelfMs:int = -999999
export var attacker_self_cache_interval_ms:int = 400

func findMobAttackingSelfCached() -> Node:
	var now_ms := OS.get_ticks_msec()
	if now_ms - _cachedAttackerSelfMs < attacker_self_cache_interval_ms:
		return _cachedAttackerSelf if is_instance_valid(_cachedAttackerSelf) else null
	if !Global.canRunExpensiveSearchThisFrame():
		return _cachedAttackerSelf if is_instance_valid(_cachedAttackerSelf) else null
	_cachedAttackerSelfMs = now_ms
	_cachedAttackerSelf = findMobAttackingSelf()
	return _cachedAttackerSelf
export var danger_scan_radius:float = 18.0
export var danger_strike_range:float = 4.0
export var danger_facing_dot_threshold:float = 0.5
export var danger_check_interval_ms:int = 600
var _last_danger_check_ms:int = -999999
var _danger_flag_cached:bool = false

func mobIsAboutToStrike(mob:Node, target:Node) -> bool:
	if !is_instance_valid(mob) or !is_instance_valid(target):
		return false
	var skill_active:bool = ("current_skill" in mob) and str(mob.current_skill) != "" and str(mob.current_skill) != "none"
	if !skill_active and "anim_locks" in mob:
		var locks = mob.anim_locks
		if typeof(locks) == TYPE_ARRAY:
			for state in locks:
				if state:
					skill_active = true
					break
		elif typeof(locks) == TYPE_DICTIONARY:
			for key in locks:
				if locks[key]:
					skill_active = true
					break
	if !skill_active:
		return false

	var to_target:Vector3 = target.global_transform.origin - mob.global_transform.origin
	to_target.y = 0.0
	var dist:float = to_target.length()
	if dist > danger_strike_range:
		return false
	if dist < 0.01:
		return true

	var mob_forward:Vector3 = -mob.global_transform.basis.z.normalized()
	return mob_forward.dot(to_target.normalized()) >= danger_facing_dot_threshold

func mobHasAggroOn(mob:Node, entity:Node) -> bool:
	if !is_instance_valid(mob) or !is_instance_valid(entity) or !("targets" in mob):
		return false
	for aggro_target in mob.targets:
		if is_instance_valid(aggro_target.target_entity) and aggro_target.target_entity == entity and aggro_target.aggro > 0:
			return true
	return false

func isFirstAggroTarget(mob:Node, entity:Node) -> bool:
	if !is_instance_valid(mob) or !mob.has_method("team_aggro"):
		return false
	var team:Array = mob.team_aggro()
	if team.empty():
		return false
	var top = team[0]
	return is_instance_valid(top.target_entity) and top.target_entity == entity

# "avoid danger at all costs"  any nearby mob that has aggro on this
# bot AND is mid-skill AND close+facing = about to land a hit.
func isSelfInImminentDanger() -> bool:
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return false
	var origin:Vector3 = global_transform.origin
	for node in Global.queryRadius(world.world_id, origin, danger_scan_radius):
		if !is_instance_valid(node) or node == self or node.is_in_group("Player"):
			continue
		if !mobHasAggroOn(node, self):
			continue
		if mobIsAboutToStrike(node, self):
			return true
	return false

func updateDangerAwareness() -> void:
	var now_ms := OS.get_ticks_msec()
	if now_ms - _last_danger_check_ms < danger_check_interval_ms:
		return
	if !Global.canRunExpensiveSearchThisFrame():
		return
	_last_danger_check_ms = now_ms
	_danger_flag_cached = isSelfInImminentDanger()

# Mobs actually engaged (have a live target) near the downed ally's
# position  distinguishes "mob wandering nearby" from "mob fighting here".
func isDownedAllySurroundedByDanger(ally:Node) -> bool:
	if !is_instance_valid(ally):
		return false
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return false
	var origin:Vector3 = ally.global_transform.origin
	for node in Global.queryRadius(world.world_id, origin, danger_scan_radius):
		if !is_instance_valid(node) or node.is_in_group("Player"):
			continue
		if !("target" in node) or node.target == null or !is_instance_valid(node.target):
			continue
		return true
	return false

var _last_danger_warning_ms:int = -999999
export var danger_warning_cooldown_ms:int = 8000
const BOT_DANGER_WARNING_LINES := [
	"move away from the mobs so I can revive!",
	"clear out, too many mobs to revive here!",
	"back off from the mobs, I need space to revive!",
	"get away from the fight so I can pick them up!",
]

func maybeWarnAwayFromDanger() -> void:
	var now_ms := OS.get_ticks_msec()
	if now_ms - _last_danger_warning_ms < danger_warning_cooldown_ms:
		return
	_last_danger_warning_ms = now_ms
	broadcastBotProximityChatMessage(BOT_DANGER_WARNING_LINES[randi() % BOT_DANGER_WARNING_LINES.size()])

# Don't abandon a fight where this bot is being directly targeted or is
# the top aggro entry  only peel off to revive if someone else is
# tanking and a downed ally actually needs help.
func shouldDisengageForRevive(mob:Node) -> bool:
	if !is_instance_valid(mob):
		return false
	if "target" in mob and mob.target == self:
		return false # I'm the tank -- never abandon
	if isFirstAggroTarget(mob, self):
		return false
	if !_nearby_downed_ally_cached:
		return false
	var ally := _cachedNearbyDownedAlly
	if !is_instance_valid(ally):
		return false
	# never break off a fight to save a non-party member
	if !isReviveTargetPartyMember(ally):
		return false
	# keep tanking/fighting until the ally is actually out of danger
	if isDownedAllySurroundedByDanger(ally):
		return false
	return true
func findMobThreateningPosition(pos:Vector3) -> Node:
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return null
	for node in Global.queryRadius(world.world_id, pos, danger_scan_radius):
		if !is_instance_valid(node) or node.is_in_group("Player"):
			continue
		if !("target" in node) or node.target == null or !is_instance_valid(node.target):
			continue
		if isMobViable(node):
			return node
	return null
func isReviveTargetPartyMember(target:Node) -> bool:
	if !is_instance_valid(target) or !("entity_name" in target):
		return false
	var target_name:String = str(target.entity_name)
	if bot_party_leader_name == "":
		return false
	if target_name == bot_party_leader_name:
		return true
	var roster:Array = Global.party_rosters.get(bot_party_leader_name, [])
	for m in roster:
		if str(m.get("entity_name","")) == target_name:
			return true
	return false




func hasAdequateMobsNearby(radius:float) -> bool:
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return false
	var origin:Vector3 = global_transform.origin
	for node in Global.queryRadius(world.world_id, origin, radius):
		if !isMobViable(node):
			continue
		var mob_stats = node.stats
		if is_instance_valid(mob_stats) and "level" in mob_stats and mob_stats.level >= farm_return_min_level:
			return true
	return false
func goFarmReturn(delta:float) -> void:
	var to_target:Vector3 = last_combat_position - global_transform.origin
	to_target.y = 0.0
	if to_target.length_squared() <= farm_arrival_distance * farm_arrival_distance:
		has_last_combat_position = false
		movement_mode = "idle"
		is_in_combat = false
		_move_dir = Vector3.ZERO
		resetStuckTracking()
		return
	is_in_combat = false
	var dir:Vector3 = to_target.normalized()
	var steered:Vector3 = computeSteeringDirectionCached(dir)
	movement_mode = "run"
	_face_dir = steered
	_face_turn_speed_mult = 2.5 if _nav_state != SteerNavState.STRAIGHT else 1.0
	_move_dir = steered
	_move_speed = stats.run_speed
	trackMovementForStuckDetection()
class AggroTarget:
	var target_entity: Node
	var aggro: float = 0.0
	var last_aggro_time: int = 0

var targets:Array = []

export var aggro_drop_distance:float = 70.0
export var aggro_decay_per_second:float = 6.0

func getAggro(target_entity:Node) -> AggroTarget:
	if target_entity == null or target_entity == self:
		return null
	for t in targets:
		if t.target_entity == target_entity:
			return t
	var t := AggroTarget.new()
	t.target_entity = target_entity
	t.last_aggro_time = OS.get_system_time_secs()
	targets.append(t)
	return t

func addAggro(target_entity:Node, amount:float) -> AggroTarget:
	if stats.health <= 0:
		return getAggro(target_entity)
	var t := getAggro(target_entity)
	if t == null:
		return null
	t.aggro += amount
	t.last_aggro_time = OS.get_system_time_secs()
	return t

func findHighestAggro() -> AggroTarget:
	var highest := 0.0
	var best:AggroTarget = null
	for t in targets:
		if !is_instance_valid(t.target_entity):
			continue
		if t.aggro > highest:
			best = t
			highest = t.aggro
	return best

func removeAggroTarget(target_entity:Node) -> void:
	for i in range(targets.size() - 1, -1, -1):
		if targets[i].target_entity == target_entity:
			targets.remove(i)

func shareAggro(_whom) -> void:
	pass # bots don't have a creator/spawned-body family to propagate to

func getAggroFromOtherMob(_other) -> void:
	pass

func cleanupAggrotargets() -> void:
	if targets.empty():
		return
	var remaining := []
	var dt := get_physics_process_delta_time()
	for t in targets:
		if !is_instance_valid(t.target_entity):
			continue
		var dist:float = global_transform.origin.distance_to(t.target_entity.global_transform.origin)
		if dist > aggro_drop_distance:
			t.aggro -= aggro_decay_per_second * dt
		if t.aggro > 0.0:
			remaining.append(t)
	targets = remaining




func isInPartyWithRealPlayer() -> bool:
	if bot_party_leader_name == "":
		return false
	var leader_node = Global.findEntityNodeByName(bot_party_leader_name)
	if is_instance_valid(leader_node) and !leader_node.is_in_group("BOT"):
		return true
	var roster:Array = Global.party_rosters.get(bot_party_leader_name, [])
	for m in roster:
		var mname:String = str(m.get("entity_name",""))
		if mname == "" or mname == entity_name:
			continue
		var node = Global.findEntityNodeByName(mname)
		if is_instance_valid(node) and !node.is_in_group("BOT"):
			return true
	return false

# aliases so Stats.gd's generic has_method("unfreezeMob")/has_method("freezeMob") calls
# (written for NPC.gd's naming) also work on bots without touching Stats.gd further.
func unfreezeMob() -> void:
	unfreezeBot()

func freezeMob() -> void:
	freezeBot()
		
		
		
		
		
		
		
		
		
		
		
func tryUsePotionInCombat() -> void:
	if countPotionsInInventory() <= 0:
		return
	var ratio:float = stats.health / max(stats.max_health,1.0)
	if ratio > potion_low_health_ratio:
		return
	if !Global.flasks.has("medicine potion"):
		return
	var icon = Global.flasks["medicine potion"]["icon"]
	var path:String = icon if icon is String else icon.resource_path
	if active_cooldowns.has(path) and active_cooldowns[path] > 0.0:
		return
	var have:int = countPotionsInInventory() - 1
	if have <= 0:
		bot_inventory.erase("medicine potion")
	else:
		bot_inventory["medicine potion"] = have
	stats.applyBuffDebuff("medicine potion", self)
	var cd:float = Global.getCooldown(path)
	if cd > 0.0:
		active_cooldowns[path] = cd

func tryUsePowerPotionInCombat() -> void:
	var have:int = int(bot_inventory.get("power potion",0))
	if have <= 0:
		return
	if stats.debuff_buffs_active.has("power potion"):
		return
	if !Global.flasks.has("power potion"):
		return
	var icon = Global.flasks["power potion"]["icon"]
	var path:String = icon if icon is String else icon.resource_path
	if active_cooldowns.has(path) and active_cooldowns[path] > 0.0:
		return
	bot_inventory["power potion"] = have - 1
	if bot_inventory["power potion"] <= 0:
		bot_inventory.erase("power potion")
	stats.applyBuffDebuff("power potion", self)
	var cd:float = Global.getCooldown(path)
	if cd > 0.0:
		active_cooldowns[path] = cd


#  resting after a kill 
func checkEnterRestAfterKill() -> void:
	if is_downed or is_dead:
		return
	var ratio:float = stats.health / max(stats.max_health, 1.0)
	if ratio < rest_health_threshold:
		is_resting = true

func updateRestState() -> void:
	if !is_resting:
		return
	var ratio:float = stats.health / max(stats.max_health, 1.0)
	if ratio >= rest_resume_threshold:
		is_resting = false


#  reviving downed allies 
func isAllyDownable(node:Node) -> bool:
	if !is_instance_valid(node) or node == self:
		return false
	if !node.is_in_group("Player"):
		return false
	if !("is_downed" in node) or !node.is_downed:
		return false
	if "is_dead" in node and node.is_dead:
		return false
	return true

func findDownedAlly() -> Node:
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return null

	var origin:Vector3 = global_transform.origin
	var nearest:Node = null
	var nearest_dist_sq:float = INF
	var fallback:Node = null
	var fallback_dist_sq:float = INF

	for p in Global.getActivePlayersInWorld(world.world_id):
		if !isAllyDownable(p):
			continue
		var d:float = origin.distance_squared_to(p.global_transform.origin)
		if d > revive_seek_range * revive_seek_range:
			continue
		if Global.isReviveTargetClaimedByOther(p, self):
			if d < fallback_dist_sq:
				fallback_dist_sq = d
				fallback = p
			continue
		if d < nearest_dist_sq:
			nearest_dist_sq = d
			nearest = p

	if is_instance_valid(nearest):
		return nearest
	# every downable ally in range is already claimed -- nothing to do
	return null
func performBotRevive(delta:float) -> void:
	if !is_instance_valid(reviving_ally) or !isAllyDownable(reviving_ally):
		if is_instance_valid(reviving_ally):
			Global.releaseReviveTarget(reviving_ally, self)
			_reportRevivingProgressToAlly(reviving_ally, 0.0, false)
		reviving_ally = null
		revive_hold_progress = 0.0
		_move_dir = Vector3.ZERO
		resetStuckTracking()
		return

	if !Global.claimReviveTarget(reviving_ally, self):
		_reportRevivingProgressToAlly(reviving_ally, 0.0, false)
		reviving_ally = null
		revive_hold_progress = 0.0
		_move_dir = Vector3.ZERO
		resetStuckTracking()
		return

	var origin:Vector3 = global_transform.origin
	var toAlly:Vector3 = reviving_ally.global_transform.origin - origin
	toAlly.y = 0.0
	var dist:float = toAlly.length()

	is_in_combat = false

	if dist > revive_range:
		var desiredDir:Vector3 = toAlly.normalized()
		var steeredDir:Vector3 = computeSteeringDirectionCached(desiredDir)
		movement_mode = "run"
		_face_dir = steeredDir
		_face_turn_speed_mult = 1.0
		_move_dir = steeredDir
		_move_speed = stats.run_speed
		trackMovementForStuckDetection()
		if revive_hold_progress > 0.0:
			_reportRevivingProgressToAlly(reviving_ally, 0.0, false)
		revive_hold_progress = 0.0
		return

	_move_dir = Vector3.ZERO

	if isDownedAllySurroundedByDanger(reviving_ally):
		maybeWarnAwayFromDanger()
		var threat := findMobThreateningPosition(reviving_ally.global_transform.origin)
		if is_instance_valid(threat):
			Global.releaseReviveTarget(reviving_ally, self)
			reviving_ally = null
			revive_hold_progress = 0.0
			target_mob = threat
			fightMobTarget(delta)
			return
		movement_mode = "idle"
		resetStuckTracking()
		_face_dir = toAlly
		_face_turn_speed_mult = 1.0
		if revive_hold_progress > 0.0:
			_reportRevivingProgressToAlly(reviving_ally, 0.0, false)
		revive_hold_progress = 0.0
		return

	movement_mode = "idle"
	resetStuckTracking()
	_face_dir = toAlly
	_face_turn_speed_mult = 1.0

	var real_delta:float = delta * max(_current_tick_scale, 1.0)
	var speed_multiplier:float = 4.0 if isReviveTargetPartyMember(reviving_ally) else 1.0
	revive_hold_progress += real_delta * speed_multiplier
	_reportRevivingProgressToAlly(reviving_ally, clamp((revive_hold_progress / bot_revive_duration) * 100.0, 0.0, 100.0), true)

	if revive_hold_progress >= bot_revive_duration:
		revive_hold_progress = 0.0
		var ally_stats = reviving_ally.get_node_or_null("Stats")
		if is_instance_valid(ally_stats) and ally_stats.has_method("reviveTarget"):
			ally_stats.reviveTarget(bot_revive_heal_percent)
		_reportRevivingProgressToAlly(reviving_ally, 0.0, false)
		Global.releaseReviveTarget(reviving_ally, self)
		reviving_ally = null



# Pushes live revive progress to the ally actually being revived, so their
# OWN screen shows the growing progress bar even though a bot  not
# themselves  is the one channeling the revive. Offline: direct call.
# Online: only the authority (server) ever runs bot AI, so this always
# routes through the ally's own owning peer via RPC (or applies directly
# if the ally's owner IS this server/host).
func _reportRevivingProgressToAlly(ally:Node, progress:float, active:bool) -> void:
	if !is_instance_valid(ally) or !ally.has_method("setBeingRevivedProgress"):
		return
	if get_tree().network_peer == null:
		ally.setBeingRevivedProgress(progress, active)
		return
	if !get_tree().is_network_server():
		return
	var peer_id = ally.get_network_master()
	if peer_id == get_tree().get_network_unique_id():
		ally.setBeingRevivedProgress(progress, active)
	else:
		ally.rpc_id(peer_id, "setBeingRevivedProgress", progress, active)




var _settle_gravity_skip:int = 0

func settleWithGravity() -> void:
	if _cached_on_floor and vertical_velocity.length_squared() < 0.0001:
		return
	_settle_gravity_skip += 1
	if _cached_on_floor and _settle_gravity_skip % 4 != 0:
		return
	move_and_slide(vertical_velocity, Vector3.UP)




func rotateBotTowards(dir:Vector3, delta:float, speed_mult:float = 1.0) -> void:
	dir.y = 0.0
	if dir.length_squared() <= 0.0001:
		return
	dir = dir.normalized()
	var origin:Vector3 = global_transform.origin
	var look_pos:Vector3 = origin - dir
	look_pos.y = origin.y
	var target_transform:Transform = global_transform.looking_at(look_pos, Vector3.UP)
	var turn_amount:float = clamp(delta * 8.0 * speed_mult, 0.0, 1.0)
	global_transform.basis = global_transform.basis.slerp(target_transform.basis, turn_amount)







# combat: combo attack (default) / evasion=dodge (sometimes) / guard (rare) 
# Timer-based lock instead of relying on the shared animation's method-
# track callback  computed from the actual animation length (scaled by
# attack_speed) so a skill holds for roughly its real duration, then
# releases itself and lets chooseCombatAction() roll the next action.
# This is what makes combat actually cycle instead of freezing on
# whatever animation happened to be set first.
var _skill_lock_until_ms:int = 0

func hasActiveSkillLock() -> bool:
	return OS.get_ticks_msec() < _skill_lock_until_ms


func chooseCombatAction() -> void:
	if !is_instance_valid(target_mob) or !isMobViable(target_mob):
		clearSkill()
		forceStopAttackAnimation()
		return

	if current_skill != "" and current_skill != "none":
		return

	var target_locked:bool = mobHasActiveLock(target_mob)
	var roll:float = randf()
	var skill_name:String = "combo attack"

	if wantsBackstabPositioning() and !isBehindMob(target_mob):
		if roll < 0.5:
			skill_name = "evasion"
		elif roll < 0.7:
			skill_name = "backstep"
		elif roll < 0.9:
			skill_name = "combo attack"
		else:
			skill_name = "guard"
	elif target_locked and roll < 0.20:
		skill_name = "evasion"
	elif target_locked and roll < 0.35:
		skill_name = "backstep"
	elif roll < 0.08:
		skill_name = "guard"

	activateSkill(skill_name)




	
func activateSkill(skill_name:String) -> void:
	if !is_instance_valid(target_mob) or !isMobViable(target_mob):
		return
	if !Global.skills.has(skill_name) or !skill_animations.has(skill_name):
		return

	var path:String = Global.skills[skill_name].resource_path

	if skill_name != "combo attack" and active_cooldowns.has(path) and active_cooldowns[path] > 0.0:
		skill_name = "combo attack"
		path = Global.skills[skill_name].resource_path

	if wants_weapon and !_bot_weapon_carry_combat:
		_bot_weapon_carry_combat = true
		reapplyWeaponHolders()

	var anim_data:Dictionary = skill_animations[skill_name]
	var new_anim:String = anim_data.get(weapons, anim_data.get(WeaponMode.NONE, ""))
	if new_anim == "" or !is_instance_valid(animation) or !animation.has_animation(new_anim):
		return # GUARD: unresolved/missing animation -- never assign, prevents !track_pp spam

	if skill_name == "evasion":
		pushThroughMobIfNeeded()

	for key in anim_locks.keys():
		anim_locks[key] = false
	anim_locks[skill_name] = true
	current_skill = skill_name
	has_anim_lock = true
	last_active_skill = skill_name

	skill_anim.animation = new_anim
	reactivateTree()

	var energy_cost:float = Global.getEnergyCost(skill_name)
	if energy_cost > 0.0:
		stats.energy = max(stats.energy - energy_cost, 0.0)

	var cooldown:float = Global.getCooldown(path)
	cooldown /= max(0.01, float(stats.derived_stats.get("cooldown_reduction", 1.0)))
	if cooldown > 0.0:
		active_cooldowns[path] = cooldown

	var anim_length := animation.get_animation(new_anim).length
	var time_scale:float = max(float(stats.derived_stats.get("attack_speed", 1.0)), 0.01)
	_skill_lock_until_ms = OS.get_ticks_msec() + int((anim_length / time_scale) * 1000.0)






func pushThroughMobIfNeeded() -> void:
	if !is_instance_valid(detection_area):
		return
	var dodge_dir:Vector3 = -global_transform.basis.z.normalized()
	if dodge_dir.length_squared() < 0.0001:
		return

	var blocked := false
	for body in detection_area.get_overlapping_bodies():
		if body == self:
			continue
		if body.is_in_group("Entity") and !body.is_in_group("Player"):
			blocked = true
			break

	if !blocked:
		return

	global_transform.origin += dodge_dir * 2.2



var active_cooldowns:Dictionary = {}

func updateCooldowns() -> void:
	for key in active_cooldowns.keys():
		var remaining = max(active_cooldowns[key] - 1, 0.0)
		if remaining <= 0.0:
			active_cooldowns.erase(key)
		else:
			active_cooldowns[key] = remaining


#  evasion i-frame + phase-through-mobs behavior 
var _collisions_disabled_for_dodge:bool = false
export var dodge_exception_radius:float = 10.0
var _dodge_exception_bodies:Array = []

func updateDodgeCollisions() -> void:
	var is_dodge_skill = Global.skill_dmg_immunity.has(current_skill)
	if is_dodge_skill == _collisions_disabled_for_dodge:
		return
	_collisions_disabled_for_dodge = is_dodge_skill
	_setDodgeCollisionExceptions(is_dodge_skill)

func _setDodgeCollisionExceptions(disable:bool) -> void:
	if disable:
		var world = getMyWorld()
		if !is_instance_valid(world) or !("world_id" in world):
			return
		_dodge_exception_bodies = Global.queryRadius(world.world_id, global_transform.origin, dodge_exception_radius)
		for body in _dodge_exception_bodies:
			if !is_instance_valid(body) or body == self:
				continue
			add_collision_exception_with(body)
			body.add_collision_exception_with(self)
	else:
		for body in _dodge_exception_bodies:
			if !is_instance_valid(body) or body == self:
				continue
			remove_collision_exception_with(body)
			body.remove_collision_exception_with(self)
		_dodge_exception_bodies.clear()

#  root motion for combo attack / evasion 
var root_motion_compensation:float = 0.01

func applySkillRootMotion(delta:float) -> void:
	if !is_instance_valid(animation_tree) or delta <= 0.0:
		return
	if current_skill != "combo attack" and current_skill != "evasion":
		return
	var motion:Vector3 = animation_tree.get_root_motion_transform().origin
	motion.y = 0.0
	if motion.length_squared() < 0.000001:
		return
	motion = global_transform.basis.xform(motion)
	move_and_slide(motion * root_motion_compensation / delta, Vector3.UP)


#  physics loop 
var vertical_velocity:Vector3 = Vector3.ZERO

var max_fall_speed:float = 40.0
var _moved_this_tick := false
var _accumulated_delta_bot:float = 0.0
var _last_animation_visual_frame:int = -1
func _physics_process(delta:float) -> void:
	botPhyProcess(delta)

func botPhyProcess(delta)->void: #EXISTS only to profile ms cost
	var frame:int = Engine.get_physics_frames()
	if isBotAuthority():
		if (frame + _bot_frame_offset) % frozen_check_interval == 0:
			updateVisibilityRelevance()
	if is_frozen:
		return
	if isBotAuthority():
		physicsProcessAuthority(delta, frame)
	else:
		physicsProcessPuppet(delta)

	if _shouldAnimateLocally():
		var visual_frame:int = Engine.get_frames_drawn()
		if visual_frame != _last_animation_visual_frame:
			_last_animation_visual_frame = visual_frame
			animationBOT(delta)

var _last_ai_visual_frame:int = -1
func physicsProcessAuthority(delta:float, frame:int) -> void:
	if is_frozen:
		if (frame + _bot_frame_offset) % 60 == 0:
			updateChat()
		return
	var revive_locked:bool = OS.get_ticks_msec() < revive_lock_until_ms
	var has_lock:bool = hasAnyAnimLockBot()

	if is_downed:
		applySkillRootMotion(delta)
		crawlTowardsNearestPlayer(delta)
	elif has_lock or revive_locked:
		if has_lock and !hasActiveSkillLock() and !revive_locked:
			clearSkill()
			forceStopAttackAnimation()
		else:
			applySkillRootMotion(delta)
			if !isGuarding() and is_instance_valid(target_mob) and !revive_locked:
				if (frame + _bot_frame_offset) % 2 == 0:
					rotateBotTowards(target_mob.global_transform.origin - global_transform.origin, delta)
	else:
		runBotMovementExecutionTick(delta)
		var visual_frame_ai:int = Engine.get_frames_drawn()
		if visual_frame_ai != _last_ai_visual_frame:
			var interval:int = getAiTickInterval()
			if frame % interval == 0 and Global.canRunBotAIThisFrame(self):
				_last_ai_visual_frame = visual_frame_ai
				var elapsed:int = frame - _last_ai_tick_frame
				if elapsed <= 0 or elapsed > max_ai_interval * 2:
					elapsed = 1
				_current_tick_scale = min(float(elapsed), 6.0)
				_last_ai_tick_frame = frame
				updateBotAI(delta)

	var visual_frame:int = Engine.get_frames_drawn()
	var is_new_visual_frame:bool = visual_frame != _last_processed_visual_frame
	if visual_frame == _last_processed_visual_frame:
		return
	_last_processed_visual_frame = visual_frame

	_moved_this_tick = false
	if current_skill == "get up" and anim_locks.get("get up", false) and !hasActiveSkillLock():
		anim_locks["get up"] = false
		current_skill = ""
		has_anim_lock = false
		last_active_skill = ""

	if stats.health <= 0 and !is_downed:
		enterDownedState()

	updateDodgeCollisions()
	if is_in_combat or has_lock or is_instance_valid(target_mob) or is_downed:
		_idle_still_frames = 0
	if is_instance_valid(target_mob) and isMobDeadOrGone(target_mob):
		var dead_mob = target_mob
		kills_since_last_sell += 1
		checkEnterRestAfterKill()
		removeAggroTarget(dead_mob)
		clearTargetOnly()
		clearSkill()
		forceStopAttackAnimation()
		var still_attacked := findHighestAggro()
		var being_attacked := still_attacked != null and is_instance_valid(still_attacked.target_entity)
		if !is_resting and !being_attacked:
			stare_at_corpse = dead_mob
			stare_until_ms = OS.get_ticks_msec() + int(rand_range(1000.0, 2000.0))

	if !_moved_this_tick:
		if !_cached_on_floor or vertical_velocity.length_squared() > 0.0001:
			settleWithGravity()

	if (frame + _bot_frame_offset) % 6 == 0:
		if wants_weapon:
			updateWeaponState()
	if (frame + _bot_frame_offset) % 10 == 0:
		applyGravity(delta)
		Global.updatePosition(self)
	if (frame + _bot_frame_offset) % 15 == 0:
		_cachedNearbyDownedAlly = findDownedAlly()
		_nearby_downed_ally_cached = is_instance_valid(_cachedNearbyDownedAlly)

	if (frame + _bot_frame_offset) % 20 == 0:
		Global.pulseAggroSignal(self)
	if (frame + _bot_frame_offset) % 60 == 0:
		updateCooldowns()
		updateChat()
		safetyCheck()
		checkFallThroughFloor()

		if is_downed:
			updateDownedState()
	if (frame + _bot_frame_offset) % 120 == 0:
		checkStuckInsideOtherEntity()

	syncToPuppets(delta)

func runBotMovementExecutionTick(delta:float) -> void:
	if _face_dir != Vector3.ZERO:
		rotateBotTowards(_face_dir, delta, _face_turn_speed_mult)
	if _move_dir != Vector3.ZERO:
		move_and_slide_with_snap(_move_dir * _move_speed + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)
		_moved_this_tick = true
func updateVisibilityRelevance() -> void:
	var forced_relevant:bool = is_in_combat or hasActiveSkillLock() or is_instance_valid(target_mob) or is_instance_valid(reviving_ally) or is_downed or isInPartyWithRealPlayer()
	if forced_relevant:
		_is_relevant = true
		_currently_on_screen = true
		unfreezeBot()
		return
	var visible_to_someone:bool
	if get_tree().network_peer != null and get_tree().is_network_server():
		if !Global.canRunExpensiveSearchThisFrame():
			_is_relevant = _is_relevant
			if _is_relevant:
				unfreezeBot()
			return
		visible_to_someone = isVisibleToAnyPlayer()
	else:
		visible_to_someone = is_instance_valid(visibility_notifier) and visibility_notifier.is_on_screen()
	_is_relevant = visible_to_someone
	_currently_on_screen = visible_to_someone
	if visible_to_someone:
		unfreezeBot()
	else:
		freezeBot()






var _cached_on_floor := true
func applyGravity(delta:float) -> void:
	_cached_on_floor = is_on_floor()
	if !_cached_on_floor:
		vertical_velocity += Vector3.DOWN * stats.weight * 2.0 * delta
		if vertical_velocity.length() > max_fall_speed:
			vertical_velocity = vertical_velocity.normalized() * max_fall_speed
	else:
		vertical_velocity = -get_floor_normal() * stats.weight / 3.0
func checkFallThroughFloor() -> void:
	if is_dead or is_downed:
		bot_fall_stuck_timer = 0.0
		return
	if !is_on_floor() and !ray_down.is_colliding() and !ground_raycast.is_colliding():
		bot_fall_stuck_timer += 1
		if bot_fall_stuck_timer >= bot_fall_stuck_time:
			teleportBotToPlayerStart()
			bot_fall_stuck_timer = 0.0
	else:
		bot_fall_stuck_timer = 0.0

func teleportBotToPlayerStart() -> void:
	var world = getMyWorld()
	if !is_instance_valid(world) or !world.has_method("getPlayerStartPosition"):
		return
	global_transform.origin = world.getPlayerStartPosition()
	vertical_velocity = Vector3.ZERO
	resetStuckTracking()
















var deadPhaseCheckInterval:int = 15

var dead_phase_entities:Array = []
var dead_phase_rescan_interval:int = 240 # ~4s @60fps, full rescan, catches late-loaded mobs/players
var _dead_phase_rescan_frame:int = -999999

func rescanDeadPhaseEntities() -> void:
	dead_phase_entities.clear()
	var world = getMyWorld()
	if !is_instance_valid(world) or !world.has_method("getAllEntities"):
		return
	for e in world.getAllEntities():
		if is_instance_valid(e) and e != self:
			dead_phase_entities.append(e)




var crawl_speed:float = 1.2
var crawl_seek_radius:float = 40.0
var crawl_stop_distance:float = 2.0
var cachedCrawlTarget:Node = null
var cachedCrawlFrame:int = -999999
var crawl_recalc_interval:int = 12

func crawlTowardsNearestPlayer(delta:float) -> void:
	var frame:int = Engine.get_physics_frames()
	if !is_instance_valid(cachedCrawlTarget) or frame - cachedCrawlFrame >= crawl_recalc_interval:
		cachedCrawlFrame = frame
		recomputeCrawlTarget()

	if !is_instance_valid(cachedCrawlTarget):
		is_crawling_now = false
		return

	var to_target:Vector3 = cachedCrawlTarget.global_transform.origin - global_transform.origin
	to_target.y = 0.0

	if to_target.length_squared() <= crawl_stop_distance * crawl_stop_distance:
		is_crawling_now = false
		return

	var dir:Vector3 = to_target.normalized()
	rotateBotTowards(dir, delta)
	move_and_slide_with_snap(dir * crawl_speed + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)
	_moved_this_tick = true
	is_crawling_now = true


func recomputeCrawlTarget() -> void:
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		cachedCrawlTarget = null
		return

	var nearest:Node = null
	var nearest_dist_sq := INF
	for p in Global.getActivePlayersInWorld(world.world_id):
		if !is_instance_valid(p) or p == self:
			continue
		if p.stats:
			var p_stats = p.stats
			if is_instance_valid(p_stats) and p_stats.health <= 0:
				continue
		var d = global_transform.origin.distance_squared_to(p.global_transform.origin)
		if d < nearest_dist_sq:
			nearest_dist_sq = d
			nearest = p

	cachedCrawlTarget = nearest if (is_instance_valid(nearest) and nearest_dist_sq <= crawl_seek_radius * crawl_seek_radius) else null



func enterDownedState() -> void:
	if is_downed:
		return
	abandonTraderGoal()
	is_downed = true
	is_dead = false
	target_mob = null
	is_in_combat = false
	is_crawling_now = false
	is_resting = false
	if is_instance_valid(reviving_ally):
		Global.releaseReviveTarget(reviving_ally, self)
	reviving_ally = null
	revive_hold_progress = 0.0
	for key in anim_locks.keys():
		anim_locks[key] = false
	anim_locks["downed start"] = true
	current_skill = "downed start"
	has_anim_lock = true
	last_active_skill = ""
	_skill_lock_until_ms = 0

	downed_elapsed_frames = 0
	_help_message_timer_frames = 0


		

	if is_instance_valid(animation_tree):
		reactivateTree()


var downed_elapsed_frames:int = 0
var _help_message_timer_frames:int = 0
var bot_proximity_chat_radius := 400.0
var bot_proximity_label_duration := 6.0
var bot_proximity_label_timer:Timer = null

func broadcastBotProximityChatMessage(message:String) -> void:
	# Bot always shows its own line on its own 3D label first, online or offline.
	showBotProximityLabel3D(message)

	if get_tree().network_peer == null:
		deliverBotProximityChatLocally(message)
		return
	if !get_tree().is_network_server():
		return

	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return

	var origin = global_transform.origin
	var nearby = Global.queryRadius(world.world_id, origin, bot_proximity_chat_radius)
	var notified := {}

	for node in nearby:
		if !is_instance_valid(node) or !node.is_in_group("Player") or node.is_in_group("BOT"):
			continue
		var peer_id = node.get_network_master()
		if notified.has(peer_id):
			continue
		notified[peer_id] = true
		if peer_id == get_tree().get_network_unique_id():
			deliverBotProximityChatLocally(message)
		else:
			rpc_id(peer_id, "receiveBotProximityChatMessage", entity_name, message)

remote func receiveBotProximityChatMessage(sender_name:String, message:String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	deliverBotProximityChatToUIs(sender_name, message)

func deliverBotProximityChatLocally(message:String) -> void:
	deliverBotProximityChatToUIs(entity_name, message)

func deliverBotProximityChatToUIs(sender_name:String, message:String) -> void:
	var chat_ui = _findLocalChatUIForBot()
	if !is_instance_valid(chat_ui) or !("proxy_chatbox" in chat_ui):
		return
	chat_ui.proxy_chatbox.append_bbcode("[b]%s:[/b] %s\n" % [sender_name, message])
	if chat_ui.has_method("flashProxyButton"):
		chat_ui.flashProxyButton()

func _findLocalChatUIForBot() -> Control:
	var local_id = get_tree().get_network_unique_id()
	for chat_ui in get_tree().get_nodes_in_group("ChatUI"):
		if !is_instance_valid(chat_ui) or !is_instance_valid(chat_ui.player):
			continue
		if chat_ui.player.get_network_master() == local_id:
			return chat_ui
	return null

func readyBotProximityLabelTimer() -> void:
	if is_instance_valid(bot_proximity_label_timer):
		return
	bot_proximity_label_timer = Timer.new()
	bot_proximity_label_timer.one_shot = true
	bot_proximity_label_timer.wait_time = bot_proximity_label_duration
	bot_proximity_label_timer.connect("timeout", self, "hideBotProximityLabel")
	add_child(bot_proximity_label_timer)

func showBotProximityLabel3D(message:String) -> void:
	if !is_instance_valid(proxymity_chat_3D_Label):
		return
	readyBotProximityLabelTimer()
	proxymity_chat_3D_Label.text = message
	proxymity_chat_3D_Label.visible = true
	bot_proximity_label_timer.start()

func hideBotProximityLabel() -> void:
	if is_instance_valid(proxymity_chat_3D_Label):
		proxymity_chat_3D_Label.visible = false

func updateDownedState() -> void:
	if stats.health > 0:
		downed_elapsed_frames = 0
		return

	downed_elapsed_frames += 1
	var elapsed_sec:float = float(downed_elapsed_frames)

	var nearby_players = countNearbyPlayers(bot_help_check_radius)

	if nearby_players <= 0:
		if elapsed_sec >= bot_alone_respawn_delay:
			respawnBotToNearestPoint()
		return

	_help_message_timer_frames += 1
	if _help_message_timer_frames >= int(bot_help_message_interval):
		_help_message_timer_frames = 0
		broadcastBotProximityChatMessage(BOT_HELP_CHAT_LINES[randi() % BOT_HELP_CHAT_LINES.size()])

	if elapsed_sec >= bot_autorespawn_time:
		respawnBotToNearestPoint()
		
func startGetUpSequence() -> void:
	exitDownedState()

const BOT_THANKS_LINES := ["thx", "ty", "<3", ":)"]
func exitDownedState() -> void:
	if !is_downed:
		return
	is_downed = false
	is_crawling_now = false
	for key in anim_locks.keys():
		anim_locks[key] = false
	anim_locks["get up"] = true
	current_skill = "get up"
	has_anim_lock = true
	last_active_skill = ""

		

	if is_instance_valid(animation_tree):
		reactivateTree()
		

	broadcastBotProximityChatMessage(BOT_THANKS_LINES[randi() % BOT_THANKS_LINES.size()])

	# Schedule the lock to actually release once the animation's done 
	# this was missing entirely, which is why bots got stuck on "get up"
	# forever and could never attack again.
	var anim_length := 1.5
	if is_instance_valid(animation) and animation.has_animation("DownedEnd"):
		anim_length = animation.get_animation("DownedEnd").length
	var time_scale:float = max(float(stats.derived_stats.get("attack_speed", 1.0)), 0.01)
	_skill_lock_until_ms = OS.get_ticks_msec() + int((anim_length / time_scale) * 1000.0) + 100


func countNearbyPlayers(radius:float) -> int:
	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return 0
	var count := 0
	for p in Global.getActivePlayersInWorld(world.world_id):
		if !is_instance_valid(p) or p == self:
			continue
		if global_transform.origin.distance_to(p.global_transform.origin) <= radius:
			count += 1
	return count


func findNearestRespawnPosition() -> Vector3:
	var world = getMyWorld()
	if is_instance_valid(world) and world.has_method("getRespawnPosition"):
		return world.getRespawnPosition(global_transform.origin)
	return global_transform.origin


func respawnBotToNearestPoint() -> void:
	is_downed = false
	is_crawling_now = false
	for key in anim_locks.keys():
		anim_locks[key] = false
	current_skill = ""
	has_anim_lock = false
	target_mob = null
	is_in_combat = false
	is_resting = true
	reviving_ally = null
	revive_hold_progress = 0.0
	stats.health = max(1.0, ceil(stats.max_health * 0.01))
	stats.energy = max(1.0, ceil(stats.max_energy * 0.01))
	stats.arcane = max(1.0, ceil(stats.max_arcane * 0.01))

	global_transform.origin = findNearestRespawnPosition()
	vertical_velocity = Vector3.ZERO

	var space_state = get_world().direct_space_state
	var from:Vector3 = global_transform.origin + Vector3.UP * 50.0
	var to:Vector3 = global_transform.origin + Vector3.DOWN * 500.0
	var result = space_state.intersect_ray(from, to, [self], 0x7FFFFFFF, false, false)
	if !result.empty():
		global_transform.origin.y = result.position.y + 0.05

	if is_instance_valid(animation_tree):
		animation_tree.active = true



#  puppet sync (authority -> every real client) 
puppet var net_position := Vector3()
puppet var net_rotation_y := 0.0
puppet var net_character_rotation_y := 0.0
puppet var net_turnable_rotation_y := 0.0
puppet var net_movement_mode := "idle"
puppet var net_current_skill := "none"
puppet var net_has_anim_lock := false
puppet var net_active_lock := ""
puppet var net_is_in_combat := false

var puppet_sync_rate:float = 0.08
var _puppet_sync_timer:float = 0.0
var puppet_lerp_speed:float = 12.0

func syncToPuppets(delta:float) -> void:
	if get_tree().network_peer == null:
		return
	if get_tree().get_network_connected_peers().empty():
		return
	_puppet_sync_timer += delta
	if _puppet_sync_timer < puppet_sync_rate:
		return
	_puppet_sync_timer = 0.0

	var char_rot_y = player_mesh.rotation.y if is_instance_valid(player_mesh) else 0.0
	var turn_rot_y = turnable.rotation.y if is_instance_valid(turnable) else 0.0

	rset_unreliable("net_position", translation)
	rset_unreliable("net_rotation_y", rotation.y)
	rset_unreliable("net_character_rotation_y", char_rot_y)
	rset_unreliable("net_turnable_rotation_y", turn_rot_y)
	rset_unreliable("net_movement_mode", movement_mode)
	rset_unreliable("net_current_skill", current_skill)
	rset_unreliable("net_has_anim_lock", has_anim_lock)
	rset_unreliable("net_active_lock", getActiveAnimLockName())
	rset_unreliable("net_is_in_combat", is_in_combat)

func getActiveAnimLockName() -> String:
	for key in anim_locks.keys():
		if anim_locks[key]:
			return key
	return ""
func isGuarding() -> bool:
	return current_skill == "guard" and hasActiveSkillLock()
func physicsProcessPuppet(delta:float) -> void:
	translation = translation.linear_interpolate(net_position, delta * puppet_lerp_speed)
	rotation.y = lerp_angle(rotation.y, net_rotation_y, delta * puppet_lerp_speed)
	if is_instance_valid(player_mesh):
		player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, net_character_rotation_y, delta * puppet_lerp_speed)
	if is_instance_valid(turnable):
		turnable.rotation.y = lerp_angle(turnable.rotation.y, net_turnable_rotation_y, delta * puppet_lerp_speed)

	movement_mode = net_movement_mode
	current_skill = net_current_skill
	has_anim_lock = net_has_anim_lock
	is_in_combat = net_is_in_combat

	for key in anim_locks.keys():
		anim_locks[key] = (key == net_active_lock)


#  animation blending (renderer only) 
var _bot_anim_cache := {}
var anim_full_rate_range:float = 25.0
var anim_far_update_interval:int = 6

func setBotAnimParam(path:String, value) -> void:
	if _bot_anim_cache.has(path):
		var cached = _bot_anim_cache[path]
		if typeof(cached) == TYPE_REAL and typeof(value) == TYPE_REAL:
			if abs(cached - value) < 0.001:
				return
		elif cached == value:
			return
	_bot_anim_cache[path] = value
	animation_tree.set(path, value)

# Decides whether this bot should run its (expensive) full AnimationTree
# blend update this physics tick. Always full-rate if animating something
# combat-relevant (skill lock, combat, target, reviving) so nothing looks
# broken mid-fight. Otherwise throttled by distance to the nearest real
# player, same distance metric bots already compute for AI ticking
# (nearestRealPlayerDistanceCached()) — reused here for zero extra cost.
var _botAnimTickCounter:int = 0
func shouldRunFullAnimationThisFrame() -> bool:
	if is_in_combat or hasActiveSkillLock() or is_instance_valid(target_mob) or is_instance_valid(reviving_ally) or is_downed:
		return true
	var dist:float = nearestRealPlayerDistanceCached()
	if dist <= anim_full_rate_range:
		return true
	_botAnimTickCounter += 1
	if _botAnimTickCounter >= anim_far_update_interval:
		_botAnimTickCounter = 0
		return true
	return false

func setCombatIdleAnimation() -> void:
	if !is_instance_valid(combat_idle):
		return
	if !combat_idle_animations.has(weapons):
		return
	var anim = combat_idle_animations[weapons]
	if !is_instance_valid(animation) or !animation.has_animation(anim):
		return
	combat_idle.animation = anim
func reactivateTree() -> void:
	if is_instance_valid(animation_tree) and !animation_tree.active:
		animation_tree.active = true
# cache-gated setBotAnimParam — this is the actual per-bot cost: Godot's
# AnimationTree.set(path,value) resolves the string path through the
# whole blend graph EVERY call regardless of whether the value changed,
# and PlayerBOT was doing this unconditionally, every frame, for every
# unfrozen bot, with zero dedup — unlike Player.gd which already caches
# via anim_blend_cache/setAnimBlend. This was never applied to bots.)
# ============================================================
var _idle_still_frames:int = 0
var idle_anim_freeze_frames:int = 30
var _anim_tree_idle_frozen:bool = false
func animationBOT(delta:float) -> void:
	if is_frozen:
		if animation_tree.active == true:
			animation_tree.active = false
		return

	var active_lock = getActiveAnimLockName()
	var idle_and_stable = movement_mode == "idle" and !is_in_combat and active_lock == "" and !is_downed and !is_crawling_now

	if idle_and_stable:
		_idle_still_frames += 1
		if _idle_still_frames >= idle_anim_freeze_frames:
			if animation_tree.active:
				setBotAnimParam("parameters/Movement/blend_amount", -1.0)
				setBotAnimParam("parameters/IsInCombat/blend_amount", 0.0)
				animation_tree.active = false
			_anim_tree_idle_frozen = true
			return
	else:
		_idle_still_frames = 0
		if _anim_tree_idle_frozen:
			animation_tree.active = true
			_anim_tree_idle_frozen = false

	if !shouldRunFullAnimationThisFrame():
		return

	if Engine.get_physics_frames() % 2 == 0:
		updateDownedAnimationBlends(delta)

	if active_lock != "" and skill_animations.has(active_lock):
		var anim_data = skill_animations[active_lock]
		var new_anim = anim_data.get(weapons, anim_data.get(WeaponMode.NONE, ""))
		if new_anim != "" and skill_anim.animation != new_anim:
			skill_anim.animation = new_anim
		setBotAnimParam("parameters/SkillBlend/blend_amount", 1.0)
		setBotAnimParam("parameters/CombatSwitch/blend_amount", 1.0)
		setBotAnimParam("parameters/MeleeSkillSwitch/blend_amount", 1.0)
		animation_tree.active = true
		return

	setBotAnimParam("parameters/SkillBlend/blend_amount", 0.0)
	setBotAnimParam("parameters/CombatSwitch/blend_amount", 0.0)
	setBotAnimParam("parameters/MeleeSkillSwitch/blend_amount", 0.0)
	setBotAnimParam("parameters/IsInCombat/blend_amount", 1.0 if is_in_combat else 0.0)

	match movement_mode:
		"idle":
			setBotAnimParam("parameters/Movement/blend_amount", -1.0)
			if is_in_combat:
				setCombatIdleAnimation()
		"walk":
			setBotAnimParam("parameters/Movement/blend_amount", 0.0)
		"run":
			setBotAnimParam("parameters/Movement/blend_amount", 1.0)

	animation_tree.active = true



func updateDownedAnimationBlends(delta:float) -> void:
	var is_alive_target := 0.0 if (is_downed or is_dead or stats.health <= 0) else 1.0
	is_alive_blend = move_toward(is_alive_blend, is_alive_target, delta * is_alive_blend_speed)
	setBotAnimParam("parameters/IsAlive/blend_amount", is_alive_blend)

	var downed_target := 0.0
	if anim_locks.get("get up", false):
		downed_target = 1.0
	elif is_downed:
		downed_target = 0.0 if is_crawling_now else -1.0
	downed_blend = move_toward(downed_blend, downed_target, delta * downed_blend_speed)
	setBotAnimParam("parameters/Downed/blend_amount", downed_blend)
var countdown_stuckdead:int = 5
func safetyCheck():
	if stats.health > 0:
		countdown_stuckdead -= 1
		if countdown_stuckdead <= 0:
			animation_tree.set("parameters/IsAlive/blend_amount",1)
			countdown_stuckdead = 5
var unstuck_check_interval:int = 30
var unstuck_overlap_distance:float = 0.6   # bodies this close are treated as "inside" each other
var unstuck_push_distance:float = 1.5

# Periodically checks whether this bot is overlapping another entity's
# origin too closely (the signature of a bad teleport/spawn stacking two
# bodies on top of each other) and shoves it out along the separating
# direction. Uses the spatial grid (queryRadius) instead of Area
# overlap, so it self-heals even when physics collision alone failed to
# push the bodies apart (e.g. both bodies frozen/kinematic at the exact
# same tick).
func checkStuckInsideOtherEntity() -> void:
	if !Global.canRunExpensiveSearchThisFrame():
		return

	var world = getMyWorld()
	if !is_instance_valid(world) or !("world_id" in world):
		return

	var origin:Vector3 = global_transform.origin

	for node in Global.queryRadius(world.world_id, origin, unstuck_overlap_distance * 2.0):
		if !is_instance_valid(node) or node == self:
			continue
		if !node.is_in_group("Entity"):
			continue

		var other_origin:Vector3 = node.global_transform.origin
		var flat_diff:Vector3 = origin - other_origin
		flat_diff.y = 0.0

		if flat_diff.length_squared() >= unstuck_overlap_distance * unstuck_overlap_distance:
			continue

		var push_dir:Vector3 = flat_diff
		if push_dir.length_squared() < 0.0001:
			push_dir = Vector3(rand_range(-1.0, 1.0), 0.0, rand_range(-1.0, 1.0))
		push_dir = push_dir.normalized()

		global_transform.origin += push_dir * unstuck_push_distance
		vertical_velocity.y = 0.0
		return

func reportOwnCoordinates() -> void:
	var pos:Vector3 = global_transform.origin
	var msg:String = entity_name + " coords: (" + str(stepify(pos.x,0.01)) + ", " + str(stepify(pos.y,0.01)) + ", " + str(stepify(pos.z,0.01)) + ")"
	broadcastBotChatMessage(msg)
func freezeBot() -> void:

	if is_frozen:
		return
	is_frozen = true
	if is_instance_valid(character):
		setDescendantProcessing(self, false)
	if is_instance_valid(animation_tree):
		animation_tree.active = false
	setStatsFrozen(true)
	for ray in [ray_front, ray_front_left, ray_front_right, ray_right, ray_left, ray_down, ground_raycast]:
		if is_instance_valid(ray):
			ray.enabled = false
	if is_instance_valid(fullbody_collision):
		fullbody_collision.disabled = true
	if is_instance_valid(upper_body_collision):
		upper_body_collision.disabled = true
	if is_instance_valid(lower_body_collision):
		lower_body_collision.disabled = true
	# these two Areas are declared but never connected/read anywhere in
	# this script  monitoring=true still costs the physics server a
	# broadphase pass every physics step for nothing, per bot, forever.
	if is_instance_valid(detection_area):
		detection_area.monitoring = false
	if is_instance_valid(water_level_area):
		water_level_area.monitoring = false

func unfreezeBot() -> void:

	if !is_frozen:
		return
	is_frozen = false
	if is_instance_valid(character):
		setDescendantProcessing(self, true)
	if is_instance_valid(animation_tree) and !is_dead:
		animation_tree.active = true
	setStatsFrozen(false)
	for ray in [ray_front, ray_front_left, ray_front_right, ray_right, ray_left, ray_down, ground_raycast]:
		if is_instance_valid(ray):
			ray.enabled = true
	if !is_dead and !is_downed:
		if is_instance_valid(fullbody_collision):
			fullbody_collision.disabled = false
		if is_instance_valid(upper_body_collision):
			upper_body_collision.disabled = false
		if is_instance_valid(lower_body_collision):
			lower_body_collision.disabled = false
	if is_instance_valid(detection_area):
		detection_area.monitoring = true
	if is_instance_valid(water_level_area):
		water_level_area.monitoring = true
	var _descendant_cache: Array = []

# Root at self, not character. Anything sibling to `character` (Shadow/
# ShadowDecal doing force_raycast_update() in _process every rendered
# frame regardless of freeze, GuardRing, proximity chat label, etc) was
# never being touched by freeze/unfreeze at all and kept costing a
# synchronous forced raycast per bot per frame forever. NPC.gd already
# roots its equivalent scan at self  this brings PlayerBOT in line.
func buildDescendantCache() -> void:
	_descendant_cache.clear()
	collectDescendantsFlat(self, _descendant_cache)
	_descendant_cache_built = true

func collectDescendantsFlat(node: Node, out: Array) -> void:
	for child in node.get_children():
		if !is_instance_valid(child):
			continue
		if child is Occluder:
			continue
		if child == visibility_notifier:
			continue # must keep ticking or a frozen bot can never detect re-entering screen
		out.append(child)
		collectDescendantsFlat(child, out)

func setDescendantProcessing(node: Node, enabled: bool) -> void:
	if !_descendant_cache_built:
		buildDescendantCache()
	for child in _descendant_cache:
		if is_instance_valid(child):
			child.set_physics_process(enabled)
			child.set_process(enabled)


var bot_party_leader_name := ""
var bot_refused_inviters := {} # inviter_entity_name -> true
var bot_party_refuse_base_chance := 0.15
var bot_party_refuse_level_diff_scale := 0.05
var _party_invite_pending := false

func receiveBotPartyInvite(inviter_name:String, inviter_peer:int, inviter_level:int) -> void:
	if !isBotAuthority():
		return
	if _party_invite_pending:
		return
	_party_invite_pending = true

	yield(get_tree().create_timer(rand_range(1.0, 4.0)), "timeout")
	_party_invite_pending = false
	if !is_instance_valid(self):
		return

	if bot_party_leader_name != "":
		_replyBotPartyInvite(inviter_peer, false)
		return
	if bot_refused_inviters.has(inviter_name):
		_replyBotPartyInvite(inviter_peer, false)
		return

	var level_diff:int = int(abs(int(stats.level) - inviter_level))
	var refuse_chance:float = clamp(bot_party_refuse_base_chance + float(level_diff) * bot_party_refuse_level_diff_scale, 0.0, 0.9)

	if randf() < refuse_chance:
		bot_refused_inviters[inviter_name] = true
		_replyBotPartyInvite(inviter_peer, false)
		broadcastBotChatMessage("nah, not this time")
		return

	bot_party_leader_name = inviter_name
	_replyBotPartyInvite(inviter_peer, true)
	broadcastBotChatMessage("sure, count me in")

func leaveBotParty() -> void:
	bot_party_leader_name = ""

func _replyBotPartyInvite(inviter_peer:int, accepted:bool) -> void:
	if get_tree().network_peer == null or inviter_peer == get_tree().get_network_unique_id():
		Global.onBotPartyInviteReply(entity_name, int(stats.level), accepted)
	else:
		Global.rpc_id(inviter_peer, "onBotPartyInviteReply", entity_name, int(stats.level), accepted)



func getBotInventoryItemCount() -> int:
	var total := 0
	for key in bot_inventory.keys():
		total += int(bot_inventory[key])
	return total


func countPotionsInInventory() -> int:
	return int(bot_inventory.get("medicine potion",0))


func findItemDataByKey(key:String) -> Dictionary:
	for source in [Global.food, Global.resources, Global.weapons, Global.armors, Global.rings, Global.necklaces, Global.flasks]:
		if source.has(key):
			return source[key]
	return {}
func findNearestSellTrader() -> Node:
	return findNearestTraderInGroups(["broker","Broker"])

func findNearestPotionTrader() -> Node:
	return findNearestPotionOrWeaponTrader(true)

func findNearestWeaponTrader() -> Node:
	return findNearestPotionOrWeaponTrader(false)

func findNearestPotionOrWeaponTrader(want_potion:bool) -> Node:
	var wid := currentWorldId()
	var origin:Vector3 = global_transform.origin
	var best:Node = null
	var best_dist_sq := INF
	var best_crowded:Node = null
	var best_crowded_dist_sq := INF
	for node in get_tree().get_nodes_in_group("Merchant"):
		if !is_instance_valid(node) or !(node is Spatial):
			continue
		if node.is_in_group("broker") or node.is_in_group("Broker"):
			continue
		var relevant := false
		if want_potion:
			for merchant_type in ["alchemist","generic"]:
				if node.is_in_group(merchant_type):
					relevant = true
					break
		else:
			relevant = node.is_in_group("generic")
		if !relevant:
			continue
		var d = origin.distance_squared_to(node.global_transform.origin)
		if Global.isTraderCrowded(node, wid):
			if d < best_crowded_dist_sq:
				best_crowded_dist_sq = d
				best_crowded = node
		else:
			if d < best_dist_sq:
				best_dist_sq = d
				best = node
	return best if is_instance_valid(best) else best_crowded

func findNearestTraderInGroups(groups:Array) -> Node:
	var wid := currentWorldId()
	var origin:Vector3 = global_transform.origin
	var best:Node = null
	var best_dist_sq := INF
	var best_crowded:Node = null
	var best_crowded_dist_sq := INF
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if !is_instance_valid(node) or !(node is Spatial):
				continue
			var d = origin.distance_squared_to(node.global_transform.origin)
			if Global.isTraderCrowded(node, wid):
				if d < best_crowded_dist_sq:
					best_crowded_dist_sq = d
					best_crowded = node
			else:
				if d < best_dist_sq:
					best_dist_sq = d
					best = node
	return best if is_instance_valid(best) else best_crowded
func abandonTraderGoal() -> void:
	if is_instance_valid(target_trader):
		Global.releaseTraderSlot(target_trader, self)
	bot_goal = ""
	target_trader = null
	trader_arrival_time_ms = 0
func currentWorldId() -> String:
	var world = getMyWorld()
	return world.world_id if is_instance_valid(world) and "world_id" in world else ""

var _trader_goal_cached_dir:Vector3 = Vector3.ZERO
var _trader_goal_cached_frame:int = -999999
export var trader_goal_recalc_interval:int = 6

func processBotTraderGoal(delta:float) -> void:
	if !is_instance_valid(target_trader):
		bot_goal = ""
		target_trader = null
		trader_arrival_time_ms = 0
		_move_dir = Vector3.ZERO
		return

	var origin:Vector3 = global_transform.origin
	var approach_point:Vector3 = target_trader.global_transform.origin + trader_approach_offset
	var to_approach:Vector3 = approach_point - origin
	to_approach.y = 0.0
	var dist_sq:float = to_approach.length_squared()

	if dist_sq > 2.25:
		is_in_combat = false

		var frame:int = Engine.get_physics_frames() + _bot_frame_offset
		if frame - _trader_goal_cached_frame >= trader_goal_recalc_interval:
			_trader_goal_cached_frame = frame
			var desiredDir:Vector3 = to_approach / sqrt(dist_sq)
			_trader_goal_cached_dir = computeSteeringDirectionCached(desiredDir)

		movement_mode = "run"
		_face_dir = _trader_goal_cached_dir
		_face_turn_speed_mult = 2.5 if _nav_state != SteerNavState.STRAIGHT else 1.0
		_move_dir = _trader_goal_cached_dir
		_move_speed = stats.run_speed
		trackMovementForStuckDetection()
		return

	is_in_combat = false
	_move_dir = Vector3.ZERO
	if has_anim_lock or current_skill != "" and current_skill != "none":
		clearSkill()
		forceStopAttackAnimation()
	movement_mode = "idle"
	resetStuckTracking()
	var to_trader_face:Vector3 = target_trader.global_transform.origin - origin
	_face_dir = to_trader_face
	_face_turn_speed_mult = 1.0

	if trader_arrival_time_ms == 0:
		trader_arrival_time_ms = OS.get_ticks_msec()
		trader_stall_duration_ms = int(rand_range(3000,5000))
		return

	if OS.get_ticks_msec() - trader_arrival_time_ms < trader_stall_duration_ms:
		return

	if bot_goal == "seeking_sell_trader":
		sellInventoryToTrader()
	elif bot_goal == "seeking_potion_trader":
		buyPotionsFromTrader()
	elif bot_goal == "seeking_weapon_trader":
		buyWeaponsFromTrader()

	Global.releaseTraderSlot(target_trader, self)
	bot_goal = ""
	target_trader = null
	trader_arrival_time_ms = 0








func getWeaponPower(weapon_key: String) -> float:
	if !Global.weapons.has(weapon_key):
		return -INF

	var weapon: Dictionary = Global.weapons[weapon_key]
	var power: float = float(weapon.get("block", 0))

	var damages: Dictionary = weapon.get("damages", {})
	for damage_type in damages:
		power += float(damages[damage_type])

	return power


func getWeaponDerivedStatsPower(weapon_key: String) -> float:
	if !Global.weapons.has(weapon_key):
		return -INF

	var weapon: Dictionary = Global.weapons[weapon_key]
	var derived_stats: Dictionary = weapon.get("derived_stats", {})
	var total: float = 0.0

	for stat in derived_stats:
		total += float(derived_stats[stat])

	return total


func isProperWeapon(weapon_key: String) -> bool:
	if !Global.weapons.has(weapon_key):
		return false

	var weapon: Dictionary = Global.weapons[weapon_key]

	# Pickaxes and other mining tools are not weapons.
	# Axes/hatchets are intentionally NOT excluded.
	if weapon.has("mining power"):
		return false

	# Shields are handled separately as offhand equipment.
	if weapon_key == "shield":
		return false

	return true


func isTwoHandedWeapon(weapon_key: String) -> bool:
	if !isProperWeapon(weapon_key):
		return false

	return bool(Global.weapons[weapon_key].get("two handed", false))


func getCheapestWeapon(two_handed: bool) -> String:
	var best_key: String = ""
	var best_price: int = 999999999

	for weapon_key in Global.weapons:
		if !isProperWeapon(weapon_key):
			continue

		if isTwoHandedWeapon(weapon_key) != two_handed:
			continue

		var price: int = int(Global.weapons[weapon_key].get("price", 0))

		if price <= 0:
			continue

		if price < best_price:
			best_price = price
			best_key = weapon_key

	return best_key


func getCheapestOneHandedWeapon() -> String:
	return getCheapestWeapon(false)


func getCheapestTwoHandedWeapon() -> String:
	return getCheapestWeapon(true)


func getWeaponIsBetter(candidate_key: String, current_key: String) -> bool:
	if !Global.weapons.has(candidate_key):
		return false

	if !Global.weapons.has(current_key):
		return true

	var candidate_power: float = getWeaponPower(candidate_key)
	var current_power: float = getWeaponPower(current_key)

	if candidate_power != current_power:
		return candidate_power > current_power

	var candidate_derived: float = getWeaponDerivedStatsPower(candidate_key)
	var current_derived: float = getWeaponDerivedStatsPower(current_key)

	return candidate_derived > current_derived


func getBestAffordableUpgrade(
	current_key: String,
	two_handed: bool
) -> String:
	if !Global.weapons.has(current_key):
		return ""

	var current_power: float = getWeaponPower(current_key)
	var current_derived: float = getWeaponDerivedStatsPower(current_key)

	var best_key: String = ""
	var best_price: int = 999999999
	var best_power: float = -INF
	var best_derived: float = -INF

	for weapon_key in Global.weapons:
		if !isProperWeapon(weapon_key):
			continue

		if isTwoHandedWeapon(weapon_key) != two_handed:
			continue

		var weapon: Dictionary = Global.weapons[weapon_key]
		var price: int = int(weapon.get("price", 0))

		if price <= 0 or price > bot_coins:
			continue

		var power: float = getWeaponPower(weapon_key)
		var derived: float = getWeaponDerivedStatsPower(weapon_key)

		# Must actually be an upgrade.
		if power < current_power:
			continue

		if power == current_power and derived <= current_derived:
			continue

		# Cheapest upgrade wins first.
		# Power is only used as the tie-breaker when prices are equal.
		if price < best_price:
			best_key = weapon_key
			best_price = price
			best_power = power
			best_derived = derived
		elif price == best_price:
			if power > best_power:
				best_key = weapon_key
				best_power = power
				best_derived = derived
			elif power == best_power and derived > best_derived:
				best_key = weapon_key
				best_derived = derived

	return best_key



"""
Controls the bot's weapon and shield purchases when visiting a weapon trader.

When the bot has no weapon, it randomly chooses its combat archetype:
- 35% chance to choose the DPS archetype, which uses a two-handed weapon.
- 65% chance to choose the tank archetype, which uses a one-handed weapon
  and shield.

The initial archetype is determined by RNG and is not chosen by comparing
the prices of the available loadouts.

For the two-handed DPS archetype:
- The bot buys the cheapest valid two-handed weapon it can afford.
- Mining tools such as pickaxes are ignored.
- Normal axes and hatchets are considered valid weapons.
- The bot remains committed to the two-handed archetype after purchasing one.

For the one-handed tank archetype:
- The bot buys the cheapest valid one-handed weapon it can afford.
- If it cannot yet afford the shield, it buys the weapon by itself.
- On a later trader visit, it prioritizes buying the shield once it can
  afford it.
- This allows the one-handed + shield loadout to be completed across
  multiple trader visits.
- Once the shield is acquired, the bot remains committed to the
  one-handed + shield archetype.

If the bot has a one-handed weapon but still cannot afford the shield:
- It normally waits until it can afford the shield.
- There is only a 5% chance per trader visit to instead attempt to
  purchase another one-handed weapon for dual wielding.
- Dual wielding is therefore a rare alternative rather than the normal
  progression.

Once the bot has a complete loadout:
- A two-handed weapon is only upgraded to another two-handed weapon.
- A one-handed weapon is only upgraded to another one-handed weapon.
- A tank loadout remains one-handed + shield and does not randomly switch
  to two-handed weapons.
- A DPS loadout remains two-handed and does not randomly switch to a
  shield-based loadout.

Weapon upgrades must be strictly more powerful than the weapon currently
owned.

Weapon power is calculated as the weapon's total block value plus the sum
of all its damage values.

When comparing weapons with equal power, the combined value of all
"derived_stats" is used as the tie-breaker. The weapon with the higher
derived-stat total is considered superior.

Among valid upgrades that the bot can currently afford, the cheapest
upgrade is always selected first.

If multiple upgrades have the same price, the one with the highest weapon
power is selected.

If multiple upgrades have the same price and weapon power, the one with
the highest combined "derived_stats" value is selected.

All weapon prices are read directly from Global.weapons so the bot always
uses the actual prices defined in the weapon database.

The function does nothing when the bot cannot currently afford an
appropriate purchase.
"""
var shield_key: String = "shield"
func buyWeaponsFromTrader() -> void:
	

	if bot_weapon_key != "" and isTwoHandedWeapon(bot_weapon_key):
		var upgrade_key: String = getBestAffordableUpgrade(bot_weapon_key, true)

		if upgrade_key == "":
			return

		var upgrade_price: int = int(Global.weapons[upgrade_key].get("price", 0))

		if bot_coins < upgrade_price:
			return

		bot_coins -= upgrade_price
		setBotWeaponLoadout(upgrade_key, "")
		bot_weapon_key = upgrade_key
		bot_offhand_key = ""

		broadcastBotChatMessage("picked up some new gear")
		return

	if bot_weapon_key != "":
		var has_shield: bool = bot_offhand_key == shield_key

		if has_shield:
			var weapon_upgrade: String = getBestAffordableUpgrade(bot_weapon_key, false)

			if weapon_upgrade == "":
				return

			var weapon_price: int = int(Global.weapons[weapon_upgrade].get("price", 0))

			if bot_coins < weapon_price:
				return

			bot_coins -= weapon_price
			setBotWeaponLoadout(weapon_upgrade, shield_key)
			bot_weapon_key = weapon_upgrade
			bot_offhand_key = shield_key

			broadcastBotChatMessage("picked up some new gear")
			return

		if Global.weapons.has(shield_key):
			var shield_price: int = int(Global.weapons[shield_key].get("price", 0))

			if bot_coins >= shield_price:
				bot_coins -= shield_price
				setBotWeaponLoadout(bot_weapon_key, shield_key)
				bot_offhand_key = shield_key

				broadcastBotChatMessage("picked up some new gear")
				return

		var weapon_upgrade: String = getBestAffordableUpgrade(bot_weapon_key, false)

		if weapon_upgrade != "" and randf() < 0.05:
			var upgrade_price: int = int(Global.weapons[weapon_upgrade].get("price", 0))

			if bot_coins >= upgrade_price:
				bot_coins -= upgrade_price
				setBotWeaponLoadout(bot_weapon_key, weapon_upgrade)
				bot_offhand_key = weapon_upgrade

				broadcastBotChatMessage("picked up some new gear")

		return

	var roll: float = randf()
	var wants_two_handed: bool = roll < 0.25

	if wants_two_handed:
		var two_handed_weapon: String = getCheapestTwoHandedWeapon()

		if two_handed_weapon == "":
			return

		var two_handed_price: int = int(Global.weapons[two_handed_weapon].get("price", 0))

		if bot_coins < two_handed_price:
			return

		bot_coins -= two_handed_price
		setBotWeaponLoadout(two_handed_weapon, "")
		bot_weapon_key = two_handed_weapon
		bot_offhand_key = ""

		broadcastBotChatMessage("picked up some new gear")
		return

	var one_handed_weapon: String = getCheapestOneHandedWeapon()

	if one_handed_weapon == "":
		return

	var one_handed_price: int = int(Global.weapons[one_handed_weapon].get("price", 0))

	if bot_coins < one_handed_price:
		return

	bot_coins -= one_handed_price
	setBotWeaponLoadout(one_handed_weapon, "")
	bot_weapon_key = one_handed_weapon
	bot_offhand_key = ""

	broadcastBotChatMessage("picked up some new gear")

func buyPotionsFromTrader() -> void:
	potion_purchases_made += 1
	buyFlaskBulk("medicine potion")
	if potion_purchases_made >= 2:
		buyFlaskBulk("power potion")

func buyFlaskBulk(flask_key:String) -> void:
	if !Global.flasks.has(flask_key):
		return
	var price:int = int(Global.flasks[flask_key].get("price",1))
	if price <= 0:
		price = 1
	var have:int = int(bot_inventory.get(flask_key,0))
	var want:int
	if potion_purchases_made >= 2:
		want = (randi() % 25) + 24
	else:
		want = max(0, potion_buy_target_count - have)
	if want <= 0:
		return
	var afford:int = bot_coins / price
	var buy_amount:int = min(want, afford)
	if buy_amount <= 0:
		return
	bot_coins -= buy_amount * price
	bot_inventory[flask_key] = have + buy_amount
	broadcastBotChatMessage("bought " + str(buy_amount) + " " + flask_key + "s")

func sellInventoryToTrader() -> void:
	var total: int = 0
	for key in bot_inventory.keys():
		var qty: int = int(bot_inventory[key])
		if qty <= 0:
			continue
		# Only food and resources can ever be sold.
		# Weapons, potions, equipment, etc. are always kept.
		var item: Dictionary
		if Global.food.has(key):
			item = Global.food[key]
		elif Global.resources.has(key):
			item = Global.resources[key]
		else:
			continue
		var unit_price: int = int(round(max(1.0, float(item.get("price", 0)) * 0.8)))
		total += unit_price * qty
		bot_inventory.erase(key)
	bot_coins += total
	kills_since_last_sell = 0
	kills_required_to_sell = int(rand_range(4.0, 7.0))
	broadcastBotChatMessage("sold my loot for " + str(total) + " coins")

# Only ever called on the same throttled cadence as findDownedAlly() (mobSearchRetryMs,
# further gated by Global.canRunExpensiveSearchThisFrame())
func maybeStartTraderGoal(nowMs: int) -> void:
	if bot_goal != "":
		return
	if nowMs < trader_search_cooldown_until_ms:
		return

	var has_enough_potions: bool = countPotionsInInventory() >= potion_buy_target_count
	var sell_gate_satisfied: bool = !has_enough_potions or kills_since_last_sell >= kills_required_to_sell

	if getBotInventoryItemCount() >= sell_when_inventory_count_at_least and sell_gate_satisfied:
		var seller = findNearestSellTrader()
		if is_instance_valid(seller) and !Global.isTraderCrowded(seller, currentWorldId()):
			bot_goal = "seeking_sell_trader"
			target_trader = seller
			trader_arrival_time_ms = 0
			pickTraderApproachOffset()
			return

	# Cheapest thing a potion trader sells to this bot is one
	# medicine potion at its real listed price.
	var cheapest_potion_price: int = int(Global.flasks.get("medicine potion", {}).get("price", 1))

	if cheapest_potion_price <= 0:
		cheapest_potion_price = 1

	if countPotionsInInventory() < potion_buy_target_count and bot_coins >= cheapest_potion_price:
		var potion_trader = findNearestPotionTrader()

		if is_instance_valid(potion_trader) and !Global.isTraderCrowded(potion_trader, currentWorldId()):
			bot_goal = "seeking_potion_trader"
			target_trader = potion_trader
			trader_arrival_time_ms = 0
			pickTraderApproachOffset()
			return

	# Find the cheapest proper weapon.
	# Pickaxes and other gathering tools are excluded.
	# Axes are proper weapons and are therefore included.
	var cheapest_weapon_price: int = 999999999

	for weapon_key in Global.weapons:
		var weapon: Dictionary = Global.weapons[weapon_key]
		var price: int = int(weapon.get("price", 0))

		if price <= 0:
			continue

		# Gathering tools are identified by their tool-specific power.
		# Axes are NOT excluded because they are proper weapons.
		var is_tool: bool = weapon.has("mining power")

		if is_tool:
			continue

		cheapest_weapon_price = int(min(cheapest_weapon_price, price))

	# Don't go to the weapon trader just because the bot can afford
	# one weapon. It needs enough money to comfortably afford 3.
	var weapon_purchase_threshold: int = cheapest_weapon_price * 3

	var wants_weapon_trader_visit := false

	if bot_weapon_key == "":
		wants_weapon_trader_visit = (
			cheapest_weapon_price < 999999999
			and bot_coins >= weapon_purchase_threshold
			and randf() < weapon_purchase_chance
		)
	elif !isTwoHandedWeapon(bot_weapon_key) and bot_offhand_key != "shield" and Global.weapons.has("shield"):
		# One-handed loadout still missing its shield -- this used to never
		# re-trigger a trader visit once bot_weapon_key was set, so the
		# shield half of the tank loadout was never bought even when
		# affordable. Go back if the shield alone is affordable.
		var shield_price:int = int(Global.weapons["shield"].get("price", 0))
		wants_weapon_trader_visit = bot_coins >= shield_price
	else:
		# Already has a complete loadout -- occasionally check for an upgrade.
		var upgrade_key:String = getBestAffordableUpgrade(bot_weapon_key, isTwoHandedWeapon(bot_weapon_key))
		wants_weapon_trader_visit = upgrade_key != "" and randf() < 0.15

	if wants_weapon_trader_visit:
		var weapon_trader = findNearestWeaponTrader()

		if is_instance_valid(weapon_trader) and !Global.isTraderCrowded(weapon_trader, currentWorldId()):
			bot_goal = "seeking_weapon_trader"
			target_trader = weapon_trader
			trader_arrival_time_ms = 0
			pickTraderApproachOffset()
			return

	trader_search_cooldown_until_ms = nowMs + trader_search_retry_ms

	trader_search_cooldown_until_ms = nowMs + trader_search_retry_ms

# Called once, when the stare at corpse timer elapses  cheap dictionary merge, no scanning.
func lootCorpse(corpse:Node) -> void:
	if !is_instance_valid(corpse) or !("stats" in corpse):
		return
	var corpse_stats = corpse.stats
	if !is_instance_valid(corpse_stats) or corpse_stats.health > 0:
		return
	var loot_list:Array = Global.generateLootForCorpse(corpse)
	for entry in loot_list:
		var key := str(entry.get("item_key",""))
		var qty := int(entry.get("quantity",0))
		if key == "" or qty <= 0:
			continue
		bot_inventory[key] = int(bot_inventory.get(key,0)) + qty
func pickTraderApproachOffset() -> void:
	var slot = Global.reserveTraderSlot(target_trader, self)
	if slot == -1:
		var angle:float = randf() * TAU
		trader_approach_offset = Vector3(cos(angle) * 2.0, 0.0, sin(angle) * 2.0)
	else:
		trader_approach_offset = Global.getTraderApproachOffset(slot)
