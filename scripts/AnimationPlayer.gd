extends AnimationPlayer
tool

const BERSERK_COMBO_ANIMS = [
	"Berserk_Raze_OneHanded","Berserk_Raze_TwoHanded",
	"Berserk_StoneSplitter_OneHanded",
	"Berserk_ShoulderBash_OneHanded","Berserk_ShoulderBash_TwoHanded",
	"Berserk_FuryStrike_OneHanded","Berserk_FuryStrike_TwoHanded",
	"Berserk_Sunder_OneHanded","Berserk_Sunder_TwoHanded",
	"Berserk_SadisticBlow_OneHanded","Berserk_SadisticBlow_TwoHanded",
	"Berserk_Sledge_OneHanded","Berserk_Sledge_TwoHanded",
	"Berserk_ShoulderBash_OneHanded","Berserk_ShoulderBash_TwoHanded",
]

# Climbing ".." from a node can walk PAST the root of the scene currently
# being edited and into the editor's own internal node tree (EditorNode/...).
# If another scene tab happens to be open too, that walk can coincidentally
# land on a real AnimationCalls.gd belonging to a DIFFERENT scene entirely.
# Never climb past edited_scene_root -- if we'd have to, there is no
# legitimate AnimationCalls to find and we must bail.
func _findRealAnimationCalls() -> Node:
	if !Engine.editor_hint:
		return get_node_or_null("../../AnimationCalls")

	var edited_root = get_tree().edited_scene_root
	var node:Node = self
	for i in range(2):
		if node == null or node == edited_root:
			return null
		node = node.get_parent()
	if node == null:
		return null

	var candidate = node.get_node_or_null("AnimationCalls")
	if candidate == null:
		return null
	var script = candidate.get_script()
	if script == null or script.resource_path.get_file() != "AnimationCalls.gd":
		return null
	return candidate

func _bakePath(animation_calls:Node) -> NodePath:
	var root := get_node_or_null(root_node) if root_node != NodePath("") else null
	if root == null:
		root = get_parent()
	return root.get_path_to(animation_calls)

func _ready():
	var animation_calls = _findRealAnimationCalls()
	if !animation_calls:
		return
	addUnlockAnimCalls(animation_calls)
	addInvincibilityFrames(animation_calls)
	addBerserkComboCalls(animation_calls)


func _stripMethodTracksByMethod(animation:Animation, method_names:Array) -> void:
	var track_index := animation.get_track_count() - 1
	while track_index >= 0:
		if animation.track_get_type(track_index) == Animation.TYPE_METHOD:
			var matches := false
			for key_index in range(animation.track_get_key_count(track_index)):
				var key = animation.track_get_key_value(track_index, key_index)
				if typeof(key) == TYPE_DICTIONARY and method_names.has(key.get("method","")):
					matches = true
					break
			if matches:
				animation.remove_track(track_index)
		track_index -= 1


func addUnlockAnimCalls(animation_calls:Node):
	var calls_path := _bakePath(animation_calls)

	for animation_name in get_animation_list():
		if animation_name.ends_with("_cycle") or animation_name.ends_with("_Cycle") or animation_name[0].is_valid_integer():
			continue

		var animation=get_animation(animation_name)
		if !animation: continue

		_stripMethodTracksByMethod(animation, ["animationStart","animationAlmostFinished","unlockAnim"])

		var longest_track_time=0.0

		for track_index in range(animation.get_track_count()):
			var key_count=animation.track_get_key_count(track_index)
			if key_count>0:
				longest_track_time=max(longest_track_time,animation.track_get_key_time(track_index,key_count-1))

		var length=animation.length
		var second_frame_time=min(1.0/60.0,length*0.1)

		var method_track=animation.add_track(Animation.TYPE_METHOD)
		animation.track_set_path(method_track,calls_path)
		animation.track_insert_key(method_track,second_frame_time,{"method":"animationStart","args":[]})
		animation.track_insert_key(method_track,length*0.78,{"method":"animationAlmostFinished","args":[]})
		animation.track_insert_key(method_track,max(longest_track_time-(1.0/Engine.iterations_per_second),0.0),{"method":"unlockAnim","args":[]})



func addInvincibilityFrames(animation_calls:Node)->void:
	var calls_path := _bakePath(animation_calls)

	for animation_name in get_animation_list():
		var lower_name=animation_name.to_lower()
		if !("evasion" in lower_name or "backstep" in lower_name or "dodge" in lower_name or "avoid" in lower_name or "iframe" in lower_name):
			continue

		var animation=get_animation(animation_name)

		_stripMethodTracksByMethod(animation, ["disableCollisions","enableCollisions"])

		var track_start=animation.add_track(Animation.TYPE_METHOD)
		var track_end=animation.add_track(Animation.TYPE_METHOD)

		animation.track_set_path(track_start,calls_path)
		animation.track_set_path(track_end,calls_path)

		animation.track_insert_key(track_start,0.0,{"method":"disableCollisions","args":[]})
		animation.track_insert_key(track_end,max(animation.length-0.01,0.0),{"method":"enableCollisions","args":[]})

func addBerserkComboCalls(animation_calls:Node):
	var calls_path := _bakePath(animation_calls)

	for anim_name in BERSERK_COMBO_ANIMS:
		if !has_animation(anim_name):
			continue

		var anim = get_animation(anim_name)

		_stripMethodTracksByMethod(anim, ["BerserkBasicCombo"])

		var track = anim.add_track(Animation.TYPE_METHOD)

		anim.track_set_path(track, calls_path)

		for time in [anim.length * 0.25 ,anim.length * 0.5, anim.length * 0.75, anim.length * 0.8, anim.length * 0.9,anim.length]:
			anim.track_insert_key(track, time, {"method":"BerserkBasicCombo","args":[]})
