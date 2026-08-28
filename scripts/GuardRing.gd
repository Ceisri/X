extends MeshInstance

var player
onready var tween=$Tween
onready var mat
export var max_scale:float = 0.2

const SCROLL_SPEED_CONST := Vector2(0, 1.25) # lerp(0.5,2.0,0.5) precomputed -- it never changes

func _ready():
	player=$"../.."
	mat=get_surface_material(0)
	visible=false
	set_process(false) # only turned on while the ring is actually shown

func _process(_delta):
	if !visible:
		set_process(false)
		return
	mat.set_shader_param("scroll_speed", SCROLL_SPEED_CONST)

	if !(player.anim_locks["guard react"] and player.stats.health > 0):
		visible=false
		scale=Vector3()
		set_process(false)

# Call this instead of relying on a per-frame poll: it only does work
# the instant the guard-react state actually flips, and turns _process
# on only for the duration the ring is visible/animating.
func updateGuardReactVisual() -> void:
	var should_show = player.anim_locks["guard react"] and player.stats.health > 0
	if should_show and !visible:
		visible=true
		scale=Vector3()
		tween.interpolate_property(self,"scale",Vector3(),Vector3(max_scale,max_scale,max_scale),0.12,Tween.TRANS_SINE,Tween.EASE_OUT)
		tween.start()
		set_process(true)
	elif !should_show and visible and !tween.is_active():
		visible=false
		scale=Vector3()
		set_process(false)
