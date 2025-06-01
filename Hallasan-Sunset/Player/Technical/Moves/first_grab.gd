extends Area2D

var item_carried : Node2D = null
var speed: float = 0.0

@export var magnet_strength: float = 1.0
@export var play_magnet_audio: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	if item_carried == null:
		speed=0.0
		pass
	elif item_carried.global_position.distance_to( global_position ) > speed :
		speed += magnet_strength * _delta
		item_carried.position += item_carried.global_position.direction_to( global_position ) * speed
		pass
	else:
		item_carried.position = global_position

	
func _on_body_entered(_b) -> void:
	print ("Fist Grabbing")
	var parent = _b.get_parent()
	if parent.throwable:
		if item_carried == null:
			item_carried = parent
			speed = magnet_strength 
			parent.set_physics_process(false)
			if parent.static_body_2d:
				var layers = parent.static_body_2d.get_collision_layer()
				if (layers & 16):
					print ("Has Wall Layer")
					var new_layers = (layers & ~16)
					parent.static_body_2d.set_collision_layer(new_layers)
			#parent.fist_grab()
			#if play_magnet_audio:
				#audio.play(0)
