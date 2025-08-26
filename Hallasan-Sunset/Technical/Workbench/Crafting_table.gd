class_name CraftingTable
extends WorkBench

func get_workbench_type() -> String:
	return "Crafting Table"

func get_available_recipes() -> Array:
	return [
		"Wooden Sword",
		"Health Potion",
		"Bow"
	]

func get_recipe_requirements(item_name: String) -> Dictionary:
	match item_name:
		"Wooden Sword":
			return {"Wood": 3, "Iron": 1}
		"Health Potion":
			return {"Herb": 2, "Water": 1}
		"Bow":
			return {"Wood": 4, "String": 2}
		_:
			return {}

func get_recipe_description(item_name: String) -> String:
	match item_name:
		"Wooden Sword":
			return "A basic wooden sword for combat"
		"Health Potion":
			return "Restores health when consumed"
		"Bow":
			return "Ranged weapon for hunting and combat"
		_:
			return "Craft " + item_name
