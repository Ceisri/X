extends Node


#__________________________________Entitygraphical interface________________________________________
onready var entity_graphic_interface = $CrossairInspect
onready var crossair = $Crossair
onready var ray = $"../Camroot/h/v/Camera/RayCast"
onready var crossair_inspect_tween = $"../Camroot/h/v/Camera/RayCast/Tween"
var fade_duration = 0.3

func crossairInspect(player):
	if ray.is_colliding():
		var body = ray.get_collider()
		if body.is_in_group("Entity") and body != player:
			entityInfo(body)
			body.debug($CrossairInspect/Debug)
			# Instantly turn alpha to maximum
			entity_graphic_interface.modulate.a = 1.0
		else:
			# Start tween to fade out
			crossair_inspect_tween.interpolate_property(entity_graphic_interface, "modulate:a", entity_graphic_interface.modulate.a, 0.0, fade_duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
			crossair_inspect_tween.start()
	else:
		# Start tween to fade out
		crossair_inspect_tween.interpolate_property(entity_graphic_interface, "modulate:a", entity_graphic_interface.modulate.a, 0.0,fade_duration/3, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		crossair_inspect_tween.start()
		#print(str(fade_duration))
onready var health_label = $CrossairInspect/Health
onready var energy_label = $CrossairInspect/Energy
onready var name_label = $CrossairInspect/Name
func entityInfo(body):

	health_label.text = str(body.stats.health)
	name_label.text = str(body.stats.Name)
