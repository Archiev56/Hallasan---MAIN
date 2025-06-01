extends Area2D

@export var area_name: String = "Default Area"

func _ready():
	pass

func _on_body_entered(body):
	if body.is_in_group("Player"):  # Ensure only the player triggers the notification
		PlayerHud.show_area_notification(area_name)
	pass
