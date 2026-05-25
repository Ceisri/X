extends Control

var cooldowns = {
	"bite.png":301.0,
	"claw_srtrike3.png":241.0,
	"claw_strike2.png":231.0,
	"claw_strike.png":121.0,
	"hide.png":128.0
}

var haste = 1.0
onready var haste_label = $Label

var active_cooldowns = {}

onready var icons = [
	$GridContainer/Icon1,
	$GridContainer/Icon2,
	$GridContainer/Icon3,
	$GridContainer/Icon4,
	$GridContainer/Icon5,
	$GridContainer/Icon6,
	$GridContainer/Icon7,
	$GridContainer/Icon8,
	$GridContainer/Icon9,
	$GridContainer/Icon10
]

func _ready():
	loadData()

	for icon in icons:
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

	for skill in active_cooldowns.keys():
		active_cooldowns[skill] -= delta

		if active_cooldowns[skill] <= 0:
			active_cooldowns.erase(skill)

	updateLabels()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_KP_ADD:
			haste += 0.1

		elif event.scancode == KEY_KP_SUBTRACT:
			haste = max(haste - 0.1,0.0)

		elif event.scancode == KEY_1:
			useSkill(0)

		elif event.scancode == KEY_2:
			useSkill(1)

		elif event.scancode == KEY_3:
			useSkill(2)

		elif event.scancode == KEY_4:
			useSkill(3)

		elif event.scancode == KEY_5:
			useSkill(4)

		elif event.scancode == KEY_6:
			useSkill(5)

		elif event.scancode == KEY_7:
			useSkill(6)

		elif event.scancode == KEY_8:
			useSkill(7)

		elif event.scancode == KEY_9:
			useSkill(8)

		elif event.scancode == KEY_0:
			useSkill(9)

func useSkill(index):
	if index >= icons.size():
		return

	var icon = icons[index]

	if !icon.texture:
		return

	var skill = icon.texture.resource_path.get_file()

	if active_cooldowns.has(skill):
		return

	if cooldowns.has(skill):
		var final_cd = cooldowns[skill]

		if haste > 0:
			final_cd /= haste

		active_cooldowns[skill] = final_cd
		saveData()

func updateLabels():
	for icon in icons:
		var label = icon.get_node("Label")

		if !icon.texture:
			label.visible = false
			continue

		var skill = icon.texture.resource_path.get_file()

		if active_cooldowns.has(skill):
			label.visible = true
			label.text = "%.1f" % max(active_cooldowns[skill],0.0)
		else:
			label.visible = false

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
