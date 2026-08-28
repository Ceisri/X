extends Control
#QuestSystem.gd

onready var player:KinematicBody = $"../.."
onready var party = $"../Party"
onready var inventory:Control = $"../Inventory"
onready var crafting:Control = $"../Crafting"
onready var shop:Control = $"../Shop"
onready var auction_house:Control = $"../AuctionHouse"
onready var chat:Control = $"../Chat"
onready var quest_giver:Control =  $QuestProposal
onready var quest_tracker:Control = $QuestTracker

onready var quest_description_label:RichTextLabel =$QuestProposal/QuestDescriptionRichTextLabel
onready var accept_button:Button = $QuestProposal/Accept
onready var refuse_button:Button =$QuestProposal/Refuse
onready var receive_reward_button:Button = $QuestProposal/ReiceiveReward
onready var tracker_scroll:ScrollContainer = $QuestTracker/ScrollContainer
onready var tracker_grid:GridContainer = $QuestTracker/ScrollContainer/GridContainer
onready var quest_row_template:Control = $QuestTracker/ScrollContainer/GridContainer/Quest1
onready var reward_coins_rho_label:Label = $QuestProposal/QuestReward/MoneyGrid/CoinsRhoLabel
onready var reward_coins_gold_label:Label = $QuestProposal/QuestReward/MoneyGrid/CoinsGoldLabel
onready var reward_coins_silver_label:Label = $QuestProposal/QuestReward/MoneyGrid/CoinsSilverLabel
onready var reward_coins_copper_label:Label = $QuestProposal/QuestReward/MoneyGrid/CoinsCopperLabel
onready var reward_item_grid:GridContainer = $QuestProposal/QuestReward/GridContainer
onready var reward_experience_label:Label = $QuestProposal/QuestReward/ExperienceRewardLabel
onready var quest_list_grid:GridContainer = $QuestList/ScrollContainer/GridContainer
onready var quest_button_template:Control = $QuestList/ScrollContainer/GridContainer/QuestButton
var _quest_list_buttons := {} # quest_id -> button node
var completing_quest_id := ""


var pending_quest:Dictionary = {}
var active_quests:Dictionary = {}
var _quest_rows := {}





# QuestSystem.gd — quests_list: add a "reward" dict to each entry
var quests_list:Array = [
	{
		"id": "quest_001",
		"name": "The Burning Village",
		"description": "Investigate the village and find out what happened to its inhabitants.",
		"goals": [
			{
				"text": "Enter the destroyed village",
				"type": "reach_position",
				"position": Vector3(-1063.959, -265.932, -1049.112),
				"range": 25.0
			},
			{
				"text": "Investigate the burning houses",
				"type": "reach_position",
				"position": Vector3(-1050.0, -265.0, -1030.0),
				"range": 55.0
			},
			{
				"text": "Defeat 5 invading enemies",
				"type": "kill",
				"amount": 5,
				"enemy_group": "InvasionEnemy"
			}
		],
		"reward": {
			"money": 250,
			"experience": 150,
			"items": [
				{"name": "silver ring", "amount": 1},
				{"name": "medicine potion", "amount": 5}
			]
		}
	},
	{
		"id": "quest_002",
		"name": "A Missing Villager",
		"requires": ["quest_001"],
		"description": "A villager has disappeared during the invasion. Search the area and find them.",
		"goals": [
			{
				"text": "Search the village",
				"type": "reach_position",
				"position": Vector3(-1000.0, -265.0, -1000.0),
				"range": 100.0
			},
			{
				"text": "Find the missing villager",
				"type": "interact",
				"target": "MissingVillager"
			},
			{
				"text": "Return to the village entrance",
				"type": "reach_position",
				"position": Vector3(-1100.0, -265.0, -1100.0),
				"range": 100.0
			}
		],
		"reward": {
			"money": 100,
			"experience": 80,
			"items": []
		}
	},
	{
		"id": "quest_003",
		"name": "Clear the Invasion",
		"requires": ["quest_001", "quest_002"],
		"description": "The village is still occupied by hostile creatures. Drive them out and make the area safe again.",
		"goals": [
			{
				"text": "Defeat 10 enemies",
				"type": "kill",
				"amount": 10,
				"enemy_group": "InvasionEnemy"
			},
			{
				"text": "Defeat the invading leader",
				"type": "kill_target",
				"target": "InvasionLeader"
			},
			{
				"text": "Report back to the quest giver",
				"type": "interact",
				"target": "QuestGiver"
			}
		],
		"reward": {
			"money": 600,
			"experience": 400,
			"items": [
				{"name": "iron sword", "amount": 1},
				{"name": "health potion", "amount": 5}
			]
		}
	}
]


onready var background:TextureRect = $BG
onready var quests_list_control:Control = $QuestList  
# ===== QuestSystem.gd — replace _ready() and _physics_process() =====
func _ready():
	add_to_group("QuestSystem")
	quest_giver.hide()
	background.hide()
	quests_list_control.hide()
	quest_row_template.visible = false
	quest_button_template.visible = false

	# Puppet copies (other players) and the server's own bookkeeping copy
	# of a remote player must never wire up input or run quest goal
	# checks against player state that only ever reflects THAT owning
	# client -- same guard every other per-player UI panel already has
	# (AuctionHouse.gd, Skillbar.gd).
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return

	accept_button.connect("pressed", self, "acceptPressed")
	refuse_button.connect("pressed", self, "refusePressed")
	receive_reward_button.connect("pressed", self, "receiveRewardPressed")

	updateTrackerDisplay()
	populateQuestList()


func _physics_process(delta):
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if player.movement_mode != "idle":
		quest_giver.visible = false
		background.visible = false
		player.quests_list.visible = false
	if Engine.get_physics_frames() % 10 == 0:
		checkQuestGoals()




func isQuestAvailable(quest:Dictionary) -> bool:
	var requires:Array = quest.get("requires", [])
	for req_id in requires:
		if !completed_quest_ids.has(req_id):
			return false
	return true

func populateQuestList() -> void:
	for quest in quests_list:
		var quest_id:String = quest["id"]
		var repeatable:bool = quest.get("repeatable", false)

		# Non-repeatable quest whose reward was already received:
		# remove its button completely.
		if !repeatable and completed_quest_ids.has(quest_id):
			if _quest_list_buttons.has(quest_id):
				var completed_button = _quest_list_buttons[quest_id]

				if is_instance_valid(completed_button):
					completed_button.queue_free()

				_quest_list_buttons.erase(quest_id)

			continue

		var available:bool = isQuestAvailable(quest)

		if !_quest_list_buttons.has(quest_id):
			if !available:
				continue

			var button = quest_button_template.duplicate()
			button.visible = true
			quest_list_grid.add_child(button)
			button.connect("pressed", self, "offerQuestFromList", [quest_id])
			_quest_list_buttons[quest_id] = button

		var btn = _quest_list_buttons.get(quest_id)
		if !is_instance_valid(btn):
			continue

		var label:Label = btn.get_node("QuestNameLabel")

		# Repeatable quests are always shown normally.
		label.text = quest["name"]
		btn.disabled = false









var completed_quest_ids := {} # quest_id -> true, only ever populated for non-repeatable quests
func offerQuest(quest_id:String, quest_name:String, quest_description:String, quest_goals:Array, quest_reward:Dictionary = {}, repeatable:bool = false) -> void:
	if active_quests.has(quest_id):
		if isQuestFullyComplete(quest_id):
			showQuestCompletion(quest_id)
		return

	if !repeatable and completed_quest_ids.has(quest_id):
		return

	pending_quest = {
		"id": quest_id,
		"name": quest_name,
		"description": quest_description,
		"goals": quest_goals,
		"reward": quest_reward,
		"repeatable": repeatable,
		"completed_goals": createCompletedGoals(quest_goals)
	}

	resetProposalButtons()
	quest_description_label.bbcode_text = quest_description
	displayQuestReward(pending_quest)
	quest_giver.show()


func resetProposalButtons() -> void:
	completing_quest_id = ""
	accept_button.show()
	refuse_button.show()
	receive_reward_button.hide()


func showQuestCompletion(quest_id:String) -> void:
	if !active_quests.has(quest_id):
		return

	completing_quest_id = quest_id
	var quest_data:Dictionary = active_quests[quest_id]

	quest_description_label.bbcode_text = quest_data["description"]
	displayQuestReward(quest_data)

	accept_button.hide()
	refuse_button.hide()
	receive_reward_button.show()
	quest_giver.show()


func isQuestFullyComplete(quest_id:String) -> bool:
	if !active_quests.has(quest_id):
		return false

	var quest_data:Dictionary = active_quests[quest_id]
	if !quest_data.has("completed_goals"):
		return false

	for done in quest_data["completed_goals"]:
		if !done:
			return false

	return true

func displayQuestReward(quest_data:Dictionary) -> void:
	var reward:Dictionary = quest_data.get("reward", {})

	var money:int = int(reward.get("money", 0))
	var money_parts := moneyToParts(money)
	reward_coins_copper_label.text = str(money_parts["copper"])
	reward_coins_silver_label.text = str(money_parts["silver"])
	reward_coins_gold_label.text = str(money_parts["gold"])
	reward_coins_rho_label.text = str(money_parts["rhodium"])

	reward_experience_label.text = str(int(reward.get("experience", 0)))

	var items:Array = reward.get("items", [])

	for i in range(1, 6):
		var slot_holder = reward_item_grid.get_node_or_null("QuestReward"+str(i))
		if !is_instance_valid(slot_holder):
			continue

		var entry_index = i - 1
		if entry_index >= Global.size():
			slot_holder.visible = false
			continue

		var item_entry:Dictionary = items[entry_index]
		var item_data = getItemDataByName(str(item_entry.get("name","")))

		if item_data == null:
			slot_holder.visible = false
			continue

		slot_holder.visible = true

		var slot = slot_holder.get_node("Slot")
		slot.texture = item_data["icon"]

		var quantity_label = slot_holder.get_node("Quantity")
		var amount = int(item_entry.get("amount", 1))
		quantity_label.text = str(amount) if amount > 1 else ""

func receiveRewardPressed() -> void:
	if completing_quest_id == "":
		return
	if !active_quests.has(completing_quest_id):
		return

	var quest_id = completing_quest_id
	var quest_data:Dictionary = active_quests[quest_id]
	var reward:Dictionary = quest_data.get("reward", {})

	if !grantQuestReward(reward):
		flashRewardSlotsRed()
		return

	if !quest_data.get("repeatable", false):
		completed_quest_ids[quest_id] = true

	removeQuest(quest_id)
	resetProposalButtons()
	quest_giver.hide()
	populateQuestList()
# ===== QuestSystem.gd — replace the money-reward line in grantQuestReward() =====
func grantQuestReward(reward:Dictionary) -> bool:
	var items:Array = reward.get("items", [])

	if !is_instance_valid(inventory) or !("inventory_grid" in inventory):
		return false

	var free_slots := 0
	for child in inventory.inventory_grid.get_children():
		var slot = child.get_node("Slot")
		if slot.texture == null:
			free_slots += 1

	var needed_slots := 0
	for item_entry in items:
		var item_data = getItemDataByName(str(item_entry.get("name","")))
		if item_data == null:
			continue
		var stackable = !(item_data.has("type") or item_data.has("scene") or item_data.has("carry"))
		if stackable:
			needed_slots += 1
		else:
			needed_slots += int(item_entry.get("amount", 1))

	if needed_slots > free_slots:
		return false

	for item_entry in items:
		var item_data = getItemDataByName(str(item_entry.get("name","")))
		if item_data == null:
			continue
		var amount = int(item_entry.get("amount", 1))
		var stackable = !(item_data.has("type") or item_data.has("scene") or item_data.has("carry"))
		if stackable:
			Global.addStackableItem(inventory.inventory_grid, item_data, inventory.floating_text_parent, amount)
		else:
			for i in range(amount):
				Global.addNotStackableItem(inventory.inventory_grid, item_data, inventory.floating_text_parent)
				
	var money_reward = int(reward.get("money", 0))
	if money_reward > 0:
		Global.grantMoney(player.entity_name, money_reward)

	var experience = int(reward.get("experience", 0))
	if experience > 0:
		player.stats.getExperience(experience) # already authority-routed

	inventory.updateInventory()

	return true

func flashRewardSlotsRed() -> void:
	for i in range(1, 6):
		var slot_holder = reward_item_grid.get_node_or_null("QuestReward"+str(i))
		if !is_instance_valid(slot_holder) or !slot_holder.visible:
			continue

		var slot = slot_holder.get_node("Slot")
		var tween = slot_holder.get_node_or_null("Tween")
		if !is_instance_valid(tween):
			tween = Tween.new()
			slot_holder.add_child(tween)
			tween.name = "Tween"

		var original_color = slot.modulate
		var original_scale = slot_holder.rect_scale

		tween.stop_all()
		tween.interpolate_property(slot, "modulate", original_color, Color(1,0.3,0.3), 0.1, Tween.TRANS_QUAD, Tween.EASE_OUT)
		tween.interpolate_property(slot, "modulate", Color(1,0.3,0.3), original_color, 0.1, Tween.TRANS_QUAD, Tween.EASE_IN, 0.1)
		tween.interpolate_property(slot_holder, "rect_scale", original_scale, original_scale * 1.15, 0.1, Tween.TRANS_QUAD, Tween.EASE_OUT)
		tween.interpolate_property(slot_holder, "rect_scale", original_scale * 1.15, original_scale, 0.1, Tween.TRANS_QUAD, Tween.EASE_IN, 0.1)
		tween.start()

func moneyToParts(money:int) -> Dictionary:
	var copper = money % 100
	var silver_total = int(money / 100)
	var silver = silver_total % 5000
	var gold_total = int(silver_total / 5000)
	var gold = gold_total % 5000
	var rhodium = int(gold_total / 5000)

	return {"copper": copper, "silver": silver, "gold": gold, "rhodium": rhodium}


func getItemDataByName(item_name:String):
	if item_name == "":
		return null

	var sources = [Global.resources, Global.weapons, Global.armors, Global.flasks, Global.food, Global.necklaces, Global.rings]

	for source in sources:
		for key in source.keys():
			if str(key).to_lower() == item_name.to_lower():
				var data = source[key].duplicate()
				data["icon"] = load(data["icon"]) if data["icon"] is String else data["icon"]
				return data

	return null


func offerQuestFromList(quest_id:String) -> void:
	quests_list_control.hide()
	for quest in quests_list:
		if quest["id"] == quest_id:
			if !quest.get("repeatable", false) and completed_quest_ids.has(quest_id):
				return
			offerQuest(
				quest["id"],
				quest["name"],
				quest["description"],
				quest["goals"],
				quest.get("reward", {}),
				quest.get("repeatable", false)
			)
			return


func createCompletedGoals(goals:Array) -> Array:
	var completed:Array = []

	for goal in goals:
		completed.append(false)

	return completed



func acceptPressed() -> void:
	if pending_quest.empty():
		quest_giver.hide()
		return

	var quest_id:String = pending_quest["id"]

	if active_quests.has(quest_id):
		pending_quest = {}
		quest_giver.hide()
		return

	active_quests[quest_id] = pending_quest.duplicate(true)
	pending_quest = {}

	quest_giver.hide()
	addQuestToTracker(active_quests[quest_id])


func refusePressed() -> void:
	pending_quest = {}
	completing_quest_id = ""
	quest_giver.hide()




func addQuestToTracker(quest_data:Dictionary) -> void:
	var quest_id:String = quest_data["id"]
	if !quest_data.has("completed_goals"):
		quest_data["completed_goals"] = createCompletedGoals(quest_data["goals"])
	if !quest_data.has("kill_progress"):
		quest_data["kill_progress"] = _zeroProgress(quest_data["goals"].size())
	if _quest_rows.has(quest_id):
		updateQuestRow(quest_id)
		return
	var row = quest_row_template.duplicate()
	row.visible = true
	tracker_grid.add_child(row)
	_quest_rows[quest_id] = row
	updateQuestRow(quest_id)


func checkQuestGoals() -> void:
	if !is_instance_valid(player):
		return

	for quest_id in active_quests.keys():
		var quest_data:Dictionary = active_quests[quest_id]

		if !quest_data.has("goals"):
			continue
		if !quest_data.has("completed_goals"):
			quest_data["completed_goals"] = createCompletedGoals(quest_data["goals"])
		if !quest_data.has("kill_progress"):
			quest_data["kill_progress"] = _zeroProgress(quest_data["goals"].size())

		var goals:Array = quest_data["goals"]
		var completed:Array = quest_data["completed_goals"]

		for i in range(goals.size()):
			if completed[i]:
				continue
			if checkGoal(goals[i], quest_data, i):
				completed[i] = true
				quest_data["completed_goals"] = completed
				active_quests[quest_id] = quest_data

		updateQuestRow(quest_id)

func checkGoal(goal:Dictionary, quest_data:Dictionary, goal_index:int) -> bool:
	var type:String = goal.get("type", "")
	match type:
		"reach_position":
			var position:Vector3 = goal["position"]
			var range_:float = goal.get("range", 10.0)
			if player.global_transform.origin.distance_to(position) <= range_:
				return true
			if is_instance_valid(party):
				for member in party.party_members:
					var member_node = party.findPlayerByName(str(member.get("entity_name","")))
					if is_instance_valid(member_node) and member_node.global_transform.origin.distance_to(position) <= range_:
						return true
			return false
		"kill":
			return getQuestKillCount(quest_data, goal_index) >= int(goal.get("amount", 1))
		"kill_target":
			return hasKilledQuestTarget(goal.get("target", ""))
		"interact":
			return hasInteractedWithQuestTarget(goal.get("target", ""))
		"collect":
			return getPlayerItemAmount(goal.get("item", "")) >= int(goal.get("amount", 1))
	return false

func updateQuestRow(quest_id:String) -> void:
	if !active_quests.has(quest_id) or !_quest_rows.has(quest_id):
		return

	var quest_data:Dictionary = active_quests[quest_id]
	var row = _quest_rows[quest_id]

	var name_label:Label = row.get_node("QuestNameLabel")
	var goals_label:RichTextLabel = row.get_node("QuestGoals")

	name_label.text = quest_data["name"]
	goals_label.bbcode_text = formatQuestGoals(quest_data)


func formatQuestGoals(quest_data:Dictionary) -> String:
	var text := ""

	var goals:Array = quest_data["goals"]
	var completed:Array = quest_data["completed_goals"]

	for i in range(goals.size()):
		var goal:Dictionary = goals[i]
		var goal_text:String = goal["text"]
		var progress_text := ""

		match goal.get("type",""):
			"kill":
				var required:int = goal.get("amount",1)
				var current:int = min(getQuestKillCount(quest_data, i), required)
				progress_text = " (" + str(current) + "/" + str(required) + ")"
			"collect":
				var required_c:int = goal.get("amount",1)
				var current_c:int = min(getPlayerItemAmount(goal.get("item","")), required_c)
				progress_text = " (" + str(current_c) + "/" + str(required_c) + ")"

		if completed[i]:
			text += "[color=yellow]- " + goal_text + progress_text + "[/color]\n"
		else:
			text += "- " + goal_text + progress_text + "\n"

	return text

func removeQuest(quest_id:String) -> void:
	if !active_quests.has(quest_id):
		return

	active_quests.erase(quest_id)

	if _quest_rows.has(quest_id):
		var row = _quest_rows[quest_id]

		if is_instance_valid(row):
			row.queue_free()

		_quest_rows.erase(quest_id)


func hasActiveQuest(quest_id:String) -> bool:
	return active_quests.has(quest_id)


func updateTrackerDisplay() -> void:
	for quest_id in active_quests.keys():
		addQuestToTracker(active_quests[quest_id])


var kill_counts := {} # enemy_group (String) -> int
# Called by the killed mob's Stats.gd (grantKillExperience) on whichever
# node actually has combat authority for that kill -- the server for
# online play, this same client for offline. Takes the dying mob's full
# group list since a goal only cares about ONE group name and different
# quests may care about different ones.
func registerKill(enemy_groups:Array) -> void:
	for quest_id in active_quests.keys():
		var quest_data:Dictionary = active_quests[quest_id]
		if !quest_data.has("goals"):
			continue
		var goals:Array = quest_data["goals"]
		if !quest_data.has("completed_goals"):
			quest_data["completed_goals"] = createCompletedGoals(goals)
		if !quest_data.has("kill_progress"):
			quest_data["kill_progress"] = _zeroProgress(goals.size())

		var completed:Array = quest_data["completed_goals"]
		var progress:Array = quest_data["kill_progress"]

		for i in range(goals.size()):
			if completed[i]:
				continue
			var goal:Dictionary = goals[i]
			if goal.get("type","") != "kill":
				continue
			var group_name = str(goal.get("enemy_group",""))
			if group_name != "" and enemy_groups.has(group_name):
				progress[i] = int(progress[i]) + 1

		quest_data["kill_progress"] = progress
		active_quests[quest_id] = quest_data

func _zeroProgress(size:int) -> Array:
	var arr := []
	for i in range(size):
		arr.append(0)
	return arr

func getQuestKillCount(quest_data:Dictionary, goal_index:int) -> int:
	var progress:Array = quest_data.get("kill_progress", [])
	if goal_index < 0 or goal_index >= progress.size():
		return 0
	return int(progress[goal_index])


func hasKilledQuestTarget(target:String) -> bool:
	return false


func hasInteractedWithQuestTarget(target:String) -> bool:
	return false


func getPlayerItemAmount(item:String) -> int:
	return 0





func gatherQuestSnapshot() -> Dictionary:
	var active_out := {}
	for quest_id in active_quests.keys():
		var qd = active_quests[quest_id]
		active_out[quest_id] = {
			"completed_goals": qd.get("completed_goals", []),
			"kill_progress": qd.get("kill_progress", [])
		}
	return {
		"active_quests": active_out,
		"completed_quest_ids": completed_quest_ids.duplicate(true)
	}

func _findQuestDefinition(quest_id:String):
	for quest in quests_list:
		if quest["id"] == quest_id:
			return quest
	return null

# Frees every tracker row / list button this node currently owns. Required
# so a pooled Player node reused for a different entity_name (or a brand
# new snapshot arriving) never leaves the previous occupant's quest UI on
# screen -- applyOwnQuestSnapshot() always calls this before rebuilding,
# even when the incoming snapshot is empty (new character, no quests.save
# yet), unlike Friends/Loot which skip applying on an empty snapshot and
# so can leave pooled leftovers on screen.
func _resetQuestUI() -> void:
	for quest_id in _quest_rows.keys():
		var row = _quest_rows[quest_id]
		if is_instance_valid(row):
			row.queue_free()
	_quest_rows.clear()

	for quest_id in _quest_list_buttons.keys():
		var btn = _quest_list_buttons[quest_id]
		if is_instance_valid(btn):
			btn.queue_free()
	_quest_list_buttons.clear()

	pending_quest = {}
	completing_quest_id = ""
	quest_giver.hide()
func hardResetForPool() -> void:
	_resetQuestUI()
	active_quests.clear()
	completed_quest_ids.clear()
	kill_counts.clear()
func applyOwnQuestSnapshot(data:Dictionary) -> void:
	_resetQuestUI()
	active_quests.clear()
	completed_quest_ids.clear()

	if data.empty():
		populateQuestList()
		return

	completed_quest_ids = data.get("completed_quest_ids", {}).duplicate(true)

	var saved_active:Dictionary = data.get("active_quests", {})
	for quest_id in saved_active.keys():
		var quest_def = _findQuestDefinition(quest_id)
		if quest_def == null:
			continue
		var saved_entry:Dictionary = saved_active[quest_id]
		active_quests[quest_id] = {
			"id": quest_def["id"],
			"name": quest_def["name"],
			"description": quest_def["description"],
			"goals": quest_def["goals"],
			"reward": quest_def.get("reward", {}),
			"repeatable": quest_def.get("repeatable", false),
			"completed_goals": saved_entry.get("completed_goals", createCompletedGoals(quest_def["goals"])),
			"kill_progress": saved_entry.get("kill_progress", _zeroProgress(quest_def["goals"].size())),
		}

	updateTrackerDisplay()
	populateQuestList()

func saveData() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	var world = player.get_parent()
	if is_instance_valid(world) and world.has_method("saveQuestsFor"):
		world.saveQuestsFor(player, gatherQuestSnapshot())

# Server calls this on the owning client during autosave for remote
# players -- same self-report pattern as Friends/Crafting/Loot. Gated on
# data_fully_loaded so a not-yet-restored pooled node can never
# self-report blank progress over a real save (the exact class of bug
# the PlayerSpawner comments describe for every other system).
remote func requestSelfSaveQuests() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if "data_fully_loaded" in player and !player.data_fully_loaded:
		return
	saveData()
