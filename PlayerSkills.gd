extends Node

var skills = {
	"cleave":preload("res://world/interface/assets/icons/player_skills/Warriorskill_50.png"),
	"battlecry":preload("res://world/interface/assets/icons/player_skills/Warriorskill_48_scullhit.png"),
	"dodge":preload("res://world/interface/assets/icons/player_skills/Archerskill_01_poison.png")
}
var descriptions = {
	"cleave":"Hits all enemies in front of you.",
	"battlecry":"Increases combat effectiveness.",
	"dodge":"Avoid the next attack."
}
var cooldowns = {
	skills["cleave"].resource_path:3.0,
	skills["battlecry"].resource_path:6.0,
	skills["dodge"].resource_path:0.0
}
func getCooldown(path)->float:
	if cooldowns.has(path):
		return cooldowns[path]

	return 0.0


var skill_energy_cost = {

	"cleave": 3,
	"battlecry": 15,
}

func getEnergyCost(skill:String) -> float:
	return skill_energy_cost.get(skill, 0)
