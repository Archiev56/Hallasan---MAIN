extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var area_2d: Area2D = $Area2D

var player_in_area: bool = false

func _ready() -> void:
	area_2d.body_entered.connect(_on_area_2d_body_entered)
	area_2d.body_exited.connect(_on_area_2d_body_exited)

func _process(_delta: float) -> void:
	if player_in_area and Input.is_action_just_pressed("interact"):
		if animation_player:
			animation_player.play("open")

func _on_area_2d_body_entered(body: Node) -> void:
	if body.name == "Player":  # Adjust as needed
		player_in_area = true

func _on_area_2d_body_exited(body: Node) -> void:
	if body.name == "Player":
		player_in_area = false
