class_name Plant
extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
var cameraShakeNoise : FastNoiseLite
var camera2D : Camera2D

func _ready():
	# Connect the damaged signal using Callable
	camera2D = get_node("/root/playground/Player/Camera2D")
	cameraShakeNoise = FastNoiseLite.new()
	$HitBox.damaged.connect(Callable(self, "take_damage"))
	
	# Connect the animation_finished signal of the AnimationPlayer
	animation_player.animation_finished.connect(Callable(self, "_on_animation_finished"))

func _on_area_2d_body_entered(body):
	if body.name == "Player":
		print("Player entered plant hitbox")
		animation_player.play("Rustle")

func take_damage(_damage: HurtBox) -> void:
	cameraShakeNoise = FastNoiseLite.new()
	var camera_tween = get_tree().create_tween()
	
	# Play the destroyed animation
	animation_player.play("Destroyed")


# Signal handler for when the animation finishes
func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "Destroyed":
		queue_free()  # Only destroy the plant after the destroyed animation is done



