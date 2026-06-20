extends Control
func _ready()->void:
	#$Close.connect("pressed",self,"collapse")
	$Tools/ToolGrid/Combine.connect("pressed",self,"combinePressed")
