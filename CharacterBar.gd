extends Control

func updateBars():
	var stats = $"../../../Stats"
	var tween = $Tween
	var energy_label = $EnergyLAbel
	var arcane_label = $ArcaneLabel
	var health_label = $HealthLabel
	var xp_label = $XPLabel
	var en_bar = $BG/EN
	var ap_bar = $BG/AP
	var hp_bar = $BG/HP
	var xp_bar = $BG/XP

	var required_experience = int(round(250.0*(1.0+pow(stats.level/10.0,1.5))))

	hp_bar.max_value = stats.max_health
	ap_bar.max_value = stats.max_arcane
	en_bar.max_value = stats.max_energy
	xp_bar.max_value = required_experience

	tween.stop_all()
	tween.interpolate_property(hp_bar,"value",hp_bar.value,stats.health,0.15,Tween.TRANS_SINE,Tween.EASE_OUT)
	tween.interpolate_property(ap_bar,"value",ap_bar.value,stats.arcane,0.15,Tween.TRANS_SINE,Tween.EASE_OUT)
	tween.interpolate_property(en_bar,"value",en_bar.value,stats.energy,0.15,Tween.TRANS_SINE,Tween.EASE_OUT)

	if stats.experience_points<xp_bar.value:
		xp_bar.value=0
	tween.interpolate_property(xp_bar,"value",xp_bar.value,stats.experience_points,0.15,Tween.TRANS_SINE,Tween.EASE_OUT)

	tween.start()

	health_label.text = str(int(stats.health)) + " / " + str(int(stats.max_health))
	arcane_label.text = str(int(stats.arcane)) + " / " + str(int(stats.max_arcane))
	energy_label.text = str(int(stats.energy)) + " / " + str(int(stats.max_energy))
	xp_label.text = str(stats.experience_points) + " / " + str(required_experience) + "  Lv." + str(stats.level)

