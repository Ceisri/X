extends TextureButton
onready var icon:TextureRect = $Slot
onready var level_label:Label = $Level
onready var name_label:Label = $Name
onready var skill_tree_node:Control = get_parent().get_parent()
onready var Player:KinematicBody = $"../../../../.."

export(Array, NodePath) var connected_skill_buttons

export var max_level:int = 100
export var skill_level:int = 0
export var is_root_skill:bool = false
export var can_be_leveled:bool = false
var can_be_dragged:bool = false
var is_from_skill_tree:bool = true
var branch_lines = []


func _ready():
	call_deferred("loadData")
	connect("pressed",self,"skillPressed")
	updateLevel()

	level_label.text = str(skill_level) + "/" + str(max_level)

	for path in connected_skill_buttons:
		var target = get_node_or_null(path)

		if target:
			var line = Line2D.new()

			line.width = 4
			line.default_color = Color.gray

			line.z_index = -1
			line.z_as_relative = false

			add_child(line)
			move_child(line, 0)

			branch_lines.append({
				"line":line,
				"target":target
			})
	nameLabelDisplay()
func nameLabelDisplay()->void:
	if name_label != null and icon != null and icon.texture != null:
		var texture_path = icon.texture.resource_path

		for skill_name in Skills.skills:
			if typeof(Skills.skills[skill_name]) != TYPE_OBJECT:
				continue

			var skill_texture = Skills.skills[skill_name]

			if skill_texture == null:
				continue

			if skill_texture.resource_path == texture_path:
				var clean_name = ""

				for c in skill_name:
					if c >= "a" and c <= "z":
						clean_name += c
					elif c >= "A" and c <= "Z":
						clean_name += c
					elif c == " ":
						clean_name += c

				name_label.text = clean_name
				break



func skillPressed()->void:
	var stats = get_parent().get_parent().stats

	if !can_be_leveled and skill_level <= 0:
		return
	if stats == null:
		return
	if skill_level >= max_level:
		return
	if stats.skill_points <= 0:
		return

	stats.skill_points -= 1
	stats.used_skill_points += 1

	skill_level += 1
	can_be_dragged = true
	updateLevel()

func updateLevel():
	if skill_level > 0:
		can_be_dragged = true
	if icon.texture != null:
		var path = icon.texture.resource_path
		for skill in Skills.skills:
			var texture = Skills.skills[skill]

			if texture.resource_path == path:
				skill_tree_node.skills[skill] = skill_level
				break
	level_label.text = str(skill_level) + "/" + str(max_level)
func _process(delta):
	if skill_level > 0:
		for branch in branch_lines:
			var target = branch.target
			if target:
				target.can_be_leveled = true

	for branch in branch_lines:
		var line = branch.line
		var target = branch.target

		if target == null:
			continue

		var start_pos = rect_size * 0.5

		var target_pos = (
			target.rect_global_position +
			target.rect_size * 0.5
		) - rect_global_position

		line.points = [
			start_pos,
			target_pos
		]

		if skill_level > 0 and target.skill_level > 0:
			line.default_color = Color(0.2,0.7,1.0)

		elif target.can_be_leveled:
			line.default_color = Color(0.75,0.72,0.45)

		else:
			line.default_color = Color(0.35,0.35,0.35)



func get_drag_data(position:Vector2):
	if !can_be_dragged or icon.texture==null:
		return null

	var preview=TextureRect.new()
	preview.texture=icon.texture
	preview.rect_size=Vector2(64,64)
	set_drag_preview(preview)

	return {
		"origin_node":self,
		"origin_icon":icon,
		"origin_texture":icon.texture,
		"origin_is_from_skill_tree":true
	}


func can_drop_data(position,data):
	return false


func drop_data(position,data):
	print("DROP EXECUTED")



const SAVE_DIR = "user://Characters/"


func saveData()->void:
	var dir = Directory.new()
	var save_dir = SAVE_DIR + Player.entity_name + "/"

	if !dir.dir_exists(save_dir):
		dir.make_dir_recursive(save_dir)

	var file = File.new()

	if file.open(save_dir + name + ".save", File.WRITE) == OK:
		file.store_var({
			"skill_level": skill_level,
			"can_be_dragged": can_be_dragged,
			"can_be_leveled": can_be_leveled
		})
		file.close()


func loadData()->void:
	var file = File.new()
	var path = SAVE_DIR + Player.entity_name + "/" + name + ".save"

	if !file.file_exists(path):
		return

	if file.open(path, File.READ) == OK:
		var data = file.get_var()

		if data.has("skill_level"):
			skill_level = data["skill_level"]

		if data.has("can_be_dragged"):
			can_be_dragged = data["can_be_dragged"]

		if data.has("can_be_leveled"):
			can_be_leveled = data["can_be_leveled"]

		file.close()

	updateLevel()
