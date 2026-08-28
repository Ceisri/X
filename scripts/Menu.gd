extends Control

onready var menuButton = $MenuButton
onready var grid = $MenuButton/GridContainer

func _ready():
	grid.visible = false

	menuButton.connect("pressed", self, "onMenuPressed")
	grid.get_node("Inventory").connect("pressed", self, "onInventoryPressed")
	grid.get_node("Character").connect("pressed", self, "onCharacterPressed")
	grid.get_node("Skills").connect("pressed", self, "onSkillsPressed")
	grid.get_node("ForceShutDown").connect("pressed", self, "onForceShutdownPressed")


func onMenuPressed():
	grid.visible = !grid.visible


func onInventoryPressed():
	$"../Inventory".visible = !$"../Inventory".visible


func onCharacterPressed():
	$"../Equipment".visible = !$"../Equipment".visible


func onSkillsPressed():
	$"../SkillTreeRoot".visible = !$"../SkillTreeRoot".visible

func onForceShutdownPressed():
	var world = findWorld(get_tree().get_root())
	if world:
		world.saveData()
		world.saveRecursive(world)
		if world.has_method("flushFileWriteQueue"):
			world.flushFileWriteQueue()
	if get_tree().network_peer != null:
		get_tree().network_peer.close_connection()
		yield(get_tree().create_timer(0.3), "timeout")
	get_tree().quit()


func findWorld(node):
	if node.name == "World":
		return node

	for child in node.get_children():
		var found = findWorld(child)
		if found:
			return found

	return null



