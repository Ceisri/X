extends Control

onready var close_button:TextureButton = $Close
onready var reset_button:TextureButton = $Reset
onready var player:KinematicBody = $"../.."
onready var stats:Node = $"../../Stats"
onready var skill_points_label:Label = $SkillPointsLabel
onready var classes_container = $ClassesScrollContainer/ClassesGridContainer

var selected_class_index:int = 0

func _ready()->void:
	hide()
	close_button.connect("pressed",self,"collapse")
	reset_button.connect("pressed",self,"resetSkills")

	for index in range(classes_container.get_child_count()):
		classes_container.get_child(index).connect("pressed",self,"selectClass",[index])

	selectClass(0)

func _physics_process(delta):
	if Engine.get_physics_frames() % 26 == 0:
		if visible == true:
			skill_points_label.text = str(stats.skill_points)
		



func selectClass(index:int)->void:
	selected_class_index = index

	for holder_index in range(16):
		get_node("SkillsTreeHolder"+str(holder_index+1)).visible = holder_index == index



func resetSkills()->void:
	var root = get_node("SkillsTreeHolder"+str(selected_class_index+1)).get_child(0)

	for child in root.get_children():
		if child is TextureButton:
			child.skill_level = 0
			child.can_be_dragged = false
			child.can_be_leveled = child.is_root_skill
			child.updateLevel()

	stats.skill_points += stats.used_skill_points
	stats.used_skill_points = 0

func collapse():
	visible = !visible
