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

	attribute_names=stats.attributes.keys()
	updateUI()

	call_deferred("saveDataBugPrevention")

func saveDataBugPrevention():
	for index in range(attribute_names.size()):
		selected_index=index
		decrease_button.emit_signal("pressed")
		increase_button.emit_signal("pressed")


func _process(_delta):
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


func updateUI():
	if attribute_names.empty():
		return

	increase_button.disabled=stats.available_attribute_points<1

	var selected=attribute_names[selected_index]
	selected_attribute_label.text=selected
	remaining_points_label.text=str(stats.available_attribute_points)

	var text=""
	text+="walk speed:"+ str(stats.walk_speed) + " base walk speed:"+ str(stats.base_walk_speed)
	text+="run speed:"+ str(stats.run_speed) + " base run speed:"+ str(stats.base_run_speed)
	text+="[center][b]ATTRIBUTES[/b][/center]\n"

	for attribute in attribute_names:
		var base=stepify(stats.attributes.get(attribute,1.0),0.01)
		var equip=stepify(stats.equipment_attributes.get(attribute,0.0),0.01)
		var buff=stepify(stats.attributes_buff.get(attribute,0.0),0.01)
		var total=stepify(base+equip+buff,0.01)

		var line=attribute+": "+str(total)+" ("+str(base)
		if equip!=0: line+=" + "+str(equip)
		if buff!=0: line+=" + "+str(buff)
		line+=")"

		if attribute==selected:
			text+="[color=yellow]> "+line+"[/color]\n"
		else:
			text+=line+"\n"

	text+="\n[center][b]DERIVED STATS[/b][/center]\n"

	for stat_name in stats.derived_stats:
		text+=stat_name+": "+str(stepify(float(stats.derived_stats[stat_name]),0.01))+"\n"

	text+="\nDAMAGE MULTIPLIERS\n"

	text += "Slash: " + str(stats.mitPercent(stats.slash_defence)) + "%  | ATK: " + str(stepify(stats.slash_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("slash",0.0) + stats.damage_flat_modifier.get("slash",0.0)) + "\n"
	text += "Blunt: " + str(stats.mitPercent(stats.blunt_defence)) + "%  | ATK: " + str(stepify(stats.blunt_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("blunt",0.0) + stats.damage_flat_modifier.get("blunt",0.0)) + "\n"
	text += "Pierce: " + str(stats.mitPercent(stats.pierce_defence)) + "%  | ATK: " + str(stepify(stats.pierce_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("pierce",0.0) + stats.damage_flat_modifier.get("pierce",0.0)) + "\n"
	text += "Sonic: " + str(stats.mitPercent(stats.sonic_defence)) + "%  | ATK: " + str(stepify(stats.sonic_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("sonic",0.0) + stats.damage_flat_modifier.get("sonic",0.0)) + "\n"
	text += "Heat: " + str(stats.mitPercent(stats.heat_defence)) + "%  | ATK: " + str(stepify(stats.heat_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("heat",0.0) + stats.damage_flat_modifier.get("heat",0.0)) + "\n"
	text += "Cold: " + str(stats.mitPercent(stats.cold_defence)) + "%  | ATK: " + str(stepify(stats.cold_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("cold",0.0) + stats.damage_flat_modifier.get("cold",0.0)) + "\n"
	text += "Jolt: " + str(stats.mitPercent(stats.jolt_defence)) + "%  | ATK: " + str(stepify(stats.jolt_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("jolt",0.0) + stats.damage_flat_modifier.get("jolt",0.0)) + "\n"
	text += "Toxic: " + str(stats.mitPercent(stats.toxic_defence)) + "%  | ATK: " + str(stepify(stats.toxic_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("toxic",0.0) + stats.damage_flat_modifier.get("toxic",0.0)) + "\n"
	text += "Acid: " + str(stats.mitPercent(stats.acid_defence)) + "%  | ATK: " + str(stepify(stats.acid_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("acid",0.0) + stats.damage_flat_modifier.get("acid",0.0)) + "\n"
	text += "Arcane: " + str(stats.mitPercent(stats.arcane_defence)) + "%  | ATK: " + str(stepify(stats.arcane_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("arcane",0.0) + stats.damage_flat_modifier.get("arcane",0.0)) + "\n"
	text += "Bleed: " + str(stats.mitPercent(stats.bleed_defence)) + "%  | ATK: " + str(stepify(stats.bleed_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("bleed",0.0) + stats.damage_flat_modifier.get("bleed",0.0)) + "\n"
	text += "Radiant: " + str(stats.mitPercent(stats.radiant_defence)) + "%  | ATK: " + str(stepify(stats.radiant_multiplier,0.01) * 100.0) + "%  | Flat: " + str(stats.flat_damage_bonus.get("radiant",0.0) + stats.damage_flat_modifier.get("radiant",0.0)) + "\n"
	text+="\n[center[b]DEFENCES[/b][/center]\n"

	text+="Slash: "+str(stats.mitPercent(stats.slash_defence))+"%\n"
	text+="Blunt: "+str(stats.mitPercent(stats.blunt_defence))+"%\n"
	text+="Pierce: "+str(stats.mitPercent(stats.pierce_defence))+"%\n"
	text+="Sonic: "+str(stats.mitPercent(stats.sonic_defence))+"%\n"
	text+="Heat: "+str(stats.mitPercent(stats.heat_defence))+"%\n"
	text+="Cold: "+str(stats.mitPercent(stats.cold_defence))+"%\n"
	text+="Jolt: "+str(stats.mitPercent(stats.jolt_defence))+"%\n"
	text+="Toxic: "+str(stats.mitPercent(stats.toxic_defence))+"%\n"
	text+="Acid: "+str(stats.mitPercent(stats.acid_defence))+"%\n"
	text+="Arcane: "+str(stats.mitPercent(stats.arcane_defence))+"%\n"
	text+="Bleed: "+str(stats.mitPercent(stats.bleed_defence))+"%\n"
	text+="Radiant: "+str(stats.mitPercent(stats.radiant_defence))+"%\n"
	rich_text_label.bbcode_text=text

