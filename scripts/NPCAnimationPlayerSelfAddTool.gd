tool
extends AnimationPlayer

export var run_once:bool = false setget setRunOnce

func setRunOnce(value:bool)->void:
	if value and Engine.is_editor_hint():
		addUnlockAnimCallsOnce()
	run_once = false

func _ready():
	if Engine.is_editor_hint():
		call_deferred("addUnlockAnimCallsOnce")

func addUnlockAnimCallsOnce()->void:
	var animation_calls = get_parent().get_parent().get_node_or_null("AnimationCalls")
	if !animation_calls:
		return

	var calls_path = animation_calls.get_path()
	var changed:bool = false

	for animation_name in get_animation_list():
		if animation_name.to_lower().ends_with("cycle"):
			continue

		var animation = get_animation(animation_name)
		if !animation:
			continue

		var end_time:float = animation.length

		var method_track:int = -1
		for track_index in range(animation.get_track_count()):
			if animation.track_get_type(track_index) == Animation.TYPE_METHOD and animation.track_get_path(track_index) == calls_path:
				method_track = track_index
				break

		if method_track == -1:
			method_track = animation.add_track(Animation.TYPE_METHOD)
			animation.track_set_path(method_track, calls_path)

		var already_has_unlock:bool = false
		for key_index in range(animation.track_get_key_count(method_track)):
			var key_value = animation.track_get_key_value(method_track, key_index)
			if typeof(key_value) == TYPE_DICTIONARY and key_value.get("method","") == "unlockAnim":
				already_has_unlock = true
				break

		if already_has_unlock:
			continue

		animation.track_insert_key(method_track, end_time, {"method":"unlockAnim","args":[]})
		changed = true

	if changed and Engine.is_editor_hint():
		print("AnimationPlayer.gd: unlockAnim calls added at exact end frames")
