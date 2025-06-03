extends Area2D

@export var tilemap_layer: LevelTileMapLayer  # Reference your specific TileMapLayer
@export var fade_time: float = 0.2            # Duration of fade in/out
var is_faded_in: bool = false                 # Track state

func _on_body_entered(body):
	if body.name == "Player":
		if not is_faded_in:
			tilemap_layer.enabled = true
			_fade_in_tilemap()
			is_faded_in = true
		else:
			_fade_out_tilemap()
			is_faded_in = false

func _fade_in_tilemap():
	tilemap_layer.modulate.a = 0.0  # Start transparent
	var tween = create_tween()
	tween.tween_property(tilemap_layer, "modulate:a", 1.0, fade_time)

func _fade_out_tilemap():
	var tween = create_tween()
	tween.tween_property(tilemap_layer, "modulate:a", 0.0, fade_time)
	tween.tween_callback(func():
		tilemap_layer.enabled = false  # Fully disable after fade-out
	)
