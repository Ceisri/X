extends Node
# Autoload this as a singleton named "Network"

const DEFAULT_PORT := 8910
const MAX_PLAYERS := 100

signal player_connected(id)
signal player_disconnected(id)
signal server_started()
signal connected_to_server()
signal connection_failed()
signal server_disconnected()

var is_server := false

# ---- manual RTT tracking (ENetPacketPeer stats aren't exposed to GDScript) ----
var _ping_sent_at := {}
var _last_rtt := {}
export var ping_interval := 2.0
var _ping_timer := 0.0

func _ready() -> void:
	get_tree().connect("network_peer_connected", self, "_on_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_peer_disconnected")
	get_tree().connect("connected_to_server", self, "_on_connected_ok")
	get_tree().connect("connection_failed", self, "_on_connection_failed")
	get_tree().connect("server_disconnected", self, "_on_server_disconnected")
	_checkServerLaunchFlag()
	set_process(false)

func _physics_process(delta:float) -> void:
	if !is_server:
		return
	if get_tree().network_peer == null:
		return
	_ping_timer += delta
	if _ping_timer < ping_interval:
		return
	_ping_timer = 0.0
	for peer_id in get_tree().get_network_connected_peers():
		_ping_sent_at[peer_id] = OS.get_ticks_msec()
		rpc_id(peer_id, "_receivePing")

remote func _receivePing() -> void:
	rpc_id(1, "_receivePong")

remote func _receivePong() -> void:
	if !is_server:
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if !_ping_sent_at.has(sender_id):
		return
	_last_rtt[sender_id] = OS.get_ticks_msec() - _ping_sent_at[sender_id]
	_ping_sent_at.erase(sender_id)

func getPingMs(peer_id:int) -> int:
	return _last_rtt.get(peer_id, -1)
	


func _checkServerLaunchFlag() -> void:
	if OS.has_feature("editor"):
		return # editor already handles the positional-scene-arg case itself

	for arg in OS.get_cmdline_args():
		if arg == "--server":
			call_deferred("_bootServerScene")
			return

func _bootServerScene() -> void:
	get_tree().change_scene("res://Server.tscn")

# Call this once, from Server.gd, to start listening.
func start_server(port:int = DEFAULT_PORT, max_players:int = MAX_PLAYERS) -> void:
	var peer := NetworkedMultiplayerENet.new()
	var err := peer.create_server(port, max_players)
	if err != OK:
		print("Network: failed to start server (error ", err, ")")
		return
	get_tree().network_peer = peer
	is_server = true
	set_process(true)
	print("Network: server listening on port ", port)
	emit_signal("server_started")

# Call this from a client to connect to a running server.
func join_server(ip:String, port:int = DEFAULT_PORT) -> void:
	remember_target(ip, port)
	var peer := NetworkedMultiplayerENet.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		print("Network: failed to create client (error ", err, ")")
		emit_signal("connection_failed")
		return
	get_tree().network_peer = peer
	is_server = false

func disconnect_network() -> void:
	if get_tree().network_peer:
		intentional_disconnect = true
		get_tree().network_peer.close_connection()
		get_tree().network_peer = null

func _on_peer_connected(id:int) -> void:
	print("Network: peer connected -> ", id)
	emit_signal("player_connected", id)

func _on_peer_disconnected(id:int) -> void:
	print("Network: peer disconnected -> ", id)
	emit_signal("player_disconnected", id)
	ready_peers.erase(id)
func _on_connected_ok() -> void:
	print("Network: connected to server")
	emit_signal("connected_to_server")

func _on_connection_failed() -> void:
	print("Network: connection failed")
	emit_signal("connection_failed")

func _on_server_disconnected() -> void:
	print("Network: lost connection to server")
	emit_signal("server_disconnected")
	if intentional_disconnect:
		intentional_disconnect = false
		return
	if is_server:
		return # the server itself doesn't "reconnect" to anything
	emit_signal("connection_lost")
	_startReconnecting()
signal player_ready(id)
var ready_peers := {}

remote func notify_ready() -> void:
	var id = get_tree().get_rpc_sender_id()
	if id == 0: id = 1
	ready_peers[id] = true
	emit_signal("player_ready", id)

func is_peer_ready(id:int) -> bool:
	return ready_peers.get(id, false)

func mark_client_ready() -> void:
	rpc_id(1, "notify_ready")
var last_ip := ""
var last_port := DEFAULT_PORT
var is_reconnecting := false
var reconnect_attempts := 0
export var max_reconnect_attempts := 10
export var reconnect_interval := 3.0
var intentional_disconnect := false

signal connection_lost()
signal reconnect_attempt(attempt_number)
signal reconnected()
signal reconnect_failed()

func remember_target(ip:String, port:int) -> void:
	last_ip = ip
	last_port = port
func _startReconnecting() -> void:
	if is_reconnecting:
		return
	is_reconnecting = true
	reconnect_attempts = 0
	_attemptReconnect()

func _attemptReconnect() -> void:
	if !is_reconnecting:
		return
	reconnect_attempts += 1
	emit_signal("reconnect_attempt", reconnect_attempts)

	if reconnect_attempts > max_reconnect_attempts:
		is_reconnecting = false
		emit_signal("reconnect_failed")
		return

	var peer := NetworkedMultiplayerENet.new()
	var err := peer.create_client(last_ip, last_port)
	if err != OK:
		call_deferred("_scheduleNextAttempt")
		return

	get_tree().network_peer = peer
	is_server = false

	if !get_tree().is_connected("connected_to_server", self, "_onReconnectSuccess"):
		get_tree().connect("connected_to_server", self, "_onReconnectSuccess", [], CONNECT_ONESHOT)
	if !get_tree().is_connected("connection_failed", self, "_onReconnectFailed"):
		get_tree().connect("connection_failed", self, "_onReconnectFailed", [], CONNECT_ONESHOT)

func _onReconnectSuccess() -> void:
	if get_tree().is_connected("connection_failed", self, "_onReconnectFailed"):
		get_tree().disconnect("connection_failed", self, "_onReconnectFailed")
	is_reconnecting = false
	reconnect_attempts = 0
	emit_signal("reconnected")
	_cleanupStaleLocalPlayer()
	if Global.selected_player_name != "":
		Global.sendSpawnRequestOnceConnected(Global.selected_player_name)

func _onReconnectFailed() -> void:
	if get_tree().is_connected("connected_to_server", self, "_onReconnectSuccess"):
		get_tree().disconnect("connected_to_server", self, "_onReconnectSuccess")
	get_tree().network_peer = null
	_scheduleNextAttempt()

func _scheduleNextAttempt() -> void:
	yield(get_tree().create_timer(reconnect_interval), "timeout")
	_attemptReconnect()

func _cleanupStaleLocalPlayer() -> void:
	# Reconnecting gets a new peer id, so the old player node (still owned
	# by the dead peer id) is now an orphan sitting in the world -- remove it
	# before the server spawns a fresh one under the new id.
	var worlds = get_tree().get_nodes_in_group("World")
	if worlds.empty():
		return
	var world = worlds[0]
	for child in world.get_children():
		if child.is_in_group("Player") and "entity_name" in child and child.entity_name == Global.selected_player_name:
			child.queue_free()
