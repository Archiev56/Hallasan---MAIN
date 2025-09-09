extends Sprite2D

const FRAME_COUNT : int = 128

func _ready() -> void:
	# Connect to equipment changes
	if PlayerManager.INVENTORY_DATA and PlayerManager.INVENTORY_DATA.has_signal("equipment_changed"):
		PlayerManager.INVENTORY_DATA.equipment_changed.connect(_on_equipment_changed)
		print("Connected to equipment_changed signal")
	else:
		print("Warning: equipment_changed signal not found")
	
	if SaveManager.has_signal("game_loaded"):
		SaveManager.game_loaded.connect(_on_equipment_changed)
		print("Connected to game_loaded signal")
	
	# Set initial equipment on ready
	_on_equipment_changed()

func _process(_delta: float) -> void:
	pass

func _on_equipment_changed() -> void:
	print("=== EQUIPMENT CHANGED DEBUG ===")
	
	# Check if PlayerManager and INVENTORY_DATA exist
	if not PlayerManager:
		print("Error: PlayerManager is null!")
		return
	
	if not PlayerManager.INVENTORY_DATA:
		print("Error: PlayerManager.INVENTORY_DATA is null!")
		return
	
	# Check if equipment_slots method exists
	if not PlayerManager.INVENTORY_DATA.has_method("equipment_slots"):
		print("Error: equipment_slots() method not found!")
		return
	
	# Get equipment slots
	var equipment : Array[SlotData] = PlayerManager.INVENTORY_DATA.equipment_slots()
	print("Equipment array size: ", equipment.size())
	
	# Check if we have enough equipment slots
	if equipment.size() <= 1:
		print("Error: Not enough equipment slots (need at least 2, got ", equipment.size(), ")")
		return
	
	# Check equipment slot 1 (index 1)
	print("Checking equipment slot 1...")
	var equipment_slot = equipment[1]
	
	if not equipment_slot:
		print("Equipment slot 1 is null - no item equipped")
		# Set default texture or handle empty slot
		_set_default_texture()
		return
	
	print("Equipment slot 1 exists, checking item_data...")
	if not equipment_slot.item_data:
		print("Equipment slot 1 has no item_data - slot is empty")
		# Set default texture or handle empty slot
		_set_default_texture()
		return
	
	print("Item in slot 1: ", equipment_slot.item_data.name)
	
	# Check if the item has a sprite_texture
	if not equipment_slot.item_data.has("sprite_texture"):
		print("Error: Item '", equipment_slot.item_data.name, "' has no sprite_texture property")
		_set_default_texture()
		return
	
	var new_texture = equipment_slot.item_data.sprite_texture
	if not new_texture:
		print("Warning: sprite_texture is null for item '", equipment_slot.item_data.name, "'")
		_set_default_texture()
		return
	
	# Successfully set the new texture
	texture = new_texture
	print("Successfully set texture to: ", new_texture.resource_path if new_texture.resource_path else "Unknown texture")
	print("=== END EQUIPMENT CHANGED DEBUG ===")

func _set_default_texture() -> void:
	"""Set a default texture when no equipment is found"""
	print("Setting default texture...")
	# You can set a default player texture here
	# texture = preload("res://path/to/default_player_texture.png")
	# Or just leave it as is if you don't want to change it
	pass

# Helper function to debug all equipment slots
func debug_all_equipment_slots() -> void:
	print("=== ALL EQUIPMENT SLOTS DEBUG ===")
	
	if not PlayerManager or not PlayerManager.INVENTORY_DATA:
		print("PlayerManager or INVENTORY_DATA is null!")
		return
	
	if not PlayerManager.INVENTORY_DATA.has_method("equipment_slots"):
		print("equipment_slots() method not found!")
		return
	
	var equipment : Array[SlotData] = PlayerManager.INVENTORY_DATA.equipment_slots()
	print("Total equipment slots: ", equipment.size())
	
	for i in range(equipment.size()):
		var slot = equipment[i]
		print("Slot ", i, ":")
		if not slot:
			print("  - Empty/null")
		elif not slot.item_data:
			print("  - Slot exists but no item_data")
		else:
			print("  - Item: ", slot.item_data.name)
			print("  - Has sprite_texture: ", slot.item_data.has("sprite_texture"))
			if slot.item_data.has("sprite_texture"):
				print("  - Sprite texture: ", slot.item_data.sprite_texture)
	
	print("=== END ALL EQUIPMENT DEBUG ===")
