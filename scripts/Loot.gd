extends Control # Loot.gd — private multi-corpse loot

onready var player = $"../.."
onready var loot_grid = $ScrollContainer/GridContainer
onready var loot_slot_holder = $ScrollContainer/GridContainer/LootSlot
onready var inventory_grid = $"../Inventory/ScrollContainer/GridContainer"
onready var area = $"../../Turnable/Area"
onready var close_button = $Close

var current_corpses = []
var current_corpse_keys = []
var displayed_loot_sources = []
var corpse_loot_data = {}
var grabbed_corpse = null
var grabbed_collision_shapes = []
var last_health = {}
var last_dead = {}
var last_respawn_id = {}
var _corpse_base_key_cache := {} # instance_id -> String
var _revive_entity_cache: Array = []
var _revive_cache_frame := -999999
var _revive_check_offset := -1
export var revive_cache_rebuild_interval := 300
func _ready():
	close_button.connect("pressed",self,"closeLoot")
	_revive_check_offset = get_instance_id() % 65
	hide()

func gatherLootSnapshot() -> Dictionary:
	return {"corpse_loot_data":corpse_loot_data,"last_respawn_id":last_respawn_id}
remote func applyOwnLootSnapshot(data:Dictionary) -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer() or data.empty():
		return
	corpse_loot_data=data.get("corpse_loot_data",{})
	last_respawn_id=data.get("last_respawn_id",{})
	if visible:
		buildCombinedLootGrid()
		updateSlots()

var _loot_save_pending := false

func saveData() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if _loot_save_pending:
		return
	_loot_save_pending = true
	call_deferred("_deferredSaveLoot")

func _deferredSaveLoot() -> void:
	_loot_save_pending = false
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	var world = player.get_parent()
	if !is_instance_valid(world) or !world.has_method("saveLootFor"):
		return
	world.saveLootFor(player, gatherLootSnapshot(), world.world_id)

remote func requestSelfSaveLoot() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	saveData()

func _physics_process(delta):
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	if (Engine.get_physics_frames() + _revive_check_offset) % 65 == 0:
		checkForRevives()
		if visible:
			autoFixStackables()
	if Input.is_action_just_pressed("loot"):
		var corpses=getDeadBodiesInArea()
		if corpses.empty():
			if visible:
				closeLoot()
			else:
				hide()
		elif visible and sameCorpseGroup(corpses,current_corpses):
			lootAll()
		else:
			openCorpseLoots(corpses)
		updateSlots()
	if Input.is_action_just_pressed("grab"):
		if grabbed_corpse:
			dropCorpse()
		else:
			var corpses=getDeadBodiesInArea()
			if !corpses.empty():
				grabCorpse(corpses[0])
	if grabbed_corpse:
		updateGrabbedCorpse()

func sameCorpseGroup(a:Array,b:Array) -> bool:
	if a.size()!=b.size():
		return false
	var keys_a=[]
	var keys_b=[]
	for corpse in a:
		keys_a.append(getCorpseKey(corpse))
	for corpse in b:
		keys_b.append(getCorpseKey(corpse))
	keys_a.sort()
	keys_b.sort()
	return keys_a==keys_b

func lootAll():
	if current_corpses.empty():
		return
	var free_slots=0
	var existing_stackables={}
	for slot in inventory_grid.get_children():
		var texture=slot.get_node("Slot").texture
		if texture:
			existing_stackables[texture]=true
		else:
			free_slots+=1

	for grid_index in range(loot_grid.get_child_count()):
		if grid_index>=displayed_loot_sources.size():
			continue
		var loot_slot=loot_grid.get_child(grid_index)
		var texture=loot_slot.get_node("Slot").texture
		if !texture:
			continue
		var requested_quantity=int(loot_slot.quantity)
		if requested_quantity<=0:
			continue
		var sources=displayed_loot_sources[grid_index]
		if sources.empty():
			continue
		var item=findItemByTexture(texture)
		if item==null:
			continue
		var stackable=isItemStackable(item)
		var amount_to_take=requested_quantity

		if stackable:
			if !existing_stackables.has(texture):
				if free_slots<=0:
					continue
				free_slots-=1
				existing_stackables[texture]=true
		else:
			amount_to_take=min(requested_quantity,free_slots)
			if amount_to_take<=0:
				continue

		var available=calculateAvailableFromSources(sources)
		amount_to_take=min(amount_to_take,available)
		if amount_to_take<=0:
			continue

		var actually_removed=consumeFromLootSources(sources,amount_to_take)
		if actually_removed<=0:
			continue

		if actually_removed<amount_to_take:
			if stackable and !existing_stackables.has(texture):
				existing_stackables.erase(texture)
			if !stackable:
				free_slots+=amount_to_take-actually_removed
			amount_to_take=actually_removed

		if stackable:
			Global.addStackableItem(inventory_grid,item,player.inventory.floating_text_parent,amount_to_take)
		else:
			for i in range(amount_to_take):
				Global.addNotStackableItem(inventory_grid,item,player.inventory.floating_text_parent)
			free_slots-=amount_to_take

	buildCombinedLootGrid()
	player.inventory.updateInventory()
	player.inventory.autoFixStackables()
	saveData()

func calculateAvailableFromSources(sources:Array) -> int:
	var total=0
	for source in sources:
		var corpse_key=source.get("corpse_key","")
		var loot_index=int(source.get("loot_index",-1))
		if corpse_key=="" or loot_index<0 or !corpse_loot_data.has(corpse_key):
			continue
		var loot_data=corpse_loot_data[corpse_key]
		if loot_index>=loot_data.size():
			continue
		total+=int(loot_data[loot_index].get("quantity",0))
	return total

func findItemByTexture(texture):
	for source in Global.categories:
		for key in source:
			var data=source[key]
			if Global.sameIcon(data["icon"],texture):
				var item=data.duplicate()
				if item.has("icon") and item.icon is String:
					item.icon=load(item.icon)
				return item
	return null

func isItemStackable(item) -> bool:
	if item==null:
		return false
	if "type" in item or "scene" in item or "carry" in item:
		return false
	return true

func consumeFromLootSources(sources:Array,amount:int) -> int:
	var remaining=amount
	var removed=0
	for source in sources:
		if remaining<=0:
			break
		var corpse_key=source.get("corpse_key","")
		var loot_index=int(source.get("loot_index",-1))
		if corpse_key=="" or loot_index<0 or !corpse_loot_data.has(corpse_key):
			continue
		var loot_data=corpse_loot_data[corpse_key]
		if loot_index>=loot_data.size():
			continue
		var entry=loot_data[loot_index]
		var available=int(entry.get("quantity",0))
		if available<=0:
			continue
		var take=min(available,remaining)
		entry["quantity"]=available-take
		loot_data[loot_index]=entry
		corpse_loot_data[corpse_key]=loot_data
		remaining-=take
		removed+=take
	return removed

func autoFixStackables()->void:
	var stacked_textures={}
	for slot in loot_grid.get_children():
		var texture=slot.get_node("Slot").texture
		if !texture:
			continue
		if player.inventory.isArmor(texture):
			slot.stackable=false
			continue
		var is_weapon=false
		for key in Global.weapons:
			if Global.sameIcon(Global.weapons[key]["icon"],texture):
				is_weapon=true
				break
		if is_weapon:
			slot.stackable=false
			continue
		if slot.quantity>1:
			stacked_textures[texture]=true
	for slot in loot_grid.get_children():
		var texture=slot.get_node("Slot").texture
		if !texture:
			continue
		if player.inventory.isArmor(texture):
			slot.stackable=false
			continue
		var is_weapon=false
		for key in Global.weapons:
			if Global.sameIcon(Global.weapons[key]["icon"],texture):
				is_weapon=true
				break
		if is_weapon:
			slot.stackable=false
		elif stacked_textures.has(texture):
			slot.stackable=true

func grabCorpse(corpse):
	if !is_instance_valid(corpse):
		return
	grabbed_corpse=corpse
	player.is_carrying=true
	grabbed_corpse.is_being_carried=true
	grabbed_collision_shapes.clear()
	disableCollisionsRecursive(corpse)
	if corpse is RigidBody:
		corpse.mode=RigidBody.MODE_KINEMATIC
		corpse.linear_velocity=Vector3.ZERO
		corpse.angular_velocity=Vector3.ZERO

func disableCollisionsRecursive(node):
	for child in node.get_children():
		if child is CollisionShape:
			child.disabled=true
			grabbed_collision_shapes.append(child)
		disableCollisionsRecursive(child)

func updateGrabbedCorpse():
	if grabbed_corpse==null:
		return
	var forward=-player.player_mesh.global_transform.basis.z
	grabbed_corpse.global_transform.origin=player.global_transform.origin+Vector3(0,2.5,0)+forward*0.5
	grabbed_corpse.rotation.y=player.player_mesh.rotation.y

func dropCorpse():
	if grabbed_corpse==null:
		return
	for shape in grabbed_collision_shapes:
		if is_instance_valid(shape):
			shape.disabled=false
	var forward=player.player_mesh.global_transform.basis.z
	grabbed_corpse.global_transform.origin=player.player_mesh.global_transform.origin+forward*2+Vector3.UP
	player.is_carrying=false
	grabbed_corpse.is_being_carried=false
	grabbed_collision_shapes.clear()
	grabbed_corpse=null

export var loot_detection_radius := 5.0

func getDeadBodiesInArea() -> Array:
	checkForRevives()
	var corpses=[]
	if !is_instance_valid(player):
		return corpses
	var world = player.get_parent()
	if !is_instance_valid(world) or !("world_id" in world):
		return corpses

	var origin = player.global_transform.origin
	for body in Global.queryRadius(world.world_id, origin, loot_detection_radius):
		if !is_instance_valid(body):
			continue
		if body==player:
			continue
		if body.is_in_group("Player") or body.is_in_group("player"):
			continue
		if !(body.is_in_group("entity") or body.is_in_group("Entity")):
			continue
		if !("stats" in body):
			continue
		var health=body.stats.health
		var dead = health<=0
		if !dead:
			continue
		corpses.append(body)
	return corpses

func pruneEmptyCorpseLootData() -> void:
	for key in corpse_loot_data.keys():
		var entries = corpse_loot_data[key]
		var has_any = false
		for entry in entries:
			if int(entry.get("quantity",0)) > 0:
				has_any = true
				break
		if !has_any:
			corpse_loot_data.erase(key)
func getDeadBodyInArea():
	var corpses=getDeadBodiesInArea()
	return corpses[0] if !corpses.empty() else null

func corpseHasLoot(corpse) -> bool:
	if !is_instance_valid(corpse):
		return false
	var corpseKey=getCorpseKey(corpse)
	if !corpse_loot_data.has(corpseKey):
		return true
	for entry in corpse_loot_data[corpseKey]:
		if int(entry.get("quantity",0))>0:
			return true
	return false

func resetCorpseLoot(corpse):
	if !is_instance_valid(corpse):
		return
	var corpseKey=getCorpseKey(corpse)
	if corpse_loot_data.has(corpseKey):
		corpse_loot_data.erase(corpseKey)
	if current_corpse_keys.has(corpseKey):
		var index=current_corpse_keys.find(corpseKey)
		if index>=0:
			current_corpse_keys.remove(index)
			if index<current_corpses.size():
				current_corpses.remove(index)

export var revive_check_radius:float = 60.0

func checkForRevives():
	if !is_instance_valid(player):
		return
	var world = player.get_parent()
	if !is_instance_valid(world) or !("world_id" in world):
		return

	var origin:Vector3 = player.global_transform.origin
	var nearby:Array = Global.queryRadius(world.world_id, origin, revive_check_radius)

	for body in nearby:
		if !is_instance_valid(body) or !("stats" in body):
			continue

		var bodyBaseKey = getCorpseBaseKey(body)

		var currentHealth = body.stats.health
		var currentDead = body.is_dead if "is_dead" in body else currentHealth <= 0
		var currentRespawnId = body.respawn_id if "respawn_id" in body else 0

		if !last_health.has(bodyBaseKey):
			last_health[bodyBaseKey] = currentHealth
			last_dead[bodyBaseKey] = currentDead
			last_respawn_id[bodyBaseKey] = currentRespawnId
			continue

		var previousRespawnId = last_respawn_id.get(bodyBaseKey, currentRespawnId)
		if previousRespawnId != currentRespawnId:
			corpse_loot_data.erase(bodyBaseKey + "_" + str(previousRespawnId))

		last_health[bodyBaseKey] = currentHealth
		last_dead[bodyBaseKey] = currentDead
		last_respawn_id[bodyBaseKey] = currentRespawnId




func getCorpseBaseKey(body):
	if !is_instance_valid(body):
		return "invalid"
	return "id_" + str(body.get_instance_id())

func getCorpseKey(body):
	var base = getCorpseBaseKey(body)
	if base == "invalid":
		return base
	var rid = body.respawn_id if "respawn_id" in body else 0
	return base+"_"+str(rid)
func openCorpseLoot(corpse):
	if corpse==null:
		return
	openCorpseLoots([corpse])

func openCorpseLoots(corpses:Array):
	current_corpses.clear()
	current_corpse_keys.clear()
	displayed_loot_sources.clear()
	var unique_corpses=[]
	var seen_keys={}
	for corpse in corpses:
		if !is_instance_valid(corpse):
			continue
		var corpse_key=getCorpseKey(corpse)
		if seen_keys.has(corpse_key):
			continue
		seen_keys[corpse_key]=true
		unique_corpses.append(corpse)
		current_corpse_keys.append(corpse_key)
	current_corpses=unique_corpses
	if current_corpses.empty():
		hide()
		return
	for corpse in current_corpses:
		var corpse_key=getCorpseKey(corpse)
		if !corpse_loot_data.has(corpse_key):
			var generated=Global.generateLootForCorpse(corpse)
			corpse_loot_data[corpse_key]=generated if generated!=null else []
	clearLootGrid()
	buildCombinedLootGrid()
	show()

func buildCombinedLootGrid():
	var combined={}
	for corpse in current_corpses:
		if !is_instance_valid(corpse):
			continue
		var corpse_key=getCorpseKey(corpse)
		if !corpse_loot_data.has(corpse_key):
			continue
		var loot_data=corpse_loot_data[corpse_key]
		for i in range(loot_data.size()):
			var entry=loot_data[i]
			if !entry.has("item_key"):
				continue
			var quantity=int(entry.get("quantity",0))
			if quantity<=0:
				continue
			var category=str(entry.get("category",""))
			var item_key=str(entry.get("item_key",""))
			var combined_key=category+"::"+item_key
			if !combined.has(combined_key):
				combined[combined_key]={"category":category,"item_key":item_key,"quantity":0,"sources":[]}
			combined[combined_key]["quantity"]+=quantity
			combined[combined_key]["sources"].append({"corpse_key":corpse_key,"loot_index":i})
	ensureSlotCount(combined.size())
	displayed_loot_sources.clear()
	var index=0
	for combined_key in combined:
		var data=combined[combined_key]
		var holder=loot_grid.get_child(index)
		holder.quantity=data["quantity"]
		var item_data=getLootItemData(data["category"],data["item_key"])
		if item_data:
			var icon=item_data["icon"]
			holder.get_node("Slot").texture=load(icon) if typeof(icon)==TYPE_STRING else icon
		displayed_loot_sources.append(data["sources"].duplicate(true))
		index+=1

	# FIX: any slot left over from a previous, larger loot table (e.g. after
	# lootAll() emptied the corpse) was never cleared -- ensureSlotCount()
	# only ever GROWS the grid, never shrinks it, so old textures/quantities
	# stayed visible and draggable after being fully taken. That stale
	# slot was the item-duplication source.
	for extra_index in range(index, loot_grid.get_child_count()):
		var extra_holder = loot_grid.get_child(extra_index)
		extra_holder.quantity = 0
		var extra_slot = extra_holder.get_node_or_null("Slot")
		if is_instance_valid(extra_slot):
			extra_slot.texture = null
func getLootItemData(category:String,item_key:String):
	var categories={"food":Global.food,"flasks":Global.flasks,"weapons":Global.weapons,"armors":Global.armors,"rings":Global.rings,"necklaces":Global.necklaces}
	if !categories.has(category):
		return null
	return categories[category].get(item_key,null)

func loadLootIntoGrid(lootData):
	ensureSlotCount(lootData.size())
	var categories={"food":Global.food,"flasks":Global.flasks,"weapons":Global.weapons,"armors":Global.armors,"rings":Global.rings,"necklaces":Global.necklaces}
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
	while loot_grid.get_child_count()<amount:
		var newSlot=loot_slot_holder.duplicate()
		newSlot.visible=true
		loot_grid.add_child(newSlot)

func clearLootGrid():
	displayed_loot_sources.clear()
	for child in loot_grid.get_children():
		child.quantity=0
		child.get_node("Slot").texture=null

func saveCurrentCorpseLoot():
	return

func saveAllCurrentCorpseLoot():
	saveData()

func closeLoot():
	saveAllCurrentCorpseLoot()
	hide()
	clearLootGrid()
	current_corpses.clear()
	current_corpse_keys.clear()
	displayed_loot_sources.clear()

func updateSlots()->void:
	for child in loot_grid.get_children():
		child.displayQuantity()
