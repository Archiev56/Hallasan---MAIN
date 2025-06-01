extends Area2D

@onready var notification_ui = $"."  # Update the path to match your scene structure
@onready var player = null  # Reference to the player (will be assigned dynamically if needed)
@onready var animation_player = $Banner/AnimationPlayer
# Signal when body enters the area
func _on_body_entered(body):
	if body.name == "Player":  # Ensure it's the player triggering the event
		player = body
		trigger_notification()

func trigger_notification():
	if notification_ui:
		notification_ui.animation_player.play("Fade_in")
