extends Control
### Party.gd — direct child of UI, direct child of Player.
###
### Client-authoritative party system: no central server-side party object,
### each player's own Party node holds its own view of the roster and pushes
### updates to other members' Party nodes directly via targeted RPCs
### (rpc_id). The server only stores a passive mirror (Global.party_rosters)
### for lookups elsewhere -- it never drives party logic itself.
###
### [b]Roster shape[/b]
### party_members: Array of {"entity_name":String, "peer_id":int}, always
### excludes the local player. party_leader_name holds the current leader's
### entity_name (empty string "" means no party / not in a party).
###
### [b]Inviting[/b]
### Click a player in the 3D world (_unhandled_input -> tryInspectPlayerAtMouse)
### to raycast for a Player node and show InspectControl with an Invite button.
### canInviteToParty() hides the button client-side when: I'm in a party but
### not its leader, or the target already appears to be in a party (based on
### MY possibly-stale copy of their Party node -- see below). Pressing Invite
### sends receivePartyInvite to the target, who re-checks their OWN
### party_members/party_leader_name (authoritative, since it's their own
### state) and rejects via onInviteRejected if they're already partied --
### this is the real guard; the button-hide is just a convenience since a
### non-member's copy of someone else's roster can be stale or never synced.
###
### [b]Accepting[/b]
### The invitee sees InvitedControl (confirm_mode == "invite") and can
### Accept/Refuse. Accepting sends onPartyMemberJoined to the inviter, who
### becomes leader if this is their first member, adds the joiner to
### party_members, then broadcastPartyListToAll() to converge everyone's
### roster, and announces the join to the party.
###
### [b]Roster sync[/b]
### The leader acts as the sync anchor: any time the roster changes
### (join/kick/promote/leave), the leader calls broadcastPartyListToAll(),
### which builds the full roster (party_members + leader's own info) and
### sends each member a version with themselves excluded, via syncPartyList.
### Every member also calls reportPartyToServer() after any local roster
### change, keeping Global.party_rosters (server-side mirror) current.
###
### [b]Kick / Promote[/b]
### Leader-only (isLocalPlayerLeader() gate). Clicking a member's row
### (rowPressed) reveals that row's kick/promote buttons (only one row's
### buttons open at a time) and also reveals the Leave button for everyone.
### kickPressed/promotePressed reuse InvitedControl as a yes/no confirmation
### (confirm_mode == "kick"/"promote"), resolved in acceptPressed/refusePressed.
### doKick removes the target, RPCs them onKicked (clears their own party
### state), then re-broadcasts and announces to the remaining party.
### doPromote reassigns party_leader_name, re-broadcasts, and announces.
###
### [b]Leaving[/b]
### leavePressed() removes the local player from the party. If the leaver
### was the leader, the oldest remaining member (party_members[0], since
### members are appended in join order and never reordered) is auto-promoted
### to leader before the roster is cleared. Every remaining member gets
### onMemberLeft(my_name, new_leader_name) to drop the leaver from their
### roster and (if applicable) adopt the new leader name locally -- including
### the new leader themselves, whose isLocalPlayerLeader() becomes true the
### instant they receive it. A single system message announces both the
### departure and the new leader in one line.
###
### [b]System messages[/b]
### Chat.gd's system tab is normally local-only (each client only sees its
### own system messages). This script is one of the few things allowed to
### push a system message onto another peer's chat directly, via
### sendSystemMessageToEntity() (single target) or notifyPartySystemMessage()
### (whole current party, optionally including self). Used for: someone
### invites you, someone joins, someone refuses an invite, someone is
### promoted, someone is kicked, someone leaves (and who the new leader is).
###
### Display
### updateMembersDisplay() rebuilds one row per OTHER party member (never a
### row for yourself) from player_template, wiring up kick/promote/row-click
### handlers. refreshAllRows() runs on a timer (refresh_rate) to keep each
### row's HP/AR/EN bars and labels live by reading the corresponding
### in-world Player node's Stats.
#
#
#
onready var player = $"../.."
onready var chat = $"../Chat"
onready var friends = $"../Friends"
onready var banner = $"../BannerSystem"
onready var members_grid:GridContainer = $MembersGrid
onready var player_template:Control = $MembersGrid/Player1

onready var inspect_control:Control = $"../InspectControl"
onready var invite_button:Button = $"../InspectControl/InviteToParty"

onready var invited_control:Control = $"../RequestControl"
onready var accept_button:Button = $"../RequestControl/Accept"
onready var refuse_button:Button = $"../RequestControl/Refuse"
onready var invited_label:Label = $"../RequestControl/invitedLabel"
onready var leave_button:Button = $Leave
onready var close_inspect_button:TextureButton = $"../InspectControl/Close"


var clicked_player:Node = null

var pending_invite_name := ""
var pending_invite_peer := -1

var party_members := [] # Array of {"entity_name":String,"peer_id":int}, excludes self
var _member_rows := {} # entity_name -> row Control

var party_leader_name := "" # entity_name of the current party leader

# InvitedControl/Accept/Refuse is reused for three different confirmations:
# "invite" (someone invited me), "kick", "promote"
var confirm_mode := "invite"
var confirm_target_name := ""

var refresh_rate := 0.2
var _refresh_timer := 0.0


func _ready():
	player_template.visible = false
	inspect_control.hide()
	invited_control.hide()
	leave_button.hide()
	var ui = get_parent()
	if is_instance_valid(ui) and ui is Control:
		ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	invite_button.connect("pressed", self, "invitePressed")
	accept_button.connect("pressed", self, "acceptPressed")
	refuse_button.connect("pressed", self, "refusePressed")
	leave_button.connect("pressed", self, "leavePressed")
	close_inspect_button.connect("pressed", self, "closeInspect")
	updateMembersDisplay()


	if get_tree().network_peer != null:
		call_deferred("_tryRequestPartyRestore")

func _physics_process(delta)->void:
	_refresh_timer += delta
	if _refresh_timer >= refresh_rate:
		_refresh_timer = 0.0
		refreshAllRows()


func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			return
		tryInspectPlayerAtMouse(event.position)


func closeInspect()->void:
	$"../InspectControl".visible = false



func _sendToPeer(target_peer:int, node_path:String, method:String, args:Array) -> void:
	if get_tree().network_peer == null:
		return
	if get_tree().is_network_server():
		var target_player = Global.getPlayerNodeByPeer(target_peer)
		if !is_instance_valid(target_player):
			return
		var target_node = target_player.get_node_or_null(node_path)
		if is_instance_valid(target_node):
			target_node.callv("rpc_id", [target_peer, method] + args)
	else:
		Global.rpc_id(1, "relayToPeer", target_peer, node_path, method, args)
func tryInspectPlayerAtMouse(mouse_pos:Vector2) -> void:
	var camera = get_viewport().get_camera()
	if camera == null:
		return

	if !is_instance_valid(player):
		return

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0

	var space_state = player.get_world().direct_space_state
	var result = space_state.intersect_ray(from, to, [player])

	if result.empty():
		inspect_control.hide()
		clicked_player = null
		return

	var target_player = resolvePlayerFromCollider(result.collider)

	if target_player == null or target_player == player:
		inspect_control.hide()
		clicked_player = null
		return

	clicked_player = target_player
	invite_button.visible = canInviteToParty(target_player)

	inspect_control.rect_global_position = mouse_pos
	inspect_control.show()
	
const PARTY_REFUSE_COOLDOWN_MS := 300000 # 5 real minutes
var recently_refused_by := {} # entity_name -> ms timestamp of last refusal

func markRefused(entity_name:String) -> void:
	recently_refused_by[entity_name] = OS.get_ticks_msec()
func canInviteToParty(target:Node) -> bool:
	if !("entity_name" in target) or target.entity_name == "":
		return false
	if target.entity_name == player.entity_name:
		return false

	for m in party_members:
		if m.entity_name == target.entity_name:
			return false

	if !party_members.empty() and !isLocalPlayerLeader():
		return false

	if recently_refused_by.has(target.entity_name):
		var elapsed_ms = OS.get_ticks_msec() - recently_refused_by[target.entity_name]
		if elapsed_ms < PARTY_REFUSE_COOLDOWN_MS:
			return false
		recently_refused_by.erase(target.entity_name)

	var target_party = target.get_node_or_null("UI/Party")
	if is_instance_valid(target_party):
		if !target_party.party_members.empty() or target_party.party_leader_name != "":
			return false

	return true




func resolvePlayerFromCollider(node:Node) -> Node:
	var n = node
	while n:
		if n.is_in_group("Player"):
			return n
		n = n.get_parent()
	return null


func findPlayerByName(entity_name:String) -> Node:
	if get_tree().network_peer != null:
		var found = Global.getPlayerNode(entity_name)
		if is_instance_valid(found):
			return found
	else:
		if is_instance_valid(player) and player.entity_name == entity_name:
			return player
	for b in get_tree().get_nodes_in_group("BOT"):
		if is_instance_valid(b) and "entity_name" in b and b.entity_name == entity_name:
			return b
	return null


# ---------------- Invite flow ----------------
func invitePressed():
	inspect_control.hide()
	if !is_instance_valid(clicked_player) or !canInviteToParty(clicked_player):
		return

	if clicked_player.is_in_group("BOT"):
		inviteBotToParty(clicked_player)
		return

	if get_tree().network_peer == null:
		return
	var target_peer = clicked_player.get_network_master()
	_sendToPeer(target_peer, "UI/Party", "receivePartyInvite", [player.entity_name, get_tree().get_network_unique_id()])
	chat.sendSystemMessage("party invite sent to " + clicked_player.entity_name)
#func invitePressed():
#	inspect_control.hide()
#	if !is_instance_valid(clicked_player) or !canInviteToParty(clicked_player):
#		return
#
#	if clicked_player.is_in_group("BOT"):
#		addPartyMember({"entity_name": clicked_player.entity_name, "peer_id": -1})
#		if party_leader_name == "":
#			party_leader_name = player.entity_name
#		if get_tree().network_peer != null:
#			broadcastPartyListToAll()
#		if is_instance_valid(chat):
#			chat.sendSystemMessage(clicked_player.entity_name + " joined the party")
#		return
#
#	if get_tree().network_peer == null:
#		return
#	var target_peer = clicked_player.get_network_master()
#	_sendToPeer(target_peer, "UI/Party", "receivePartyInvite", [player.entity_name, get_tree().get_network_unique_id()])
	chat.sendSystemMessage("party invite sent to " + clicked_player.entity_name)
func inviteBotToParty(bot:Node) -> void:
	if !is_instance_valid(bot) or !bot.has_method("receiveBotPartyInvite"):
		return
	var lvl:int = int(player.stats.level) if is_instance_valid(player.stats) else 0
	if get_tree().network_peer == null:
		bot.receiveBotPartyInvite(player.entity_name, 1, lvl)
	else:
		Global.rpc_id(1, "requestBotPartyInvite", bot.get_path(), player.entity_name, get_tree().get_network_unique_id(), lvl)
	chat.sendSystemMessage("party invite sent to " + bot.entity_name)








remote func receivePartyInvite(inviter_name:String, inviter_peer:int) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return

	if !party_members.empty() or party_leader_name != "":
		_sendToPeer(inviter_peer, "UI/Party", "onInviteRejected", [player.entity_name])
		return

	pending_invite_name = inviter_name
	pending_invite_peer = inviter_peer

	confirm_mode = "invite"
	invited_label.text = "you have been invited\nto a party by " + inviter_name
	invited_control.show()

	chat.sendSystemMessage(inviter_name + " invited you to a party")
func refusePressed() -> void:
	invited_control.hide()

	if confirm_mode == "kick" or confirm_mode == "promote":
		confirm_mode = "invite"
		confirm_target_name = ""
		return

	if confirm_mode == "friend_request":
		if is_instance_valid(friends):
			friends.onFriendRequestRefused(confirm_target_name)
		confirm_mode = "invite"
		confirm_target_name = ""
		return

	if confirm_mode == "banner_invite":
		if is_instance_valid(banner):
			banner.onBannerInviteRefused(confirm_target_name)
		confirm_mode = "invite"
		confirm_target_name = ""
		return

	if pending_invite_name != "":
		sendSystemMessageToEntity(pending_invite_name, pending_invite_peer, player.entity_name + " refused to join the party")
		_sendToPeer(pending_invite_peer, "UI/Party", "receivePartyInviteRefused", [player.entity_name])

	pending_invite_name = ""
	pending_invite_peer = -1

remote func receivePartyInviteRefused(refuser_name:String) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	markRefused(refuser_name)

func onBotInviteReply(bot_entity_name:String, bot_level:int, accepted:bool) -> void:
	if !accepted:
		chat.sendSystemMessage(bot_entity_name + " declined to join the party")
		markRefused(bot_entity_name)
		return
	if party_members.empty() and party_leader_name == "":
		party_leader_name = player.entity_name
	addPartyMember({"entity_name": bot_entity_name, "peer_id": -1})
	broadcastPartyListToAll()
	notifyPartySystemMessage(bot_entity_name + " joined the party")
remote func onInviteRejected(target_name:String) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	chat.sendSystemMessage(target_name + " couldn't be invited (already in a party)")

func acceptPressed():
	invited_control.hide()

	if confirm_mode == "kick":
		doKick(confirm_target_name)
		confirm_mode = "invite"
		confirm_target_name = ""
		return

	if confirm_mode == "promote":
		doPromote(confirm_target_name)
		confirm_mode = "invite"
		confirm_target_name = ""
		return

	if confirm_mode == "friend_request":
		if is_instance_valid(friends):
			friends.onFriendRequestAccepted(confirm_target_name)
		confirm_mode = "invite"
		confirm_target_name = ""
		return

	if confirm_mode == "banner_invite":
		if is_instance_valid(banner):
			banner.onBannerInviteAccepted(confirm_target_name)
		confirm_mode = "invite"
		confirm_target_name = ""
		return


	if pending_invite_name == "" or get_tree().network_peer == null:
		pending_invite_name = ""
		pending_invite_peer = -1
		return

	var my_info = {"entity_name": player.entity_name, "peer_id": get_tree().get_network_unique_id()}
	_sendToPeer(pending_invite_peer, "UI/Party", "onPartyMemberJoined", [my_info])

	pending_invite_name = ""
	pending_invite_peer = -1


	var inviter_node = findPlayerByName(pending_invite_name)
	if is_instance_valid(inviter_node):
		var inviter_party = inviter_node.get_node_or_null("UI/Party")
		if is_instance_valid(inviter_party):
			inviter_party.rpc_id(pending_invite_peer, "onPartyMemberJoined", my_info)




# ---------------- Party membership sync ----------------
# Inviter acts as the sync anchor: whenever the party roster changes on the
# inviter's copy, it pushes the full roster out to every member's own Party
# node so everyone converges on the same list.

remote func onPartyMemberJoined(member_info:Dictionary) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return

	if party_members.empty() and party_leader_name == "":
		party_leader_name = player.entity_name

	addPartyMember(member_info)
	broadcastPartyListToAll()
	notifyPartySystemMessage(member_info.entity_name + " joined the party")


func addPartyMember(info:Dictionary) -> void:
	for m in party_members:
		if m.entity_name == info.entity_name:
			return
	party_members.append(info)
	reportPartyToServer()
	# NOTE: no updateMembersDisplay() here anymore -- both callers of this
	# function (onBotInviteReply, onPartyMemberJoined) already call
	# broadcastPartyListToAll() right after, which rebuilds the display
	# exactly once. Calling it here too caused a duplicate-row flicker for
	# one frame, since queue_free() doesn't actually remove the old row
	# until the frame ends.


# ---------------- Kick / Promote ----------------

func isLocalPlayerLeader() -> bool:
	return party_leader_name != "" and party_leader_name == player.entity_name


func rowPressed(entity_name:String) -> void:
	leave_button.visible = true

	if !isLocalPlayerLeader():
		return

	var row = _member_rows.get(entity_name)
	if !is_instance_valid(row):
		return

	var kick_btn = row.get_node_or_null("kick")
	var promote_btn = row.get_node_or_null("promote")
	var showing = is_instance_valid(kick_btn) and kick_btn.visible

	for other_name in _member_rows.keys():
		var other_row = _member_rows[other_name]
		if !is_instance_valid(other_row):
			continue
		var ok = other_row.get_node_or_null("kick")
		var op = other_row.get_node_or_null("promote")
		if is_instance_valid(ok): ok.visible = false
		if is_instance_valid(op): op.visible = false

	if !showing:
		if is_instance_valid(kick_btn): kick_btn.visible = true
		if is_instance_valid(promote_btn): promote_btn.visible = true


func kickPressed(entity_name:String) -> void:
	if !isLocalPlayerLeader():
		return
	confirm_mode = "kick"
	confirm_target_name = entity_name
	invited_label.text = "are you sure you want to kick " + entity_name
	invited_control.show()


func promotePressed(entity_name:String) -> void:
	if !isLocalPlayerLeader():
		return
	confirm_mode = "promote"
	confirm_target_name = entity_name
	invited_label.text = "are you sure you want to promote " + entity_name
	invited_control.show()

func doKick(entity_name:String) -> void:
	if !isLocalPlayerLeader():
		return

	var kicked_peer := -1
	for i in range(party_members.size() - 1, -1, -1):
		if party_members[i].entity_name == entity_name:
			kicked_peer = party_members[i].peer_id
			party_members.remove(i)
			break

	if kicked_peer != -1:
		_sendToPeer(kicked_peer, "UI/Party", "onKicked", [])
	else:
		var bot = findPlayerByName(entity_name)
		if is_instance_valid(bot) and bot.is_in_group("BOT"):
			if get_tree().network_peer == null or get_tree().is_network_server():
				if bot.has_method("leaveBotParty"):
					bot.leaveBotParty()
			else:
				Global.rpc_id(1, "requestBotLeaveParty", bot.get_path())

	updateMembersDisplay()
	reportPartyToServer()
	broadcastPartyListToAll()
	notifyPartySystemMessage(entity_name + " was kicked from the party")


remote func onKicked() -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	party_members.clear()
	party_leader_name = ""
	updateMembersDisplay()
	reportPartyToServer()
	chat.sendSystemMessage("you were kicked from the party")





func doPromote(entity_name:String) -> void:
	if !isLocalPlayerLeader():
		return
	party_leader_name = entity_name
	updateMembersDisplay()
	reportPartyToServer()
	broadcastPartyListToAll()
	notifyPartySystemMessage(entity_name + " was promoted to party leader")


func reportPartyToServer() -> void:
	if get_tree().network_peer == null:
		Global.updatePartyRosterAndMirrorBots(player.entity_name, party_members.duplicate(true))
		Global.party_leaders[player.entity_name] = party_leader_name
		return
	if get_tree().is_network_server():
		Global.updatePartyRosterAndMirrorBots(player.entity_name, party_members.duplicate(true))
		Global.party_leaders[player.entity_name] = party_leader_name
		return
	rpc_id(1, "requestUpdatePartyRoster", player.entity_name, party_members.duplicate(true), party_leader_name)

remote func requestUpdatePartyRoster(entity_name:String, roster:Array, leader_name:String = "") -> void:
	if !get_tree().is_network_server():
		return
	Global.updatePartyRosterAndMirrorBots(entity_name, roster)
	if leader_name != "":
		Global.party_leaders[entity_name] = leader_name

remote func requestRestorePartyRoster(entity_name:String) -> void:
	if !get_tree().is_network_server():
		return
	var sender_id = get_tree().get_rpc_sender_id()
	if sender_id == 0:
		sender_id = 1
	if !Global.party_rosters.has(entity_name):
		return
	var stored_roster:Array = Global.party_rosters[entity_name]
	if stored_roster.empty():
		return
	var leader_name = str(Global.party_leaders.get(entity_name,""))
	var live_roster := []
	for m in stored_roster:
		var mname = str(m.get("entity_name",""))
		if mname == "":
			continue
		var node = Global.getPlayerOrBotNode(mname)
		var live_peer = -1
		if is_instance_valid(node) and !node.is_in_group("BOT"):
			live_peer = node.get_network_master()
		live_roster.append({"entity_name": mname, "peer_id": live_peer})
	rpc_id(sender_id, "receiveRestoredPartyRoster", live_roster, leader_name)

remote func receiveRestoredPartyRoster(roster:Array, leader_name:String) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if roster.empty() and leader_name == "":
		return
	party_members = roster.duplicate(true)
	party_leader_name = leader_name
	updateMembersDisplay()


func _tryRequestPartyRestore() -> void:
	if get_tree().network_peer == null:
		return
	yield(get_tree().create_timer(1.0), "timeout")
	if !is_instance_valid(self) or get_tree().network_peer == null:
		return
	rpc_id(1, "requestRestorePartyRoster", player.entity_name)


func myInfo() -> Dictionary:
	return {"entity_name": player.entity_name, "peer_id": get_tree().get_network_unique_id()}


# Party.gd — sendSystemMessageToEntity()
func sendSystemMessageToEntity(entity_name:String, peer_id:int, message:String) -> void:
	if entity_name == player.entity_name:
		chat.sendSystemMessage(message)
		return
	if get_tree().network_peer == null:
		return
	_sendToPeer(peer_id, "UI/Chat", "receiveSystemMessage", [message])

func notifyPartySystemMessage(message:String, include_self:bool = true) -> void:
	if include_self:
		chat.sendSystemMessage(message)
	for m in party_members:
		sendSystemMessageToEntity(m.entity_name, m.peer_id, message)






func broadcastPartyListToAll() -> void:
	var full_roster = party_members.duplicate(true)
	full_roster.append(myInfo())

	for m in party_members:
		var recipient_list := []
		for entry in full_roster:
			if entry.entity_name != m.entity_name:
				recipient_list.append(entry)
		_sendToPeer(m.peer_id, "UI/Party", "syncPartyList", [recipient_list, party_leader_name])

	updateMembersDisplay()
remote func syncPartyList(list:Array, leader_name:String) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	party_members = list.duplicate(true)
	party_leader_name = leader_name
	updateMembersDisplay()
	reportPartyToServer()

func leavePressed() -> void:
	leave_button.hide()

	if party_members.empty() and party_leader_name == "":
		return

	var my_name = player.entity_name
	var was_leader = isLocalPlayerLeader()
	var new_leader_name = ""

	# Oldest remaining member = party_members[0], since members are
	# appended in join order and never reordered.
	if was_leader and !party_members.empty():
		new_leader_name = party_members[0].entity_name

	var leave_message = my_name + " left the party"
	if new_leader_name != "":
		leave_message += ". " + new_leader_name + " is now the party leader"

	notifyPartySystemMessage(leave_message, false)

	for m in party_members:
		_sendToPeer(m.peer_id, "UI/Party", "onMemberLeft", [my_name, new_leader_name])

	party_members.clear()
	party_leader_name = ""
	updateMembersDisplay()
	reportPartyToServer()


remote func onMemberLeft(entity_name:String, new_leader_name:String) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	for i in range(party_members.size() - 1, -1, -1):
		if party_members[i].entity_name == entity_name:
			party_members.remove(i)
			break
	if new_leader_name != "":
		party_leader_name = new_leader_name
	elif party_leader_name == entity_name:
		party_leader_name = ""
	updateMembersDisplay()
	reportPartyToServer()

func showConfirmation(mode:String, target_name:String, message:String) -> void:
	confirm_mode = mode
	confirm_target_name = target_name
	invited_label.text = message
	invited_control.show()























# ---------------- Display ----------------
func updateMembersDisplay() -> void:
	for child in members_grid.get_children():
		if child != player_template:
			members_grid.remove_child(child)
			child.free()
	_member_rows.clear()

	members_grid.visible = !party_members.empty()

	if party_members.empty():
		return

	for info in party_members:
		var row = player_template.duplicate()
		row.visible = true
		members_grid.add_child(row)
		_member_rows[info.entity_name] = row

		var kick_btn = row.get_node_or_null("kick")
		var promote_btn = row.get_node_or_null("promote")
		if is_instance_valid(kick_btn):
			kick_btn.visible = false
			if kick_btn.is_connected("pressed", self, "kickPressed"):
				kick_btn.disconnect("pressed", self, "kickPressed")
			kick_btn.connect("pressed", self, "kickPressed", [info.entity_name])
		if is_instance_valid(promote_btn):
			promote_btn.visible = false
			if promote_btn.is_connected("pressed", self, "promotePressed"):
				promote_btn.disconnect("pressed", self, "promotePressed")
			promote_btn.connect("pressed", self, "promotePressed", [info.entity_name])

		if row.has_signal("pressed"):
			if row.is_connected("pressed", self, "rowPressed"):
				row.disconnect("pressed", self, "rowPressed")
			row.connect("pressed", self, "rowPressed", [info.entity_name])

	refreshAllRows()



func refreshAllRows() -> void:
	for entity_name in _member_rows.keys():
		var row = _member_rows[entity_name]
		if is_instance_valid(row):
			updateRow(row, entity_name)

func updateRow(row:Control, entity_name:String) -> void:
	var target = findPlayerByName(entity_name)
	var hp_bar = row.get_node_or_null("HP")
	var ar_bar = row.get_node_or_null("AR")
	var en_bar = row.get_node_or_null("EN")
	var name_label = row.get_node_or_null("NameLalbel")
	var hp_label = row.get_node_or_null("HPLalbel")

	var is_online = is_instance_valid(target)

	if !is_online:
		if is_instance_valid(hp_bar): hp_bar.modulate = Color(0.5,0.5,0.5,1)
		if is_instance_valid(ar_bar): ar_bar.modulate = Color(0.5,0.5,0.5,1)
		if is_instance_valid(en_bar): en_bar.modulate = Color(0.5,0.5,0.5,1)
		row.modulate = Color(0.6,0.6,0.6,1)
		if is_instance_valid(name_label):
			var prefix = "Leader:" if entity_name == party_leader_name else ""
			name_label.text = prefix + entity_name + " (offline)"
		if is_instance_valid(hp_label):
			hp_label.text = "offline"
		return

	if is_instance_valid(hp_bar): hp_bar.modulate = Color(1,1,1,1)
	if is_instance_valid(ar_bar): ar_bar.modulate = Color(1,1,1,1)
	if is_instance_valid(en_bar): en_bar.modulate = Color(1,1,1,1)
	row.modulate = Color(1,1,1,1)

	var stats = target.get_node_or_null("Stats")
	if !is_instance_valid(stats):
		return

	if hp_bar:
		hp_bar.max_value = stats.max_health
		hp_bar.value = stats.health
	if ar_bar:
		ar_bar.max_value = stats.max_arcane
		ar_bar.value = stats.arcane
	if en_bar:
		en_bar.max_value = stats.max_energy
		en_bar.value = stats.energy
	if name_label:
		if entity_name == party_leader_name:
			name_label.text = "Leader:" + entity_name
		else:
			name_label.text = entity_name
	if hp_label:
		hp_label.text = _formatNumber(stats.health) + "/" + _formatNumber(stats.max_health)



func _formatNumber(n:float) -> String:
	if n >= 1000.0:
		return ("%.1f" % (n / 1000.0)) + "k"
	return str(int(round(n)))









func gatherPartySnapshot() -> Dictionary:
	return {
		"party_members": party_members.duplicate(true),
		"party_leader_name": party_leader_name
	}

remote func applyOwnPartySnapshot(data:Dictionary) -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if data.empty():
		return
	party_members = data.get("party_members", []).duplicate(true)
	party_leader_name = str(data.get("party_leader_name",""))
	if !party_members.empty() or party_leader_name != "":
		updateMembersDisplay()
		reportPartyToServer()

func saveData() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if "data_fully_loaded" in player and !player.data_fully_loaded:
		return
	var world = player.get_parent()
	if is_instance_valid(world) and world.has_method("savePartyFor"):
		world.savePartyFor(player, gatherPartySnapshot())

remote func requestSelfSaveParty() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if "data_fully_loaded" in player and !player.data_fully_loaded:
		return




