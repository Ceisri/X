extends KinematicBody #NPC/Mob Script this node is is_in_group("Entity"), this node is child of another spatial that contains the words Spawner or Spawnpoint, Spawn spatials are direct children of the map root


onready var animation_tree:AnimationTree = $AnimationTree

onready var flinch_anim = animation_tree.tree_root.get_node("Flinch")
onready var stats = $Stats
onready var ray_down = $RayDown
onready var anim_calls = $AnimationCalls
var creator:KinematicBody = null setget _set_creator

func _set_creator(value):
	creator = value
	if creator != null and is_instance_valid(creator):
		shareAggro(creator)
		getAggroFromOtherMob(creator)

func addSelfToCreator()->void:
	if creator==null:return
	if creator.spawned_bodies==null:creator.spawned_bodies=[]
	if creator.spawned_bodies.has(self):return
	creator.spawned_bodies.append(self)
	shareAggro(creator)
	getAggroFromOtherMob(creator)
var spawned_bodies:Array = []
var current_skill:String 
var is_dead:bool = false
var just_loaded_dead_grace:int = 0
var is_in_combat:bool = false
var is_being_carried:bool = false
var last_anim_lock_time:int = 0
var anim_lock_delay_ms:int = 500
var vertical_velocity:Vector3 = Vector3.ZERO
export var gravity:float = 9.8
export var max_fall_speed:float = 40.0
puppet var net_translation := Vector3() setget _set_net_translation
puppet var net_rotation_y := 0.0
puppet var net_movement_mode := "idle"
puppet var net_current_skill := ""
puppet var net_active_lock := -1
puppet var net_is_dead := false

export var mob_sync_rate := 0.1
export var puppet_lerp_speed := 10.0
var _mob_sync_timer := 0.0
var _has_received_mob_sync := false

func _set_net_translation(value):
	_has_received_mob_sync = true
	net_translation = value


func applyGravity(delta:float)->void:
	var collision_shape:CollisionShape=$CollisionShape
	if !collision_shape.disabled:
		if is_on_floor():
			vertical_velocity=Vector3.DOWN*0.5
		else:
			vertical_velocity+=Vector3.DOWN*gravity*2.0*delta
			if vertical_velocity.length()>max_fall_speed:
				vertical_velocity=vertical_velocity.normalized()*max_fall_speed

enum Lock {
	ATK1,
	ATK2,
	ATK3,
	ATK4,
	ATK5,
	ATK6,
	ATK7,
	GUARD,
	GUARD_REACT,
	PARRY,
	DIE,
	FLINCH,
	FLINCH_BACK,
	KNOCKED_DOWN,
	KNOCKED_BACK,
	DOWNED,
}

var anim_locks := []

func _ready_anim_locks() -> void:
	anim_locks.resize(Lock.size())
	for i in range(anim_locks.size()):
		anim_locks[i] = false


var _sync_offset:int = 0
func _ready()->void:
	if get_tree().network_peer != null:
		set_network_master(1, true)
		if stats.isAuthority():
			get_tree().connect("network_peer_connected", self, "_onPeerConnectedSyncMob")
	visible = true
	_ready_anim_locks()
	var node=get_parent()
	while node:
		if node is Spatial and (node.name.to_lower()=="spawnpoint" or node.name.to_lower().find("spawnpoint")!=-1 or node.is_in_group("spawnpoint")):
			spawn_point=node
			break
		node=node.get_parent()
	cacheEntities()
	randomize()
	spawn_point = get_parent()
	random_interval = int(rand_range(2,5))
	ignoreMobBodies()
	addSelfToCreator()
	vis_notifier.connect("screen_exited",self,"screenExited")
	vis_notifier.connect("screen_entered",self,"screenEntered")
	# dedicated server has no camera/viewport driving VisibilityNotifier, so
	# is_on_screen() is always false there -- and screenEntered/screenExited
	# both early-return on the server, so `sleeping` would otherwise get
	# stuck true forever, permanently failing _computeRelevance() and
	# freezing every mob that isn't already in combat.
	if get_tree().network_peer != null and get_tree().is_network_server():
		sleeping = false
	else:
		sleeping = !vis_notifier.is_on_screen()
	_is_relevant = _computeRelevance()
	if _is_relevant and is_instance_valid(CommonBehaviours):
		CommonBehaviours.markActive(self)
	is_in_combat = false
	_sync_offset = int(rand_range(0, 600))


onready var vis_notifier =  $VisibilityNotifier
var sleeping=false
var _printed_moving := false



#
#func _physics_process(delta)->void:
#	if get_tree().network_peer != null and not is_network_master():
#		_applyMobPuppetState(delta)
#		return
#
#	var frame = Engine.get_physics_frames() + _sync_offset
#	var active_lock = getActiveAnimLock()
#	if frame % 600 == 0:
#		respawn()
#	if frame % max(_current_relevance_interval, 1) == 0:
#		_is_relevant = _computeRelevance()
#		applyGravity(delta)
#		#from here
#		animLockOrder()
#		syncAnimLockAnimation(active_lock)
#		setCurrentSkillBasedOnSpecies(active_lock)
#		#to here is all combat stuff but still required to avoid desyncs where the mob
#		#keeps launching the wrong attacks and sometimes even the same attack over and over again
#		#but still, skip those 3 functions if there's no target
#	if !_is_relevant:
#		return
#
#	if frame % 120 == 0:
#		if anim_locks[Lock.DIE] == true:
#			anim_locks[Lock.DIE] = false
#			animation_tree.active = false
#	if frame % 60 == 0:
#		cleanIframes()
#		unstuck()
#		updateCooldowns()
#		decayAggroWhileRunning()
#	if frame % 30 == 0:
#		if creator != null:
#			shareAggro(creator)
#			getAggroFromOtherMob(creator)
#	if frame % 2 == 0:
#		movementanimation()
#		if is_dead == false and stats.health > 0:
#			if target == null:
#				animation_tree.active = true
#			switchState(delta, active_lock)


#freeze the AnimationTree itself when a mob drops out of relevance.
# Right now !_is_relevant only skips switchState/combat/movementanimation --
# animation_tree.active stays whatever it last was, so frozen/offscreen mobs
# keep advancing skeletal animation (skinning cost) every frame for nothing.
# This is the single biggest offline win at high mob counts: 30 active mobs
# each still animating even while "frozen" is most of your CPU/GPU cost.

func _physics_process(delta)->void:
	if get_tree().network_peer != null and not is_network_master():
		_applyMobPuppetState(delta)
		return

	var frame = Engine.get_physics_frames() + _sync_offset
	var active_lock = getActiveAnimLock()
	var is_dying_playback = stats.health <= 0 and !is_dead

	if stats.health <= 0 and (target != null or !targets.empty()):
		clearAggro()
	if stats.health <= 0 and !is_dead and !_is_relevant:
		_is_relevant = true
		if is_instance_valid(CommonBehaviours):
			CommonBehaviours.markActive(self)

	if frame % 600 == 0:
		respawn()

	if frame % max(_current_relevance_interval, 1) == 0:
		var was_relevant = _is_relevant
		_is_relevant = _computeRelevance()
		if was_relevant != _is_relevant and is_instance_valid(CommonBehaviours):
			if _is_relevant:
				CommonBehaviours.markActive(self)
			else:
				CommonBehaviours.markInactive(self)

		applyGravity(delta)
		# ONLINE FIX -- this used to only run "if target != null", but
		# clearAggro() now nulls target the instant health hits 0, which
		# meant animLockOrder() (the thing that actually flips
		# animation_tree.active and drives the death sequence) never ran
		# again after death -- the mob just froze in whatever pose it had
		# a moment before dying. Also cover the dying-but-not-yet-dead window.
		if target != null or is_dying_playback:
			animLockOrder()
			syncAnimLockAnimation(active_lock)
			setCurrentSkillBasedOnSpecies(active_lock)

	if !_is_relevant and !is_dying_playback:
		applyGravity(delta)
		if !is_on_floor():
			move_and_slide(vertical_velocity, Vector3.UP)
		if animation_tree.active:
			animation_tree.active = false
		return

	if !animation_tree.active and !is_dead and (target != null or stats.health > 0):
		animation_tree.active = true

	if frame % 120 == 0:
		if anim_locks[Lock.DIE] == true:
			anim_locks[Lock.DIE] = false
			animation_tree.active = false
	if frame % max(_getAiTickInterval(), 1) == 0:
		cleanIframes()
		unstuck()
		updateCooldowns()
		decayAggroWhileRunning()
	if frame % 30 == 0:
		if creator != null:
			shareAggro(creator)
			getAggroFromOtherMob(creator)
	if frame % _getAiTickInterval() == 0:
		movementanimation()
		if is_dead == false and stats.health > 0:
			if target == null:
				animation_tree.active = true
			switchState(delta, active_lock)


func _getAiTickInterval() -> int:
	var active_count = CommonBehaviours.getActiveMobCount() if is_instance_valid(CommonBehaviours) else 1
	if active_count <= 12:
		return 2
	elif active_count <= 24:
		return 3
	elif active_count <= 40:
		return 4
	else:
		return 6


func _exit_tree() -> void:
	if _is_relevant and is_instance_valid(CommonBehaviours):
		CommonBehaviours.markInactive(self)









func screenEntered():
	if get_tree().network_peer != null and get_tree().is_network_server():
		return # server has no camera/viewport driving VisibilityNotifier -- ignore
	sleeping=false
	_is_relevant = _computeRelevance()

func screenExited():
	if get_tree().network_peer != null and get_tree().is_network_server():
		return # server has no camera/viewport driving VisibilityNotifier -- ignore
	sleeping=true
	_is_relevant = _computeRelevance()
		





remote func applyBruteForceSync(pos:Vector3, rot_y:float, mode:String, skill:String, lock:int, dead:bool) -> void:
	_has_received_mob_sync = true
	net_translation = pos
	net_rotation_y = rot_y
	net_movement_mode = mode
	net_current_skill = skill
	net_active_lock = lock
	net_is_dead = dead

remote func applyBruteForceCombatSync(cooldowns:Dictionary, aggro_list:Array) -> void:
	net_skill_cooldowns = cooldowns.duplicate()
	net_aggro_list = aggro_list.duplicate()
	skill_cooldowns = net_skill_cooldowns

# builds the array net_aggro_list/applyBruteForceCombatSync expects --
# nothing ever populated this before, so displayAggro() on puppets
# always showed empty
func buildAggroSnapshotForSync() -> Array:
	var snapshot := []
	for aggro_target in targets:
		if !is_instance_valid(aggro_target.target_entity):
			continue

		var entity_name := "?"
		if "entity_name" in aggro_target.target_entity:
			entity_name = aggro_target.target_entity.entity_name

		snapshot.append({
			"name": aggro_target.target_entity.name,
			"entity_name": entity_name,
			"aggro": aggro_target.aggro,
			"time": aggro_target.last_aggro_time
		})

	return snapshot















func _applyMobPuppetState(delta:float) -> void:
	if !_has_received_mob_sync:
		return

	animation_tree.active = true

	global_transform.origin = global_transform.origin.linear_interpolate(net_translation, delta * puppet_lerp_speed)
	rotation.y = lerp_angle(rotation.y, net_rotation_y, delta * puppet_lerp_speed)

	movement_mode = net_movement_mode
	current_skill = net_current_skill
	is_dead = net_is_dead

	for i in range(anim_locks.size()):
		anim_locks[i] = false
	if net_active_lock >= 0 and net_active_lock < anim_locks.size():
		anim_locks[net_active_lock] = true

	var active := getActiveAnimLock()
	setCurrentSkillBasedOnSpecies(active)
	animLockOrder()
	syncAnimLockAnimation(active)
	movementanimation()

	if active >= Lock.ATK1 and active <= Lock.ATK7:
		animation_tree.set("parameters/Interraction/blend_amount", 1)
	else:
		animation_tree.set("parameters/Interraction/blend_amount", 0)

	if is_dead:
		animation_tree.set("parameters/IsAlive/blend_amount", 1)
var can_move:bool = true
var _anim_param_cache := {}
func setAnimParam(path:String, value) -> void:
	if _anim_param_cache.get(path) == value:
		return
	_anim_param_cache[path] = value
	animation_tree.set(path, value)


func animLockOrder()->void:
	if stats.health <=0:
		stats.getReleased()
		setAnimParam("parameters/IsAlive/blend_amount",1)
		can_move = false
		if is_dead == false or just_loaded_dead_grace > 0:
			animation_tree.active = true
			if just_loaded_dead_grace > 0:
				just_loaded_dead_grace -= 1
		else:
			animation_tree.active = false
	else:
		setAnimParam("parameters/IsAlive/blend_amount",0)
		if anim_locks[Lock.KNOCKED_DOWN] == true:
			setAnimParam("parameters/Interuption/blend_amount",1)
			setAnimParam("parameters/React/blend_amount",0)
			can_move = false
		elif anim_locks[Lock.KNOCKED_BACK] == true:
			setAnimParam("parameters/Interuption/blend_amount",1)
			setAnimParam("parameters/React/blend_amount",-1)
			can_move = false
		elif anim_locks[Lock.FLINCH] == true:
			setAnimParam("parameters/Interuption/blend_amount",1)
			setAnimParam("parameters/React/blend_amount",1)
			can_move = false
		else:
			setAnimParam("parameters/Interuption/blend_amount",0)
			can_move = true
	if movement_mode == "run":
		setAnimParam("parameters/Interuption/blend_amount",0)
		setAnimParam("parameters/Interraction/blend_amount",0)
		setAnimParam("parameters/Movement/blend_amount",1)
		anim_locks[Lock.KNOCKED_DOWN] = false
		anim_locks[Lock.KNOCKED_BACK] = false
		anim_locks[Lock.FLINCH] = false
		anim_locks[Lock.FLINCH_BACK] = false
		can_move = true
var cached_spawnpoints = []

var _cached_world:Node = null
func getMyWorld():
	if _cached_world != null and is_instance_valid(_cached_world):
		return _cached_world
	var node = get_parent()
	while node:
		if "world_id" in node:
			_cached_world = node
			return node
		node = node.get_parent()
	return null

func cacheEntities()->void:
	var my_world = getMyWorld()
	if my_world != null and my_world.has_method("getCachedEntities"):
		cached_entities = my_world.getCachedEntities()
		return
	cached_entities.clear()
	for e in get_tree().get_nodes_in_group("Entity"):
		if is_instance_valid(e) and _isUnderWorld(e, my_world):
			cached_entities.append(e)

func _isUnderWorld(node, world) -> bool:
	if world == null:
		return false # unresolved world context -- exclude, don't leak every map's spawnpoints/entities
	var n = node
	while n:
		if n == world:
			return true
		n = n.get_parent()
	return false
	


var respawn_time:float = 3
export var max_respawn_time:float =6
export var can_respawn:bool = true
var respawn_id:int = 0

func respawn()->void:
	if stats.health >0:
		return
	if is_dead == true:
		respawn_time -= 1
		clearAggro()
		resetCooldowns()
	if respawn_time <= 0:
		if can_respawn:
			respawn_id += 1
			is_dead = false
			animation_tree.set("parameters/IsAlive/blend_amount",0)
			animation_tree.set("parameters/Interuption/blend_amount",0)
			animation_tree.set("parameters/Interraction/blend_amount",0)
			stats.health = stats.max_health
			stats.arcane = stats.max_arcane
			stats.energy = stats.max_energy
			respawn_time = max_respawn_time
			clearAggro()
			resetCooldowns()
			is_in_combat = false
			can_move = true

			if spawn_point and is_instance_valid(spawn_point):
				var spawn_pos=spawn_point.global_transform.origin
				global_transform.origin=Vector3(spawn_pos.x+rand_range(-5,5),spawn_pos.y+0.5,spawn_pos.z+rand_range(-5,5))
		else:
			queue_free()

export var root_motion_compensation = 0.01 
func rootMotion(delta)->Vector3:
	var motion = animation_tree.get_root_motion_transform().origin
	motion.y = 0.0
	if motion.length_squared() < 0.000001:return Vector3.ZERO
	motion = global_transform.basis.xform(motion)
	return motion * root_motion_compensation  / delta


#_______________________________________________________________________________________________________________________________________________________
#_______________________________________________________________________________________________________________________________________________________
#_______________________________________________________________________________________________________________________________________________________
#_________________________COMBAT SEQUENCE AND ANIMATION_________________________________________________________________________________________________
#_______________________________________________________________________________________________________________________________________________________
#_______________________________________________________________________________________________________________________________________________________
#NOTE FOR FUTURE SELF
#to collapse this entire thing into something easier, managed to get this to work
#but by coincidence only, castle of glass, prone to breakering
var last_active_skill:String=""	
var skill_cooldowns={}
var attack_pattern=[]
var attack_pattern_index=0
puppet var net_skill_cooldowns := {}   # resource_path -> remaining seconds
puppet var net_aggro_list := []        # [{name, entity_name, aggro, time}, ...]


func resetCooldowns()->void:
	skill_cooldowns.clear()
	attack_waiting=false
	next_attack_time=0
	has_anim_lock=false
	current_skill=""
func getAvailableSkills() -> Array:
	var species = stats.species
	if !Skills.skills_by_species.has(species):return []
	var result = []
	for skill_name in Skills.skills_by_species[species]:
		var skill_res = Skills.skills.get(skill_name, null)
		if skill_res == null:continue
		var path = skill_res.resource_path
		if skill_cooldowns.has(path):continue
		result.append({"skill": skill_name,"cooldown": Skills.getCooldown(path)})

	return result
func startCooldown(skill_name:String) -> void:
	if !Skills.skills.has(skill_name):
		return

	var path = Skills.skills[skill_name].resource_path
	var cd = Skills.getCooldown(path)

	var haste = stats.derived_stats["cooldown_reduction"]
	cd = cd / max(0.01, haste)

	if cd > 0.0:
		skill_cooldowns[path] = cd

func updateCooldowns() -> void:
	var to_remove = []

	for path in skill_cooldowns.keys():
		skill_cooldowns[path] -= 1 

		if skill_cooldowns[path] <= 0.0:
			to_remove.append(path)

	for p in to_remove:
		skill_cooldowns.erase(p)

func sortCooldownDesc(a,b)->bool:
	return a.cooldown>b.cooldown
	
	
func pickNextSkill(entries:Array)->String:
	# Get every skill that is currently available for use.
	# A skill is considered available if:
	# - The species can use it.
	# - It exists in Skills.skills.
	# - It is not currently on cooldown.
	#
	# (entries is now passed in by the caller so it's only
	# computed once per combat tick instead of being rebuilt
	# here every time pickNextSkill is called.)

	# If there are no usable skills at all,
	# return an empty string so the caller
	# knows nothing can be used right now.
	if entries.empty():
		return ""
	# Calculate current health percentage.
	var hp_ratio=float(stats.health)/max(stats.max_health,1.0)
	# We split skills into two groups:
	# support_entries: Skills listed inside Skills.support_skills.
	# normal_entries: Everything else.
	var support_entries=[]
	var normal_entries=[]
	for entry in entries:
		if entry.skill in Skills.support_skills:
			support_entries.append(entry)
		else:
			normal_entries.append(entry)
	# Sort both lists by cooldown descending.
	support_entries.sort_custom(self,"sortCooldownDesc")
	normal_entries.sort_custom(self,"sortCooldownDesc")
	# Critical health behavior: below 30% HP, support is highest priority.
	if hp_ratio<=0.3:
		if !support_entries.empty():
			return support_entries[0].skill
		if !normal_entries.empty():
			return normal_entries[0].skill
		return ""
	# Above 30% HP, gradually increase support skill usage as health decreases.
	if !support_entries.empty():
		var support_chance=int(clamp((1.0-hp_ratio)*100.0,0,100))
		if randi()%100<support_chance:
			return support_entries[0].skill
	# If support was not selected, use the strongest available normal skill.
	if !normal_entries.empty():
		return normal_entries[0].skill
	# If only support skills exist, use the best support skill.
	if !support_entries.empty():
		return support_entries[0].skill
	# Safety fallback.
	return ""


 
onready var animation = $character/AnimationPlayer
onready var skill_anim = animation_tree.tree_root.get_node("Skill")
var random_interval:int = 2
var skill_to_lock := {}
var has_anim_lock = false
var next_attack_time = 0
var attack_waiting = false
var same_skill_uses=0
var previous_skill_name=""

var last_species=""
var last_skill=""
var last_lock=""

func getActiveAnimLock()->int:
	for state in [Lock.DIE, Lock.FLINCH, Lock.FLINCH_BACK, Lock.KNOCKED_DOWN, Lock.KNOCKED_BACK]:
		if anim_locks[state]:return state 
	for i in range(Lock.ATK1, Lock.ATK7+1):
		if anim_locks[i]:return i
	return -1

func setCurrentSkillBasedOnSpecies(active:int)->void:
	var species=stats.species
	if !Skills.skills_by_species.has(species):return

	if active<Lock.ATK1 or active>Lock.ATK7:return

	var index=active-Lock.ATK1
	var skills=Skills.skills_by_species[species]

	if index<0 or index>=skills.size():return

	var skill=skills[index]
	var anim_str="atk"+str(index+1)
	var anim_name=anim_str if animation.has_animation(anim_str) else "atk1"

	if species!=last_species or skill!=last_skill or skill_anim.animation!=anim_name:
		last_species=species
		last_skill=skill
		skill_anim.animation=anim_name


func setSkillAnimation(anim_name:String)->void:
	var final=anim_name if animation.has_animation(anim_name) else "atk1"

	if skill_anim.animation==final:
		skill_anim.animation=""
		animation_tree.active=false
		animation_tree.active=true

	skill_anim.animation=final
	last_skill=final

func syncAnimLockAnimation(active:int)->void:
	if active in [Lock.FLINCH, Lock.FLINCH_BACK, Lock.KNOCKED_DOWN, Lock.KNOCKED_BACK, Lock.DIE]:
		has_anim_lock=false
		attack_waiting=false
		last_lock=""
		for i in range(Lock.ATK1, Lock.ATK7+1):
			anim_locks[i]=false
		return

	if active<Lock.ATK1 or active>Lock.ATK7:return

	var anim_str="atk"+str(active-Lock.ATK1+1)
	var anim_name=anim_str if animation.has_animation(anim_str) else "atk1"

	if anim_name!=last_lock:
		last_lock=anim_name
		skill_anim.animation=""
		skill_anim.animation=anim_name


func combatAnimations()->void:
	if stats.debuff_buffs_active.has("stunned") and float(stats.debuff_buffs_active["stunned"].get("duration",0.0)) > 0.0:
		return
	if stats.health<=0:
		for i in range(anim_locks.size()):
			anim_locks[i]=false
		has_anim_lock=false
		attack_waiting=false
		return
	if anim_locks[Lock.FLINCH] or anim_locks[Lock.FLINCH_BACK] or anim_locks[Lock.KNOCKED_DOWN] or anim_locks[Lock.KNOCKED_BACK] or anim_locks[Lock.DIE]:
		has_anim_lock=false
		attack_waiting=false
		for i in range(Lock.ATK1, Lock.ATK7+1):
			anim_locks[i]=false
		return

	var now=OS.get_ticks_msec()
	if has_anim_lock:return
	if attack_waiting and now<next_attack_time:return
	if now-last_anim_lock_time<anim_lock_delay_ms:return

	for i in range(Lock.ATK1, Lock.ATK7+1):
		anim_locks[i]=false

	var available=getAvailableSkills()
	var skill_name=pickNextSkill(available)
	if skill_name=="":return

	var skill_path=Skills.skills[skill_name].resource_path
	var has_cooldown=Skills.getCooldown(skill_path)>0.0

	if skill_name!=previous_skill_name:
		previous_skill_name=skill_name
		same_skill_uses=0

	same_skill_uses+=1

	if has_cooldown:
		if same_skill_uses>1:
			for entry in available:
				if entry.skill!=skill_name:
					skill_name=entry.skill
					break
			previous_skill_name=skill_name
			same_skill_uses=1
	else:
		if same_skill_uses>3:
			for entry in available:
				if entry.skill!=skill_name:
					skill_name=entry.skill
					break
			previous_skill_name=skill_name
			same_skill_uses=1

	var energy_cost=Skills.getEnergyCost(skill_name)

	if stats.energy<energy_cost:
		for entry in available:
			var candidate_cost=Skills.getEnergyCost(entry.skill)
			if stats.energy>=candidate_cost:
				skill_name=entry.skill
				energy_cost=candidate_cost
				break
		if stats.energy<energy_cost:
			return

	var skills=Skills.skills_by_species[stats.species]
	var index=skills.find(skill_name)
	if index<0:return

	var lock=Lock.ATK1+index
	var anim_name="atk"+str(index+1)

	for i in range(Lock.ATK1, Lock.ATK7+1):
		anim_locks[i]=false
	anim_locks[lock]=true

	stats.energy-=energy_cost
	current_skill=skill_name
	setSkillAnimation(anim_name)

	has_anim_lock=true
	last_anim_lock_time=now
	next_attack_time=now+400
	attack_waiting=true

	animation_tree.active=false
	animation_tree.active=true
	startCooldown(skill_name)
	setAnimationSpeed()

func setAnimationSpeed()->void:
	var skill_scale:float =  stats.derived_stats["attack_speed"] 
	animation_tree.set("parameters/SkillTimeScale/scale", skill_scale)

#_______________________________________________________________________________________________________________________________________________________
#_______________________________________________________________________________________________________________________________________________________
#_______________________________________________________________________________________________________________________________________________________
#_______________________________________________________________________________________________________________________________________________________
#_______________________________________________________________________________________________________________________________________________________
#_______________________________________________________________________________________________________________________________________________________
#_______________________________________________________________________________________________________________________________________________________
func switchState(delta, active_lock:int):
	if stats.health <= 0:
		for i in range(anim_locks.size()):
			if i != Lock.DIE:
				anim_locks[i] = false
		if target != null or !targets.empty():
			clearAggro()
		return
	if (Engine.get_physics_frames() + _sync_offset) % 6 == 0:
		cleanupAggrotargets()
		cleanupDeadAggro()
	var highest = findHighestAggro()
	if highest:
		target = highest.target_entity
	else:
		target = null

	if target != null and isTargetDownedOrDead(target):
		removeAggroTarget(target)
		target = null
		interruptAttack()

	if target != null:
		checkLeashDistance()

	if target == null:
		wander()
	else:
		combat(delta, active_lock)
		is_in_combat = true
		
		
		
var target_history = []
export var target_delay_frames:int = 10
var delayed_target_pos = Vector3.ZERO
var using_delayed_target = false

var chase_offset = Vector3.ZERO
var last_offset_target = Vector3.ZERO

func updateTargetHistory(target):
	target_history.append(target.global_transform.origin)

	if target_history.size() > target_delay_frames:
		delayed_target_pos = target_history.pop_front()
		using_delayed_target = true


var combat_animation_mode:float = 0
var last_melee_time = 0
export var melee_distance:float = 8
onready var detection_area:Area = $DetectionArea
var reached_melee_time = 0
var resume_chase_time = 0
var melee_entered = true

var side_history = []
export var side_check_frames:int = 30
export var side_dot_threshold:float = 0.6

var flanking = false
var flank_target = Vector3.ZERO
var flank_timeout = 0

export var flank_min_distance: float = 12.0
export var flank_max_distance: float = 32.0
func checkSides():
	if target == null:
		side_history.clear()
		return false

	var to_target = target.global_transform.origin - global_transform.origin
	to_target.y = 0

	if to_target.length_squared() < 0.001:
		side_history.clear()
		return false

	to_target = to_target.normalized()

	var forward = -global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()

	var dot = abs(forward.dot(to_target))

	side_history.append(dot < side_dot_threshold)

	if side_history.size() > side_check_frames:
		side_history.pop_front()

	if side_history.size() < side_check_frames:
		return false

	for value in side_history:
		if !value:
			return false

	side_history.clear()
	return true

var walk_timer := 0.0
var _cached_in_detection := false
func combat(delta, active_lock:int):
	if stats.health <= 0:
		for i in range(anim_locks.size()):
			if i != Lock.DIE:
				anim_locks[i] = false
		return
	if stats.debuff_buffs_active.has("stunned") and float(stats.debuff_buffs_active["stunned"].get("duration",0.0)) > 0.0:
		return
	if target == null:
		target_history.clear()
		using_delayed_target = false
		movement_mode = "idle"
		melee_entered = false
		chase_offset = Vector3.ZERO
		last_offset_target = Vector3.ZERO
		return
	stuckDetection(active_lock)
	updateTargetHistory(target)

	var origin = global_transform.origin
	var real_target = target.global_transform.origin
	var distance_to_target = origin.distance_to(real_target)
	var move_target = real_target

	var has_lock = false
	for i in range(anim_locks.size()):
		if anim_locks[i]:
			has_lock = true
			break

	if (Engine.get_physics_frames() + _sync_offset) % 4 == 0:
		_cached_in_detection = false
		for body in detection_area.get_overlapping_bodies():
			if body == target and !has_lock:
				_cached_in_detection = true
				break
	var in_detection = _cached_in_detection

	if !in_detection and distance_to_target > melee_distance and using_delayed_target:
		if chase_offset == Vector3.ZERO or last_offset_target.distance_to(delayed_target_pos) > 3.0:
			last_offset_target = delayed_target_pos
			chase_offset = Vector3(rand_range(-5,5),0,rand_range(-5,5))

		move_target = applySeparation(delayed_target_pos + chase_offset)
	else:
		chase_offset = Vector3.ZERO
		last_offset_target = Vector3.ZERO
		move_target = real_target


	if in_detection:
		if !melee_entered:
			melee_entered = true

			for i in range(anim_locks.size()):
				anim_locks[i] = false

			has_anim_lock = false

			setAnimParam("parameters/Interuption/blend_amount",0)
			animation_tree.set("parameters/InteruptionSeek/seek_position",0)
			animation_tree.set("parameters/InteruptionOneShot/active",false)

		reached_melee_time = OS.get_ticks_msec()
		resume_chase_time = reached_melee_time + 700
		movement_mode = "idle"

		if !has_lock:
			rotateToTargetMelee(delta,real_target)

		combatAnimations()
		setAnimParam("parameters/Interraction/blend_amount",1)

		if animation_tree.active and can_move:
			var velocity = rootMotion(delta)

			if velocity != Vector3.ZERO:
				move_and_slide(velocity, Vector3.UP)

		return

	melee_entered = false

	if has_lock:
		movement_mode = "idle"
		setAnimParam("parameters/Interraction/blend_amount",1)

		if can_move:
			var velocity = rootMotion(delta)

			if velocity != Vector3.ZERO:
				move_and_slide(velocity, Vector3.UP)

		return

	animation_tree.active = stats.health >0
	if is_dead == false:
		animation_tree.active = true
	setAnimParam("parameters/Interraction/blend_amount",0)
	# ----------------------------
	# FLANKING LOGIC
	# ----------------------------

	if !flanking:
		if checkSides():
			flanking = true
			flank_timeout = OS.get_ticks_msec() + 2500

			var dir = Vector3(rand_range(-1,1), 0, rand_range(-1,1)).normalized()
			flank_target = origin + dir * rand_range(flank_min_distance, flank_max_distance)

	if flanking:
		move_target = flank_target

		if origin.distance_to(flank_target) < 1.0:
			flanking = false
		elif OS.get_ticks_msec() > flank_timeout:
			flanking = false

	# ----------------------------
	# CHASE OFFSET / DELAY LOGIC (only if NOT flanking)
	# ----------------------------
	if !flanking:
		if !in_detection and distance_to_target > melee_distance and using_delayed_target:

			if chase_offset == Vector3.ZERO or last_offset_target.distance_to(delayed_target_pos) > 3.0:
				last_offset_target = delayed_target_pos
				chase_offset = Vector3(rand_range(-5,5), 0, rand_range(-5,5))

			move_target = applySeparation(delayed_target_pos + chase_offset)
		else:
			chase_offset = Vector3.ZERO
			last_offset_target = Vector3.ZERO
			move_target = real_target

	# ----------------------------
	rotateToTarget(delta,move_target)

	var direction = move_target - origin
	direction.y = 0

	if direction.length_squared() <= 0.001:
		movement_mode = "idle"
		return

	stats.getReleased()
	var close_threshold = melee_distance * 0.6
	var is_close = distance_to_target <= close_threshold

	if !is_close:
		walk_timer = 0.17

	if walk_timer > 0.0:
		walk_timer -= delta
		movement_mode = "run"
		move_and_slide_with_snap(direction.normalized() * stats.run_speed + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)

	else:
		movement_mode = "walk"
		move_and_slide_with_snap(direction.normalized() * stats.walk_speed + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)



var _separation_result := Vector3.ZERO
var _separation_next_frame := 0
export var separation_recalc_interval := 6

func applySeparation(base_target:Vector3) -> Vector3:
	var frame = Engine.get_physics_frames()
	if frame < _separation_next_frame:
		return _separation_result
	_separation_next_frame = frame + separation_recalc_interval

	var result = base_target
	var target_position = result
	target_position.y = 0

	for node in cached_entities:
		if !is_instance_valid(node) or node == self or !(node is KinematicBody):
			continue
		var npc_position = node.global_transform.origin
		npc_position.y = 0
		if npc_position.distance_squared_to(target_position) < 2.25:
			var separation = target_position - npc_position
			if separation.length_squared() < 0.0001:
				separation = Vector3(rand_range(-1,1), 0, rand_range(-1,1))
			separation = separation.normalized()
			result += separation * 3.0

	_separation_result = result
	return result









func isTargetDownedOrDead(t) -> bool:
	if t == null or !is_instance_valid(t):
		return true
	if t.has_node("Stats") and t.get_node("Stats").health <= 0:
		return true
	if "is_downed" in t and t.is_downed:
		return true
	if "is_dead" in t and t.is_dead:
		return true
	return false

func interruptAttack() -> void:
	for i in range(Lock.ATK1, Lock.ATK7+1):
		anim_locks[i] = false
	has_anim_lock = false
	attack_waiting = false
	setAnimParam("parameters/Interraction/blend_amount", 0)
	animation_tree.active = false
	animation_tree.active = true


var anim_lock_started_time = 0
var tracked_anim_lock = -1
export var max_stuck_time = 5000
func stuckDetection(active_anim_lock:int):
	if active_anim_lock==-1:
		tracked_anim_lock=-1
		anim_lock_started_time=0
		return

	var time_to_stop=1000 if (active_anim_lock==Lock.FLINCH or active_anim_lock==Lock.FLINCH_BACK) else max_stuck_time

	if tracked_anim_lock!=active_anim_lock:
		tracked_anim_lock=active_anim_lock
		anim_lock_started_time=OS.get_ticks_msec()
		return

	if OS.get_ticks_msec()-anim_lock_started_time<time_to_stop:
		return

	for i in range(anim_locks.size()):
		anim_locks[i] = false

	has_anim_lock = false
	attack_waiting = false
	tracked_anim_lock = -1
	anim_lock_started_time = 0

	animation_tree.active = stats.health > 0
	setAnimParam("parameters/Interuption/blend_amount",0)
	setAnimParam("parameters/Interraction/blend_amount",0)
	animation_tree.set("parameters/InteruptionOneShot/active",false) # one-shot trigger, not a cacheable blend value

	if target == null:
		movement_mode = "idle"
	else:
		movement_mode = "run"
func has_any_anim_lock() -> bool:
	for i in range(anim_locks.size()):
		if anim_locks[i]:
			return true
	return false
	
	
	
	
var anim_blend_cache := {}

	
onready var dmg_area = $AreaDamage
var turn_speed:float = 3.0
var run_turn_speed:float = 6.0
func rotateToTargetMelee(speed:float,target_pos:Vector3):
	var origin = global_transform.origin

	var direction = target_pos - origin
	direction.y = 0

	if direction.length_squared() <= 0.001:
		turn_anim = ""
		return

	direction = direction.normalized()

	var look_pos = origin - direction
	look_pos.y = origin.y

	var target_transform = global_transform.looking_at(look_pos, Vector3.UP)

	var current_turn_speed = turn_speed
	if movement_mode == "run":
		current_turn_speed = run_turn_speed

	global_transform.basis = global_transform.basis.slerp(target_transform.basis,speed * current_turn_speed)

	var forward = -global_transform.basis.z.normalized()
	forward.y = 0

	var angle = forward.angle_to(direction)

	var yaw = rotation.y
	var delta = wrapf(yaw - last_yaw, -PI, PI)

	if angle > deg2rad(15):
		if delta > 0:
			turn_anim = "turn_l"
		else:
			turn_anim = "turn_r"
	else:
		turn_anim = ""

	last_yaw = yaw
func rotateToTarget(speed:float,target_pos:Vector3):

	var origin = global_transform.origin

	var direction = target_pos - origin
	direction.y = 0

	if direction.length_squared() <= 0.001:
		return

	direction = direction.normalized()

	var look_pos = origin - direction
	look_pos.y = origin.y

	var target_transform = global_transform.looking_at(look_pos,Vector3.UP)

	var current_turn_speed = turn_speed

	if movement_mode == "run":
		current_turn_speed = run_turn_speed

	global_transform.basis = global_transform.basis.slerp(target_transform.basis,speed * current_turn_speed)

	var forward = -global_transform.basis.z.normalized()
	forward.y = 0



#_________________________________MOVEMENT______________________________________
var wander_dir := Vector3.ZERO
var wander_dir_next_change := 0
export var max_wander_distance:=50.0
export var return_distance:=25.0

var spawn_point:Spatial
var returning_to_spawn=false
func movementanimation():
	match movement_mode:
		"idle":
			setAnimParam("parameters/Movement/blend_amount", -1)
		"walk":
			setAnimParam("parameters/Interraction/blend_amount", 0)
			setAnimParam("parameters/Movement/blend_amount", 0)
		"run":
			setAnimParam("parameters/Interraction/blend_amount", 0)
			setAnimParam("parameters/Movement/blend_amount", 1)
func checkLeashDistance()->void:
	if hyper_aggressive:
		return
	if target==null:
		return

	var anchor:Vector3
	if creator!=null and is_instance_valid(creator):
		anchor=creator.global_transform.origin
	elif spawn_point and is_instance_valid(spawn_point):
		anchor=spawn_point.global_transform.origin
	else:
		return

	if !is_instance_valid(target):
		return

	var target_pos=target.global_transform.origin
	if anchor.distance_to(target_pos)>max_wander_distance:
		removeAggroTarget(target)
export var leash_return_teleport_time:float = 8000.0 # ms spent walking back before we give up and teleport
var returning_to_spawn_start_time:int = 0
var returning_to_creator:bool = false
var returning_to_creator_start_time:int = 0
var wander_target_start_time:int = 0
func wander():
	if stats.debuff_buffs_active.has("stunned") and float(stats.debuff_buffs_active["stunned"].get("duration",0.0)) > 0.0:
		return
	if Engine.get_physics_frames() % 35 == 0:
		stats.regenerations()
	is_in_combat=false
	animation_tree.set("parameters/Interraction/blend_amount",0)

	# Handle idle/walk-stop state switching.
	updateState()

	if get_meta("is_stopped"):
		movement_mode="idle"
		animation_tree.set("parameters/Movement/blend_amount",-1)
		return

	# Randomly switch between walking and running.
	movementStateSwitch()

	var time=Engine.get_physics_frames()

	# When this mob has a creator:
	# Instead of wandering in arbitrary directions,
	# periodically pick a random position around the creator
	# and walk toward it.
	if creator!=null and is_instance_valid(creator):
		if wander_target==Vector3.ZERO or time>=wander_dir_next_change:
			var angle=rand_range(0,PI*2.0)
			var radius=rand_range(3.0,12.0)
			wander_target=creator.global_transform.origin+Vector3(cos(angle)*radius,0,sin(angle)*radius)
			wander_dir_next_change=time+int(rand_range(60,180))
			wander_target_start_time=OS.get_ticks_msec()

		var dir=wander_target-global_transform.origin
		dir.y=0

		if dir.length()<1.5:
			wander_target=Vector3.ZERO
			wander_target_start_time=0
			return

		if OS.get_ticks_msec()-wander_target_start_time>=leash_return_teleport_time:
			var creator_pos=creator.global_transform.origin
			global_transform.origin=Vector3(creator_pos.x+rand_range(-5,5),creator_pos.y+0.5,creator_pos.z+rand_range(-5,5))
			wander_target=Vector3.ZERO
			wander_target_start_time=0
			return

		dir=dir.normalized()

		set_meta("dir",-dir)
		rotateMob()

		if nav_path.size()>0:
			moveforward()
			return

		# Force run speed + run animation state so it doesn't look like sliding.
		movement_mode="run"
		animation_tree.set("parameters/Movement/blend_amount",1)
		move_and_slide_with_snap(dir*stats.run_speed + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)

		return
	if spawn_point and is_instance_valid(spawn_point):
		var dir=spawn_point.global_transform.origin-global_transform.origin
		dir.y=0
		var dist=dir.length()

		if returning_to_spawn:
			if dist<=return_distance:
				returning_to_spawn=false
				returning_to_spawn_start_time=0
			else:
				if returning_to_spawn_start_time==0:
					returning_to_spawn_start_time=OS.get_ticks_msec()
				elif OS.get_ticks_msec()-returning_to_spawn_start_time>=leash_return_teleport_time:
					var spawn_pos=spawn_point.global_transform.origin
					global_transform.origin=Vector3(spawn_pos.x+rand_range(-5,5),spawn_pos.y+0.5,spawn_pos.z+rand_range(-5,5))
					returning_to_spawn=false
					returning_to_spawn_start_time=0
					return

				dir=dir.normalized()
				set_meta("dir",-dir)
				rotateMob()

				# Force run speed + run animation state so it doesn't look like sliding.
				movement_mode="run"
				animation_tree.set("parameters/Movement/blend_amount",1)
				move_and_slide_with_snap(dir*stats.run_speed + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)

				return
		elif dist>max_wander_distance:
			returning_to_spawn=true
			returning_to_spawn_start_time=OS.get_ticks_msec()
	# Normal wandering behavior when no creator exists.
	if wander_dir==Vector3.ZERO or time>=wander_dir_next_change:
		wander_dir=Vector3(randf()*2.0-1.0,0,randf()*2.0-1.0)

		if wander_dir.length()<0.01:
			wander_dir=Vector3.FORWARD

		wander_dir=wander_dir.normalized()
		wander_dir_next_change=time+int(rand_range(30,120))

	set_meta("dir",-wander_dir)
	rotateMob()

	if nav_path.size()>0:
		moveforward()
		return

	if movement_mode=="run":
		animation_tree.set("parameters/Movement/blend_amount",1)
		move_and_slide_with_snap(wander_dir * stats.run_speed + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)
	else:
		animation_tree.set("parameters/Movement/blend_amount",0)
		move_and_slide_with_snap(wander_dir * stats.walk_speed + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)
		

func moveforward():
	if nav_path.size() <= 0:
		return
	if nav_index >= nav_path.size():
		nav_path.clear()
		nav_index = 0
		return
	var next_pos = nav_path[nav_index]
	var dir = next_pos - global_transform.origin
	dir.y = 0
	if dir.length() < 1.0:
		nav_index += 1
		return
	dir = dir.normalized()
	set_meta("dir", -dir)
	if movement_mode == "run":
		animation_tree.set("parameters/Movement/blend_amount", 1)
		move_and_slide_with_snap(dir * stats.run_speed + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)
	elif movement_mode == "walk":
		animation_tree.set("parameters/Movement/blend_amount", 0)
		move_and_slide_with_snap(dir * stats.run_speed + vertical_velocity, Vector3.DOWN * 0.3, Vector3.UP, true)
func moveToTarget():
	if !is_instance_valid(target):
		return
	var dir = target.global_transform.origin - global_transform.origin
	dir.y = 0
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	set_meta("dir", -dir)
	rotateMob()
	move_and_slide(dir * stats.run_speed + vertical_velocity, Vector3.UP)
	
	
	
var movement_mode:String = "idle"
var stored_body:KinematicBody = null
var nav_path = []
var nav_index = 0
var wander_target = Vector3.ZERO

func updateState():
	var frames = Engine.get_physics_frames()
	if !has_meta("state_next"):
		set_meta("state_next",frames + int(rand_range(120,600)))
		set_meta("is_stopped",false)
		set_meta("is_moving",true)
		return
	if frames >= get_meta("state_next"):
		var stopped = !get_meta("is_stopped")
		if stopped:
			nav_path.clear()
			nav_index = 0
		else:
			set_meta("next_switch",0)
		set_meta("is_stopped",stopped)
		set_meta("is_moving",!stopped)
		set_meta("state_next",frames + int(rand_range(120,600)))
var last_yaw = 0.0
var turn_anim = ""
var run_turn_anim = ""
func rotateMob():
	var dir = get_meta("dir") if has_meta("dir") else Vector3.ZERO
	if dir == Vector3.ZERO:
		return
	var target_pos = global_transform.origin + dir
	target_pos.y = global_transform.origin.y
	var target_transform = global_transform.looking_at(target_pos,Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_transform.basis,0.1)

func movementStateSwitch():
	var time = OS.get_ticks_msec()
	if !has_meta("move_state_next"):
		set_meta("move_state_next",time + int(rand_range(8500,35000)))
		if randf() <= 0.9:
			movement_mode = "walk"
			animation_tree.set("parameters/Movement/blend_amount", 0)
		else:
			movement_mode = "run"
			animation_tree.set("parameters/Movement/blend_amount", 1)
		return
	if time >= get_meta("move_state_next"):
		set_meta("move_state_next",time + int(rand_range(8500,35000)))
		if randf() <= 0.9:
			movement_mode = "walk"
			animation_tree.set("parameters/Movement/blend_amount", 0)
		else:
			movement_mode = "run"
			animation_tree.set("parameters/Movement/blend_amount", 1)




#______________________________AGGRO MANAGEMENT_________________________________
var target: Node = null
var targets = []
export var hyper_aggressive:bool = true # if false, mob drops aggro entirely when target flees beyond the spawn leash distance
class AggroTarget:
	var target_entity:Node
	var aggro=0
	var last_aggro_time=0
func addAggro(target_entity:Node,amount:int)->AggroTarget:
	if stats.health<=0:
		return getAggro(target_entity)
	sleeping=false
	var aggro_target=getAggro(target_entity)
	aggro_target.aggro+=amount
	aggro_target.last_aggro_time=OS.get_system_time_secs()

	var highest=findHighestAggro()
	target=highest.target_entity if highest and highest.aggro>0 else null

	if creator!=null and is_instance_valid(creator):
		creator.addAggro(target_entity,amount)

	return aggro_target
func setAggroValue(target_entity:Node, amount:float, time:int)->void:
	if target_entity==null or stats.health<=0:return
	var aggro_target=getAggro(target_entity)
	if aggro_target==null:return
	if amount>aggro_target.aggro:
		aggro_target.aggro=amount
		aggro_target.last_aggro_time=time
func shareAggro(with_whom)->void:
	if with_whom==null or !is_instance_valid(with_whom):return
	if stats.health<=0:return

	for aggro_target in targets:
		if !is_instance_valid(aggro_target.target_entity):continue
		with_whom.setAggroValue(aggro_target.target_entity,aggro_target.aggro,aggro_target.last_aggro_time)

func getAggroFromOtherMob(other_mob)->void:
	if other_mob==null or !is_instance_valid(other_mob):return
	if stats.health<=0:return

	for other_aggro in other_mob.targets:
		if !is_instance_valid(other_aggro.target_entity):continue
		setAggroValue(other_aggro.target_entity,other_aggro.aggro,other_aggro.last_aggro_time)

	var highest=findHighestAggro()
	target=highest.target_entity if highest and highest.aggro>0 else null
var _had_target_recently_until := 0 # ms timestamp; keeps relevance alive briefly after losing a target

func clearAggro()->void:
	if target != null:
		_had_target_recently_until = OS.get_ticks_msec() + 5000
	target = null
	targets.clear()
	dead_target_aggro.clear()
	target_history.clear()
	using_delayed_target = false
func removeAggroTarget(target_entity:Node)->void:
	for i in range(targets.size()-1,-1,-1):
		if targets[i].target_entity==target_entity:
			targets.remove(i)
	if target==target_entity:
		target=null
	if dead_target_aggro.has(target_entity):
		dead_target_aggro.erase(target_entity)
export var aggro_drop_distance = 70
export var aggro_decay_per_second:float = 6.0
export var run_aggro_decay:float = 3.0 # extra aggro lost per second on ALL targets while mob is running
export var sustained_run_time_before_percent_decay:float = 25.0 # seconds of uninterrupted running before percent decay kicks in
export var sustained_run_percent_decay:float = 0.6 # % of aggro lost per second once sustained
var uninterrupted_run_time:float = 0.0
func decayAggroWhileRunning()->void:
	if movement_mode != "run":
		uninterrupted_run_time = 0.0
		return

	uninterrupted_run_time += 1.0 # this func runs once per second (called from the % 60 == 0 block)

	for aggro_target in targets:
		if uninterrupted_run_time >= sustained_run_time_before_percent_decay:
			aggro_target.aggro -= aggro_target.aggro * sustained_run_percent_decay
			aggro_target.aggro -= run_aggro_decay

var dead_target_aggro = {}
func cleanupDeadAggro():
	var target_removed := false
	for i in range(targets.size()-1,-1,-1):
		var aggro_target = targets[i]
		if !is_instance_valid(aggro_target.target_entity):
			continue
		if isTargetDownedOrDead(aggro_target.target_entity):
			dead_target_aggro[aggro_target.target_entity] = aggro_target.aggro
			if aggro_target.target_entity == target:
				target_removed = true
			targets.remove(i)
			animation_tree.active = true
			animation_tree.set("parameters/Interraction/blend_amount",0)

	var highest = findHighestAggro()
	target = highest.target_entity if highest and highest.aggro > 0 else null
	if target_removed:
		interruptAttack()
func getAggro(target_entity:Node)->AggroTarget:
	if target_entity == null or target_entity == self:
		return null

	for existing_target in targets:
		if existing_target.target_entity == target_entity:
			return existing_target

	var aggro_target = AggroTarget.new()
	aggro_target.target_entity = target_entity
	aggro_target.last_aggro_time = OS.get_system_time_secs()
	targets.append(aggro_target)
	return aggro_target
func findHighestAggro()->AggroTarget:
	var highest_aggro = 0
	var target : AggroTarget = null

	for aggro_target in targets:
		if aggro_target.target_entity == self:
			continue
		if aggro_target.aggro > highest_aggro:
			target = aggro_target
			highest_aggro = aggro_target.aggro

	return target
func team_aggro():
	var sorted_targets = targets.duplicate()
	sorted_targets.sort_custom(self,"sort_aggro_desc")
	return sorted_targets.slice(0,min(5,sorted_targets.size()))
func sort_aggro_desc(a,b):
	return a.aggro > b.aggro



func cleanupAggrotargets():
	var remaining_targets = []

	for aggro_target in targets:
		if !is_instance_valid(aggro_target.target_entity):
			continue

		var distance = global_transform.origin.distance_to(aggro_target.target_entity.global_transform.origin)

		if distance > aggro_drop_distance:
			aggro_target.aggro -= aggro_decay_per_second * get_physics_process_delta_time()

		if aggro_target.aggro > 0:
			remaining_targets.append(aggro_target)

	targets = remaining_targets


#____________________________DEBUGGING STUFF____________________________________

func displayAnimLocks(label)->void:
	var text="AnimationTree: "+str(animation_tree.active)+"\n\n"

	for i in range(anim_locks.size()):
		if anim_locks[i]:
			text+=Lock.keys()[i]+"\n"

	label.text=text
func displayAggro(label)->void:
	var text=""

	if get_tree().network_peer != null and not is_network_master():
		# Puppets never populate `targets` (that's authority-only aggro
		# tracking against real Node references) -- use the synced
		# net_aggro_list snapshot instead.
		for entry in net_aggro_list:
			var dt=OS.get_datetime_from_unix_time(int(entry.get("time",0)))
			text+=(str(entry.get("name","?")) + " : "+ str(entry.get("entity_name","?"))+" : "+str(round(entry.get("aggro",0)))+" | "+str(dt.hour).pad_zeros(2)+":"+str(dt.minute).pad_zeros(2)+":"+str(dt.second).pad_zeros(2)+" "+str(dt.day).pad_zeros(2)+"/"+str(dt.month).pad_zeros(2)+"/"+str(dt.year)+"\n")
		label.text=text
		return

	for aggro_target in team_aggro():
		if !is_instance_valid(aggro_target.target_entity):continue

		var dt=OS.get_datetime_from_unix_time(aggro_target.last_aggro_time)
		text+=(aggro_target.target_entity.name + " : "+ aggro_target.target_entity.entity_name+" : "+str(round(aggro_target.aggro))+" | "+str(dt.hour).pad_zeros(2)+":"+str(dt.minute).pad_zeros(2)+":"+str(dt.second).pad_zeros(2)+" "+str(dt.day).pad_zeros(2)+"/"+str(dt.month).pad_zeros(2)+"/"+str(dt.year)+"\n")

	label.text=text
	
var was_stuck_there = {"position":Vector3(),"time":0}
var fall_time:float = 0.0
func unstuck()->void:
	if is_dead:
		return
	if !is_on_floor() and !ray_down.is_colliding():
		fall_time += 1
		if fall_time >= 12.0:
			was_stuck_there.position = global_transform.origin
			was_stuck_there.time = OS.get_unix_time()
			if spawn_point and is_instance_valid(spawn_point):
				var spawn_pos = spawn_point.global_transform.origin
				global_transform.origin = Vector3(spawn_pos.x + rand_range(-5,5),spawn_pos.y + 0.5,spawn_pos.z + rand_range(-5,5))
			fall_time = 0.0
	else:
		fall_time = 0.0
		
		
		
var forced_refresh_repetitions=0
var last_forced_refresh_skill=""
var last_forced_refresh_anim=""
var forced_refresh_stuck_counter=0
func forceRefreshCombatAnimation()->void:
	if stats.health<=0:return
	if current_skill=="" or !Skills.skills.has(current_skill):return
	var species=stats.species
	if !Skills.skills_by_species.has(species):return
	var skill_index=Skills.skills_by_species[species].find(current_skill)
	if skill_index<0:return
	var anim_name="atk"+str(skill_index+1)
	if !animation.has_animation(anim_name):
		anim_name="atk1"
	var skill_path=Skills.skills[current_skill].resource_path
	var has_cooldown=Skills.getCooldown(skill_path)>0.0
	var on_cooldown=skill_cooldowns.has(skill_path)
	if current_skill!=last_forced_refresh_skill or anim_name!=last_forced_refresh_anim:
		last_forced_refresh_skill=current_skill
		last_forced_refresh_anim=anim_name
		forced_refresh_repetitions=0
		forced_refresh_stuck_counter=0
		return
	forced_refresh_stuck_counter+=1
	if has_cooldown:
		if on_cooldown:
			forced_refresh_repetitions=999
		else:
			forced_refresh_repetitions+=1
	else:
		forced_refresh_repetitions+=1
	var max_repetitions=0 if has_cooldown else 3
	if forced_refresh_repetitions<=max_repetitions and forced_refresh_stuck_counter<30:
		return
	forced_refresh_repetitions=0
	forced_refresh_stuck_counter=0
	has_anim_lock=false
	attack_waiting=false
	for i in range(Lock.ATK1, Lock.ATK7+1):
		anim_locks[i]=false
	skill_anim.animation=""
	animation.stop(true)
	var available=getAvailableSkills()
	var next_skill=pickNextSkill(available)
	if next_skill=="":
		current_skill=""
		return
	current_skill=next_skill
	skill_index=Skills.skills_by_species[species].find(next_skill)
	if skill_index<0:return
	anim_name="atk"+str(skill_index+1)
	if !animation.has_animation(anim_name):
		anim_name="atk1"
	skill_anim.animation=""
	skill_anim.animation=anim_name
	animation_tree.active=false
	animation_tree.active=true
		
var cached_entities = []

func ignoreMobBodies()->void:
	if is_in_group("Player") or is_in_group("Boss"):
		return

	for body in cached_entities:
		if !is_instance_valid(body) or body == self:
			continue
		if body.has_method("add_collision_exception_with"):
			add_collision_exception_with(body)
			body.add_collision_exception_with(self)


export var activity_range := 170.0       # bigger fallback distance (minimap-style awareness)
export var relevance_check_interval := 25 # physics frames between rechecks 
var _is_relevant := false
func isRelevantForSync() -> bool:
	return _is_relevant

var _warned_no_offline_player := false

#func _getActivePlayers() -> Array:
#	var world = get_parent().get_parent()
#	if !is_instance_valid(world):
#		return []
#	if get_tree().network_peer == null:
#		var p = world.get_node_or_null("Player")
#		if !is_instance_valid(p):
#			if !_warned_no_offline_player:
#				_warned_no_offline_player = true
#				print("NPC: offline player not found under ", world.name, " -- all mobs will stay frozen")
#			return []
#		return [p]
#	var players := []
#	for child in world.get_children():
#		if is_instance_valid(child) and child.is_in_group("Player"):
#			players.append(child)
#	return players
func _getActivePlayers() -> Array:
	var world = getMyWorld()
	if !is_instance_valid(world):
		return []
	if get_tree().network_peer == null:
		var p = world.get_node_or_null("Player")
		if !is_instance_valid(p):
			if !_warned_no_offline_player:
				_warned_no_offline_player = true
				print("NPC: offline player not found under ", world.name, " -- all mobs will stay frozen")
			return []
		return [p]
	var players := []
	for child in world.get_children():
		if is_instance_valid(child) and child.is_in_group("Player"):
			players.append(child)
	return players


export var los_collision_mask := 1 

func _computeRelevance() -> bool:
	if stats.health <= 0 and !is_dead:
		return true
	if OS.get_ticks_msec() < _had_target_recently_until:
		return true

	var nearest_dist := INF
	var nearest_player:Node = null
	for player in _getActivePlayers():
		if !is_instance_valid(player): continue
		var d = global_transform.origin.distance_to(player.global_transform.origin)
		if d < nearest_dist:
			nearest_dist = d
			nearest_player = player

	_current_relevance_interval = relevance_check_interval_near if target != null else _getRelevanceInterval(nearest_dist)

	if target != null:
		return true
	if nearest_dist > activity_range:
		return false
	if sleeping:
		return false

	return _hasLineOfSightTo(nearest_player)

func _hasLineOfSightTo(player:Node) -> bool:
	if !is_instance_valid(player):
		return false
	var space_state = get_world().direct_space_state
	var from = global_transform.origin + Vector3.UP
	var to = player.global_transform.origin + Vector3.UP
	var result = space_state.intersect_ray(from, to, [self, player], los_collision_mask)
	return result.empty()


export var relevance_check_interval_near := 15
export var relevance_check_interval_mid := 45
export var relevance_check_interval_far := 100
export var relevance_near_range := 40.0
export var relevance_mid_range := 90.0
var _current_relevance_interval := 45

func _getRelevanceInterval(dist:float) -> int:
	if dist <= relevance_near_range: return relevance_check_interval_near
	elif dist <= relevance_mid_range: return relevance_check_interval_mid
	return relevance_check_interval_far















func cleanIframes():
	if current_skill != "burrow" or current_skill != "burrow":
		anim_calls.enableCollisions()
		
		
var entity_name = "nameless"
func randomizeEntityName():
	if entity_name != "nameless":
		return
	var prefixes = ["Iron","Dark","Wild","Blood","Stone","Shadow","Frost","Fire","Storm","Ash"]
	var suffixes = ["fang","claw","heart","walker","hunter","reaver","maw","blade","caller","born"]
	entity_name = prefixes[randi() % prefixes.size()] + " " + suffixes[randi() % suffixes.size()].capitalize()
