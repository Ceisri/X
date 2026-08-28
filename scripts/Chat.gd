# ============================================================
# Chat.gd — FULL FILE REPLACEMENT
# ============================================================
extends Control
onready var player=$"../.."
onready var background= $BG
onready var chatbox:RichTextLabel=$RichTextLabel
onready var system_chatbox:RichTextLabel= $SystemChat
onready var proxy_chatbox:RichTextLabel = $ProximityChat
onready var line_edit=$LineEdit
onready var tween=$Tween
onready var send=$SendButton
onready var general_chat_button=$GeneralChatButton
onready var system_chat_button=$SystemChatButton
onready var proxy_chat_button=$ProximityChatButton
onready var proxy_chat_3D_label:Label3D = $"../../ProximityChat3DLabel"
var hide_timer=null

var chat_mode := "general" # "general"  "proximity"

func _ready():
	add_to_group("ChatUI")
	background.connect("mouse_entered",self,"mouseEntered")
	background.connect("mouse_exited",self,"mouseExited")
	send.connect("pressed",self,"sendButtonPressed")
	general_chat_button.connect("pressed",self,"showGeneralChat")
	system_chat_button.connect("pressed",self,"showSystemChat")
	proxy_chat_button.connect("pressed",self,"showProxyChat")
	line_edit.connect("gui_input",self,"_on_line_edit_gui_input")
	modulate.a=0.3
	line_edit.text=""
	system_chatbox.text=""
	chatbox.text=""
	proxy_chatbox.text=""
	proxy_chatbox.hide()
	if is_instance_valid(proxy_chat_3D_label):
		proxy_chat_3D_label.visible=false
	chat_mode="general"
	line_edit.connect("text_changed",self,"writing")
	line_edit.connect("focus_exited",self,"stopWriting")

func writing(text)->void:
	player.is_writing=true
func stopWriting()->void:
	player.is_writing=false

func showProxyChat():
	chatbox.hide()
	$RichTextLabel3.hide()

	proxy_chatbox.show()
	chat_mode="proximity"

func showGeneralChat():
	chatbox.show()
	proxy_chatbox.hide()

	$RichTextLabel3.hide()
	chat_mode="general"

var system_button_flash=false
func sendSystemMessage(m):
	system_chatbox.append_bbcode("%s\n"%m)
	flashSystemButton()

remote func receiveSystemMessage(message:String) -> void:
	sendSystemMessage(message)

func flashSystemButton():
	if chatbox.visible == false:
		return
	if system_button_flash:
		system_chat_button.modulate=Color(1,1,1)
		tween.stop_all()
	system_button_flash=true
	var button=system_chat_button
	tween.stop_all()
	tween.interpolate_property(button,"modulate",button.modulate,Color(1,1,0),0.10,Tween.TRANS_SINE,Tween.EASE_OUT)
	tween.interpolate_property(button,"modulate",Color(1,1,0),Color(1,0,0),0.12,Tween.TRANS_SINE,Tween.EASE_IN_OUT,0.10)
	tween.interpolate_property(button,"modulate",Color(1,0,0),Color(1,1,0),0.12,Tween.TRANS_SINE,Tween.EASE_IN_OUT,0.22)
	tween.interpolate_property(button,"modulate",Color(1,1,0),Color(1,1,1),0.16,Tween.TRANS_SINE,Tween.EASE_OUT,0.34)
	tween.start()

var general_button_flash=false
func flashGeneralButton():
	if chatbox.visible == true:
		return
	if general_button_flash:
		general_chat_button.modulate=Color(1,1,1)
		tween.stop_all()
	general_button_flash=true
	var button=general_chat_button
	tween.stop_all()
	tween.interpolate_property(button,"modulate",button.modulate,Color(1,1,0),0.10,Tween.TRANS_SINE,Tween.EASE_OUT)
	tween.interpolate_property(button,"modulate",Color(1,1,0),Color(1,0,0),0.12,Tween.TRANS_SINE,Tween.EASE_IN_OUT,0.10)
	tween.interpolate_property(button,"modulate",Color(1,0,0),Color(1,1,0),0.12,Tween.TRANS_SINE,Tween.EASE_IN_OUT,0.22)
	tween.interpolate_property(button,"modulate",Color(1,1,0),Color(1,1,1),0.16,Tween.TRANS_SINE,Tween.EASE_OUT,0.34)
	tween.start()

var proxy_button_flash=false
func flashProxyButton():
	if proxy_chatbox.visible == false:
		return
	if proxy_button_flash:
		proxy_chat_button.modulate=Color(1,1,1)
		tween.stop_all()
	proxy_button_flash=true
	var button=proxy_chat_button
	tween.stop_all()
	tween.interpolate_property(button,"modulate",button.modulate,Color(1,1,0),0.10,Tween.TRANS_SINE,Tween.EASE_OUT)
	tween.interpolate_property(button,"modulate",Color(1,1,0),Color(1,0,0),0.12,Tween.TRANS_SINE,Tween.EASE_IN_OUT,0.10)
	tween.interpolate_property(button,"modulate",Color(1,0,0),Color(1,1,0),0.12,Tween.TRANS_SINE,Tween.EASE_IN_OUT,0.22)
	tween.interpolate_property(button,"modulate",Color(1,1,0),Color(1,1,1),0.16,Tween.TRANS_SINE,Tween.EASE_OUT,0.34)
	tween.start()

func mouseEntered():
	if hide_timer:hide_timer.stop()
	fade(1.0)
func mouseExited():
	if !player.is_chatting:startHideTimer()
func startHideTimer():
	if hide_timer:hide_timer.stop()
	else:
		hide_timer=Timer.new()
		hide_timer.one_shot=true
		hide_timer.wait_time=15.0
		hide_timer.connect("timeout",self,"_on_hide_timeout")
		add_child(hide_timer)
	hide_timer.start()
func _on_hide_timeout():
	if !player.is_chatting:fade(0.3)
func fade(a):
	tween.stop_all()
	tween.interpolate_property(self,"modulate:a",modulate.a,a,0.15,Tween.TRANS_SINE,Tween.EASE_OUT)
	tween.start()
func _on_line_edit_gui_input(e):
	if e is InputEventKey and e.pressed and !e.echo:
		if Input.is_action_just_pressed("Enter"):
			if player.is_chatting:sendMessage()
			else:
				player.is_chatting=true
				line_edit.grab_focus()
				if hide_timer:hide_timer.stop()
				fade(1.0)
			accept_event()
		elif e.scancode==KEY_ESCAPE:
			player.is_chatting=false
			line_edit.release_focus()
			startHideTimer()
			accept_event()
func sendButtonPressed():
	sendMessage()

func sendMessage():
	var m=line_edit.text.strip_edges()
	if m=="":
		player.is_chatting=false
		line_edit.release_focus()
		startHideTimer()
		return

	if chat_mode=="proximity":
		sendProximityChatMessage(m)
	else:
		if get_tree().network_peer != null:
			rpc_id(1, "requestSendChatMessage", player.entity_name, m)
		else:
			chatbox.append_bbcode("[b]%s:[/b] %s\n"%[player.entity_name,m])

	line_edit.clear()
	player.is_chatting=false
	line_edit.release_focus()
	fade(1.0)
	startHideTimer()

remote func requestSendChatMessage(entity_name:String, message:String) -> void:
	if !get_tree().is_network_server():
		return
	message = message.strip_edges()
	if message == "" or message.length() > 500:
		return
	receiveChatMessage(entity_name, message)
	rpc("receiveChatMessage", entity_name, message)

remote func receiveChatMessage(entity_name:String, message:String) -> void:
	var chat_ui = _findLocalChatUI()
	if chat_ui == null:
		return
	chat_ui.chatbox.append_bbcode("[b]%s:[/b] %s\n"%[entity_name,message])
	if chat_ui != self:
		chat_ui.flashGeneralButton()

func _findLocalChatUI() -> Control:
	var local_id = get_tree().get_network_unique_id()
	for chat_ui in get_tree().get_nodes_in_group("ChatUI"):
		if !is_instance_valid(chat_ui) or !is_instance_valid(chat_ui.player):
			continue
		if chat_ui.player.get_network_master() == local_id:
			return chat_ui
	return null

# ---------------- PROXIMITY CHAT ----------------

export var proximity_chat_radius := 400.0
export var proximity_label_duration := 6.0
var proximity_label_timer:Timer = null

func sendProximityChatMessage(m:String) -> void:
	# Show it on our own chatbox + our own 3D label immediately, online or offline.
	proxy_chatbox.append_bbcode("[b]%s:[/b] %s\n" % [player.entity_name, m])
	showProximityLabel3D(m)

	if get_tree().network_peer != null:
		rpc_id(1, "requestSendProximityChatMessage", player.entity_name, m)

remote func requestSendProximityChatMessage(entity_name:String, message:String) -> void:
	if !get_tree().is_network_server():
		return
	message = message.strip_edges()
	if message == "" or message.length() > 500:
		return
	if !is_instance_valid(player):
		return

	receiveProximityChatMessage(entity_name, message)

	var world = player.get_parent()
	if !is_instance_valid(world) or !("world_id" in world):
		return

	var origin = player.global_transform.origin
	var nearby = Global.queryRadius(world.world_id, origin, proximity_chat_radius)
	var my_peer = player.get_network_master()
	var notified := {my_peer: true}

	for node in nearby:
		if !is_instance_valid(node) or !node.is_in_group("Player") or node == player:
			continue
		var peer_id = node.get_network_master()
		if notified.has(peer_id):
			continue
		notified[peer_id] = true
		rpc_id(peer_id, "receiveProximityChatMessage", entity_name, message)

remote func receiveProximityChatMessage(entity_name:String, message:String) -> void:
	showProximityLabel3D(message)
	var chat_ui = _findLocalChatUI()
	if chat_ui == null:
		return
	chat_ui.proxy_chatbox.append_bbcode("[b]%s:[/b] %s\n" % [entity_name, message])
	if chat_ui != self:
		chat_ui.flashProxyButton()

func readyProximityLabelTimer() -> void:
	if is_instance_valid(proximity_label_timer):
		return
	proximity_label_timer = Timer.new()
	proximity_label_timer.one_shot = true
	proximity_label_timer.wait_time = proximity_label_duration
	proximity_label_timer.connect("timeout", self, "hideProximityLabel")
	add_child(proximity_label_timer)

func showProximityLabel3D(message:String) -> void:
	if !is_instance_valid(proxy_chat_3D_label):
		return
	readyProximityLabelTimer()
	proxy_chat_3D_label.text = message
	proxy_chat_3D_label.visible = true
	proximity_label_timer.start()

func hideProximityLabel() -> void:
	if is_instance_valid(proxy_chat_3D_label):
		proxy_chat_3D_label.visible = false

func _on_BugHunting_pressed():
	$RichTextLabel3.show()
	$RichTextLabel.hide()
