extends Node

var cleave = preload("res://world/interface/assets/icons/player_skills/Warriorskill_50.png")

var battlecry = preload("res://world/interface/assets/icons/player_skills/Warriorskill_48_scullhit.png")
var dodge = preload("res://world/interface/assets/icons/player_skills/Archerskill_01_poison.png")

var cooldowns = {
	cleave.get_path():3.0,
	battlecry.get_path():6.0,
	dodge.get_path():0.0
}

func getCooldown(path)->float:
	if cooldowns.has(path):
		return cooldowns[path]

	return 0.0
