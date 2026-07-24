extends KinematicBody
onready var player_mesh = $character
onready var animation =  $character/AnimationPlayer
onready var anim_calls = $AnimationCalls
onready var character = $character
onready var equipment =$UI/Equipment
onready var skeleton = $character/root/Skeleton


onready var stats =$Stats
onready var camroot = $Camroot
onready var camera_v = $Camroot/h/v
onready var camera_h = $Camroot/h
onready var skillbar = $UI/Skillbar
onready var loot = $UI/Loot
onready var inventory = $UI/Inventory
onready var turnable:Spatial = $Turnable


var respawn_id:int = 0
var entity_name = Global.selected_player_name
export var sex:String = "female"
var creator
var spawned_bodies
export var gravity = 9.8 
# Physics values
var direction = Vector3()
var horizontal_velocity = Vector3()
var aim_turn = float()
var movement = Vector3()
var vertical_velocity = Vector3()
var movement_speed = int()
var angular_acceleration:int = 7.5
var acceleration = int()
var can_move= true
var is_carrying = false
var cursor_visible = false
var is_swimming:bool = false
var is_downed:bool = false
var is_dead:bool = false
var wall_incline
var is_on_stairs: bool = false
var wall_hanging:bool = false
onready var head_ray = $Turnable/Vault
onready var climb_ray = $Turnable/MidRay
onready var root_bone = skeleton.find_bone("ik_foot_root")
var root_motion_active:bool= false
var last_root_pos := Vector3.ZERO
var root_motion_velocity := Vector3.ZERO
var _last_root_motion_pos := Vector3.ZERO
var is_climbing:bool= false
onready var animation_tree:AnimationTree = $AnimationTree
onready var skill_anim = animation_tree.tree_root.get_node("Skill")

enum WeaponMode {
	NONE,
	SWORD,
	DUAL,
	SHIELD,
	TWO_HANDED
}
var which_portal = ""
var which_scene = ""
func _ready():
	match which_portal:
		"mines":
			translation.x = -5.243
			translation.y = 1.101
			translation.z = 13.625
		"world":
			translation.x = 22.5
			translation.y = -16.349
			translation.z = 41.371
	entity_name = Global.selected_player_name
	$UI/Crafting/Smelting.hide()
	$character/root/Skeleton/Mesh.hide()
	equipment.updateEquipment()
	for child in $UI/Skillbar/GridContainer.get_children():
		child.get_node("Slot").player=self
		child.get_node("TextureButton").parent=self
		child.get_node("Slot").loadData()
	direction=Vector3.BACK.rotated(Vector3.UP,$Camroot/h.global_transform.basis.get_euler().y)
	initializeAnimationBlends()
	call_deferred("loadData")
	loadCharacterData()
	ApplySex()
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")
	call_deferred("loadBoneData")
	_updateInputKeys()
	_cacheToolIcons()
	disableFallDamage()
	water_level_area.connect("area_shape_entered", self, "enterDeepWaters")
	water_level_area.connect("area_shape_exited", self, "exitDeepWaters")

var weapons:int = WeaponMode.NONE

var current_skill:String = "none"
var anim_locks = { 
	"combo attack":false,

	"guard":false,
	"downed":false,
	"get up":false,
	"die":false,
	"downed die":false,
	"flinch":false,
	"flinch  back":false,
	"knocked back":false,
	"knocked down":false,
	"guard react":false,

#BERSERK SKILLS
	"raze":false,
	"reckless vengeance":false,
	"shoulder bash":false,
	"stone splitter":false,
	"brutal chop":false,
	"fury strike":false,
	"sadistic blow":false,
	"sunder" :false,
	"heart thrust":false,
	"obliteration":false,
	"obliteration charge":false,
	"obliteration start":false,
	"sledge":false,
	

	"death from above":false,
	"flury of blows":false,
	"section":false,
	"perforation trifecta":false,
	"dodge":false,
	"cleave":false,
	"battlecry":false,
	"dash":false,
	"stop_run":false,
	"parry":false,
	"sit":false,
	"stop_sit":false,
	"scream":false,
	"prepare":false,
	"stunned":false,
	"staggered":false}




var interrupt_groups = {
	"hard_interrupt":["dodge","block","parry","guard react"],
	"skills":["section","perforation trifecta","cleave","battlecry","scream","stone splitter"],
	"base_attack":["combo attack"]
}


var skill_animations = {
	
	
	"mine":{
		WeaponMode.NONE:"mine_cycle",
		WeaponMode.SWORD:"mine_cycle",
		WeaponMode.DUAL:"mine_cycle",
		WeaponMode.SHIELD:"mine_cycle",
		WeaponMode.TWO_HANDED:"mine_cycle",
	},
	"chop":{
		WeaponMode.NONE:"chop_cycle",
		WeaponMode.SWORD:"chop_cycle",
		WeaponMode.DUAL:"chop_cycle",
		WeaponMode.SHIELD:"chop_cycle",
		WeaponMode.TWO_HANDED:"chop_cycle",
	},
	"gather":{
		WeaponMode.NONE:"gather",
		WeaponMode.SWORD:"gather",
		WeaponMode.DUAL:"gather",
		WeaponMode.SHIELD:"gather",
		WeaponMode.TWO_HANDED:"gather",
	},
	
	
	"combo attack":{
		WeaponMode.NONE:"ComboATK_Empty_cycle",
		WeaponMode.SWORD:"ComboATK_OneHanded_cycle",
		WeaponMode.DUAL:"ComboATK_Dual",
		WeaponMode.SHIELD:"ComboATK_OneHanded_cycle",
		WeaponMode.TWO_HANDED:"ComboATK_TwoHanded_cycle",
	},
	"penetrating blow":{
		WeaponMode.SWORD:"Basic_Stab_OneHanded",
		WeaponMode.DUAL:"Basic_Stab_OneHanded",
		WeaponMode.SHIELD:"Basic_Stab_OneHanded",
		WeaponMode.TWO_HANDED:"Basic_Stab_TwoHanded",
		#WeaponMode.BOW:"Basic_PenetratingShot",
	},
	"evasion":{
		WeaponMode.NONE:"Roll_Generic",
		WeaponMode.SWORD:"Roll_Generic",
		WeaponMode.DUAL:"Roll_Generic",
		WeaponMode.SHIELD:"Roll_Generic",
		WeaponMode.TWO_HANDED:"Roll_TwoHanded",
	},
	"backstep":{
		WeaponMode.NONE:"Basic_Generic_Backstep",
		WeaponMode.SWORD:"Basic_Generic_Backstep",
		WeaponMode.DUAL:"Basic_Generic_Backstep",
		WeaponMode.SHIELD:"Basic_Generic_Backstep",
		WeaponMode.TWO_HANDED:"Basic_TwoHanded_Backstep",
	},
	"guard":{
		WeaponMode.NONE:"Guard_Unarmed_cycle",
		WeaponMode.SWORD:"Guard_Sword_cycle",
		WeaponMode.DUAL:"Guard_Dual_cycle",
		WeaponMode.SHIELD:"Guard_Shield_cycle",
		WeaponMode.TWO_HANDED:"Guard_Sword_cycle",
	},
	"guard react":{
		WeaponMode.NONE:"Guard_Unarmed_react",
		WeaponMode.SWORD:"Guard_General_react",
		WeaponMode.DUAL:"Guard_Dual_react",
		WeaponMode.SHIELD:"Guard_Shield_react",
		WeaponMode.TWO_HANDED:"Guard_General_react",
	},
	"downed die":{
		WeaponMode.NONE:"DownedDie",
		WeaponMode.SWORD:"DownedDie",
		WeaponMode.DUAL:"DownedDie",
		WeaponMode.SHIELD:"DownedDie",
		WeaponMode.TWO_HANDED:"DownedDie",
	},
	"die":{
		WeaponMode.NONE:"Die",
		WeaponMode.SWORD:"Die",
		WeaponMode.DUAL:"Die",
		WeaponMode.SHIELD:"Die",
		WeaponMode.TWO_HANDED:"Die",
	},
	"get up":{
		WeaponMode.NONE:"DownedEnd",
		WeaponMode.SWORD:"DownedEnd",
		WeaponMode.DUAL:"DownedEnd",
		WeaponMode.SHIELD:"DownedEnd",
		WeaponMode.TWO_HANDED:"DownedEnd",
	},
	"flinch  back":{
		WeaponMode.NONE:"FlinchBack_OneHanded",
		WeaponMode.SWORD:"FlinchBack_OneHanded",
		WeaponMode.DUAL:"FlinchBack_OneHanded",
		WeaponMode.SHIELD:"FlinchBack_OneHanded",
		WeaponMode.TWO_HANDED:"FlinchBack_TwoHanded",
	},
	"flinch":{
		WeaponMode.NONE:"Flinch_OneHanded",
		WeaponMode.SWORD:"Flinch_OneHanded",
		WeaponMode.DUAL:"Flinch_OneHanded",
		WeaponMode.SHIELD:"Flinch_OneHanded",
		WeaponMode.TWO_HANDED:"Flinch_TwoHanded",
	},
	
	"knocked back":{
		WeaponMode.NONE:"FlinchKnockedBack_OneHanded",
		WeaponMode.SWORD:"FlinchKnockedBack_OneHanded",
		WeaponMode.DUAL:"FlinchKnockedBack_OneHanded",
		WeaponMode.SHIELD:"FlinchKnockedBack_OneHanded",
		WeaponMode.TWO_HANDED:"FlinchKnockedBack_TwoHanded",
	},
	"knocked down":{
		WeaponMode.NONE:"KnockedDown_OneHanded",
		WeaponMode.SWORD:"KnockedDown_OneHanded",
		WeaponMode.DUAL:"KnockedDown_OneHanded",
		WeaponMode.SHIELD:"KnockedDown_OneHanded",
		WeaponMode.TWO_HANDED:"KnockedDown_TwoHanded",
	},


#WARDEN SKLLLS
"veiled thrust":{
		WeaponMode.SWORD:"Warden_VeiledThrust_OneHanded",
		WeaponMode.DUAL:"Warden_VeiledThrust_OneHanded",
		WeaponMode.SHIELD:"Warden_VeiledThrust_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_VeiledThrust_TwoHanded",
	},
"shield bash":{
		WeaponMode.NONE:"Warden_Bash_OneHanded",
		WeaponMode.SWORD:"Warden_Bash_OneHanded",
		WeaponMode.DUAL:"Warden_Bash_OneHanded",
		WeaponMode.SHIELD:"Warden_Bash_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_Bash_TwoHanded",
	},
"shield pummel":{
		WeaponMode.NONE:"Warden_ShieldPummel_OneHanded",
		WeaponMode.SWORD:"Warden_ShieldPummel_OneHanded",
		WeaponMode.DUAL:"Warden_ShieldPummel_OneHanded",
		WeaponMode.SHIELD:"Warden_ShieldPummel_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_ShieldPummel_TwoHanded",
	},
"mighty push":{
		WeaponMode.NONE:"Warden_MightyPush_OneHanded",
		WeaponMode.SWORD:"Warden_MightyPush_OneHanded",
		WeaponMode.DUAL:"Warden_MightyPush_OneHanded",
		WeaponMode.SHIELD:"Warden_MightyPush_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_MightyPush_TwoHanded",
	},
"smite":{
		WeaponMode.SWORD:"Warden_Smite_OneHanded",
		WeaponMode.DUAL:"Warden_Smite_OneHanded",
		WeaponMode.SHIELD:"Warden_Smite_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_Smite_TwoHanded",
	},
"aegis":{
		WeaponMode.NONE:"Rally",
		WeaponMode.SWORD:"Rally",
		WeaponMode.DUAL:"Rally",
		WeaponMode.SHIELD:"Rally",
		WeaponMode.TWO_HANDED:"Rally",
	},
"second wind":{
		WeaponMode.NONE:"Scream_OneHanded",
		WeaponMode.SWORD:"Scream_OneHanded",
		WeaponMode.DUAL:"Scream_OneHanded",
		WeaponMode.SHIELD:"Scream_OneHanded",
		WeaponMode.TWO_HANDED:"Scream_TwoHanded",
	},
"counterstrike":{
		WeaponMode.NONE:"Warden_CounterStrike_OneHanded",
		WeaponMode.SWORD:"Warden_CounterStrike_OneHanded",
		WeaponMode.DUAL:"Warden_CounterStrike_OneHanded",
		WeaponMode.SHIELD:"Warden_CounterStrike_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_CounterStrike_TwoHanded",
	},
"intercept":{
		WeaponMode.NONE:"Warden_Intercept_OneHanded",
		WeaponMode.SWORD:"Warden_Intercept_OneHanded",
		WeaponMode.DUAL:"Warden_Intercept_OneHanded",
		WeaponMode.SHIELD:"Warden_Intercept_OneHanded",
		WeaponMode.TWO_HANDED:"Warden_Intercept_TwoHanded",
	},


#DROMEUS SKILLS
"cross draw":{
		WeaponMode.NONE:"Dromeus_CrossDraw_Dual",
		WeaponMode.SWORD:"Dromeus_CrossDraw_Dual",
		WeaponMode.DUAL:"Dromeus_CrossDraw_Dual",
		WeaponMode.SHIELD:"Dromeus_CrossDraw_Dual",
		WeaponMode.TWO_HANDED:"Dromeus_CrossDraw_Dual",
	},
"lunar slash":{
		WeaponMode.NONE:"Dromeus_LunarSlash_Dual",
		WeaponMode.SWORD:"Dromeus_LunarSlash_Dual",
		WeaponMode.DUAL:"Dromeus_LunarSlash_Dual",
		WeaponMode.SHIELD:"Dromeus_LunarSlash_Dual",
		WeaponMode.TWO_HANDED:"Dromeus_LunarSlash_Dual",
	},
"recoil slash":{
		WeaponMode.NONE:"Dromeus_RecoilSlash_OneHanded",
		WeaponMode.SWORD:"Dromeus_RecoilSlash_OneHanded",
		WeaponMode.DUAL:"Dromeus_RecoilSlash_OneHanded",
		WeaponMode.SHIELD:"Dromeus_RecoilSlash_OneHanded",
		WeaponMode.TWO_HANDED:"Dromeus_RecoilSlash_OneHanded",
	},
#BERSERK SKILLS
	"raze":{
		WeaponMode.SWORD:"Berserk_Raze_OneHanded",
		WeaponMode.DUAL:"Berserk_Raze_OneHanded",
		WeaponMode.SHIELD:"Berserk_Raze_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_Raze_TwoHanded",
	},
	"reckless":{
		WeaponMode.SWORD:"Buff_OneHanded",
		WeaponMode.DUAL:"Buff_OneHanded",
		WeaponMode.SHIELD:"Buff_OneHanded",
		WeaponMode.TWO_HANDED:"Buff_TwoHanded",
	},
	"stone splitter":{
		WeaponMode.SWORD:"Berserk_StoneSplitter_OneHanded",
		WeaponMode.DUAL:"Berserk_StoneSplitter_OneHanded",
		WeaponMode.SHIELD:"Berserk_StoneSplitter_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_StoneSplitter_TwoHanded",
	},
	"brutal chop":{
		WeaponMode.SWORD:"Berserk_BrutalChop_OneHanded",
		WeaponMode.DUAL:"Berserk_BrutalChop_OneHanded",
		WeaponMode.SHIELD:"Berserk_BrutalChop_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_BrutalChop_TwoHanded",
	},
	"shoulder bash":{
		WeaponMode.NONE:"Berserk_ShoulderBash_OneHanded",
		WeaponMode.SWORD:"Berserk_ShoulderBash_OneHanded",
		WeaponMode.DUAL:"Berserk_ShoulderBash_OneHanded",
		WeaponMode.SHIELD:"Berserk_ShoulderBash_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_ShoulderBash_TwoHanded",
	},
	
	"fury strike":{
		WeaponMode.SWORD:"Berserk_FuryStrike_OneHanded",
		WeaponMode.DUAL:"Berserk_FuryStrike_OneHanded",
		WeaponMode.SHIELD:"Berserk_FuryStrike_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_FuryStrike_TwoHanded",
	},
	"sadistic blow":{
		WeaponMode.SWORD:"Berserk_SadisticBlow_OneHanded",
		WeaponMode.DUAL:"Berserk_SadisticBlow_OneHanded",
		WeaponMode.SHIELD:"Berserk_SadisticBlow_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_SadisticBlow_TwoHanded",
	},

	"sunder" :{
		WeaponMode.SWORD:"Berserk_Sunder_OneHanded",
		WeaponMode.DUAL:"Berserk_Sunder_OneHanded",
		WeaponMode.SHIELD:"Berserk_Sunder_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_Sunder_TwoHanded",
	},
	"sledge":{
		WeaponMode.SWORD:"Berserk_Sledge_OneHanded",
		WeaponMode.DUAL:"Berserk_Sledge_OneHanded",
		WeaponMode.SHIELD:"Berserk_Sledge_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_Sledge_TwoHanded",
	},
	"heart thrust":{
		WeaponMode.SWORD:"Berserk_HeartThrust_OneHanded",
		WeaponMode.DUAL:"Berserk_HeartThrust_OneHanded",
		WeaponMode.SHIELD:"Berserk_HeartThrust_OneHanded",
		WeaponMode.TWO_HANDED:"Berserk_HeartThrust_TwoHanded",
	},
	"obliteration charge":{
		WeaponMode.SWORD:"Berserk_ObliterationCharge_cycle",
		WeaponMode.DUAL:"Berserk_ObliterationCharge_cycle",
		WeaponMode.SHIELD:"Berserk_ObliterationCharge_cycle",
		WeaponMode.TWO_HANDED:"Berserk_ObliterationCharge_cycle",
	},
	"obliteration":{
		WeaponMode.SWORD:"Berserk_SadisticBlow_TwoHanded",
		WeaponMode.DUAL:"Berserk_SadisticBlow_TwoHanded",
		WeaponMode.SHIELD:"Berserk_SadisticBlow_TwoHanded",
		WeaponMode.TWO_HANDED:"Berserk_SadisticBlow_TwoHanded",
	},

	"death from above":{
		WeaponMode.NONE:"ALL_DeathFromAbove",
		WeaponMode.SWORD:"ALL_DeathFromAbove",
		WeaponMode.DUAL:"ALL_DeathFromAbove",
		WeaponMode.SHIELD:"ALL_DeathFromAbove",
		WeaponMode.TWO_HANDED:"ALL_DeathFromAbove",
	},
	"flury of blows":{
		WeaponMode.NONE:"ALL_Guillotine",
		WeaponMode.SWORD:"ALL_Guillotine",
		WeaponMode.DUAL:"ALL_Guillotine",
		WeaponMode.SHIELD:"ALL_Guillotine",
		WeaponMode.TWO_HANDED:"ALL_Guillotine",
	},
	"section":{
		WeaponMode.NONE:"1h_Section",
		WeaponMode.SWORD:"1h_Section",
		WeaponMode.DUAL:"1h_Section",
		WeaponMode.SHIELD:"1h_Section",
		WeaponMode.TWO_HANDED:"1h_Section",
	},
	"perforation trifecta":{
		WeaponMode.NONE:"1h_PerforactionTrifecta",
		WeaponMode.SWORD:"1h_PerforactionTrifecta",
		WeaponMode.DUAL:"1h_PerforactionTrifecta",
		WeaponMode.SHIELD:"1h_PerforactionTrifecta",
		WeaponMode.TWO_HANDED:"1h_PerforactionTrifecta",
	},
	"cleave":{
		WeaponMode.NONE:"1h_Slice",
		WeaponMode.SWORD:"1h_Slice",
		WeaponMode.DUAL:"1h_Slice",
		WeaponMode.SHIELD:"1h_Slice",
		WeaponMode.TWO_HANDED:"1h_Slice",
	},
	"parry":{
		WeaponMode.NONE:"ALL_SwordGuard",
		WeaponMode.SWORD:"ALL_SwordGuard",
		WeaponMode.DUAL:"ALL_SwordGuard",
		WeaponMode.SHIELD:"ALL_SwordGuard",
		WeaponMode.TWO_HANDED:"Backstep",
	},


	"dodge":{
		WeaponMode.NONE:"Basic_Slide_OneHanded",
		WeaponMode.SWORD:"Basic_Slide_OneHanded",
		WeaponMode.DUAL:"Basic_Slide_OneHanded",
		WeaponMode.SHIELD:"Basic_Slide_OneHanded",
		WeaponMode.TWO_HANDED:"Basic_Slide_TwoHanded",
	},
	"downed":{
		WeaponMode.NONE:"DownedStart",
		WeaponMode.SWORD:"DownedStart",
		WeaponMode.DUAL:"DownedStart",
		WeaponMode.SHIELD:"DownedStart",
		WeaponMode.TWO_HANDED:"DownedStart",
	},

}
var last_skill_animation:String =""
var guard_react_priority := false

func activateAnimLock(lock_name:String)->void:
	if lock_name=="guard react":
		unlockAnim()
		guard_react_priority=true
		anim_locks.clear()
		anim_locks["guard react"]=true
		current_skill="guard"
		return
	guard_react_priority=false
	if anim_locks["dodge"] and lock_name!="dodge": return
	if lock_name=="dodge":
		unlockAnim();anim_locks["dodge"]=true;current_skill="dodge";return
	if lock_name=="parry":
		unlockAnim();anim_locks["parry"]=true;current_skill="parry";return


	if lock_name == "combo attack":
		for key in anim_locks:
			if anim_locks[key]:
				return

		anim_locks["combo attack"] = true
		current_skill = lock_name
		return

	if lock_name in interrupt_groups["skills"]:
		anim_locks["combo attack"] = false

		for skill in interrupt_groups["skills"]:
			anim_locks[skill] = false

		anim_locks[lock_name] = true
		current_skill = lock_name

func getActiveAnimLock()->String:
	var active_locks=[]
	for lock_name in anim_locks:
		if anim_locks[lock_name]:
			active_locks.append(lock_name)
	 $UI/Chat/debug.text=", ".join(active_locks)  
	if active_locks.size()>0:
		return active_locks[0]
	return ""
"""
Assigns the correct animation for a skill based on the player's current
weapon mode.
If the skill exists but does not have an animation assigned for the
currently equipped weapon type, the skill is cancelled and its resource
cost and cooldown are refunded through skillbar.reimburseSkill().
Parameters:skill_name (String)Name of the skill being activated.
Returns:
	void
"""

var last_active_skill:String = ""

func setSkillAnimation(skill_name:String)->void:
	if !skill_animations.has(skill_name):
		return
	var skill_data = skill_animations[skill_name]
	var new_anim:String = ""
	if skill_data.has(weapons):
		new_anim=skill_data[weapons]
	else:
		anim_locks[skill_name] = false
		current_skill = "none"
		if anim_locks["flinch"] == false or anim_locks["knocked back"] == false:
			unlockAnim()
		skillbar.reimburseSkill(skill_name)
		animation_tree.active =true
		return

	if new_anim == "":
		anim_locks[skill_name] = false
		current_skill = "none"
		skillbar.reimburseSkill(skill_name)
		animation_tree.active =true
		return

	# Same skill still active this frame.
	# Do nothing.
	if skill_name == last_active_skill:
		return

	last_active_skill = skill_name

	skill_anim.animation = new_anim
	animation_tree.active = false
	animation_tree.active = true




var movement_blend:float= -1.0
var combat_blend:float= -1.0
var attack_defend_switch:float= 0.0

var movement_type_blend:float= 0.0
var vertical_blend:float= 0.0
var crouch_blend:float= 1.0
var crouch_mode_blend:float= 0.0
var climb_blend:float= 0.0
var water_blend:float = 0.0

var anim_blend_cache := {}

# ------------------------------------------------------------
# setAnimBlend
# Smooths any AnimationTree blend parameter using per-path
# cached interpolation instead of overwriting values directly.
# This prevents flickering caused by competing writes from
# different animation states in the same frame.
# Parameters:
# - path: AnimationTree parameter path
# - target: desired blend value (-1 to 1 or 0 to 1 depending on node)
# - speed: interpolation strength (higher = snappier, lower = smoother)
# - delta: frame delta time
# ------------------------------------------------------------
var flip_blend_timer:float= 0.0
var dodge_cleanup_timer:float= 0.0
var dodge_cleanup_reset:bool= false
var dodge_cleanup_blend_speed:float = 0.4
var blend:float = 1
func setAnimBlend(path:String, target:float, speed:float, delta:float) -> void:
	var current:float = 0.0

	if anim_blend_cache.has(path):
		var cached_value = anim_blend_cache[path]
		if cached_value != null:
			current = float(cached_value)
		else:
			print("Player.gd setAnimBlend(): AnimBlend warning: null cache value for path: ", path)
			current = 0.0
	else:
		var tree_value = animation_tree.get(path)
		if tree_value == null:
			print("Player.gd setAnimBlend(): AnimBlend warning: missing AnimationTree path: ", path)
			current = 0.0
		else:
			current = float(tree_value)

	current = move_toward(current, target, delta * speed)

	anim_blend_cache[path] = current
	animation_tree.set(path, current)
func initializeAnimationBlends() -> void:
	var blendPaths:Array = [
		"parameters/CombatSwitch/blend_amount",
		"parameters/MeleeSkillSwitch/blend_amount",
		"parameters/Movement/blend_amount",
		"parameters/MovementType/blend_amount",
		"parameters/Vertical/blend_amount",
		"parameters/CrouchOrNot/blend_amount",
		"parameters/CrouchMode/blend_amount",
		"parameters/climbPoint/blend_amount",
		"parameters/Water/blend_amount",
		"parameters/IsInCombat/blend_amount",
		"parameters/SkillBlend/blend_amount"
	]

	anim_blend_cache.clear()

	for path in blendPaths:
		var value = animation_tree.get(path)

		if value == null:
			print("Player.gd initializeAnimationBlends(): AnimBlend init warning: missing AnimationTree path: ", path)
			value = 0.0

		anim_blend_cache[path] = float(value)

func safeGetBlend(path:String) -> float:
	var value = animation_tree.get(path)
	if value == null:
		return 0.0
	return float(value)



var combat_walk_animations = {
	WeaponMode.NONE:"Walk_cycle",
	WeaponMode.SWORD:"Walk_OneHandedCombat_cycle",
	WeaponMode.DUAL:"Walk_OneHandedCombat_cycle",
	WeaponMode.SHIELD:"Walk_OneHandedCombat_cycle",
	WeaponMode.TWO_HANDED:"Walk_TwoHandedCombat_cycle",
}
var combat_run_animations = {
	WeaponMode.NONE:"Sprint_cycle",
	WeaponMode.SWORD:"Run_OneHandedCombat_cycle",
	WeaponMode.DUAL:"Run_OneHandedCombat_cycle",
	WeaponMode.SHIELD:"Run_OneHandedWithShieldCombat_cycle",
	WeaponMode.TWO_HANDED:"Run_TwoHandedCombat_cycle",
}
var combat_idle_animations = {
	WeaponMode.NONE:"IdleOneHanded_cycle",
	WeaponMode.SWORD:"IdleOneHanded_cycle",
	WeaponMode.DUAL:"IdleOneHanded_cycle",
	WeaponMode.SHIELD:"IdleOneHanded_cycle",
	WeaponMode.TWO_HANDED:"IdleTwoHanded_cycle",
}
onready var combat_idle = animation_tree.tree_root.get_node("CombatIdle")
onready var combat_walk = animation_tree.tree_root.get_node("WalkCombat")
onready var run_node = animation_tree.tree_root.get_node("RunCombat")
onready var combat_idle_skill_smooth = animation_tree.tree_root.get_node("IdleForSkill")
func setCombatIdleAnimation()->void:
	if !combat_idle_animations.has(weapons):
		return
	var anim = combat_idle_animations[weapons]

	combat_idle.animation = anim
	combat_idle_skill_smooth.animation = anim
func setCombatWalkAnimation()->void:
	if !combat_walk_animations.has(weapons):
		return
	var anim = combat_walk_animations[weapons]

	combat_walk.animation = anim
func setRunAnimation()->void:
	if !combat_run_animations.has(weapons):
		return
	var anim = combat_run_animations[weapons]

	run_node.animation = anim

var skillExitBlendSpeed:float = 2.0

func animationOrder() -> void:
	if stats.debuff_buffs_active.has("stunned") and float(stats.debuff_buffs_active["stunned"].get("duration",0.0)) > 0.0:
		animation_tree.set("parameters/CombatSwitch/blend_amount", 0.0)
		animation_tree.set("parameters/MovementType/blend_amount", 0.0)
		animation_tree.set("parameters/CrouchOrNot/blend_amount", 1.0)
		animation_tree.set("parameters/Movement/blend_amount", -1.0)
		animation_tree.set("parameters/IsInCombat/blend_amount", 0.0)
		animation_tree.active = true
		return
	#leave animaiton_tree off by default 
	var delta:float =get_process_delta_time()
	var active_lock:=getActiveAnimLock()
	var now = OS.get_ticks_msec() / 1000.0
	var skill_scale:float =  stats.derived_stats["attack_speed"] 
	if anim_calls.speed_up_combo_until.has(active_lock):
		if now < anim_calls.speed_up_combo_until[active_lock]:
			skill_scale =  stats.derived_stats["attack_speed"] + 3
		else:
			anim_calls.speed_up_combo_until.erase(active_lock)

	animation_tree.set("parameters/SkillTimeScale/scale", skill_scale)
	
	var speed_factor_walk = max(0.0, stats.walk_speed / 4.0)
	if speed_factor_walk > 1.0:
		speed_factor_walk = 1.0 + sqrt(speed_factor_walk - 1.0) * 0.5
	animation_tree.set("WalkSpeed", speed_factor_walk)
	var speed_factor_run = max(0.0, stats.run_speed / 15.5)
	if speed_factor_run > 1.0:
		speed_factor_run = 1.0 + (speed_factor_run - 1.0) * 0.25
	animation_tree.set("RunSpeed", speed_factor_run)
	
	
	# -----------------------------
	# STAGGER / STUN OVERRIDE
	# -----------------------------
	if stats != null and stats.statuses.has("stun"):
		last_active_skill = "staggered"
		current_skill = "staggered"
		skill_anim.animation = "staggered"

		animation_tree.set("parameters/CombatSwitch/blend_amount", 1.0)
		animation_tree.set("parameters/MeleeSkillSwitch/blend_amount",1.0)
		animation_tree.set("parameters/MeleeSkillSwitch/blend_amount", 1.0)
		return

	else:
		anim_locks["stunned"] = false
		anim_locks["staggered"] = false

		# ============================================================
		# SKILL / COMBAT STATE
		# ============================================================
		if active_lock!="" and skill_animations.has(active_lock):
			setSkillAnimation(active_lock)
			setAnimBlend("parameters/SkillBlend/blend_amount",1.0,blend,delta)
			setAnimBlend("parameters/CombatSwitch/blend_amount",1.0,blend,delta)
			setAnimBlend("parameters/MeleeSkillSwitch/blend_amount",1.0,blend,delta)

			if active_lock == "combo attack":
				skill_scale = stats.derived_stats["attack_speed"]

			if anim_calls != null and anim_calls.speed_up_combos.has(active_lock):
				animation_tree.set("parameters/SkillTimeScale/scale", skill_scale)

			return
		# Character returns to movement locomotion state.
		# ============================================================
		last_active_skill=""

		# ------------------------------------------------------------
		# Leave combat state smoothly.
		# ------------------------------------------------------------

		if flip_blend_timer > 0.0:
			animation_tree.set("parameters/CombatSwitch/blend_amount",1.0)
			animation_tree.set("parameters/MeleeSkillSwitch/blend_amount",1.0)
		else:
			animation_tree.set("parameters/CombatSwitch/blend_amount",0.0)
			animation_tree.set("parameters/MeleeSkillSwitch/blend_amount",0.0)

		# ============================================================
		# TARGET VALUES
		# ============================================================
		# These values are calculated first.
		# Afterward they are interpolated smoothly.
		# ============================================================
		var movement_target:float=-1.0
		var movement_type_target:float=0.0
		var vertical_target:float=0.0
		var crouch_target:float=1.0
		var crouch_mode_target:float=0.0
		var climb_target:float=0.0
		var water_target:float=0.0

		# ============================================================
		# AIRBORNE STATE
		# ============================================================
		if is_airborne and !is_climbing and !is_swimming:
			movement_type_target=1.0
			vertical_target=1.0

		else:
			if is_dead == true:
				return
			# ========================================================
			# MOVEMENT STATE MACHINE
			# ========================================================
			match movement_mode:

				# ----------------------------------------------------
				# IDLE
				# ----------------------------------------------------
				"idle":
					if stats.health >0:
						setAnimBlend("parameters/IsAlive/blend_amount",1.0,blend,delta)
						movement_target=-1.0
						if is_in_combat:
							setAnimBlend("parameters/IsInCombat/blend_amount",1.0,blend,delta)
							setCombatIdleAnimation()

						else:
							setAnimBlend("parameters/IsInCombat/blend_amount",0.0,blend,delta)
					else:
						setAnimBlend("parameters/IsAlive/blend_amount",0.0,blend,delta)
						setAnimBlend("parameters/Downed/blend_amount",0.0,blend,delta)
				# ----------------------------------------------------
				# WALK
				# ----------------------------------------------------
				"walk":
					movement_target=0.0
					if stats.health >0:
						setAnimBlend("parameters/IsAlive/blend_amount",1.0,blend,delta)
						if is_in_combat == true:
							animation_tree.set("parameters/WalkCombatOrNot/blend_amount",1)
							setCombatWalkAnimation()
						else:
							animation_tree.set("parameters/WalkCombatOrNot/blend_amount",0)
					else:
						setAnimBlend("parameters/IsAlive/blend_amount",0.0,blend,delta)
						setAnimBlend("parameters/Downed/blend_amount",1.0,blend,delta)
				# ----------------------------------------------------
				# RUN
				# ----------------------------------------------------
				"run":
					if stats.health >0:
						if is_in_combat == true: 
							setRunAnimation()
							animation_tree.set("parameters/IsInCombatRun/blend_amount",1)
						else:
							animation_tree.set("parameters/IsInCombatRun/blend_amount",0)
						movement_target=1.0
						animation_tree.set("parameters/RunSpeed/scale",0.8+(0.0125*stats.run_speed))
						
				# ----------------------------------------------------
				# CROUCH IDLE
				# ----------------------------------------------------
				"crouch_idle":
					crouch_target=0.0
					crouch_mode_target=0.0
					animation_tree.set("parameters/CrouchMov/blend_amount",0)
					animation_tree.set("parameters/IsInCombatRun/blend_amount",0)
				# ----------------------------------------------------
				# CROUCH MOVEMENT
				# ----------------------------------------------------
				"crouch_moving":
					crouch_target=0.0
					crouch_mode_target=1.0
					animation_tree.set("parameters/CrouchMov/blend_amount",1)
					animation_tree.set("parameters/IsInCombatRun/blend_amount",0)
				# ----------------------------------------------------
				# CLIMB
				# ----------------------------------------------------
				"climb":
					movement_type_target=1.0
					vertical_target=0.0
					climb_target=0.0

				# ----------------------------------------------------
				# VAULT
				# ----------------------------------------------------
				"vault":
					movement_type_target=1.0
					vertical_target=0.0
					climb_target=1.0

				# ----------------------------------------------------
				# SWIMMING
				# ----------------------------------------------------
				"swimming":
					movement_type_target=-1.0
					water_target=1.0

					animation_tree.set("parameters/SwimSpeed/scale",0.97+(0.03*stats.derived_stats["swim_speed"]))

				# ----------------------------------------------------
				# TREADING WATER
				# ----------------------------------------------------
				"treading water":
					movement_type_target=-1.0
					water_target=0.0
		# ============================================================
		# FINAL BLENDING
		# ============================================================
		# All calculated targets are interpolated smoothly.
		# This prevents snapping between animation states.
		# ============================================================
		setAnimBlend("parameters/Movement/blend_amount",movement_target,8.0,delta)
		setAnimBlend("parameters/MovementType/blend_amount",movement_type_target,8.0,delta)


		setAnimBlend("parameters/CrouchOrNot/blend_amount",crouch_target,8.0,delta)
		setAnimBlend("parameters/CrouchMode/blend_amount",crouch_mode_target,8.0,delta)
		setAnimBlend("parameters/climbPoint/blend_amount",climb_target,8.0,delta)
		setAnimBlend("parameters/Water/blend_amount",water_target,8.0,delta)






		

export var root_motion_scale:float = 0.01

onready var detection_area:Area = $Turnable/Area

var root_motion_exceptions = [
	"shoulder bash",
	"backstep",
	"evasion",
	"foresight slash",
	"lunar slash"
]

func rootMotion(delta)->void:
	if current_skill == "backstep":
		root_motion_scale = 0.01 * stats.attributes["agility"] * 1.25

	var ignore_detection = (
		current_skill in root_motion_exceptions
		or anim_locks["flinch"]
		or anim_locks["knocked back"]
		or anim_locks["knocked down"]
		or anim_locks["dodge"]
	)

	if !ignore_detection:
		for body in detection_area.get_overlapping_bodies():
			if body != self and body.is_in_group("Entity"):
				return



	var motion:Transform = animation_tree.get_root_motion_transform()
	var offset:Vector3 = motion.origin
	offset.y = 0.0

	if offset.length_squared() < 0.000001:
		return

	offset *= root_motion_scale
	offset = player_mesh.global_transform.basis.xform(offset)

	move_and_slide(Vector3(offset.x / delta, vertical_velocity.y, offset.z / delta), Vector3.UP)








var unstuckDistance = 15
onready var dodge_check:Area = $Turnable/Cleave

func dodgeMessage()->void:
	var bodies = dodge_check.get_overlapping_bodies()
	for body in bodies:
		if body == self: continue
		if !body.is_in_group("Entity"): continue

		var skill_name = body.get("current_skill") if body.has_method("get") or "current_skill" in body else ""
		if skill_name == "" or skill_name == "none" or !Skills.skills.has(skill_name) or Skills.support_skills.has(skill_name): continue
		
		var message = "dodged "
		if "entity_name" in body and body.entity_name != "nameless":
			message += body.entity_name
		else:
			message += body.species

		message += " " + skill_name
		chat.sendSystemMessage(message)
					
					
onready var area_check_level_detector = $unstuckCheck

func dodgeCollisions(_delta) -> void:
	var is_dodge_skill = Skills.skill_dmg_immunity.has(current_skill)

	if is_dodge_skill:
		if current_skill != last_active_skill:
			dodgeMessage()

		anim_calls.disableCollisions()

		var should_enable = true

		for body in area_check_level_detector.get_overlapping_bodies():
			if body == self:
				continue

			if body.is_in_group("Entity") and !body.is_in_group("Player"):
				horizontal_velocity = direction.normalized() * stats.walk_speed
				should_enable = false
				break

		if should_enable:
			anim_calls.enableCollisions()

		return

	anim_calls.enableCollisions()




var mining_icons = []
var chopping_icons = []
var harvest_key = ""
var loot_key = ""



func _updateInputKeys():
	harvest_key = InputMap.get_action_list("Harvest")[0].as_text().replace(" (Physical)", "").replace(" (physical)", "")

	var loot_keys = []
	for event in InputMap.get_action_list("loot"):
		loot_keys.append(event.as_text().replace(" (Physical)", "").replace(" (physical)", ""))
	loot_key = " / ".join(loot_keys)

func _cacheToolIcons():
	mining_icons.clear()
	chopping_icons.clear()

	for weapon_name in Items.weapons:
		var weapon = Items.weapons[weapon_name]
		var icon = weapon.icon
		if typeof(icon) == TYPE_STRING:
			icon = load(icon)

		if weapon.has("mining power"):
			mining_icons.append(icon)

		if weapon.has("chopping power"):
			chopping_icons.append(icon)


func detectGathering() -> void:
	var label:Label = $UI/ResourceDetectionLabel
	label.visible = false
	label.text = ""

	for body in $"Turnable/Area".get_overlapping_bodies():
		if body == self:
			continue
		if (body.is_in_group("entity") or body.is_in_group("Entity")) and "stats" in body and body.stats.health <= 0:
			label.visible = true
			label.text = "Press " + loot_key + " to loot"
			return

	var bash = $"Turnable/Bash"

	for target in bash.get_overlapping_bodies():
		if _handleGatherTarget(target, label):
			return

	for target in bash.get_overlapping_areas():
		if _handleGatherTarget(target, label):
			return

func _handleGatherTarget(target, label:Label) -> bool:
	if !is_instance_valid(target) or !target.is_in_group("Resource"):
		return false

	var main_hand=$"UI/Equipment/MainHand/Slot".texture
	var inventory=$UI/Inventory/ScrollContainer/GridContainer
	var has_pickaxe=main_hand in mining_icons
	var has_axe=main_hand in chopping_icons

	if !has_pickaxe or !has_axe:
		for child in inventory.get_children():
			var slot=child.get_node_or_null("Slot")
			if !slot:continue
			if !has_pickaxe and slot.texture in mining_icons:
				has_pickaxe=true
			if !has_axe and slot.texture in chopping_icons:
				has_axe=true
			if has_pickaxe and has_axe:
				break

	var can_harvest=false
	for group in target.get_groups():
		match group.to_lower():
			"plant":
				can_harvest=true
			"rock","iron","gold":
				can_harvest=has_pickaxe
			"tree":
				can_harvest=has_axe
		if can_harvest:
			break

	if can_harvest and current_skill!="mine" and current_skill!="gather" and current_skill!="chop":
		label.visible=true
		label.text="Press "+harvest_key+" to Harvest"

	if !Input.is_action_just_pressed("Harvest"):
		return true

	if !can_harvest:
		return true

	forceRotationTowardsTarget(target)

	for group in target.get_groups():
		match group.to_lower():
			"plant":
				skillbar.castSkill("gather")
				return true
			"rock","iron","gold":
				skillbar.castSkill("mine")
				return true
			"tree":
				skillbar.castSkill("chop")
				return true

	return true
#func _handleGatherTarget(target, label:Label) -> bool:
#	if !is_instance_valid(target) or !target.is_in_group("Resource"):
#		return false
#
#	if current_skill != "mine" and current_skill != "gather" and current_skill != "chop":
#		label.visible = true
#		label.text = "Press " + harvest_key + " to Harvest"
#
#	if !Input.is_action_just_pressed("Harvest"):
#		return true
#
#	forceRotationTowardsTarget(target)
#
#	var main_hand = $"UI/Equipment/MainHand/Slot".texture
#	var inventory = $UI/Inventory/ScrollContainer/GridContainer
#
#	for group in target.get_groups():
#		match group.to_lower():
#			"plant":
#				skillbar.castSkill("gather")
#				return true
#
#			"rock", "iron", "gold":
#				if main_hand in mining_icons:
#					skillbar.castSkill("mine")
#					return true
#
#				for child in inventory.get_children():
#					var slot = child.get_node_or_null("Slot")
#					if slot and slot.texture in mining_icons:
#						skillbar.castSkill("mine")
#						return true
#
#			"tree":
#				if main_hand in chopping_icons:
#					skillbar.castSkill("chop")
#					return true
#
#				for child in inventory.get_children():
#					var slot = child.get_node_or_null("Slot")
#					if slot and slot.texture in chopping_icons:
#						skillbar.castSkill("chop")
#						return true
#
#	return true



func detectCraftingStations()->void:
	var smelting_system:Control=$UI/Crafting/Smelting
	var recipes_book:Control=$UI/Crafting/RecipeeBook
	var label:Label=$UI/ResourceDetectionLabel

	var key=InputMap.get_action_list("Harvest")[0].as_text().replace(" (Physical)","").replace(" (physical)","")

	for target in $"Turnable/Bash".get_overlapping_bodies()+$"Turnable/Bash".get_overlapping_areas():
		if !is_instance_valid(target):continue
		if target.is_in_group("Fire") and Input.is_action_just_pressed("Harvest"):
			if crafting.current_fire!=target:
				if crafting.current_fire:
					crafting.saveSmelter(crafting.current_fire)
				crafting.loadSmelter(target)
			
			smelting_system.visible=!smelting_system.visible
			recipes_book.visible=false
			inventory.visible=true
			crafting.visible=true
			return

		if target.is_in_group("Portal"):
			label.visible=true
			label.text="Press "+key+" to enter portal"
			if  Input.is_action_just_pressed("Harvest"):
				var world = get_parent()
				world.portal()


onready var crafting:Control = $UI/Crafting
onready var skill_tree_root:Control = $UI/SkillTreeRoot
func _physics_process(delta)->void:

	
	dodgeCollisions(delta)
	detectGathering()
	if current_skill=="mine" or current_skill=="chop" or current_skill=="gather":
		if !chat.line_edit.has_focus():
			if Input.is_action_pressed("forward") or Input.is_action_pressed("backward") or Input.is_action_pressed("left")or Input.is_action_pressed("right"):
				current_skill=""
				anim_calls.unlockAnim()

	if stats.health <= 0:
		skillbar.combo_queue = 0
		skillbar.continue_combo_atk = false
		anim_locks["combo attack"] = false
		animation_tree.set("parameters/CombatSwitch/blend_amount",0)
		animation_tree.set("parameters/IsAlive/blend_amount",0)
	if anim_locks["guard react"] == true:
		anim_locks["guard"] = false 
	if Engine.get_physics_frames() % 12 == 0:
		if is_on_floor():
			water_areas.clear()
			is_in_water = false
	animationOrder()
	safetyStuff()
	forceMovementAnimUnlock()
	if Input.is_action_just_pressed("unstuck"):
		if is_writing == false and is_chatting == false:
			is_in_combat = !is_in_combat
			translation.x = 0
			translation.y = 20
			translation.z = 0
			enableEntityCollisions()
			unlockAnim()
			disableFallDamage()
			is_in_water = false
	if Input.is_action_just_pressed("out_of_combat"):
		if is_writing == false and is_chatting == false:
			is_in_combat = !is_in_combat

	if Input.is_action_just_pressed("skills"):
		if is_writing == false and is_chatting == false:
			skill_tree_root.visible = !skill_tree_root.visible
	buoyancy(delta)
	rootMotion(delta)
	if anim_locks["stunned"] == false and anim_locks["staggered"] == false and is_dead == false:
		jump()
		movement(delta)
	physics(delta)
	collisionShapesManager()
	
	if cursor_visible == false:
		dash()

	if !movement_mode == "idle":
		loot.closeLoot()
		inventory.clearCart()
		inventory.shop.hide()
		$UI/Crafting/Smelting.hide()
		if inventory.buy_button.visible == false:
			inventory.restoreBrokerItems()
	if Input.is_action_just_pressed("character"):
		if is_writing == false:
			equipment.visible = !equipment.visible
			inventory.shop.visible =false
			$UI/SkillTreeRoot.visible =false
		

	crafting.update_crafting()
	
	if !crafting.visible:
		crafting.returnCraftingItems()
	else:
		if is_writing == false:
			if Input.is_action_just_pressed("help"):
				crafting.recipes_book.visible  = false

	detectCraftingStations()
	if Engine.get_physics_frames() % 6 == 0:
		forceWaterSwitch()
	if Engine.get_physics_frames() % 12 == 0:
		equipment.updateEquipment()
	if Engine.get_physics_frames() % 35 == 0:
		if inventory.visible: if inventory.has_method("updateInventory"):inventory.updateInventory()
	if Engine.get_physics_frames() % 60 == 0:
		$UI/CrossairInspect.crossairInspect(self)
		$UI/Menu/CharacterBar.updateBars()
	if Engine.get_physics_frames() % 12000 == 0:
		if not is_in_combat:
			stored_body == null
	movement_speed = 0
	acceleration = 15

	if !is_in_water:
		if !is_on_floor():
			vertical_velocity += Vector3.DOWN * gravity * 2 * delta
		else:
			vertical_velocity = -get_floor_normal() * gravity / 3
	else:
		vertical_velocity.y = 0
	checkFall()


func _input(event):
	if event.is_action_pressed("Esc"):
		is_writing = false
		is_chatting = false
		crafting.line_edit.release_focus()
		chat.line_edit.release_focus()







var moving:bool = false
var movement_mode:String = "idle"
var previous_movement_mode:String = "idle"
var effective_turn_speed:float 


	
onready var fullbody_collision=$CollisionShape
onready var upper_body_collision=$CollisionUP
onready var lower_body_collision=$CollisionDown

func collisionShapesManager()->void:
	var crouching=movement_mode=="crouch_idle" or movement_mode=="crouch_moving"

	fullbody_collision.disabled=crouching
	upper_body_collision.disabled=crouching
	lower_body_collision.disabled=!crouching
	
var movement_unlock_locks = [
	"parry",
	"guard",
]
func clearMovementLocks()->void:
	for lock_name in movement_unlock_locks:
		if anim_locks.has(lock_name):
			anim_locks[lock_name] = false

var animation_almost_finished:bool = false
var is_chatting:bool = false
func forceRotationTowardsTarget(target)->void:
	if !is_instance_valid(self) or !is_instance_valid(player_mesh) or !is_instance_valid(turnable):
		return
	if target==null:
		return

	var pos
	if target is Spatial:
		if !is_instance_valid(target):
			return
		pos=target.global_transform.origin
	elif target is Vector3:
		pos=target
	else:
		return

	var dir=pos-global_transform.origin
	dir.y=0
	if dir.length_squared()==0:
		return

	var rot=atan2(dir.x,dir.z)-rotation.y
	player_mesh.rotation.y=rot
	turnable.rotation.y=rot
var is_writing:bool= false
func movement(delta) -> void:
	if is_writing == true:
		return
	if stats.debuff_buffs_active.has("stunned") and float(stats.debuff_buffs_active["stunned"].get("duration",0.0)) > 0.0:
		return
	if is_chatting == true:
		return 
	# ==================================================
	# TURN SPEED HANDLING (combat overrides)
	# ==================================================
	effective_turn_speed = base_turn_speed
	
	# Attacking or guarding slows turn rate (or dash modifies it)
	if guarding or attacking:
		effective_turn_speed = stats.derived_stats["atk_turn_speed"] if !is_dashing else base_turn_speed * stats.derived_stats["dash_turn_speed"]
	elif is_dashing:
		effective_turn_speed = base_turn_speed * stats.derived_stats["dash_turn_speed"] * 20

	# ==================================================
	# RESET / INITIAL STATE
	# ==================================================
	previous_movement_mode = movement_mode
	movement_mode = "idle"

	var input_direction = Vector3.ZERO

	# ==================================================
	# INPUT COLLECTION
	# ==================================================
	if can_move or !guarding:
		if Input.is_action_pressed("left") and !is_climbing:
			anim_locks["downed"] = false
			if anim_locks["guard"] == false:
				animation_tree.active = true
				input_direction.x += 1
		elif Input.is_action_pressed("right") and !is_climbing:
			anim_locks["downed"] = false
			if anim_locks["guard"] == false:
				animation_tree.active = true
				input_direction.x -= 1
		if Input.is_action_pressed("forward"):
			anim_locks["downed"] = false
			if anim_locks["guard"] == false:
				animation_tree.active = true
				input_direction.z += 1
			
		elif Input.is_action_pressed("backward"):
			anim_locks["downed"] = false
			if anim_locks["guard"] == false:
				animation_tree.active = true
				input_direction.z -= 1

	var movement_input = input_direction.length() > 0
	if current_skill != "" or current_skill != "none":
		if !Skills.canRotateDuringSkill(current_skill):
			input_direction = Vector3.ZERO
			movement_input = false
	var crouching = Input.is_action_pressed("crouch") and inventory.shop.visible == false
	var sprinting = Input.is_action_pressed("sprint") and !crouching
		
	# ==================================================
	# INPUT-BASED ANIM LOCK CLEAR (requested change)
	# ==================================================
	if movement_input:
		# movement cancels these locks immediately
		clearMovementLocks()


	# ==================================================
	# STOP RUN TRIGGER LOGIC
	# ==================================================
#	if anim_locks["stop_run"] and movement_input:
#		activateAnimLock("stop_run")

	# ==================================================
	# GLOBAL LOCK CHECK (prevents movement override)
	# ==================================================
	var locked = false
	for anim_name in anim_locks.keys():
		if anim_name != "stop_run" and anim_locks[anim_name]:
			locked = true
			break

	# ==================================================
	# CAMERA-RELATIVE DIRECTION
	# ==================================================
	var h_rot = camera_v.global_transform.basis.get_euler().y

	movement_speed = 0
	moving = false

	if movement_input:
		direction = input_direction.rotated(Vector3.UP, h_rot).normalized()
	else:
		direction = Vector3.ZERO

	# ==================================================
	# MOVEMENT STATE MACHINE
	# ==================================================
	if !locked:
		if direction != Vector3.ZERO:
			moving = true
			if crouching:
				movement_mode = "crouch_moving"
				movement_speed = stats.walk_speed * 0.5
				is_in_combat = false
				
				animation_tree.active = true

			elif sprinting and !is_in_water and stats.health >0:
				movement_speed = stats.run_speed
				movement_mode = "run"
				animation_tree.active = true

			else:
				movement_mode = "walk"
				movement_speed = stats.walk_speed

				# leaving sprint triggers stop_run lock
				if previous_movement_mode == "run":
					pass
					#anim_locks["stop_run"] = true

		else:
			if crouching :
				movement_mode = "crouch_idle"
				animation_tree.active = true
				is_in_combat = false
			else:
				movement_mode = "idle"

			if previous_movement_mode == "run":
				pass
			#	anim_locks["stop_run"] = true

	else:
		moving = false
		movement_mode = "idle"
		movement_speed = 0

	# ==================================================
	# MOVEMENT MODIFIERS
	# ==================================================
	if is_carrying:
		movement_speed *= 0.7

	if is_in_combat:
		movement_speed *= 0.65

	if attacking:
		movement_speed *= 0.38
	if stats.health<=0:
		is_in_combat = false
		movement_speed *= 0.07

	# ==================================================
	# WATER OVERRIDE STATE
	# ==================================================
	if is_in_water == true:
		animation_tree.active = true
		if moving:
			movement_mode = "swimming"
			movement_speed = stats.derived_stats["swim_speed"]
		else:
			movement_mode = "treading water"

	# ==================================================
	# ROTATION HANDLING
	# ==================================================
	var can_rotate = true

	if current_skill != "":
		can_rotate = Skills.skill_rotation_allowed.get(current_skill, false)

	if is_instance_valid(player_mesh) and is_instance_valid(turnable):
		if can_rotate:
			for anim_name in anim_locks:
				if anim_locks[anim_name] and !Skills.skill_rotation_allowed.get(anim_name,false):
					can_rotate=false
					break

			if anim_locks.has("guard") and anim_locks["guard"] or current_skill=="guard" or anim_locks.has("guard react") and anim_locks["guard react"] or current_skill=="guard react":
				pass
			elif can_rotate and !is_climbing and direction!=Vector3.ZERO:
				var target_rot=atan2(direction.x,direction.z)-rotation.y
				player_mesh.rotation.y=lerp_angle(player_mesh.rotation.y,target_rot,delta*angular_acceleration)
				turnable.rotation.y=lerp_angle(turnable.rotation.y,target_rot,delta*angular_acceleration)

func forceMovementAnimUnlock()->void:
	if animation_almost_finished == true:
		if Input.is_action_pressed("sprint"):
			var has_lock = false
			for lock_name in anim_locks:
				if anim_locks[lock_name]:
					has_lock = true
			if has_lock == true:
				anim_calls.unlockAnim()
				animation_almost_finished = false
			else:
				animation_almost_finished = false



var is_dashing:bool = false
var dash_timer:float = 0.0
var dash_duration:float = 0.3
var dash_velocity:Vector3 = Vector3.ZERO
var dash_falloff:float = 12.0
var dash_current_speed:float = 0.0
var dash_max_power:float = 50.0
var dash_accel:float = 10.0
var dash_start_delay:float = 0.06
var dash_time:float = 0.0

var dash_phase:int = 0
# 0 = startup (10%)
# 1 = delay
# 2 = acceleration
var base_turn_speed:float = 4.4
var dash_turn_multiplier:float = 10
var dash_start_speed:float = 0.0




var last_dash_input = ""
var last_dash_time = 0.0
var dash_double_press_time = 0.15
func dash()->void:
	var current_input = ""
	if Input.is_action_just_pressed("forward"):
		current_input = "forward"
	elif Input.is_action_just_pressed("backward"):
		current_input = "backward"
	elif Input.is_action_just_pressed("left"):
		current_input = "left"
	elif Input.is_action_just_pressed("right"):
		current_input = "right"
	if current_input == "":
		return
	var time = OS.get_ticks_msec() / 1000.0
	if current_input == last_dash_input and time - last_dash_time <= dash_double_press_time:
		activateAnimLock("dodge")

		guarding =false
		last_dash_input = ""
		last_dash_time = 0
	else:
		last_dash_input = current_input
		last_dash_time = time


func enableEntityCollisions()->void:
	for body in get_tree().get_nodes_in_group("Entity"):
		if body == self:
			continue
		remove_collision_exception_with(body)
		body.remove_collision_exception_with(self)

func unlockAnim():
	for key in anim_locks:
		anim_locks[key] = false
	current_skill = ""
	enableEntityCollisions()
	animation_tree.active = false
	last_active_skill = ""
	stats.charged_attack_stacks["obliteration"]["stacks"] = 0 


var guarding:bool = false
var attacking:bool = false
var is_in_combat:bool = false
onready var stored_body:KinematicBody = null
var stored_body_timer:int = 15


onready var left_ray:RayCast = $Turnable/Left
onready var right_ray:RayCast = $Turnable/Right
var climbing_is_enabled:bool = true


var is_wall_in_range:bool = false
func checkWallInclination()-> void:
	if get_slide_count() > 0:
		var collision_info = get_slide_collision(0)
		var normal = collision_info.normal
		if normal.length_squared() > 0:
			wall_incline = acos(normal.y)  # Calculate the inclination angle in radians
			wall_incline = rad2deg(wall_incline)  # Convert inclination angle to degrees
			if normal.x < 0:
				wall_incline = -wall_incline
			# Check if the wall inclination is within the specified range 
			is_wall_in_range = (wall_incline >= -60 and wall_incline <= 60)
		else:
			wall_incline = 0  # Set to 0 if the normal is not valid
			is_wall_in_range = false
	else:
		wall_incline = 0  # Set to 0 if there is no collision
		is_wall_in_range = false


func jump()->void:
	var has_lock = false
	for lock_name in anim_locks:
		if anim_locks[lock_name]:
			has_lock = true
			
	if has_lock == false:
		if stats.health >=1:
			if cursor_visible == false:
				if Input.is_action_just_pressed("jump") and is_on_floor():
					vertical_velocity = Vector3.UP * stats.derived_stats["jump_power"]
					is_in_combat = false



	
var was_on_floor := true
var max_fall_speed := 0.0
var fall_start_y := 0.0
var is_falling := false
var highest_y:float = 0.0
var is_airborne:bool = false
var airborne_delay := 0.0

export var safe_fall_speed := 28.0
export var fall_damage_multiplier := 4
var fall_damage_grace_period := 0.0
export var fall_damage_grace_time := 15
func disableFallDamage():
	fall_damage_grace_period = fall_damage_grace_time
	is_airborne = false
	was_on_floor = true
	highest_y = global_transform.origin.y
func checkFall():
	if fall_damage_grace_period > 0.0:
		fall_damage_grace_period -= get_physics_process_delta_time()
		was_on_floor = is_on_floor()
		highest_y = global_transform.origin.y
		return
	if is_in_water:
		is_airborne = false
		airborne_delay = 0.0
		return

	var on_floor := is_on_floor()

	# Left ground
	if was_on_floor and !on_floor:
		is_in_combat = false
		highest_y = global_transform.origin.y

		if Input.is_action_pressed("sprint"):
			airborne_delay = 0.3
			is_airborne = false
		else:
			airborne_delay = 0.0
			is_airborne = true

	# Delay airborne while sprinting
	if !on_floor and airborne_delay > 0.0:
		airborne_delay -= get_physics_process_delta_time()
		if airborne_delay <= 0.0:
			is_airborne = true

	if is_airborne and !is_climbing:
		movement_mode = "fall"

	# Track highest point
	if !on_floor:
		highest_y = max(highest_y, global_transform.origin.y)
		animation_tree.active = true
		animation_tree.set("parameters/Vertical/blend_amount", 1)

	# Landed
	if !was_on_floor and on_floor:
		airborne_delay = 0.0

		if is_airborne:
			var landing_y = global_transform.origin.y
			var fall_distance = highest_y - landing_y

			if !attacking and (current_skill == "" or current_skill == "none"):
				applyFallDamage(fall_distance)

		is_airborne = false

	was_on_floor = on_floor
	
	
	
	
onready var chat:Control = $UI/Chat

export var minimum_fall_distance := 3.0
export var base_fall_damage_multiplier := 3
export var base_fall_resistance := 1.0

func applyFallDamage(fall_distance: float):
	if fall_damage_grace_period > 0.0:
		return
	if fall_distance < stats.derived_stats["jump_power"]:
		return

	var damage := int(max(0.0, round(((fall_distance - minimum_fall_distance) * base_fall_damage_multiplier) / (base_fall_resistance + stats.derived_stats["fall_resistance"]) - stats.derived_stats["jump_power"])))

	stats.health -= damage
	is_in_combat = false

	if damage > 0:
		chat.sendSystemMessage(entity_name + " took " + str(damage) + " fall damage")















var is_in_water:bool = false
var water_areas := []

func physics(delta):
	if root_motion_active:
		if is_in_water:
				translation.y += vertical_velocity.y * get_physics_process_delta_time()

				movement.x = horizontal_velocity.x
				movement.y = 0
				movement.z = horizontal_velocity.z

				move_and_slide(movement,Vector3.ZERO,false,4,PI,false)
		else:
			vertical_velocity = move_and_slide(vertical_velocity,Vector3.ZERO,false,4,PI,false)
		return
	if is_dashing:
		dash_time += delta
		dash_timer -= delta
		var dash_dir = direction.normalized()
		if dash_phase == 0:
			dash_current_speed = dash_start_speed
			if dash_time >= dash_start_delay:
				dash_phase = 1
				dash_time = 0.0
		elif dash_phase == 1:
			dash_current_speed = dash_start_speed
			if dash_time >= 0.05:
				dash_phase = 2
				dash_time = 0.0
		elif dash_phase == 2:dash_current_speed = lerp(dash_current_speed,dash_max_power,12.0 * delta)
		horizontal_velocity = dash_dir * dash_current_speed
		if dash_timer <= 0.0:
			is_dashing = false
			dash_phase = 0
			dash_turn_multiplier = 1.0
	else:horizontal_velocity = horizontal_velocity.linear_interpolate(direction.normalized() * movement_speed,acceleration * delta)
	movement.z = horizontal_velocity.z + vertical_velocity.z
	movement.x = horizontal_velocity.x + vertical_velocity.x
	movement.y = vertical_velocity.y
	if is_in_water:
			translation.y += vertical_velocity.y * get_physics_process_delta_time()

			movement.x = horizontal_velocity.x
			movement.y = 0
			movement.z = horizontal_velocity.z

			move_and_slide(movement,Vector3.ZERO,false,4,PI,false)
	else:
		movement = move_and_slide(movement,Vector3.UP)
func isWaterArea(area) -> bool:
	var node = area
	while node:
		if node.is_in_group("Water") or node.is_in_group("water"):
			return true
		if node.name.to_lower() == "water":
			return true
		node = node.get_parent()
	return false

onready var water_level_area:Area = $WaterLevelChest
onready var water_level_legs_area:Area = $WaterLevelLegs
func enterDeepWaters(area_rid, area, area_shape_index, _local_shape_index):
	if isWaterArea(area):
		if !water_areas.has(area):
			water_areas.append(area)
		is_in_water = true
		is_in_combat = false
		stats.applyBuffDebuff("wrenched", self)


var water_exit_pending := false

func exitDeepWaters(area_rid, area, area_shape_index, _local_shape_index):
	if water_exit_pending:
		return

	water_exit_pending = true
	yield(get_tree().create_timer(2.0), "timeout")
	water_exit_pending = false

	var touching_floor = is_on_floor()

	if is_instance_valid($DistanceToFloordRay):
		touching_floor = touching_floor or $DistanceToFloordRay.is_colliding()

	if touching_floor:
		if water_areas.has(area):
			water_areas.erase(area)

		var valid_water_areas := []
		for water_area in water_areas:
			if is_instance_valid(water_area):
				valid_water_areas.append(water_area)

		water_areas = valid_water_areas
		is_in_water = water_areas.size() > 0


func getWaterSurfaceY(area: Area) -> float:
	var node = area

	while node:
		if node is MeshInstance and node.mesh is CubeMesh:
			var size = node.mesh.size
			return node.global_transform.origin.y + size.y * node.global_transform.basis.get_scale().y * 0.5
		node = node.get_parent()

	return area.global_transform.origin.y

func buoyancy(_delta) -> void:
	var valid_water_areas := []
	for water_area in water_areas:
		if is_instance_valid(water_area):
			valid_water_areas.append(water_area)

	water_areas = valid_water_areas

	if !is_in_water:
		return

	var chest_underwater = false
	for area in water_level_area.get_overlapping_areas():
		if isWaterArea(area):
			chest_underwater = true
			break

	var speed = stats.derived_stats["swim_speed"]
	var surface_offset = 1.35
	var can_go_up = false

	for area in water_areas:
		var water_surface_y = getWaterSurfaceY(area) + surface_offset

		if global_transform.origin.y < water_surface_y:
			can_go_up = true
			break

	# At water surface, jump exits water instead of swimming upward
	if Input.is_action_pressed("jump") and !chest_underwater:
		water_areas.clear()
		is_in_water = false
		return

	if Input.is_action_pressed("crouch"):
		vertical_velocity.y = -speed

	elif Input.is_action_pressed("jump") and can_go_up:
		vertical_velocity.y = speed

	elif chest_underwater and can_go_up:
		vertical_velocity.y = max(vertical_velocity.y, speed * 0.35)

	else:
		vertical_velocity.y = 0.0


var force_water_timer := 0.0

func forceWaterSwitch() -> void:
	if !is_instance_valid(water_level_area):
		return

	var chest_in_water := false

	for area in water_level_area.get_overlapping_areas():
		if isWaterArea(area):
			chest_in_water = true

			if !water_areas.has(area):
				water_areas.append(area)

	if chest_in_water:
		force_water_timer = 0.0
		is_in_water = true
	else:
		force_water_timer += 6.0 / float(Engine.iterations_per_second)

		if force_water_timer >= 1.0:
			if $DistanceToFloordRay.is_colliding():
				water_areas.clear()
				is_in_water = false
















func safetyStuff()->void:
	if stats != null and !stats.statuses.has("stun"):
		anim_locks["stunned"] = false
		anim_locks["staggered"] = false



var male_scene = null
var female_scene = null
func get_character_scene(male:bool)->PackedScene:
	if male:
		if !male_scene: male_scene = load("res://world/player/human/scenes/character_male.tscn")
		return male_scene
	if !female_scene: female_scene = load("res://world/player/human/scenes/character_female.tscn")
	return female_scene

func _on_SexChange_pressed():
	var male=stats.sex=="female"
	stats.sex="male" if male else "female"
	$UI/Chat/SexChange.text=stats.sex
	ApplySex()

func ApplySex():
	var packed_scene=get_character_scene(stats.sex=="male")
	if !packed_scene: return

	var old_character=$character
	var previous_transform=Transform()

	if is_instance_valid(old_character):
		previous_transform=old_character.transform
		old_character.get_parent().remove_child(old_character)
		old_character.queue_free()

	var new_character=packed_scene.instance()
	new_character.name="character"
	new_character.transform=previous_transform
	add_child(new_character)
	player_mesh=new_character

	if animation_tree:
		var animation_player=new_character.get_node_or_null("AnimationPlayer")
		var root_bone=new_character.get_node_or_null("root/Skeleton/root")
		if animation_player and animation_tree.has_method("set_animation_player"):
			animation_tree.call("set_animation_player",animation_player.get_path())
		elif animation_player:
			animation_tree.set("anim_player",animation_player.get_path())
		if root_bone:
			animation_tree.set("root_motion_track",root_bone.get_path())

	equipment.updateEquipment()
	animation_tree.call_deferred("findAnimPlayer")
	$character/root/Skeleton/Mesh.hide()
	stats.applySpecies()
	stats.resetAttributePoints()
	
func _on_SexChange_mouse_entered():
	 $UI/Chat/SexChange.text = stats.sex
func saveData()->void:
	if !is_instance_valid(self):
		return

	var world_id = get_parent().world_id
	var save_dir = "user://"
	var save_path = save_dir + name + "_" + entity_name + ".save"
	var dir = Directory.new()

	if !dir.dir_exists(save_dir):
		dir.make_dir_recursive(save_dir)

	var data = {
		"position": translation,
		"current_skill": current_skill,
		"cursor_visible": cursor_visible,
		"direction": direction,
		"which_scene": which_scene,
		"world_id": world_id
	}

	if is_instance_valid(character):
		data.character_rotation = character.rotation
	if is_instance_valid(turnable):
		data.turnable_rotation = turnable.rotation
	if is_inside_tree():
		data.rotation = rotation

	var file = File.new()
	if file.open(save_path, File.WRITE) == OK:
		file.store_var(data)
		file.close()

	# Update the character's sex inside button_list.save
	var button_list_path = "user://button_list.save"
	var button_data = {
		"buttons": [],
		"sexes": {}
	}

	var button_file = File.new()

	if button_file.file_exists(button_list_path):
		if button_file.open(button_list_path, File.READ) == OK:
			var loaded_data = button_file.get_var()
			button_file.close()

			if typeof(loaded_data) == TYPE_DICTIONARY:
				button_data = loaded_data

	if !button_data.has("buttons") or typeof(button_data["buttons"]) != TYPE_ARRAY:
		button_data["buttons"] = []

	if !button_data.has("sexes") or typeof(button_data["sexes"]) != TYPE_DICTIONARY:
		button_data["sexes"] = {}

	if button_data["buttons"].find(entity_name) == -1:
		button_data["buttons"].append(entity_name)

	button_data["sexes"][entity_name] = stats.sex

	if button_file.open(button_list_path, File.WRITE) == OK:
		button_file.store_var(button_data)
		button_file.close()

func loadData()->void:
	var save_path = "user://" + name + "_" + entity_name + ".save"

	var file = File.new()

	if !file.file_exists(save_path):
		return

	if file.open(save_path, File.READ) != OK:
		return

	var data = file.get_var()
	file.close()

	if typeof(data) != TYPE_DICTIONARY:
		return

	if data.has("rotation"):
		rotation = data["rotation"]

	if data.has("which_scene"):
		which_scene = data["which_scene"]

	if data.has("character_rotation") and is_instance_valid(character):
		character.rotation = data["character_rotation"]

	if data.has("turnable_rotation") and is_instance_valid(turnable):
		turnable.rotation = data["turnable_rotation"]


	if data.has("cursor_visible"):
		cursor_visible = data["cursor_visible"]

	if data.has("direction"):
		direction = data["direction"]

	yield(get_tree(), "idle_frame")

	if which_portal != "":
		match which_portal:
			"mines":
				translation.x = -5.243
				translation.y = 1.101
				translation.z = 13.625

			"world":
				translation.x = 22.5
				translation.y = -16.349
				translation.z = 41.371

			_:
				if data.has("world_id"):
					var current_world_id = get_parent().world_id

					if current_world_id != data["world_id"]:
						switchToSavedWorld(data["world_id"], data)
						return

				if data.has("position"):
					translation = data["position"]

	else:
		if data.has("world_id"):
			var current_world_id = get_parent().world_id

			if current_world_id != data["world_id"]:
				switchToSavedWorld(data["world_id"], data)
				return

		if data.has("position"):
			translation = data["position"]
	yield(get_tree(), "physics_frame")
	disableFallDamage()

func switchToSavedWorld(saved_world_id:String, data:Dictionary)->void:
	var target_scene = "res://World.tscn"

	if saved_world_id == "mines":
		target_scene = "res://mines.tscn"

	var packed_scene = load(target_scene)

	if packed_scene == null:
		return

	var new_scene = packed_scene.instance()

	var old_scene = get_tree().current_scene

	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

	var player_found = false

	for node in new_scene.get_children():
		if node.is_in_group("Player") and node.entity_name == entity_name:
			player_found = true

			if data.has("position"):
				node.translation = data["position"]

			break

	if !player_found:
		var new_player = load("res://world/player/scenes/Player.tscn").instance()

		new_player.entity_name = entity_name
		new_player.which_scene = saved_world_id

		new_scene.add_child(new_player)

		if data.has("position"):
			new_player.translation = data["position"]

	old_scene.queue_free()



func loadCharacterData()->void:
	var file = File.new()
	if !file.file_exists("user://button_list.save"):
		return
	if file.open("user://button_list.save", File.READ) != OK:
		return
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("sexes") and typeof(data["sexes"]) == TYPE_DICTIONARY:
		var sexes:Dictionary = data["sexes"]
		if sexes.has(entity_name):
			stats.sex = sexes[entity_name]


	call_deferred("loadBoneData")
	call_deferred("loadHairData")
	yield(get_tree(),"idle_frame")
	call_deferred("loadBlendShapeData")
	call_deferred("loadEyeData")
var boneDefaultRest = {}

var lastSkeleton = null
func loadBoneData()->void:
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")

	var currentSkeleton:Skeleton = get_node_or_null("character/root/Skeleton")

	if currentSkeleton == null:
		return

	if lastSkeleton != currentSkeleton:
		boneDefaultRest.clear()
		lastSkeleton = currentSkeleton

	var file = File.new()

	if !file.file_exists("user://button_list.save"):
		return

	if file.open("user://button_list.save", File.READ) != OK:
		return

	var data = file.get_var()
	file.close()

	if typeof(data) != TYPE_DICTIONARY:
		return

	if data.has("sexes") and typeof(data["sexes"]) == TYPE_DICTIONARY:
		if data["sexes"].has(entity_name):
			stats.sex = data["sexes"][entity_name]

	if !data.has("bone_scale"):
		return

	if typeof(data["bone_scale"]) != TYPE_DICTIONARY:
		return

	if !data["bone_scale"].has(entity_name):
		return

	var savedBones:Dictionary = data["bone_scale"][entity_name]

	for boneName in savedBones:

		if !is_instance_valid(currentSkeleton):
			return

		var boneIndex = currentSkeleton.find_bone(boneName)

		if boneIndex == -1:
			continue

		if !boneDefaultRest.has(boneName):
			boneDefaultRest[boneName] = currentSkeleton.get_bone_rest(boneIndex)

		var bone = savedBones[boneName]

		if typeof(bone) != TYPE_DICTIONARY:
			bone = {
				"scale":1.0,
				"width":1.0,
				"height":1.0,
				"depth":1.0,
				"rotation":0.0,
				"position":Vector3()
			}

		if !bone.has("scale"):
			bone["scale"] = 1.0
		if !bone.has("width"):
			bone["width"] = 1.0
		if !bone.has("height"):
			bone["height"] = 1.0
		if !bone.has("depth"):
			bone["depth"] = 1.0
		if !bone.has("rotation"):
			bone["rotation"] = 0.0
		if !bone.has("position") or typeof(bone["position"]) != TYPE_VECTOR3:
			bone["position"] = Vector3()

		var position:Vector3 = bone["position"]

		if boneName == "clavicle_l" or boneName == "clavicle_r":
			position.x = -position.x

		var rest:Transform = boneDefaultRest[boneName]

		var basis:Basis = rest.basis

		basis = basis.scaled(Vector3(
			bone["scale"] * bone["width"],
			bone["scale"] * bone["height"],
			bone["scale"] * bone["depth"]
		))

		basis = basis.rotated(
			Vector3.UP,
			deg2rad(bone["rotation"])
		)

		currentSkeleton.set_bone_rest(
			boneIndex,
			Transform(
				basis,
				rest.origin + position
			)
		)
func loadHairData()->void:
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")

	var skeleton:Skeleton=get_node_or_null("character/root/Skeleton")
	if skeleton==null:
		return

	var file=File.new()
	if !file.file_exists("user://button_list.save"):
		return
	if file.open("user://button_list.save",File.READ)!=OK:
		return

	var data=file.get_var()
	file.close()

	if typeof(data)!=TYPE_DICTIONARY:
		return

	var style:=0
	if data.has("hair") and typeof(data["hair"])==TYPE_DICTIONARY and data["hair"].has(entity_name):
		style=int(data["hair"][entity_name])

	var textureVariant:=0
	if data.has("hair_texture") and typeof(data["hair_texture"])==TYPE_DICTIONARY and data["hair_texture"].has(entity_name):
		textureVariant=int(data["hair_texture"][entity_name])

	var color:=Color.white
	if data.has("hair_colors") and typeof(data["hair_colors"])==TYPE_DICTIONARY and data["hair_colors"].has(entity_name):
		color=data["hair_colors"][entity_name]

	var paths={
		"male":[
			"res://world/player/human/male/hair/1.tscn",
			"res://world/player/human/male/hair/2.tscn",
			"res://world/player/human/male/hair/3.tscn"],
		"female":[
			"res://world/player/human/female/hair/1.tscn",
			"res://world/player/human/female/hair/2.tscn",
			"res://world/player/human/female/hair/3.tscn"]}

	var textures={
		"male":[#placeholder
			"res://world/player/human/female/hair/textures/hair1fem.png",
			"res://world/player/human/female/hair/textures/hair1fem_dark.png",
			"res://world/player/human/female/hair/textures/hair1fem_darker.png",
			"res://world/player/human/female/hair/textures/hair1fem_darkest.png",
			"res://world/player/human/female/hair/textures/hair2fem.png",
			"res://world/player/human/female/hair/textures/hair2fem_dark.png",
			"res://world/player/human/female/hair/textures/hair2fem_darker.png",
			"res://world/player/human/female/hair/textures/hair2fem_darkest.png",
			"res://world/player/human/female/hair/textures/hair3fem.png",
			"res://world/player/human/female/hair/textures/hair3fem_dark.png",
			"res://world/player/human/female/hair/textures/hair3fem_darker.png",
			"res://world/player/human/female/hair/textures/hair3fem_darkest.png"],
		"female":[
			"res://world/player/human/female/hair/textures/hair1fem.png",
			"res://world/player/human/female/hair/textures/hair1fem_dark.png",
			"res://world/player/human/female/hair/textures/hair1fem_darker.png",
			"res://world/player/human/female/hair/textures/hair1fem_darkest.png",
			"res://world/player/human/female/hair/textures/hair2fem.png",
			"res://world/player/human/female/hair/textures/hair2fem_dark.png",
			"res://world/player/human/female/hair/textures/hair2fem_darker.png",
			"res://world/player/human/female/hair/textures/hair2fem_darkest.png",
			"res://world/player/human/female/hair/textures/hair3fem.png",
			"res://world/player/human/female/hair/textures/hair3fem_dark.png",
			"res://world/player/human/female/hair/textures/hair3fem_darker.png",
			"res://world/player/human/female/hair/textures/hair3fem_darkest.png"]}

	if !paths.has(stats.sex):
		return

	style=clamp(style,0,paths[stats.sex].size()-1)
	textureVariant=clamp(textureVariant,0,3)

	for child in skeleton.get_children():
		if child.name=="Hair" or child.is_in_group("Hair"):
			child.free()

	var hair=load(paths[stats.sex][style]).instance()
	hair.name="Hair"
	skeleton.add_child(hair)
	makeHairUnique(hair)
	applyHairTextureRecursive(hair,load(textures[stats.sex][style*4+textureVariant]))
	applyHairColorRecursive(hair,color)



func makeHairUnique(node:Node):
	if node is MeshInstance:
		if node.mesh:
			node.mesh=node.mesh.duplicate()
			for i in range(node.mesh.get_surface_count()):
				var material=node.mesh.surface_get_material(i)
				if material:
					material=material.duplicate()
					node.mesh.surface_set_material(i,material)
					node.set_surface_material(i,material)
		if node.material_override:
			node.material_override=node.material_override.duplicate()
		if node.material_overlay:
			node.material_overlay=node.material_overlay.duplicate()
	for child in node.get_children():
		makeHairUnique(child)


var headInstance=null

func loadBlendShapeData():
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")

	var skeleton=$character/root/Skeleton
	if skeleton==null:
		return

	if is_instance_valid(headInstance):
		headInstance.queue_free()

	var head=load("res://world/player/human/"+stats.sex+"/Head0.tscn")
	if head:
		headInstance=head.instance()
		headInstance.name="Head"
		skeleton.add_child(headInstance)

	yield(get_tree(),"idle_frame")

	var file=File.new()
	if !file.file_exists("user://button_list.save"):
		return

	if file.open("user://button_list.save",File.READ)!=OK:
		return

	var data=file.get_var()
	file.close()

	if typeof(data)!=TYPE_DICTIONARY:
		return

	if !data.has("blend_shapes") or !data["blend_shapes"].has(entity_name):
		return

	var shapes=data["blend_shapes"][entity_name]

	if typeof(shapes)!=TYPE_DICTIONARY:
		return

	var meshes=[]
	findBlendMeshes(skeleton,meshes)

	for key in shapes:
		var parts=str(key).split("_",false,1)

		if parts.size()!=2:
			continue

		var bodyPart=parts[0]
		var shape=parts[1]
		var value=float(shapes[key])

		for mesh in meshes:
			var isHead="head" in mesh.name.to_lower()

			if bodyPart=="Head" and !isHead:
				continue
			if bodyPart=="Body" and isHead:
				continue

			for i in range(mesh.mesh.get_blend_shape_count()):
				if mesh.mesh.get_blend_shape_name(i)==shape:
					mesh.set("blend_shapes/"+shape,value)
					break
func findBlendMeshes(node,meshes):
	if node is MeshInstance and node.mesh and node.mesh.get_blend_shape_count()>0:
		meshes.append(node)

	for child in node.get_children():
		findBlendMeshes(child,meshes)


func loadEyeData():
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")

	if !is_instance_valid(headInstance):
		return

	var file=File.new()
	if !file.file_exists("user://button_list.save"):
		return
	if file.open("user://button_list.save",File.READ)!=OK:
		return

	var data=file.get_var()
	file.close()

	if typeof(data)!=TYPE_DICTIONARY:
		return
	if !data.has("eye_colors"):
		return
	if typeof(data["eye_colors"])!=TYPE_DICTIONARY:
		return
	if !data["eye_colors"].has(entity_name):
		return

	var eyes=data["eye_colors"][entity_name]

	if typeof(eyes)!=TYPE_DICTIONARY:
		return

	var mesh:MeshInstance=null

	if headInstance is MeshInstance:
		mesh=headInstance
	else:
		for child in headInstance.get_children():
			if child is MeshInstance:
				mesh=child
				break

	if mesh==null:
		return

	var material_path="res://world/player/human/"+stats.sex+"/materials/Head0.tres"
	var material=load(material_path)

	if !(material is ShaderMaterial):
		return

	material=material.duplicate()
	material.set_shader_param("eye_left_color",eyes.get("left",Color.white))
	material.set_shader_param("eye_right_color",eyes.get("right",Color.white))

	for i in range(mesh.get_surface_material_count()):
		mesh.set_surface_material(i,material)





func applyHairColorRecursive(node:Node,color:Color):
	if node is MeshInstance:
		if node.material_override:
			node.material_override=node.material_override.duplicate()
			node.material_override.albedo_color=color

		if node.material_overlay:
			node.material_overlay=node.material_overlay.duplicate()
			node.material_overlay.albedo_color=color

		for i in range(node.mesh.get_surface_count() if node.mesh else 0):
			var material=node.get_surface_material(i)
			if material==null and node.mesh:
				material=node.mesh.surface_get_material(i)
			if material:
				material=material.duplicate()
				material.albedo_color=color
				node.set_surface_material(i,material)
	for child in node.get_children():
		applyHairColorRecursive(child,color)
func applyHairTextureRecursive(node:Node,texture:Texture):
	if node is MeshInstance:
		if node.material_override:
			node.material_override=node.material_override.duplicate()
			node.material_override.albedo_texture=texture

		if node.material_overlay:
			node.material_overlay=node.material_overlay.duplicate()
			node.material_overlay.albedo_texture=texture

		if node.mesh:
			for i in range(node.mesh.get_surface_count()):
				var material=node.get_surface_material(i)
				if material==null:
					material=node.mesh.surface_get_material(i)
				if material:
					material=material.duplicate()
					material.albedo_texture=texture
					node.mesh.surface_set_material(i,material)
					node.set_surface_material(i,material)

	for child in node.get_children():
		applyHairTextureRecursive(child,texture)


