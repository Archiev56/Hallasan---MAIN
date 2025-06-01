class_name EnemySpawner extends Area2D

@export var enemy_scene : PackedScene  # Assign different enemy types in the editor
@export var spawn_offset : Vector2 = Vector2.ZERO  # Base offset from spawner
@export var enemy_count : int = 1  # Number of enemies to spawn
@export var spawn_spread : float = 32.0  # Distance between each enemy (optional)

@onready var animation_player = $AnimationPlayer

var player_inside := false
var has_spawned := false

func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is Player and not has_spawned:
		animation_player.play("strike")
		spawn_enemies()
		has_spawned = true
		player_inside = true
		monitoring = false  # Disable further detection

func _on_body_exited(body: Node) -> void:
	if body is Player:
		player_inside = false

func spawn_enemies():
	if enemy_scene == null:
		push_warning("No enemy_scene assigned to EnemySpawner at: " + str(global_position))
		return

	for i in range(enemy_count):
		var enemy_instance = enemy_scene.instantiate()
		if enemy_instance is Node2D:
			get_tree().get_root().add_child(enemy_instance)
			var offset = spawn_offset + Vector2(i * spawn_spread, 0)
			enemy_instance.global_position = global_position + offset
		else:
			push_error("enemy_scene must be a Node2D-compatible scene.")
