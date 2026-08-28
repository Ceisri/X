extends Node2D

onready var rich_text_label: RichTextLabel = $RichTextLabel
onready var rich_text_label2: RichTextLabel = $RichTextLabel2

onready var inventory:Control = $"../Inventory"
onready var inventory_grid: GridContainer = $"../Inventory/ScrollContainer/GridContainer"
onready var loot_grid: GridContainer = $"../Loot/ScrollContainer/GridContainer"
onready var equipment: Control = $"../Equipment"
onready var enemy_skills: GridContainer = $"../CrossairInspect/GridContainer"
onready var skill_tree_root: Node = $"../SkillTreeRoot"
onready var skill_bar: GridContainer = $"../Skillbar/GridContainer"
onready var shop_grid: GridContainer =  $"../Shop/ScrollContainer/GridContainer"
onready var shop_grid2: GridContainer =   $"../Shop/ScrollContainer2/GridContainer"
var last_right_click_time = -1.0
var tooltip_expanded = false
var tooltip_item_texture = null
export var normal_tooltip_size = Vector2(380,250)
export var expanded_tooltip_size = Vector2(700,700)

var tooltip_lock := false
var tooltip_timer := 0.0

func _ignoreMouse(node):
	if node is Control:
		node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignoreMouse(child)

func _ready():
	tooltip_background.rect_size = normal_tooltip_size
	rich_text_label.rect_size = normal_tooltip_size
	rich_text_label.bbcode_enabled=true
	rich_text_label2.rect_size = normal_tooltip_size
	rich_text_label2.bbcode_enabled=true
	_ignoreMouse(self)
	hide()
var double_right_click_time:float = 1.2
func _input(event):
	if event.is_action_pressed("esc"):
		tooltip_lock = false
		tooltip_timer = 0.0
		tooltip_expanded = false
		resetTooltipSize()
		hide()
	if Input.is_action_pressed("shift"):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_RIGHT:
		var click_time = OS.get_ticks_msec() * 0.001

		if visible and rich_text_label.get_v_scroll().max_value > 0:
			if click_time - last_right_click_time < double_right_click_time:
				tooltip_expanded = !tooltip_expanded

				if tooltip_expanded:
					tooltip_background.rect_size = expanded_tooltip_size
					rich_text_label.rect_size = expanded_tooltip_size
					rich_text_label2.rect_size = expanded_tooltip_size
				else:
					resetTooltipSize()

				if !tooltip_expanded:
					updatePosition()

				last_right_click_time = -1.0
				return

			last_right_click_time = click_time

		var mouse_pos = get_viewport().get_mouse_position()

		for grid in [inventory_grid,loot_grid,equipment,enemy_skills,skill_bar,shop_grid,shop_grid2] + getVisibileSkillTrees():
			if !is_instance_valid(grid):
				continue
			if !grid.is_visible_in_tree():
				continue

			for node in _get_all_children(grid):
				if !(node is TextureRect):
					continue
				if !node.is_visible_in_tree():
					continue
				if node.texture == null:
					continue

				if _get_visible_rect(node).has_point(mouse_pos):
					if showTooltipForTexture(node.texture):
						tooltip_lock = true
						tooltip_timer = 0.0
						show()
						if !tooltip_expanded:
							updatePosition()
						return
func getVisibileSkillTrees() -> Array:
	var trees := []

	if skill_tree_root == null:
		return trees

	for child in skill_tree_root.get_children():
		if child == null:
			continue
		if !child.visible:
			continue
		if !child.name.begins_with("SkillsTreeHolder"):
			continue

		var control = child.get_node_or_null("Control")
		if control != null and control.visible:
			trees.append(control)

	return trees
	

func _get_visible_rect(control:Control)->Rect2:
	var rect=control.get_global_rect()
	var parent=control.get_parent()
	while parent:
		if parent is ScrollContainer:
			rect=rect.clip(parent.get_global_rect())
			if rect.size.x<=0 or rect.size.y<=0:
				break
		parent=parent.get_parent()
	return rect



func _is_hovering(mouse_pos: Vector2) -> bool:
	for grid in [inventory_grid,loot_grid,equipment,enemy_skills,skill_bar,shop_grid,shop_grid2,] +getVisibileSkillTrees():
		if !is_instance_valid(grid):
			continue
		if !grid.is_visible_in_tree():
			continue
		for node in _get_all_children(grid):
			if !(node is TextureRect):
				continue
			if !node.is_visible_in_tree():
				continue
			if node.texture == null:
				continue
			if _get_visible_rect(node).has_point(mouse_pos):
				return true
	return false
func getHoveredTexture(mouse_pos:Vector2):
	for grid in [inventory_grid,loot_grid,equipment,enemy_skills,skill_bar,shop_grid,shop_grid2] + getVisibileSkillTrees():
		if !is_instance_valid(grid) or !grid.is_visible_in_tree():
			continue

		for node in _get_all_children(grid):
			if node is TextureRect and node.is_visible_in_tree() and node.texture != null:
				if _get_visible_rect(node).has_point(mouse_pos):
					return node.texture

	return null
func _process(delta):
	var mouse_pos = get_viewport().get_mouse_position()
	if tooltip_lock and !tooltip_expanded:
		var hovered_texture = getHoveredTexture(mouse_pos)
		if hovered_texture != null and hovered_texture != tooltip_item_texture:
			showTooltipForTexture(hovered_texture)
			tooltip_timer = 0.0
	if tooltip_lock:
		tooltip_timer += delta

		if tooltip_timer >= 10.0 and !tooltip_expanded:
			tooltip_lock = false
			tooltip_timer = 0.0
			hide()
			return

		if !tooltip_expanded:
			if !_is_hovering(mouse_pos):
				tooltip_lock = false
				tooltip_timer = 0.0
				tooltip_item_texture = null
				hide()
				return

			updatePosition()

		return

	hide()
# Tooltip offsets: move tooltip away from cursor depending on screen quadrant
export var tooltip_left_offset:float = -530 # horizontal offset when cursor is on right side
export var tooltip_right_offset:float = 30 # horizontal offset when cursor is on left side
export var tooltip_top_offset:float = -300 # vertical offset when cursor is on bottom side
export var tooltip_bottom_offset:float = 20 # vertical offset when cursor is on top side
onready var tooltip_background:Control =  $BG

export var tooltip_overlap_offset:float = 40 # extra movement when cursor is over tooltip

func updatePosition():
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_center = get_viewport_rect().size * 0.5
	var offset = Vector2()

	offset.x = tooltip_left_offset if mouse_pos.x > screen_center.x else tooltip_right_offset
	offset.y = tooltip_top_offset if mouse_pos.y > screen_center.y else tooltip_bottom_offset

	var tooltip_rect = tooltip_background.get_global_rect()
	if tooltip_rect.has_point(mouse_pos):
		offset.x += tooltip_overlap_offset if mouse_pos.x < screen_center.x else -tooltip_overlap_offset

	position = get_canvas_transform().affine_inverse().xform(mouse_pos) + offset
func _get_all_children(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		result.append(child)
		result += _get_all_children(child)
	return result

func showTooltipForTexture(texture:Texture)->bool:
	if tooltip_item_texture!=texture:
		tooltip_item_texture=texture
		resetTooltipSize()

	
	for category in Global.categories:
		for item_name in category:
			if Global.sameIcon(category[item_name]["icon"],texture):
				displayItemLabel(item_name,category)
				return true

	for skill_name in Global.skills:
		if Global.sameIcon(Global.skills[skill_name],texture):
			displayPlayerSkillLabel(skill_name)
			return true

	return false

onready var coins_copper_label:Label= $GridContainer/CoinsCopperLabel
onready var coins_silver_label:Label= $GridContainer/CoinsSilverLabel
onready var coins_gold_label:Label= $GridContainer/CoinsGoldLabel
onready var coins_rho_label:Label= $GridContainer/CoinsRhoLabel
onready var money_grid:GridContainer = $GridContainer #original position x0 y 265

func displayItemLabel(item_name,category)->void:
	money_grid.show()

	var item = category[item_name]
	var price = int(item.get("price",0))

	var copper = price % inventory.COPPER_PER_SILVER
	var silver_total = price / inventory.COPPER_PER_SILVER
	var silver = silver_total % inventory.SILVER_PER_GOLD
	var gold_total = silver_total / inventory.SILVER_PER_GOLD
	var gold = gold_total % inventory.GOLD_PER_RHODIUM
	var rhodium = gold_total / inventory.GOLD_PER_RHODIUM

	coins_copper_label.text = str(copper)
	coins_silver_label.text = str(silver)
	coins_gold_label.text = str(gold)
	coins_rho_label.text = str(rhodium)

	var text = "[b]%s[/b]\n[i]%s[/i]\nRarity: %s"%[
		item_name.capitalize().replace("_"," "),
		item.get("description",""),
		str(item.get("rarity",0))
	]

	rich_text_label.bbcode_text = text
	rich_text_label.visible = true
	rich_text_label2.visible = false
	
	
	
	
	
func displayPlayerSkillLabel(skill_name:String) -> void:
	money_grid.hide()

	var texture = Global.skills[skill_name]
	var cooldown:float = Global.cooldowns[texture.resource_path] if Global.cooldowns.has(texture.resource_path) else 0.0
	var description = Global.descriptions.get(skill_name,"")
	var level = 0

	for tree in getVisibileSkillTrees():
		for child in tree.get_children():
			if !child.name.begins_with("SkillButton"):
				continue

			var slot = child.get_node_or_null("Slot")
			if slot == null or slot.texture == null:
				continue

			if slot.texture.resource_path == texture.resource_path:
				level = child.skill_level
				break
		if level > 0:
			break

	var damage_mult = Global.getDamageMultiplier(skill_name,max(0,level - 1))
	var damages = Global.getDamages(skill_name)

	var sections = []
	var info_text = "[b]%s[/b]\nCD: %.1fs"%[skill_name.capitalize(),cooldown]

	var energy_cost = Global.getEnergyCost(skill_name)
	if energy_cost > 0:
		info_text += " | Energy: %s"%energy_cost

	sections.append(info_text)

	if damages.size() > 0:
		var damage_text = "[b]Damage[/b]"
		for damage_type in damages:
			damage_text += "\n%s: %.1f"%[
				Global.dmg_to_string(damage_type),
				damages[damage_type] * damage_mult
			]
		sections.append(damage_text)

	if Global.cooldown_effects.has(skill_name):
		var effects = Global.cooldown_effects[skill_name]
		var effect_text = "[b]Effects[/b]"

		if effects.has("self_reset_chance"):
			effect_text += "\nSelf Reset %d%%"%int(effects.self_reset_chance * 100)

		if effects.has("reset_skills"):
			for target_skill in effects.reset_skills:
				effect_text += "\nReset %s %d%%"%[
					target_skill.capitalize(),
					int(effects.reset_skills[target_skill] * 100)
				]

		if effects.has("reduce_cooldowns"):
			for target_skill in effects.reduce_cooldowns:
				effect_text += "\n-%ss CD %.1fs"%[
					target_skill.capitalize(),
					effects.reduce_cooldowns[target_skill]
				]

		sections.append(effect_text)

	if description != "":
		sections.append("[i]%s[/i]"%description)

	sections.append("Level: %s | Mult: x%.2f"%[level,damage_mult])

	var text = ""
	if tooltip_expanded and sections.size() > 1:
		for section_index in range(sections.size()):
			text += sections[section_index]
			if section_index < sections.size() - 1:
				text += "          "
			if (section_index + 1) % 2 == 0:
				text += "\n"
	else:
		for section in sections:
			text += "\n\n%s"%section

	rich_text_label2.bbcode_text = text
	rich_text_label2.visible = true
	rich_text_label.visible = false
	
	
func resetTooltipSize()->void:
	tooltip_expanded = false
	tooltip_background.rect_size = normal_tooltip_size
	rich_text_label.rect_size = normal_tooltip_size
	rich_text_label.scroll_to_line(0)
