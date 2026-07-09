extends AnimationTree

func findAnimPlayer()->void:
	var ap=get_node_or_null("../character/AnimationPlayer")
	if !ap:
		ap=get_parent().find_node("AnimationPlayer",true,false)
	if !ap: return

	var ap_path=ap.get_path()

	if has_method("set_animation_player"):
		call("set_animation_player",ap_path)
	else:
		set("animation_player",ap_path)


