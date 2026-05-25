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

var skill_damage = {
	"bite.png":10,
	"claw_srtrike3.png":14,
	"claw_strike2.png":18,
	"claw_strike.png":24,
	"hide.png":0,
	"trail_strike1.png":12,
	"poison_claw.png":16,
	"bear.png":20,
	"bear_red.png":28,
	"claw.png":22
}


var skill_stun = {
	"bite.png":false,
	"claw_srtrike3.png":false,
	"claw_strike2.png":false,
	"claw_strike.png":false,
	"hide.png":false,
	"trail_strike1.png":false,
	"poison_claw.png":false,
	"bear.png":false,
	"bear_red.png":false,
	"claw.png":false
}

var skill_lifesteal = {
	"bite.png":true,
	"claw_srtrike3.png":false,
	"claw_strike2.png":false,
	"claw_strike.png":false,
	"hide.png":false,
	"trail_strike1.png":false,
	"poison_claw.png":false,
	"bear.png":false,
	"bear_red.png":false,
	"claw.png":false
}

var skill_lifesteal_power = {
	"bite.png":1,
	"claw_srtrike3.png":0.0,
	"claw_strike2.png":0.0,
	"claw_strike.png":0.0,
	"hide.png":0.0,
	"trail_strike1.png":0.0,
	"poison_claw.png":0.0,
	"bear.png":0.0,
	"bear_red.png":0.0,
	"claw.png":0.0
}


var skill_cd_reduce = {

	"claw_srtrike3.png":false,
	"claw_strike2.png":false,
	"claw_strike.png":false,
	"hide.png":false,
	"trail_strike1.png":false,
	"poison_claw.png":false,
	"bear.png":false,
	"bear_red.png":false,
	"claw.png":false
}

var skill_cd_reduce_power = {

	"claw_srtrike3.png":0.0,
	"claw_strike2.png":0.0,
	"claw_strike.png":0.0,
	"hide.png":0.0,
	"trail_strike1.png":0.0,
	"poison_claw.png":0.0,
	"bear.png":0.0,
	"bear_red.png":0.0,
	"claw.png":0.0
}

func isCooldownReduce(skill):
	return skill_cd_reduce.get(skill,false)

func getCooldownReducePower(skill):
	return skill_cd_reduce_power.get(skill,0.0)


func isStun(skill):
	return skill_stun.get(skill,false)

func isLifesteal(skill):
	return skill_lifesteal.get(skill,false)

func getLifestealPower(skill):
	return skill_lifesteal_power.get(skill,0.0)



var support_skills = [
	"hide.png"
]

func getDamage(skill):
	return skill_damage.get(skill,0)

func isAttack(skill):
	return !support_skills.has(skill)

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
