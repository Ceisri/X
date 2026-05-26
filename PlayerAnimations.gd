extends AnimationPlayer
onready var player = $"../.."
var blend = 0.25

func animationOrder(controller,stats)->void:
	if controller.anim_locks["dodge"] == true:
		play("dodge",blend)
	elif controller.anim_locks["cleave"] == true:
		play("cleave",blend)
	elif controller.anim_locks["battlecry"] == true:
		play("battlecry",blend)
	elif controller.anim_locks["stop_run"] == true:
		if player.is_running == false:
			play("stop_run",blend,stats.agility)
		else:
			play("run_cycle",0,stats.agility)
	elif player.is_running == true:
		play("run_cycle",0,stats.agility)
	elif player.is_walking == true:
		play("walk_cycle")
	else:
		play("idle_cycle",blend)
