extends Control #node called BannerSystem
### BannerSystem.gd — direct child of UI, direct child of Player.


onready var player = $"../.."
onready var chat = $"../Chat"
onready var party = $"../Party"

onready var close_button:TextureButton =  $ButtonList/Close
onready var show_banner_list_button:TextureButton = $ButtonList/ShowBannerList 
onready var show_your_banner_button:TextureButton = $ButtonList/ShowYourBanner 
onready var show_invitations_button:TextureButton = $ButtonList/ShowBannerInvitations

onready var banner_list_panel:Control = $"BannerList"
onready var banner_list_grid:GridContainer = $"BannerList/ScrollContainer/GridContainer"
onready var banner_list_template:Control = $"BannerList/ScrollContainer/GridContainer/BannerButton1"

onready var your_banner_panel:Control = $YourBanner
onready var create_banner_panel:Control = $CreateBanner
onready var create_banner_line_edit:LineEdit = $CreateBanner/LineEdit
onready var create_banner_button:Button = $CreateBanner/Create

onready var invited_panel:Control = $InvitedToBanner
onready var invited_grid:GridContainer = $InvitedToBanner/ScrollContainer/GridContainer
onready var invited_template:Control = $InvitedToBanner/ScrollContainer/GridContainer/BannerButton1

onready var inspect_control:Control = $"../InspectControl"
onready var invite_button:Button = $"../InspectControl/InviteToBanner"
onready var your_banner_grid:GridContainer = $YourBanner/ScrollContainer/GridContainer
onready var your_banner_member_template:Control = $YourBanner/ScrollContainer/GridContainer/MemberButton1
onready var choose_banner_image_button:Button = $YourBanner/ChooseBannerImage

onready var leave_button:Button =$YourBanner/Leave
onready var edit_description_button:Button = $YourBanner/EditBannerDescription
onready var description_line_edit:LineEdit = $YourBanner/LineEdit
onready var description_label:RichTextLabel = $YourBanner/BannerDescriptionRichTextLabel
onready var banner_image:TextureRect = $YourBanner/BannerImage
onready var banner_file_dialog:FileDialog = $YourBanner/BannerFileDialog
var my_banner_description := ""
var clicked_player:Node = null
var my_banner_name := ""
var my_banner_leader_name := ""
var banner_members := []      # Array of {"entity_name":String,"peer_id":int}, excludes self

var banner_list := []         # Array of {"name":String,"leader":String,"member_count":int}
var banner_invitations := []  # Array of {"name":String,"leader_name":String,"leader_peer":int}
var _invite_rows := {}        # banner_name -> row Control

var _offline := false
var my_banner_image_data := PoolByteArray()
export var banner_refresh_rate := 0.5
export var banner_full_resync_interval := 5.0
var _banner_full_resync_timer := 0.0
var _banner_refresh_timer := 0.0









func _ready():
	_offline = get_tree().network_peer == null

	banner_list_template.visible = false
	invited_template.visible = false
	your_banner_member_template.visible = false

	if is_instance_valid(invite_button):
		invite_button.visible = false

	# Normal button connections
	close_button.connect("pressed", self, "closePressed")
	show_banner_list_button.connect("pressed", self, "showBannerListPressed")
	show_your_banner_button.connect("pressed", self, "showYourBannerPressed")
	show_invitations_button.connect("pressed", self, "showInvitationsPressed")
	create_banner_button.connect("pressed", self, "createBannerPressed")
	invite_button.connect("pressed", self, "invitePressed")
	leave_button.connect("pressed", self, "leaveBanner")
	edit_description_button.connect("pressed", self, "toggleDescriptionEdit")
	choose_banner_image_button.connect("pressed", self, "chooseBannerImagePressed")


	description_line_edit.visible = false

	if !description_line_edit.is_connected("text_changed", self, "onDescriptionTextChanged"):
		description_line_edit.connect("text_changed", self, "onDescriptionTextChanged")

	if !description_line_edit.is_connected("focus_entered", self, "onLineEditFocusEntered"):
		description_line_edit.connect("focus_entered", self, "onLineEditFocusEntered")

	if !description_line_edit.is_connected("focus_exited", self, "onLineEditFocusExited"):
		description_line_edit.connect("focus_exited", self, "onLineEditFocusExited")


	if !create_banner_line_edit.is_connected("focus_entered", self, "onLineEditFocusEntered"):
		create_banner_line_edit.connect("focus_entered", self, "onLineEditFocusEntered")

	if !create_banner_line_edit.is_connected("focus_exited", self, "onLineEditFocusExited"):
		create_banner_line_edit.connect("focus_exited", self, "onLineEditFocusExited")

	# MemberButton1 template buttons
	var template_invite = your_banner_member_template.get_node("Invite")
	var template_remove = your_banner_member_template.get_node("Remove")

	if is_instance_valid(template_invite):
		template_invite.visible = false


	banner_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	banner_file_dialog.mode = FileDialog.MODE_OPEN_FILE
	banner_file_dialog.clear_filters()
	banner_file_dialog.add_filter("*.png;PNG Images")
	banner_file_dialog.add_filter("*.jpg,*.jpeg;JPEG Images")

	if !banner_file_dialog.is_connected("file_selected", self, "onBannerImageSelected"):
		banner_file_dialog.connect("file_selected", self, "onBannerImageSelected")

	if banner_file_dialog.get_parent() != self:
		banner_file_dialog.get_parent().remove_child(banner_file_dialog)
		add_child(banner_file_dialog)

	showOnly(create_banner_panel)

	set_process(true)
	set_physics_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)

	if _offline:
		hide()

func _physics_process(delta):
	_offline = get_tree().network_peer == null
	if _offline:
		return

	if Input.is_action_just_pressed("banners") and !isWritingInLineEdit():
		visible = !visible
		player.equipment.hide()
		player.inventory.shop.hide()
		player.auction_house_control.hide()

	_banner_refresh_timer += delta
	if _banner_refresh_timer >= banner_refresh_rate:
		_banner_refresh_timer = 0.0
		if your_banner_panel.visible:
			refreshAllBannerRows()
	_banner_full_resync_timer += delta
	if _banner_full_resync_timer >= banner_full_resync_interval:
		_banner_full_resync_timer = 0.0
		Global.rpc_id(1, "requestBannerRosterSync")

func isWritingInLineEdit() -> bool:
	if is_instance_valid(create_banner_line_edit) and create_banner_line_edit.has_focus():
		return true
	if is_instance_valid(description_line_edit) and description_line_edit.has_focus():
		return true
	return false

func onLineEditFocusEntered() -> void:
	if is_instance_valid(player):
		player.is_writing = true

func onLineEditFocusExited() -> void:
	if is_instance_valid(player) and !isWritingInLineEdit():
		player.is_writing = false
			
			
			
			
func refreshAllBannerRows() -> void:
	# ---------------------------------------------------------
	# YOUR CURRENT BANNER IMAGE
	# ---------------------------------------------------------
	if is_instance_valid(banner_image):
		banner_image.texture = decodeBannerImage(my_banner_image_data)


	# ---------------------------------------------------------
	# BANNER LIST
	#
	# Every BannerButton1 row gets the image belonging to the
	# banner whose name is displayed in its NameLabel.
	# ---------------------------------------------------------
	if is_instance_valid(banner_list_grid):
		for row in banner_list_grid.get_children():
			if row == banner_list_template:
				continue

			if !is_instance_valid(row):
				continue

			var name_label = row.get_node("NameLabel")
			if !is_instance_valid(name_label):
				continue

			var banner_name = name_label.text
			var image_data := PoolByteArray()

			for banner in banner_list:
				if str(banner.get("name", "")) == banner_name:
					image_data = banner.get("image_data", PoolByteArray())
					break

			if row is TextureButton:
				row.texture_normal = decodeBannerImage(image_data)


	# ---------------------------------------------------------
	# INVITED BANNERS
	#
	# Every invitation row gets the image belonging to the
	# banner whose name is displayed in its NameLabel.
	# ---------------------------------------------------------
	if is_instance_valid(invited_grid):
		for row in invited_grid.get_children():
			if row == invited_template:
				continue

			if !is_instance_valid(row):
				continue

			var name_label = row.get_node("NameLabel")
			if !is_instance_valid(name_label):
				continue

			var banner_name = name_label.text
			var image_data := PoolByteArray()

			for invite in banner_invitations:
				if str(invite.get("name", "")) == banner_name:
					image_data = invite.get("image_data", PoolByteArray())
					break

			if row is TextureButton:
				row.texture_normal = decodeBannerImage(image_data)


	# ---------------------------------------------------------
	# MEMBER ONLINE COUNT
	# ---------------------------------------------------------
	var online_count := 0
	var total := _banner_member_rows.size()

	for entity_name in _banner_member_rows.keys():
		var row = _banner_member_rows[entity_name]

		if !is_instance_valid(row):
			continue

		if isEntityOnline(entity_name):
			online_count += 1

	var online_label = your_banner_panel.get_node("MembersOnlineLabel")
	if is_instance_valid(online_label):
		online_label.text = str(online_count) + " / " + str(total) + " online"
func decodeBannerImage(bytes:PoolByteArray) -> Texture:
	if bytes.size() == 0:
		return null
	var image = Image.new()
	var err = image.load_png_from_buffer(bytes)
	if err != OK:
		err = image.load_jpg_from_buffer(bytes)
	if err != OK:
		return null
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture
func chooseBannerImagePressed() -> void:
	if _offline:
		return
	if my_banner_name == "" or my_banner_leader_name != player.entity_name:
		return
	banner_file_dialog.raise()
	banner_file_dialog.popup_centered_ratio()


export var max_banner_image_bytes := 512000 # 500KB cap, checked client and server side
export var banner_image_chunk_size := 16000
# ============================================================
# BannerSystem.gd — banner image receive rewritten. Add the new vars,
# replace the listed functions in full.
# ============================================================

# add near the other banner image vars:
var my_banner_image_revision := 0
var _incoming_banner_image_banner := ""
var _incoming_banner_image_revision := 0
var _pending_banner_images := {} # banner_name -> {"bytes":PoolByteArray,"revision":int}


func receiveBannerImageChunk(banner_name:String, chunk:PoolByteArray, is_first:bool, is_last:bool, revision:int = 0) -> void:
	if is_first:
		_incoming_banner_image_chunks = PoolByteArray()
		_incoming_banner_image_banner = banner_name
		_incoming_banner_image_revision = revision
	_incoming_banner_image_chunks.append_array(chunk)
	if !is_last:
		return

	var full_bytes = _incoming_banner_image_chunks
	var received_banner = _incoming_banner_image_banner
	var received_revision = _incoming_banner_image_revision
	_incoming_banner_image_chunks = PoolByteArray()

	# FIX: never drop a completed transfer just because syncBannerRoster
	# hasn't been processed yet -- buffer by banner name and apply the
	# instant it actually matches (below, and also from syncBannerRoster
	# once my_banner_name is set).
	_pending_banner_images[received_banner] = {"bytes": full_bytes, "revision": received_revision}
	_applyPendingBannerImageIfCurrent()

func _applyPendingBannerImageIfCurrent() -> void:
	if my_banner_name == "" or !_pending_banner_images.has(my_banner_name):
		return
	var pending = _pending_banner_images[my_banner_name]

	# FIX: reject anything older than what we already have. This is what
	# stopped a freshly uploaded image from being silently overwritten a
	# moment later by a periodic resync that read the server's roster
	# mid-upload (before the new bytes were saved there).
	if pending["revision"] < my_banner_image_revision:
		return

	my_banner_image_revision = pending["revision"]
	my_banner_image_data = pending["bytes"]

	if !is_instance_valid(banner_image):
		return
	if my_banner_image_data.size() == 0:
		banner_image.texture = null
	else:
		banner_image.texture = decodeBannerImage(my_banner_image_data)


func receiveBannerListImageChunk(banner_name:String, chunk:PoolByteArray, is_first:bool, is_last:bool, revision:int = 0) -> void:
	if is_first or _incoming_banner_list_image_banner != banner_name:
		_incoming_banner_list_image_chunks = PoolByteArray()
		_incoming_banner_list_image_banner = banner_name
	_incoming_banner_list_image_chunks.append_array(chunk)
	if !is_last:
		return

	var full_bytes = _incoming_banner_list_image_chunks
	_incoming_banner_list_image_chunks = PoolByteArray()
	_banner_list_image_cache[banner_name] = full_bytes

	for entry in banner_list:
		if str(entry.get("name","")) == banner_name:
			entry["image_data"] = full_bytes
			break

	if is_instance_valid(banner_list_grid):
		for row in banner_list_grid.get_children():
			if row == banner_list_template or !is_instance_valid(row):
				continue
			var name_label = row.get_node("NameLabel")
			if is_instance_valid(name_label) and name_label.text == banner_name and row is TextureButton:
				row.texture_normal = decodeBannerImage(full_bytes)
				break


func onBannerImageSelected(path:String) -> void:
	if _offline:
		return
	if my_banner_name == "" or my_banner_leader_name != player.entity_name:
		return

	var file = File.new()
	if !file.file_exists(path) or file.open(path, File.READ) != OK:
		push_error("Banner.gd: could not open selected image: " + path)
		return
	var bytes = file.get_buffer(file.get_len())
	file.close()

	if bytes.size() > max_banner_image_bytes:
		chat.sendSystemMessage("banner image too large (max 500KB)")
		return

	var image = Image.new()
	var ext = path.get_extension().to_lower()
	var err
	if ext == "jpg" or ext == "jpeg":
		err = image.load_jpg_from_buffer(bytes)
	else:
		err = image.load_png_from_buffer(bytes)

	if err != OK:
		push_error("Banner.gd: could not decode selected image: " + path)
		return

	var texture = ImageTexture.new()
	texture.create_from_image(image)
	banner_image.texture = texture
	my_banner_image_data = bytes

	# FIX: claim the next revision number locally the instant we upload.
	# The server will land on exactly this same number once it applies
	# the upload (only the leader can ever bump it), so any in-flight
	# periodic resync that still reports the OLD (pre-upload) revision
	# now compares as stale and gets rejected instead of stomping this
	# fresh image back to empty a second later.
	my_banner_image_revision += 1
	_pending_banner_images.erase(my_banner_name)

	_sendBannerImageUploadChunked(my_banner_name, bytes)


remote func syncBannerRoster(banner_name:String, leader_name:String, members:Array, description:String = "", image_data:PoolByteArray = PoolByteArray()) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	var banner_changed = (my_banner_name != banner_name)
	my_banner_name = banner_name
	my_banner_leader_name = leader_name
	my_banner_description = description
	if banner_changed:
		my_banner_image_revision = 0
		my_banner_image_data = PoolByteArray()
		if is_instance_valid(banner_image):
			banner_image.texture = null
	banner_members.clear()
	for m in members:
		if m.entity_name != player.entity_name:
			banner_members.append(m)
	refreshBannerTabVisibility()
	refreshInviteButtonVisibility()
	_applyPendingBannerImageIfCurrent()

remote func onBannerCreateSucceeded(banner_name:String) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		push_error("onBannerCreateSucceeded rejected: isLocalPlayer=" + str(player.isLocalPlayer() if player.has_method("isLocalPlayer") else "no method"))
		return
	create_banner_button.disabled = false
	create_banner_line_edit.text = ""
	my_banner_name = banner_name
	my_banner_leader_name = player.entity_name
	my_banner_description = ""
	my_banner_image_revision = 0
	my_banner_image_data = PoolByteArray()
	if is_instance_valid(banner_image):
		banner_image.texture = null
	banner_members.clear()
	refreshBannerTabVisibility()
	requestBannerListRefresh()
	refreshInviteButtonVisibility()
	chat.sendSystemMessage("banner \"" + banner_name + "\" created")

remote func onKickedFromBanner() -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	_pending_banner_images.erase(my_banner_name)
	my_banner_name = ""
	my_banner_leader_name = ""
	my_banner_image_revision = 0
	my_banner_image_data = PoolByteArray()
	if is_instance_valid(banner_image):
		banner_image.texture = null
	banner_members.clear()
	refreshBannerTabVisibility()    
	requestBannerListRefresh()
	chat.sendSystemMessage("you were removed from the banner")

remote func onLeftBanner() -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	_pending_banner_images.erase(my_banner_name)
	my_banner_name = ""
	my_banner_leader_name = ""
	my_banner_image_revision = 0
	my_banner_image_data = PoolByteArray()
	if is_instance_valid(banner_image):
		banner_image.texture = null
	banner_members.clear()
	refreshBannerTabVisibility()    
	requestBannerListRefresh()
	chat.sendSystemMessage("you left the banner")



func _sendBannerImageUploadChunked(banner_name:String, bytes:PoolByteArray) -> void:
	if _offline:
		return
	var offset = 0
	var total = bytes.size()
	if total == 0:
		Global.rpc_id(1, "requestUpdateBannerImageChunk", player.entity_name, banner_name, PoolByteArray(), true)
		return
	while offset < total:
		var end = min(offset + banner_image_chunk_size, total)
		var chunk = bytes.subarray(offset, end - 1)
		var is_last = end >= total
		Global.rpc_id(1, "requestUpdateBannerImageChunk", player.entity_name, banner_name, chunk, is_last)
		offset = end


# ---------------- chunked banner image receive ----------------
var _incoming_banner_image_chunks := PoolByteArray()
var _banner_list_image_cache := {} # banner_name -> PoolByteArray
var _incoming_banner_list_image_chunks := PoolByteArray()
var _incoming_banner_list_image_banner := ""



# ---------------- open / close / tabs ----------------

func openBannerUI() -> void:
	if _offline:
		return
	show()
	if my_banner_name == "" and !banner_invitations.empty():
		showInvitationsPressed()
	else:
		showYourBannerPressed()

func closePressed() -> void:
	hide()

func showOnly(panel:Control) -> void:
	if is_instance_valid(banner_list_panel):
		banner_list_panel.visible   = (panel == banner_list_panel)
	if is_instance_valid(your_banner_panel):
		your_banner_panel.visible   = (panel == your_banner_panel)
	if is_instance_valid(create_banner_panel):
		create_banner_panel.visible = (panel == create_banner_panel)
	if is_instance_valid(invited_panel):
		invited_panel.visible       = (panel == invited_panel)

func showBannerListPressed() -> void:
	showOnly(banner_list_panel)
	requestBannerListRefresh()

func showYourBannerPressed() -> void:
	if my_banner_name != "":
		showOnly(your_banner_panel)
		updateYourBannerDisplay()
		if !_offline:
			Global.rpc_id(1, "requestBannerRosterSync")
	elif !banner_invitations.empty():
		showOnly(invited_panel)
		updateInvitationsDisplay()
	else:
		showOnly(create_banner_panel)

func showInvitationsPressed() -> void:
	if my_banner_name != "":
		# Already in a banner -- invitations is not a valid destination
		# until we leave it.
		showYourBannerPressed()
		return
	showOnly(invited_panel)
	updateInvitationsDisplay()


# ---------------- creating ----------------

func createBannerPressed() -> void:
	if _offline or my_banner_name != "":
		return
	var banner_name = create_banner_line_edit.text.strip_edges()
	if banner_name == "":
		return
	call_deferred("_lockCreateButton")
	print("CLIENT: sending requestCreateBanner, name=", banner_name)
	Global.rpc_id(1, "requestCreateBanner", player.entity_name, get_tree().get_network_unique_id(), banner_name)
func lockCreateButton() -> void:
	create_banner_button.disabled = true

remote func onBannerCreateFailed(banner_name:String) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	create_banner_button.disabled = false
	chat.sendSystemMessage("could not create banner \"" + banner_name + "\" (name already taken)")


func requestBannerListRefresh() -> void:
	if _offline:
		return
	Global.rpc_id(1, "requestBannerList", get_tree().get_network_unique_id())


remote func receiveBannerImage(banner_name:String, image_data:PoolByteArray) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if banner_name != my_banner_name:
		return
	my_banner_image_data = image_data
	if !is_instance_valid(banner_image):
		return
	if image_data.size() == 0:
		banner_image.texture = null
		return
	var image = Image.new()
	var err = image.load_png_from_buffer(image_data)
	if err != OK:
		err = image.load_jpg_from_buffer(image_data)
	if err == OK:
		var texture = ImageTexture.new()
		texture.create_from_image(image)
		banner_image.texture = texture
remote func receiveBannerList(summary:Array) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	banner_list = summary
	for entry in banner_list:
		var bname = str(entry.get("name",""))
		if _banner_list_image_cache.has(bname):
			entry["image_data"] = _banner_list_image_cache[bname]
	if banner_list_panel.visible:
		updateBannerListDisplay()

func updateBannerListDisplay() -> void:
	for child in banner_list_grid.get_children():
		if child != banner_list_template:
			child.queue_free()

	for entry in banner_list:
		var row = banner_list_template.duplicate()
		row.visible = true
		banner_list_grid.add_child(row)

		var name_label = row.get_node("NameLabel")
		var members_label = row.get_node("Members Label")
		if is_instance_valid(name_label):
			name_label.text = entry.name
		if is_instance_valid(members_label):
			members_label.text = str(entry.member_count) + (" member" if entry.member_count == 1 else " members")

		if row is TextureButton:
			row.texture_normal = decodeBannerImage(entry.get("image_data", PoolByteArray()))

# ---------------- your banner ----------------

var _banner_member_rows := {}     # entity_name -> row Control
var _open_banner_rows := {}   # which row currently has its buttons shown, "" = none

func updateYourBannerDisplay() -> void:
	var name_label = your_banner_panel.get_node("NameLabel")
	name_label.text = my_banner_name
	var am_leader = (my_banner_leader_name == player.entity_name)
	edit_description_button.visible = am_leader
	choose_banner_image_button.visible = am_leader
	if !am_leader:
		description_line_edit.visible = false
	description_label.bbcode_text = my_banner_description


	if my_banner_image_data.size() > 0:
		var image = Image.new()
		var err = image.load_png_from_buffer(my_banner_image_data)
		if err != OK:
			err = image.load_jpg_from_buffer(my_banner_image_data)
		if err == OK:
			var texture = ImageTexture.new()
			texture.create_from_image(image)
			banner_image.texture = texture
	else:
		banner_image.texture = null

	if !is_instance_valid(your_banner_grid) or !is_instance_valid(your_banner_member_template):
		push_error("Banner.gd updateYourBannerDisplay(): grid or member template missing")
		return

	var members_grid = your_banner_grid
	var member_template = your_banner_member_template

	# Whichever row (if any) currently has its buttons open -- restored
	# after the rebuild below instead of being silently dropped.
	var reopen_entities = _open_banner_rows.keys()

	member_template.visible = false
	for child in members_grid.get_children():
		if child != member_template:
			child.queue_free()
	_banner_member_rows.clear()
	_open_banner_rows.clear()

	var full_list := []
	full_list.append({"entity_name": player.entity_name, "peer_id": get_tree().get_network_unique_id()})
	for m in banner_members:
		full_list.append(m)

	full_list.sort_custom(self, "sortLeaderFirst")

	for info in full_list:
		var entity_name = str(info.get("entity_name",""))
		var row = member_template.duplicate()
		row.visible = true
		members_grid.add_child(row)
		_banner_member_rows[entity_name] = row

		var name_lbl = row.get_node("NameLabel")
		name_lbl.text = entity_name
		var remove_btn = row.get_node("Remove")
		var invite_btn = row.get_node("Invite")
		var cancel_btn = row.get_node("Cancel")
		if is_instance_valid(remove_btn): remove_btn.visible = false
		if is_instance_valid(invite_btn): invite_btn.visible = false
		if is_instance_valid(cancel_btn): cancel_btn.visible = false
		if entity_name != player.entity_name:

			if remove_btn.is_connected("pressed", self, "bannerRemovePressed"):
				remove_btn.disconnect("pressed", self, "bannerRemovePressed")
			remove_btn.connect("pressed", self, "bannerRemovePressed", [entity_name])

			if invite_btn.is_connected("pressed", self, "bannerInviteToPartyPressed"):
				invite_btn.disconnect("pressed", self, "bannerInviteToPartyPressed")
			invite_btn.connect("pressed", self, "bannerInviteToPartyPressed", [entity_name, int(info.get("peer_id",-1))])

			if cancel_btn.is_connected("pressed", self, "bannerRowCancelPressed"):
				cancel_btn.disconnect("pressed", self, "bannerRowCancelPressed")
			if cancel_btn.is_connected("pressed", self, "bannerRowCancelPressedDeferred"):
				cancel_btn.disconnect("pressed", self, "bannerRowCancelPressedDeferred")
			cancel_btn.connect("pressed", self, "bannerRowCancelPressedDeferred", [entity_name])
			if row.has_signal("pressed"):
				if row.is_connected("pressed", self, "bannerRowPressed"):
					row.disconnect("pressed", self, "bannerRowPressed")
				row.connect("pressed", self, "bannerRowPressed", [entity_name])

	for reopen_entity in reopen_entities:
		if _banner_member_rows.has(reopen_entity):
			openBannerRow(reopen_entity)

	refreshAllBannerRows()
	refreshInviteButtonVisibility()



func sortLeaderFirst(a, b) -> bool:
	var a_is_leader = str(a.get("entity_name","")) == my_banner_leader_name
	var b_is_leader = str(b.get("entity_name","")) == my_banner_leader_name
	if a_is_leader and !b_is_leader:
		return true
	return false


func isEntityOnline(entity_name:String) -> bool:
	if _offline:
		return entity_name == player.entity_name
	if entity_name == player.entity_name:
		return true
	if get_tree().is_network_server():
		return is_instance_valid(Global.getPlayerNode(entity_name))
	# Non-server clients have no direct registry lookup -- fall back to
	# "found in the currently loaded world" which is the only info we have.
	return is_instance_valid(Global.getPlayerNode(entity_name))

func bannerRowPressed(entity_name:String) -> void:
	openBannerRow(entity_name)



func openBannerRow(entity_name:String) -> void:
	var row = _banner_member_rows.get(entity_name)
	if !is_instance_valid(row):
		return
	var remove_btn = row.get_node("Remove")
	var invite_btn = row.get_node("Invite")
	var cancel_btn = row.get_node("Cancel")

	if is_instance_valid(invite_btn):
		invite_btn.visible = true
	if is_instance_valid(cancel_btn):
		cancel_btn.visible = true
	if is_instance_valid(remove_btn):
		remove_btn.visible = (my_banner_leader_name == player.entity_name)

	_open_banner_rows[entity_name] = true

func bannerRowCancelPressedDeferred(entity_name:String) -> void:
	call_deferred("_bannerRowCancelPressed", entity_name)

func bannerRowCancelPressed(entity_name:String) -> void:
	var row = _banner_member_rows.get(entity_name)
	if !is_instance_valid(row):
		return

	var remove_btn = row.get_node("Remove")
	var invite_btn = row.get_node("Invite")
	var cancel_btn = row.get_node("Cancel")

	if is_instance_valid(remove_btn):
		remove_btn.visible = false
	if is_instance_valid(invite_btn):
		invite_btn.visible = false
	if is_instance_valid(cancel_btn):
		cancel_btn.visible = false

	_open_banner_rows.erase(entity_name)
# Invite that banner member to my party -- reuses Party.gd's existing
# invite RPC path directly (same targeted-peer send pattern as everywhere
# else in this file).
func bannerInviteToPartyPressed(entity_name:String, peer_id:int) -> void:
	bannerRowCancelPressed(entity_name)
	if _offline or peer_id <= 0:
		return
	if !is_instance_valid(party):
		return
	if party.party_leader_name != "" and !party.isLocalPlayerLeader():
		return
	_sendToPeer(peer_id, "UI/Party", "receivePartyInvite", [player.entity_name, get_tree().get_network_unique_id()])
	chat.sendSystemMessage("party invite sent to " + entity_name)


# Leader-only kick out of the banner (distinct from leaving it yourself).
func bannerRemovePressed(entity_name:String) -> void:
	bannerRowCancelPressed(entity_name)
	if _offline or my_banner_leader_name != player.entity_name:
		return
	Global.rpc_id(1, "requestKickFromBanner", player.entity_name, my_banner_name, entity_name)







func toggleDescriptionEdit() -> void:
	if _offline or my_banner_leader_name != player.entity_name:
		return
	if !is_instance_valid(description_line_edit):
		return
	description_line_edit.visible = !description_line_edit.visible
	if description_line_edit.visible:
		description_line_edit.text = my_banner_description
		description_line_edit.grab_focus()

func onDescriptionTextChanged(new_text:String) -> void:
	if _offline or my_banner_name == "" or my_banner_leader_name != player.entity_name:
		return
	my_banner_description = new_text
	if is_instance_valid(description_label):
		description_label.bbcode_text = new_text
	Global.rpc_id(1, "requestUpdateBannerDescription", player.entity_name, my_banner_name, new_text)

remote func receiveBannerDescription(banner_name:String, description:String) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if banner_name != my_banner_name:
		return
	my_banner_description = description
	if is_instance_valid(description_label):
		description_label.bbcode_text = description
	# don't stomp the leader's own in-progress typing
	if is_instance_valid(description_line_edit) and !description_line_edit.has_focus():
		description_line_edit.text = description




func leaveBanner() -> void:
	if _offline or my_banner_name == "":
		return
	Global.rpc_id(1, "requestLeaveBanner", player.entity_name, get_tree().get_network_unique_id(), my_banner_name)



# ---------------- inviting ----------------

func canInviteToBanner(target:Node) -> bool:
	# FIX 2: not in a banner at all (my_banner_name == "") is already
	# covered here, along with "in a banner but not its leader" — both
	# collapse to the same check since a non-member has my_banner_name=="".
	if _offline:
		return false
	if my_banner_name == "" or my_banner_leader_name != player.entity_name:
		return false
	var target_banner = target.get_node("UI/BannerSystem")
	if is_instance_valid(target_banner) and target_banner.my_banner_name == my_banner_name:
		return false
	return true

func refreshInviteButtonVisibility() -> void:
	if !is_instance_valid(invite_button):
		return
	invite_button.visible = is_instance_valid(clicked_player) and canInviteToBanner(clicked_player)

func refreshBannerTabVisibility() -> void:
	if _offline:
		return
	var in_banner = my_banner_name != ""

	if is_instance_valid(show_invitations_button):
		show_invitations_button.visible = !in_banner

	if in_banner:
		if (is_instance_valid(create_banner_panel) and create_banner_panel.visible) \
		or (is_instance_valid(invited_panel) and invited_panel.visible):
			showOnly(your_banner_panel)
		updateYourBannerDisplay()
	else:
		if is_instance_valid(your_banner_panel) and your_banner_panel.visible:
			showYourBannerPressed()
func invitePressed() -> void:
	inspect_control.hide()
	if _offline or !is_instance_valid(clicked_player) or !canInviteToBanner(clicked_player):
		return
	var target_peer = clicked_player.get_network_master()
	_sendToPeer(target_peer, "UI/BannerSystem", "receiveBannerInvite", [my_banner_name, my_banner_leader_name, get_tree().get_network_unique_id()])
	_sendInviteImageChunked(target_peer, my_banner_name, my_banner_image_data)
	chat.sendSystemMessage("banner invite sent to " + clicked_player.entity_name)

func _sendInviteImageChunked(target_peer:int, banner_name:String, bytes:PoolByteArray) -> void:
	if _offline:
		return
	var total = bytes.size()
	if total == 0:
		_sendToPeer(target_peer, "UI/BannerSystem", "receiveBannerInviteImageChunk", [banner_name, PoolByteArray(), true, true])
		return
	var offset = 0
	var first = true
	while offset < total:
		var end = min(offset + banner_image_chunk_size, total)
		var chunk = bytes.subarray(offset, end - 1)
		var is_last = end >= total
		_sendToPeer(target_peer, "UI/BannerSystem", "receiveBannerInviteImageChunk", [banner_name, chunk, first, is_last])
		first = false
		offset = end


var _incoming_invite_image_chunks := PoolByteArray()

remote func receiveBannerInviteImageChunk(banner_name:String, chunk:PoolByteArray, is_first:bool, is_last:bool) -> void:
	if is_first:
		_incoming_invite_image_chunks = PoolByteArray()
	_incoming_invite_image_chunks.append_array(chunk)
	if !is_last:
		return

	var full_bytes = _incoming_invite_image_chunks
	_incoming_invite_image_chunks = PoolByteArray()

	var invite = findInvitation(banner_name)
	if invite == null:
		return
	invite["image_data"] = full_bytes

	if invited_panel.visible:
		updateInvitationsDisplay()
	else:
		var row = _invite_rows.get(banner_name)
		if is_instance_valid(row) and row is TextureButton:
			row.texture_normal = decodeBannerImage(full_bytes)
remote func receiveBannerInvite(banner_name:String, leader_name:String, leader_peer:int, image_data:PoolByteArray = PoolByteArray()) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if my_banner_name == banner_name:
		return
	if findInvitation(banner_name) == null:
		banner_invitations.append({"name":banner_name, "leader_name":leader_name, "leader_peer":leader_peer, "image_data":image_data})

	if invited_panel.visible:
		updateInvitationsDisplay()

	chat.sendSystemMessage(leader_name + " invited you to join the banner \"" + banner_name + "\"")

	if is_instance_valid(party):
		party.showConfirmation("banner_invite", banner_name, "you have been invited\nto join the banner\n" + banner_name)
remote func onBannerInviteDeclined(entity_name:String, banner_name:String) -> void:
	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	chat.sendSystemMessage(entity_name + " declined the invitation to join \"" + banner_name + "\"")


func onBannerInviteAccepted(banner_name:String) -> void:
	if _offline or findInvitation(banner_name) == null:
		return
	Global.rpc_id(1, "requestJoinBanner", player.entity_name, get_tree().get_network_unique_id(), banner_name)
	banner_invitations.clear()
	_invite_rows.clear()
	updateInvitationsDisplay()

func onBannerInviteRefused(banner_name:String) -> void:
	var invite = findInvitation(banner_name)
	if invite == null:
		return
	removeInvitation(banner_name)
	updateInvitationsDisplay()
	if !_offline:
		_sendToPeer(invite.leader_peer, "UI/BannerSystem", "onBannerInviteDeclined", [player.entity_name, banner_name])

func findInvitation(banner_name:String):
	for invite in banner_invitations:
		if invite.name == banner_name:
			return invite
	return null

func removeInvitation(banner_name:String) -> void:
	for i in range(banner_invitations.size() - 1, -1, -1):
		if banner_invitations[i].name == banner_name:
			banner_invitations.remove(i)
			break
	_invite_rows.erase(banner_name)


# ---------------- invitations list ----------------

func updateInvitationsDisplay() -> void:
	for child in invited_grid.get_children():
		if child != invited_template:
			child.queue_free()
	_invite_rows.clear()

	invited_template.visible = false

	for invite in banner_invitations:
		var row = invited_template.duplicate()
		row.visible = true
		invited_grid.add_child(row)
		_invite_rows[invite.name] = row

		var name_label = row.get_node("NameLabel")
		name_label.text = invite.name

		if row is TextureButton:
			row.texture_normal = decodeBannerImage(invite.get("image_data", PoolByteArray()))

		var accept_btn = row.get_node("Accept")
		var refuse_btn = row.get_node("Refuse")

		accept_btn.visible = false
		if accept_btn.is_connected("pressed", self, "onInvitationAcceptPressed"):
			accept_btn.disconnect("pressed", self, "onInvitationAcceptPressed")
		accept_btn.connect("pressed", self, "onInvitationAcceptPressed", [invite.name])

		refuse_btn.visible = false
		if refuse_btn.is_connected("pressed", self, "onInvitationRefusePressed"):
			refuse_btn.disconnect("pressed", self, "onInvitationRefusePressed")
		refuse_btn.connect("pressed", self, "onInvitationRefusePressed", [invite.name])

		if row.has_signal("pressed"):
			if row.is_connected("pressed", self, "invitationRowPressed"):
				row.disconnect("pressed", self, "invitationRowPressed")
			row.connect("pressed", self, "invitationRowPressed", [invite.name])
func invitationRowPressed(banner_name:String) -> void:
	var row = _invite_rows.get(banner_name)
	if !is_instance_valid(row):
		return
	var accept_btn = row.get_node("Accept")
	var refuse_btn = row.get_node("Refuse")
	var showing = is_instance_valid(accept_btn) and accept_btn.visible

	for other_name in _invite_rows.keys():
		var other_row = _invite_rows[other_name]
		if !is_instance_valid(other_row):
			continue
		var oa = other_row.get_node("Accept")
		var orf = other_row.get_node("Refuse")
		if is_instance_valid(oa): oa.visible = false
		if is_instance_valid(orf): orf.visible = false

	if !showing:
		if is_instance_valid(accept_btn): accept_btn.visible = true
		if is_instance_valid(refuse_btn): refuse_btn.visible = true

func onInvitationAcceptPressed(banner_name:String) -> void:
	onBannerInviteAccepted(banner_name)

func onInvitationRefusePressed(banner_name:String) -> void:
	onBannerInviteRefused(banner_name)


# ---------------- inspect / click-to-invite ----------------

func _unhandled_input(event):
	if _offline:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			return
		_updateInviteButtonForMouse(event.position)

func _updateInviteButtonForMouse(mouse_pos:Vector2) -> void:
	var camera = get_viewport().get_camera()
	if camera == null or !is_instance_valid(player):
		return

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var space_state = player.get_world().direct_space_state
	var result = space_state.intersect_ray(from, to, [player])

	if result.empty():
		clicked_player = null
		refreshInviteButtonVisibility()
		return

	var target_player = _resolvePlayerFromCollider(result.collider)
	if target_player == null or target_player == player:
		clicked_player = null
		refreshInviteButtonVisibility()
		return

	clicked_player = target_player
	refreshInviteButtonVisibility()

func _resolvePlayerFromCollider(node:Node) -> Node:
	var n = node
	while n:
		if n.is_in_group("Player"):
			return n
		n = n.get_parent()
	return null


# ---------------- networking helper ----------------

func _sendToPeer(target_peer:int, node_path:String, method:String, args:Array) -> void:
	if _offline:
		return
	if get_tree().is_network_server():
		var target_player = Global.getPlayerNodeByPeer(target_peer)
		if !is_instance_valid(target_player):
			return
		var target_node = target_player.get_node(node_path)
		if is_instance_valid(target_node):
			target_node.callv("rpc_id", [target_peer, method] + args)
	else:
		Global.rpc_id(1, "relayToPeer", target_peer, node_path, method, args)
