tool
extends EditorScript

const METHOD_NAMES_TO_FIX := [
	"animationStart","animationAlmostFinished","unlockAnim",
	"disableCollisions","enableCollisions",
	"BerserkBasicCombo",
]

func _run():
	var root = get_editor_interface().get_edited_scene_root()
	if root == null:
		print("[FIX] No scene open. Open Player.tscn as the active tab and run again.")
		return

	var anim_player = root.get_node_or_null("character/AnimationPlayer")
	var animation_calls = root.get_node_or_null("AnimationCalls")

	if anim_player == null or animation_calls == null:
		print("[FIX] Wrong scene open -- need Player.tscn with character/AnimationPlayer and AnimationCalls. Got root=", root.get_path())
		return

	var calls_root = anim_player.get_node_or_null(anim_player.root_node) if anim_player.root_node != NodePath("") else anim_player.get_parent()
	if calls_root == null:
		calls_root = anim_player.get_parent()
	var correct_path = calls_root.get_path_to(animation_calls)

	print("[FIX] correct path resolved as: ", correct_path)

	var fixed_count := 0

	for anim_name in anim_player.get_animation_list():
		var anim:Animation = anim_player.get_animation(anim_name)
		if anim == null:
			continue

		var touched := false
		var track_index := anim.get_track_count() - 1
		while track_index >= 0:
			if anim.track_get_type(track_index) == Animation.TYPE_METHOD:
				var path_here = anim.track_get_path(track_index)
				var has_target_method := false
				for key_index in range(anim.track_get_key_count(track_index)):
					var key = anim.track_get_key_value(track_index, key_index)
					if typeof(key) == TYPE_DICTIONARY and METHOD_NAMES_TO_FIX.has(key.get("method","")):
						has_target_method = true
						break
				if has_target_method and path_here != correct_path:
					print("[FIX] ", anim_name, " track ", track_index, " had bad path: ", path_here)
					anim.track_set_path(track_index, correct_path)
					touched = true
			track_index -= 1

		if touched:
			fixed_count += 1
			var resource_path = anim.resource_path
			if resource_path != "":
				var err = ResourceSaver.save(resource_path, anim)
				print("[FIX] resaved ", resource_path, " err=", err)
			else:
				print("[FIX] ", anim_name, " has no resource_path (embedded in scene) -- will be saved when you save the scene")

	print("[FIX] done. animations touched: ", fixed_count)
