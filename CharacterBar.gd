extends Control

onready var stats = $"../../../Stats"

onready var hpBar = $BG/HP
onready var apBar = $BG/AP

onready var healthLabel = $HealthLabel 
onready var arcaneLabel = $ArcaneLabel


func _ready():
	updateBars()

	stats.connect("health_changed", self, "onHealthChanged")
	stats.connect("arcane_changed", self, "onArcaneChanged")


func onHealthChanged(value = null):
	hpBar.max_value = stats.max_health
	hpBar.value = stats.health

	healthLabel.text = str(int(stats.health)) + " / " + str(int(stats.max_health))


func onArcaneChanged(value = null):
	apBar.max_value = stats.max_arcane
	apBar.value = stats.arcane

	arcaneLabel.text = str(int(stats.arcane)) + " / " + str(int(stats.max_arcane))


func updateBars(value = null):
	onHealthChanged()
	onArcaneChanged()
