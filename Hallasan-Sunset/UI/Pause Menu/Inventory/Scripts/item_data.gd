class_name ItemData
extends Resource

@export var name: String = ""
@export_multiline var description: String = ""
@export var texture: Texture2D
@export var cost: int = 10

@export_category("Item Use Effects")
@export var effects: Array[ItemEffect]

@export_category("Collection Notification")
@export var show_collection_notification: bool = true
@export var notification_sound: AudioStream
@export var is_important: bool = false  # For special items like keys, artifacts
@export var custom_notification_message: String = ""  # Optional custom message

func use() -> bool:
	if effects.size() == 0:
		return false
	
	for e in effects:
		if e:
			e.use()
	return true

func get_display_name() -> String:
	"""Get formatted name for display"""
	return name if name != "" else "Unknown Item"

func get_notification_message() -> String:
	"""Get the message to display in notification"""
	if custom_notification_message != "":
		return custom_notification_message
	else:
		return "Obtained " + get_display_name() + "!"

func get_item_name() -> String:
	"""Get just the item name for simple display"""
	return get_display_name()

func get_rarity_color() -> Color:
	"""Get color based on cost/importance for UI theming"""
	if is_important:
		return Color.GOLD
	elif cost >= 100:
		return Color.PURPLE  # Epic
	elif cost >= 50:
		return Color.BLUE    # Rare
	elif cost >= 20:
		return Color.GREEN   # Uncommon
	else:
		return Color.WHITE   # Common
