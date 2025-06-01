@icon( "res://Hallasan-Sunset/Technical/Icons/icon_character.png" )

extends Node2D


func _ready() -> void:
	visible = false
	if PlayerManager.player_spawned == false:
		PlayerManager.set_player_position( global_position )
		PlayerManager.player_spawned = true
