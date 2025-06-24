class_name Boomerang extends Sprite2D

enum State { INACTIVE, THROW, RETURN }

var player : Player
var direction : Vector2
var speed : float = 0
var state

@export var acceleration : float = 500.0
@export var max_speed : float = 400.0
@export var catch_audio : AudioStream

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var fist_grab: Area2D = $Fist_Grab

var frame_width: float = 0
var frame_height: float = 0
var frame_index: int = 0

func _ready() -> void:
	visible = false
	state = State.INACTIVE
	player = PlayerManager.player
	PlayerManager.INVENTORY_DATA.equipment_changed.connect(_on_equipment_changed)
	SaveManager.game_loaded.connect(_on_equipment_changed)

func _physics_process(delta: float) -> void:
	if state == State.THROW:
		speed -= acceleration * delta
		position += direction * speed * delta
		if speed <= 0:
			state = State.RETURN
	elif state == State.RETURN:
		direction = global_position.direction_to(player.global_position)
		speed += acceleration * delta
		position += direction * speed * delta
		if global_position.distance_to(player.global_position) <= 10:
			PlayerManager.play_audio(catch_audio)
			if fist_grab.item_carried:
				fist_grab.item_carried.throwable.player_interact()
			queue_free()
			_reset_boomerang_counter()  # Reset counter when returning

	var speed_ratio = speed / max_speed
	audio.pitch_scale = speed_ratio * 0.75 + 0.75
	animation_player.speed_scale = 1 + (speed_ratio * 0.25)

func throw(throw_direction: Vector2) -> void:
	_on_equipment_changed()
	player.UpdateAnimation("attack")
	direction = throw_direction
	speed = max_speed
	state = State.THROW

	# Increment global throw count
	PlayerManager.boomerang_throw_count += 1
	var boomerang_number = (PlayerManager.boomerang_throw_count - 1) % 2 + 1  # 1 or 2
	print("🚀 Throwing Boomerang ", boomerang_number)

	# Determine frame index
	frame_index = _get_frame_from_direction(direction)
	_update_region_rect()

	# Flip logic: vertical throws flip for second boomerang; horizontal don't
	if abs(direction.x) <= abs(direction.y):  # Vertical throw
		if boomerang_number == 2:
			scale.x = -1
		else:
			scale.x = 1
	else:
		scale.x = 1 if direction.x > 0 else -1

	# Play directional animation

	PlayerManager.play_audio(catch_audio)
	player.UpdateAnimation("catch")
	visible = true

func _on_equipment_changed() -> void:
	var equipment : Array[SlotData] = PlayerManager.INVENTORY_DATA.equipment_slots()
	var new_texture = equipment[1].item_data.sprite_texture
	if new_texture:
		texture = new_texture
		region_enabled = true
		frame_width = new_texture.get_width() / 16
		frame_height = new_texture.get_height()
		_update_region_rect()

func _get_frame_from_direction(dir: Vector2) -> int:
	if abs(dir.x) > abs(dir.y):
		return 8  # Horizontal
	elif dir.y > 0:
		return 0  # Down
	else:
		return 4  # Up

func _update_region_rect() -> void:
	if texture and region_enabled:
		region_rect = Rect2(frame_width * frame_index, 0, frame_width, frame_height)

func _reset_boomerang_counter() -> void:
	PlayerManager.boomerang_throw_count = 0
	print("🔄 Boomerang counter reset!")
