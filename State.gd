extends Node

onready var controller = $".."
onready var wander_node = $Wander

func stateMachine(mob):
	changeState(mob)
	CommonBehaviours.updateAnimation(mob)
	match mob.get_meta("state"):
		"wander":
			CommonBehaviours.wander(mob)

var give_up_range = 40
func changeState(mob):
	if mob.stats.health > 0:
		var has_target = false
		for aggro_target in mob.targets:
			if is_instance_valid(aggro_target.target_entity):
				if aggro_target.aggro <= 0:
					mob.set_meta("state","wander")
				else:
					has_target = true
					if mob.stats.is_predator == true:
						var distance = mob.global_transform.origin.distance_to(aggro_target.target_entity.global_transform.origin)
						if distance <= give_up_range:
							mob.set_meta("state","fight")
						else:
							mob.set_meta("state","chase")
					else:
						mob.set_meta("state","run")

#_________________________________________Dead and Done_____________________________________________
	else:
		if mob.stats.is_finished == true:
			mob.set_meta("state","dead")
		else:
			mob.set_meta("state","dying")
