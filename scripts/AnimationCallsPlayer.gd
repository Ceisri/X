extends Node
#AnimationCalls.gd direct child of $character which is a direct child of Player
onready var parent= $".."
onready var animation=$"../character/AnimationPlayer"

onready var stats=$"../Stats"

var combo_stage:int=0
var combo_playing:bool=false
var can_comboB:bool=false
var can_comboC:bool=false
var locked:bool=false



"""
combo_atk()->void stops the combo attack animation
call this for press to attack otherwise the player needs to hold on the combo attack
button to keep doing base attacks, there's a modality to switch between the two
but for the people that want to do press to attack instead of hold to attack this is needed
call it at the end of every hit in the combo attack animation, during the recovery frames
"""


func combo_atk()->void:
	$"../UI/Skillbar".continue_combo_atk = false
	$"../UI/Skillbar".consumeCombo()




func mine()->void:
	var chat:Control=$"../UI/Chat"
	var item_slot=$"../UI/Equipment/MainHand/Slot"
	var inventory=parent.inventory
	var inventory_grid=inventory.inventory_grid
	var floating_text_parent=inventory.floating_text_parent
	var mining_area:Area=$"../Turnable/Bash"
	var stats=parent.stats
	var mining_power:=1

	for key in Global.weapons:
		var icon=Global.weapons[key]["icon"]
		var texture=load(icon) if typeof(icon)==TYPE_STRING else icon
		if texture==item_slot.texture:
			mining_power=Global.weapons[key].get("mining power",1)
			break

	var quantity:=max(1,randi()%mining_power+1)

	for body in mining_area.get_overlapping_bodies():
		var item_data=null
		var item_name=""
		if body.has_method("gather"): body.gather()
		if body.is_in_group("rock") or body.is_in_group("Rock"):
			item_data=Global.resources["stone"]
			item_name="stone"
		elif body.is_in_group("gold") or body.is_in_group("Gold"):
			item_data=Global.resources["gold ore"]
			item_name="gold ore"
		elif body.is_in_group("iron") or body.is_in_group("Iron"):
			item_data=Global.resources["iron ore"]
			item_name="iron ore"

		if item_data:
			Global.addStackableItem(inventory_grid,item_data,floating_text_parent,quantity)
			chat.sendSystemMessage("Gathered %d %s."%[quantity,item_name])
			var experience_gained:int = 1
			stats.getExperience(experience_gained)

			
			
			
func chop()->void:
	var chat:Control=$"../UI/Chat"
	var item_slot=$"../UI/Equipment/MainHand/Slot"
	var inventory=parent.inventory
	var inventory_grid=inventory.inventory_grid
	var floating_text_parent=inventory.floating_text_parent
	var chopping_area:Area=$"../Turnable/Bash"
	var stats=parent.stats
	var chopping_power:=1

	for key in Global.weapons:
		var icon=Global.weapons[key]["icon"]
		var texture=load(icon) if typeof(icon)==TYPE_STRING else icon
		if texture==item_slot.texture:
			chopping_power=Global.weapons[key].get("chopping power",1)
			break

	var quantity:=max(1,randi()%chopping_power+1)

	for body in chopping_area.get_overlapping_bodies():
		if not body.has_method("gather"):
			continue

		var gathered_items=[]
		
		for group in body.get_groups():
			var key=String(group).to_lower()
			if Global.resources.has(key):
				gathered_items.append({
					"data": Global.resources[key],
					"name": key
				})

		for item in gathered_items:
			Global.addStackableItem(
				inventory_grid,
				item.data,
				floating_text_parent,
				quantity
			)

			chat.sendSystemMessage("Gathered %d %s."%[
				quantity,
				item.name
			])

			stats.getExperience(1)

		body.gather()



func gather()->void:
	var chat:Control=$"../UI/Chat"
	var inventory=parent.inventory
	var inventory_grid=inventory.inventory_grid
	var floating_text_parent=inventory.floating_text_parent
	var gather_area:Area=$"../Turnable/Bash"
	var stats=parent.stats

	for body in gather_area.get_overlapping_areas():
		if !body.is_in_group("Plant"):
			continue

		var gathered_items=[]

		for group in body.get_groups():
			var key=String(group).to_lower()
			if Global.resources.has(key):
				gathered_items.append({
					"data":Global.resources[key],
					"name":key
				})

		if body.has_method("gather"):
			body.gather()

		for item in gathered_items:
			var quantity:=randi()%4+3
			if item.data.has("gatherable_qauntity") and typeof(item.data.gatherable_qauntity)==TYPE_INT:
				quantity=item.data.gatherable_qauntity

			Global.addStackableItem(
				inventory_grid,
				item.data,
				floating_text_parent,
				quantity
			)

			chat.sendSystemMessage("Gathered %d %s."%[
				quantity,
				item.name
			])

			stats.getExperience(3)




func dealDMG()->void:
	stats.dealDamage()

func applyBuff()->void:
	stats.applyBuffDebuff(parent.current_skill,get_parent())




func animationStart():
	if parent.is_in_group("BOT"):
		return
	get_parent().animation_almost_finished = false
func animationAlmostFinished():
	if parent.is_in_group("BOT"):
		return
	get_parent().animation_almost_finished = true











var speed_up_combos = {
	"stone splitter": false,
	"placeholder": false,
}
var speed_up_combo_until = {}
func speedUPtheNextATK(selected_atk:String):
	speed_up_combo_until[selected_atk] = OS.get_ticks_msec() / 1000.0 + 4.0

var BerserkComboTimer:float = 2
func BerserkBasicCombo():
	var selected_atk:String = "stone splitter"
	speed_up_combo_until[selected_atk] = OS.get_ticks_msec() / 1000.0 + BerserkComboTimer



func flipDirection()->void:
	parent.direction = -parent.direction
	parent.player_mesh.rotation.y += PI
	parent.turnable.rotation.y += PI

	
var _iframe_collisions_disabled:bool = false

func disableCollisions()->void:
	if _iframe_collisions_disabled:
		return
	_iframe_collisions_disabled = true
	if parent.cached_entities.empty():
		parent.cacheEntities()
	for body in parent.cached_entities:
		if !is_instance_valid(body) or body == parent:
			continue
		parent.add_collision_exception_with(body)
		body.add_collision_exception_with(parent)

func enableCollisions()->void:
	if !_iframe_collisions_disabled:
		return
	_iframe_collisions_disabled = false
	if parent.cached_entities.empty():
		parent.cacheEntities()
	for body in parent.cached_entities:
		if !is_instance_valid(body) or body == parent:
			continue
		parent.remove_collision_exception_with(body)
		body.remove_collision_exception_with(parent)


	



func unlockAnim():
	speed_up_combo_until.erase(parent.current_skill)
	enableCollisions()
	parent.root_motion_active = false
	if parent.current_skill != "combo attack":
		for key in parent.anim_locks:
			parent.anim_locks[key] = false
			parent.current_skill = "none"
			parent.last_active_skill = ""
			parent.animation_tree.active = false
			if stats.has_method("resetChargedStacks"):
				stats.resetChargedStacks()
	if !parent.is_in_group("Player"):
		parent.has_active_lock = false
	if parent.is_in_group("BOT"):
		if parent.is_downed:
			parent.current_skill = "downed"
		else:
			parent.current_skill = ""



func connectUnlockAnimLastFrames():
	var save_path = "res://world/player/human/animations/"

	var dir = Directory.new()

	if !dir.dir_exists(save_path):
		dir.make_dir_recursive(save_path)

	for anim_name in animation.get_animation_list():
		var anim = animation.get_animation(anim_name)

		if anim == null:
			continue

		for i in range(anim.get_track_count() - 1,-1,-1):
			if anim.track_get_type(i) == Animation.TYPE_METHOD:
				anim.remove_track(i)

		var unlock_track = anim.add_track(Animation.TYPE_METHOD)

		anim.track_set_path(
			unlock_track,
			NodePath("../AnimationCalls")
		)

		anim.track_insert_key(
			unlock_track,
			anim.length,
			{"method":"unlockAnim","args":[]})

		ResourceSaver.save("%s%s.tres" % [save_path,anim_name],anim)




func cleanCallTracks():
	var save_path = "res://world/player/human/animations/"

	var dir = Directory.new()

	if !dir.dir_exists(save_path):
		return

	for anim_name in animation.get_animation_list():
		if !(anim_name in parent.anim_locks):
			continue

		var anim = animation.get_animation(anim_name)

		if anim == null:
			continue

		for i in range(anim.get_track_count() - 1,-1,-1):
			if anim.track_get_type(i) == Animation.TYPE_METHOD:
				anim.remove_track(i)

		ResourceSaver.save("%s%s.tres" % [save_path,anim_name],anim)

func loadAnimations():
	var save_path = "res://world/player/human/animations/"

	var dir = Directory.new()

	if dir.open(save_path) != OK:
		return

	dir.list_dir_begin(true,true)

	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var anim_name = file_name.get_basename()

			var anim = load("%s%s" % [save_path,file_name])

			if anim:
				if animation.has_animation(anim_name):
					animation.remove_animation(anim_name)

				animation.add_animation(anim_name,anim)

		file_name = dir.get_next()

	dir.list_dir_end()

func starttNonCombatAbility():
	parent.is_in_combat = false
func existNonCombatAbility():
	parent.is_in_combat = false
	parent.animation_tree.active = true
	parent.animation_tree.set("parameters/IsInCombat/blend_amount", 0.0)
	parent.animation_tree.set("parameters/CombatSwitch/blend_amount", 0.0)
	parent.current_skill = ""
	for key in parent.anim_locks:
		parent.anim_locks[key] = false

