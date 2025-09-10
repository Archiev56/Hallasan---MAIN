class_name State_Grapple
extends State

@onready var idle: State_Idle = $"../Idle"
@onready var grapple_hook: Node2D = %GrappleHook
@onready var nine_patch_rect: NinePatchRect = $"../../Interactions/GrappleHook/NinePatchRect"
@onready var chain_audio_player: AudioStreamPlayer2D = $"../../Interactions/GrappleHook/AudioStreamPlayer2D"
@onready var grapple_ray_cast_2d: RayCast2D = %GrappleRayCast2D
@onready var grapple_hurt_box: HurtBox = %GrappleHurtBox

@export var grapple_distance : float = 100.0
@export var grapple_speed : float = 200.0

@export_group("Audio SFX")
@export var grapple_fire_audio : AudioStream
@export var grapple_stick_audio : AudioStream
@export var grapple_bounce_audio : AudioStream

var collision_distance : float
var collision_type : int = 0 # 0 = none, 1 = wall, 2 = grapple point
var nine_patch_size : float = 25.0

var tween : Tween
var next_state : State = null

var positions : Array[ Vector3 ] = [
	Vector3( 0.0, -20.0, 180.0 ),  # UP
	Vector3( 0.0, -10.0, 0.0 ),    # DOWN
	Vector3( 10.0, -15.0, -90.0 ), # LEFT
	Vector3( -10.0, -15.0, 90.0 ), # RIGHT
]

# FIX: use a normal mapping (no L/R swap)
var pos_map : Dictionary = {
	Vector2.UP: 0,
	Vector2.DOWN: 1,
	Vector2.LEFT: 3,
	Vector2.RIGHT: 2
}

## Initialize this state
func init() -> void:
	grapple_hook.visible = false
	grapple_ray_cast_2d.enabled = false
	grapple_hurt_box.monitoring = false

	# Control setup: anchor to top-left; rotate the control itself later
	nine_patch_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	nine_patch_rect.rotation_degrees = 0.0
	nine_patch_rect.scale = Vector2.ONE
	_align_chain_to_hook()
	pass

## Enter state
func enter() -> void:
	player.UpdateAnimation("idle")
	grapple_hook.visible = true
	grapple_hurt_box.monitoring = true

	set_grapple_position()
	raycast_detection()
	shoot_grapple()

	chain_audio_player.play()
	play_audio(grapple_fire_audio)
	pass

## Exit state
func exit() -> void:
	next_state = null
	grapple_hook.visible = false
	grapple_hurt_box.monitoring = false
	chain_audio_player.stop()
	if tween:
		tween.kill()
	nine_patch_rect.size.y = nine_patch_size
	# reset for cleanliness
	nine_patch_rect.rotation_degrees = 0.0
	nine_patch_rect.scale = Vector2.ONE
	pass

## _process
func process(_delta: float) -> State:
	player.velocity = Vector2.ZERO
	return next_state

## _physics_process
func physics(_delta: float) -> State:
	return null

## input
func handle_input(_event: InputEvent) -> State:
	return null

func set_grapple_position() -> void:
	var new_pos: Vector3 = positions[pos_map[player.cardinal_direction]]

	# Hook sprite uses Node2D rotation (fine to keep)
	grapple_hook.position = Vector2(new_pos.x, new_pos.y)
	grapple_hook.rotation_degrees = new_pos.z

	# Rotate the NinePatchRect itself; Controls don't inherit Node2D rotation
	nine_patch_rect.rotation_degrees = new_pos.z

	# Flip the chain texture horizontally only when aiming LEFT
	# RIGHT/UP/DOWN keep normal scale
	match player.cardinal_direction:
		Vector2.LEFT:
			nine_patch_rect.scale = Vector2(-1.0, 1.0)
		_:
			nine_patch_rect.scale = Vector2(1.0, 1.0)

	# Keep chain's top-center fixed at the hook origin
	_align_chain_to_hook()

	# Optional layering tweak
	grapple_hook.show_behind_parent = (player.cardinal_direction == Vector2.UP)

	# Ray aligned with aim
	grapple_ray_cast_2d.target_position = player.cardinal_direction * grapple_distance
	pass

func _align_chain_to_hook() -> void:
	# Pivot around top-center so growth comes from the hook
	nine_patch_rect.pivot_offset = Vector2(nine_patch_rect.size.x * 0.5, 0.0)
	# Place top-left so that top-center sits at the hook origin (0,0)
	nine_patch_rect.position = Vector2(-nine_patch_rect.pivot_offset.x, 0.0)

func raycast_detection() -> void:
	collision_type = 0
	collision_distance = grapple_distance

	grapple_ray_cast_2d.set_collision_mask_value(5, false)
	grapple_ray_cast_2d.set_collision_mask_value(6, true)
	grapple_ray_cast_2d.force_raycast_update()
	if grapple_ray_cast_2d.is_colliding():
		collision_type = 2
		collision_distance = grapple_ray_cast_2d.get_collision_point().distance_to(player.global_position)
		return

	grapple_ray_cast_2d.set_collision_mask_value(5, true)
	grapple_ray_cast_2d.set_collision_mask_value(6, false)
	grapple_ray_cast_2d.force_raycast_update()
	if grapple_ray_cast_2d.is_colliding():
		collision_type = 1
		collision_distance = grapple_ray_cast_2d.get_collision_point().distance_to(player.global_position)
		return
	pass

func shoot_grapple() -> void:
	if tween:
		tween.kill()

	var tween_duration: float = collision_distance / grapple_speed
	tween = create_tween()
	tween.tween_property(
		nine_patch_rect, "size",
		Vector2(nine_patch_rect.size.x, collision_distance),
		tween_duration
	)

	if collision_type == 2:
		tween.tween_callback(grapple_player)
	else:
		tween.tween_callback(return_grapple)
	pass

func grapple_player() -> void:
	if tween:
		tween.kill()
	play_audio(grapple_stick_audio)
	player.set_collision_mask_value(4, false)

	var tween_duration: float = collision_distance / grapple_speed
	tween = create_tween()
	tween.tween_property(
		nine_patch_rect, "size",
		Vector2(nine_patch_rect.size.x, nine_patch_size),
		tween_duration
	)

	var player_target: Vector2 = player.global_position
	player_target += (player.cardinal_direction * collision_distance)
	player_target -= player.cardinal_direction * nine_patch_size

	tween.parallel().tween_property(
		player, "global_position",
		player_target,
		tween_duration
	)
	player.make_invulnerable(tween_duration)

	tween.tween_callback(grapple_finished)
	pass

func return_grapple() -> void:
	if tween:
		tween.kill()

	if collision_type > 0:
		play_audio(grapple_bounce_audio)

	var tween_duration: float = collision_distance / grapple_speed
	tween = create_tween()
	tween.tween_property(
		nine_patch_rect, "size",
		Vector2(nine_patch_rect.size.x, nine_patch_size),
		tween_duration
	)

	tween.tween_callback(grapple_finished)
	pass

func grapple_finished() -> void:
	player.set_collision_mask_value(4, true)
	state_machine.change_state(idle)
	pass

func play_audio(audio: AudioStream) -> void:
	player.audio.stream = audio
	player.audio.play()
	pass
