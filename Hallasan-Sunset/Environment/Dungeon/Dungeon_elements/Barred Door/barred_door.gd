class_name BarredDoor extends Node2D

var is_open : bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var is_open_data: PersistentDataHandler = $"Persistent-data-handler"


func _ready() -> void:
	set_state()
	is_open_data.data_loaded.connect( set_state )
	pass


func open_door():
	animation_player.play( "open_door" )
	is_open_data.set_value()
	pass



func close_door() -> void:
	animation_player.play( "close_door" )
	pass

func set_state() -> void:
	is_open = is_open_data.value
	if is_open:
		animation_player.play( "opened" )
	else:
		animation_player.play( "closed" )
