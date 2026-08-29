extends TextureButton
onready var icon:TextureRect = $Slot
onready var level_label:Label = $Level
onready var name_label:Label = $Name

export(Array, NodePath) var connected_skill_buttons

export var max_level:int = 100
export var skill_level:int = 0
export var is_root_skill:bool = false
export var can_be_leveled:bool = false
var can_be_dragged:bool = false
var is_from_skill_tree:bool = true
var branch_lines = []

var Player:Node = null
var skill_tree_node:Node = null
var _warned_missing_ancestors := false
var _initial_skill_level:int = 0
var _initial_can_be_dragged:bool = false

func _ready() -> void:
	_resolveAncestors()
	call_deferred("staggeredLoadData")
	connect("pressed",self,"skillPressed")
	updateLevel()
	call_deferred("_deferredBuildBranchLines")
	call_deferred("nameLabelDisplay")


func _resolveAncestors() -> void:
	var n:Node = get_parent()
	while n:
		if skill_tree_node == null and "skills" in n and typeof(n.get("skills")) == TYPE_DICTIONARY:
			skill_tree_node = n
		if n.is_in_group("Player"):
			Player = n
			break
		n = n.get_parent()

	if (Player == null or skill_tree_node == null) and !_warned_missing_ancestors:
		_warned_missing_ancestors = true
		if Player == null:
			push_error("DragDataSkillTree.gd (" + name + "): no ancestor in group 'Player' found -- leveling/saving broken until scene tree is fixed.")
		if skill_tree_node == null:
			push_error("DragDataSkillTree.gd (" + name + "): no ancestor with a 'skills' dictionary found -- per-button skill tracking skipped until scene tree is fixed.")


func _deferredBuildBranchLines() -> void:
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

func nameLabelDisplay()->void:
	if name_label == null or icon == null or icon.texture == null:
		return
	var skill_name = Global.getSkillNameByIconPath(icon.texture.resource_path)
	if skill_name == "":
		return
	name_label.text = Global.getSkillCleanName(skill_name)

func updateLevel():
	if skill_level > 0:
		can_be_dragged = true
	if icon.texture != null:
		var skill_name = Global.getSkillNameByIconPath(icon.texture.resource_path)
		if skill_name != "":
			if is_instance_valid(skill_tree_node):
				skill_tree_node.skills[skill_name] = skill_level
			if is_instance_valid(Player) and "stats" in Player and is_instance_valid(Player.stats) and Player.stats.has_method("invalidateSkillLevelCache"):
				Player.stats.invalidateSkillLevelCache(skill_name)
	level_label.text = str(skill_level) + "/" + str(max_level)

func staggeredLoadData() -> void:
	var my_ticket:int = Global.claimSkillLoadTicket()
	while Global.skill_load_served_ticket < my_ticket:
		yield(get_tree(), "idle_frame")
	loadData()
	Global.skill_load_served_ticket += 1


func skillPressed()->void:
	if !is_instance_valid(skill_tree_node) or !("stats" in skill_tree_node):
		return
	var stats = skill_tree_node.stats
	if !is_instance_valid(stats):
		return

	if !can_be_leveled and skill_level <= 0:
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


func _physics_process(delta):
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
	if !is_instance_valid(Player) or !("entity_name" in Player):
		return
	Global.setSkillTreeNodeData(Player.entity_name, name, {
		"skill_level": skill_level,
		"can_be_dragged": can_be_dragged,
		"can_be_leveled": can_be_leveled
	})
	Global.flushSkillTreeSaves()
func loadData()->void:
	if !is_instance_valid(Player) or !("entity_name" in Player):
		return
	var data = Global.getSkillTreeNodeData(Player.entity_name, name)

	if data.has("skill_level"):
		skill_level = data["skill_level"]

	if data.has("can_be_dragged"):
		can_be_dragged = data["can_be_dragged"]

	if data.has("can_be_leveled"):
		can_be_leveled = data["can_be_leveled"]

	updateLevel()

	_initial_skill_level = skill_level
	_initial_can_be_dragged = can_be_dragged
