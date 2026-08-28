extends ClippedCamera

onready var water_screen=$"../../../../UI/WaterScreen"
onready var detector=$CameraWaterDetecter

func _ready():
	detector.connect("area_entered",self,"_updateWater")
	detector.connect("area_exited",self,"_updateWater")
	_updateWater()

func _updateWater(_area=null):
	if !water_screen: 
		return
	water_screen.visible=false
	for area in detector.get_overlapping_areas():
		var name=area.name.to_lower()
		if name=="water" or name=="ocean" or area.is_in_group("Water") or area.is_in_group("water"):
			water_screen.visible=true
			return
