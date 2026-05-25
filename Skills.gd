extends Node

var cooldowns = {
	"bite.png":1,
	"claw_srtrike3.png":3,
	"claw_strike2.png":6,
	"claw_strike.png":9,
	"hide.png":12,
	"trail_strike1.png":15,
	"poison_claw.png":18,
	"bear.png":21,
	"bear_red.png":24,
	"claw.png":27
}
var skill_anims = {
	"bite.png":"atk1",
	"claw_srtrike3.png":"atk2",
	"claw_strike2.png":"atk3",
	"claw_strike.png":"atk4",
	"hide.png":"prepare",
	"trail_strike1.png":"atk1",
	"poison_claw.png":"atk2",
	"bear.png":"atk1",
	"bear_red.png":"atk2",
	"claw.png":"atk3"
}


var species_skills = {
	"wolf":[
		"bite.png",
		"claw_srtrike3.png",
		"claw_strike2.png",
		"claw_strike.png",
		"hide.png",
		"poison_claw.png",
		"trail_strike1.png"
	],

	"bear":[
		"bear.png",
		"bear_red.png",
		"claw.png"
	]
}

func getSpeciesSkills(species):
	return species_skills.get(species,[])

func getSkillPath(skill):
	match skill:
		"bear.png","bear_red.png","claw.png":
			return "res://world/interface/assets/icons/mobs/bear/" + skill

	return "res://world/interface/assets/icons/mobs/generic/" + skill




func useSkill(index,grid,active_cooldowns,haste,caller):
	var icons = grid.get_children()

	if index >= icons.size():
		return

	var icon = icons[index]

	if !icon.texture:
		return

	useSkillName(icon.texture.resource_path.get_file(),active_cooldowns,haste,caller)

func useSkillName(skill,active_cooldowns,haste,caller):
	if active_cooldowns.has(skill):
		return false

	if !cooldowns.has(skill):
		return false

	var final_cd = cooldowns[skill]

	if haste > 0:
		final_cd /= haste

	active_cooldowns[skill] = final_cd

	if caller.has_method("saveData"):
		caller.saveData()

	return true

func canUseSkill(skill,active_cooldowns):
	return cooldowns.has(skill) and !active_cooldowns.has(skill)

func getCooldown(skill):
	if cooldowns.has(skill):
		return cooldowns[skill]

	return 0

func getAnim(skill):
	if skill_anims.has(skill):
		return skill_anims[skill]

	return "prepare"

func updateLabels(grid,active_cooldowns):
	for icon in grid.get_children():
		if !icon.has_node("Label"):
			continue

		var label = icon.get_node("Label")

		if !icon.texture:
			label.visible = false
			continue

		var skill = icon.texture.resource_path.get_file()

		if active_cooldowns.has(skill):
			label.visible = true
			label.text = str(int(ceil(max(active_cooldowns[skill],0))))
		else:
			label.visible = false
