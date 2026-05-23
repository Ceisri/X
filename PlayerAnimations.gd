extends AnimationPlayer

var blend = 0.25

func animationOrder(controller,stats)->void:
	if controller.anim_locks["stop_run"] == true:
		if controller.is_running == false:
			play("stop_run",blend,stats.agility)
		else:
			play("run_cycle",0,stats.agility)
	elif controller.is_running == true:
		play("run_cycle",0,stats.agility)
	elif controller.is_walking == true:
		play("walk_cycle")
	else:
		play("idle_cycle",blend)
