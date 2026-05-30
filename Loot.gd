extends Control

onready var player = $"../.."
onready var loot_grid = $ScrollContainer/GridContainer
onready var loot_slot_holder = $ScrollContainer/GridContainer/LootSlot
onready var label_debug = $Label
onready var area = $"../../Area"
onready var close_button = $Close

var current_corpse = null

# corpse_id -> [{texture, quantity}]
var corpse_loot_data = {}

func _ready():
	close_button.connect("pressed",self,"closeLoot")
	loadData()
	hide()


func _physics_process(delta):
	if Input.is_action_just_pressed("loot"):
		var corpse = getDeadBodyInArea()

		if corpse:
			openCorpseLoot(corpse)
		else:
			hide()
func getDeadBodyInArea():
	for body in area.get_overlapping_bodies():
		if body == player:
			continue
		if body.is_in_group("entity") or body.is_in_group("Entity"):
			if "stats" in body and body.stats.health <= 0:
				return body
	return null


func getCorpseKey(body):
	return body.stats.species + "_" + body.stats.Name + "_" + body.name


func openCorpseLoot(corpse):
	saveCurrentCorpseLoot()

	current_corpse = corpse

	var corpseKey = getCorpseKey(corpse)

	if !corpse_loot_data.has(corpseKey):
		corpse_loot_data[corpseKey] = generateLootForCorpse(corpse)

	clearLootGrid()
	loadLootIntoGrid(corpse_loot_data[corpseKey])

	show()


func generateLootForCorpse(corpse):
	var loot = []

	match corpse.stats.species.to_lower():

		"wolf":
			loot.append({
				"item_key":"raw_meat_1",
				"quantity":randi() % 2 + 2
			})

			loot.append({
				"item_key":"bone",
				"quantity":randi() % 2 + 1
			})


		"goat":
			loot.append({
				"item_key":"raw_meat_2",
				"quantity":randi() % 2 + 2
			})

			if randf() < 0.4:
				loot.append({
					"item_key":"bone",
					"quantity":1
				})


		"boar":
			loot.append({
				"item_key":"raw_meat_3",
				"quantity":randi() % 3 + 3
			})

			loot.append({
				"item_key":"bone",
				"quantity":randi() % 2 + 1
			})


		"moose":
			loot.append({
				"item_key":"raw_meat_4",
				"quantity":randi() % 4 + 5
			})

			loot.append({
				"item_key":"bone",
				"quantity":randi() % 3 + 2
			})


		_:
			loot.append({
				"item_key":"raw_meat_1",
				"quantity":1
			})

	return loot

func loadLootIntoGrid(lootData):
	ensureSlotCount(lootData.size())

	for i in range(lootData.size()):
		var holder = loot_grid.get_child(i)

		holder.quantity = lootData[i]["quantity"]
		holder.get_node("Slot").texture = Items.food[lootData[i]["item_key"]]


func ensureSlotCount(amount):
	while loot_grid.get_child_count() < amount:
		var newSlot = loot_slot_holder.duplicate()
		newSlot.visible = true
		loot_grid.add_child(newSlot)


func clearLootGrid():
	for child in loot_grid.get_children():
		child.quantity = 0
		child.get_node("Slot").texture = null
func closeLoot():
	if current_corpse == null:
		return

	saveCurrentCorpseLoot()

	hide()
	clearLootGrid()

	current_corpse = null

func saveCurrentCorpseLoot():
	if current_corpse == null:
		return

	var corpseKey = getCorpseKey(current_corpse)
	var savedLoot = []

	for child in loot_grid.get_children():
		var slot = child.get_node("Slot")

		if slot.texture != null:

			var itemKey = ""

			for key in Items.food:
				if Items.food[key] == slot.texture:
					itemKey = key
					break

			if itemKey != "":
				savedLoot.append({
					"item_key": itemKey,
					"quantity": child.quantity
				})

	corpse_loot_data[corpseKey] = savedLoot


func saveData():
	saveCurrentCorpseLoot()

	var file = File.new()

	if file.open("user://corpse_loot.save", File.WRITE) == OK:
		file.store_var(corpse_loot_data)
		file.close()


func loadData():
	var file = File.new()

	if !file.file_exists("user://corpse_loot.save"):
		return

	if file.open("user://corpse_loot.save", File.READ) != OK:
		return

	corpse_loot_data = file.get_var()
	file.close()
