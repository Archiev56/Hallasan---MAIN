@icon( "res://Hallasan-Sunset/Technical/Icons/icon_area_damage.png")
extends Area2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Function triggered when a body enters the spike's area
func _on_body_entered(body):# Ensure the body is the player
		animation_player.play("Spike")
		# Check if the player is invulnerable (e.g., while dashing)


# Function triggered when a body exits the spike's area
func _on_body_exited(body):
	animation_player.play("SpikeDown")
	await animation_player.animation_finished
	
