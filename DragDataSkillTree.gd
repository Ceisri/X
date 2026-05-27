extends TextureButton

onready var icon = $Slot
#onready var player = get_parent().player
onready var level_label = $Level

export(Array, NodePath) var connected_skill_buttons

export var max_level:int = 100
export var skill_level:int = 0

var can_be_leveled:bool = false

var branch_lines = []


func _ready():
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
				"line": line,
				"target": target
			})


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


func _pressed():

	if !can_be_leveled and skill_level <= 0:
		return

	if skill_level >= max_level:
		return

	skill_level += 1

	level_label.text = str(skill_level) + "/" + str(max_level)
