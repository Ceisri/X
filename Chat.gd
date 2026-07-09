extends Control

onready var player=$"../.."
onready var background= $BG
onready var chatbox=$RichTextLabel
onready var system_chatbox=$RichTextLabel2
onready var line_edit=$LineEdit
onready var tween=$Tween
onready var send=$SendButton
onready var general_chat_button=$GeneralChatButton
onready var system_chat_button=$SystemChatButton
var hide_timer=null

func _ready():
	background.connect("mouse_entered",self,"mouseEntered")
	background.connect("mouse_exited",self,"mouseExited")
	send.connect("pressed",self,"sendButtonPressed")
	general_chat_button.connect("pressed",self,"showGeneralChat")
	system_chat_button.connect("pressed",self,"showsystemChat")
	line_edit.connect("gui_input",self,"_on_line_edit_gui_input")
	modulate.a=0.3
	line_edit.text=""
	system_chatbox.text=""
	chatbox.text=""
	system_chatbox.hide()


func showsystemChat():
	system_chatbox.show()
	chatbox.hide()
	$RichTextLabel3.hide()
func showGeneralChat():
	system_chatbox.hide()
	chatbox.show()
	$RichTextLabel3.hide()
var system_button_flash=false

func sendSystemMessage(m):
	system_chatbox.append_bbcode("%s\n"%m)
	flashSystemButton()

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
	chatbox.append_bbcode("[b]%s:[/b] %s\n"%[player.entity_name,m])
	line_edit.clear()
	player.is_chatting=false
	line_edit.release_focus()
	fade(1.0)
	startHideTimer()


func _on_BugHunting_pressed():
	$RichTextLabel3.show()
	$RichTextLabel2.hide()
	$RichTextLabel.hide()
