extends Node
class_name Hit_Pause

# --- Micro-pause policy (tweak to taste) ---
const MIN_SCALE: float    = 0.20     # never go "harder" than this (0 = full stop)
const MAX_DURATION: float = 0.045    # hard cap total pause time in seconds (45ms)
const COOLDOWN: float     = 0.080    # ignore new requests for 80ms after resume

var _active: bool = false
var _resume_time: float = 0.0
var _prev_time_scale: float = 1.0
var _current_scale: float = 1.0
var _cooldown_until: float = 0.0

func request(scale: float, duration: float, extend: bool = false) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	# Respect cooldown to keep pauses "minimal"
	if now < _cooldown_until:
		return

	# Clamp to micro-pause policy
	scale = clamp(scale, MIN_SCALE, 1.0)
	duration = clamp(duration, 0.0, MAX_DURATION)

	if _active:
		# With micro-pause design, we generally DO NOT extend.
		# If you ever pass extend=true, we still cap to MAX_DURATION.
		if extend:
			_resume_time = min(now + MAX_DURATION, max(_resume_time, now + duration))
			# If new request is "harder", apply immediately (still within MIN_SCALE cap)
			if scale < _current_scale:
				_current_scale = scale
				Engine.time_scale = _current_scale
		return

	_active = true
	_prev_time_scale = Engine.time_scale
	_current_scale = scale
	Engine.time_scale = _current_scale
	_resume_time = now + duration
	_tick_until_resume()

func _tick_until_resume() -> void:
	while _active:
		var now := Time.get_ticks_msec() / 1000.0
		var remaining := _resume_time - now
		if remaining <= 0.0:
			_active = false
			Engine.time_scale = _prev_time_scale
			_cooldown_until = Time.get_ticks_msec() / 1000.0 + COOLDOWN
			return
		var t := get_tree().create_timer(remaining, false, true) # ignore_time_scale = true
		await t.timeout
