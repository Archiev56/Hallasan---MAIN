extends Node2D

@export var butterfly_scene: PackedScene      # Assign your Butterfly.tscn
@export var butterfly_count: int = 20         # Number of butterflies to spawn
@export var spawn_area: Rect2 = Rect2(Vector2.ZERO, Vector2(1024, 768))  # Spawn region in pixels

func _ready():
	for i in range(butterfly_count):  # ✅ FIXED loop
		var butterfly = butterfly_scene.instantiate()
		butterfly.position = _random_spawn_position()
		add_child(butterfly)

func _random_spawn_position() -> Vector2:
	var x = randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x)
	var y = randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
	return Vector2(x, y)
