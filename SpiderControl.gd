extends Spatial

const scene = preload("res://world/spider/spider.tscn")
const SPAWN_RANGE = 10.0
const SAVE_PASSWORD = "spider_save"
enum State {ROAM,EAT,AIR,DEAD,HUNT,FIGHT}
var spider_type = ["forest","night","autumn","purple","red"]

var textures = {
	"forest": preload("res://world/spider/texture/forest.png"),
	"night": preload("res://world/spider/texture/night.png"),
	"autumn": preload("res://world/spider/texture/autumn.png"),
	"purple": preload("res://world/spider/texture/purplesky.png"),
	"red": preload("res://world/spider/texture/red.png")
}



func _ready():
	randomize()
	loadData()

func _input(event):
	if event.is_action_pressed("add3"):
		debug()
		saveData()


func debug():
	for i in range(3):
		var spider=scene.instance()
		var offset=Vector3(rand_range(-SPAWN_RANGE,SPAWN_RANGE),0,rand_range(-SPAWN_RANGE,SPAWN_RANGE))
		spider.translation=global_transform.origin+offset
		var type=spider_type[randi()%spider_type.size()]
		create(spider,type)

func create(spider,type):
	add_child(spider)
	var mesh=spider.get_node("Armature/Skeleton/Mesh")
	var material=load("res://world/spider/spider.material").duplicate()
	if textures.has(type):
		material.albedo_texture=textures[type]
	mesh.material_override=material
	spider.set_meta("type",type)

func saveData():
	var spiders=[]
	for child in get_children():
		if child.has_meta("type"):
			var stats=child.get_node("Stats")
			spiders.append({
				"position": child.translation,
				"type": child.get_meta("type"),
				"health": stats.health,
				"target": child.target
			})

	var save_directory="user://"
	var save_path=save_directory+get_parent().name+name+".dat"
	var file=File.new()
	if file.open_encrypted_with_pass(save_path,File.WRITE,SAVE_PASSWORD)==OK:
		file.store_var(spiders)
		file.close()

func loadData():
	var save_directory="user://"
	var save_path=save_directory+get_parent().name+name+".dat"
	var file=File.new()
	if file.file_exists(save_path):
		var error=file.open_encrypted_with_pass(save_path,File.READ,SAVE_PASSWORD)
		if error==OK:
			var data=file.get_var()
			file.close()
			for saved_data in data:
				if saved_data.has("position") and saved_data.has("type"):
					var spider=scene.instance()
					spider.translation=spider_data["position"]
					create(spider,spider_data["type"])
					var stats=spider.get_node("Stats")
					if saved_data.has("health"):
						stats.health=saved_data["health"]
					if spider_data.has("target"):
						spider.target=saved_data["target"]

