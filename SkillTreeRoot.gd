extends Control 

onready var close_button = $Close
onready var reset_button = $Reset
onready var player = $"../.."
onready var stats = $"../../Stats"
onready var skilltree_holder = $SkillsTreeHolder

const SAVE_DIR = "user://Characters/"
const SAVE_FILE = "/ui_skilltreeroot.save"

func _ready()->void:
	close_button.connect("pressed",self,"collapse")
	reset_button.connect("pressed",self,"resetSkills")
	call_deferred("loadData")

func _physics_process(delta):
	if Input.is_action_just_pressed("skills"):
		visible = !visible
		saveData()

func resetSkills()->void:
	for child in skilltree_holder.get_child(0).get_children():
		if child is TextureButton:
			child.skill_level = 0
			child.can_be_dragged = false
			
			if child.is_root_skill:
				child.can_be_leveled = true
			else:
				child.can_be_leveled = false
			
			child.updateLevel()

	stats.skill_points += stats.used_skill_points
	stats.used_skill_points = 0
	
	saveData()

func collapse():
	visible = !visible
	saveData()

func saveData():
	var dir = Directory.new()
	var character_dir = SAVE_DIR + player.entity_name

	if !dir.dir_exists(character_dir):
		dir.make_dir_recursive(character_dir)

	var file = File.new()

	if file.open(character_dir + SAVE_FILE,File.WRITE) == OK:
		file.store_var({
			"visible": visible,
			"skill_points": stats.skill_points,
			"used_skill_points": stats.used_skill_points
		})
		file.close()

	for child in skilltree_holder.get_child(0).get_children():
		if child is TextureButton:
			
			var skill_file = File.new()
			var skill_path = character_dir + "/" + child.name + ".save"

			if skill_file.open(skill_path,File.WRITE) == OK:
				skill_file.store_var({
					"skill_level": child.skill_level,
					"can_be_dragged": child.can_be_dragged,
					"can_be_leveled": child.can_be_leveled
				})
				skill_file.close()

func loadData():
	yield(get_tree(),"idle_frame")

	var character_dir = SAVE_DIR + player.entity_name
	var path = character_dir + SAVE_FILE

	var file = File.new()

	if file.file_exists(path):
		if file.open(path,File.READ) == OK:
			
			var data = file.get_var()

			if data.has("visible"):
				visible = data["visible"]

			if data.has("skill_points"):
				stats.skill_points = data["skill_points"]

			if data.has("used_skill_points"):
				stats.used_skill_points = data["used_skill_points"]

			file.close()

	for child in skilltree_holder.get_child(0).get_children():
		if child is TextureButton:
			
			var skill_file = File.new()
			var skill_path = character_dir + "/" + child.name + ".save"

			if skill_file.file_exists(skill_path):
				if skill_file.open(skill_path,File.READ) == OK:
					
					var skill_data = skill_file.get_var()

					if skill_data.has("skill_level"):
						child.skill_level = skill_data["skill_level"]

					if skill_data.has("can_be_dragged"):
						child.can_be_dragged = skill_data["can_be_dragged"]

					if skill_data.has("can_be_leveled"):
						child.can_be_leveled = skill_data["can_be_leveled"]

					child.updateLevel()

					skill_file.close()
