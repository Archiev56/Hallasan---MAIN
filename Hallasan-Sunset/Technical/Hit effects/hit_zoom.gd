extends Node
class_name CameraZoomPunch_

const MAX_AMOUNT: float      = 0.22
const MAX_TOTAL_TIME: float  = 0.4
const COALESCE_WINDOW: float = 0.06
const COOLDOWN: float        = 0.06

var _active: bool = false
var _tween: Tween
var _orig_zoom: Vector2 = Vector2.ONE
var _start_time: float = 0.0
var _peak_time: float = 0.0
var _resume_time: float = 0.0
var _cooldown_until: float = 0.0
var _current_peak_amount: float = 0.0

func punch(amount: float = 0.10, in_time: float = 0.05, hold_time: float = 0.00, out_time: float = 0.08) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _cooldown_until:
		return

	amount = clamp(amount, 0.0, MAX_AMOUNT)
	in_time = max(in_time, 0.0)
	hold_time = max(hold_time, 0.0)
	out_time = max(out_time, 0.0)

	var total: float = in_time + hold_time + out_time
	if total > MAX_TOTAL_TIME:
		var s: float = MAX_TOTAL_TIME / total
		in_time *= s
		hold_time *= s
		out_time *= s
		total = MAX_TOTAL_TIME

	var cam: Camera2D = _get_camera()
	if cam == null:
		return

	# Coalesce early hits into one peak
	if _active:
		if now - _start_time <= COALESCE_WINDOW:
			if amount > _current_peak_amount:
				_current_peak_amount = amount
				var remaining_in: float = max(0.015, max(0.0, _peak_time - now))
				var remaining_total: float = max(0.03, max(0.0, _resume_time - now))
				var rem_hold_out: float = max(0.0, remaining_total - remaining_in)
				_rebuild_from_current(cam, remaining_in, rem_hold_out)
		return

	_active = true
	_current_peak_amount = amount
	_start_time = now
	_peak_time = now + in_time
	_resume_time = now + total

	_orig_zoom = cam.zoom
	_build_tween(cam, amount, in_time, hold_time, out_time)
	_finish_after(total)

func _build_tween(cam: Camera2D, amount: float, in_time: float, hold_time: float, out_time: float) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(false)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var punch_zoom: Vector2 = Vector2.ONE * (1.0 + amount)

	_tween.tween_property(cam, "zoom", punch_zoom, in_time)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	if hold_time > 0.0:
		_tween.tween_interval(hold_time)

	_tween.tween_property(cam, "zoom", _orig_zoom, out_time)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _rebuild_from_current(cam: Camera2D, new_in_time: float, new_hold_out_time: float) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(false)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var target: Vector2 = Vector2.ONE * (1.0 + _current_peak_amount)

	_tween.tween_property(cam, "zoom", target, new_in_time)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	if new_hold_out_time > 0.0:
		var hold: float = min(0.01, new_hold_out_time * 0.25)
		if hold > 0.0:
			_tween.tween_interval(hold)
		var out_time: float = max(0.02, new_hold_out_time - hold)
		_tween.tween_property(cam, "zoom", _orig_zoom, out_time)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		_tween.tween_property(cam, "zoom", _orig_zoom, 0.04)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _finish_after(total_time: float) -> void:
	var t: SceneTreeTimer = get_tree().create_timer(total_time, false, true)
	await t.timeout
	_active = false
	_cooldown_until = Time.get_ticks_msec() / 1000.0 + COOLDOWN
	var cam: Camera2D = _get_camera()
	if cam:
		cam.zoom = _orig_zoom

func _get_camera() -> Camera2D:
	return get_viewport().get_camera_2d()
