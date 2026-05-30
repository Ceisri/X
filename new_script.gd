extends KinematicBody




func skillState() -> void:
	if skill_bar_input == "none":
		firstLevelAnimations()
	else:
		match skill_bar_input:
			"1":
				var slot = $Canvas/Skillbar/GridContainer/Slot1/Icon
				skills(slot)
			"2":
				var slot = $Canvas/Skillbar/GridContainer/Slot2/Icon
				skills(slot)




var can_input_cancel:bool = true 
var skill_bar_input:String = "none"
func skillBarInputs():
	if Input.is_action_just_pressed("1"):
		skill_bar_input = "1"
	elif Input.is_action_just_pressed("2"):
		skill_bar_input = "2"
