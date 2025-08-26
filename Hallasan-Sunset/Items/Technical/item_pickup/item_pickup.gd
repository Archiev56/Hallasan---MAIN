@tool
@icon("res://Hallasan-Sunset/Technical/Icons/icon_particle.png")
class_name ItemPickup
extends CharacterBody2D

signal picked_up

@export var item_data: ItemData : set = set_item_data

@export_category("Juice Effects")
@export var bob_height : float = 5.0  # How high/low the item bobs
@export var bob_speed : float = 3.0   # How fast the bobbing motion is

@onready var area_2d: Area2D = $Area2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

# Animation variables
var time_offset : float
var base_position : Vector2

func _ready() -> void:
	update_texture()
	
	if Engine.is_editor_hint():
		return
	
	# Initialize animation variables
	time_offset = randf() * TAU  # Random start time for variety
	base_position = global_position
	
	# Start the floating animation
	start_floating_animation()
	
	area_2d.body_entered.connect(_on_body_entered)

func start_floating_animation() -> void:
	# Create gentle floating tweens for extra smoothness
	var float_tween = create_tween()
	float_tween.set_loops()
	
	# Add some random variation to make each item unique
	var random_offset = randf_range(-1.0, 1.0)
	time_offset += random_offset

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# Handle bouncing physics
	var collision_info = move_and_collide(velocity * delta)
	if collision_info:
		velocity = velocity.bounce(collision_info.get_normal())
		# Update base position after bouncing
		base_position = global_position
	
	# Apply friction
	velocity -= velocity * delta * 5
	
	# Apply floating effects only if not bouncing much
	if velocity.length() < 50.0:
		apply_floating_effects(delta)

func apply_floating_effects(delta: float) -> void:
	time_offset += delta
	
	# Bobbing motion (sine wave)
	var bob_offset = sin(time_offset * bob_speed) * bob_height
	global_position.y = base_position.y + bob_offset

func _on_body_entered(b) -> void:
	if b is Player:
		if item_data:
			# Use original method that definitely works
			var success = PlayerManager.INVENTORY_DATA.add_item(item_data)
			
			if success:
				# FORCE workbench UI update directly
				var player_hud = get_tree().get_first_node_in_group("player_hud")
				if player_hud and player_hud.has_method("_refresh_workbench"):
					player_hud._refresh_workbench()
				
				# Emit signals manually
				PlayerManager.item_added.emit(item_data.name, 1)
				PlayerManager.crafting_materials_changed.emit()
				
				# Show item notification
				show_item_notification()
				
				# Check if the collected item is the gem
				if item_data.resource_path == "res://Hallasan-Sunset/Items/Currency/Gem/Gem.tres":
					var coin_counter = get_tree().get_first_node_in_group("coin_counter")
					if coin_counter:
						coin_counter.animation_player.play("show_coin")
						coin_counter.increase_coin_count()
				
				item_picked_up()

func show_item_notification() -> void:
	"""Show the item notification if enabled"""
	if not item_data or not item_data.show_collection_notification:
		return
	
	# Find PlayerHUD
	var player_hud = get_tree().get_first_node_in_group("player_hud")
	if not player_hud:
		# Fallback: search for PlayerHUD type
		var all_nodes = get_tree().get_nodes_in_group("ui")
		for node in all_nodes:
			if node.has_method("show_item_notification"):
				player_hud = node
				break
	
	# Show notification
	if player_hud and player_hud.has_method("show_item_notification"):
		player_hud.show_item_notification(item_data)
		
		# Play notification sound if available (separate from pickup sound)
		if item_data.notification_sound and player_hud.has_method("play_audio"):
			player_hud.play_audio(item_data.notification_sound)

func item_picked_up() -> void:
	area_2d.body_entered.disconnect(_on_body_entered)
	
	# Juicy pickup animation
	create_pickup_effects()
	
	audio_stream_player_2d.play()
	picked_up.emit()
	await audio_stream_player_2d.finished
	queue_free()

func create_pickup_effects() -> void:
	# Bring item to top layer so it appears above player
	sprite_2d.z_index = 100  # High z_index to render on top
	
	# Create simple pickup animation
	var pickup_tween = create_tween()
	pickup_tween.set_parallel(true)
	
	# Move up slightly
	pickup_tween.tween_property(self, "global_position", global_position + Vector2(0, -20), 0.3)
	
	# Fade out
	pickup_tween.tween_property(sprite_2d, "modulate", Color.TRANSPARENT, 0.2).set_delay(0.1)

func set_item_data(value: ItemData) -> void:
	item_data = value
	update_texture()

func update_texture() -> void:
	if item_data and sprite_2d:
		sprite_2d.texture = item_data.texture
