extends Node

onready var user = $"../.."

const puddle = preload("res://world/Spawnable/scenes/acid puddle.tscn")


func launchPoisonAttack():
	var poison_puddle = puddle.instance()

	poison_puddle.summoner = user
	poison_puddle.damage = 15

	get_tree().current_scene.add_child(
		poison_puddle
	)

	poison_puddle.global_transform.origin = (
		user.global_transform.origin
	)
