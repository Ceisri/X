extends Spatial

onready var area = $Area
onready var mesh = $Mesh
onready var summoner = self

export var expand_speed = 0.35
export var lifetime_frames = 600

var damage = 20
var spawn_frame = 0

func _ready():
	scale = Vector3.ZERO

	spawn_frame = Engine.get_physics_frames()

	expand()

func _physics_process(delta):
	if Engine.get_physics_frames() % 90 == 0:
		dealDamage(summoner, damage)

	if Engine.get_physics_frames() - spawn_frame >= lifetime_frames:
		dissapear()

func dissapear():
	set_physics_process(false)

	queue_free()

func expand():
	var tween = Tween.new()

	add_child(tween)

	tween.interpolate_property(self, "scale", Vector3.ZERO, Vector3.ONE, expand_speed, Tween.TRANS_SINE, Tween.EASE_OUT)

	tween.start()

	yield(tween, "tween_all_completed")

	mesh.conform_to_terrain()

func dealDamage(summoner, damage):
	for body in area.get_overlapping_bodies():
		if body != summoner:
			if body.is_in_group("Entity"):
				if is_instance_valid(body.stats.species):
					if body.stats.species != summoner.stats.species:
						if body.has_method("get_hit"):
							body.get_hit(summoner, damage)

						if body.has_method("display_aggro_player"):
							body.display_aggro_player($AggroInfo)
