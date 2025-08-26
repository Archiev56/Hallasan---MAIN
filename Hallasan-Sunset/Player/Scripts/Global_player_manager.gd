extends Node

const PLAYER = preload("res://Hallasan-Sunset/Player/Player.tscn")
const INVENTORY_DATA_PATH = "res://Hallasan-Sunset/UI/Pause Menu/Inventory/player_inventory.tres"
var _inventory_data : InventoryData

var INVENTORY_DATA : InventoryData:
	get:
		return get_inventory_data()

# ============================================================
#  SIGNALS
# ============================================================
signal camera_shook(trauma: float)
signal interact_pressed
signal player_leveled_up
signal energy_changed
signal item_added(item_name: String, quantity: int)
signal item_removed(item_name: String, quantity: int)
signal crafting_materials_changed
signal equipment_changed
signal player_interact

# ============================================================
#  VARIABLES
# ============================================================
var interact_handled: bool = true
var player: Player
var player_spawned: bool = false
var boomerang_throw_count: int = 0
var level_requirements = [0, 50, 100, 200, 400, 800, 1500, 3000, 6000, 12000, 25000]

func get_inventory_data() -> InventoryData:
	if not _inventory_data:
		_inventory_data = load(INVENTORY_DATA_PATH)
		if _inventory_data:
			if _inventory_data.has_signal("update"):
				_inventory_data.update.connect(_on_inventory_update)
			if _inventory_data.has_signal("equipment_changed"):
				_inventory_data.equipment_changed.connect(_on_equipment_changed)
	return _inventory_data

func _ready() -> void:
	add_player_instance()
	await get_tree().create_timer(0.2).timeout
	player_spawned = true

func _on_inventory_update() -> void:
	crafting_materials_changed.emit()

func _on_equipment_changed() -> void:
	equipment_changed.emit()

func refresh_crafting_data() -> void:
	crafting_materials_changed.emit()

# ============================================================
#  CORE ITEM METHODS - THE IMPORTANT PART
# ============================================================

func add_item(item_name: String, quantity: int = 1) -> bool:
	if not INVENTORY_DATA:
		return false
	
	var item_data = _get_item_data_by_name(item_name)
	var success = false
	
	if item_data and INVENTORY_DATA.has_method("add_item"):
		success = INVENTORY_DATA.add_item(item_data, quantity)
	else:
		success = _add_item_manually(item_name, quantity)
	
	if success:
		item_added.emit(item_name, quantity)
		crafting_materials_changed.emit()
		if INVENTORY_DATA.has_signal("update"):
			INVENTORY_DATA.update.emit()
	
	return success

func _add_item_manually(item_name: String, quantity: int) -> bool:
	if not INVENTORY_DATA or not INVENTORY_DATA.slots:
		return false
	
	var item_data = _get_item_data_by_name(item_name)
	if not item_data:
		return false
	
	# Try to stack first
	for slot in INVENTORY_DATA.slots:
		if slot and slot.item_data and slot.item_data.name == item_name:
			if not item_data.has("max_stack_count") or slot.quantity < item_data.max_stack_count:
				var can_add = item_data.max_stack_count - slot.quantity if item_data.has("max_stack_count") else quantity
				var add_amount = min(can_add, quantity)
				slot.quantity += add_amount
				quantity -= add_amount
				if quantity <= 0:
					return true
	
	# Add to empty slots
	for i in range(INVENTORY_DATA.slots.size()):
		var slot = INVENTORY_DATA.slots[i]
		if not slot or not slot.item_data:
			if not slot:
				var SlotData = preload("res://Hallasan-Sunset/UI/Pause Menu/Inventory/Scripts/slot_data.gd")
				slot = SlotData.new()
				INVENTORY_DATA.slots[i] = slot
			
			slot.item_data = item_data
			slot.quantity = quantity
			return true
	
	return false

func has_item(item_name: String, quantity: int = 1) -> bool:
	if not INVENTORY_DATA:
		return false
	
	var total_count = 0
	for slot in INVENTORY_DATA.slots:
		if slot and slot.item_data and _items_match(slot.item_data.name, item_name):
			total_count += slot.quantity
	
	return total_count >= quantity

func remove_items(item_name: String, quantity: int) -> bool:
	if not INVENTORY_DATA or not has_item(item_name, quantity):
		return false
	
	var item_data = _get_item_data_by_name(item_name)
	if not item_data:
		return false
	
	if INVENTORY_DATA.has_method("use_item"):
		var success = INVENTORY_DATA.use_item(item_data, quantity)
		if success:
			item_removed.emit(item_name, quantity)
			crafting_materials_changed.emit()
			if INVENTORY_DATA.has_signal("update"):
				INVENTORY_DATA.update.emit()
		return success
	
	# Manual removal
	var remaining_to_remove = quantity
	for slot in INVENTORY_DATA.slots:
		if slot and slot.item_data and _items_match(slot.item_data.name, item_name):
			var remove_from_slot = min(slot.quantity, remaining_to_remove)
			slot.quantity -= remove_from_slot
			remaining_to_remove -= remove_from_slot
			
			if slot.quantity <= 0:
				slot.item_data = null
				slot.quantity = 0
			
			if remaining_to_remove <= 0:
				break
	
	if remaining_to_remove <= 0:
		item_removed.emit(item_name, quantity)
		crafting_materials_changed.emit()
		if INVENTORY_DATA.has_signal("update"):
			INVENTORY_DATA.update.emit()
		return true
	
	return false

func get_item_count(item_name: String) -> int:
	if not INVENTORY_DATA:
		return 0
	
	if INVENTORY_DATA.has_method("get_item_held_quantity"):
		var item_data = _get_item_data_by_name(item_name)
		if item_data:
			return INVENTORY_DATA.get_item_held_quantity(item_data)
	
	var total_count = 0
	for slot in INVENTORY_DATA.slots:
		if slot and slot.item_data and _items_match(slot.item_data.name, item_name):
			total_count += slot.quantity
	
	return total_count

func _items_match(item_name1: String, item_name2: String) -> bool:
	return item_name1 == item_name2 or item_name1.to_lower() == item_name2.to_lower() or item_name1.strip_edges() == item_name2.strip_edges()

func _get_item_data_by_name(item_name: String):
	if INVENTORY_DATA:
		for slot in INVENTORY_DATA.slots:
			if slot and slot.item_data and slot.item_data.name == item_name:
				return slot.item_data
	
	var common_paths = [
		"res://items/" + item_name.to_lower().replace(" ", "_") + ".tres",
		"res://Hallasan-Sunset/Items/" + item_name + ".tres",
		"res://Items/" + item_name + ".tres"
	]
	
	for path in common_paths:
		if ResourceLoader.exists(path):
			return load(path)
	
	return null

# ============================================================
#  EXISTING FUNCTIONS (unchanged)
# ============================================================

func add_player_instance() -> void:
	player = PLAYER.instantiate()
	add_child(player)

func set_health(hp: int, max_hp: int) -> void:
	player.max_hp = max_hp
	player.hp = hp
	player.update_hp(0)

func reward_xp(_xp: int) -> void:
	player.xp += _xp
	check_for_level_advance()

func check_for_level_advance() -> void:
	if player.level >= level_requirements.size():
		return
	if player.xp >= level_requirements[player.level]:
		player.level += 1
		player.attack += 1
		player.defense += 1
		player_leveled_up.emit()
		check_for_level_advance()

func set_player_position(new_pos: Vector2) -> void:
	player.global_position = new_pos

func set_as_parent(_p: Node2D) -> void:
	if player.get_parent():
		player.get_parent().remove_child(player)
	_p.add_child(player)

func unparent_player(_p: Node2D) -> void:
	_p.remove_child(player)

func play_audio(_audio: AudioStream) -> void:
	player.audio.stream = _audio
	player.audio.play()

func interact() -> void:
	interact_handled = false
	interact_pressed.emit()

func shake_camera(trauma: float = 1) -> void:
	camera_shook.emit(clampi(trauma, 0, 3))

func get_all_items() -> Dictionary:
	var items = {}
	if not INVENTORY_DATA:
		return items
	
	for slot in INVENTORY_DATA.slots:
		if slot and slot.item_data:
			var item_name = slot.item_data.name
			if items.has(item_name):
				items[item_name] += slot.quantity
			else:
				items[item_name] = slot.quantity
	
	return items


func get_equipped_item_texture(slot_index: int) -> Texture2D:
	if not INVENTORY_DATA or not INVENTORY_DATA.has_method("equipment_slots"):
		return null
	
	var equipment : Array[SlotData] = INVENTORY_DATA.equipment_slots()
	if slot_index >= equipment.size() or slot_index < 0:
		return null
	
	var slot = equipment[slot_index]
	if not slot or not slot.item_data or not slot.item_data.has("sprite_texture"):
		return null
	
	return slot.item_data.sprite_texture
