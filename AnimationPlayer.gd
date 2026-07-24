extends AnimationPlayer

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

func _ready():
	addUnlockAnimCalls()
	addInvincibilityFrames()
	addBerserkComboCalls()


func addUnlockAnimCalls():
	var animation_calls=get_parent().get_parent().get_node_or_null("AnimationCalls")
	if !animation_calls: return

	for animation_name in get_animation_list():
		if animation_name.ends_with("_cycle") or animation_name.ends_with("_Cycle") or animation_name[0].is_valid_integer():
			continue

		var animation=get_animation(animation_name)
		if !animation: continue

		var longest_track_time=0.0

		for track_index in range(animation.get_track_count()):
			var key_count=animation.track_get_key_count(track_index)
			if key_count>0:
				longest_track_time=max(longest_track_time,animation.track_get_key_time(track_index,key_count-1))

		var length=animation.length
		var second_frame_time=min(1.0/60.0,length*0.1)

		var method_track=animation.add_track(Animation.TYPE_METHOD)
		animation.track_set_path(method_track,animation_calls.get_path())
		animation.track_insert_key(method_track,second_frame_time,{"method":"animationStart","args":[]})
		animation.track_insert_key(method_track,length*0.78,{"method":"animationAlmostFinished","args":[]})
		animation.track_insert_key(method_track,max(longest_track_time-(1.0/Engine.iterations_per_second),0.0),{"method":"unlockAnim","args":[]})



func addInvincibilityFrames()->void:
	var animation_calls= $"../../AnimationCalls"
	if !animation_calls: return
	for animation_name in get_animation_list():
		var lower_name=animation_name.to_lower()
		if !("evasion" in lower_name or "backstep" in lower_name or "dodge" in lower_name or "avoid" in lower_name or "iframe" in lower_name):
			continue

		var animation=get_animation(animation_name)
		var track_start=animation.add_track(Animation.TYPE_METHOD)
		var track_end=animation.add_track(Animation.TYPE_METHOD)

		animation.track_set_path(track_start,animation_calls.get_path())
		animation.track_set_path(track_end,animation_calls.get_path())

		animation.track_insert_key(track_start,0.0,{"method":"disableCollisions","args":[]})
		animation.track_insert_key(track_end,max(animation.length-0.01,0.0),{"method":"enableCollisions","args":[]})
		
func addBerserkComboCalls():
	var animation_calls = $"../../AnimationCalls"
	if !animation_calls: return

	for anim_name in BERSERK_COMBO_ANIMS:
		if !has_animation(anim_name):
			continue

		var anim = get_animation(anim_name)
		var track = anim.add_track(Animation.TYPE_METHOD)

		anim.track_set_path(track, animation_calls.get_path())

		for time in [anim.length * 0.25 ,anim.length * 0.5, anim.length * 0.75, anim.length * 0.8, anim.length * 0.9,anim.length]:
			anim.track_insert_key(track, time, {"method":"BerserkBasicCombo","args":[]})
