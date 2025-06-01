class_name VisionArea extends Area2D

signal player_entered()
signal player_exited()

@onready var animation_player_2 = get_node_or_null("AnimationPlayer2")
@onready var sprite_2d = $Sprite2D  # Exclamation mark Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_enter)
	body_exited.connect(_on_body_exit)
	if animation_player_2:
		animation_player_2.play("no show")  # Ensure it starts hidden
	
	var p = get_parent()
	if p is Enemy:
		p.direction_changed.connect(_on_direction_change)


func _process(delta: float) -> void:
	# Keep the sprite upright
	if sprite_2d:
		sprite_2d.rotation = -rotation

func _on_body_enter(_b: Node2D) -> void:
	if _b is Player:
		player_entered.emit()
		if animation_player_2:
			animation_player_2.play("show")

func _on_body_exit(_b: Node2D) -> void:
	if _b is Player:
		player_exited.emit()
		if animation_player_2:
			animation_player_2.play("no show")

func _on_direction_change(new_direction: Vector2) -> void:
	# Rotate the VisionArea
	match new_direction:
		Vector2.DOWN:
			rotation_degrees = 0
		Vector2.UP:
			rotation_degrees = 180
			animation_player_2.play("no show") 
		Vector2.LEFT:
			rotation_degrees = 90
			animation_player_2.play("no show") 
		Vector2.RIGHT:
			rotation_degrees = -90
			animation_player_2.play("no show") 
		_:
			rotation_degrees = 0
