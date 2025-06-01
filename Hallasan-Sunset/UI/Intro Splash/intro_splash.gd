extends Node2D

@onready var animation_player = $Control/AnimationPlayer


func _ready():
	PlayerManager.player.visible = false
	PlayerHud.visible = false
	PauseMenu.process_mode = Node.PROCESS_MODE_DISABLED
	animation_player.play("intro")


func _on_animation_player_animation_finished(anim_name):
	get_tree().change_scene_to_file("res://Hallasan-Sunset/UI/Main_menu/Main Menu.tscn")
