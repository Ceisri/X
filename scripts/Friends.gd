extends Control
# Friends.gd — direct child of UI, direct child of Player.
#
# InspectControl now lives directly under UI (moved out of Party.gd) so both
# Party.gd (Invite button) and this script (Add Friend button) share the same
# inspect popup that appears when clicking another player in the world.
# Party.gd still owns the actual raycast/click detection (tryInspectPlayerAtMouse)
# and clicked_player -- this script just reads that result.




onready var player = $"../.."
onready var party = $"../Party"
onready var chat = $"../Chat"

onready var inspect_control:Control = $"../InspectControl"
onready var add_friend_button:Button = $"../InspectControl/AddFriend"

onready var friends_grid:GridContainer = $ScrollContainer/GridContainer
onready var friend_button_template:Control = $ScrollContainer/GridContainer/FriendButton1

var friends := [] # Array of entity_name Strings
var _friend_rows := {} # entity_name -> row Control

export var refresh_rate := 0.5
var _refresh_timer := 0.0


func _ready():
	add_friend_button.connect("pressed", self, "addFriendPressed")
	friend_button_template.visible = false
	updateFriendsDisplay()
	hide()


func _physics_process(delta)->void:
	if Input.is_action_just_pressed("FriendList") and !player.is_writing:
		visible = !visible 
		player.skill_tree_root.hide()
		player.crafting.hide()
		player.banner_system_control.hide()
		
		
		
	if !is_instance_valid(inspect_control) or !inspect_control.visible:
		pass
	else:
		if !is_instance_valid(party) or !is_instance_valid(party.clicked_player):
			add_friend_button.visible = false
		else:
			var target = party.clicked_player
			if target == player or !("entity_name" in target):
				add_friend_button.visible = false
			else:
				add_friend_button.visible = !isFriend(target.entity_name)
			add_friend_button.visible = !isFriend(target.entity_name) and !pending_sent_requests.has(target.entity_name)
	_refresh_timer += delta
	if _refresh_timer >= refresh_rate:
		_refresh_timer = 0.0
		refreshAllRows()
	

func isFriend(entity_name:String) -> bool:
	return friends.has(entity_name)


var pending_friend_request_name := ""
var pending_friend_request_peer := -1
var pending_sent_requests := [] # entity_names I've sent a request to, awaiting reply


func addFriendPressed() -> void:
	if !is_instance_valid(party) or !is_instance_valid(party.clicked_player):
		return
	var target = party.clicked_player
	if !("entity_name" in target) or target.entity_name == "":
		return
	if target.entity_name == player.entity_name:
		return
	if isFriend(target.entity_name) or pending_sent_requests.has(target.entity_name):
		return
	if get_tree().network_peer == null:
		return

	var target_friends = target.get_node_or_null("UI/Friends")
	if !is_instance_valid(target_friends):
		return

	var target_peer = target.get_network_master()
	target_friends.rpc_id(target_peer, "receiveFriendRequest", player.entity_name, get_tree().get_network_unique_id())

	pending_sent_requests.append(target.entity_name)
	if is_instance_valid(chat):
		chat.sendSystemMessage("friend request sent to " + target.entity_name)


remote func receiveFriendRequest(requester_name:String, requester_peer:int) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if isFriend(requester_name):
		return

	pending_friend_request_name = requester_name
	pending_friend_request_peer = requester_peer

	if is_instance_valid(party):
		party.showConfirmation("friend_request", requester_name, requester_name + " asked you to be friends")


func onFriendRequestAccepted(entity_name:String) -> void:
	if entity_name != pending_friend_request_name:
		return

	if !isFriend(entity_name):
		friends.append(entity_name)
		saveData()
		updateFriendsDisplay()

	var requester_node = party.findPlayerByName(entity_name) if is_instance_valid(party) else null
	if is_instance_valid(requester_node):
		var requester_friends = requester_node.get_node_or_null("UI/Friends")
		if is_instance_valid(requester_friends):
			requester_friends.rpc_id(pending_friend_request_peer, "onFriendRequestConfirmed", player.entity_name)

	if is_instance_valid(chat):
		chat.sendSystemMessage("you are now friends with " + entity_name)

	pending_friend_request_name = ""
	pending_friend_request_peer = -1


func onFriendRequestRefused(entity_name:String) -> void:
	if entity_name != pending_friend_request_name:
		return

	var requester_node = party.findPlayerByName(entity_name) if is_instance_valid(party) else null
	if is_instance_valid(requester_node):
		var requester_friends = requester_node.get_node_or_null("UI/Friends")
		if is_instance_valid(requester_friends):
			requester_friends.rpc_id(pending_friend_request_peer, "onFriendRequestDenied", player.entity_name)

	pending_friend_request_name = ""
	pending_friend_request_peer = -1


remote func onFriendRequestConfirmed(entity_name:String) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	pending_sent_requests.erase(entity_name)
	if !isFriend(entity_name):
		friends.append(entity_name)
		saveData()
		updateFriendsDisplay()
	if is_instance_valid(chat):
		chat.sendSystemMessage(entity_name + " accepted your friend request")


remote func onFriendRequestDenied(entity_name:String) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	pending_sent_requests.erase(entity_name)
	if is_instance_valid(chat):
		chat.sendSystemMessage(entity_name + " denied your friend request")


func removeFriend(entity_name:String) -> void:
	if !friends.has(entity_name):
		return
	friends.erase(entity_name)
	saveData()
	updateFriendsDisplay()


# ---------------- Display ----------------

func updateFriendsDisplay() -> void:
	for child in friends_grid.get_children():
		if child != friend_button_template:
			child.queue_free()
	_friend_rows.clear()

	for entity_name in friends:
		var row = friend_button_template.duplicate()
		row.visible = true
		friends_grid.add_child(row)
		_friend_rows[entity_name] = row

		var name_label = row.get_node_or_null("FriendNameLabel")
		if is_instance_valid(name_label):
			name_label.text = entity_name

		var remove_btn = row.get_node_or_null("Remove")
		var invite_btn = row.get_node_or_null("Invite")
		var cancel_btn = row.get_node_or_null("Cancel")

		if is_instance_valid(remove_btn):
			remove_btn.visible = false
			if remove_btn.is_connected("pressed", self, "removePressed"):
				remove_btn.disconnect("pressed", self, "removePressed")
			remove_btn.connect("pressed", self, "removePressed", [entity_name])

		if is_instance_valid(invite_btn):
			invite_btn.visible = false
			if invite_btn.is_connected("pressed", self, "invitePressed"):
				invite_btn.disconnect("pressed", self, "invitePressed")
			invite_btn.connect("pressed", self, "invitePressed", [entity_name])

		if is_instance_valid(cancel_btn):
			cancel_btn.visible = false
			if cancel_btn.is_connected("pressed", self, "cancelPressed"):
				cancel_btn.disconnect("pressed", self, "cancelPressed")
			cancel_btn.connect("pressed", self, "cancelPressed", [entity_name])

		if row.has_signal("pressed"):
			if row.is_connected("pressed", self, "rowPressed"):
				row.disconnect("pressed", self, "rowPressed")
			row.connect("pressed", self, "rowPressed", [entity_name])

	refreshAllRows()


func rowPressed(entity_name:String) -> void:
	var row = _friend_rows.get(entity_name)
	if !is_instance_valid(row):
		return

	var remove_btn = row.get_node_or_null("Remove")
	var invite_btn = row.get_node_or_null("Invite")
	var cancel_btn = row.get_node_or_null("Cancel")
	var showing = is_instance_valid(remove_btn) and remove_btn.visible

	# collapse every other row's expanded buttons first, only one open at a time
	for other_name in _friend_rows.keys():
		var other_row = _friend_rows[other_name]
		if !is_instance_valid(other_row):
			continue
		var orb = other_row.get_node_or_null("Remove")
		var oib = other_row.get_node_or_null("Invite")
		var ocb = other_row.get_node_or_null("Cancel")
		if is_instance_valid(orb): orb.visible = false
		if is_instance_valid(oib): oib.visible = false
		if is_instance_valid(ocb): ocb.visible = false

	if !showing:
		if is_instance_valid(remove_btn): remove_btn.visible = true
		if is_instance_valid(cancel_btn): cancel_btn.visible = true
		if is_instance_valid(invite_btn): invite_btn.visible = canInviteFriend(entity_name)


func cancelPressed(entity_name:String) -> void:
	var row = _friend_rows.get(entity_name)
	if !is_instance_valid(row):
		return
	var remove_btn = row.get_node_or_null("Remove")
	var invite_btn = row.get_node_or_null("Invite")
	var cancel_btn = row.get_node_or_null("Cancel")
	if is_instance_valid(remove_btn): remove_btn.visible = false
	if is_instance_valid(invite_btn): invite_btn.visible = false
	if is_instance_valid(cancel_btn): cancel_btn.visible = false


func removePressed(entity_name:String) -> void:
	removeFriend(entity_name)


func invitePressed(entity_name:String) -> void:
	if !is_instance_valid(party):
		return
	var target = party.findPlayerByName(entity_name)
	if !is_instance_valid(target):
		return
	party.clicked_player = target
	party.invitePressed()
	cancelPressed(entity_name)


func canInviteFriend(entity_name:String) -> bool:
	if !is_instance_valid(party):
		return false
	var target = party.findPlayerByName(entity_name)
	if !is_instance_valid(target):
		return false # offline/unresolved -- nothing to invite
	return party.canInviteToParty(target)


func refreshAllRows() -> void:
	for entity_name in _friend_rows.keys():
		var row = _friend_rows[entity_name]
		if !is_instance_valid(row):
			continue

		var target = party.findPlayerByName(entity_name) if is_instance_valid(party) else null
		var is_online = is_instance_valid(target)

		var online_texture = row.get_node_or_null("Onlinetexture")
		if is_instance_valid(online_texture):
			online_texture.modulate = Color(0,1,0) if is_online else Color(1,0,0)

		var invite_btn = row.get_node_or_null("Invite")
		if is_instance_valid(invite_btn) and invite_btn.visible:
			invite_btn.visible = canInviteFriend(entity_name)


# ---------------- Save / Load, routed through World.gd like Inventory/Equipment/Crafting ----------------

func gatherFriendsSnapshot() -> Dictionary:
	return {"friends": friends.duplicate()}

remote func applyOwnFriendsSnapshot(data:Dictionary) -> void:
	if data.empty():
		return
	friends = data.get("friends", []).duplicate()
	updateFriendsDisplay()

func saveData() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	var world = player.get_parent()
	if is_instance_valid(world) and world.has_method("saveFriendsFor"):
		world.saveFriendsFor(player, gatherFriendsSnapshot())

remote func requestSelfSaveFriends() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	saveData()
