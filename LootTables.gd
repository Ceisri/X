extends Node

var tables = {
	"wolf": [
		{"item": "raw_meat_1", "weight": 70},
		{"item": "bone", "weight": 30}
	],

	"boar": [
		{"item": "raw_meat_2", "weight": 60},
		{"item": "raw_meat_3", "weight": 30},
		{"item": "bone", "weight": 10}
	],

	"goat": [
		{"item": "raw_meat_4", "weight": 50},
		{"item": "bone", "weight": 50}
	]
}

func ensureLootInitialized(stats):
	if stats.loot_generated:
		return

	if !tables.has(stats.species):
		return

	for entry in tables[stats.species]:
		var roll = randi() % 100
		if roll <= entry.weight:
			stats.addItem(entry.item, 1)

	stats.markLootGenerated()
	stats.saveData()

# ----------------------------
# UI BUILD (FROM SAVED DATA)
# ----------------------------

func buildLootTable(slot_scene, grid_container, stats):

	ensureLootInitialized(stats)

	for child in grid_container.get_children():
		child.queue_free()

	for item_id in stats.loot_data.keys():
		var slot = slot_scene.duplicate()
		grid_container.add_child(slot)

		var tex = Items.food.get(item_id, null)
		if tex:
			slot.get_node("Slot").texture = tex

		slot.item_id = item_id
		slot.quantity = stats.loot_data[item_id]

		# IMPORTANT: connect removal hook
		slot.connect("taken", self, "_on_item_taken", [stats, item_id, slot])

func _on_item_taken(stats, item_id, slot):
	stats.removeItem(item_id, 1)
