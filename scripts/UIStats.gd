extends Control
#UI stats display for the player

onready var stats = $"../../../Stats"
onready var rich_text_label = $RichTextStatistics
onready var up_button = $Up
onready var down_button = $Down
onready var increase_button = $Increase
onready var decrease_button = $Decrease 
onready var selected_attribute_label = $SelectedAttributeLabel
onready var remaining_points_label = $RemainingPoints

var attribute_names = []
var selected_index = 0

func _ready():
	up_button.connect("pressed", self, "_on_up_pressed")
	down_button.connect("pressed", self, "_on_down_pressed")
	increase_button.connect("pressed", self, "_on_increase_pressed")
	decrease_button.connect("pressed", self, "_on_decrease_pressed")

	attribute_names=stats.attributes.keys()
	updateUI()

	call_deferred("saveDataBugPrevention")

func saveDataBugPrevention(): #DONT FUCKING TOUCH OR CHANGE THIS, IT'S CALLED BUGPREVENTION FOR A REASON
	for index in range(attribute_names.size()):
		selected_index=index
		decrease_button.emit_signal("pressed")
		increase_button.emit_signal("pressed")


var _ui_update_interval:int = 6
var _last_processed_visual_frame:int = -1
func _physics_process(delta):

	if !visible:
		return
	var visual_frame:int = Engine.get_frames_drawn()
	if visual_frame == _last_processed_visual_frame:
		return
	_last_processed_visual_frame = visual_frame
	if Engine.get_frames_drawn() % _ui_update_interval != 0:
		return
	updateUI()
	
	
	
func _on_up_pressed():
	updateUI()
	if attribute_names.empty():
		return
	selected_index -= 1
	if selected_index < 0:
		selected_index = attribute_names.size() - 1
	updateUI()


func _on_down_pressed():
	updateUI()
	if attribute_names.empty():
		return
	selected_index += 1
	if selected_index >= attribute_names.size():
		selected_index = 0
	updateUI()


func _on_increase_pressed():
	updateUI()
	if attribute_names.empty():
		return
	var selected = attribute_names[selected_index]
	stats.increaseAttribute(selected)
	stats.updateAttributes()

	updateUI()


func _on_decrease_pressed():
	updateUI()
	if attribute_names.empty():
		return

	var selected = attribute_names[selected_index]

	stats.decreaseAttribute(selected)
	stats.updateAttributes()

	updateUI()
const DMG_ROWS = [
		["Slash", "slash_defence", "slash_multiplier", "slash"],
		["Blunt", "blunt_defence", "blunt_multiplier", "blunt"],
		["Pierce", "pierce_defence", "pierce_multiplier", "pierce"],
		["Sonic", "sonic_defence", "sonic_multiplier", "sonic"],
		["Heat", "heat_defence", "heat_multiplier", "heat"],
		["Cold", "cold_defence", "cold_multiplier", "cold"],
		["Jolt", "jolt_defence", "jolt_multiplier", "jolt"],
		["Toxic", "toxic_defence", "toxic_multiplier", "toxic"],
		["Acid", "acid_defence", "acid_multiplier", "acid"],
		["Arcane", "arcane_defence", "arcane_multiplier", "arcane"],
		["Bleed", "bleed_defence", "bleed_multiplier", "bleed"],
		["Radiant", "radiant_defence", "radiant_multiplier", "radiant"],
	]


var _last_ui_signature := ""

func updateUI():
	if attribute_names.empty():
		return

	increase_button.disabled = stats.available_attribute_points < 1

	var selected = attribute_names[selected_index]
	selected_attribute_label.text = selected
	remaining_points_label.text = str(stats.available_attribute_points)

	# Cheap signature check: skip the whole expensive rebuild if nothing changed.
	var sig:String= str(stats.available_attribute_points) + "|" + selected + "|" \
		+ str(stats.walk_speed) + "|" + str(stats.run_speed) + "|" \
		+ str(stats.attributes.hash()) + "|" + str(stats.attributes_buff.hash()) + "|" \
		+ str(stats.equipment_attributes.hash()) + "|" + str(stats.derived_stats.hash()) + "|" \
		+ str(stats.slash_defence) + str(stats.blunt_defence) + str(stats.pierce_defence) \
		+ str(stats.sonic_defence) + str(stats.heat_defence) + str(stats.cold_defence) \
		+ str(stats.jolt_defence) + str(stats.toxic_defence) + str(stats.acid_defence) \
		+ str(stats.arcane_defence) + str(stats.bleed_defence) + str(stats.radiant_defence)

	if sig == _last_ui_signature:
		return
	_last_ui_signature = sig

	var parts := PoolStringArray()

	parts.append("walk speed:" + str(stats.walk_speed) + " base walk speed:" + str(stats.base_walk_speed))
	parts.append("run speed:" + str(stats.run_speed) + " base run speed:" + str(stats.base_run_speed))
	parts.append("[center][b]ATTRIBUTES[/b][/center]")

	for attribute in attribute_names:
		var base = stepify(stats.attributes.get(attribute, 1.0), 0.01)
		var equip = stepify(stats.equipment_attributes.get(attribute, 0.0), 0.01)
		var buff = stepify(stats.attributes_buff.get(attribute, 0.0), 0.01)
		var total = stepify(base + equip + buff, 0.01)

		var line = attribute + ": " + str(total) + " (" + str(base)
		if equip != 0: line += " + " + str(equip)
		if buff != 0: line += " + " + str(buff)
		line += ")"

		if attribute == selected:
			parts.append("[color=yellow]> " + line + "[/color]")
		else:
			parts.append(line)

	parts.append("")
	parts.append("[center][b]DERIVED STATS[/b][/center]")

	for stat_name in stats.derived_stats:
		parts.append(stat_name + ": " + str(stepify(float(stats.derived_stats[stat_name]), 0.01)))

	parts.append("")
	parts.append("DAMAGE MULTIPLIERS")


	for row in DMG_ROWS:
		var flat = stats.flat_damage_bonus.get(row[3], 0.0) + stats.damage_flat_modifier.get(row[3], 0.0)
		parts.append(row[0] + ": " + str(stats.mitPercent(stats.get(row[1]))) + "%  | ATK: " \
			+ str(stepify(stats.get(row[2]), 0.01) * 100.0) + "%  | Flat: " + str(flat))

	parts.append("")
	parts.append("[center[b]DEFENCES[/b][/center]")

	for row in DMG_ROWS:
		parts.append(row[0] + ": " + str(stats.mitPercent(stats.get(row[1]))) + "%")

	rich_text_label.bbcode_text = parts.join("\n")
