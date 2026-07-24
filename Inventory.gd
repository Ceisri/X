extends Control

onready var player = $"../.."
onready var stats = $"../../Stats"
onready var floating_text_parent = $"../Menu/CharacterBar/Control"

onready var close_button:TextureButton = $Close
onready var combine_button:TextureButton = $Tools/ToolGrid/Combine
onready var split_button:TextureButton = $Tools/ToolGrid/Split
onready var order_button:TextureButton = $Tools/ToolGrid/Order
onready var debug_give_me_items =  $DebugGiveMeItems
onready var inventory_grid =  $ScrollContainer/GridContainer
onready var craft_control:Control = $"../Crafting"

onready var shop:Control = $"../Shop"
onready var shop_grid:GridContainer=  $"../Shop/ScrollContainer/GridContainer"
onready var shopping_cart_grid:GridContainer= $"../Shop/ScrollContainer2/GridContainer"
onready var buy_button:TextureButton = $"../Shop/Buy"
onready var sell_button:TextureButton = $"../Shop/Sell"
onready var area_detect_merchant:Area = $"../../Turnable/Melee" 
var last_pressed_index:int = -1
var last_press_time:float = 0.0

export var double_press_time:float = 0.4
export var max_inventory_slots:int = 132

const SAVE_DIR = "user://Characters/"
const SAVE_FILE = "/inventory.save"


func _ready()->void:
	shop.hide()
	close_button.connect("pressed",self,"collapse")
	combine_button.connect("pressed",self,"combinePressed")
	split_button.connect("pressed",self,"splitSelectedSlot")
	order_button.connect("pressed",self,"orderSlots")
	debug_give_me_items.connect("pressed",self,"getRandItems")
	buy_button.connect("pressed",self,"buyItemsFromCart")
	sell_button.connect("pressed",self,"sellItems")
	setupShop()
	setupInventorySlots()
	loadData()
	updateInventory()
	autoFixStackables()
	findMerchant()
	convertCoin()
func _physics_process(delta):
	if Engine.get_physics_frames() % 60 == 0 and visible:
		autoFixStackables()
		convertCoin()
	if Engine.get_physics_frames() % 200 == 0 and shop.visible:
		if sell_button.visible == false:
			updateCartCost()
		else:
			updateTotalSellGain()
			
		
	if Input.is_action_just_pressed("Inventory"):
		if player.is_writing == false:
			visible = !visible
			updateInventory()
			autoFixStackables()
	if visible == true:
		if Input.is_action_just_pressed("craft"):
			craft_control.visible = !craft_control.visible
	else:
		craft_control.visible = false
			
	if Input.is_action_just_pressed("interract"):
		$"../Equipment".visible = false
		if player.is_writing == false:
			if !isMerchantNearby():
				player.equipment.hide()
				restoreBrokerItems()
				clearCart()
				shop.hide()
				current_merchant_type=""
				return

		var merchant_type=findMerchant()

		if sell_button.visible:
			if current_merchant_type!="broker":
				for slot in shop_grid.get_children():
					slot.get_node("Slot").texture=null
					slot.set_meta("quantity",1)
					slot.get_node("Quantity").text=""
				current_merchant_type="broker"
			shop.visible=!shop.visible
			return

		if current_merchant_type!=merchant_type:
			restoreBrokerItems()
			clearCart()
			current_merchant_type=merchant_type
			loadMerchandising()

		shop.visible=!shop.visible

func isMerchantNearby()->bool:
	for body in area_detect_merchant.get_overlapping_bodies():
		if body.is_in_group("Merchant"):
			return true
	return false


func clearCart()->void:
	for cart_slot in shopping_cart_grid.get_children():
		cart_slot.get_node("Slot").texture = null
		cart_slot.set_meta("quantity",1)
		cart_slot.get_node("Quantity").text = ""
	updateCartCost()



func findMerchant()->String:
	sell_button.visible = false
	buy_button.visible = true
	shopping_cart_grid.visible = true


	for body in area_detect_merchant.get_overlapping_bodies():
		if !body.is_in_group("Merchant"):
			continue

		if body.is_in_group("broker") or body.is_in_group("Broker"):
			sell_button.visible = true
			buy_button.visible = false
			shopping_cart_grid.visible = false
			return ""

		for merchant_type in Items.merchant_inventories.keys():
			if body.is_in_group(merchant_type):
				return merchant_type

		return "generic"

	return ""


func restoreBrokerItems()->void:
	if buy_button.visible:return

	var item_sources=[Items.resources,Items.weapons,Items.armors,Items.flasks,Items.food,Items.necklaces,Items.rings]

	for shop_slot in shop_grid.get_children():
		var slot_icon=shop_slot.get_node("Slot").texture
		if !slot_icon:continue

		var slot_quantity=int(shop_slot.get_meta("quantity",1))
		var matched_item=null

		for source in item_sources:
			for item_data in source.values():
				if sameIcon(item_data["icon"],slot_icon):
					matched_item=item_data.duplicate()
					matched_item["icon"]=load(matched_item["icon"])
					break
			if matched_item:break

		if !matched_item:continue

		if "type" in matched_item or "scene" in matched_item or "carry" in matched_item:
			for amount in range(slot_quantity):
				CommonBehaviours.addNotStackableItem(inventory_grid,matched_item,floating_text_parent)
		else:
			CommonBehaviours.addStackableItem(inventory_grid,matched_item,floating_text_parent,slot_quantity)

		shop_slot.get_node("Slot").texture=null
		shop_slot.set_meta("quantity",1)
		var quantity_label=shop_slot.get_node_or_null("Quantity")
		if quantity_label:quantity_label.text=""
		
		
var current_merchant_type := ""
func loadMerchandising()->void:
	var items=Items.merchant_inventories.get(current_merchant_type,[])

	for slot in shop_grid.get_children():
		slot.get_node("Slot").texture=null

	var index=0
	for item in items:
		if index>=shop_grid.get_child_count():break
		var slot=shop_grid.get_child(index)
		slot.get_node("Slot").texture=load(item["icon"]) if item["icon"] is String else item["icon"]
		index+=1
		
var coins = 10257155


onready var coins_copper_label:Label= $MoneyGrid/CoinsCopperLabel
onready var coins_silver_label:Label= $MoneyGrid/CoinsSilverLabel
onready var coins_gold_label:Label= $MoneyGrid/CoinsGoldLabel
onready var coins_rho_label:Label= $MoneyGrid/CoinsRhoLabel

const COPPER_PER_SILVER=100
const SILVER_PER_GOLD=5000
const GOLD_PER_RHODIUM=5000

func convertCoin()->void:
	var copper=coins%COPPER_PER_SILVER
	var silver_total=coins/COPPER_PER_SILVER
	var silver=silver_total%SILVER_PER_GOLD
	var gold_total=silver_total/SILVER_PER_GOLD
	var gold=gold_total%GOLD_PER_RHODIUM
	var rhodium=gold_total/GOLD_PER_RHODIUM

	coins_copper_label.text=str(copper)
	coins_silver_label.text=str(silver)
	coins_gold_label.text=str(gold)
	coins_rho_label.text=str(rhodium)
	
	
	

onready var shop_coins_copper_label:Label=$"../Shop/MoneyGrid/CoinsCopperLabel" 
onready var shop_coins_silver_label:Label=$"../Shop/MoneyGrid/CoinsSilverLabel" 
onready var shop_coins_gold_label:Label=$"../Shop/MoneyGrid/CoinsGoldLabel" 
onready var shop_coins_rho_label:Label=$"../Shop/MoneyGrid/CoinsRhoLabel" 

func updateCartCost()->void:
	var total_cost=0
	var items=Items.merchant_inventories.get(current_merchant_type,[])

	for cart_slot in shopping_cart_grid.get_children():
		var texture=cart_slot.get_node("Slot").texture
		if !texture:continue

		var quantity=int(cart_slot.get_meta("quantity",1))
		for item in items:
			if sameIcon(item["icon"],texture):
				total_cost+=int(item.get("price",0))*quantity
				break

	var copper=total_cost%COPPER_PER_SILVER
	var silver_total=total_cost/COPPER_PER_SILVER
	var silver=silver_total%SILVER_PER_GOLD
	var gold_total=silver_total/SILVER_PER_GOLD
	var gold=gold_total%GOLD_PER_RHODIUM
	var rhodium=gold_total/GOLD_PER_RHODIUM

	shop_coins_copper_label.text=str(copper)
	shop_coins_silver_label.text=str(silver)
	shop_coins_gold_label.text=str(gold)
	shop_coins_rho_label.text=str(rhodium)

func shopPressed(index):
	var slot=shop_grid.get_child(index)
	var texture=slot.get_node("Slot").texture
	if !texture:return

	if sell_button.visible and !buy_button.visible:
		var quantity=int(slot.get_meta("quantity",1))
		var item=null

		for source in Items.categories:
			for item_data in source.values():
				if sameIcon(item_data["icon"],texture):
					item=item_data.duplicate()
					item["icon"]=load(item["icon"]) if item["icon"] is String else item["icon"]
					break
			if item:break

		if !item:return

		if "type" in item or "scene" in item or "carry" in item:
			for amount in range(quantity):
				CommonBehaviours.addNotStackableItem(inventory_grid,item,floating_text_parent)
		else:
			CommonBehaviours.addStackableItem(inventory_grid,item,floating_text_parent,quantity)

		slot.get_node("Slot").texture=null
		slot.set_meta("quantity",1)
		slot.get_node("Quantity").text=""
		updateInventory()
		updateTotalSellGain()
		convertCoin()
		return

	var items=Items.merchant_inventories.get(current_merchant_type,[])

	for item in items:
		if !sameIcon(item["icon"],texture):continue

		var stackable=!item.has("type") and !item.has("scene") and !item.has("carry")
		var add_amount=30 if stackable and Input.is_key_pressed(KEY_SHIFT) else 1

		if !stackable:
			for cart_slot in shopping_cart_grid.get_children():
				if cart_slot.get_node("Slot").texture==null:
					cart_slot.get_node("Slot").texture=texture
					cart_slot.set_meta("quantity",1)
					cart_slot.get_node("Quantity").text=""
					updateCartCost()
					return
			return

		for cart_slot in shopping_cart_grid.get_children():
			if sameIcon(cart_slot.get_node("Slot").texture,texture):
				var quantity2=int(cart_slot.get_meta("quantity",1))+add_amount
				cart_slot.set_meta("quantity",quantity2)
				cart_slot.get_node("Quantity").text=str(quantity2) if quantity2>1 else ""
				updateCartCost()
				return

		for cart_slot in shopping_cart_grid.get_children():
			if cart_slot.get_node("Slot").texture==null:
				cart_slot.get_node("Slot").texture=texture
				cart_slot.set_meta("quantity",add_amount)
				cart_slot.get_node("Quantity").text=str(add_amount) if add_amount>1 else ""
				updateCartCost()
				return

		break
		
	
func buyItemsFromCart()->void:
	var items=Items.merchant_inventories.get(current_merchant_type,[])
	var free_slots=0
	var stackable_counts={}

	for inv_slot in inventory_grid.get_children():
		var inv_tex=inv_slot.get_node("Slot").texture
		if inv_tex==null:
			free_slots+=1
		else:
			stackable_counts[inv_tex]=true

	var slots_left=free_slots
	var cart_cost=0

	for cart_slot in shopping_cart_grid.get_children():
		var texture=cart_slot.get_node("Slot").texture
		if !texture:continue

		var quantity=int(cart_slot.get_meta("quantity",1))
		for item in items:
			if sameIcon(item["icon"],texture):
				cart_cost+=int(item.get("price",0))*quantity
				break

	if cart_cost>coins:return

	for cart_slot in shopping_cart_grid.get_children():
		var texture=cart_slot.get_node("Slot").texture
		if !texture:continue

		var quantity=int(cart_slot.get_meta("quantity",1))
		var item=null

		for merchant_item in items:
			if sameIcon(merchant_item["icon"],texture):
				item=merchant_item.duplicate()
				item["icon"]=load(item["icon"]) if item["icon"] is String else item["icon"]
				break

		if !item:continue

		var stackable=!item.has("type") and !item.has("scene") and !item.has("carry")
		var has_stack=stackable and stackable_counts.has(texture)

		if stackable:
			if slots_left<=0 and !has_stack:continue

			CommonBehaviours.addStackableItem(inventory_grid,item,floating_text_parent,quantity)

			if !has_stack:
				slots_left-=1
				stackable_counts[texture]=true

			cart_slot.get_node("Slot").texture=null
			cart_slot.set_meta("quantity",1)
			cart_slot.get_node("Quantity").text=""

		else:
			if slots_left<=0:continue

			var can_buy=min(quantity,slots_left)

			for amount in range(can_buy):
				CommonBehaviours.addNotStackableItem(inventory_grid,item,floating_text_parent)
			slots_left-=can_buy
			var left_quantity=quantity-can_buy
			if left_quantity>0:
				cart_slot.set_meta("quantity",left_quantity)
				cart_slot.get_node("Quantity").text=str(left_quantity)
			else:
				cart_slot.get_node("Slot").texture=null
				cart_slot.set_meta("quantity",1)
				cart_slot.get_node("Quantity").text=""

	coins-=cart_cost
	updateInventory()
	convertCoin()
func getItemByIcon(icon:String):
	for p in get_script().get_script_property_list():
		if p.type!=TYPE_DICTIONARY and p.type!=TYPE_ARRAY:continue
		
		var data=get(p.name)

		if typeof(data)==TYPE_DICTIONARY:
			for item in data.values():
				if typeof(item)==TYPE_DICTIONARY and item.has("icon") and sameIcon(item["icon"],icon):
					return item

				if typeof(item)==TYPE_ARRAY:
					for sub in item:
						if typeof(sub)==TYPE_DICTIONARY and sub.has("icon") and sameIcon(sub["icon"],icon):
							return sub

		elif typeof(data)==TYPE_ARRAY:
			for item in data:
				if typeof(item)==TYPE_DICTIONARY and item.has("icon") and sameIcon(item["icon"],icon):
					return item

	return null
func sellItems()->void:
	var total=0

	for shop_slot in shop_grid.get_children():
		var texture=shop_slot.get_node("Slot").texture
		if !texture:continue

		var quantity=int(shop_slot.get_meta("quantity",1))
		var item=null

		for list in Items.categories:
			for i in list.values():
				if sameIcon(i["icon"],texture):
					item=i
					break
			if item:break

		if !item:
			for merchant_items in Items.merchant_inventories.values():
				for i in merchant_items:
					if sameIcon(i["icon"],texture):
						item=i
						break
				if item:break

		if item:
			total+=max(1,int(round(float(item["price"]))))*quantity

		shop_slot.get_node("Slot").texture=null
		shop_slot.set_meta("quantity",1)
		shop_slot.get_node("Quantity").text=""

	coins+=total
	updateTotalSellGain()
	convertCoin()


func updateTotalSellGain()->void:
	var total=0

	for shop_slot in shop_grid.get_children():
		var texture=shop_slot.get_node("Slot").texture
		if !texture:continue

		var quantity=int(shop_slot.get_meta("quantity",1))
		var item=null

		for list in Items.categories:
			for i in list.values():
				if sameIcon(i["icon"],texture):
					item=i
					break
			if item:break

		if !item:
			for merchant_items in Items.merchant_inventories.values():
				for i in merchant_items:
					if sameIcon(i["icon"],texture):
						item=i
						break
				if item:break

		if item:
			total+=int(round(max(1,float(item["price"])*0.8)))*quantity

	var copper=total%100
	var silver_total=int(total/100)
	var silver=silver_total%5000
	var gold_total=int(silver_total/5000)
	var gold=gold_total%5000
	var rhodium=int(gold_total/5000)

	shop_coins_copper_label.text=str(copper)
	shop_coins_silver_label.text=str(silver)
	shop_coins_gold_label.text=str(gold)
	shop_coins_rho_label.text=str(rhodium)

func cartItemPressed(index)->void:
	var slot = shopping_cart_grid.get_child(index)
	slot.get_node("Slot").texture = null
	slot.set_meta("quantity",1)
	slot.get_node("Quantity").text = ""
	updateCartCost()

	
func setupShop():
	var original_buy_slot = $"../Shop/ScrollContainer/GridContainer/ShopSlotHolder"
	var original_sell_slot = $"../Shop/ScrollContainer2/GridContainer/ShopSlotHolder"
	for i in range(shop_grid.get_child_count(),30):
		var new_slot = original_buy_slot.duplicate()
		new_slot.name = "BuySlot"+str(i)
		new_slot.get_node("Slot").texture = null
		shop_grid.add_child(new_slot)

	for i in range(shopping_cart_grid.get_child_count(),30):
		var new_slot = original_sell_slot.duplicate()
		new_slot.name = "SellSlot"+str(i)
		new_slot.get_node("Slot").texture = null
		shopping_cart_grid.add_child(new_slot)

	for child in shop_grid.get_children():
		var index = int(child.name.replace("BuySlot",""))
		if !child.is_connected("pressed",self,"shopPressed"): child.connect("pressed",self,"shopPressed",[index])
	for child in shopping_cart_grid.get_children():
		var index = int(child.name.replace("SellSlot",""))
		if !child.is_connected("pressed",self,"cartItemPressed"): child.connect("pressed",self,"cartItemPressed",[index])

	
	
	
	
	
	
func setupInventorySlots():
	var original_slot = inventory_grid.get_child(0)

	for i in range(inventory_grid.get_child_count(),max_inventory_slots):
		var new_slot = original_slot.duplicate()

		new_slot.name = "InventorySlot" + str(i)
		new_slot.quantity = 0
		new_slot.get_node("Slot").texture = null

		inventory_grid.add_child(new_slot)
	
	for child in inventory_grid.get_children():
		var index_str = child.get_name().replace("InventorySlot","")
		var index = int(index_str)
		if !child.is_connected("gui_input",self,"inventorySlotInput"):
			child.connect("gui_input",self,"inventorySlotInput",[index])
		if !child.is_connected("pressed",self,"inventorySlotPressed"):
			child.connect("pressed",self,"inventorySlotPressed",[index])

		if !child.is_connected("mouse_entered",self,"_on_inventory_slot_mouse_entered"):
			child.connect("mouse_entered",self,"_on_inventory_slot_mouse_entered",[index])

		if !child.is_connected("mouse_exited",self,"_on_inventory_slot_mouse_exited"):
			child.connect("mouse_exited",self,"_on_inventory_slot_mouse_exited",[index])

	
	

func inventorySlotPressed(index):
	var current_time = OS.get_ticks_msec() / 1000.0
	var alt_pressed = Input.is_action_pressed("ui_alt") or Input.is_key_pressed(KEY_ALT)

	if shop.visible and sell_button.visible and !buy_button.visible:
		var inventory_slot = inventory_grid.get_node("InventorySlot"+str(index))
		var inventory_icon = inventory_slot.get_node("Slot")
		if inventory_icon.texture:
			var move_quantity = 1
			if Input.is_key_pressed(KEY_CONTROL):
				move_quantity = inventory_slot.quantity
			elif Input.is_key_pressed(KEY_SHIFT):
				move_quantity = min(10,inventory_slot.quantity)

			for shop_slot in shop_grid.get_children():
				var shop_icon = shop_slot.get_node("Slot")
				if shop_icon.texture == inventory_icon.texture:
					var quantity = shop_slot.get_meta("quantity",1)+move_quantity
					shop_slot.set_meta("quantity",quantity)
					shop_slot.get_node("Quantity").text = str(quantity) if quantity > 1 else ""
					inventory_slot.quantity -= move_quantity
					if inventory_slot.quantity <= 0:
						inventory_icon.texture = null
						inventory_slot.quantity = 0
					inventory_slot.displayQuantity()
					updateInventory()
					updateTotalSellGain()
					return

			for shop_slot in shop_grid.get_children():
				var shop_icon = shop_slot.get_node("Slot")
				if shop_icon.texture == null:
					shop_icon.texture = inventory_icon.texture
					shop_slot.set_meta("quantity",move_quantity)
					shop_slot.get_node("Quantity").text = str(move_quantity) if move_quantity > 1 else ""
					inventory_slot.quantity -= move_quantity
					if inventory_slot.quantity <= 0:
						inventory_icon.texture = null
						inventory_slot.quantity = 0
					inventory_slot.displayQuantity()
					updateInventory()
					updateTotalSellGain()
					return

	if last_pressed_index == index and current_time-last_press_time <= double_press_time:
		last_pressed_index = -1
		last_press_time = 0.0
		if alt_pressed:
			clearSlot(index)
			return
		useItem(index)
		consumeItem(index)
		return

	selected_slot = inventory_grid.get_node("InventorySlot"+str(index))
	showSlotDebug(selected_slot)
	last_pressed_index = index
	last_press_time = current_time
	updateInventory()

	if Input.is_key_pressed(KEY_SHIFT):
		combineSlot(index)



func inventoryCooldowns(delta):
	for key in skillbar.active_cooldowns.keys():
		var time_left=skillbar.active_cooldowns[key]-delta*0.5
		skillbar.active_cooldowns[key]=0.0 if time_left<=0.0 else time_left

	for slot in inventory_grid.get_children():
		var icon=slot.get_node("Slot")
		if !icon.texture:continue

		var key=icon.texture.resource_path
		if Items.getCooldown(key)<=0.0:continue


onready var tween = $Tween
var cooldowns = {}
var flash_time={}
onready var skillbar= $"../Skillbar"

func get_cd(k):
	return skillbar.active_cooldowns[k] if skillbar.active_cooldowns.has(k) else 0.0

func set_cd(k,t):
	if t>0.0:skillbar.active_cooldowns[k]=t
func consumeItem(index):
	var slot=inventory_grid.get_node("InventorySlot"+str(index))
	var icon=slot.get_node("Slot")
	if !icon.texture:return
	var key=icon.texture.resource_path
	if get_cd(key)>0.0:return
	if !CommonBehaviours.useItem(slot,inventory_grid,stats):return
	slot.quantity-=1
	if slot.quantity<=0:
		slot.quantity=0
		icon.texture=null
	set_cd(key,Items.getCooldown(key))
	



func useItem(index):
	var slot=inventory_grid.get_node("InventorySlot"+str(index))
	var icon=slot.get_node("Slot")
	if !icon.texture:return
	
	for resource_name in Items.resources:
		var resource=Items.resources[resource_name]
		if sameIcon(resource["icon"],icon.texture) and resource_name=="crafting book":
			tween.stop_all()
			tween.interpolate_property(icon,"rect_scale",Vector2.ONE,Vector2(0.9,0.9),0.08,Tween.TRANS_QUAD,Tween.EASE_OUT)
			tween.interpolate_property(icon,"rect_scale",Vector2(0.9,0.9),Vector2.ONE,0.08,Tween.TRANS_QUAD,Tween.EASE_IN,0.08)
			tween.start()

			var recipes_book:Control=$"../Crafting/RecipeeBook"
			player.crafting.visible=true
			recipes_book.visible=!recipes_book.visible
			return
	
	
	for ring_name in Items.rings:
		var ring=Items.rings[ring_name]
		if !sameIcon(ring["icon"],icon.texture):
			continue

		for ring_index in range(1,8):
			var ring_slot=get_node_or_null("../Equipment/Ring"+str(ring_index))
			if !ring_slot:
				continue

			var ring_icon=ring_slot.get_node_or_null("Slot")
			if !ring_icon:
				continue

			if ring_icon.texture==null:
				ring_icon.texture=icon.texture
				icon.texture=null
				slot.quantity=0
				slot.displayQuantity()
				return

		return

	for necklace_name in Items.necklaces:
		var necklace=Items.necklaces[necklace_name]
		if !sameIcon(necklace["icon"],icon.texture):
			continue

		var necklace_slot=get_node_or_null("../Equipment/Necklace")
		if !necklace_slot:
			return

		var necklace_icon=necklace_slot.get_node_or_null("Slot")
		if !necklace_icon:
			return

		var previous_texture=necklace_icon.texture
		necklace_icon.texture=icon.texture
		icon.texture=null
		slot.quantity=0
		slot.displayQuantity()

		if previous_texture:
			for inventory_slot in inventory_grid.get_children():
				var inventory_icon=inventory_slot.get_node("Slot")
				if inventory_icon.texture==null:
					inventory_icon.texture=previous_texture
					inventory_slot.quantity=1
					inventory_slot.displayQuantity()
					break
		return
	for armor_name in Items.armors:
		var armor=Items.armors[armor_name]
		if !sameIcon(armor["icon"],icon.texture):continue

		var equipment_slot=null
		if armor["type"]=="torso":
			equipment_slot=$"../Equipment/Torso"
		elif armor["type"]=="hands":
			equipment_slot=$"../Equipment/Hands"
		elif armor["type"]=="feet":
			equipment_slot=$"../Equipment/Feet"

		if !is_instance_valid(equipment_slot):return

		var equipment_icon=equipment_slot.get_node("Slot")
		var previous_texture=equipment_icon.texture
		equipment_icon.texture=icon.texture
		icon.texture=null
		slot.quantity=0
		slot.displayQuantity()

		if previous_texture:
			for inventory_slot in inventory_grid.get_children():
				var inventory_icon=inventory_slot.get_node("Slot")
				if inventory_icon.texture==null:
					inventory_icon.texture=previous_texture
					inventory_slot.quantity=1
					inventory_slot.displayQuantity()
					break
		return
	
	if player.current_skill!="mine" and player.current_skill!="chop" and player.current_skill!="gather":
		for weapon_name in Items.weapons:
			var weapon=Items.weapons[weapon_name]
			if !sameIcon(weapon["icon"],icon.texture):continue

			var main_icon=$"../Equipment/MainHand/Slot"
			var off_icon=$"../Equipment/OffHand/Slot"
			var carry=str(weapon.get("carry",""))
			var previous_texture=null
			var previous_off_texture=null

			if carry=="back up" or carry=="back low":
				previous_texture=main_icon.texture
				previous_off_texture=off_icon.texture
				main_icon.texture=icon.texture
				off_icon.texture=null
			elif carry=="carry" or carry=="hips inverted" or carry=="hips":
				var equipped_main_weapon=null

				for equipped_weapon_name in Items.weapons:
					var equipped_weapon=Items.weapons[equipped_weapon_name]
					if sameIcon(equipped_weapon["icon"],main_icon.texture):
						equipped_main_weapon=equipped_weapon
						break

				if equipped_main_weapon and (equipped_main_weapon.get("carry","")=="back up" or equipped_main_weapon.get("carry","")=="back low"):
					previous_texture=main_icon.texture
					main_icon.texture=icon.texture
				elif main_icon.texture==null:
					main_icon.texture=icon.texture
				else:
					previous_texture=off_icon.texture
					off_icon.texture=icon.texture

			elif carry=="shield":
				if main_icon.texture==null:return

				for equipped_weapon_name in Items.weapons:
					var equipped_weapon=Items.weapons[equipped_weapon_name]
					if sameIcon(equipped_weapon["icon"],main_icon.texture):
						var equipped_carry=str(equipped_weapon.get("carry",""))
						if equipped_carry=="back up" or equipped_carry=="back low":
							return
						break

				previous_texture=off_icon.texture
				off_icon.texture=icon.texture
			else:
				return

			icon.texture=null
			slot.quantity=0
			slot.displayQuantity()

			for texture in [previous_texture,previous_off_texture]:
				if !texture:continue
				for inventory_slot in inventory_grid.get_children():
					var inventory_icon=inventory_slot.get_node("Slot")
					if inventory_icon.texture==null:
						inventory_icon.texture=texture
						inventory_slot.quantity=1
						inventory_slot.displayQuantity()
						break
			return







func inventorySlotInput(event,index):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_RIGHT and Input.is_key_pressed(KEY_SHIFT):
			splitSlot(index)


func splitSlot(index):
	var slot=inventory_grid.get_node("InventorySlot"+str(index))
	var icon=slot.get_node("Slot")

	if icon.texture==null or slot.quantity<2:
		return

	var split_amount=int(slot.quantity/2)

	for child in inventory_grid.get_children():
		if child==slot:
			continue

		var cicon=child.get_node("Slot")

		if cicon.texture==null:
			cicon.texture=icon.texture
			child.quantity=split_amount
			child.stackable=slot.stackable
			child.max_quantity=slot.max_quantity

			slot.quantity-=split_amount

			slot.displayQuantity()
			child.displayQuantity()
			updateInventory()
			return




func combineSlot(index):
	var slot=inventory_grid.get_node("InventorySlot"+str(index))
	var icon=slot.get_node("Slot")

	if icon.texture==null or !slot.stackable:
		return

	for child in inventory_grid.get_children():
		if child==slot:
			continue

		var cicon=child.get_node("Slot")

		if cicon.texture==icon.texture and child.stackable:
			slot.quantity+=child.quantity
			child.quantity=0
			cicon.texture=null

			child.displayQuantity()

	slot.displayQuantity()
	updateInventory()

func autoFixStackables()->void:
	for slot in inventory_grid.get_children():
		var texture=slot.get_node("Slot").texture
		if !texture:
			continue

		var item=getItemByIcon(texture.resource_path)

		if !item:
			continue

		var is_stackable=true

		if item.has("type") or item.has("scene") or item.has("carry"):
			is_stackable=false

		if isArmor(texture):
			is_stackable=false

		for weapon_name in Items.weapons:
			if sameIcon(Items.weapons[weapon_name]["icon"],texture):
				is_stackable=false
				break

		slot.stackable=is_stackable

		if !is_stackable:
			if slot.quantity != 1:
				slot.quantity=1
		else:
			if slot.quantity<=0:
				slot.quantity=1

		slot.displayQuantity()	
			
			
func isArmor(texture)->bool:
	for key in Items.armors:
		if sameIcon(Items.armors[key]["icon"],texture):
			return true
	for key in Items.rings:
		if sameIcon(Items.rings[key]["icon"],texture):
			return true
	for key in Items.necklaces:
		if sameIcon(Items.necklaces[key]["icon"],texture):
			return true
	return false



func switchDefensiveStanceWeapons() -> void:
	var main_slot = $"../Equipment/MainHand/Slot"
	var off_slot = $"../Equipment/OffHand/Slot"

	var current_weapon = null
	if main_slot.texture:
		for weapon_name in Items.weapons:
			var weapon = Items.weapons[weapon_name]
			if sameIcon(weapon["icon"],main_slot.texture):
				current_weapon = weapon
				break

	var using_two_handed = false
	if current_weapon:
		var carry = str(current_weapon.get("carry", ""))
		using_two_handed = carry == "back up" or carry == "back low"

	if using_two_handed:
		var one_handed_slot = null
		var offhand_slot = null

		for inventory_slot in inventory_grid.get_children():
			var inventory_icon = inventory_slot.get_node("Slot")
			if !inventory_icon.texture:
				continue

			for weapon_name in Items.weapons:
				var weapon = Items.weapons[weapon_name]
				if !sameIcon(weapon["icon"],inventory_icon.texture):
					continue

				var carry = str(weapon.get("carry", ""))
				if carry != "shield" and carry != "back up" and carry != "back low":
					one_handed_slot = inventory_slot
					break
			if one_handed_slot:
				break

		if !one_handed_slot:
			return

		for inventory_slot in inventory_grid.get_children():
			if inventory_slot == one_handed_slot:
				continue

			var inventory_icon = inventory_slot.get_node("Slot")
			if !inventory_icon.texture:
				continue

			for weapon_name in Items.weapons:
				var weapon = Items.weapons[weapon_name]
				if !sameIcon(weapon["icon"],inventory_icon.texture):
					continue
				if str(weapon.get("carry", "")) == "shield":
					offhand_slot = inventory_slot
					break
			if offhand_slot:
				break

		if !offhand_slot:
			for inventory_slot in inventory_grid.get_children():
				if inventory_slot == one_handed_slot:
					continue

				var inventory_icon = inventory_slot.get_node("Slot")
				if !inventory_icon.texture:
					continue

				for weapon_name in Items.weapons:
					var weapon = Items.weapons[weapon_name]
					if !sameIcon(weapon["icon"],inventory_icon.texture):
						continue

					var carry = str(weapon.get("carry", ""))
					if carry != "shield" and carry != "back up" and carry != "back low":
						offhand_slot = inventory_slot
						break
				if offhand_slot:
					break

		var previous_main = main_slot.texture
		var previous_off = off_slot.texture

		main_slot.texture = one_handed_slot.get_node("Slot").texture
		one_handed_slot.get_node("Slot").texture = null
		one_handed_slot.quantity = 0
		one_handed_slot.displayQuantity()

		if offhand_slot:
			off_slot.texture = offhand_slot.get_node("Slot").texture
			offhand_slot.get_node("Slot").texture = null
			offhand_slot.quantity = 0
			offhand_slot.displayQuantity()
		else:
			off_slot.texture = null

		for texture in [previous_main, previous_off]:
			if !texture:
				continue
			for inventory_slot in inventory_grid.get_children():
				var inventory_icon = inventory_slot.get_node("Slot")
				if inventory_icon.texture == null:
					inventory_icon.texture = texture
					inventory_slot.quantity = 1
					inventory_slot.displayQuantity()
					break
	else:
		var two_handed_slot = null

		for inventory_slot in inventory_grid.get_children():
			var inventory_icon = inventory_slot.get_node("Slot")
			if !inventory_icon.texture:
				continue

			for weapon_name in Items.weapons:
				var weapon = Items.weapons[weapon_name]
				if !sameIcon(weapon["icon"],inventory_icon.texture):continue

				var carry = str(weapon.get("carry", ""))
				if carry == "back up" or carry == "back low":
					two_handed_slot = inventory_slot
					break
			if two_handed_slot:
				break

		if !two_handed_slot:
			return

		var previous_main = main_slot.texture
		var previous_off = off_slot.texture

		main_slot.texture = two_handed_slot.get_node("Slot").texture
		off_slot.texture = null

		two_handed_slot.get_node("Slot").texture = null
		two_handed_slot.quantity = 0
		two_handed_slot.displayQuantity()

		for texture in [previous_main, previous_off]:
			if !texture:
				continue
			for inventory_slot in inventory_grid.get_children():
				var inventory_icon = inventory_slot.get_node("Slot")
				if inventory_icon.texture == null:
					inventory_icon.texture = texture
					inventory_slot.quantity = 1
					inventory_slot.displayQuantity()
					break






func clearSlot(index):
	var button = inventory_grid.get_node("InventorySlot" + str(index))
	var slot = button.get_node("Slot")

	button.quantity = 0
	slot.texture = null

	button.displayQuantity()
	updateInventory()
	
	
	
var combine_mode := 0 # 0=selected, 1=all
func combinePressed()->void:
	if combine_mode == 0:
		combineSelectedSlot()
	else:
		combine()

	combine_mode = (combine_mode + 1) % 2
func combine()->void:
	var slots=inventory_grid.get_children()

	for i in range(slots.size()):
		var slot_a=slots[i]
		var texture_a=slot_a.get_node("Slot").texture
		if !texture_a:
			continue

		var path_a=""
		if texture_a is Texture:
			path_a=texture_a.resource_path
		else:
			path_a=str(texture_a)

		var weapon_a=false
		for key in Items.weapons:
			var icon=Items.weapons[key]["icon"]
			var path=""
			if icon is Texture:
				path=icon.resource_path
			else:
				path=str(icon)
			if path_a==path:
				weapon_a=true
				break

		if isArmor(texture_a) or weapon_a:
			continue

		for j in range(i+1,slots.size()):
			var slot_b=slots[j]
			var texture_b=slot_b.get_node("Slot").texture
			if !texture_b:
				continue

			var path_b=""
			if texture_b is Texture:
				path_b=texture_b.resource_path
			else:
				path_b=str(texture_b)

			var weapon_b=false
			for key in Items.weapons:
				var icon=Items.weapons[key]["icon"]
				var path=""
				if icon is Texture:
					path=icon.resource_path
				else:
					path=str(icon)
				if path_b==path:
					weapon_b=true
					break

			if isArmor(texture_b) or weapon_b:
				continue

			if path_a!=path_b:
				continue

			var max_quantity=max(slot_a.max_quantity,9999999999)
			var space_left=max_quantity-slot_a.quantity
			if space_left<=0:
				break

			var amount_to_move=min(space_left,slot_b.quantity)
			slot_a.stackable=true
			slot_b.stackable=true
			slot_a.quantity+=amount_to_move
			slot_b.quantity-=amount_to_move

			if slot_b.quantity<=0:
				slot_b.quantity=0
				slot_b.get_node("Slot").texture=null

			slot_a.displayQuantity()
			slot_b.displayQuantity()

	updateInventory()



var selected_slot:TextureButton = null
onready var debug:Label = $Selected

func splitSelectedSlot()->void:
	if selected_slot:
		splitSlot(int(selected_slot.name.replace("InventorySlot","")))

func combineSelectedSlot()->void:
	if selected_slot:
		combineSlot(int(selected_slot.name.replace("InventorySlot","")))
func orderSlots() -> void:
	var slots_with_texture = []
	var slots_without_texture = []
	# Separate slots based on their icon texture
	for child in inventory_grid.get_children():
		var icon_texture = child.get_node("Slot").texture
		if icon_texture != null:
			slots_with_texture.append(child)
		else:
			slots_without_texture.append(child)
	# Reorder slots so that slots with texture come first
	var ordered_slots = []
	ordered_slots += slots_with_texture
	ordered_slots += slots_without_texture
	# Reposition the slots in the inventory_grid
	for i in range(ordered_slots.size()):
		var slot = ordered_slots[i]
		inventory_grid.move_child(slot, i)
func updateInventory()->void:
	for child in inventory_grid.get_children():
		child.displayQuantity()


	
	
	
func saveData():
	var dir = Directory.new()
	var character_dir = SAVE_DIR + player.entity_name

	if !dir.dir_exists(character_dir):
		dir.make_dir_recursive(character_dir)

	var file = File.new()

	if file.open(character_dir + SAVE_FILE,File.WRITE) == OK:
		var data = {
			"visible": visible,
			"coins":coins,
			"max_inventory_slots": max_inventory_slots,
			"slots": {}
		}

		for child in inventory_grid.get_children():
			var slot = child.get_node("Slot")

			data["slots"][child.name] = {
			"texture": slot.texture.resource_path if slot.texture != null else "",
			"quantity": child.quantity,
			"stackable": child.stackable,
			"max_quantity": child.max_quantity
}

		file.store_var(data)
		file.close()

func loadData():
	var path = SAVE_DIR + player.entity_name + SAVE_FILE

	var file = File.new()

	if !file.file_exists(path):
		return

	if file.open(path,File.READ) == OK:
		var data = file.get_var()

		if data.has("visible"):
			visible = data["visible"]
		if data.has("coins"):
			coins = data["coins"]
		if data.has("max_inventory_slots"):
			max_inventory_slots = data["max_inventory_slots"]
		if data.has("slots"):
			for child in inventory_grid.get_children():
				if data["slots"].has(child.name):
					var slot = child.get_node("Slot")
					var slot_data = data["slots"][child.name]
					child.quantity = slot_data.get("quantity", 0)
					child.stackable = slot_data.get("stackable", false)
					child.max_quantity = slot_data.get("max_quantity", 9999999999)
					if slot_data["texture"] != "":
						slot.texture = load(slot_data["texture"])
					else:
						slot.texture = null
		file.close()

func collapse()->void:
	hide()
	updateInventory()

func getRandItems()->void:
	for c in inventory_grid.get_children():
		c.displayQuantity()

	var has={}
	for c in inventory_grid.get_children():
		var t=c.get_node("Slot").texture
		if t: has[t]=true

#	for w in Items.weapons.values():
#		if has.has(w["icon"]): continue
#		CommonBehaviours.addNotStackableItem(inventory_grid,w,floating_text_parent)
#		has[w["icon"]]=true
#		updateInventory()
#
#	for a in Items.armors.values():
#		if has.has(a["icon"]): continue
#		CommonBehaviours.addNotStackableItem(inventory_grid,a,floating_text_parent)
#		has[a["icon"]]=true
#		updateInventory()
#	for a in Items.rings.values():
#		if has.has(a["icon"]): continue
#		CommonBehaviours.addNotStackableItem(inventory_grid,a,floating_text_parent)
#		has[a["icon"]]=true
#		updateInventory()
#	for a in Items.necklaces.values():
#		if has.has(a["icon"]): continue
#		CommonBehaviours.addNotStackableItem(inventory_grid,a,floating_text_parent)
#		has[a["icon"]]=true
#		updateInventory()
	var fk=Items.flasks.keys()
	for i in range(20):
		CommonBehaviours.addStackableItem(inventory_grid,Items.flasks[fk[i%fk.size()]],floating_text_parent,5)
		updateInventory()
	var res=Items.resources.keys()
	for i in range(20):
		CommonBehaviours.addStackableItem(inventory_grid,Items.resources[res[i%res.size()]],floating_text_parent,500)
		updateInventory()
		
func _on_inventory_slot_mouse_entered(index):
	updateInventory()

func _on_inventory_slot_mouse_exited(index):
	updateInventory()



func showSlotDebug(slot):
	if slot == null:
		debug.text = "null slot"
		return

	var icon = slot.get_node("Slot")

	var item_name = "empty"
	var qty = slot.quantity

	if icon.texture != null:
		item_name = icon.texture.resource_path.get_file().get_basename()

	debug.text = str(slot) + " | " + item_name + " x" + str(qty)
func sameIcon(icon,texture)->bool:
	if !icon or !texture:return false
	var icon_path=icon if icon is String else icon.resource_path
	return icon_path==texture.resource_path
