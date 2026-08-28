extends Node
export var port := 8910
export var max_players := 100
var worlds := {}
onready var full_Screen_rich_text_label:RichTextLabel = $RichTextLabel

export var dashboard_update_interval := 5.0
var _dashboard_timer := Timer.new()
var _server_start_time := 0

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_server_start_time = OS.get_ticks_msec()
	Engine.target_fps = 25
	Network.start_server(port, max_players)
	Network.connect("player_connected", self, "_on_player_connected")
	Network.connect("player_disconnected", self, "_on_player_disconnected")
	for world_id in Global.allWorldIds():
		var path = Global.getScenePath(world_id)
		var scene:PackedScene = load(path)
		if scene == null:
			push_error("Server.gd: no scene for world_id '" + world_id + "' (" + path + ")")
			continue
		var instance = scene.instance()
		instance.world_id = world_id
		get_tree().root.add_child(instance)
		worlds[world_id] = instance
	print("=== SERVER RUNNING on port ", port, " ===")

	add_child(_dashboard_timer)
	_dashboard_timer.wait_time = dashboard_update_interval
	_dashboard_timer.connect("timeout", self, "_updateDashboard")
	_dashboard_timer.start()
	_updateDashboard()

func _on_player_connected(id:int) -> void: print("Player joined: ", id)
func _on_player_disconnected(id:int) -> void: print("Player left: ", id)
func _notification(what:int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		get_tree().quit()


func _formatUptime(ms:int) -> String:
	var total_seconds = ms / 1000
	return "%02d:%02d:%02d" % [total_seconds / 3600, (total_seconds % 3600) / 60, total_seconds % 60]

func _countCreatedCharacters() -> int:
	var base = "user://PlayerSaves/"
	var dir = Directory.new()
	if !dir.dir_exists(base):
		return 0
	var count = 0
	if dir.open(base) == OK:
		dir.list_dir_begin(true, true)
		var server_folder = dir.get_next()
		while server_folder != "":
			if dir.current_is_dir():
				var sub = Directory.new()
				if sub.open(base + server_folder) == OK:
					sub.list_dir_begin(true, true)
					var char_folder = sub.get_next()
					while char_folder != "":
						if sub.current_is_dir():
							count += 1
						char_folder = sub.get_next()
					sub.list_dir_end()
			server_folder = dir.get_next()
		dir.list_dir_end()
	return count

# ---- manual RTT tracking (ENetPacketPeer stats aren't exposed to GDScript) ----
var _ping_sent_at := {}   # peer_id -> msec timestamp of last ping sent
var _last_rtt := {}       # peer_id -> last measured RTT in ms
export var ping_interval := 2.0
var _ping_timer := 0.0


remote func _receivePing() -> void:
	rpc_id(1, "_receivePong")



func _getConnectionQuality(peer_id:int) -> String:
	var ping = Network.getPingMs(peer_id)
	if ping < 0:
		return "measuring..."
	return str(ping) + " ms ping"
func _updateDashboard() -> void:
	if !is_instance_valid(full_Screen_rich_text_label):
		return

	var text := "[b]=== SERVER DASHBOARD ===[/b]\n"
	text += "Uptime: " + _formatUptime(OS.get_ticks_msec() - _server_start_time) + "\n"
	text += "Players online: " + str(Global.spawned_players.size()) + " / " + str(max_players) + "\n"
	text += "Characters created: " + str(_countCreatedCharacters()) + "\n\n"

	text += "[b]-- PERFORMANCE --[/b]\n"
	text += "FPS: " + str(Performance.get_monitor(Performance.TIME_FPS)) + "\n"
	text += "Process time: " + str(stepify(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01)) + " ms\n"
	text += "Physics time: " + str(stepify(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01)) + " ms\n"
	text += "Static memory: " + str(stepify(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01)) + " MB\n"
	text += "Dynamic memory: " + str(stepify(Performance.get_monitor(Performance.MEMORY_DYNAMIC) / 1048576.0, 0.01)) + " MB\n"
	text += "Object count: " + str(Performance.get_monitor(Performance.OBJECT_COUNT)) + "\n"
	text += "Node count: " + str(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) + "\n"
	text += "(no cross-platform CPU%/GPU usage API in Godot 3.x headless)\n\n"

	text += "[b]-- PLAYERS --[/b]\n"
	for peer_id in Global.spawned_players.keys():
		var data = Global.spawned_players[peer_id]
		var entity_name = str(data.get("entity_name",""))
		var world_id = str(data.get("world_id",""))
		var node = Global.getPlayerNodeByPeer(peer_id)
		var pos_text = "n/a"
		if is_instance_valid(node):
			var p = node.global_transform.origin
			pos_text = "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]
		text += entity_name + " [peer " + str(peer_id) + "] world=" + world_id + " pos=" + pos_text + " | " + _getConnectionQuality(peer_id) + "\n"

	full_Screen_rich_text_label.bbcode_text = text
