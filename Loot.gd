extends Control

onready var player = $"../.."
onready var loot_grid = $ScrollContainer/GridContainer
onready var loot_slot_holder = $ScrollContainer/GridContainer/LootSlot
onready var label_debug = $Label
onready var area =  $"../../Turnable/Area"
onready var close_button = $Close

var current_corpse = null

	
var corpse_loot_data = {}# corpse_id -> [{texture, quantity}]

func _ready():
	close_button.connect("pressed",self,"closeLoot")
	loadData()
	hide()

var grabbed_corpse = null
var grabbed_collision_shapes = []
func _physics_process(delta):
	if Input.is_action_just_pressed("loot"):
		var corpse = getDeadBodyInArea()
		updateSlots()

		if corpse:
			openCorpseLoot(corpse)
		else:
			hide()

	if Input.is_action_just_pressed("grab"):
		if grabbed_corpse:
			dropCorpse()
		else:
			var corpse = getDeadBodyInArea()
			if corpse:
				grabCorpse(corpse)

	if grabbed_corpse:
		updateGrabbedCorpse()
		
func grabCorpse(corpse):
	grabbed_corpse = corpse

	player.is_carrying = true
	grabbed_corpse.is_being_carried = true

	grabbed_collision_shapes.clear()
	disableCollisionsRecursive(corpse)

	if corpse is RigidBody:
		corpse.mode = RigidBody.MODE_KINEMATIC
		corpse.linear_velocity = Vector3.ZERO
		corpse.angular_velocity = Vector3.ZERO
		
		
func disableCollisionsRecursive(node):
	for child in node.get_children():

		if child is CollisionShape:
			child.disabled = true
			grabbed_collision_shapes.append(child)

		disableCollisionsRecursive(child)
func updateGrabbedCorpse():
	if grabbed_corpse == null:
		return

	var forward = -player.player_mesh.global_transform.basis.z

	grabbed_corpse.global_transform.origin = player.global_transform.origin + Vector3(0,2.5,0) + forward * 0.5
	grabbed_corpse.rotation.y = player.player_mesh.rotation.y
	
func dropCorpse():
	if grabbed_corpse == null:
		return

	for shape in grabbed_collision_shapes:
		if is_instance_valid(shape):
			shape.disabled = false

	var forward = player.player_mesh.global_transform.basis.z

	grabbed_corpse.global_transform.origin = player.player_mesh.global_transform.origin + forward * 2 + Vector3.UP

	player.is_carrying = false
	grabbed_corpse.is_being_carried = false

	grabbed_collision_shapes.clear()
	grabbed_corpse = null
	
	
	
func getDeadBodyInArea():
	checkForRevives()
	for body in area.get_overlapping_bodies():
		if body == player:
			continue
		if body.is_in_group("entity") or body.is_in_group("Entity"):
			if "stats" in body and body.stats.health <= 0:
				return body
	return null

var last_health = {} # corpseKey -> previous health
func resetCorpseLoot(corpse):
	if corpse == null:
		return
	var corpseKey = getCorpseKey(corpse)
	if corpse_loot_data.has(corpseKey):
		corpse_loot_data.erase(corpseKey)

func checkForRevives():
	for body in get_tree().get_nodes_in_group("entity"):
		if !"stats" in body:
			continue

		var corpseKey = getCorpseKey(body)
		var currentHealth = body.stats.health

		if !last_health.has(corpseKey):
			last_health[corpseKey] = currentHealth
			continue

		var previousHealth = last_health[corpseKey]

		# dead -> alive transition
		if previousHealth <= 0 and currentHealth > 0:
			resetCorpseLoot(body)

		last_health[corpseKey] = currentHealth

	# repeat for "Entity" group if you use both
	for body in get_tree().get_nodes_in_group("Entity"):
		if !"stats" in body:
			continue

		var corpseKey = getCorpseKey(body)
		var currentHealth = body.stats.health

		if !last_health.has(corpseKey):
			last_health[corpseKey] = currentHealth
			continue

		var previousHealth = last_health[corpseKey]

		if previousHealth <= 0 and currentHealth > 0:
			resetCorpseLoot(body)

		last_health[corpseKey] = currentHealth

func getCorpseKey(body):
	return body.stats.species + "_" + body.stats.Name + "_" + body.name


func openCorpseLoot(corpse):
	saveCurrentCorpseLoot()

	current_corpse = corpse

	var corpseKey = getCorpseKey(corpse)

	if !corpse_loot_data.has(corpseKey):
		corpse_loot_data[corpseKey] = Items.generateLootForCorpse(corpse)

	clearLootGrid()
	loadLootIntoGrid(corpse_loot_data[corpseKey])
	
	show()





func loadLootIntoGrid(lootData):
	ensureSlotCount(lootData.size())

	for i in range(lootData.size()):
		var holder = loot_grid.get_child(i)

		holder.quantity = lootData[i]["quantity"]
		holder.get_node("Slot").texture = Items.food[lootData[i]["item_key"]]["icon"]
		
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
				if Items.food[key]["icon"] == slot.texture:
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
	updateSlots()



func updateSlots()->void:
	for child in loot_grid.get_children():
		child.displayQuantity()
