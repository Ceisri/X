extends Spatial

const HORSE_SCENE = preload("res://world/horse/horse.tscn")
const WOLF_SCENE = preload("res://world/horse/placeholder.tscn")
const SPIDER_SCENE = preload("res://world/spider/spider.tscn")
const MOVE_SPEED = 2.0
const SPAWN_RANGE = 10.0
const SAVE_PATH = "user://mobs.save"

onready var mov_node = $State
onready var state_node = $State
onready var spawn_node = $Spawner



func _ready():
	randomize()
	loadData()

func _process(delta):
	if Engine.get_physics_frames() % 900 == 0:
		saveData()
	for mob in get_children():
		if mob.is_in_group("Entity"):
			state_node.stateMachine(mob)
			CommonBehaviours.gravity(mob)
			updateLabel(mob)

func _input(event):
	var randomHealth = randi() % 101 + 100
	if event.is_action_pressed("add"):
		saveData()
		spawn_node.spawn(HORSE_SCENE,null,"",100,randomHealth)
	if event.is_action_pressed("add2"):
		saveData()
		spawn_node.spawn(WOLF_SCENE,null,"",100,randomHealth)
	if event.is_action_pressed("add3"):
		saveData()

		var mob = spawn_node.spawn(
			SPIDER_SCENE,
			null,
			"",
			100,
			randomHealth
		)

		var dir = Directory.new()
		var palettes = []
		var texture_folder = "res://world/%s/texture" % mob.stats.species

		if dir.open(texture_folder) == OK:
			dir.list_dir_begin(true, true)

			var file = dir.get_next()

			while file != "":
				if file.ends_with(".png"):
					palettes.append(file.get_basename())

				file = dir.get_next()

			dir.list_dir_end()

		if palettes.size() > 0:
			mob.stats.palette = palettes[randi() % palettes.size()]
			mob.stats.switchPalette()


func updateLabel(mob):
	var label = mob.get_node("Name")
	var stats = mob.get_node("Stats")
	var mobName = stats.Name
	var nutrition = stats.nutrition
	var health = stats.health
	var state = mob.get_meta("state")
	label.text = (mobName+ " | HP:"+ str(health)+ " | N:"+ str(nutrition)+ " | "+ str(state))

func saveData():

	var saveDirectory = "user://" + name + "/"
	var savePath = saveDirectory + name + ".save"

	var dir = Directory.new()

	if !dir.dir_exists(saveDirectory):
		dir.make_dir_recursive(saveDirectory)

	var mobsData = []

	for mob in get_children():

		if mob.is_in_group("Entity"):

			var stats = mob.get_node("Stats")

			var aggro_data = []

			for aggro_target in mob.targets:

				if is_instance_valid(aggro_target.target_entity):

					aggro_data.append({
						"target_name": aggro_target.target_entity.save_id,
						"aggro": aggro_target.aggro})
			mobsData.append({
				"scene": mob.filename,
				"finished": stats.is_finished,
				"palette": stats.palette,
				"position": mob.translation,
				"name": stats.Name,
				"nutrition": stats.nutrition,
				"health": stats.health,
				"aggro": aggro_data
			})

	var file = File.new()

	if file.open(savePath,File.WRITE) == OK:

		file.store_var({
			"mobs": mobsData
		})

		file.close()
func loadData():

	var saveDirectory = "user://" + name + "/"
	var savePath = saveDirectory + name + ".save"

	var file = File.new()

	if !file.file_exists(savePath):
		return

	if file.open(savePath,File.READ) == OK:

		var data = file.get_var()

		file.close()

		if data.has("mobs"):

			var loaded_mobs = []

			for mobData in data["mobs"]:
				var scene = load(mobData["scene"])

				var mob = spawn_node.spawn(
					scene,
					mobData["position"],
					mobData["name"],
					mobData.get("nutrition",100),
					mobData.get("health",100),
					mobData.get("finished",false)
				)

				if mobData.has("palette"):
					mob.stats.palette = mobData["palette"]
					mob.stats.switchPalette()

				loaded_mobs.append({
					"mob": mob,
					"aggro": mobData.get("aggro",[])
				})
			for entry in loaded_mobs:
				var mob = entry.mob
				for saved_aggro in entry.aggro:
					for node in get_tree().get_nodes_in_group("Entity"):
						if node.has_method("get"):
							if node.get("save_id") == saved_aggro.target_name:
								var aggro_target = mob.get_or_create_aggro_target(node)
								aggro_target.aggro = saved_aggro.aggro
								print(
									mob.name,
									" restored ",
									aggro_target.aggro,
									" -> ",
									node.save_id
								)
