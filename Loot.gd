extends Control

onready var player = $"../.."
onready var loot_grid = $ScrollContainer/GridContainer
onready var loot_slot_holder = $ScrollContainer/GridContainer/LootSlot
onready var inventory_grid = $"../Inventory/ScrollContainer/GridContainer"
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
	if Engine.get_physics_frames() % 12 == 0:
		checkForRevives()
		if visible:
			autoFixStackables()
	if Input.is_action_just_pressed("loot"):
		var corpse=getDeadBodyInArea()
		updateSlots()

		if corpse:
			if visible and current_corpse==corpse:
				updateSlots()
				lootAll()
			else:
				openCorpseLoot(corpse)
				updateSlots()
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
		
		
func lootAll()->void:
	var free_slots=0
	var stackable_icons={}

	for slot in inventory_grid.get_children():
		var texture=slot.get_node("Slot").texture
		if texture:
			stackable_icons[texture]=true
		else:
			free_slots+=1

	for loot_slot in loot_grid.get_children():
		var texture=loot_slot.get_node("Slot").texture
		if !texture:
			continue

		var quantity=loot_slot.quantity
		var item=null

		for source in Items.categories:
			for data in source.values():
				if CommonBehaviours.sameIcon(data["icon"],texture):
					item=data.duplicate()
					item.icon=load(item.icon) if item.icon is String else item.icon
					break
			if item:
				break

		if !item:
			continue

		var stackable=!("type" in item) and !("scene" in item) and !("carry" in item)

		if stackable:
			if !stackable_icons.has(texture):
				if free_slots<=0:
					continue
				free_slots-=1
				stackable_icons[texture]=true

			CommonBehaviours.addStackableItem(inventory_grid,item,player.inventory.floating_text_parent,quantity)
			loot_slot.get_node("Slot").texture=null
			loot_slot.quantity=0
			loot_slot.displayQuantity()
		else:
			var moved=min(quantity,free_slots)
			if moved<=0:
				continue

			for i in range(moved):
				CommonBehaviours.addNotStackableItem(inventory_grid,item,player.inventory.floating_text_parent)

			free_slots-=moved
			loot_slot.quantity-=moved

			if loot_slot.quantity<=0:
				loot_slot.get_node("Slot").texture=null
				loot_slot.quantity=0

			loot_slot.displayQuantity()

	saveCurrentCorpseLoot()
	player.inventory.updateInventory()
	player.inventory.autoFixStackables()
func autoFixStackables()->void:
	var stacked_textures={}

	for slot in loot_grid.get_children():
		var texture=slot.get_node("Slot").texture
		if !texture:continue

		if player.inventory.isArmor(texture):
			slot.stackable=false
			continue

		var is_weapon=false
		for key in Items.weapons:
			if CommonBehaviours.sameIcon(Items.weapons[key]["icon"],texture):
				is_weapon=true
				break

		if is_weapon:
			slot.stackable=false
			continue

		if slot.quantity>1:
			stacked_textures[texture]=true

	for slot in loot_grid.get_children():
		var texture=slot.get_node("Slot").texture
		if !texture:continue

		if player.inventory.isArmor(texture):
			slot.stackable=false
			continue

		var is_weapon=false
		for key in Items.weapons:
			if CommonBehaviours.sameIcon(Items.weapons[key]["icon"],texture):
				is_weapon=true
				break

		if is_weapon:
			slot.stackable=false
		elif stacked_textures.has(texture):
			slot.stackable=true
		
		
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

var last_health = {}
var last_dead = {}
var last_respawn_id = {}
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
		var currentDead = body.is_dead if "is_dead" in body else currentHealth <= 0

		if !last_health.has(corpseKey):
			last_health[corpseKey] = currentHealth
			last_dead[corpseKey] = currentDead
			continue

		var previousHealth = last_health[corpseKey]
		var previousDead = last_dead.get(corpseKey,currentDead)

		if previousHealth <= 0 and currentHealth > 0:
			resetCorpseLoot(body)

		if previousDead and !currentDead:
			resetCorpseLoot(body)

		if currentHealth > 0 and !currentDead and (previousHealth <= 0 or previousDead):
			resetCorpseLoot(body)
		var currentRespawnId = body.respawn_id
		if last_respawn_id.get(corpseKey,-1) != currentRespawnId:
			resetCorpseLoot(body)

		last_respawn_id[corpseKey] = currentRespawnId
		last_health[corpseKey] = currentHealth
		last_dead[corpseKey] = currentDead

	for body in get_tree().get_nodes_in_group("Entity"):
		if !"stats" in body:
			continue

		var corpseKey = getCorpseKey(body)
		var currentHealth = body.stats.health
		var currentDead = body.is_dead if "is_dead" in body else currentHealth <= 0

		if !last_health.has(corpseKey):
			last_health[corpseKey] = currentHealth
			last_dead[corpseKey] = currentDead
			continue

		var previousHealth = last_health[corpseKey]
		var previousDead = last_dead.get(corpseKey,currentDead)

		if previousHealth <= 0 and currentHealth > 0:
			resetCorpseLoot(body)

		if previousDead and !currentDead:
			resetCorpseLoot(body)

		if currentHealth > 0 and !currentDead and (previousHealth <= 0 or previousDead):
			resetCorpseLoot(body)

		last_health[corpseKey] = currentHealth
		last_dead[corpseKey] = currentDead

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

	var categories={
		"food":Items.food,
		"flasks":Items.flasks,
		"weapons":Items.weapons,
		"armors":Items.armors,
		"rings":Items.rings,
		"necklaces":Items.necklaces
	}

	for i in range(lootData.size()):
		var holder=loot_grid.get_child(i)
		var item=lootData[i]
		var data=null

		if item.has("category"):
			data=categories[item["category"]].get(item["item_key"],null)
		else:
			for category in categories.values():
				if category.has(item["item_key"]):
					data=category[item["item_key"]]
					break

		if !data:
			continue

		holder.quantity=item.get("quantity",1)
		var icon=data["icon"]
		holder.get_node("Slot").texture=load(icon) if typeof(icon)==TYPE_STRING else icon
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
	if current_corpse==null:return

	var corpseKey=getCorpseKey(current_corpse)
	var savedLoot=[]

	var categories={
		"food":Items.food,
		"flasks":Items.flasks,
		"weapons":Items.weapons,
		"armors":Items.armors,
		"rings":Items.rings,
		"necklaces":Items.necklaces
	}

	for child in loot_grid.get_children():
		var texture=child.get_node("Slot").texture
		if !texture:continue

		for category_name in categories:
			var category=categories[category_name]
			for item_key in category:
				if CommonBehaviours.sameIcon(category[item_key]["icon"],texture):
					savedLoot.append({
						"category":category_name,
						"item_key":item_key,
						"quantity":child.quantity
					})
					break

	corpse_loot_data[corpseKey]=savedLoot

func saveData():
	saveCurrentCorpseLoot()

	var file = File.new()

	if file.open("user://corpse_loot.save",File.WRITE) == OK:
		file.store_var({
			"corpse_loot_data":corpse_loot_data,
			"last_respawn_id":last_respawn_id
		})
		file.close()

func loadData():
	var file = File.new()

	if !file.file_exists("user://corpse_loot.save"):
		return

	if file.open("user://corpse_loot.save",File.READ) != OK:
		return

	var data = file.get_var()
	file.close()

	if typeof(data) == TYPE_DICTIONARY:
		corpse_loot_data = data.get("corpse_loot_data",{})
		last_respawn_id = data.get("last_respawn_id",{})
	else:
		corpse_loot_data = data

	updateSlots()





func updateSlots()->void:
	for child in loot_grid.get_children():
		child.displayQuantity()
