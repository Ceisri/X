extends Control #Pre-character creation script

const SAVE_PATH = "user://button_list.save"

const SERVER_ADDRESS := "stammer-sensors.tun.ply.gg"
const SERVER_PORT := 16314

onready var scrollContainer:ScrollContainer = $ScrollContainer
onready var gridContainer:GridContainer = $ScrollContainer/GridContainer
onready var buttonTemplate:TextureButton  = $ScrollContainer/GridContainer/TextureButton
onready var characterCreationButton:TextureButton = $CharacterCreation
onready var enter_game_label:Label = $EnterGameLabel
onready var ext_game_button:TextureButton =  $ExitGame
onready var server_button:TextureButton = $ServerButton
onready var server_button_label:Label=$ServerButton/Label
onready var offline_button:TextureButton = $OfflineButton
onready var offline_button_label:Label = $OfflineButton/Label
onready var tween:Tween = $Tween
var play_offline :bool= false
var server_online :bool= false
onready var status_timer :Timer= Timer.new()
var is_probing :bool= false
const PROBE_INTERVAL :float= 5.0
const PROBE_TIMEOUT :float= 3.0

func _ready():
	buttonTemplate.hide()
	enter_game_label.hide()
	for child in gridContainer.get_children():
		if child != buttonTemplate:
			child.queue_free()

	characterCreationButton.connect("pressed", self, "characterCreationPressed")
	ext_game_button.connect("pressed", self, "exitGame")
	offline_button.connect("pressed", self, "_toggleOfflineMode")
	_updateModeLabel()
	loadCharacters()
	hideLoadscreen()
	server_button_label.text = "Checking..."
	add_child(status_timer)
	status_timer.wait_time = PROBE_INTERVAL
	status_timer.connect("timeout", self, "_probeServer")
	status_timer.start()
	_probeServer() # immediate first check



var last_loaded_world_id := ""

func _loadLastWorldIdFor(char_name:String) -> String:
	var file = File.new()
	if !file.file_exists("user://last_world.save"):
		return ""
	if file.open("user://last_world.save", File.READ) != OK:
		return ""
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	if data.get("player","") != char_name:
		return ""
	return str(data.get("world_id",""))


func _toggleOfflineMode():
	play_offline = !play_offline
	offline_button_label.text = "Offline: ON" if play_offline else "Offline: OFF"
	_updateModeLabel()

func _updateModeLabel():
	if play_offline:
		enter_game_label.text = "Enter game and play offline as:"
	else:
		enter_game_label.text = "Enter game and play online as:"




func _probeServer():
	if is_connecting or is_loading or is_probing:
		return

	is_probing = true
	var peer = NetworkedMultiplayerENet.new()
	var err = peer.create_client(SERVER_ADDRESS, SERVER_PORT)
	if err != OK:
		_setServerStatus(false)
		is_probing = false
		return

	get_tree().network_peer = peer

	if !get_tree().is_connected("connected_to_server", self, "_onProbeSuccess"):
		get_tree().connect("connected_to_server", self, "_onProbeSuccess", [], CONNECT_ONESHOT)
	if !get_tree().is_connected("connection_failed", self, "_onProbeFailed"):
		get_tree().connect("connection_failed", self, "_onProbeFailed", [], CONNECT_ONESHOT)

	yield(get_tree().create_timer(PROBE_TIMEOUT), "timeout")

	# If neither signal fired in time, treat as offline and clean up.
	if is_probing:
		_disconnectProbeSignals()
		_setServerStatus(false)
		if get_tree().network_peer == peer:
			get_tree().network_peer = null
		is_probing = false

func _onProbeSuccess():
	if !is_probing:
		return
	_disconnectProbeSignals()
	_setServerStatus(true)
	get_tree().network_peer = null
	is_probing = false

func _onProbeFailed():
	if !is_probing:
		return
	_disconnectProbeSignals()
	_setServerStatus(false)
	get_tree().network_peer = null
	is_probing = false

func _disconnectProbeSignals() -> void:
	if get_tree().is_connected("connected_to_server", self, "_onProbeSuccess"):
		get_tree().disconnect("connected_to_server", self, "_onProbeSuccess")
	if get_tree().is_connected("connection_failed", self, "_onProbeFailed"):
		get_tree().disconnect("connection_failed", self, "_onProbeFailed")

func _setServerStatus(online:bool) -> void:
	server_online = online

	if online:
		server_button_label.text = "Server: Online"
		server_button_label.modulate = Color.green
	else:
		server_button_label.text = "Server: Offline"
		server_button_label.modulate = Color.red
	
func loadCharacters():
	var file = File.new()

	if !file.file_exists(SAVE_PATH):
		return

	if file.open(SAVE_PATH, File.READ) != OK:
		return

	var data = file.get_var()

	file.close()

	if typeof(data) != TYPE_DICTIONARY:
		return

	if !data.has("buttons"):
		return

	if typeof(data["buttons"]) != TYPE_ARRAY:
		return

	for characterName in data["buttons"]:
		createCharacterButton(str(characterName))
		if enter_game_label.visible == false:
			enter_game_label.show()


func createCharacterButton(characterName:String):
	var newButton = buttonTemplate.duplicate()

	newButton.show()
	gridContainer.add_child(newButton)

	newButton.get_node("Label").text = characterName

	newButton.connect("pressed", self, "characterButtonPressed", [characterName])


var pending_character_name := ""
var is_loading := false
var interactive_loader:ResourceInteractiveLoader = null
var is_connecting := false

#func characterButtonPressed(characterName:String):
#	if is_loading or is_connecting:
#		return
#
#	_stopProbing()  
#
#	pending_character_name = characterName
#	Global.selected_player_name = characterName
#
#	if play_offline:
#		get_tree().network_peer = null
#		is_loading = true
#		showLoadscreen()
#		last_loaded_world_id = _loadLastWorldIdFor(characterName)
#		var target_path = "res://World.tscn"
#		if Global.isKnownWorldId(last_loaded_world_id):
#			target_path = Global.getScenePath(last_loaded_world_id)
#		interactive_loader = ResourceLoader.load_interactive(target_path)
#		if interactive_loader == null:
#			push_error("Failed to start loading " + target_path + " (offline)")
#			is_loading = false
#			hideLoadscreen()
#			return
#		real_progress = 0.0
#		displayed_progress = 0.0
#		return
#
#	var peer = NetworkedMultiplayerENet.new()
#	Network.remember_target(SERVER_ADDRESS, SERVER_PORT)
#	var err = peer.create_client(SERVER_ADDRESS, SERVER_PORT)
#	if err != OK:
#		push_error("Failed to create client, error code: " + str(err))
#		return
#
#	get_tree().network_peer = peer
#	is_connecting = true
#	showLoadscreen()
#
#	if get_tree().network_peer.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTED:
#		_beginWorldLoad()
#	else:
#		if !get_tree().is_connected("connected_to_server", self, "_beginWorldLoad"):
#			get_tree().connect("connected_to_server", self, "_beginWorldLoad", [], CONNECT_ONESHOT)
#		if !get_tree().is_connected("connection_failed", self, "_onConnectFailed"):
#			get_tree().connect("connection_failed", self, "_onConnectFailed", [], CONNECT_ONESHOT)

func characterButtonPressed(characterName:String):
	if is_loading or is_connecting:
		return

	if !play_offline and !server_online:
		_flashServerButton()
		return

	_stopProbing()

	pending_character_name = characterName
	Global.selected_player_name = characterName

	if play_offline:
		get_tree().network_peer = null
		is_loading = true
		showLoadscreen()
		last_loaded_world_id = _loadLastWorldIdFor(characterName)

		var target_path = "res://World.tscn"
		if Global.isKnownWorldId(last_loaded_world_id):
			target_path = Global.getScenePath(last_loaded_world_id)

		interactive_loader = ResourceLoader.load_interactive(target_path)
		if interactive_loader == null:
			push_error("Failed to start loading " + target_path + " (offline)")
			is_loading = false
			hideLoadscreen()
			return

		real_progress = 0.0
		displayed_progress = 0.0
		return

	var peer = NetworkedMultiplayerENet.new()
	Network.remember_target(SERVER_ADDRESS, SERVER_PORT)
	var err = peer.create_client(SERVER_ADDRESS, SERVER_PORT)

	if err != OK:
		push_error("Failed to create client, error code: " + str(err))
		return

	get_tree().network_peer = peer
	is_connecting = true
	showLoadscreen()

	if get_tree().network_peer.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTED:
		_beginWorldLoad()
	else:
		if !get_tree().is_connected("connected_to_server", self, "_beginWorldLoad"):
			get_tree().connect("connected_to_server", self, "_beginWorldLoad", [], CONNECT_ONESHOT)
		if !get_tree().is_connected("connection_failed", self, "_onConnectFailed"):
			get_tree().connect("connection_failed", self, "_onConnectFailed", [], CONNECT_ONESHOT)

func _flashServerButton() -> void:
	server_button.rect_pivot_offset = server_button.rect_size / 2.0

	tween.stop_all()
	server_button.modulate = Color.white
	server_button.rect_scale = Vector2.ONE

	tween.interpolate_property(server_button, "modulate",
		Color.white, Color.red, 0.12,
		Tween.TRANS_QUAD, Tween.EASE_OUT)

	tween.interpolate_property(server_button, "modulate",
		Color.red, Color.white, 0.25,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT, 0.12)

	tween.interpolate_property(server_button, "rect_scale",
		Vector2.ONE, Vector2(1.15, 1.15), 0.12,
		Tween.TRANS_BACK, Tween.EASE_OUT)

	tween.interpolate_property(server_button, "rect_scale",
		Vector2(1.15, 1.15), Vector2.ONE, 0.25,
		Tween.TRANS_BACK, Tween.EASE_IN_OUT, 0.12)

	tween.start()

func _stopProbing() -> void:
	status_timer.stop()
	_disconnectProbeSignals()
	is_probing = false
func _disconnectJoinSignals() -> void:
	if get_tree().is_connected("connected_to_server", self, "_beginWorldLoad"):
		get_tree().disconnect("connected_to_server", self, "_beginWorldLoad")
	if get_tree().is_connected("connection_failed", self, "_onConnectFailed"):
		get_tree().disconnect("connection_failed", self, "_onConnectFailed")

func _beginWorldLoad():
	_disconnectJoinSignals()
	is_connecting = false

	interactive_loader = ResourceLoader.load_interactive("res://World.tscn")
	if interactive_loader == null:
		push_error("Failed to start loading World.tscn")
		_onConnectFailed()
		return
	real_progress = 0.0
	displayed_progress = 0.0
	is_loading = true

func _onConnectFailed():
	_disconnectJoinSignals()
	push_error("Could not connect to server")
	is_connecting = false
	is_loading = false
	interactive_loader = null
	if get_tree().network_peer != null:
		get_tree().network_peer = null
	hideLoadscreen()
	status_timer.start()  # resume probing since we're back at the menu
var real_progress := 0.0
var displayed_progress := 0.0
export var progress_catchup_speed := 12 # lower = label lags further behind

onready var loading_label:Label = $LoadingScreen/Label
var waiting_for_player_ready := false
var _player_ready_wait_start := 0
export var player_ready_timeout_ms := 10000

func _process(delta): #from pregameenter.gd
	if waiting_for_player_ready:
		displayed_progress = lerp(displayed_progress, 1.0, delta * progress_catchup_speed)
		if loading_label: loading_label.text = "Loading... " + str(int(displayed_progress * 100)) + "%"

		if Global.isPlayerReady():
			waiting_for_player_ready = false
			hideLoadscreen()
			return

		if OS.get_ticks_msec() - _player_ready_wait_start >= player_ready_timeout_ms:
			push_error("ButtonList.gd: timed out waiting for player_ready, hiding loadscreen anyway")
			waiting_for_player_ready = false
			hideLoadscreen()
		return

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
				real_progress = min(real_progress, 0.99) # keep under 100% until truly done
		ERR_FILE_EOF: # finished loading successfully
			var world_scene:PackedScene = interactive_loader.get_resource()
			interactive_loader = null
			real_progress = 1.0
			finishEnteringWorld(world_scene)
		_: # some error occurred
			interactive_loader = null
			is_loading = false
			hideLoadscreen()
			push_error("Failed to load World.tscn, error code: " + str(err))








func finishEnteringWorld(world_scene:PackedScene):
	is_loading = false

	var world = world_scene.instance()
	if last_loaded_world_id != "" and Global.isKnownWorldId(last_loaded_world_id):
		world.world_id = last_loaded_world_id

	get_tree().root.add_child(world)
	if get_tree().current_scene:
		get_tree().current_scene.queue_free()
	get_tree().current_scene = world

	loading_label.text = "Loading... 99%"
	_waitForPlayerReady()


func _waitForPlayerReady() -> void:
	_player_ready_wait_start = OS.get_ticks_msec()
	if Global.isPlayerReady():
		hideLoadscreen()
		return
	if !Global.is_connected("player_ready", self, "_onPlayerReadySignal"):
		Global.connect("player_ready", self, "_onPlayerReadySignal", [], CONNECT_ONESHOT)
	set_process(true)

func _onPlayerReadySignal() -> void:
	hideLoadscreen()
	
	

	
	
func showLoadscreen()->void:
	$LoadingScreen.visible = true

func hideLoadscreen()->void:
	$LoadingScreen.visible = false

func characterCreationPressed():
	get_tree().change_scene("res://charactercreation.tscn")
func exitGame():
	get_tree().quit()

func _on_RunThisGameasServer_pressed():
	get_tree().change_scene("res://Server.tscn")
