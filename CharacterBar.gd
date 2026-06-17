extends Control

onready var stats = $"../../../Stats"

onready var hpBar = $BG/HP
onready var apBar = $BG/AP

onready var healthLabel = $HealthLabel 
onready var arcaneLabel = $ArcaneLabel
onready var tween = $Tween




func updateBars():
	hpBar.max_value = stats.max_health
	apBar.max_value = stats.max_energy

	tween.stop_all()

	tween.interpolate_property(hpBar,"value",hpBar.value,stats.health,0.3,Tween.TRANS_SINE,Tween.EASE_OUT)

	tween.interpolate_property(apBar,"value",apBar.value,stats.energy,0.3,Tween.TRANS_SINE,Tween.EASE_OUT)

	tween.start()

	healthLabel.text = str(int(stats.health)) + " / " + str(int(stats.max_health))
	arcaneLabel.text = str(int(stats.energy)) + " / " + str(int(stats.max_energy))


