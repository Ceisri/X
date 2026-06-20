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
	addBerserkComboCalls()

func addUnlockAnimCalls():
	var animation_calls = $"../../AnimationCalls"

	for anim_name in get_animation_list():
		if anim_name.ends_with("_cycle") or anim_name.ends_with("_Cycle"):
			continue

		var anim = get_animation(anim_name)
		var longest_track_time = 0.0

		for track_idx in range(anim.get_track_count()):
			var key_count = anim.track_get_key_count(track_idx)
			if key_count > 0:
				longest_track_time = max(longest_track_time, anim.track_get_key_time(track_idx, key_count - 1))

		var track = anim.add_track(Animation.TYPE_METHOD)
		anim.track_set_path(track, animation_calls.get_path())
		anim.track_insert_key(
			track,
			max(longest_track_time - (1.0 / Engine.iterations_per_second), 0.0),
			{"method":"unlockAnim","args":[]}
		)
func addBerserkComboCalls():
	var animation_calls = $"../../AnimationCalls"

	for anim_name in BERSERK_COMBO_ANIMS:
		if !has_animation(anim_name):
			continue

		var anim = get_animation(anim_name)
		var track = anim.add_track(Animation.TYPE_METHOD)

		anim.track_set_path(track, animation_calls.get_path())

		for time in [anim.length * 0.25 ,anim.length * 0.5, anim.length * 0.75, anim.length * 0.8, anim.length * 0.9,anim.length]:
			anim.track_insert_key(track, time, {"method":"BerserkBasicCombo","args":[]})
