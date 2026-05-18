extends KinematicBody

onready var mesh = $Armature/Skeleton/Mesh
onready var stats = $Stats
var target:Node = null

func getHit(attacker: Node, damage: float) -> void:
	stats.health -= damage
	$Name.text = " | HP:"+ str(stats.health)
	print("damaged")
