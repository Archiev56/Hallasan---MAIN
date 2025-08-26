class_name RecipeRequirement
extends Resource

@export var material: ItemData
@export var quantity: int = 1

func is_valid() -> bool:
	"""Check if this requirement is valid"""
	return material != null and quantity > 0

func get_material_name() -> String:
	"""Get the material name"""
	return material.name if material else "Unknown Material"

func get_display_text() -> String:
	"""Get display text for UI"""
	return get_material_name() + " x" + str(quantity)
