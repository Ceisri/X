extends Control



var haste = 1.0
var active_cooldowns = {}

onready var haste_label = $Label
onready var grid = $GridContainer

func _ready():
	loadData()
	test(grid)

func test(grid):
	for icon in grid.get_children():
		if icon.has_node("Label"):
			icon.get_node("Label").visible = false

func _process(delta):
	haste_label.text = "Haste %.1f" % haste

	if Input.is_action_just_pressed("haste_test1"):
		haste += 0.1

	elif Input.is_action_just_pressed("haste_test2"):
		haste = max(haste - 0.1,0.0)

	elif Input.is_action_just_pressed("haste_test3"):
		haste = 50

	elif Input.is_action_just_pressed("haste_test4"):
		haste = 0

	if Input.is_action_just_pressed("1"):
		Skills.useSkill(0,grid,active_cooldowns,haste,self)

	elif Input.is_action_just_pressed("2"):
		Skills.useSkill(1,grid,active_cooldowns,haste,self)

	elif Input.is_action_just_pressed("3"):
		Skills.useSkill(2,grid,active_cooldowns,haste,self)

	elif Input.is_action_just_pressed("4"):
		Skills.useSkill(3,grid,active_cooldowns,haste,self)

	elif Input.is_action_just_pressed("5"):
		Skills.useSkill(4,grid,active_cooldowns,haste,self)

	elif Input.is_action_just_pressed("6"):
		Skills.useSkill(5,grid,active_cooldowns,haste,self)

	elif Input.is_action_just_pressed("7"):
		Skills.useSkill(6,grid,active_cooldowns,haste,self)

	elif Input.is_action_just_pressed("8"):
		Skills.useSkill(7,grid,active_cooldowns,haste,self)

	elif Input.is_action_just_pressed("9"):
		Skills.useSkill(8,grid,active_cooldowns,haste,self)

	elif Input.is_action_just_pressed("0"):
		Skills.useSkill(9,grid,active_cooldowns,haste,self)

	for skill in active_cooldowns.keys():
		active_cooldowns[skill] -= delta

		if active_cooldowns[skill] <= 0:
			active_cooldowns.erase(skill)

	Skills.updateLabels($GridContainer,active_cooldowns)

func saveData():
	var saveDirectory = "user://" + name + "/"
	var savePath = saveDirectory + name + ".save"
	var dir = Directory.new()

	if !dir.dir_exists(saveDirectory):
		dir.make_dir_recursive(saveDirectory)

	var file = File.new()

	if file.open(savePath,File.WRITE) == OK:
		file.store_var({
			"cooldowns":active_cooldowns,
			"haste":haste
		})
		file.close()

func loadData():
	var saveDirectory = "user://" + name + "/"
	var savePath = saveDirectory + name + ".save"
	var file = File.new()

	if file.file_exists(savePath):
		if file.open(savePath,File.READ) == OK:
			var data = file.get_var()

			active_cooldowns = data.get("cooldowns",{})
			haste = data.get("haste",1.0)

			file.close()
