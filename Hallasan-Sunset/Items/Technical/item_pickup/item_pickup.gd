@tool
@icon("res://Hallasan-Sunset/Technical/Icons/icon_particle.png")

class_name ItemPickup extends CharacterBody2D

signal picked_up

@export var item_data: ItemData : set = _set_item_data

@onready var area_2d: Area2D = $Area2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	_update_texture()
	if Engine.is_editor_hint():
		return
	area_2d.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var collision_info = move_and_collide(velocity * delta)
	if collision_info:
		velocity = velocity.bounce(collision_info.get_normal())
	velocity -= velocity * delta * 5

func _on_body_entered(b) -> void:
	if b is Player:
		if item_data:
			if PlayerManager.INVENTORY_DATA.add_item(item_data) == true:
				# Check if the collected item is the gem
				if item_data.resource_path == "res://Hallasan-Sunset/Items/Currency/Gem/Gem.tres":
					var coin_counter = get_tree().get_first_node_in_group("coin_counter")
					if coin_counter:
						# Play animation
						coin_counter.animation_player.play("show_coin")
						print("Gem collected! Playing 'show_coin' animation.")  # Debug message

						# Increase coin count and update label
						coin_counter.increase_coin_count()  # Call function inside CoinCounter
					else:
						print("ERROR: CoinCounter not found in the scene!")

				item_picked_up()

func item_picked_up() -> void:
	area_2d.body_entered.disconnect(_on_body_entered)
	audio_stream_player_2d.play()
	visible = false
	picked_up.emit()
	await audio_stream_player_2d.finished
	queue_free()

func _set_item_data(value: ItemData) -> void:
	item_data = value
	_update_texture()

func _update_texture() -> void:
	if item_data and sprite_2d:
		sprite_2d.texture = item_data.texture
