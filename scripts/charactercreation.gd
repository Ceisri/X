extends Spatial #charactercreation.gd 









# ===== MISSING ONREADY DECLARATIONS (ADDED) =====
onready var createNewCharacterButton = $Control/CreateNewCharacterButton
onready var selectedSpeciesLabel = $Control/RaceSlider/SelectedSpeciesLabel
onready var goBackButton = $Control/GoBack
onready var serverButton:TextureButton = $Control/ServerButton
onready var serverButtonLabel:Label = $Control/ServerButton/Label
onready var offlinePlayButton = $Control/OfflinePlayButton
onready var tween:Tween = $Control/Tween
onready var offline_button_label:Label = $Control/OfflinePlayButton/Label

var server_online := false
onready var status_timer := Timer.new()
var is_probing := false
const PROBE_INTERVAL := 5.0
const PROBE_TIMEOUT := 3.0
# ===== ORIGINAL ONREADY DECLARATIONS =====
onready var gridContainer = $Control/ScrollContainer/GridContainer
onready var createButton = $Control/CompleteCreateButton

onready var line_edit = $Control/LineEdit
onready var buttonTemplate = $Control/ScrollContainer/GridContainer/TextureButton
onready var selected_player_label = $Control/LabelSelected
onready var selected_sex_label =  $Control/LabelSelectedSex
onready var podium = $Podium
onready var changeSexButton = $Control/ChangeSexButton
onready var popup = $Control/PopUp
onready var confirmButton = $Control/PopUp/Confirm
onready var regretButton = $Control/PopUp/Regret

onready var raceSlider = $Control/RaceSlider
onready var humanButton = $Control/RaceSlider/HumanButton
onready var kragunButton = $Control/RaceSlider/KragunButton

# ===== HAIR CUSTOMIZATION =====
var deleteCharacterButton = null
onready var nextHair= $Control/CharacterCustomizationControl/GridContainerHair/SelectHairstyle/IncreaseButton
onready var prevHair= $Control/CharacterCustomizationControl/GridContainerHair/SelectHairstyle/DecreaseButton
onready var hairstyle_label=  $Control/CharacterCustomizationControl/GridContainerHair/SelectHairstyle/Label

var hairIndex={}
var hairs={
	"male":[
		"res://world/player/human/male/hair/1.tscn",
		"res://world/player/human/male/hair/2.tscn",
		"res://world/player/human/male/hair/3.tscn"],
	"female":[
		"res://world/player/human/female/hair/1.tscn",
		"res://world/player/human/female/hair/2.tscn",
		"res://world/player/human/female/hair/3.tscn"]}

onready var next_hair_texture_button =  $Control/CharacterCustomizationControl/GridContainerHair/HairTexture/IncreaseButton
onready var prev_hair_texture_button =  $Control/CharacterCustomizationControl/GridContainerHair/HairTexture/DecreaseButton

var hair_texture_index={}
var hair_textures={
	"male":[#placeholder
		"res://world/player/human/female/hair/textures/hair1fem.png",
		"res://world/player/human/female/hair/textures/hair1fem_dark.png",
		"res://world/player/human/female/hair/textures/hair1fem_darker.png",
		"res://world/player/human/female/hair/textures/hair1fem_darkest.png",
		"res://world/player/human/female/hair/textures/hair2fem.png",
		"res://world/player/human/female/hair/textures/hair2fem_dark.png",
		"res://world/player/human/female/hair/textures/hair2fem_darker.png",
		"res://world/player/human/female/hair/textures/hair2fem_darkest.png",
		"res://world/player/human/female/hair/textures/hair3fem.png",
		"res://world/player/human/female/hair/textures/hair3fem_dark.png",
		"res://world/player/human/female/hair/textures/hair3fem_darker.png",
		"res://world/player/human/female/hair/textures/hair3fem_darkest.png",
		],
	"female":[
		"res://world/player/human/female/hair/textures/hair1fem.png",
		"res://world/player/human/female/hair/textures/hair1fem_dark.png",
		"res://world/player/human/female/hair/textures/hair1fem_darker.png",
		"res://world/player/human/female/hair/textures/hair1fem_darkest.png",
		"res://world/player/human/female/hair/textures/hair2fem.png",
		"res://world/player/human/female/hair/textures/hair2fem_dark.png",
		"res://world/player/human/female/hair/textures/hair2fem_darker.png",
		"res://world/player/human/female/hair/textures/hair2fem_darkest.png",
		"res://world/player/human/female/hair/textures/hair3fem.png",
		"res://world/player/human/female/hair/textures/hair3fem_dark.png",
		"res://world/player/human/female/hair/textures/hair3fem_darker.png",
		"res://world/player/human/female/hair/textures/hair3fem_darkest.png",]}

onready var hair_texture_label:Label= $Control/CharacterCustomizationControl/GridContainerHair/HairTexture/Label
onready var hairColorPicker:ColorPicker= $Control/CharacterCustomizationControl/GridContainerHair/ColorPicker
var hairColors={} 

# ===== SCENE CACHE =====
var sceneCache = {}

# ===== STATE VARIABLES =====
var selected_player_name = ""
var selected_sex = "male"
var playerSexes = {}
var selected_race = "human"
var playerRaces = {}
var podium_character = null
var expanded_character_button = null


# ===== BONE CUSTOMIZATION =====
onready var reset_button:TextureButton =$Control/CharacterCustomizationControl/Reset 
onready var select_next_bone:TextureButton =$Control/CharacterCustomizationControl/GridContainer/SelectedBone/IncreaseButton
onready var select_prev_bone:TextureButton =$Control/CharacterCustomizationControl/GridContainer/SelectedBone/DecreaseButton
onready var selected_bone_label:Label=$Control/CharacterCustomizationControl/GridContainer/SelectedBone/Label
onready var character_custom_control:Control = $Control/CharacterCustomizationControl
onready var customizationGrid = $Control/CharacterCustomizationControl/GridContainer

var editableBones = [
	"head",
	"clavicle_l",
	"clavicle_r",
	"neck_02",
	"neck_01",
	"spine_05"
]

var selectedBoneIndex := 0
var boneDefaultRest = {}
var playerBoneScale = {
	"CharacterName": {
		"head":{
			"scale":1.0,
			"width":1.0,
			"height":1.0,
			"depth":1.0,
			"rotation":0.0,
			"position":Vector3()
		}
	}
}

# ===== EYE CUSTOMIZATION =====
onready var eye_color_picker:ColorPicker=$Control/CharacterCustomizationControl/GridContainerEyes/ColorPicker
onready var next_eye=$Control/CharacterCustomizationControl/GridContainerEyes/SelectEye/IncreaseButton
onready var prev_eye=$Control/CharacterCustomizationControl/GridContainerEyes/SelectEye/DecreaseButton
onready var eye_label=$Control/CharacterCustomizationControl/GridContainerEyes/SelectEye/Label
onready var even_eyes_button=$Control/CharacterCustomizationControl/GridContainerEyes/EvenEyesButton

var selected_eye:=0
var eye_names=["Left","Right"]
var eye_colors={}

# ===== SCENE PRELOADS =====
var maleScene = preload("res://world/player/human/scenes/character_male.tscn")
var femaleScene = preload("res://world/player/human/scenes/character_female.tscn")
var kragunScene = preload("res://world/player/kragun/scenes/character_kragun.tscn")

func _ready():
	$Podium/character.queue_free()
	character_custom_control.hide()
	buttonTemplate.hide()
	popup.hide()

	for child in gridContainer.get_children():
		if child != buttonTemplate:
			child.queue_free()
	
	# ===== SIGNAL CONNECTIONS =====
	createButton.connect("pressed", self, "createButtonPressed")
	goBackButton.connect("pressed", self, "goBackPressed")
	serverButton.connect("pressed", self, "enterGamePressed")
	offlinePlayButton.connect("pressed", self, "enterGameOfflinePressed")
	line_edit.connect("text_entered", self, "lineEditEntered")
	changeSexButton.connect("pressed", self, "changeSexPressed")
	confirmButton.connect("pressed", self, "confirmDeleteCharacter")
	regretButton.connect("pressed", self, "cancelDeleteCharacter")
	createNewCharacterButton.connect("pressed", self, "createNewCharacterPressed")  # NEW
	select_next_bone.connect("pressed", self, "selectAnotherBone", ["up"])
	select_prev_bone.connect("pressed", self, "selectAnotherBone", ["down"])
	reset_button.connect("pressed", self, "resetAllBones")
	nextHair.connect("pressed",self,"changeHair",[1])
	prevHair.connect("pressed",self,"changeHair",[-1])
	hairColorPicker.connect("color_changed",self,"hairColorChanged")
	next_hair_texture_button.connect("pressed",self,"changeHairTexture",[1])
	prev_hair_texture_button.connect("pressed",self,"changeHairTexture",[-1])
	selected_bone_label.text = editableBones[selectedBoneIndex]
	next_eye.connect("pressed",self,"changeEye",[1])
	prev_eye.connect("pressed",self,"changeEye",[-1])
	even_eyes_button.connect("pressed", self, "makeEyeColorEven")
	eye_color_picker.connect("color_changed",self,"eyeColorChanged")
	raceSlider.connect("value_changed", self, "raceSliderChanged")
	humanButton.connect("pressed", self, "selectRace", ["human"])
	kragunButton.connect("pressed", self, "selectRace", ["kragun"])
	loadData()
	cacheDefaultEquipment()
	spawnPodiumCharacter()
	
	# Scale
	ScaleIncrease.connect("pressed",self,"changeBoneScale",[0.05,"scale"])
	ScaleDecrease.connect("pressed",self,"changeBoneScale",[-0.05,"scale"])
	# Width
	WidthIncrease.connect("pressed",self,"changeBoneScale",[0.05,"width"])
	WidthDecrease.connect("pressed",self,"changeBoneScale",[-0.05,"width"])
	# Height
	HeightIncrease.connect("pressed",self,"changeBoneScale",[0.05,"height"])
	HeightDecrease.connect("pressed",self,"changeBoneScale",[-0.05,"height"])
	# Depth
	DepthIncrease.connect("pressed",self,"changeBoneScale",[0.05,"depth"])
	DepthDecrease.connect("pressed",self,"changeBoneScale",[-0.05,"depth"])
	# Rotation
	RotationIncrease.connect("pressed",self,"changeBoneScale",[0.5,"rotation"])
	RotationDecrease.connect("pressed",self,"changeBoneScale",[-0.5,"rotation"])
	# Position
	PositionXIncrease.connect("pressed", self, "changeBoneScale", [ 0.5, "position_x"])
	PositionXDecrease.connect("pressed", self, "changeBoneScale", [-0.5, "position_x"])
	PositionYIncrease.connect("pressed", self, "changeBoneScale", [ 0.5, "position_y"])
	PositionYDecrease.connect("pressed", self, "changeBoneScale", [-0.5, "position_y"])
	PositionZIncrease.connect("pressed", self, "changeBoneScale", [ 0.5, "position_z"])
	PositionZDecrease.connect("pressed", self, "changeBoneScale", [-0.5, "position_z"])

	connectBodyPartButtons()
	setupBlendShapes()
	hideLoadscreen()
	probeServer()


func probeServer():
	if is_connecting or is_loading or is_probing:
		return

	is_probing = true
	var peer = NetworkedMultiplayerENet.new()
	var err = peer.create_client(SERVER_ADDRESS, SERVER_PORT)
	if err != OK:
		setServerStatus(false)
		is_probing = false
		return

	get_tree().network_peer = peer

	if !get_tree().is_connected("connected_to_server", self, "onProbeSuccess"):
		get_tree().connect("connected_to_server", self, "onProbeSuccess", [], CONNECT_ONESHOT)
	if !get_tree().is_connected("connection_failed", self, "onProbeFailed"):
		get_tree().connect("connection_failed", self, "onProbeFailed", [], CONNECT_ONESHOT)

	yield(get_tree().create_timer(PROBE_TIMEOUT), "timeout")

	if is_probing:
		disconnectProbeSignals()
		setServerStatus(false)
		if get_tree().network_peer == peer:
			get_tree().network_peer = null
		is_probing = false

func onProbeSuccess():
	if !is_probing:
		return
	disconnectProbeSignals()
	setServerStatus(true)
	get_tree().network_peer = null
	is_probing = false

func onProbeFailed():
	if !is_probing:
		return
	disconnectProbeSignals()
	setServerStatus(false)
	get_tree().network_peer = null
	is_probing = false

func disconnectProbeSignals() -> void:
	if get_tree().is_connected("connected_to_server", self, "onProbeSuccess"):
		get_tree().disconnect("connected_to_server", self, "onProbeSuccess")
	if get_tree().is_connected("connection_failed", self, "onProbeFailed"):
		get_tree().disconnect("connection_failed", self, "onProbeFailed")

func setServerStatus(online:bool) -> void:
	server_online = online
	if online:
		serverButtonLabel.text = "Server: Online"
		serverButtonLabel.modulate = Color.green
	else:
		serverButtonLabel.text = "Server: Offline"
		serverButtonLabel.modulate = Color.red

func stopProbing() -> void:
	status_timer.stop()
	disconnectProbeSignals()
	is_probing = false

func flashOfflineButtonLabel() -> void:
	tween.interpolate_property(offline_button_label, "modulate",
		Color.white, Color.green, 0.15,
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(offline_button_label, "modulate",
		Color.green, Color.white, 0.35,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT, 0.15)
	tween.start()

# ===== CHARACTER CREATION/SELECTION =====
func createNewCharacterPressed():
	"""Clear selection and reset to creation mode"""
	selected_player_name = ""
	selected_player_label.text = ""
	selected_sex = "male"
	selected_race = "human"
	character_custom_control.hide()
	
	# Enable race slider for new characters
	if is_instance_valid(raceSlider):
		raceSlider.value = 0
		raceSlider.editable = true
	if is_instance_valid(humanButton):
		humanButton.disabled = false
	if is_instance_valid(kragunButton):
		kragunButton.disabled = false
	
	spawnPodiumCharacter()
	updateSpeciesLabel()

func updateSpeciesLabel():
	"""Update the selected species label"""
	if is_instance_valid(selectedSpeciesLabel):
		selectedSpeciesLabel.text = selected_race.capitalize()

func changeSexPressed():
	"""Toggle sex - only disabled for existing Kragun characters"""
	# Don't allow sex change for Kragun (they are unisex)
	if selected_race == "kragun":
		return
	
	# Allow sex switching for new characters (selected_player_name == "")
	# For existing characters, only allow if they're still being edited
	if selected_player_name != "" and line_edit.text.strip_edges() == "":
		# Existing character - disable sex change
		return
	
	selected_sex = "female" if selected_sex == "male" else "male"
	selected_sex_label.text = selected_sex
	
	# If creating new character, just update preview
	if selected_player_name == "":
		spawnPodiumCharacter()
		return
	
	# For existing character
	playerSexes[selected_player_name] = selected_sex

	if !playerEquipment.has(selected_player_name):
		playerEquipment[selected_player_name] = defaultEquipment[selected_sex].duplicate(true)
	else:
		var equipment = playerEquipment[selected_player_name]
		for slot in ["torso", "hands", "feet", "head"]:
			var path = equipment.get(slot, "")
			if path == "":
				equipment[slot] = defaultEquipment[selected_sex][slot]
				continue
			path = path.replace("/female/", "/male/") if selected_sex == "male" else path.replace("/male/", "/female/")
			equipment[slot] = path if ResourceLoader.exists(path) else defaultEquipment[selected_sex][slot]

	spawnPodiumCharacter()
	saveData()
	selected_sex_label.text = selected_sex
	updateLabels()

func selectRace(race: String):
	"""Select a race - only for new characters"""
	if race != "human" and race != "kragun":
		return
	
	# Only allow race change if creating new character
	if selected_player_name != "":
		return
	
	selected_race = race
	if is_instance_valid(raceSlider):
		raceSlider.value = 0 if race == "human" else 1
	
	spawnPodiumCharacter()
	updateSpeciesLabel()
	saveData()

func raceSliderChanged(value: float):
	"""Handle race slider - only for new characters"""
	if selected_player_name != "":
		return  # Don't allow race change for existing characters
	
	var race = "human" if value < 0.5 else "kragun"
	if race == selected_race:
		return
	selectRace(race)

func createButtonPressed():
	var buttonText = line_edit.text.strip_edges()
	if buttonText == "":
		return
	# Only allow letters, spaces, underscores and hyphens.
	var allowed := RegEx.new()
	allowed.compile("^[A-Za-z ]+$")
	if allowed.search(buttonText) == null:
		return
	if playerSexes.has(buttonText):
		return
	playerSexes[buttonText] = selected_sex
	playerRaces[buttonText] = selected_race
	playerEquipment[buttonText] = getDefaultEquipmentFor(selected_race, selected_sex)
	createPlayerButton(buttonText)
	line_edit.clear()
	saveData()
	selectLastCharacter()

func playerButtonPressed(button):
	if expanded_character_button == button:
		hideCharacterActionButtons(button)
		expanded_character_button = null
		character_custom_control.hide()
		return

	if is_instance_valid(expanded_character_button):
		hideCharacterActionButtons(expanded_character_button)
	expanded_character_button = button
	showCharacterActionButtons(button)

	character_custom_control.hide()
	selected_player_name = button.get_node("Label").text
	selected_player_label.text = selected_player_name

	if playerSexes.has(selected_player_name):
		selected_sex = playerSexes[selected_player_name]
	else:
		selected_sex = "male"

	selected_race = playerRaces.get(selected_player_name, "human")
	if is_instance_valid(raceSlider):
		raceSlider.value = 0 if selected_race == "human" else 1
	
	# Disable race/sex controls for existing characters
	if is_instance_valid(raceSlider):
		raceSlider.editable = false
	if is_instance_valid(humanButton):
		humanButton.disabled = true
	if is_instance_valid(kragunButton):
		kragunButton.disabled = true
	
	updateEditButtonVisibility(selected_player_name)
	spawnPodiumCharacter()
	
	if hairColors.has(selected_player_name):
		hairColorPicker.color = hairColors[selected_player_name]
	else:
		hairColorPicker.color = Color.white
	applyHair()
	applyHairTexture()
	applyHairColor()
	applyEyeColors()
	call_deferred("applyBlendShapes")
	refreshBodyMeshes()

	hairstyle_label.text = "Hair: " + str(hairIndex.get(selected_player_name, 0) + 1)
	hair_texture_label.text = ["Light", "Dark", "Darker", "Darkest"][hair_texture_index.get(selected_player_name, 0)]
func showCharacterActionButtons(button) -> void:
	if !is_instance_valid(button):
		return
	var deleteButton = button.get_node_or_null("DeleteCharacter")
	var editButton = button.get_node_or_null("EditCharacter")
	if is_instance_valid(deleteButton):
		deleteButton.visible = true
	if is_instance_valid(editButton):
		var char_name = button.get_node("Label").text
		var char_race = playerRaces.get(char_name, "human")
		editButton.visible = char_race == "human"

func hideCharacterActionButtons(button) -> void:
	if !is_instance_valid(button):
		return
	var deleteButton = button.get_node_or_null("DeleteCharacter")
	var editButton = button.get_node_or_null("EditCharacter")
	if is_instance_valid(deleteButton):
		deleteButton.visible = false
	if is_instance_valid(editButton):
		editButton.visible = false
func selectLastCharacter():
	var lastButton = null

	for child in gridContainer.get_children():
		if child == buttonTemplate:
			continue
		lastButton = child

	if lastButton:
		playerButtonPressed(lastButton)
	else:
		selected_player_name = ""
		selected_player_label.text = ""
		selected_sex = "male"
		selected_race = "human"
		if is_instance_valid(raceSlider):
			raceSlider.value = 0
			raceSlider.editable = true
		if is_instance_valid(humanButton):
			humanButton.disabled = false
		if is_instance_valid(kragunButton):
			kragunButton.disabled = false
		spawnPodiumCharacter()
	
	saveData()
	hairstyle_label.text = "Hair: " + str(hairIndex.get(selected_player_name, 0) + 1)

func createPlayerButton(buttonText):
	var newButton = buttonTemplate.duplicate()

	newButton.show()
	gridContainer.add_child(newButton)

	newButton.get_node("Label").text = buttonText

	newButton.connect("pressed", self, "playerButtonPressed", [newButton])

	var deleteButton = newButton.get_node("DeleteCharacter")
	deleteButton.connect("pressed", self, "deleteCharacterPressed", [newButton])
	deleteButton.visible = false
	var editButton = newButton.get_node("EditCharacter")
	editButton.connect("pressed", self, "editCharacterPressed", [newButton])
	if !playerRaces.has(buttonText):
		playerRaces[buttonText] = "human"
	editButton.visible = false
	if !playerBoneScale.has(buttonText):
		playerBoneScale[buttonText] = {}

		for boneName in editableBones:
			playerBoneScale[buttonText][boneName] = {
				"scale": 1.0,
				"width": 1.0,
				"height": 1.0,
				"depth": 1.0,
				"rotation": 0.0,
				"position": Vector3()
			}
	if !hairIndex.has(buttonText):
		hairIndex[buttonText] = randi() % hairs[playerSexes[buttonText]].size()

	if !hair_texture_index.has(buttonText):
		hair_texture_index[buttonText] = 0

	if !hairColors.has(buttonText):
		hairColors[buttonText] = Color.white

	hairstyle_label.text = "Hair: " + str(hairIndex[buttonText] + 1)
	hair_texture_label.text = ["Light", "Dark", "Darker", "Darkest"][hair_texture_index[buttonText]]
	hairColorPicker.color = hairColors[buttonText]
	hairstyle_label.text = "Hair: " + str(hairIndex.get(selected_player_name, 0) + 1)

func editCharacterPressed(button):
	playerButtonPressed(button)
	character_custom_control.show()

func deleteCharacterPressed(button):
	var label = $Control/PopUp/Label
	deleteCharacterButton = button
	label.text = "Are you sure you want to delete [" + selected_player_name + "]?"
	popup.show()
	selectLastCharacter()
	saveData()

func confirmDeleteCharacter():
	if !is_instance_valid(deleteCharacterButton):
		popup.hide()
		return

	var characterName = deleteCharacterButton.get_node("Label").text

	playerSexes.erase(characterName)
	playerRaces.erase(characterName)
	playerEquipment.erase(characterName)
	playerBoneScale.erase(characterName)

	deleteAllDataForCharacter(characterName)

	var deletedButton = deleteCharacterButton
	deleteCharacterButton = null

	if selected_player_name == characterName:
		selected_player_name = ""
		selected_player_label.text = ""

	if expanded_character_button == deletedButton:
		expanded_character_button = null

	deletedButton.get_parent().remove_child(deletedButton)
	deletedButton.free()

	saveData()

	popup.hide()

	selectLastCharacter()


# ---------------------------------------------------------------
# Wipes EVERY piece of local save data tied to this character name:
#  - user://save/<name>/                      (legacy)
#  - user://Characters/<name>/                (skill tree, bones, hair)
#  - user://PlayerSaves/Offline/<name>/        (offline save)
#  - user://PlayerSaves/Server_*/<name>/       (any local server's save
#                                                of this character)
# This only ever touches folders scoped to this exact character name
# on THIS machine's user:// -- when playing online, the actual save
# data lives on the remote server's own user://, which this client
# has no access to and never touches, so other players online are
# never at risk.
# ---------------------------------------------------------------
func deleteAllDataForCharacter(characterName: String) -> void:
	var dir := Directory.new()

	# Old flat legacy save files
	for filePath in [
		"user://" + characterName + "_" + characterName + ".save",
		"user://" + characterName + ".save"
	]:
		if dir.file_exists(filePath):
			dir.remove(filePath)

	trashOrDeleteDirectory("user://save/" + characterName)
	trashOrDeleteDirectory("user://Characters/" + characterName)
	trashOrDeleteDirectory("user://PlayerSaves/Offline/" + characterName)

	var player_saves_dir := Directory.new()
	if player_saves_dir.open("user://PlayerSaves/") == OK:
		player_saves_dir.list_dir_begin(true, true)
		var server_folder := player_saves_dir.get_next()
		while server_folder != "":
			if player_saves_dir.current_is_dir() and server_folder.begins_with("Server_"):
				trashOrDeleteDirectory("user://PlayerSaves/" + server_folder + "/" + characterName)
			server_folder = player_saves_dir.get_next()
		player_saves_dir.list_dir_end()


# Empties a directory completely, then either sends the now-empty folder
# to the OS trash/recycle bin (if this Godot build exposes that API), or
# falls back to a plain hard delete of the empty folder. Directory.remove()
# can only ever remove an EMPTY directory -- that's why everything inside
# has to be cleared out first regardless of which path we take after.
func trashOrDeleteDirectory(path: String) -> void:
	var dir := Directory.new()
	if !dir.dir_exists(path):
		return

	emptyDirectoryRecursive(path)

	if OS.has_method("move_to_trash"):
		var err = OS.move_to_trash(ProjectSettings.globalize_path(path))
		if err == OK:
			return

	var parent_dir := Directory.new()
	parent_dir.remove(path)


func emptyDirectoryRecursive(path: String) -> void:
	var dir := Directory.new()
	if dir.open(path) != OK:
		return

	dir.list_dir_begin(true, true)
	var entry := dir.get_next()

	while entry != "":
		var full_path := path.plus_file(entry)
		if dir.current_is_dir():
			emptyDirectoryRecursive(full_path)
			var sub_dir := Directory.new()
			sub_dir.remove(full_path)
		else:
			dir.remove(full_path)
		entry = dir.get_next()

	dir.list_dir_end()




func removeDirectoryRecursive(path: String) -> void:
	var dir = Directory.new()
	if !dir.dir_exists(path):
		return

	if dir.open(path) != OK:
		return

	dir.list_dir_begin(true, true)
	var entry = dir.get_next()

	while entry != "":
		var full_path = path.plus_file(entry)
		if dir.current_is_dir():
			removeDirectoryRecursive(full_path)
		else:
			dir.remove(full_path)
		entry = dir.get_next()

	dir.list_dir_end()

	# Directory should be empty now -- remove it, and its parent's
	# reference to it, via the top-level Directory instance.
	var parent_dir = Directory.new()
	parent_dir.remove(path)
func cancelDeleteCharacter():
	deleteCharacterButton = null
	popup.hide()
	saveData()

# ===== EQUIPMENT =====
var playerEquipment = {}

var defaultEquipment = {
	"male": {
		"torso": "res://world/player/human/male/Torso0.tscn",
		"hands": "res://world/player/human/male/Hands0.tscn",
		"feet": "res://world/player/human/male/Feet0.tscn",
		"head": "res://world/player/human/male/Head0.tscn"
	},
	"female": {
		"torso": "res://world/player/human/female/Torso0.tscn",
		"hands": "res://world/player/human/female/Hands0.tscn",
		"feet": "res://world/player/human/female/Feet0.tscn",
		"head": "res://world/player/human/female/Head0.tscn"
	}
}

var defaultEquipmentKragun = {
	"torso": "res://world/player/kragun/unisex/KragunTorso0.tscn",
	"hands": "res://world/player/kragun/unisex/Hands0.tscn",
	"feet": "res://world/player/kragun/unisex/Feet0.tscn",
	"head": "res://world/player/kragun/unisex/Head0.tscn"
}

func getDefaultEquipmentFor(race:String, sex:String) -> Dictionary:
	if race == "kragun":
		return defaultEquipmentKragun.duplicate(true)
	return defaultEquipment[sex].duplicate(true)

func clearBodyEquipment():
	if !is_instance_valid(podium_character):
		return

	var skeleton = podium_character.get_node_or_null("root/Skeleton")

	if skeleton == null:
		return

	for child in skeleton.get_children():
		if child is Spatial:
			child.queue_free()

func applyBodyEquipment():
	if !is_instance_valid(podium_character):
		return
	var skeleton = podium_character.get_node_or_null("root/Skeleton")
	var animaiton_player: AnimationPlayer = podium_character.get_node_or_null("AnimationPlayer")
	if animaiton_player:
		animaiton_player.play("Idle_cycle", 0, 0.1)
	if skeleton == null:
		return
	clearBodyEquipment()
	var equipment = {}
	if selected_player_name != "" and playerEquipment.has(selected_player_name):
		equipment = playerEquipment[selected_player_name]
	else:
		equipment = getDefaultEquipmentFor(selected_race, selected_sex)
	
	for slot in ["torso", "hands", "feet", "head"]:
		if !equipment.has(slot):
			continue
		var scene = getCachedScene(equipment[slot])
		if scene:
			skeleton.add_child(scene.instance())
	
	updateLabels()
	applyHair()
	createBlendShapeButtons()

# ===== SPAWNING & SCENE MANAGEMENT =====
func spawnPodiumCharacter():
	if is_instance_valid(podium_character):
		podium_character.queue_free()
	if selected_race == "kragun":
		podium_character = kragunScene.instance()
	elif selected_sex == "male":
		podium_character = maleScene.instance()
	else:
		podium_character = femaleScene.instance()
	podium.add_child(podium_character)
	podium_character.translation = Vector3(0, 1, 0)
	var krogun_scale = Global.krogun_scale
	podium_character.scale = Vector3(krogun_scale,krogun_scale,krogun_scale) if selected_race == "kragun" else Vector3.ONE
	selected_sex_label.text = selected_sex
	applyBodyEquipment()
	yield(get_tree(), "idle_frame")
	applyHair()
	applyHairTexture()
	applyHairColor()
	yield(get_tree(), "idle_frame")
	cacheBoneDefaults()
	updateLabels()
	saveData()
	setupBlendShapes()
	call_deferred("applyBlendShapes")

func getCachedScene(path:String) -> PackedScene:
	if path == "":
		return null

	if sceneCache.has(path):
		return sceneCache[path]

	var scene = load(path)

	if scene:
		sceneCache[path] = scene

	return scene

func cacheDefaultEquipment():
	for sex in defaultEquipment:
		for slot in defaultEquipment[sex]:
			getCachedScene(defaultEquipment[sex][slot])

	for slot in defaultEquipmentKragun:
		getCachedScene(defaultEquipmentKragun[slot])

	for character in playerEquipment:
		for slot in playerEquipment[character]:
			getCachedScene(playerEquipment[character][slot])

func updateEditButtonVisibility(characterName: String):
	if characterName == "":
		return
	for child in gridContainer.get_children():
		if child == buttonTemplate:
			continue
		if child.get_node("Label").text == characterName:
			var editButton = child.get_node_or_null("EditCharacter")
			if editButton:
				# Only show edit button for humans
				var char_race = playerRaces.get(characterName, "human")
				editButton.visible = char_race == "human"
			return

# ===== HAIR CUSTOMIZATION =====
func changeHair(direction:int):
	if selected_player_name=="":return
	if !hairIndex.has(selected_player_name):hairIndex[selected_player_name]=0
	var list=hairs[selected_sex]
	hairIndex[selected_player_name]=posmod(hairIndex[selected_player_name]+direction,list.size())
	hairstyle_label.text="Hair: "+str(hairIndex.get(selected_player_name,0)+1)
	applyHair()
	updateLabels()
	saveData()

func applyHair():
	if !is_instance_valid(podium_character):return
	var skeleton:Skeleton=podium_character.get_node_or_null("root/Skeleton")
	if skeleton==null:return

	for child in skeleton.get_children():
		if child.name=="Hair" or child.is_in_group("Hair"):
			child.free()

	if selected_race == "kragun":
		return

	var hair=getCachedScene(hairs[selected_sex][hairIndex.get(selected_player_name,0)]).instance()
	hair.name="Hair"
	skeleton.add_child(hair)

	if hairColors.has(selected_player_name):
		hairColorPicker.color=hairColors[selected_player_name]

	applyHairColor()

func changeHairTexture(direction:int):
	if selected_player_name=="":return
	if !hair_texture_index.has(selected_player_name):hair_texture_index[selected_player_name]=0
	hair_texture_index[selected_player_name]=posmod(hair_texture_index[selected_player_name]+direction,4)
	hair_texture_label.text=["Light","Dark","Darker","Darkest"][hair_texture_index[selected_player_name]]
	applyHairTexture()
	updateLabels()
	saveData()

func applyHairTexture():
	if !is_instance_valid(podium_character):return
	var hair:Spatial=podium_character.get_node_or_null("root/Skeleton/Hair")
	if hair==null:return

	var style=hairIndex.get(selected_player_name,0)
	var variant=hair_texture_index.get(selected_player_name,0)
	var texture=load(hair_textures[selected_sex][style*4+variant])
	
	applyHairTextureRecursive(hair,texture)
	saveData()

func applyHairTextureRecursive(node:Node,texture:Texture):
	if node is MeshInstance:
		if node.material_override:
			node.material_override=node.material_override.duplicate()
			node.material_override.albedo_texture=texture

		if node.material_overlay:
			node.material_overlay=node.material_overlay.duplicate()
			node.material_overlay.albedo_texture=texture

		if node.mesh:
			for i in range(node.mesh.get_surface_count()):
				var material=node.get_surface_material(i)
				if material==null:
					material=node.mesh.surface_get_material(i)
				if material:
					material=material.duplicate()
					material.albedo_texture=texture
					node.mesh.surface_set_material(i,material)
					node.set_surface_material(i,material)

	for child in node.get_children():
		applyHairTextureRecursive(child,texture)

func applyHairColor():
	if selected_player_name!="":
		hairColors[selected_player_name]=hairColorPicker.color

	if !is_instance_valid(podium_character):return
	var hair:Spatial=podium_character.get_node_or_null("root/Skeleton/Hair")
	if hair==null:return
	applyHairColorRecursive(hair,hairColorPicker.color)

func applyHairColorRecursive(node:Node,color:Color):
	if node is MeshInstance:
		if node.material_override:
			node.material_override=node.material_override.duplicate()
			node.material_override.albedo_color=color

		if node.material_overlay:
			node.material_overlay=node.material_overlay.duplicate()
			node.material_overlay.albedo_color=color

		for i in range(node.mesh.get_surface_count() if node.mesh else 0):
			var material=node.get_surface_material(i)
			if material==null and node.mesh:
				material=node.mesh.surface_get_material(i)
			if material:
				material=material.duplicate()
				material.albedo_color=color
				node.set_surface_material(i,material)

	for child in node.get_children():
		applyHairColorRecursive(child,color)

func hairColorChanged(color:Color):
	if selected_player_name=="":
		return
	hairColors[selected_player_name]=color
	applyHairColor()
	saveData()

# ===== BONE CUSTOMIZATION =====
onready var ScaleIncrease:TextureButton = $Control/CharacterCustomizationControl/GridContainer/ButtonBackground/IncreaseButton
onready var ScaleDecrease:TextureButton = $Control/CharacterCustomizationControl/GridContainer/ButtonBackground/DecreaseButton
onready var WidthIncrease:TextureButton = $Control/CharacterCustomizationControl/GridContainer/ButtonBackground2/IncreaseButton
onready var WidthDecrease:TextureButton = $Control/CharacterCustomizationControl/GridContainer/ButtonBackground2/DecreaseButton
onready var HeightIncrease:TextureButton =$Control/CharacterCustomizationControl/GridContainer/ButtonBackground3/IncreaseButton
onready var HeightDecrease:TextureButton = $Control/CharacterCustomizationControl/GridContainer/ButtonBackground3/DecreaseButton
onready var DepthIncrease:TextureButton = $Control/CharacterCustomizationControl/GridContainer/ButtonBackground4/IncreaseButton
onready var DepthDecrease:TextureButton = $Control/CharacterCustomizationControl/GridContainer/ButtonBackground4/DecreaseButton
onready var RotationIncrease:TextureButton =$Control/CharacterCustomizationControl/GridContainer/ButtonBackground5/IncreaseButton
onready var RotationDecrease:TextureButton =$Control/CharacterCustomizationControl/GridContainer/ButtonBackground5/DecreaseButton
onready var PositionXIncrease:TextureButton =$Control/CharacterCustomizationControl/GridContainer/ButtonBackground6/IncreaseButton
onready var PositionXDecrease:TextureButton =$Control/CharacterCustomizationControl/GridContainer/ButtonBackground6/DecreaseButton
onready var PositionZIncrease:TextureButton =$Control/CharacterCustomizationControl/GridContainer/ButtonBackground7/IncreaseButton
onready var PositionZDecrease:TextureButton =$Control/CharacterCustomizationControl/GridContainer/ButtonBackground7/DecreaseButton
onready var PositionYIncrease:TextureButton =$Control/CharacterCustomizationControl/GridContainer/ButtonBackground8/IncreaseButton
onready var PositionYDecrease:TextureButton =$Control/CharacterCustomizationControl/GridContainer/ButtonBackground8/DecreaseButton

func selectAnotherBone(direction:String):
	if editableBones.empty():
		return
	if direction == "up":
		selectedBoneIndex += 1
	else:
		selectedBoneIndex -= 1
	if selectedBoneIndex >= editableBones.size():
		selectedBoneIndex = 0
	elif selectedBoneIndex < 0:
		selectedBoneIndex = editableBones.size() - 1
	selected_bone_label.text = editableBones[selectedBoneIndex]
	updateLabels()

func cacheBoneDefaults():
	boneDefaultRest.clear()

	if !is_instance_valid(podium_character):
		return

	var skeleton:Skeleton = podium_character.get_node_or_null("root/Skeleton")
	if skeleton == null:
		return

	if !playerBoneScale.has(selected_player_name):
		playerBoneScale[selected_player_name] = {}

	for boneName in editableBones:
		if !playerBoneScale[selected_player_name].has(boneName):
			playerBoneScale[selected_player_name][boneName] = {
				"scale":1.0,
				"width":1.0,
				"height":1.0,
				"depth":1.0,
				"rotation":0.0,
				"position":Vector3()
			}
		elif typeof(playerBoneScale[selected_player_name][boneName]) != TYPE_DICTIONARY:
			var oldScale:float = float(playerBoneScale[selected_player_name][boneName])

			playerBoneScale[selected_player_name][boneName] = {
				"scale":oldScale,
				"width":1.0,
				"height":1.0,
				"depth":1.0,
				"rotation":0.0,
				"position":Vector3()
			}

	for boneName in editableBones:
		var boneIndex:int = skeleton.find_bone(boneName)

		if boneIndex == -1:
			continue

		var boneData:Dictionary = playerBoneScale[selected_player_name][boneName]

		if !boneData.has("scale"):
			boneData["scale"] = 1.0
		if !boneData.has("width"):
			boneData["width"] = 1.0
		if !boneData.has("height"):
			boneData["height"] = 1.0
		if !boneData.has("depth"):
			boneData["depth"] = 1.0
		if !boneData.has("rotation"):
			boneData["rotation"] = 0.0

		if !boneData.has("position"):
			boneData["position"] = Vector3()
		elif typeof(boneData["position"]) == TYPE_REAL:
			boneData["position"] = Vector3(0, boneData["position"], 0)
		elif typeof(boneData["position"]) != TYPE_VECTOR3:
			boneData["position"] = Vector3()

		playerBoneScale[selected_player_name][boneName] = boneData

		var defaultRest:Transform = skeleton.get_bone_rest(boneIndex)
		boneDefaultRest[boneName] = defaultRest

		var boneBasis:Basis = defaultRest.basis

		boneBasis = boneBasis.scaled(Vector3(
			boneData["scale"] * boneData["width"],
			boneData["scale"] * boneData["height"],
			boneData["scale"] * boneData["depth"]
		))

		boneBasis = boneBasis.rotated(
			Vector3.UP,
			deg2rad(boneData["rotation"])
		)

		var boneOrigin:Vector3 = defaultRest.origin + boneData["position"]

		skeleton.set_bone_rest(
			boneIndex,
			Transform(boneBasis, boneOrigin)
		)

func changeBoneScale(amount:float, change:String):
	if editableBones.empty():
		return

	var boneName:String = editableBones[selectedBoneIndex]

	if !is_instance_valid(podium_character):
		return

	var skeleton:Skeleton = podium_character.get_node_or_null("root/Skeleton")
	if skeleton == null:
		return

	var boneIndex:int = skeleton.find_bone(boneName)
	if boneIndex == -1:
		return

	if !boneDefaultRest.has(boneName):
		return

	if selected_player_name == "":
		return

	if !playerBoneScale.has(selected_player_name):
		playerBoneScale[selected_player_name] = {}

	if !playerBoneScale[selected_player_name].has(boneName):
		playerBoneScale[selected_player_name][boneName] = {
			"scale":1.0,
			"width":1.0,
			"height":1.0,
			"depth":1.0,
			"rotation":0.0,
			"position":Vector3()
		}

	var boneData:Dictionary = playerBoneScale[selected_player_name][boneName]

	if !boneData.has("position") or typeof(boneData["position"]) != TYPE_VECTOR3:
		boneData["position"] = Vector3()

	var positionLimit:float = 2.0

	if boneName == "clavicle_l" or boneName == "clavicle_r":
		positionLimit = 5.0

	match change:
		"scale":
			boneData["scale"] = clamp(boneData["scale"] + amount, 0.85, 1.10)

		"width":
			boneData["width"] = clamp(boneData["width"] + amount, 0.85, 1.10)

		"height":
			boneData["height"] = clamp(boneData["height"] + amount, 0.85, 1.10)

		"depth":
			boneData["depth"] = clamp(boneData["depth"] + amount, 0.85, 1.10)

		"rotation":
			boneData["rotation"] = clamp(boneData["rotation"] + amount, -6.0, 6.0)

		"position_x":
			boneData["position"].x = clamp(boneData["position"].x + amount, -positionLimit, positionLimit)

		"position_y":
			boneData["position"].y = clamp(boneData["position"].y + amount, -positionLimit, positionLimit)

		"position_z":
			boneData["position"].z = clamp(boneData["position"].z + amount, -positionLimit, positionLimit)

		_:
			return

	playerBoneScale[selected_player_name][boneName] = boneData

	var defaultRest:Transform = boneDefaultRest[boneName]

	var boneBasis:Basis = defaultRest.basis

	boneBasis = boneBasis.scaled(Vector3(
		boneData["scale"] * boneData["width"],
		boneData["scale"] * boneData["height"],
		boneData["scale"] * boneData["depth"]
	))

	boneBasis = boneBasis.rotated(
		Vector3.UP,
		deg2rad(boneData["rotation"])
	)

	skeleton.set_bone_rest(
		boneIndex,
		Transform(
			boneBasis,
			defaultRest.origin + boneData["position"]
		)
	)

	saveData()
	updateLabels()

func updateLabels():
	if selected_player_name == "" or editableBones.empty():
		return

	if selectedBoneIndex < 0 or selectedBoneIndex >= editableBones.size():
		return

	var boneName:String = editableBones[selectedBoneIndex]

	if !playerBoneScale.has(selected_player_name) or !playerBoneScale[selected_player_name].has(boneName):
		return

	var boneData = playerBoneScale[selected_player_name][boneName]

	if typeof(boneData) != TYPE_DICTIONARY:
		var oldScale = float(boneData)
		boneData = {
			"scale":oldScale,
			"width":1.0,
			"height":1.0,
			"depth":1.0,
			"rotation":0.0,
			"position":Vector3()
		}
		playerBoneScale[selected_player_name][boneName] = boneData

	var bone:Dictionary = boneData

	bone["scale"] = float(bone.get("scale",1.0))
	bone["width"] = float(bone.get("width",1.0))
	bone["height"] = float(bone.get("height",1.0))
	bone["depth"] = float(bone.get("depth",1.0))
	bone["rotation"] = float(bone.get("rotation",0.0))
	bone["position"] = bone.get("position",Vector3())

	if typeof(bone["position"]) != TYPE_VECTOR3:
		bone["position"] = Vector3()

	$Control/CharacterCustomizationControl/GridContainer/ButtonBackground/Label.text = "Scale: " + str(stepify(bone["scale"],0.01))
	$Control/CharacterCustomizationControl/GridContainer/ButtonBackground2/Label.text = "Scale X: " + str(stepify(bone["width"],0.01))
	$Control/CharacterCustomizationControl/GridContainer/ButtonBackground3/Label.text = "Scale Z: " + str(stepify(bone["height"],0.01))
	$Control/CharacterCustomizationControl/GridContainer/ButtonBackground4/Label.text = "Scale Y: " + str(stepify(bone["depth"],0.01))
	$Control/CharacterCustomizationControl/GridContainer/ButtonBackground5/Label.text = "Rotation: " + str(stepify(bone["rotation"],0.1)) + "°"
	$Control/CharacterCustomizationControl/GridContainer/ButtonBackground6/Label.text = "Position X: " + str(stepify(bone["position"].x,0.01))
	$Control/CharacterCustomizationControl/GridContainer/ButtonBackground8/Label.text = "Position Y: " + str(stepify(bone["position"].y,0.01))
	$Control/CharacterCustomizationControl/GridContainer/ButtonBackground7/Label.text = "Position Z: " + str(stepify(bone["position"].z,0.01))

	selected_bone_label.text = "Bone: " + boneName

	if hair_texture_index.has(selected_player_name):
		var hairIndexValue = hair_texture_index[selected_player_name]
		if hairIndexValue >= 0 and hairIndexValue < 4:
			hair_texture_label.text = ["Light","Dark","Darker","Darkest"][hairIndexValue]

	hairstyle_label.text = "Hair: " + str(hairIndex.get(selected_player_name,0)+1)

func resetAllBones():
	if selected_player_name == "":
		return

	if !playerBoneScale.has(selected_player_name):
		playerBoneScale[selected_player_name]={}

	playerBoneScale[selected_player_name].clear()

	for boneName in editableBones:
		playerBoneScale[selected_player_name][boneName]={
			"scale":1.0,
			"width":1.0,
			"height":1.0,
			"depth":1.0,
			"rotation":0.0,
			"position":Vector3()
		}

	if eye_colors.has(selected_player_name):
		eye_colors[selected_player_name]={
			"left":Color.white,
			"right":Color.white
		}

	if playerBlendShapes.has(selected_player_name):
		playerBlendShapes[selected_player_name].clear()

	if is_instance_valid(podium_character):
		var skeleton:Skeleton=podium_character.get_node_or_null("root/Skeleton")

		if skeleton:
			for boneName in editableBones:
				if !boneDefaultRest.has(boneName):
					continue

				var boneIndex=skeleton.find_bone(boneName)
				if boneIndex==-1:
					continue

				skeleton.set_bone_rest(boneIndex,boneDefaultRest[boneName])
	resetBlendShapes()
	applyEyeColors()
	applyBlendShapes()

	saveData()
	updateLabels()

# ===== BLEND SHAPES =====
var playerBlendShapes={}
var blendShapeButtons={}
const BLEND_STEP:float=0.01

var blendShape=""
var blendDirection:=0

var currentBodyPart:="Head"
var bodyMeshes={}

func getBodyPart(mesh):
	if "head" in mesh.name.to_lower():
		return "Head"
	return "Body"

func findBodyMeshes(node):
	if node is MeshInstance and node.mesh:
		var part=getBodyPart(node)
		if !bodyMeshes.has(part):
			bodyMeshes[part]=[]
		bodyMeshes[part].append(node)

	for child in node.get_children():
		findBodyMeshes(child)

func getCurrentMesh():
	if !bodyMeshes.has(currentBodyPart):
		return null

	for mesh in bodyMeshes[currentBodyPart]:
		if mesh.mesh.get_blend_shape_count()>0:
			return mesh

	return null

func refreshBodyMeshes():
	bodyMeshes.clear()

	if is_instance_valid(podium_character):
		findBodyMeshes(podium_character)

func setupBlendShapes():
	refreshBodyMeshes()
	currentBodyPart="Head"
	createBlendShapeButtons()
	applyBlendShapes()

func switchBodyPart(direction):
	var podium=$Podium
	var parts=["Head","Body"]
	var index=parts.find(currentBodyPart)

	for _i in range(parts.size()):
		index=(index+direction+parts.size())%parts.size()

		if bodyMeshes.has(parts[index]):
			currentBodyPart=parts[index]

			if currentBodyPart=="Head":
				if podium and podium.has_method("showCustomizationCamera"):
					podium.showCustomizationCamera()
			else:
				if podium and podium.has_method("hideCustomizationCamera"):
					podium.hideCustomizationCamera()

			$Control/CharacterCustomizationControl/ScrollContainerMorphs/GridContainerFace/ButtonHolder/Label.text=currentBodyPart
			createBlendShapeButtons()
			applyBlendShapes()
			return

	saveData()

func createBlendShapeButtons():
	for holder in blendShapeButtons.values():
		if is_instance_valid(holder):
			holder.queue_free()

	blendShapeButtons.clear()

	var mesh=getCurrentMesh()
	if mesh==null:
		return

	var parent=$Control/CharacterCustomizationControl/ScrollContainerMorphs/GridContainerFace
	var template=parent.get_node("ButtonHolder")
	template.get_node("HSlider").hide()

	for i in range(mesh.mesh.get_blend_shape_count()):
		var holder=template.duplicate()
		holder.name="BlendShape_"+str(i)
		holder.show()
		parent.add_child(holder)

		var shape_name=mesh.mesh.get_blend_shape_name(i)
		holder.get_node("Label").text=shape_name

		holder.get_node("IncreaseButton").connect("button_down",self,"startBlendShape",[shape_name,1])
		holder.get_node("IncreaseButton").connect("button_up",self,"stopBlendShape")
		holder.get_node("DecreaseButton").connect("button_down",self,"startBlendShape",[shape_name,-1])
		holder.get_node("DecreaseButton").connect("button_up",self,"stopBlendShape")

		var slider=holder.get_node("HSlider")
		slider.show()
		slider.min_value=-1.25
		slider.max_value=1.25
		slider.step=0.01
		slider.value=playerBlendShapes.get(selected_player_name,{}).get(currentBodyPart+"_"+shape_name,0.0)
		slider.connect("value_changed",self,"blendShapeSliderChanged",[shape_name])

		blendShapeButtons[shape_name]=holder

func blendShapeSliderChanged(value,shape_name):
	if !playerBlendShapes.has(selected_player_name):
		playerBlendShapes[selected_player_name]={}

	playerBlendShapes[selected_player_name][currentBodyPart+"_"+shape_name]=value

	for mesh in bodyMeshes.get(currentBodyPart,[]):
		if !is_instance_valid(mesh) or !mesh.mesh:
			continue

		for i in range(mesh.mesh.get_blend_shape_count()):
			if mesh.mesh.get_blend_shape_name(i)==shape_name:
				mesh.set("blend_shapes/"+shape_name,value)
				break

	if blendShapeButtons.has(shape_name):
		blendShapeButtons[shape_name].get_node("Label").text=shape_name+": "+str(stepify(value,0.01))

	saveData()

func connectBodyPartButtons():
	var holder=$Control/CharacterCustomizationControl/ScrollContainerMorphs/GridContainerFace/ButtonHolder

	holder.get_node("IncreaseButton").connect("pressed",self,"switchBodyPart",[1])
	holder.get_node("DecreaseButton").connect("pressed",self,"switchBodyPart",[-1])

func startBlendShape(blend_name:String,direction:int):
	blendShape=blend_name
	blendDirection=direction
	if podium and podium.has_method("showCustomizationCamera"):
		podium.showCustomizationCamera()

func stopBlendShape():
	blendShape=""
	blendDirection=0
	saveData()

func _physics_process(delta):
	updateBlendShape(delta)

func updateBlendShape(delta):
	if blendDirection==0 or blendShape=="":
		return

	var mesh=getCurrentMesh()
	if mesh==null:
		return

	if !playerBlendShapes.has(selected_player_name):
		playerBlendShapes[selected_player_name]={}

	var key=currentBodyPart+"_"+blendShape
	var value=playerBlendShapes[selected_player_name].get(key,0.0)

	value=clamp(value+blendDirection*BLEND_STEP*delta*15,-1.25,1.25)

	playerBlendShapes[selected_player_name][key]=value

	for body_mesh in bodyMeshes.get(currentBodyPart,[]):
		if !body_mesh.mesh:
			continue

		for i in range(body_mesh.mesh.get_blend_shape_count()):
			if body_mesh.mesh.get_blend_shape_name(i)==blendShape:
				body_mesh.set("blend_shapes/"+blendShape,value)
				break

	if blendShapeButtons.has(blendShape):
		var holder=blendShapeButtons[blendShape]
		holder.get_node("Label").text=blendShape+": "+str(stepify(value,0.01))
		var slider=holder.get_node("HSlider")
		if slider.value!=value:
			slider.value=value

func applyBlendShapes():
	if !playerBlendShapes.has(selected_player_name):
		return

	var meshes=[]
	var nodes=[podium_character]

	while nodes.size()>0:
		var node=nodes.pop_front()

		if node is MeshInstance and node.mesh:
			if node.mesh.get_blend_shape_count()>0:
				meshes.append(node)

		for child in node.get_children():
			nodes.append(child)

	for mesh in meshes:
		for i in range(mesh.mesh.get_blend_shape_count()):
			var shape=mesh.mesh.get_blend_shape_name(i)

			for key in playerBlendShapes[selected_player_name]:
				if key.ends_with("_"+shape):
					mesh.set("blend_shapes/"+shape,playerBlendShapes[selected_player_name][key])
					break

	saveData()

func resetBlendShapes():
	var mesh=getCurrentMesh()
	if mesh==null:
		return

	if !playerBlendShapes.has(selected_player_name):
		playerBlendShapes[selected_player_name]={}

	for i in range(mesh.mesh.get_blend_shape_count()):
		var shape=mesh.mesh.get_blend_shape_name(i)
		playerBlendShapes[selected_player_name][currentBodyPart+"_"+shape]=0.0

		for bodyMesh in bodyMeshes.get(currentBodyPart,[]):
			if bodyMesh.mesh:
				for j in range(bodyMesh.mesh.get_blend_shape_count()):
					if bodyMesh.mesh.get_blend_shape_name(j)==shape:
						bodyMesh.set("blend_shapes/"+shape,0.0)
						break

		if blendShapeButtons.has(shape):
			var holder=blendShapeButtons[shape]
			holder.get_node("Label").text=shape+": 0.0"
			holder.get_node("HSlider").value=0.0

	saveData()

# ===== EYE CUSTOMIZATION =====
func changeEye(direction:int):
	selected_eye=posmod(selected_eye+direction,2)
	eye_label.text=eye_names[selected_eye]
	if selected_player_name=="":
		return
	if !eye_colors.has(selected_player_name):
		eye_colors[selected_player_name]={"left":Color.white,"right":Color.white}

	if selected_eye==0:
		eye_color_picker.color=eye_colors[selected_player_name]["left"]
	else:
		eye_color_picker.color=eye_colors[selected_player_name]["right"]
	if podium and podium.has_method("showCustomizationCamera"):
		podium.showCustomizationCamera()

func eyeColorChanged(color:Color):
	if selected_player_name=="":
		return

	if !eye_colors.has(selected_player_name):
		eye_colors[selected_player_name]={
			"left":Color.white,
			"right":Color.white
		}

	if selected_eye==0:
		eye_colors[selected_player_name]["left"]=color
	else:
		eye_colors[selected_player_name]["right"]=color

	applyEyeColors()
	saveData()

func getHeadMesh():
	if !is_instance_valid(podium_character):
		return null
	return findHeadMesh(podium_character)

func findHeadMesh(node):
	if node is MeshInstance:
		if node.is_in_group("Head") or "head" in node.name.to_lower() or "face" in node.name.to_lower():
			return node

	for child in node.get_children():
		var mesh=findHeadMesh(child)
		if mesh:
			return mesh

	return null

func applyEyeColors():
	if !is_instance_valid(podium_character):
		return

	if !eye_colors.has(selected_player_name):
		return

	var mesh=getHeadMesh()
	if mesh==null:
		return

	var material_path=""

	if selected_sex=="female":
		material_path= "res://world/player/human/female/materials/Head0.tres"
	else:
		material_path="res://world/player/human/male/materials/Head0.tres" 

	var forced_material=load(material_path)

	if forced_material==null:
		return

	forced_material=forced_material.duplicate()

	if forced_material is ShaderMaterial:
		forced_material.set_shader_param("eye_left_color",eye_colors[selected_player_name]["left"])
		forced_material.set_shader_param("eye_right_color",eye_colors[selected_player_name]["right"])

	for i in range(mesh.get_surface_material_count()):
		mesh.set_surface_material(i,forced_material)

func makeEyeColorEven()->void:
	if selected_player_name=="":
		return
	if !eye_colors.has(selected_player_name):
		eye_colors[selected_player_name]={"left":Color.white,"right":Color.white}

	if selected_eye==0:
		eye_colors[selected_player_name]["right"]=eye_colors[selected_player_name]["left"]
	else:
		eye_colors[selected_player_name]["left"]=eye_colors[selected_player_name]["right"]

	changeEye(0)
	applyEyeColors()
	saveData()
	if podium and podium.has_method("showCustomizationCamera"):
		podium.showCustomizationCamera()

# ===== WORLD LOADING & NETWORK =====
const SERVER_ADDRESS := "stammer-sensors.tun.ply.gg"
const SERVER_PORT := 16314

var pending_character_name := ""
var is_loading := false
var is_connecting := false
var interactive_loader:ResourceInteractiveLoader = null

var real_progress := 0.0
var displayed_progress := 0.0
func enterGamePressed():
	if selected_player_name == "":
		return
	if is_loading or is_connecting:
		return
	if !server_online:
		flashServerButton()
		return

	stopProbing()

	is_connecting = true
	pending_character_name = selected_player_name
	Global.selected_player_name = selected_player_name

	var peer = NetworkedMultiplayerENet.new()
	Network.remember_target(SERVER_ADDRESS, SERVER_PORT)
	var err = peer.create_client(SERVER_ADDRESS, SERVER_PORT)
	if err != OK:
		push_error("Failed to create client, error code: " + str(err))
		is_connecting = false
		flashServerButton()
		return

	get_tree().network_peer = peer
	showLoadscreen()

	if get_tree().network_peer.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTED:
		beginWorldLoad()
	else:
		if !get_tree().is_connected("connected_to_server", self, "beginWorldLoad"):
			get_tree().connect("connected_to_server", self, "beginWorldLoad", [], CONNECT_ONESHOT)
		if !get_tree().is_connected("connection_failed", self, "onConnectFailed"):
			get_tree().connect("connection_failed", self, "onConnectFailed", [], CONNECT_ONESHOT)



func enterGameOfflinePressed():
	if selected_player_name == "":
		return
	if is_loading or is_connecting:
		return

	Global.selected_player_name = selected_player_name
	get_tree().network_peer = null
	is_loading = true
	showLoadscreen()

	interactive_loader = ResourceLoader.load_interactive("res://World.tscn")
	if interactive_loader == null:
		push_error("Failed to start loading World.tscn (offline)")
		is_loading = false
		hideLoadscreen()
		return

	real_progress = 0.0
	displayed_progress = 0.0
var _next_scene_after_load := "" # "" = the World.tscn path (default), else an explicit target
func goBackPressed():
	if is_loading or is_connecting:
		return

	is_loading = true
	showLoadscreen()

	interactive_loader = ResourceLoader.load_interactive("res://PreCharacterCreation.tscn")
	if interactive_loader == null:
		push_error("Failed to start loading PreCharacterCreation.tscn")
		is_loading = false
		hideLoadscreen()
		return

	real_progress = 0.0
	displayed_progress = 0.0
	_next_scene_after_load = "res://PreCharacterCreation.tscn"
func disconnectJoinSignals() -> void:
	if get_tree().is_connected("connected_to_server", self, "beginWorldLoad"):
		get_tree().disconnect("connected_to_server", self, "beginWorldLoad")
	if get_tree().is_connected("connection_failed", self, "onConnectFailed"):
		get_tree().disconnect("connection_failed", self, "onConnectFailed")

func beginWorldLoad():
	disconnectJoinSignals()
	is_connecting = false

	interactive_loader = ResourceLoader.load_interactive("res://World.tscn")
	if interactive_loader == null:
		push_error("Failed to start loading World.tscn")
		returnToCharacterSelect()
		return
	real_progress = 0.0
	displayed_progress = 0.0
	is_loading = true

func onConnectFailed():
	disconnectJoinSignals()
	push_error("Could not connect to server")
	is_connecting = false
	if get_tree().network_peer != null:
		get_tree().network_peer = null
	hideLoadscreen()
	flashServerButton()

func flashServerButton() -> void:
	serverButton.rect_pivot_offset = serverButton.rect_size / 2.0

	tween.stop_all()
	serverButtonLabel.modulate = Color.white
	serverButton.rect_scale = Vector2.ONE

	tween.interpolate_property(serverButton, "rect_scale",
		Vector2.ONE, Vector2(1.15, 1.15), 0.12,
		Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.interpolate_property(serverButton, "rect_scale",
		Vector2(1.15, 1.15), Vector2.ONE, 0.25,
		Tween.TRANS_BACK, Tween.EASE_IN_OUT, 0.12)

	tween.start()
	flashOfflineButtonLabel()
func returnToCharacterSelect() -> void:
	is_loading = false
	is_connecting = false
	interactive_loader = null
	disconnectJoinSignals()
	if get_tree().network_peer != null:
		get_tree().network_peer = null
	hideLoadscreen()
	var err := get_tree().change_scene("res://PreCharacterCreation.tscn")
	if err != OK:
		push_error("returnToCharacterSelect: change_scene failed, error " + str(err))

export var progress_catchup_speed := 1.1
onready var loading_label:Label = $Control/LoadingScreen/Label

func _process(delta):
	if !server_online:
		serverButtonLabel.modulate = Color.red
	else:
		serverButtonLabel.modulate = Color.green

	if !is_loading:
		return

	displayed_progress = lerp(displayed_progress, real_progress, delta * progress_catchup_speed)
	if loading_label: loading_label.text = "Loading... " + str(int(displayed_progress * 100)) + "%"

	if interactive_loader == null:
		return

	var err = interactive_loader.poll()

	match err:
		OK:
			var stage_count = interactive_loader.get_stage_count()
			if stage_count > 0:
				real_progress = float(interactive_loader.get_stage()) / stage_count
				real_progress = min(real_progress, 0.99)

		ERR_FILE_EOF:
			var loaded_scene:PackedScene = interactive_loader.get_resource()
			interactive_loader = null
			real_progress = 1.0
			if _next_scene_after_load != "":
				var target = _next_scene_after_load
				_next_scene_after_load = ""
				is_loading = false
				hideLoadscreen()
				get_tree().change_scene_to(loaded_scene)
			else:
				finishEnteringWorld(loaded_scene)

		_:
			interactive_loader = null
			is_loading = false
			hideLoadscreen()
			push_error("Failed to load World.tscn, error code: " + str(err))
			returnToCharacterSelect()

func finishEnteringWorld(world_scene:PackedScene):
	is_loading = false
	var world = world_scene.instance()
	get_tree().root.add_child(world)
	if get_tree().current_scene:
		get_tree().current_scene.queue_free()
	get_tree().current_scene = world
	hideLoadscreen()

func showLoadscreen()->void:
	$Control/LoadingScreen.visible = true

func hideLoadscreen()->void:
	$Control/LoadingScreen.visible = false

# ===== SAVE/LOAD =====
const SAVE_PATH = "user://button_list.save"

func saveData():
	var data={
		"buttons":[],
		"sexes":playerSexes,
		"races":playerRaces,
		"equipment":playerEquipment,
		"bone_scale":playerBoneScale,
		"hair":hairIndex,
		"hair_colors":hairColors,
		"hair_texture":hair_texture_index,
		"blend_shapes": playerBlendShapes,
		"eye_colors":eye_colors,
	}

	for child in gridContainer.get_children():
		if child == buttonTemplate:
			continue

		data["buttons"].append(child.get_node("Label").text)

	# Never let an accidentally-empty roster overwrite a real one on disk --
	# if this fires before the button grid finished building, that's a bug
	# elsewhere, not a reason to delete every character's entry.
	if data["buttons"].empty():
		var existing = Global.getButtonListData()
		if !existing.empty() and existing.has("buttons") and typeof(existing["buttons"]) == TYPE_ARRAY and !existing["buttons"].empty():
			return

	writeButtonListAtomic(data)
	Global.invalidateButtonListCache()


func writeButtonListAtomic(data:Dictionary) -> void:
	var tmp_path := SAVE_PATH + ".tmp"
	var file := File.new()
	if file.open(tmp_path, File.WRITE) != OK:
		return
	file.store_var(data)
	file.close()

	var dir := Directory.new()
	if dir.file_exists(SAVE_PATH):
		if dir.file_exists(SAVE_PATH + ".bak"):
			dir.remove(SAVE_PATH + ".bak")
		dir.rename(SAVE_PATH, SAVE_PATH + ".bak")
	dir.rename(tmp_path, SAVE_PATH)


func loadData():
	var data = safeLoadButtonList()

	if typeof(data) != TYPE_DICTIONARY:
		return

	playerSexes.clear()
	playerRaces.clear()
	playerEquipment.clear()
	playerBoneScale.clear()
	hairColors.clear()
	hairIndex.clear()
	hair_texture_index.clear()
	playerBlendShapes.clear()
	eye_colors.clear()

	if data.has("eye_colors"):
		eye_colors=data["eye_colors"].duplicate(true)

	if data.has("sexes") and typeof(data["sexes"]) == TYPE_DICTIONARY:
		playerSexes = data["sexes"].duplicate(true)

	if data.has("races") and typeof(data["races"]) == TYPE_DICTIONARY:
		playerRaces = data["races"].duplicate(true)

	if data.has("equipment") and typeof(data["equipment"]) == TYPE_DICTIONARY:
		playerEquipment = data["equipment"].duplicate(true)

	if data.has("bone_scale") and typeof(data["bone_scale"]) == TYPE_DICTIONARY:
		playerBoneScale = data["bone_scale"].duplicate(true)
	if data.has("hair") and typeof(data["hair"])==TYPE_DICTIONARY:
		hairIndex=data["hair"].duplicate(true)

	if data.has("hair_colors") and typeof(data["hair_colors"])==TYPE_DICTIONARY:
		hairColors=data["hair_colors"].duplicate(true)
	if data.has("hair_texture") and typeof(data["hair_texture"])==TYPE_DICTIONARY:
		hair_texture_index=data["hair_texture"].duplicate(true)

	if data.has("blend_shapes") and typeof(data["blend_shapes"]) == TYPE_DICTIONARY:
		playerBlendShapes = data["blend_shapes"].duplicate(true)
	if data.has("buttons") and typeof(data["buttons"]) == TYPE_ARRAY:
		for buttonText in data["buttons"]:
			buttonText = str(buttonText)

			if !playerSexes.has(buttonText):
				playerSexes[buttonText] = "male"

			if !playerRaces.has(buttonText):
				playerRaces[buttonText] = "human"

			var defaults = getDefaultEquipmentFor(playerRaces[buttonText], playerSexes[buttonText])

			if !playerEquipment.has(buttonText):
				playerEquipment[buttonText] = defaults.duplicate(true)
			else:
				for slot in defaults:
					if !playerEquipment[buttonText].has(slot):
						playerEquipment[buttonText][slot] = defaults[slot]

			if !playerBoneScale.has(buttonText):
				playerBoneScale[buttonText] = {}

			for boneName in editableBones:

				if !playerBoneScale[buttonText].has(boneName):
					playerBoneScale[buttonText][boneName] = {
						"scale":1.0,
						"width":1.0,
						"height":1.0,
						"depth":1.0,
						"rotation":0.0,
						"position":Vector3()
					}
				elif typeof(playerBoneScale[buttonText][boneName]) != TYPE_DICTIONARY:
					var oldScale = float(playerBoneScale[buttonText][boneName])

					playerBoneScale[buttonText][boneName] = {
						"scale":oldScale,
						"width":1.0,
						"height":1.0,
						"depth":1.0,
						"rotation":0.0,
						"position":Vector3()
					}
				else:
					var bone:Dictionary = playerBoneScale[buttonText][boneName]

					if !bone.has("scale"):
						bone["scale"] = 1.0
					if !bone.has("width"):
						bone["width"] = 1.0
					if !bone.has("height"):
						bone["height"] = 1.0
					if !bone.has("depth"):
						bone["depth"] = 1.0
					if !bone.has("rotation"):
						bone["rotation"] = 0.0
					if !bone.has("position"):
						bone["position"] = 0.0

					playerBoneScale[buttonText][boneName] = bone

			createPlayerButton(buttonText)

	selectLastCharacter()
	applyBlendShapes()


func safeLoadButtonList() -> Dictionary:
	var file := File.new()
	if file.file_exists(SAVE_PATH):
		if file.open(SAVE_PATH, File.READ) == OK:
			var data = file.get_var()
			file.close()
			if typeof(data) == TYPE_DICTIONARY and data.has("buttons") and typeof(data["buttons"]) == TYPE_ARRAY and !data["buttons"].empty():
				return data
	var bak_path := SAVE_PATH + ".bak"
	if file.file_exists(bak_path):
		if file.open(bak_path, File.READ) == OK:
			var data = file.get_var()
			file.close()
			if typeof(data) == TYPE_DICTIONARY:
				return data
	return {}

