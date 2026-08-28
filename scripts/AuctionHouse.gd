extends Control
#AuctionHouse.gd child of UI which is child of Player

onready var inventory = $"../Inventory"
onready var player = $"../.."

onready var close_button:TextureButton = $Close
onready var show_sell_interface_button:TextureButton = $ShowInterfaceToSellMyOwnItems

onready var items_being_sold:Control = $ItemsBeingSold
onready var items_being_sold_from_me:Control = $ItemsBeingSoldFromMe
onready var item_to_be_sold:Control = $ItemToBeSold

onready var item_to_be_sold_slot:TextureRect = $ItemToBeSold/Slot
onready var item_name_label:Label = $ItemToBeSold/ItemNameLabel
onready var place_item_button:Button = $ItemToBeSold/PlaceItemForSale
onready var price_line_edit:LineEdit = $ItemToBeSold/LineEditDecidePrice

onready var listings_grid:GridContainer = $ItemsBeingSoldFromMe/GridContainer
onready var listing_template:Control = $ItemsBeingSoldFromMe/GridContainer/AuctionHouseHolder1

onready var market_grid:GridContainer = $ItemsBeingSold/GridContainer
onready var market_template:Control = $ItemsBeingSold/GridContainer/AuctionHouseHolder1
onready var tween:Tween = $Tween

const COPPER_PER_SILVER = 100
const SILVER_PER_GOLD = 5000
const GOLD_PER_RHODIUM = 5000

export var max_listing_slots:int = 30
export var buy_request_timeout_ms:int = 6000

var current_listing_price:int = 0
var last_seen_texture:Texture = null

var my_seller_slots := {}      # listing_id -> $ItemsBeingSoldFromMe holder
var market_slots := {}         # listing_id -> $ItemsBeingSold holder
var pending_buys := {}         # listing_id -> amount, while waiting on a server reply
var pending_buy_started_at := {}


func _ready():
	hide()
	items_being_sold.show()
	items_being_sold_from_me.hide()
	item_to_be_sold.hide()
	item_name_label.text = ""

	listings_grid.remove_child(listing_template)
	market_grid.remove_child(market_template)

	if !player.has_method("isLocalPlayer") or !player.isLocalPlayer():
		return # puppet copy of another player -- this window is never
			   # opened for a character we don't control, so it stays inert.

	close_button.connect("pressed", self, "_on_close_pressed")
	show_sell_interface_button.connect("pressed", self, "switchFromBuyingToSelling")
	place_item_button.connect("pressed", self, "placeItemforSale")
	price_line_edit.connect("text_changed", self, "priceInput")

	AuctionHouseData.connect("listing_added", self, "onListingAdded")
	AuctionHouseData.connect("listing_quantity_changed", self, "onListingQuantityChanged")
	AuctionHouseData.connect("listing_removed", self, "onListingRemoved")
	AuctionHouseData.connect("buy_result", self, "onBuyResult")
	AuctionHouseData.connect("sale_proceeds_received", self, "onSaleProceedsReceived")
	AuctionHouseData.connect("retrieve_confirmed", self, "onRetrieveConfirmed")

	displayPrice(item_to_be_sold, 0)

	# Pick up anything AuctionHouseData already knows about (e.g. catch-up
	# arrived, or listings existed before this UI connected its signals).
	for listing_id in AuctionHouseData.listings.keys():
		onListingAdded(listing_id, AuctionHouseData.listings[listing_id])


func _physics_process(delta):
	if player.movement_mode != "idle":
		hide()
	updateItemToBeSoldLabel()
	if visible:
		item_to_be_sold.displayQuantity()
	checkPendingBuyTimeouts()

func checkPendingBuyTimeouts() -> void:
	if pending_buys.empty():
		return
	var now = OS.get_ticks_msec()
	for listing_id in pending_buys.keys():
		if now - pending_buy_started_at.get(listing_id, now) > buy_request_timeout_ms:
			pending_buys.erase(listing_id)
			pending_buy_started_at.erase(listing_id)
			var market_slot = market_slots.get(listing_id, null)
			if is_instance_valid(market_slot):
				setBuyButtonsDisabled(market_slot, false)


func _on_close_pressed() -> void:
	hide()

func switchFromBuyingToSelling() -> void:
	var opening = !items_being_sold_from_me.visible
	items_being_sold.visible = !opening
	items_being_sold_from_me.visible = opening
	item_to_be_sold.visible = opening

func updateItemToBeSoldLabel() -> void:
	if !is_instance_valid(item_to_be_sold_slot):
		return
	var texture = item_to_be_sold_slot.texture
	if texture == last_seen_texture:
		return
	last_seen_texture = texture
	item_name_label.text = getItemNameFromTexture(texture) if texture != null else ""

func getItemNameFromTexture(texture:Texture) -> String:
	if texture == null:
		return ""
	for category in Global.categories:
		for item_name in category:
			var item = category[item_name]
			if item.has("icon") and sameIcon(item["icon"], texture):
				return item_name
	return texture.resource_path.get_file().get_basename()

func getItemDataFromTexture(texture:Texture):
	if texture == null:
		return null
	for category in Global.categories:
		for item_name in category:
			var item = category[item_name]
			if item.has("icon") and sameIcon(item["icon"], texture):
				var data = item.duplicate()
				data["icon"] = load(data["icon"]) if data["icon"] is String else data["icon"]
				return data
	return null

func sameIcon(icon, texture:Texture) -> bool:
	if !icon or !texture:
		return false
	var icon_path = icon if icon is String else icon.resource_path
	return icon_path == texture.resource_path

func priceInput(new_text:String) -> void:
	current_listing_price = int(new_text) if new_text.is_valid_integer() else 0
	displayPrice(item_to_be_sold, current_listing_price)

func flashPriceFieldRed() -> void:
	tween.stop_all()
	tween.interpolate_property(price_line_edit, "modulate", Color(1,1,1,1), Color(1,0,0,1), 0.15, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(price_line_edit, "modulate", Color(1,0,0,1), Color(1,1,1,1), 0.15, Tween.TRANS_QUAD, Tween.EASE_IN, 0.15)
	tween.start()

func updateQuantityLabel(button:Control, quantity:int) -> void:
	var quantity_label = button.get_node_or_null("Quantity")
	if quantity_label:
		quantity_label.text = str(quantity) if quantity > 1 else ""


func placeItemforSale() -> void:
	if !is_instance_valid(item_to_be_sold_slot) or item_to_be_sold_slot.texture == null:
		return

	if current_listing_price <= 0:
		flashPriceFieldRed()
		return

	if listings_grid.get_child_count() >= max_listing_slots:
		return

	var texture = item_to_be_sold_slot.texture
	var item_name = getItemNameFromTexture(texture)
	var quantity = int(item_to_be_sold.quantity) if "quantity" in item_to_be_sold else 1
	if quantity <= 0:
		quantity = 1

	# Item already left the inventory on drag-drop -- SlotHolder.gd's
	# drop_data() handled that. We just ask the server to create the
	# listing; both grids get built from onListingAdded, the SAME code
	# path every client (including us) uses -- one source of truth.
	AuctionHouseData.requestPlaceListing(texture.resource_path, item_name, quantity, current_listing_price, player.entity_name)

	item_to_be_sold_slot.texture = null
	item_name_label.text = ""
	last_seen_texture = null
	price_line_edit.text = ""
	current_listing_price = 0
	displayPrice(item_to_be_sold, 0)


func isMyListing(listing:Dictionary) -> bool:
	# FIX for #3: compare against persistent entity_name, not the
	# session-only peer_id that used to break on relogin.
	return listing.get("seller_name", "") == player.entity_name


func onListingAdded(listing_id:String, listing:Dictionary) -> void:
	if market_slots.has(listing_id):
		return

	if !ResourceLoader.exists(listing["texture_path"]):
		return
	var texture = load(listing["texture_path"])
	var is_mine = isMyListing(listing)

	var market_slot = market_template.duplicate()
	market_slot.name = "AuctionHouseHolder" + str(market_grid.get_child_count() + 1)
	market_slot.set_meta("listing_id", listing_id)

	var market_button = market_slot.get_node("AuctionItemButton")
	market_button.get_node("Slot").texture = texture
	market_button.get_node("ItemNameLabel").text = listing["item_name"]
	market_button.get_node("SellerName").text = listing["seller_name"]
	updateQuantityLabel(market_button, int(listing["quantity"]))

	market_grid.add_child(market_slot)
	displayPrice(market_button, int(listing["price"]))
	market_slots[listing_id] = market_slot

	if is_mine:
		setupMarketButtonsForOwnListing(market_button, listing_id)
	else:
		setupMarketButtonsForOtherListing(market_button, listing_id, int(listing["quantity"]))

	if is_mine:
		var seller_slot = listing_template.duplicate()
		seller_slot.name = "AuctionHouseHolder" + str(listings_grid.get_child_count() + 1)
		seller_slot.set_meta("listing_id", listing_id)

		var seller_button = seller_slot.get_node("AuctionItemButton")
		seller_button.get_node("Slot").texture = texture
		seller_button.get_node("ItemNameLabel").text = listing["item_name"]
		updateQuantityLabel(seller_button, int(listing["quantity"]))

		listings_grid.add_child(seller_slot)
		displayPrice(seller_button, int(listing["price"]))
		my_seller_slots[listing_id] = seller_slot

		var seller_retrieve = seller_button.get_node_or_null("retrieve")
		if seller_retrieve and !seller_retrieve.is_connected("pressed", self, "retrievePressed"):
			seller_retrieve.connect("pressed", self, "retrievePressed", [listing_id])


func setupMarketButtonsForOwnListing(market_button:Control, listing_id:String) -> void:
	var buy_x1 = market_button.get_node_or_null("Buyx1")
	var buy_all = market_button.get_node_or_null("BuyAll")
	var buy_x10 = market_button.get_node_or_null("Buyx10")
	var retrieve = market_button.get_node_or_null("retrieve")

	if buy_x1: buy_x1.visible = false
	if buy_all: buy_all.visible = false
	if buy_x10: buy_x10.visible = false

	if retrieve:
		retrieve.visible = true
		if !retrieve.is_connected("pressed", self, "retrievePressed"):
			retrieve.connect("pressed", self, "retrievePressed", [listing_id])

func setupMarketButtonsForOtherListing(market_button:Control, listing_id:String, quantity:int) -> void:
	var buy_x1 = market_button.get_node_or_null("Buyx1")
	var buy_all = market_button.get_node_or_null("BuyAll")
	var buy_x10 = market_button.get_node_or_null("Buyx10")
	var retrieve = market_button.get_node_or_null("retrieve")

	if retrieve: retrieve.visible = false

	if buy_x1:
		buy_x1.visible = true
		if !buy_x1.is_connected("pressed", self, "buyx1Pressed"):
			buy_x1.connect("pressed", self, "buyx1Pressed", [listing_id])

	if buy_all:
		buy_all.visible = true
		if !buy_all.is_connected("pressed", self, "buyAllPressed"):
			buy_all.connect("pressed", self, "buyAllPressed", [listing_id])

	if buy_x10:
		buy_x10.visible = quantity >= 10
		if !buy_x10.is_connected("pressed", self, "buyx10Pressed"):
			buy_x10.connect("pressed", self, "buyx10Pressed", [listing_id])


func onListingQuantityChanged(listing_id:String, quantity:int) -> void:
	var market_slot = market_slots.get(listing_id, null)
	if is_instance_valid(market_slot):
		var market_button = market_slot.get_node("AuctionItemButton")
		updateQuantityLabel(market_button, quantity)
		var buy_x10 = market_button.get_node_or_null("Buyx10")
		if buy_x10:
			buy_x10.visible = quantity >= 10

	var seller_slot = my_seller_slots.get(listing_id, null)
	if is_instance_valid(seller_slot):
		updateQuantityLabel(seller_slot.get_node("AuctionItemButton"), quantity)


func onListingRemoved(listing_id:String) -> void:
	var market_slot = market_slots.get(listing_id, null)
	if is_instance_valid(market_slot):
		market_slot.queue_free()
	market_slots.erase(listing_id)

	var seller_slot = my_seller_slots.get(listing_id, null)
	if is_instance_valid(seller_slot):
		seller_slot.queue_free()
	my_seller_slots.erase(listing_id)

	pending_buys.erase(listing_id)
	pending_buy_started_at.erase(listing_id)


func setBuyButtonsDisabled(market_slot:Control, disabled:bool) -> void:
	if !is_instance_valid(market_slot):
		return
	var market_button = market_slot.get_node("AuctionItemButton")
	for button_name in ["Buyx1", "BuyAll", "Buyx10"]:
		var b = market_button.get_node_or_null(button_name)
		if b:
			b.disabled = disabled


func buyx1Pressed(listing_id:String) -> void:
	requestBuyAmount(listing_id, 1)

func buyx10Pressed(listing_id:String) -> void:
	requestBuyAmount(listing_id, 10)

func buyAllPressed(listing_id:String) -> void:
	var listing = AuctionHouseData.listings.get(listing_id, null)
	if listing == null:
		return
	requestBuyAmount(listing_id, int(listing.get("quantity", 1)))

func requestBuyAmount(listing_id:String, amount:int) -> void:
	if pending_buys.has(listing_id):
		return # already waiting on this listing -- blocks the
			   # double-click race that used to fire two conflicting
			   # requests and made buttons "sometimes just not work"

	var market_slot = market_slots.get(listing_id, null)
	if !is_instance_valid(market_slot):
		return

	var listing = AuctionHouseData.listings.get(listing_id, null)
	if listing == null:
		return

	var quantity = int(listing.get("quantity", 1))
	if amount <= 0 or amount > quantity:
		return

	var price = int(listing.get("price", 0))
	var total_cost = price * amount
	var icon = market_slot.get_node("AuctionItemButton/Slot")

	if total_cost > inventory.coins:
		flashSlotRed(icon)
		return

	if !hasInventorySpaceFor(icon.texture, amount):
		flashSlotRed(icon)
		return

	pending_buys[listing_id] = amount
	pending_buy_started_at[listing_id] = OS.get_ticks_msec()
	setBuyButtonsDisabled(market_slot, true)
	AuctionHouseData.requestBuy(listing_id, amount)


func onBuyResult(listing_id:String, success:bool, amount:int, texture_path:String, price:int, listing_removed_after:bool, authoritative_coins:int) -> void:
	if !pending_buys.has(listing_id):
		return
	pending_buys.erase(listing_id)
	pending_buy_started_at.erase(listing_id)

	var market_slot = market_slots.get(listing_id, null)

	if !success:
		if is_instance_valid(market_slot):
			setBuyButtonsDisabled(market_slot, false)
			flashSlotRed(market_slot.get_node("AuctionItemButton/Slot"))
		if authoritative_coins >= 0:
			inventory.coins = authoritative_coins
			inventory.convertCoin()
		return

	if !ResourceLoader.exists(texture_path):
		return
	var texture = load(texture_path)
	var item = getItemDataFromTexture(texture)
	if item:
		var stackable = !(item.has("type") or item.has("scene") or item.has("carry"))
		if stackable:
			Global.addStackableItem(inventory.inventory_grid, item, inventory.floating_text_parent, amount)
		else:
			for i in range(amount):
				Global.addNotStackableItem(inventory.inventory_grid, item, inventory.floating_text_parent)

	# FIX for #1: set to the server-computed post-purchase balance instead
	# of self-subtracting -- the server is now the source of truth.
	inventory.coins = authoritative_coins
	inventory.convertCoin()
	inventory.updateInventory()

	if !listing_removed_after and is_instance_valid(market_slot):
		setBuyButtonsDisabled(market_slot, false)


func onSaleProceedsReceived(amount:int, authoritative_coins:int) -> void:
	inventory.coins = authoritative_coins
	inventory.convertCoin()




func retrievePressed(listing_id:String) -> void:
	var seller_slot = my_seller_slots.get(listing_id, null)
	if !is_instance_valid(seller_slot):
		return

	var button = seller_slot.get_node("AuctionItemButton")
	var retrieve_button = button.get_node_or_null("retrieve")
	if retrieve_button and retrieve_button.disabled:
		return

	var icon = button.get_node("Slot")
	var texture = icon.texture
	if texture == null:
		return

	var listing = AuctionHouseData.listings.get(listing_id, null)
	var quantity = int(listing["quantity"]) if listing != null else 1

	if !hasInventorySpaceFor(texture, quantity):
		flashSlotRed(icon)
		return

	if retrieve_button:
		retrieve_button.disabled = true
	AuctionHouseData.requestRetrieve(listing_id)


func onRetrieveConfirmed(listing_id:String, texture_path:String, quantity:int) -> void:
	if texture_path == "":
		var seller_slot = my_seller_slots.get(listing_id, null)
		if is_instance_valid(seller_slot):
			var retrieve_button = seller_slot.get_node_or_null("AuctionItemButton/retrieve")
			if retrieve_button:
				retrieve_button.disabled = false
		return

	if !ResourceLoader.exists(texture_path):
		return
	var texture = load(texture_path)
	var item = getItemDataFromTexture(texture)
	if !item:
		return

	var stackable = !(item.has("type") or item.has("scene") or item.has("carry"))
	if stackable:
		Global.addStackableItem(inventory.inventory_grid, item, inventory.floating_text_parent, quantity)
	else:
		for i in range(quantity):
			Global.addNotStackableItem(inventory.inventory_grid, item, inventory.floating_text_parent)

	inventory.updateInventory()
	# onListingRemoved (also fired by the server's broadcast) frees the
	# seller/market holder nodes for this listing.


func hasInventorySpaceFor(texture:Texture, quantity:int) -> bool:
	var item = getItemDataFromTexture(texture)
	var stackable = item and !(item.has("type") or item.has("scene") or item.has("carry"))

	if stackable:
		for slot in inventory.inventory_grid.get_children():
			var slot_icon = slot.get_node("Slot")
			if slot_icon.texture == texture or slot_icon.texture == null:
				return true
		return false

	var free_slots = 0
	for slot in inventory.inventory_grid.get_children():
		if slot.get_node("Slot").texture == null:
			free_slots += 1
	return free_slots >= quantity


func flashSlotRed(icon:TextureRect) -> void:
	tween.stop_all()
	tween.interpolate_property(icon, "modulate", Color(1,1,1,1), Color(1,0,0,1), 0.15, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(icon, "modulate", Color(1,0,0,1), Color(1,1,1,1), 0.15, Tween.TRANS_QUAD, Tween.EASE_IN, 0.15)
	tween.start()


func displayPrice(root:Node, total:int) -> void:
	if !is_instance_valid(root):
		return
	var money_grid = root.get_node_or_null("MoneyGrid")
	if !is_instance_valid(money_grid):
		return

	var copper = total % COPPER_PER_SILVER
	var silver_total = total / COPPER_PER_SILVER
	var silver = silver_total % SILVER_PER_GOLD
	var gold_total = silver_total / SILVER_PER_GOLD
	var gold = gold_total % GOLD_PER_RHODIUM
	var rhodium = gold_total / GOLD_PER_RHODIUM

	var copper_label = money_grid.get_node_or_null("CoinsCopperLabel")
	var silver_label = money_grid.get_node_or_null("CoinsSilverLabel")
	var gold_label = money_grid.get_node_or_null("CoinsGoldLabel")
	var rho_label = money_grid.get_node_or_null("CoinsRhoLabel")

	if copper_label: copper_label.text = str(copper)
	if silver_label: silver_label.text = str(silver)
	if gold_label: gold_label.text = str(gold)
	if rho_label: rho_label.text = str(rhodium)











