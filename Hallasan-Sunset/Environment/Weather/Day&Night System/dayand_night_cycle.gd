extends CanvasModulate
class_name DayAndNightCycle

# One full day lasts 3,600 real seconds (1 hour).
# We keep the original 24s animation timeline (12pm->12pm) and slow it down via speed_scale.
@export var day_length_seconds: float = 3600.0        # target real-time length of a full day
@export var base_anim_length_seconds: float = 24.0     # your existing animation's length (do not change your .anim)

signal changeDayTime(dayTime: DAY_STATE)

@onready var animation_player: AnimationPlayer = $AnimationPlayer

enum DAY_STATE { DAWN, NOON, EVENING, NIGHT }

var dayTime: DAY_STATE = DAY_STATE.NOON
var previous_dayTime: DAY_STATE = DAY_STATE.NOON

# Light management properties
@export var manage_lights: bool = true
@export var light_group_name: String = "scene_lights"
@export var dawn_light_energy: float = 0.0   # 6am - lights turn off
@export var noon_light_energy: float = 0.0   # 12pm - lights off (daylight)
@export var evening_light_energy: float = 1.0 # 7pm - lights turn on
@export var night_light_energy: float = 1.0   # 12am - lights fully on

# Flicker effect properties
@export var enable_flicker: bool = true
@export var flicker_intensity: float = 0.1
@export var flicker_speed: float = 0.1333

# Animation thresholds (as percentages of total animation)
# Cycle starts at 12pm (midday). These map 12pm->7pm->12am->6am->12pm over the cycle.
@export var dawn_threshold: float = 0.75     # 6am
@export var noon_threshold: float = 0.0      # 12pm
@export var evening_threshold: float = 0.292 # ~7pm
@export var night_threshold: float = 0.5     # 12am

var scene_lights: Array[Light2D] = []
var flickering_lights: Dictionary = {}
var base_light_energy: float = 0.0

func _ready() -> void:
	add_to_group("dayAndNightCycle")

	# Slow the animation so that one full 'day' takes day_length_seconds.
	# If your base animation is 24s long, speed_scale = 24 / 3600 = 0.006666...
	if day_length_seconds > 0.0:
		animation_player.speed_scale = base_anim_length_seconds / day_length_seconds

	if manage_lights:
		find_scene_lights()
		get_tree().node_added.connect(_on_node_added)
		get_tree().node_removed.connect(_on_node_removed)

func _process(_delta: float) -> void:
	update_day_state()

func update_day_state() -> void:
	if not animation_player.is_playing():
		return

	var animation_progress = animation_player.current_animation_position / animation_player.current_animation_length
	var new_dayTime = get_day_state_from_progress(animation_progress)

	if new_dayTime != dayTime:
		previous_dayTime = dayTime
		dayTime = new_dayTime
		changeDayTime.emit(dayTime)

		if manage_lights:
			update_lights_for_state(dayTime)

func get_day_state_from_progress(progress: float) -> DAY_STATE:
	if progress >= night_threshold:
		return DAY_STATE.NIGHT
	elif progress >= evening_threshold:
		return DAY_STATE.EVENING
	elif progress >= noon_threshold:
		return DAY_STATE.NOON
	else:
		return DAY_STATE.DAWN

func find_scene_lights() -> void:
	scene_lights.clear()

	if not light_group_name.is_empty():
		var grouped_lights = get_tree().get_nodes_in_group(light_group_name)
		for light in grouped_lights:
			if light is Light2D:
				scene_lights.append(light)

	if scene_lights.is_empty():
		var all_lights = find_children("*", "Light2D", true, false)
		for light in all_lights:
			scene_lights.append(light)

	print("Found ", scene_lights.size(), " lights in the scene (PointLight2D, DirectionalLight2D, etc.)")

func update_lights_for_state(state: DAY_STATE) -> void:
	var target_energy: float

	match state:
		DAY_STATE.DAWN:
			target_energy = dawn_light_energy
		DAY_STATE.NOON:
			target_energy = noon_light_energy
		DAY_STATE.EVENING:
			target_energy = evening_light_energy
		DAY_STATE.NIGHT:
			target_energy = night_light_energy

	base_light_energy = target_energy

	for light in scene_lights:
		if is_instance_valid(light):
			stop_flicker_for_light(light)
			if target_energy > 0.0 and enable_flicker:
				start_flicker_for_light(light, target_energy)
			else:
				var tween = create_tween()
				tween.tween_property(light, "energy", target_energy, 0.5)
				light.scale = Vector2.ONE

# Smooth light transition based on animation progress
func update_lights_smooth() -> void:
	if not manage_lights or scene_lights.is_empty():
		return

	var progress = animation_player.current_animation_position / animation_player.current_animation_length
	var light_energy = calculate_smooth_light_energy(progress)

	for light in scene_lights:
		if is_instance_valid(light):
			light.energy = light_energy

func calculate_smooth_light_energy(progress: float) -> float:
	var normalized_progress = fmod(progress, 1.0)
	var light_curve = 0.5 + 0.5 * cos(normalized_progress * TAU)
	return light_curve * night_light_energy

func _on_node_added(node: Node) -> void:
	if node is Light2D and manage_lights:
		if light_group_name.is_empty() or node.is_in_group(light_group_name):
			scene_lights.append(node)
			if base_light_energy > 0.0 and enable_flicker:
				start_flicker_for_light(node, base_light_energy)
			else:
				node.energy = base_light_energy
				node.scale = Vector2.ONE

func _on_node_removed(node: Node) -> void:
	if node is Light2D:
		stop_flicker_for_light(node)
		scene_lights.erase(node)

# Flicker management
func start_flicker_for_light(light: Light2D, base_energy: float) -> void:
	if not is_instance_valid(light) or not enable_flicker:
		return
	stop_flicker_for_light(light)
	flickering_lights[light] = true
	flicker_light(light, base_energy)

func stop_flicker_for_light(light: Light2D) -> void:
	if light in flickering_lights:
		flickering_lights.erase(light)

func flicker_light(light: Light2D, base_energy: float) -> void:
	if not is_instance_valid(light) or light not in flickering_lights:
		return

	var min_energy = base_energy * (1.0 - flicker_intensity)
	var max_energy = base_energy * (1.0 + flicker_intensity)
	var flickered_energy = randf() * (max_energy - min_energy) + min_energy

	light.energy = flickered_energy
	light.scale = Vector2.ONE * (0.9 + flickered_energy * 0.1)

	await get_tree().create_timer(flicker_speed).timeout

	if light in flickering_lights:
		flicker_light(light, base_energy)

# Public API
func set_day_state(state: DAY_STATE) -> void:
	dayTime = state
	changeDayTime.emit(dayTime)
	if manage_lights:
		update_lights_for_state(dayTime)

func add_light_to_management(light: Light2D) -> void:
	if light not in scene_lights:
		scene_lights.append(light)
		if base_light_energy > 0.0 and enable_flicker:
			start_flicker_for_light(light, base_light_energy)
		else:
			light.energy = base_light_energy
			light.scale = Vector2.ONE

func remove_light_from_management(light: Light2D) -> void:
	stop_flicker_for_light(light)
	scene_lights.erase(light)

func get_current_day_state() -> DAY_STATE:
	return dayTime

# Enable smooth light transitions (call this if you want smoother lighting)
func enable_smooth_lighting() -> void:
	set_process(true)
	# Call update_lights_smooth() in _process instead of update_day_state() if desired.

func toggle_light_management(enabled: bool) -> void:
	manage_lights = enabled
	if enabled:
		find_scene_lights()
		update_lights_for_state(dayTime)
	else:
		for light in scene_lights:
			if is_instance_valid(light):
				stop_flicker_for_light(light)
				light.energy = 1.0
				light.scale = Vector2.ONE

func toggle_flicker(enabled: bool) -> void:
	enable_flicker = enabled
	if not enabled:
		for light in scene_lights:
			stop_flicker_for_light(light)
			if is_instance_valid(light):
				light.energy = base_light_energy
				light.scale = Vector2.ONE
	else:
		if base_light_energy > 0.0:
			for light in scene_lights:
				if is_instance_valid(light):
					start_flicker_for_light(light, base_light_energy)

# Debug helper for testing the 3,600-second (1 hour) cycle
func print_current_time_debug() -> void:
	if not animation_player.is_playing():
		return

	var progress = animation_player.current_animation_position / animation_player.current_animation_length
	var current_seconds = animation_player.current_animation_position / animation_player.speed_scale  # real seconds into the slowed cycle

	var total_hours = progress * 24.0
	var hour = int(12 + total_hours) % 24
	var minute = int((total_hours - floor(total_hours)) * 60.0)

	var lights_on = (dayTime == DAY_STATE.EVENING or dayTime == DAY_STATE.NIGHT)
	var flicker_status = "FLICKER" if (lights_on and enable_flicker) else "STEADY"

	print("Real: %.1fs | AnimPos: %.1fs | Game Time: %02d:%02d | State: %s | Lights: %s %s" % [
		current_seconds,
		animation_player.current_animation_position,
		hour,
		minute,
		DAY_STATE.keys()[dayTime],
		"ON" if lights_on else "OFF",
		flicker_status if lights_on else ""
	])

func enable_debug_output() -> void:
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(print_current_time_debug)
	timer.autostart = true
	add_child(timer)
