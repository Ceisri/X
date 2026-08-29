extends Control

onready var close_button:TextureButton = $Close
onready var reset_button:TextureButton = $Reset
onready var player:KinematicBody = $"../.."
onready var stats:Node = $"../../Stats"
onready var skill_points_label:Label = $SkillPointsLabel

# Single unified skill tree now (was 16 separate SkillsTreeHolderN
# panels, one per class -- collapsed into one shared pannable MoveThis
# node). This lookup tries the expected path first, then falls back to
# a recursive name search, so a future rename never turns into a
# null-instance crash -- it just logs one clear error instead.
var skill_tree_buttons_container:Node = null
var _warned_missing_container := false

func _ready()->void:
	hide()

	if is_instance_valid(close_button):
		close_button.connect("pressed",self,"collapse")
	else:
		push_error("SkillTreeRoot.gd: 'Close' button not found -- close/collapse will not work")

	if is_instance_valid(reset_button):
		reset_button.connect("pressed",self,"resetSkills")
	else:
		push_error("SkillTreeRoot.gd: 'Reset' button not found -- reset will not work")

	skill_tree_buttons_container = findSkillTreeButtonsContainer()


func findSkillTreeButtonsContainer() -> Node:
	var direct = get_node_or_null("SkillTree/Control/MoveThis")
	if is_instance_valid(direct):
		return direct

	var found = findNodeByNameRecursive(self,"MoveThis")
	if is_instance_valid(found):
		return found

	if !_warned_missing_container:
		_warned_missing_container = true
		push_error("SkillTreeRoot.gd: could not find the 'MoveThis' skill button container anywhere under SkillTreeRoot -- reset will do nothing until this is fixed.")
	return null


func findNodeByNameRecursive(node:Node, target_name:String) -> Node:
	for child in node.get_children():
		if child.name == target_name:
			return child
		var found = findNodeByNameRecursive(child,target_name)
		if is_instance_valid(found):
			return found
	return null


func _physics_process(delta):
	if !is_instance_valid(player) or !is_instance_valid(skill_points_label) or !is_instance_valid(stats):
		return
	if player.isLocalPlayer():
		if Engine.get_physics_frames() % 26 == 0:
			if visible == true:
				skill_points_label.text = str(stats.skill_points)

func resetSkills()->void:
	if !is_instance_valid(skill_tree_buttons_container):
		skill_tree_buttons_container = findSkillTreeButtonsContainer()
	if !is_instance_valid(skill_tree_buttons_container):
		return

	for child in skill_tree_buttons_container.get_children():
		if child is TextureButton and "skill_level" in child:
			var original_level:int = 0
			var original_dragged:bool = false
			if "_initial_skill_level" in child:
				original_level = child._initial_skill_level
			if "_initial_can_be_dragged" in child:
				original_dragged = child._initial_can_be_dragged

			child.skill_level = original_level
			child.can_be_dragged = original_dragged
			child.can_be_leveled = child.is_root_skill
			if child.has_method("updateLevel"):
				child.updateLevel()

	if !is_instance_valid(stats):
		return

	stats.skill_points += stats.used_skill_points
	stats.used_skill_points = 0
	if stats.has_method("invalidateSkillLevelCache"):
		stats.invalidateSkillLevelCache()
func collapse():
	visible = !visible
