extends AnimationPlayer
onready var player = $"../.."
onready var animation_calls = $"../../AnimationCalls"
var blend = 0.25

func animationOrder(controller,stats)->void:
	for anim_name in controller.anim_locks.keys():
		if controller.anim_locks[anim_name]:
			if current_animation != anim_name:
				if has_animation(anim_name):
					play(anim_name,blend)
				else:
					print("Missing animation: ",anim_name)
					play("land",blend)

			return

	if !player.is_on_floor():
		play("fall",blend)
	elif player.moving:
		if player.movement_mode == "run":
			play("run_cycle",0,stats.agility)
		elif player.movement_mode == "walk":
			play("walk_cycle")
	else:
		play("idle_cycle",blend)
		
		
		
