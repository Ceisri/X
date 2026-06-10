extends Node
# singleton called Items



func generateLootForCorpse(corpse):
	var loot = []

	var weight = corpse.stats.weight

	var bone_amount = 250
	var meat_amount = int(round(weight * 0.6))

	var meat_key = ""

	match corpse.stats.species.to_lower():
		"wolf":
			meat_key = "wolf meat"

		"goat":
			meat_key = "goat meat"

		"boar":
			meat_key = "boar meat"

		"moose":
			meat_key = "moose meat"

		_:
			meat_key = "wolf meat"

	loot.append({
		"item_key": meat_key,
		"quantity": meat_amount
	})

	loot.append({
		"item_key": "bone",
		"quantity": bone_amount
	})

	return loot







var flasks = {
	"empty": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/ProfessionAndCraftIcons/Alchemy/Alchemy_19_little_flask.png"),
		"rarity": 0.0,
		"description": "placeholder1"
	},
	"energy": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/ProfessionAndCraftIcons/Alchemy/Alchemy_20_littlemana_flask.png"),
		"rarity": 0.0,
		"description": "placeholder2"
	},
	"medicine": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/ProfessionAndCraftIcons/Alchemy/Alchemy_21_littleheal_flask.png"),
		"rarity": 0.0,
		"description": "placeholder3"
	},
	"poison": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/ProfessionAndCraftIcons/Alchemy/Alchemy_22_deadly_poison.png"),
		"rarity": 0.0,
		"description": "placeholder4"
	},
	"power": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/ProfessionAndCraftIcons/Alchemy/Alchemy_23_black_poison.png"),
		"rarity": 0.0,
		"description": "placeholder1"
	}
}

var food = {
	"boar meat": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/ProfessionAndCraftIcons/Cooking_fishing/Cooking_34_meat.png"),
		"rarity": 0.0,
		"description": "placeholder1"
	},
	"moose meat": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/ProfessionAndCraftIcons/Cooking_fishing/Cooking_27_meat.png"),
		"rarity": 0.0,
		"description": "placeholder2"
	},
	"wolf meat": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/ProfessionAndCraftIcons/Cooking_fishing/Cooking_23_meat.png"),
		"rarity": 0.0,
		"description": "placeholder3"
	},
	"goat meat": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/ProfessionAndCraftIcons/Cooking_fishing/Cooking_24_meat.png"),
		"rarity": 0.0,
		"description": "placeholder4"
	},
	"bone": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/ProfessionAndCraftIcons/Cooking_fishing/Cooking_25_bone.png"),
		"rarity": 0.0,
		"description": "placeholder1"
	}
}

var armors = {
	"torso1": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/equipment/Armor1.png"),
		"rarity": 0.0,
		"description": "Leather armor",

		"defences": {
			"slash": 15,
			"pierce": 5,
			"blunt": 2
		},

		"max_health": 10
	},

	"torso2": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/equipment/torso2_placeholder.png"),
		"rarity": 0.0,
		"description": "Plate armor",

		"defences": {
			"slash": 30,
			"pierce": 20,
			"blunt": 10
		},

		"max_health": 20
	},

	"hands1": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/equipment/hand1_placeholder.png"),
		"rarity": 0.0,
		"description": "Leather gloves",

		"defences": {
			"slash": 4,
			"pierce": 2,
			"blunt": 1
		},

		"max_health": 2
	},

	"hands2": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/equipment/hand2_placeholder.png"),
		"rarity": 0.0,
		"description": "Steel gauntlets",

		"defences": {
			"slash": 8,
			"pierce": 6,
			"blunt": 4
		},

		"max_health": 5
	},

	"feet1": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/equipment/boots1_placeholder.png"),
		"rarity": 0.0,
		"description": "Leather boots",

		"defences": {
			"slash": 3,
			"pierce": 2,
			"blunt": 2
		},

		"max_health": 3
	}
}

var weapons = {
	"sword": {
		"price": 0,
		"icon": preload("res://world/interface/assets/interface_elements/ArrowLittleRight.png"),
		"rarity": 0.0,
		"two handed":false,
		"description": "placeholder1",
		"damages": {
			"slash": 3,
			"pierce": 2
		}
	},

	"fork": {
		"price": 0,
		"icon": preload("res://world/interface/assets/interface_elements/ToggleButtonStandart.png"),
		"rarity": 0.0,
		"two handed":true,
		"description": "placeholder2",
		"damages": {
			"pierce": 66,
			"slash": 2
		}
	},

	"shield": {
		"price": 0,
		"icon": preload("res://world/interface/assets/icons/equipment/shield_placeholder.png"),
		"rarity": 0.0,
		"two handed":false,
		"description": "placeholder2",
		"damages": {
			"pierce": 66,
			"slash": 2
		}
	}
}
