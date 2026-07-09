extends MeshInstance

var player
onready var tween=$Tween
onready var mat
export var max_scale:float = 0.2
func _ready():
	player=$"../.."
	mat=get_surface_material(0)

func _process(_delta):
	mat.set_shader_param("scroll_speed",Vector2(0,lerp(0.5,2.0,0.5)))
	if player.anim_locks["guard react"] and player.stats.health >0:
		if !visible:
			visible=true
			scale=Vector3()
			tween.interpolate_property(self,"scale",Vector3(),Vector3(max_scale,max_scale,max_scale),0.12,Tween.TRANS_SINE,Tween.EASE_OUT)
			tween.start()
	else:
		visible=false
		scale=Vector3()
