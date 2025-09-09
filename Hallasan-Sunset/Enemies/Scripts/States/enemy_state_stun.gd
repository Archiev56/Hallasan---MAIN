class_name EnemyStateStun
extends EnemyState

@export var anim_name: String = "hurt"

@export_category("Motion")
@export var knockback_speed: float = 200.0
@export var decelerate_speed: float = 600.0

@export_category("Stun Timing")
@export var min_stun_time: float = 0.12
@export var max_stun_time: float = 0.60
@export var refresh_on_hit: bool = true

@export_category("Grace I-Frames")
@export var grace_invuln_duration: float = 0.08
@export var refresh_grace_on_hit: bool = true

@export_category("Juice")
@export var do_hit_pause: bool = true
@export var hit_pause_scale: float = 0.25
@export var hit_pause_duration: float = 0.03
@export var hit_pause_extend_on_overlap: bool = false

@export var do_screen_shake: bool = true
@export var shake_amplitude: float = 6.0
@export var shake_duration: float = 0.10

@export var do_flash: bool = true
@export var flash_color: Color = Color(1.6, 1.6, 1.6, 1.0)
@export var flash_duration: float = 0.08

@export var do_squash: bool = true
@export var squash_scale: Vector2 = Vector2(1.12, 0.88)
@export var squash_duration: float = 0.08

@export var tilt_degrees: float = 7.0
@export var tilt_duration: float = 0.06

# Flash zoom punch
@export var do_flash_zoom: bool = true
@export var zoom_amount: float = 0.05
@export var zoom_in_time: float = 0.05
@export var zoom_hold_time: float = 0.00
@export var zoom_out_time: float = 0.09

@export_category("Nodes (optional but recommended)")
@export var sprite_path: NodePath
@export var particles_path: NodePath
@export var sfx_player_path: NodePath

@export_category("AI")
@export var next_state: EnemyState
@onready var audio_stream_player_2d_2 = $"../../AudioStreamPlayer2D2"

var _damage_position: Vector2
var _direction: Vector2 = Vector2.ZERO
var _animation_finished: bool = false
var _stun_time: float = 0.0
var _invuln_timer: float = 0.0
var _tween: Tween
var _orig_modulate: Color = Color.WHITE
var _orig_scale: Vector2 = Vector2.ONE
var _orig_rotation: float = 0.0

func init() -> void:
	if not enemy.enemy_damaged.is_connected(_on_enemy_damaged):
		enemy.enemy_damaged.connect(_on_enemy_damaged)

func enter() -> void:
	_animation_finished = false
	_stun_time = 0.0
	_invuln_timer = 0.0
	enemy.invulnerable = true

	# Compute knockback away from damage source (fallback safely)
	var from_pos: Vector2 = _damage_position if _damage_position != Vector2.ZERO else (enemy.global_position + Vector2.LEFT)
	_direction = enemy.global_position.direction_to(from_pos)
	if _direction == Vector2.ZERO:
		_direction = Vector2.LEFT
	enemy.set_direction(_direction)
	enemy.velocity = -_direction * knockback_speed

	# Animation (one-shot finished)
	if anim_name != "":
		enemy.update_animation(anim_name)
		if not enemy.animation_player.animation_finished.is_connected(_on_animation_finished):
			enemy.animation_player.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

	# Cache visuals and apply juice
	_cache_visual_defaults()
	_apply_hit_juice()

func exit() -> void:
	enemy.invulnerable = false
	if enemy.animation_player.animation_finished.is_connected(_on_animation_finished):
		enemy.animation_player.animation_finished.disconnect(_on_animation_finished)
	if _tween and _tween.is_running():
		_tween.kill()
	_restore_visual_defaults()

func process(delta: float) -> EnemyState:
	_stun_time += delta
	_invuln_timer += delta

	# Grace window ends
	if enemy.invulnerable and _invuln_timer >= grace_invuln_duration:
		enemy.invulnerable = false

	# Smoothly damp knockback toward 0
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, decelerate_speed * delta)

	var min_done: bool = _stun_time >= min_stun_time
	var fail_safe: bool = _stun_time >= max_stun_time
	if (_animation_finished and min_done) or fail_safe:
		return next_state

	return null

func physics(_delta: float) -> EnemyState:
	return null

func _on_enemy_damaged(hurt_box: HurtBox) -> void:
	
	_damage_position = hurt_box.global_position

	# Optional camera shake on impact
	if do_screen_shake:
		if "shake_camera" in PlayerManager:
			# PlayerManager.shake_camera(shake_amplitude, shake_duration)
			PlayerManager.shake_camera()

	# Global hit-pause first
	if do_hit_pause:
		_request_hit_pause(hit_pause_scale, hit_pause_duration, hit_pause_extend_on_overlap)

	# Camera flash zoom punch
	if do_flash_zoom:
		var cz: Node = get_node_or_null("/root/CameraZoomPunch")
		if cz and cz.has_method("punch"):
			cz.punch(zoom_amount, zoom_in_time, zoom_hold_time, zoom_out_time)

	# Re-stun / refresh if allowed
	if refresh_on_hit:
		state_machine.change_state(self)
	else:
		# Nudge direction/velocity even if not fully re-stunning
		var dir: Vector2 = enemy.global_position.direction_to(_damage_position)
		if dir == Vector2.ZERO:
			dir = Vector2.LEFT
		enemy.velocity = -dir * knockback_speed * 0.6

	# Flash / squash again if we didn’t re-enter
	if not refresh_on_hit:
		_reapply_impact_juice_only()

func _on_animation_finished(_a: StringName) -> void:
	_animation_finished = true

# ------------ Juice helpers ------------

func _cache_visual_defaults() -> void:
	var sprite: CanvasItem = get_node_or_null(sprite_path) as CanvasItem
	if sprite:
		_orig_modulate = sprite.modulate
		_orig_scale = sprite.get_scale()
		_orig_rotation = sprite.rotation

func _restore_visual_defaults() -> void:
	var sprite: CanvasItem = get_node_or_null(sprite_path) as CanvasItem
	if sprite:
		sprite.modulate = _orig_modulate
		sprite.set_scale(_orig_scale)
		sprite.rotation = _orig_rotation

func _apply_hit_juice() -> void:
	var sprite: CanvasItem = get_node_or_null(sprite_path) as CanvasItem
	var particles: GPUParticles2D = get_node_or_null(particles_path) as GPUParticles2D
	var sfx: AudioStreamPlayer = get_node_or_null(sfx_player_path) as AudioStreamPlayer

	if particles:
		particles.restart()
	if sfx:
		sfx.play()

	if sprite:
		if _tween and _tween.is_running():
			_tween.kill()
		_tween = create_tween().set_parallel(true)

		if do_flash:
			sprite.modulate = _orig_modulate
			_tween.tween_property(sprite, "modulate", flash_color, 0.0)
			_tween.tween_property(sprite, "modulate", _orig_modulate, flash_duration)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		if do_squash:
			sprite.set_scale(_orig_scale)
			var squash: Vector2 = Vector2(_orig_scale.x * squash_scale.x, _orig_scale.y * squash_scale.y)
			_tween.tween_property(sprite, "scale", squash, 0.0)
			_tween.tween_property(sprite, "scale", _orig_scale, squash_duration)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

		if tilt_degrees != 0.0:
			sprite.rotation = deg_to_rad(signf(enemy.velocity.x)) * -tilt_degrees
			_tween.tween_property(sprite, "rotation", _orig_rotation, tilt_duration)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _reapply_impact_juice_only() -> void:
	_apply_hit_juice()

# ------------ Hit Pause (global manager + safe fallback) ------------

func _request_hit_pause(scale: float, duration: float, extend: bool) -> void:
	var hp: Node = get_node_or_null("/root/HitPause")
	if hp and hp.has_method("request"):
		hp.request(clamp(scale, 0.0, 1.0), max(duration, 0.0), extend)
	else:
		_local_hit_pause(scale, duration)

var __local_pause_active: bool = false
func _local_hit_pause(time_scale: float, duration: float) -> void:
	if __local_pause_active:
		return
	__local_pause_active = true
	var prev: float = Engine.time_scale
	Engine.time_scale = clamp(time_scale, 0.0, 1.0)
	var t: SceneTreeTimer = get_tree().create_timer(max(duration, 0.0), false, true)
	await t.timeout
	Engine.time_scale = prev
	__local_pause_active = false
