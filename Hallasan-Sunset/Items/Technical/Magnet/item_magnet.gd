class_name ItemMagnet
extends Area2D

var items: Array[Node2D] = []
var speeds: Array[float] = []

@export var magnet_strength: float = 1.0
@export var play_magnet_audio: bool = false

@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	area_entered.connect(_on_area_enter)

func _process(delta: float) -> void:
	for i in range(items.size() - 1, -1, -1):
		var _item = items[i]
		if _item == null or not is_instance_valid(_item):
			items.remove_at(i)
			speeds.remove_at(i)
			continue

		if _item.global_position.distance_to(global_position) > speeds[i]:
			speeds[i] += magnet_strength * delta
			if _item.has_method("move_toward_magnet"):
				_item.move_toward_magnet(global_position, speeds[i])
		else:
			_item.global_position = global_position

func _on_area_enter(_a: Area2D) -> void:
	var parent = _a.get_parent()
	if parent is ItemPickup or parent is Throwable:
		if not items.has(parent):
			items.append(parent)
			speeds.append(magnet_strength)
			parent.set_physics_process(false)
			if play_magnet_audio:
				audio.play(0)
