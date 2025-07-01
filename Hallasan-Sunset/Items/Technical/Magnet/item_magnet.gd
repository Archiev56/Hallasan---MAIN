class_name ItemMagnet extends Area2D

var items: Array[ItemPickup] = []
var item_data: Array[Dictionary] = []

@export var magnet_strength: float = 400.0
@export var max_speed: float = 1200.0
@export var acceleration_curve: float = 2.0  # Higher = more aggressive acceleration
@export var orbit_strength: float = 0.3  # Adds slight orbital motion
@export var wobble_strength: float = 50.0  # Adds slight wobble for juice
@export var scale_effect: bool = true  # Scale items during attraction
@export var play_magnet_audio: bool = false

@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	area_entered.connect(_on_area_enter)

func _process(delta: float) -> void:
	for i in range(items.size() - 1, -1, -1):
		var item = items[i]
		if item == null:
			items.remove_at(i)
			item_data.remove_at(i)
			continue
		
		_update_item_movement(item, item_data[i], delta)

func _update_item_movement(item: ItemPickup, data: Dictionary, delta: float) -> void:
	var distance = item.global_position.distance_to(global_position)
	
	# If item is very close, snap to position
	if distance < 10.0:
		item.global_position = global_position
		return
	
	# Calculate base direction
	var direction = item.global_position.direction_to(global_position)
	
	# Add orbital motion for more dynamic movement
	var perpendicular = Vector2(-direction.y, direction.x)
	var orbital_force = perpendicular * orbit_strength * sin(data.time * 8.0)
	
	# Add wobble effect
	var wobble = Vector2(
		sin(data.time * 12.0) * wobble_strength,
		cos(data.time * 10.0) * wobble_strength
	) * (distance / 200.0)  # Wobble decreases as item gets closer
	
	# Calculate acceleration based on distance (closer = faster)
	var distance_factor = pow(1.0 - min(distance / 300.0, 1.0), acceleration_curve)
	var target_speed = lerp(magnet_strength, max_speed, distance_factor)
	
	# Smooth acceleration
	data.current_speed = lerp(data.current_speed, target_speed, 8.0 * delta)
	
	# Combine all forces
	var final_direction = (direction + orbital_force).normalized()
	var velocity = final_direction * data.current_speed * delta
	
	# Add wobble to final position
	item.position += velocity + wobble * delta
	
	# Scale effect - items get slightly larger as they approach
	if scale_effect:
		var scale_factor = lerp(1.0, 1.3, 1.0 - min(distance / 150.0, 1.0))
		item.scale = Vector2.ONE * scale_factor
	
	# Update rotation for spinning effect
	data.rotation += (data.current_speed / 100.0) * delta
	item.rotation = data.rotation
	
	# Update time for animations
	data.time += delta

func _on_area_enter(area: Area2D) -> void:
	if area.get_parent() is ItemPickup:
		var new_item = area.get_parent() as ItemPickup
		
		# Don't add if already in the list
		if new_item in items:
			return
		
		items.append(new_item)
		
		# Create data dictionary for this item
		var data = {
			"current_speed": 0.0,
			"time": 0.0,
			"rotation": new_item.rotation,
			"original_scale": new_item.scale
		}
		item_data.append(data)
		
		new_item.set_physics_process(false)
		
		# Add initial attraction effect
		_create_attraction_effect(new_item)
		
		if play_magnet_audio:
			audio.play(0)

func _create_attraction_effect(item: ItemPickup) -> void:
	# Create a brief flash/pulse effect when item gets magnetized
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Quick scale pulse
	tween.tween_property(item, "scale", item.scale * 1.2, 0.1)
	tween.tween_property(item, "scale", item.scale, 0.15).set_delay(0.1)
	
	# Brief glow effect (if the item has a modulate property)
	if item.has_method("get_modulate"):
		tween.tween_property(item, "modulate", Color.WHITE * 1.5, 0.1)
		tween.tween_property(item, "modulate", Color.WHITE, 0.2).set_delay(0.1)

func remove_item(item: ItemPickup) -> void:
	"""Call this when an item is picked up to clean up properly"""
	var index = items.find(item)
	if index != -1:
		items.remove_at(index)
		item_data.remove_at(index)
		
		# Reset item properties
		if scale_effect and item != null:
			item.scale = item_data[index].get("original_scale", Vector2.ONE)
		
		item.set_physics_process(true)
