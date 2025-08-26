class_name Recipe
extends Resource

@export var craftable_item: ItemData
@export var requirements: Array[RecipeRequirement] = []
@export var custom_description: String = ""  # Optional override for item description
@export var crafting_time: float = 0.0  # Future feature: crafting delays
@export var requires_fuel: bool = false  # Future feature: some recipes need fuel
@export var workbench_types: Array[String] = []  # Optional: limit to specific workbenches

func is_valid() -> bool:
	"""Check if this recipe is valid"""
	if not craftable_item:
		return false
	
	for req in requirements:
		if not req or not req.is_valid():
			return false
	
	return true

func get_item_name() -> String:
	"""Get the name of the craftable item"""
	return craftable_item.name if craftable_item else "Unknown Item"

func get_description() -> String:
	"""Get the recipe description"""
	if custom_description != "":
		return custom_description
	elif craftable_item:
		return craftable_item.description
	else:
		return "Craft unknown item"

func get_requirements_dict() -> Dictionary:
	"""Get requirements as Dictionary for backward compatibility"""
	var dict = {}
	for req in requirements:
		if req and req.is_valid():
			dict[req.get_material_name()] = req.quantity
	return dict

func can_craft() -> bool:
	"""Check if player can craft this recipe"""
	for req in requirements:
		if req and req.is_valid():
			if not PlayerManager.has_item(req.get_material_name(), req.quantity):
				return false
	return true

func get_missing_materials() -> Array[String]:
	"""Get list of materials the player doesn't have enough of"""
	var missing = []
	for req in requirements:
		if req and req.is_valid():
			var player_amount = PlayerManager.get_item_count(req.get_material_name())
			if player_amount < req.quantity:
				missing.append(req.get_material_name() + " (need " + str(req.quantity - player_amount) + " more)")
	return missing

func works_with_workbench(workbench_name: String) -> bool:
	"""Check if this recipe works with the given workbench type"""
	if workbench_types.is_empty():
		return true  # Works with any workbench
	return workbench_name in workbench_types
