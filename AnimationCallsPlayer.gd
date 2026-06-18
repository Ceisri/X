extends Node

onready var parent=$".."
onready var animation=$"../character/AnimationPlayer"
onready var tween=$Tween
onready var timer=$Timer
onready var dmg_area=$"../Area"
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




func dealDMG()->void:
	stats.dealDamage()

func applyBuff()->void:
	stats.selfBuff()

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

	
func disableCollisions()->void:
	for body in get_tree().get_nodes_in_group("Entity"):
		if body == parent:
			continue
		parent.add_collision_exception_with(body)
		body.add_collision_exception_with(parent)
func enableCollisions()->void:
	for body in get_tree().get_nodes_in_group("Entity"):
		if body == parent:
			continue
		parent.remove_collision_exception_with(body)
		body.remove_collision_exception_with(parent)


	



func unlockAnim():
	speed_up_combo_until.erase(parent.current_skill)
	if parent.current_skill != "combo attack":
		for key in parent.anim_locks:
			parent.anim_locks[key] = false
			parent.current_skill = "none"
			parent.last_active_skill = ""
			parent.animation_tree.active = false
			stats.charged_attack_stacks["obliteration"]["stacks"] = 0 




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
			{
				"method":"unlockAnim",
				"args":[]
			}
		)

		ResourceSaver.save(
			"%s%s.tres" % [save_path,anim_name],
			anim
		)




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

		ResourceSaver.save(
			"%s%s.tres" % [save_path,anim_name],
			anim
		)

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
