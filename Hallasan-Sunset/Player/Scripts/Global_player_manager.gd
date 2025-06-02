extends Node

const PLAYER = preload("res://Hallasan-Sunset/Player/Player.tscn")
const INVENTORY_DATA : InventoryData = preload("res://Hallasan-Sunset/UI/Pause Menu/Inventory/player_inventory.tres")

signal camera_shook( trauma : float )
signal interact_pressed
signal player_leveled_up
signal energy_changed

var interact_handled : bool = true
var player : Player
var player_spawned : bool = false
var boomerang_throw_count: int = 0

var level_requirements = [ 0, 50, 100, 200, 400, 800, 1500, 3000, 6000, 12000, 25000 ]


func _ready() -> void:
	add_player_instance()
	await get_tree().create_timer(0.2).timeout
	player_spawned = true



func add_player_instance() -> void:
	player = PLAYER.instantiate()
	add_child( player )
	pass



func set_health( hp: int, max_hp: int ) -> void:
	player.max_hp = max_hp
	player.hp = hp
	player.update_hp( 0 )



func reward_xp( _xp : int ) -> void:
	player.xp += _xp
	check_for_level_advance()


func check_for_level_advance() -> void:
	if player.level >= level_requirements.size():
		return
	if player.xp >= level_requirements[player.level]:
		player.level += 1
		player.attack += 1
		player.defense += 1
		player_leveled_up.emit()
		check_for_level_advance()
	pass  # Recursive call

func set_player_position( _new_pos : Vector2 ) -> void:
	player.global_position = _new_pos
	pass



func set_as_parent( _p : Node2D ) -> void:
	if player.get_parent():
		player.get_parent().remove_child( player )
	_p.add_child( player )



func unparent_player( _p : Node2D ) -> void:
	_p.remove_child( player )



func play_audio( _audio : AudioStream ) -> void:
	player.audio.stream = _audio
	player.audio.play()



func interact() -> void:
	interact_handled = false
	interact_pressed.emit()



func shake_camera( trauma : float = 1 ) -> void:
	camera_shook.emit( clampi( trauma, 0, 3 ) )
