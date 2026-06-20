extends Control


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

	attribute_names = stats.attributes.keys()

	updateUI()

func _process(delta):
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


#func updateUI():
#	if attribute_names.empty():
#		return
#
#	increase_button.disabled = stats.available_attribute_points < 1
#
#	var selected = attribute_names[selected_index]
#
#	selected_attribute_label.text = selected
#	remaining_points_label.text = str(stats.available_attribute_points)
#
#	var text = ""
#
#	# ATTRIBUTES
#	text += "[center][b]ATTRIBUTES[/b][/center]\n"
#
#	for attribute in attribute_names:
#		var base=stepify(stats.attributes.get(attribute,1.0),0.01)
#		var equip=stepify(stats.equipment_attributes.get(attribute,0.0),0.01)
#		var total=stepify(base+equip,0.01)
#
#		var line=attribute+": "+str(total)+" ("+str(base)
#
#		if equip!=0:
#			line+=" + "+str(equip)
#
#		line+=")"
#
#		if attribute==selected:
#			text+="[color=yellow]> "+line+"[/color]\n"
#		else:
#			text+=line+"\n"
#
#	# DERIVED STATS
#	text += "\n[center][b]DERIVED STATS[/b][/center]\n"
#
#	for stat_name in stats.derived_stats:
#		var value=stepify(float(stats.derived_stats[stat_name]),0.01)
#
#		if stat_name=="max_health":
#			text+=stat_name+": "+str(value)+" (+"+str(stepify(stats.equipment_max_health,0.01))+")\n"
#		else:
#			text+=stat_name+": "+str(value)+"\n"
#
#	text += "\n[center][b]DAMAGE MULTIPLIERS[/b][/center]\n"
#
#	text += "Slash: x" + str(stepify(stats.slash_multiplier,0.01)) + "\n"
#	text += "Blunt: x" + str(stepify(stats.blunt_multiplier,0.01)) + "\n"
#	text += "Pierce: x" + str(stepify(stats.pierce_multiplier,0.01)) + "\n"
#	text += "Sonic: x" + str(stepify(stats.sonic_multiplier,0.01)) + "\n"
#	text += "Heat: x" + str(stepify(stats.heat_multiplier,0.01)) + "\n"
#	text += "Cold: x" + str(stepify(stats.cold_multiplier,0.01)) + "\n"
#	text += "Jolt: x" + str(stepify(stats.jolt_multiplier,0.01)) + "\n"
#	text += "Toxic: x" + str(stepify(stats.toxic_multiplier,0.01)) + "\n"
#	text += "Acid: x" + str(stepify(stats.acid_multiplier,0.01)) + "\n"
#	text += "Arcane: x" + str(stepify(stats.arcane_multiplier,0.01)) + "\n"
#	text += "Bleed: x" + str(stepify(stats.bleed_multiplier,0.01)) + "\n"
#	text += "Radiant: x" + str(stepify(stats.radiant_multiplier,0.01)) + "\n"
#
#	# DEFENCES
#	text += "\n[center][b]DEFENCES[/b][/center]\n"
#
#	var d=0.0
#
#	d=stats.slash_defence/(stats.slash_defence+45.0)*100.0
#	text += "Slash: " + str(stepify(d,0.01)) + "%\n"
#
#	d=stats.blunt_defence/(stats.blunt_defence+45.0)*100.0
#	text += "Blunt: " + str(stepify(d,0.01)) + "%\n"
#
#	d=stats.pierce_defence/(stats.pierce_defence+45.0)*100.0
#	text += "Pierce: " + str(stepify(d,0.01)) + "%\n"
#
#	d=stats.sonic_defence/(stats.sonic_defence+45.0)*100.0
#	text += "Sonic: " + str(stepify(d,0.01)) + "%\n"
#
#	d=stats.heat_defence/(stats.heat_defence+45.0)*100.0
#	text += "Heat: " + str(stepify(d,0.01)) + "%\n"
#
#	d=stats.cold_defence/(stats.cold_defence+45.0)*100.0
#	text += "Cold: " + str(stepify(d,0.01)) + "%\n"
#
#	d=stats.jolt_defence/(stats.jolt_defence+45.0)*100.0
#	text += "Jolt: " + str(stepify(d,0.01)) + "%\n"
#
#	d=stats.toxic_defence/(stats.toxic_defence+45.0)*100.0
#	text += "Toxic: " + str(stepify(d,0.01)) + "%\n"
#
#	d=stats.acid_defence/(stats.acid_defence+45.0)*100.0
#	text += "Acid: " + str(stepify(d,0.01)) + "%\n"
#
#	d=stats.arcane_defence/(stats.arcane_defence+45.0)*100.0
#	text += "Arcane: " + str(stepify(d,0.01)) + "%\n"
#
#	d=stats.bleed_defence/(stats.bleed_defence+45.0)*100.0
#	text += "Bleed: " + str(stepify(d,0.01)) + "%\n"
#
#	d=stats.radiant_defence/(stats.radiant_defence+45.0)*100.0
#	text += "Radiant: " + str(stepify(d,0.01)) + "%\n"
#
#	rich_text_label.bbcode_text = text
func updateUI():
	if attribute_names.empty():
		return

	increase_button.disabled = stats.available_attribute_points < 1

	var selected = attribute_names[selected_index]

	selected_attribute_label.text = selected
	remaining_points_label.text = str(stats.available_attribute_points)

	var text = ""

	text += "[center][b]ATTRIBUTES[/b][/center]\n"

	for attribute in attribute_names:
		var base=stepify(stats.attributes.get(attribute,1.0),0.01)
		var equip=stepify(stats.equipment_attributes.get(attribute,0.0),0.01)
		var buff=stepify(stats.attributes_buff.get(attribute,0.0),0.01)
		var total=stepify(base+equip+buff,0.01)

		var line=attribute+": "+str(total)+" ("+str(base)

		if equip!=0:line+=" + "+str(equip)
		if buff!=0:line+=" + "+str(buff)

		line+=")"

		if attribute==selected:
			text+="[color=yellow]> "+line+"[/color]\n"
		else:
			text+=line+"\n"

	text += "\n[center][b]DERIVED STATS[/b][/center]\n"

	for stat_name in stats.derived_stats:
		var value=stepify(float(stats.derived_stats[stat_name]),0.01)
		text+=stat_name+": "+str(value)+"\n"

	text += "\n[center][b]DAMAGE MULTIPLIERS[/b][/center]\n"

	text += "Slash: x" + str(stepify(stats.slash_multiplier,0.01)) + "\n"
	text += "Blunt: x" + str(stepify(stats.blunt_multiplier,0.01)) + "\n"
	text += "Pierce: x" + str(stepify(stats.pierce_multiplier,0.01)) + "\n"
	text += "Sonic: x" + str(stepify(stats.sonic_multiplier,0.01)) + "\n"
	text += "Heat: x" + str(stepify(stats.heat_multiplier,0.01)) + "\n"
	text += "Cold: x" + str(stepify(stats.cold_multiplier,0.01)) + "\n"
	text += "Jolt: x" + str(stepify(stats.jolt_multiplier,0.01)) + "\n"
	text += "Toxic: x" + str(stepify(stats.toxic_multiplier,0.01)) + "\n"
	text += "Acid: x" + str(stepify(stats.acid_multiplier,0.01)) + "\n"
	text += "Arcane: x" + str(stepify(stats.arcane_multiplier,0.01)) + "\n"
	text += "Bleed: x" + str(stepify(stats.bleed_multiplier,0.01)) + "\n"
	text += "Radiant: x" + str(stepify(stats.radiant_multiplier,0.01)) + "\n"

	text += "\n[center][b]DEFENCES[/b][/center]\n"

	var d=0.0

	d=stats.slash_defence/(stats.slash_defence+45.0)*100.0
	text+="Slash: "+str(stepify(d,0.01))+"%\n"

	d=stats.blunt_defence/(stats.blunt_defence+45.0)*100.0
	text+="Blunt: "+str(stepify(d,0.01))+"%\n"

	d=stats.pierce_defence/(stats.pierce_defence+45.0)*100.0
	text+="Pierce: "+str(stepify(d,0.01))+"%\n"

	d=stats.sonic_defence/(stats.sonic_defence+45.0)*100.0
	text+="Sonic: "+str(stepify(d,0.01))+"%\n"

	d=stats.heat_defence/(stats.heat_defence+45.0)*100.0
	text+="Heat: "+str(stepify(d,0.01))+"%\n"

	d=stats.cold_defence/(stats.cold_defence+45.0)*100.0
	text+="Cold: "+str(stepify(d,0.01))+"%\n"

	d=stats.jolt_defence/(stats.jolt_defence+45.0)*100.0
	text+="Jolt: "+str(stepify(d,0.01))+"%\n"

	d=stats.toxic_defence/(stats.toxic_defence+45.0)*100.0
	text+="Toxic: "+str(stepify(d,0.01))+"%\n"

	d=stats.acid_defence/(stats.acid_defence+45.0)*100.0
	text+="Acid: "+str(stepify(d,0.01))+"%\n"

	d=stats.arcane_defence/(stats.arcane_defence+45.0)*100.0
	text+="Arcane: "+str(stepify(d,0.01))+"%\n"

	d=stats.bleed_defence/(stats.bleed_defence+45.0)*100.0
	text+="Bleed: "+str(stepify(d,0.01))+"%\n"

	d=stats.radiant_defence/(stats.radiant_defence+45.0)*100.0
	text+="Radiant: "+str(stepify(d,0.01))+"%\n"

	rich_text_label.bbcode_text=text
