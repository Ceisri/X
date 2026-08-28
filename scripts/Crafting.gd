extends Control #crafting, smelting, cooking and general item processing script

onready var player:KinematicBody = $"../.."
onready var inventory_grid:GridContainer = $"../Inventory/ScrollContainer/GridContainer"
onready var grid= $GridContainer
onready var result_slot=$result/Slot
onready var recipes_book:Control = $RecipeeBook
onready var line_edit:LineEdit = $RecipeeBook/LineEdit

onready var burn_slot=$Smelting/ToBurn 
onready var smelted_slot=$Smelting/Smelted
onready var smelt_progress:TextureProgress=$Smelting/TextureProgress

var smelting={
	"iron powder":Global.resources["iron bar"],
	"gold powder":Global.resources["gold bar"],
	"wood log":Global.resources["coal powder"],
}

var smelt_item=null
var smelt_time=0.0
var smelt_duration=2.5
var smelt_last_time=OS.get_unix_time()+OS.get_ticks_msec()/1000.0



var recipes={
	"iron sword":{
		"result":Global.weapons["sword"],
		"pattern":[
			["iron bar",1,1],
			["iron bar",1,0],
			["wood log",0,0]
		]
	},
	"iron pickaxe":{
		"result":Global.weapons["iron pickaxe"],
		"pattern":[
			["iron bar",0,0],
			["iron bar",1,0],
			["iron bar",2,0],
			["wood log",1,1],
			["wood log",1,2],
		]
	},
	"medicine potion":{
		"result":Global.flasks["medicine potion"],
		"pattern":[
			["oyster mushrooms",0,0],
			["tomato",1,0],
			["tomato",2,0],
			["tomato",3,0],
			["empty",0,1]
		]
	},
	"energy potion":{
		"result":Global.flasks["energy potion"],
		"pattern":[
			["tomato",0,0],
			["empty",1,0],
			["oyster mushrooms",1,1]
		]
	},
	"poison potion":{
		"result":Global.flasks["poison potion"],
		"pattern":[
			["oyster mushrooms",0,0],
			["oyster mushrooms",1,0],
			["empty",1,1]
		]
	},
	"power potion":{
		"result":Global.flasks["power potion"],
		"pattern":[
			["gold ore",1,1],
			["empty",1,0],
			["tomato",0,0]
		]
	},
	"axe":{
		"result":Global.weapons["axe"],
		"pattern":[
			["iron ore",1,1],
			["wood log",0,1],
			["wood log",0,0]
		]
	},
	"hatchet":{
		"result":Global.weapons["hatchet"],
		"pattern":[
			["stone",1,1],
			["wood log",0,1],
			["wood log",0,0]
		]
	},
	"shield":{
		"result":Global.weapons["shield"],
		"pattern":[
			["wood log",0,0],
			["wood log",1,0],
			["iron ore",1,1]
		]
	},
	"great axe":{
		"result":Global.weapons["greataxe"],
		"pattern":[
			["iron ore",0,0],
			["iron ore",1,0],
			["wood log",1,1]
		]
	},
	"great sword":{
		"result":Global.weapons["greatsword"],
		"pattern":[
			["iron ore",1,0],
			["iron ore",1,1],
			["iron ore",1,2]
		]
	},
	"steel pickaxe":{
		"result":Global.weapons["steel pickaxe"],
		"pattern":[
			["gold ore",1,1],
			["gold ore",1,0],
			["wood log",0,0]
		]
	},
	"iron powder":{
		"result":Global.resources["iron powder"],
		"quantity":5,
		"shapeless":true,
		"pattern":[["iron ore"]]
	},
	"gold powder":{
		"result":Global.resources["gold powder"],
		"quantity":5,
		"shapeless":true,
		"pattern":[["gold ore"]]
	},
	"steel powder":{
		"result":Global.resources["steel powder"],
		"pattern":[
			["iron powder",1,0],
			["iron powder",1,1],
			["iron powder",1,2],
			["iron powder",2,0],
			["iron powder",2,1],
			["iron powder",2,2],
			["coal powder",0,0],
		]
	},
	"torso1":{
		"result":Global.armors["torso1"],
		"pattern":[
			["wolf meat",0,0],
			["bone",1,0],
			["bone",1,1]
		]
	},
	"torso2":{
		"result":Global.armors["torso2"],
		"pattern":[
			["iron ore",0,0],
			["iron ore",1,0],
			["bone",1,1]
		]
	},
	"hands1":{
		"result":Global.armors["hands1"],
		"pattern":[
			["wolf meat",0,0],
			["bone",1,0],
			["wood log",0,1]
		]
	},
	"feet1":{
		"result":Global.armors["feet1"],
		"pattern":[
			["boar meat",0,0],
			["bone",1,0],
			["wood log",1,1]
		]
	},
	"silver ring":{
		"result":Global.rings["silver ring"],
		"pattern":[
			["gold ore",0,0],
			["iron ore",1,0],
			["gold ore",1,1]
		]
	},
	"strength ring":{
		"result":Global.rings["strength ring"],
		"pattern":[
			["gold ore",0,0],
			["bone",1,0],
			["gold ore",1,1]
		]
	},
	"orange necklace":{
		"result":Global.necklaces["orange necklace"],
		"pattern":[
			["gold ore",0,0],
			["tomato",1,0],
			["bone",1,1]
		]
	},
	"medallion":{
		"result":Global.necklaces["medallion"],
		"pattern":[
			["gold ore",0,0],
			["gold ore",1,0],
			["bone",0,1]
		]
	}
}





var current_recipe=null


var _recipes_built := false

func _ready():
	$result.connect("pressed",self,"craft")
	$Smelting/Smelted.connect("pressed",self,"takeSmelted")
	recipes_book.visible = false
	line_edit.connect("text_changed",self,"filterRecipes")
	line_edit.connect("focus_entered",self,"startWriting")
	line_edit.connect("focus_exited",self,"stopWriting")
	burn_slot.connect("pressed", self, "burnSlotPressed")

func ensureRecipesBuilt() -> void:
	if _recipes_built:
		return
	_recipes_built = true
	showRecipesButtons()

	



func updateSmelting():
	if !is_instance_valid(current_fire):
		current_fire = null
		return

	var input_icon:Texture = burn_slot.get_node("Slot").texture

	if !input_icon:
		smelt_item = null
		smelt_time = 0.0
		smelt_progress.value = 0
		return

	var input_item_name = texture_to_item(input_icon)

	if !smelting.has(input_item_name):
		smelt_item = null
		smelt_time = 0.0
		smelt_progress.value = 0
		return

	var output_icon:Texture = smelted_slot.get_node("Slot").texture
	var result_icon:Texture = load(smelting[input_item_name]["icon"])

	if output_icon:
		if !Global.sameIcon(output_icon, result_icon):
			smelt_progress.value = 100
			return
	else:
		smelt_progress.value = 0

	if smelt_item != input_item_name:
		smelt_item = input_item_name
		smelt_time = 0.0

	smelt_time += 1
	smelt_progress.value = min(100, smelt_time * 100.0 / smelt_duration)

	if smelt_time < smelt_duration:
		return

	burn_slot.quantity -= 1

	if burn_slot.quantity <= 0:
		burn_slot.quantity = 0
		burn_slot.get_node("Slot").texture = null
		burn_slot.get_node("Quantity").text = ""
	else:
		burn_slot.get_node("Quantity").text = str(burn_slot.quantity)

	if output_icon:
		smelted_slot.quantity += 1
		smelted_slot.get_node("Quantity").text = str(smelted_slot.quantity)
	else:
		smelted_slot.get_node("Slot").texture = result_icon
		smelted_slot.quantity = 1
		smelted_slot.get_node("Quantity").text = "1"

	smelt_time = 0.0
	smelt_progress.value = 0
	smelt_item = null


func takeSmelted():
	var slot=smelted_slot.get_node("Slot")
	var tex=slot.texture
	if !tex:return

	var amount=max(1,int(smelted_slot.get_node("Quantity").text))
	for category in Global.categories:
		for item in category.values():
			if item["icon"]!=tex.resource_path:continue
			if item.get("stackable",false):
				Global.addStackableItem(inventory_grid,item,null,amount)
			else:
				for i in range(amount):
					Global.addNotStackableItem(inventory_grid,item)
			break

	slot.texture=null
	smelted_slot.get_node("Quantity").text=""
	inventory.updateInventory()
	player.stats.getExperience(amount)
	if is_instance_valid(current_fire):
		saveSmelter(current_fire)

var current_fire=null
var cached_fires_to_save_across_scens

var fire_states := {}  # fire_key (String) -> {time,last_time,input,input_amount,output,output_amount}
func _defaultFireState() -> Dictionary:
	return {
		"time": 0.0,
		"last_time": OS.get_unix_time() + OS.get_ticks_msec() / 1000.0,
		"input": "",
		"input_amount": 0,
		"output": "",
		"output_amount": 0
	}

func loadSmelter(fire):
	if !is_instance_valid(fire):
		return

	if is_instance_valid(current_fire) and current_fire != fire:
		saveSmelter(current_fire)

	current_fire = fire
	var key = fire.getFireKey()

	var state = fire_states.get(key)
	if state == null:
		state = _defaultFireState()
		fire_states[key] = state

	var current_time = OS.get_unix_time() + OS.get_ticks_msec() / 1000.0
	var elapsed_time = current_time - state.get("last_time", current_time)
	state["last_time"] = current_time
	state["time"] = state.get("time", 0.0) + elapsed_time

	while state["time"] >= smelt_duration:
		state["time"] -= smelt_duration

		if state["input_amount"] <= 0:
			break
		if !smelting.has(state["input"]):
			break

		var smelt_result = smelting[state["input"]]
		var smelt_result_name = texture_to_item(load(smelt_result["icon"]))

		if state["output"] != "" and state["output"] != smelt_result_name:
			break

		state["input_amount"] -= 1
		state["output"] = smelt_result_name
		state["output_amount"] += 1

		if state["input_amount"] <= 0:
			state["input"] = ""

	smelt_time = state["time"]

	var input_texture_rect = burn_slot.get_node("Slot")
	var input_quantity_label = burn_slot.get_node("Quantity")

	if state["input"] == "":
		input_texture_rect.texture = null
		burn_slot.quantity = 0
		input_quantity_label.text = ""
	else:
		for category in Global.categories:
			if category.has(state["input"]):
				input_texture_rect.texture = load(category[state["input"]]["icon"])
				break
		burn_slot.quantity = state["input_amount"]
		input_quantity_label.text = str(burn_slot.quantity)

	var output_texture_rect = smelted_slot.get_node("Slot")
	var output_quantity_label = smelted_slot.get_node("Quantity")

	if state["output"] == "":
		output_texture_rect.texture = null
		smelted_slot.quantity = 0
		output_quantity_label.text = ""
	else:
		for category in Global.categories:
			if category.has(state["output"]):
				output_texture_rect.texture = load(category[state["output"]]["icon"])
				break
		smelted_slot.quantity = state["output_amount"]
		output_quantity_label.text = str(smelted_slot.quantity)


func saveSmelter(fire):
	if !is_instance_valid(fire):
		return

	var key = fire.getFireKey()
	var state = fire_states.get(key)
	if state == null:
		state = _defaultFireState()
		fire_states[key] = state

	if fire == current_fire:
		state["time"] = smelt_time

		var input_texture = burn_slot.get_node("Slot").texture
		state["input"] = texture_to_item(input_texture)
		state["input_amount"] = burn_slot.quantity

		var output_texture = smelted_slot.get_node("Slot").texture
		state["output"] = texture_to_item(output_texture)
		state["output_amount"] = smelted_slot.quantity

	state["last_time"] = OS.get_unix_time() + OS.get_ticks_msec() / 1000.0
	
	
	
func startWriting()->void:
	player.is_writing=true

func stopWriting()->void:
	player.is_writing=false

func recipeMatches(name,search)->bool:
	var s=search.to_lower()
	var n=name.to_lower()

	if n.find(s)>=0:
		return true

	var item=recipes[name]["result"]

	for word in getSearchKeywords(item):
		if word.find(s)>=0 or s.find(word)>=0:
			return true

	return false




func getSearchKeywords(item)->Array:
	var keys=[]

	if Global.weapons.values().has(item):
		keys+=["weapon","weapons","tool","tools"]

	elif Global.flasks.values().has(item):
		keys+=["flask","flasks","potion","potions","alchemy"]

	elif Global.resources.values().has(item):
		keys+=["resource","resources","material","materials"]

	elif Global.armors.values().has(item):
		keys+=["armor","armors","equipment","gear"]

	elif Global.rings.values().has(item):
		keys+=["ring","rings","jewelry"]

	elif Global.necklaces.values().has(item):
		keys+=["necklace","necklaces","jewelry"]

	elif Global.food.values().has(item):
		keys+=["food","cook","cooking"]

	return keys






	
func filterRecipes(text)->void:
	showRecipesButtons(text)


func sortRecipes(a,b)->bool:
	var search=line_edit.text.to_lower()

	if search=="":
		return a<b

	return getRecipeScore(a,search)>getRecipeScore(b,search)


func getRecipeScore(name,search)->int:
	var score=0
	var n=name.to_lower()

	if n==search:
		score+=100
	if n.begins_with(search):
		score+=50
	if n.find(search)>=0:
		score+=25

	var item=recipes[name]["result"]

	for k in getSearchKeywords(item):
		if k==search:
			score+=80
		elif k.begins_with(search):
			score+=40
		elif k.find(search)>=0:
			score+=20

	return score






func showRecipe(recipe)->void:
	selected_recipe=recipe
	var show=$RecipeeBook/GridContainer
	

	for i in range(min(9,show.get_child_count())):
		var slot=show.get_child(i)
		if slot is Control:
			var tex=slot.get_node_or_null("Slot")
			if tex is TextureRect:
				tex.texture=null

	for r in recipe["pattern"]:
		var item=null
		for category in Global.categories:
			if category.has(r[0]):
				item=category[r[0]]
				break

		if !item:
			continue

		var index=0
		if r.size()>=3:
			index=r[2]*3+r[1]

		if index<show.get_child_count():
			var slot=show.get_child(index)
			if slot is Control:
				var tex=slot.get_node_or_null("Slot")
				if tex is TextureRect:
					tex.texture=cachedIcon(item["icon"])

func returnCraftingItems():
	for i in range(9):
		var slot=grid.get_node("CraftingSlot"+str(i))
		var tex=slot.get_node("Slot").texture
		var label=slot.get_node("Quantity")

		if tex:
			var item=null
			var tex_path = tex.resource_path

			for category in Global.categories:
				for data in category.values():
					var icon_path = data["icon"] if data["icon"] is String else data["icon"].resource_path
					if icon_path == tex_path:
						item=data
						break
				if item:
					break

			if item:
				var amount=int(label.text) if label.text!="" else 1
				if item.get("stackable",false):
					Global.addStackableItem(inventory_grid,item,null,amount)
				else:
					for x in range(amount):
						Global.addNotStackableItem(inventory_grid,item)

		slot.get_node("Slot").texture=null
		slot.quantity = 0
		label.text=""
var _icon_cache := {}
func cachedIcon(path):
	if path == null or path == "":
		return null
	return Global.loadCachedTexture(path)

func showRecipesButtons(search="")->void:
	var list=$RecipeeBook/ScrollContainer/GridContainer
	var holder=list.get_node_or_null("RecipeHolder0")
	if !holder:
		return

	for c in list.get_children():
		if c!=holder:
			c.queue_free()

	var names=recipes.keys()
	names.sort_custom(self,"sortRecipes")

	if search!="":
		var filtered=[]
		for n in names:
			if recipeMatches(n,search):
				filtered.append(n)
		names=filtered

	if names.size()==0:
		return

	holder.visible=true
	holder.get_node("Slot").texture=cachedIcon(recipes[names[0]]["result"]["icon"])
	if holder.is_connected("pressed",self,"showRecipe"):
		holder.disconnect("pressed",self,"showRecipe")
	holder.connect("pressed",self,"showRecipe",[recipes[names[0]]])

	for i in range(1,names.size()):
		var b=holder.duplicate()
		list.add_child(b)
		b.visible=true
		b.get_node("Slot").texture=cachedIcon(recipes[names[i]]["result"]["icon"])
		b.connect("pressed",self,"showRecipe",[recipes[names[i]]])
		if i % 10 == 0:
			yield(get_tree(), "idle_frame")










func get_slot_texture(i):
	if visible == false:
		return
	return grid.get_node_or_null("CraftingSlot"+str(i)+"/Slot").texture

func texture_to_item(texture):
	if texture==null:
		return ""

	for category in Global.categories:
		for name in category:
			if category[name]["icon"]==texture.resource_path:
				return name

	return ""
func checkRecipe(recipe): 
	if visible == false:
		return
	if recipe.get("shapeless",false):
		var found=false
		for i in range(9):
			var name=texture_to_item(get_slot_texture(i))
			if name!="":
				if name!=recipe["pattern"][0][0] or found:
					return false
				found=true
		return found

	for y in range(3):
		for x in range(3):
			var needed=""
			for r in recipe["pattern"]:
				if r[1]==x and r[2]==y:
					needed=r[0]
			if texture_to_item(get_slot_texture(y*3+x))!=needed:
				return false
	return true

onready var result_quanity:Label = $result/Quantity
func updateCrafting():
	if !visible:
		return

	# ALWAYS clear the result first.
	current_recipe = null
	result_slot.texture = null
	result_quanity.text = ""

	# Check the actual current contents of the crafting grid.
	var has_items := false

	for i in range(9):
		var slot = grid.get_node_or_null("CraftingSlot" + str(i))
		if slot == null:
			continue

		var tex = slot.get_node("Slot").texture

		if tex != null:
			has_items = true
			break

	# Empty grid = no result.
	if !has_items:
		return

	# Find a recipe that EXACTLY matches the current grid.
	for recipe in recipes.values():
		if checkRecipe(recipe):
			current_recipe = recipe
			break

	# Items exist, but they don't make a recipe.
	if current_recipe == null:
		return

	# Valid recipe.
	result_slot.texture = cachedIcon(current_recipe["result"]["icon"])

	var amount = current_recipe.get("quantity", 1)

	if amount > 1:
		result_quanity.text = str(amount)

func craft():
	if !current_recipe:
		return

	var amount = 1

	if Input.is_key_pressed(KEY_SHIFT):
		amount = 10
	elif Input.is_key_pressed(KEY_CONTROL):
		amount = getMaxCrafts(current_recipe)

	amount = min(amount, getMaxCrafts(current_recipe))

	if amount <= 0:
		updateCrafting()
		return

	for i in range(amount):
		addCraftedItem(
			current_recipe["result"],
			current_recipe.get("quantity", 1)
		)

		consumeRecipe(current_recipe)

	# IMPORTANT:
	# Ingredients have changed, so the result must be recalculated.
	updateCrafting()

	inventory.updateInventory()


onready var inventory :Control = $"../Inventory"


func getMaxCrafts(recipe):
	var max_amount=999999

	if recipe.get("shapeless",false):
		var found=0
		for i in range(9):
			if texture_to_item(get_slot_texture(i))==recipe["pattern"][0][0]:
				found+=int(grid.get_node("CraftingSlot"+str(i)).get_node("Quantity").text)
		return found

	for r in recipe["pattern"]:
		var index=r[2]*3+r[1]
		var label=grid.get_node("CraftingSlot"+str(index)).get_node("Quantity")
		if label.text=="":
			return 0
		max_amount=min(max_amount,int(label.text))

	return max_amount


func addCraftedItem(item,amount=1):
	if item.has("stackable") and item["stackable"]:
		Global.addStackableItem(inventory_grid,item,null,amount)
	else:
		for i in range(amount):
			Global.addNotStackableItem(inventory_grid,item)

func consumeRecipe(recipe):
	if recipe.get("shapeless",false):
		for i in range(9):
			var slot=grid.get_node("CraftingSlot"+str(i))
			if texture_to_item(slot.get_node("Slot").texture)==recipe["pattern"][0][0]:
				var label=slot.get_node("Quantity")
				label.text=str(int(label.text)-1)
				if int(label.text)<=0:
					label.text=""
					slot.get_node("Slot").texture=null
				return

	for r in recipe["pattern"]:
		var index=r[2]*3+r[1]
		var slot=grid.get_node("CraftingSlot"+str(index))
		var label=slot.get_node("Quantity")

		label.text=str(int(label.text)-1)
		if int(label.text)<=0:
			label.text=""
			slot.get_node("Slot").texture=null




func gatherCraftingSnapshot() -> Dictionary:
	var data := {}
	var craft := []
	for i in range(9):
		var slot = grid.get_node("CraftingSlot" + str(i))
		var tex = slot.get_node("Slot").texture
		craft.append({
			"texture": tex.resource_path if tex else "",
			"quantity": slot.get_node("Quantity").text
		})
	data["crafting"] = craft

	if is_instance_valid(current_fire):
		saveSmelter(current_fire)
	data["fires"] = fire_states
	return data


remote func applyOwnCraftingSnapshot(data:Dictionary) -> void:
	if data.empty():
		return
	if data.has("crafting"):
		for i in range(9):
			var slot = grid.get_node("CraftingSlot" + str(i))
			var saved = data["crafting"][i]
			slot.get_node("Slot").texture = load(saved["texture"]) if saved["texture"] != "" else null
			slot.quantity = int(saved.get("quantity", 0))
			slot.get_node("Quantity").text = str(slot.quantity) if slot.quantity > 0 else ""

	if data.has("fires") and typeof(data["fires"]) == TYPE_DICTIONARY:
		fire_states = data["fires"]
	updateCrafting()





remote func requestSelfSaveCrafting() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	var world = player.get_parent()
	if is_instance_valid(world) and world.has_method("saveCraftingFor"):
		world.saveCraftingFor(player, gatherCraftingSnapshot(), world.world_id)












func retrieveAllSmeltedObjects()->void:
	for fire_key in fire_states.keys():
		var state = fire_states[fire_key]
		if state.get("output","") == "" or state.get("output_amount",0) <= 0:
			continue

		var item = null
		for category in Global.categories:
			if category.has(state["output"]):
				item = category[state["output"]]
				break
		if !item:
			continue

		var amount = state["output_amount"]
		if item.get("stackable",false):
			Global.addStackableItem(inventory_grid,item,null,amount)
		else:
			for i in range(amount):
				Global.addNotStackableItem(inventory_grid,item)

		state["output"] = ""
		state["output_amount"] = 0

		if is_instance_valid(current_fire) and current_fire.getFireKey() == fire_key:
			smelted_slot.get_node("Slot").texture = null
			smelted_slot.get_node("Quantity").text = ""

	inventory.updateInventory()

func _on_Close_pressed():
	visible = false

var selected_recipe=null
var previous_recipe=null

func _on_SendRecipeToCraftingGrid_pressed():
	if !selected_recipe:
		return

	if previous_recipe != selected_recipe:
		returnCraftingItems()
		previous_recipe = selected_recipe

	if selected_recipe.get("shapeless", false):
		var ingredient = selected_recipe["pattern"][0][0]

		for category in Global.categories:
			if category.has(ingredient):
				for inventory_slot in inventory_grid.get_children():
					if inventory_slot.get_node("Slot").texture and Global.sameIcon(inventory_slot.get_node("Slot").texture, load(category[ingredient]["icon"])):

						var craft_slot = grid.get_node("CraftingSlot0")

						inventory_slot.quantity -= 1

						craft_slot.get_node("Slot").texture = load(category[ingredient]["icon"])
						craft_slot.quantity += 1
						craft_slot.get_node("Quantity").text = str(craft_slot.quantity)

						break
				break

	else:
		for recipe_entry in selected_recipe["pattern"]:
			var ingredient = recipe_entry[0]
			var craft_slot = grid.get_node("CraftingSlot" + str(recipe_entry[2] * 3 + recipe_entry[1]))

			for category in Global.categories:
				if category.has(ingredient):
					for inventory_slot in inventory_grid.get_children():
						if inventory_slot.get_node("Slot").texture and Global.sameIcon(inventory_slot.get_node("Slot").texture, load(category[ingredient]["icon"])):

							inventory_slot.quantity -= 1

							craft_slot.get_node("Slot").texture = load(category[ingredient]["icon"])
							craft_slot.quantity += 1
							craft_slot.get_node("Quantity").text = str(craft_slot.quantity)

							break
					break

	updateCrafting()
	inventory.updateInventory()



func _on_ClearCraftingGrid_pressed():
	returnCraftingItems()
func burnSlotPressed():
	if burn_slot.get_node("Slot").texture == null:
		return

	var item = null

	for category in Global.categories:
		for data in category.values():
			if Global.sameIcon(load(data["icon"]), burn_slot.get_node("Slot").texture):
				item = data
				break
		if item:
			break

	if !item:
		return

	if item.get("stackable", false):
		Global.addStackableItem(inventory_grid, item, null, burn_slot.quantity)
	else:
		for i in range(burn_slot.quantity):
			Global.addNotStackableItem(inventory_grid, item)

	burn_slot.get_node("Slot").texture = null
	burn_slot.quantity = 0
	burn_slot.get_node("Quantity").text = ""

	smelt_item = null
	smelt_time = 0
	smelt_progress.value = 0
	inventory.updateInventory()

	if current_fire:
		saveSmelter(current_fire)

func saveData() -> void:
	if !is_instance_valid(player) or !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return
	var world = player.get_parent()
	if is_instance_valid(world) and world.has_method("saveCraftingFor"):
		world.saveCraftingFor(player, gatherCraftingSnapshot(), world.world_id)
