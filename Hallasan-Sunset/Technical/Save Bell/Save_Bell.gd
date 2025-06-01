extends StaticBody2D

@onready var animation_player = $AnimationPlayer
@onready var audio_stream_player_2d = $AudioStreamPlayer2D

@onready var animation_player2 = $CanvasLayer/AnimationPlayer2





func _on_hit_box_damaged(hurt_box):
	SaveManager.save_game()
	animation_player.play('Game saved')
	audio_stream_player_2d.play()
	animation_player2.play("Pulse")
	pass # Replace with function body.
