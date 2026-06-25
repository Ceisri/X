extends KinematicBody

onready var animation_tree:AnimationTree = $AnimationTree

onready var flinch_anim = animation_tree.tree_root.get_node("Flinch")
onready var stats = $Stats
onready var ray_down = $RayDown
onready var anim_calls = $AnimationCalls
var current_skill:String 
var is_dead:bool = false
var is_in_combat:bool = false
var is_being_carried:bool = false
var last_anim_lock_time:int = 0
var anim_lock_delay_ms:int = 500
var anim_locks={
	"atk1":false,
	"atk2":false,
	"atk3":false,
	"atk4":false,
	"atk5":false,
	"atk6":false,
	"atk7":false,
	
	"guard":false,
	"guard react":false,
	"parry":false,
	"die":false,
	"flinch":false,  
	"flinch back":false,
	"knocked down":false,
	"knocked back":false,
	"downed":false,
}

func _ready()->void:
	cacheSpawnpoints()
	cacheEntities()
	randomize()
	random_interval = int(rand_range(2,5))
	ignoreMobBodies()

func _physics_process(delta):
	setCurrentSkillBasedOnSpecies()
	animLockOrder()
	syncAnimLockAnimation()
	if Engine.get_physics_frames() % 600 == 0:#once every 10 seconds
		respawn()#if respawn timer of 12, -1 every 600 frames = 2minute respawn time 
	if Engine.get_physics_frames() % 60 == 0:#once per second
		unstuck()
		updateCooldowns()
	if Engine.get_physics_frames() % 30 == 0:#once  half second
		if anim_locks["die"] == true:
			anim_locks["die"] = false
			animation_tree.active = false
	if Engine.get_physics_frames() % random_interval == 0:#once every 2-4 frames
		CommonBehaviours.gravity(self)
	if Engine.get_physics_frames() % 2  == 0:
		movementanimation() #minimum every two frames or it becomes glitchy 
		if is_dead == false and stats.health >0:
			if target == null:
				animation_tree.active = true
			switchState(delta)





var can_move:bool = true
func animLockOrder()->void:
	if stats.health <=0:
		stats.getReleased()
		animation_tree.set("parameters/IsAlive/blend_amount",1)
		can_move = false
		if is_dead== false:
			animation_tree.active = true
		else:
			animation_tree.active = false
	else:
		animation_tree.set("parameters/IsAlive/blend_amount",0)
		if anim_locks["knocked down"] == true:
			animation_tree.set("parameters/Interuption/blend_amount",1)
			animation_tree.set("parameters/React/blend_amount",0)
			can_move = false
		elif anim_locks["knocked back"] == true:
			animation_tree.set("parameters/Interuption/blend_amount",1)
			animation_tree.set("parameters/React/blend_amount",-1)
			can_move = false
		elif anim_locks["flinch"] == true:
			animation_tree.set("parameters/Interuption/blend_amount",1)
			animation_tree.set("parameters/React/blend_amount",1)
			can_move = false
		else:
			animation_tree.set("parameters/Interuption/blend_amount",0)
			can_move = true
	if movement_mode == "run":
		animation_tree.set("parameters/Interuption/blend_amount",0)
		animation_tree.set("parameters/Interraction/blend_amount",0)
		animation_tree.set("parameters/Movement/blend_amount",1)
		anim_locks["knocked down"] = false
		anim_locks["knocked back"] = false
		anim_locks["flinch"] = false
		anim_locks["flinch back"] = false
		can_move = true


var cached_spawnpoints = []

func cacheSpawnpoints()->void:
	cached_spawnpoints = get_tree().get_nodes_in_group("Spawnpoint")

func getNearestSpawnpoint():
	var nearest_spawn = null
	var nearest_distance = INF

	for spawnpoint in cached_spawnpoints:
		if !is_instance_valid(spawnpoint):
			continue

		var distance = global_transform.origin.distance_squared_to(spawnpoint.global_transform.origin)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_spawn = spawnpoint

	return nearest_spawn



var respawn_time:float = 5
var respawn_id:int = 0
func respawn()->void:
	if is_dead == true:
		respawn_time -= 1 
	if respawn_time <= 0:
		respawn_id += 1
		is_dead = false
		animation_tree.set("parameters/IsAlive/blend_amount",0)
		animation_tree.set("parameters/Interuption/blend_amount",0)
		animation_tree.set("parameters/Interraction/blend_amount",0)
		stats.health = stats.max_health
		stats.arcane = stats.max_arcane
		stats.energy = stats.max_energy
		respawn_time = 12
		clearAggro()
		resetCooldowns()
		is_in_combat = false
		can_move = true
		var nearest_spawn = getNearestSpawnpoint()

		if nearest_spawn:
			var spawn_pos = nearest_spawn.global_transform.origin
			global_transform.origin = Vector3(spawn_pos.x + rand_range(-5,5),spawn_pos.y + 0.5,spawn_pos.z + rand_range(-5,5))


	


func rootMotion(delta)->Vector3:
	var compensation = 0.01
	if stats.species == "orc":
		compensation = 1
	var motion = animation_tree.get_root_motion_transform().origin
	motion.y = 0.0
	if motion.length_squared() < 0.000001:return Vector3.ZERO
	motion = global_transform.basis.xform(motion)
	return motion * compensation / delta

var last_active_skill:String=""

		
		
var skill_cooldowns={}
var attack_pattern=[]
var attack_pattern_index=0
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

func pickNextSkill()->String:
	# Get every skill that is currently available for use.
	# A skill is considered available if:
	# - The species can use it.
	# - It exists in Skills.skills.
	# - It is not currently on cooldown.
	var entries=getAvailableSkills()

	# If there are no usable skills at all,
	# return an empty string so the caller
	# knows nothing can be used right now.
	if entries.empty():
		return ""

	# Calculate current health percentage.
	#
	# Examples:
	# health=100 max_health=100 -> 1.0
	# health=50  max_health=100 -> 0.5
	# health=25  max_health=100 -> 0.25
	#
	# max() prevents division by zero.
	var hp_ratio=float(stats.health)/max(stats.max_health,1.0)

	# We split skills into two groups:
	#
	# support_entries:
	#   Skills listed inside Skills.support_skills.
	#
	# normal_entries:
	#   Everything else.
	var support_entries=[]
	var normal_entries=[]

	# Sort every available skill into the
	# appropriate category.
	for entry in entries:
		if entry.skill in Skills.support_skills:
			support_entries.append(entry)
		else:
			normal_entries.append(entry)

	# Sort both lists by cooldown descending.
	#
	# Highest cooldown first.
	#
	# Example:
	# Heal      30s
	# Barrier   20s
	# Regen     10s
	#
	# Result:
	# Heal -> Barrier -> Regen
	#
	# This means more impactful abilities
	# generally get used before weaker ones.
	support_entries.sort_custom(self,"sortCooldownDesc")
	normal_entries.sort_custom(self,"sortCooldownDesc")

	# Critical health behavior.
	#
	# When health drops below 30%,
	# support abilities become the highest
	# possible priority.
	#
	# Example:
	# HP = 20%
	# Available:
	#   Heal
	#   Barrier
	#   Fireball
	#
	# Result:
	# Heal or Barrier is chosen first.
	if hp_ratio<=0.3:

		# Use best support skill available.
		if !support_entries.empty():
			return support_entries[0].skill

		# If no support skills are available,
		# fall back to normal combat skills.
		if !normal_entries.empty():
			return normal_entries[0].skill

		return ""

	# Above 30% HP we gradually increase
	# support skill usage as health decreases.
	#
	# Formula:
	# hp=100% -> 0%
	# hp=80%  -> 20%
	# hp=60%  -> 40%
	# hp=50%  -> 50%
	# hp=40%  -> 60%
	# hp=31%  -> 69%
	#
	# The lower the health,
	# the more likely support skills become.
	if !support_entries.empty():

		var support_chance=int(clamp((1.0-hp_ratio)*100.0,0,100))

		# Random roll.
		#
		# If the roll succeeds,
		# use the highest-priority support skill.
		if randi()%100<support_chance:
			return support_entries[0].skill

	# If support was not selected,
	# use the strongest available normal skill.
	if !normal_entries.empty():
		return normal_entries[0].skill

	# If only support skills exist,
	# use the best support skill.
	if !support_entries.empty():
		return support_entries[0].skill

	# Safety fallback.
	return ""


func startCooldown(skill_name:String) -> void:
	if !Skills.skills.has(skill_name):
		return

	var path = Skills.skills[skill_name].resource_path
	var cd = Skills.getCooldown(path)

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

func getActiveAnimLock()->String:
	for state in ["die","flinch","flinch back","knocked down","knocked back"]:
		if anim_locks[state]:return state
	for i in["atk1","atk2","atk3","atk4","atk5","atk6","atk7"]:
		if anim_locks[i]:return i
	return ""

func setCurrentSkillBasedOnSpecies()->void:
	var species=stats.species
	if !Skills.skills_by_species.has(species):return

	var active=getActiveAnimLock()
	if !active.begins_with("atk"):return

	var index=int(active.replace("atk",""))-1
	var skills=Skills.skills_by_species[species]

	if index<0 or index>=skills.size():return

	var skill=skills[index]
	var anim_name=active if animation.has_animation(active) else "atk1"

	if species!=last_species or skill!=last_skill or skill_anim.animation!=anim_name:
		last_species=species
		last_skill=skill
		skill_anim.animation=anim_name


var skill_anim_repeat_count=0
var last_skill_anim_name=""
var skill_anim_lock_until=0

func setSkillAnimation(anim_name:String)->void:
	var now=OS.get_ticks_msec()

	var final=anim_name if animation.has_animation(anim_name) else "atk1"
	var species=stats.species
	if !Skills.skills_by_species.has(species):return

	var skills=Skills.skills_by_species[species]
	var index=int(final.replace("atk",""))-1
	if index<0 or index>=skills.size():return

	var skill_name=skills[index]
	var skill_path=Skills.skills[skill_name].resource_path

	var has_cd=Skills.getCooldown(skill_path)>0.0
	var on_cd=skill_cooldowns.has(skill_path)
	var energy_cost=Skills.getEnergyCost(skill_name)

	if stats.energy<energy_cost or (has_cd and on_cd):
		if now<skill_anim_lock_until:return
		skill_anim_lock_until=now+200
		skill_anim.animation=""
		animation_tree.active=false
		animation_tree.active=true
		skill_anim_repeat_count=0
		last_skill_anim_name=""
		return

	if final!=last_skill_anim_name:
		last_skill_anim_name=final
		skill_anim_repeat_count=0
	else:
		skill_anim_repeat_count+=1

	if skill_anim_repeat_count>=3:
		skill_anim.animation=""
		animation_tree.active=false
		animation_tree.active=true
		skill_anim_repeat_count=0
		last_skill_anim_name=""

	skill_anim.animation=final
	last_skill=final

func syncAnimLockAnimation()->void:
	var active=getActiveAnimLock()

	if active in ["flinch","flinch back","knocked down","knocked back","die"]:
		has_anim_lock=false
		attack_waiting=false
		last_lock=""
		for attack_lock in ["atk1","atk2","atk3","atk4","atk5","atk6","atk7"]:
			anim_locks[attack_lock]=false
		return

	if active=="" or !active.begins_with("atk"):return

	var anim_name=active if animation.has_animation(active) else "atk1"

	if anim_name!=last_lock:
		last_lock=anim_name
		skill_anim.animation=""
		skill_anim.animation=anim_name

func combatAnimations(delta)->void:
	if stats.health<=0:
		for lock_name in anim_locks:
			anim_locks[lock_name]=false
		has_anim_lock=false
		attack_waiting=false
		return

	if anim_locks["flinch"] or anim_locks["flinch back"] or anim_locks["knocked down"] or anim_locks["knocked back"] or anim_locks["die"]:
		has_anim_lock=false
		attack_waiting=false
		for attack_lock in ["atk1","atk2","atk3","atk4","atk5","atk6","atk7"]:
			anim_locks[attack_lock]=false
		return

	var now=OS.get_ticks_msec()

	if has_anim_lock:return
	if attack_waiting and now<next_attack_time:return
	if now-last_anim_lock_time<anim_lock_delay_ms:return

	for attack_lock in ["atk1","atk2","atk3","atk4","atk5","atk6","atk7"]:
		anim_locks[attack_lock]=false
		
	var skill_name=pickNextSkill()
	if skill_name=="":return

	var skill_path=Skills.skills[skill_name].resource_path
	var has_cooldown=Skills.getCooldown(skill_path)>0.0

	if skill_name!=previous_skill_name:
		previous_skill_name=skill_name
		same_skill_uses=0

	same_skill_uses+=1

	if has_cooldown:
		if same_skill_uses>1:
			var available=getAvailableSkills()

			for entry in available:
				if entry.skill!=skill_name:
					skill_name=entry.skill
					break

			previous_skill_name=skill_name
			same_skill_uses=1
	else:
		if same_skill_uses>3:
			var available=getAvailableSkills()

			for entry in available:
				if entry.skill!=skill_name:
					skill_name=entry.skill
					break

			previous_skill_name=skill_name
			same_skill_uses=1

	var energy_cost=Skills.getEnergyCost(skill_name)

	if stats.energy<energy_cost:
		var available=getAvailableSkills()

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




	var lock="atk"+str(index+1)
	for attack_lock in ["atk1","atk2","atk3","atk4","atk5","atk6","atk7"]:
		anim_locks[attack_lock]=false
	anim_locks[lock]=true
	stats.energy-=energy_cost
	current_skill=skill_name
	setSkillAnimation(lock)

	has_anim_lock=true
	last_anim_lock_time=now
	next_attack_time=now+400
	attack_waiting=true

	animation_tree.active=false
	animation_tree.active=true
	startCooldown(skill_name)
	stats.applyBuffDebuff(skill_name)






















func switchState(delta):
	if stats.health <= 0:
		for key in anim_locks.keys():
			if key != "die":
				anim_locks[key] = false
		return
	cleanupAggrotargets()
	cleanupDeadAggro()

	var highest = findHighestAggro()

	if highest:
		target = highest.target_entity
	else:
		target = null

	if target == null:
		wander()
	else:
		combat(delta)






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
var cached_entities = []

func cacheEntities()->void:
	cached_entities = get_tree().get_nodes_in_group("Entity")
	
	
func combat(delta):
	if stats.health <= 0:
		for key in anim_locks.keys():
			if key != "die":
				anim_locks[key] = false
		return
	if target == null:
		target_history.clear()
		using_delayed_target = false
		movement_mode = "idle"
		melee_entered = false
		chase_offset = Vector3.ZERO
		last_offset_target = Vector3.ZERO
		return
	stuckDetection()
	updateTargetHistory(target)

	var origin = global_transform.origin
	var real_target = target.global_transform.origin
	var distance_to_target = origin.distance_to(real_target)
	var move_target = real_target

	var in_detection = false

	for body in detection_area.get_overlapping_bodies():
		if body == target:
			in_detection = true
			break

	if !in_detection and distance_to_target > melee_distance and using_delayed_target:
		if chase_offset == Vector3.ZERO or last_offset_target.distance_to(delayed_target_pos) > 3.0:
			last_offset_target = delayed_target_pos
			chase_offset = Vector3(rand_range(-5,5),0,rand_range(-5,5))

		move_target = delayed_target_pos + chase_offset

		for node in cached_entities:
			if !is_instance_valid(node):
				continue
			if node == self:
				continue
			if !(node is KinematicBody):
				continue

			var npc_position = node.global_transform.origin
			npc_position.y = 0

			var target_position = move_target
			target_position.y = 0

			if npc_position.distance_to(target_position) < 1.5:
				var separation = (target_position - npc_position).normalized()

				if separation == Vector3.ZERO:
					separation = Vector3(rand_range(-1,1),0,rand_range(-1,1)).normalized()

				move_target += separation * 3.0
	else:
		chase_offset = Vector3.ZERO
		last_offset_target = Vector3.ZERO
		move_target = real_target

	var has_lock = false

	for lock_name in anim_locks:
		if anim_locks[lock_name]:
			has_lock = true
			break

	if in_detection:
		if !melee_entered:
			melee_entered = true

			for lock_name in anim_locks:
				anim_locks[lock_name] = false

			has_anim_lock = false

			animation_tree.set("parameters/Interuption/blend_amount",0)
			animation_tree.set("parameters/InteruptionSeek/seek_position",0)
			animation_tree.set("parameters/InteruptionOneShot/active",false)

		reached_melee_time = OS.get_ticks_msec()
		resume_chase_time = reached_melee_time + 700
		movement_mode = "idle"

		if !has_lock:
			rotateToTargetMelee(delta,real_target)

		combatAnimations(delta)
		animation_tree.set("parameters/Interraction/blend_amount",1)

		if animation_tree.active and can_move:
			var velocity = rootMotion(delta)

			if velocity != Vector3.ZERO:
				move_and_slide(velocity)

		return

	melee_entered = false

	if has_lock:
		movement_mode = "idle"
		animation_tree.set("parameters/Interraction/blend_amount",1)

		if can_move:
			var velocity = rootMotion(delta)

			if velocity != Vector3.ZERO:
				move_and_slide(velocity)

		return
	
	animation_tree.active = stats.health >0
	animation_tree.set("parameters/Interraction/blend_amount",0)

	rotateToTarget(delta,move_target)

	var direction = move_target - origin
	direction.y = 0

	if direction.length_squared() <= 0.001:
		movement_mode = "idle"
		return

	stats.getReleased()
	movement_mode = "run"
	move_and_slide(direction.normalized() * stats.derived_stats["run_speed"])


var anim_lock_started_time = 0
var tracked_anim_lock = ""

func stuckDetection():
	var active_anim_lock=getActiveAnimLock()

	if active_anim_lock=="":
		tracked_anim_lock=""
		anim_lock_started_time=0
		return

	var time_to_stop=1000 if active_anim_lock.begins_with("flinch") else 3000

	if tracked_anim_lock!=active_anim_lock:
		tracked_anim_lock=active_anim_lock
		anim_lock_started_time=OS.get_ticks_msec()
		return

	if OS.get_ticks_msec()-anim_lock_started_time<time_to_stop:
		return

	for lock_name in anim_locks:
		anim_locks[lock_name] = false

	has_anim_lock = false
	attack_waiting = false
	tracked_anim_lock = ""
	anim_lock_started_time = 0

	animation_tree.active = stats.health > 0
	animation_tree.set("parameters/Interuption/blend_amount",0)
	animation_tree.set("parameters/Interraction/blend_amount",0)
	animation_tree.set("parameters/InteruptionOneShot/active",false)

	if target == null:
		movement_mode = "idle"
	else:
		movement_mode = "run"
		
		
		
func has_any_anim_lock() -> bool:
	for lock_name in anim_locks:
		if anim_locks[lock_name]:
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
func movementanimation():
	match movement_mode:
		"idle":
			animation_tree.set("parameters/Movement/blend_amount", -1)
		"walk":
			animation_tree.set("parameters/Interraction/blend_amount", 0)
			animation_tree.set("parameters/Movement/blend_amount", 0)
		"run":
			animation_tree.set("parameters/Interraction/blend_amount", 0)
			animation_tree.set("parameters/Movement/blend_amount", 1)
func wander():
	is_in_combat = false
	animation_tree.set("parameters/Interraction/blend_amount", 0)
	updateState()
	if get_meta("is_stopped"):
		movement_mode = "idle"
		animation_tree.set("parameters/Movement/blend_amount", -1)
		return

	movementStateSwitch()
	var time = Engine.get_physics_frames()
	if wander_dir == Vector3.ZERO or time >= wander_dir_next_change:
		wander_dir = Vector3(randf() * 2.0 - 1.0,0,randf() * 2.0 - 1.0)
		if wander_dir.length() < 0.01:
			wander_dir = Vector3.FORWARD
		wander_dir = wander_dir.normalized()
		wander_dir_next_change = time + int(rand_range(30, 120))

	set_meta("dir", -wander_dir)
	rotateMob()

	if nav_path.size() > 0:
		moveforward()
		return

	if movement_mode == "run":
		animation_tree.set("parameters/Movement/blend_amount", 1)
		move_and_slide(wander_dir * stats.derived_stats["run_speed"])
	else:
		animation_tree.set("parameters/Movement/blend_amount", 0)
		move_and_slide(wander_dir * stats.walk_speed)
		
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
		move_and_slide(dir * stats.derived_stats["run_speed"])
	elif movement_mode == "walk":
		animation_tree.set("parameters/Movement/blend_amount", 0)
		move_and_slide(dir * stats.walk_speed)
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
	move_and_slide(dir * stats.run_speed)
	
	
	
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

class AggroTarget:
	var target_entity:Node
	var aggro=0
	var last_aggro_time=0
func clearAggro()->void:
	target = null
	targets.clear()
	dead_target_aggro.clear()
	target_history.clear()
	using_delayed_target = false
var dead_target_aggro = {}

func cleanupDeadAggro():
	for i in range(targets.size()-1,-1,-1):
		var aggro_target = targets[i]
		if !is_instance_valid(aggro_target.target_entity):
			continue
		if aggro_target.target_entity.has_node("Stats") and aggro_target.target_entity.stats.health <= 0:
			dead_target_aggro[aggro_target.target_entity] = aggro_target.aggro
			targets.remove(i)
			animation_tree.active = true
			animation_tree.set("parameters/Interraction/blend_amount",0)

	var highest = findHighestAggro()
	target = highest.target_entity if highest and highest.aggro > 0 else null

func getAggro(target_entity:Node)->AggroTarget:
	for existing_target in targets:
		if existing_target.target_entity==target_entity:
			return existing_target

	var aggro_target=AggroTarget.new()
	aggro_target.target_entity=target_entity
	aggro_target.last_aggro_time=OS.get_system_time_secs()
	targets.append(aggro_target)
	return aggro_target
func findHighestAggro() -> AggroTarget:
	var highest_aggro = 0
	var target : AggroTarget = null

	for aggro_target in targets:
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


export var aggro_drop_distance = 50.0
export var aggro_decay_per_second = 3.0

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

func ignoreMobBodies():
	for body in get_tree().get_nodes_in_group("Entity"):
		if body == self:
			continue

		if body.is_in_group("Player") or body.is_in_group("Boss"):
			continue

		if is_in_group("Player") or is_in_group("Boss"):
			continue

		add_collision_exception_with(body)
		body.add_collision_exception_with(self)


#____________________________DEBUGGING STUFF____________________________________

func displayAnimLocks(label)->void:
	var text="AnimationTree: "+str(animation_tree.active)+"\n\n"

	for lock_name in anim_locks:
		if anim_locks[lock_name]:
			text+=lock_name+"\n"

	label.text=text
func displayAggro(label)->void:
	var text=""

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

			var nearest_spawn = getNearestSpawnpoint()

			if nearest_spawn:
				var spawn_pos = nearest_spawn.global_transform.origin
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

	for lock_name in ["atk1","atk2","atk3","atk4","atk5","atk6","atk7"]:
		anim_locks[lock_name]=false

	skill_anim.animation=""
	animation.stop(true)

	var next_skill=pickNextSkill()

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
		
		
		
		
		
		
		
		
		
		
var entity_name = "nameless"
func randomizeEntityName():
	if entity_name != "nameless":
		return
	var prefixes = ["Iron","Dark","Wild","Blood","Stone","Shadow","Frost","Fire","Storm","Ash"]
	var suffixes = ["fang","claw","heart","walker","hunter","reaver","maw","blade","caller","born"]
	entity_name = prefixes[randi() % prefixes.size()] + " " + suffixes[randi() % suffixes.size()].capitalize()



