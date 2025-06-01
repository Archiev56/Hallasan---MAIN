extends Node2D

@export var rain_scene: PackedScene
@export var columns := 6
@export var rows := 4
@export var spacing := Vector2(160, 160)

func _ready():
	for x in range(columns):
		for y in range(rows):
			var rain = rain_scene.instantiate()
			rain.position = Vector2(x, y) * spacing
			add_child(rain)
