extends Node2D

enum WeatherType { CLEAR, RAIN, WIND, STORM }

@export var current_weather: WeatherType = WeatherType.CLEAR
@export var weather_change_interval: float = 60.0

# Nodes
@onready var rain_anim_player = $Rain/AnimationPlayer
@onready var rain_sprite = $Rain/Rain

@onready var leaf_particles = $MagicLeaves
@onready var wind_particles = $Wind

@onready var lightning_sprite = $Lightning/Sprite2D
@onready var lightning_anim_player = $Lightning/AnimationPlayer

# Add a reference to a Timer under $Lightning (name it LightningTimer)
@onready var lightning_timer = $Lightning/LightningTimer

var _time_since_last_change = 0.0

func _ready():
	set_weather(current_weather)
	if lightning_timer:
		lightning_timer.timeout.connect(_on_lightning_timer_timeout)

func _process(delta):
	_time_since_last_change += delta
	if _time_since_last_change >= weather_change_interval:
		_time_since_last_change = 0
		randomize_weather()


func randomize_weather():
	var new_weather = WeatherType.values()[randi() % WeatherType.size()]
	set_weather(new_weather)

func set_weather(weather: WeatherType) -> void:
	current_weather = weather

	match weather:
		WeatherType.CLEAR:
			stop_rain()
			leaf_particles.emitting = true
			wind_particles.emitting = false
			stop_lightning()

		WeatherType.RAIN:
			start_rain()
			leaf_particles.emitting = false
			wind_particles.emitting = false
			stop_lightning()

		WeatherType.WIND:
			stop_rain()
			leaf_particles.emitting = true
			wind_particles.emitting = true
			stop_lightning()

		WeatherType.STORM:
			start_rain()
			leaf_particles.emitting = false
			wind_particles.emitting = true
			start_lightning()

# === WEATHER HELPERS ===

func start_rain():
	if rain_anim_player.has_animation("Rainfall"):
		rain_sprite.visible = true
		rain_anim_player.play("Rainfall")

func stop_rain():
	rain_anim_player.stop()
	rain_sprite.visible = false

func start_lightning():
	if lightning_anim_player.has_animation("flash"):
		lightning_sprite.visible = true
		randomize_lightning_timer()
	

func stop_lightning():
	if lightning_timer:
		lightning_timer.stop()
	lightning_anim_player.stop()
	lightning_sprite.visible = false

func randomize_lightning_timer():
	if lightning_timer:
		lightning_timer.wait_time = randf_range(2.0, 5.0)
		lightning_timer.start()

func _on_lightning_timer_timeout():
	# Randomize lightning position on screen
	var viewport_size = get_viewport().get_visible_rect().size
	var random_position = Vector2(
		randf_range(0, viewport_size.x),
		randf_range(0, viewport_size.y * 0.6)  # top-biased for realism
	)
	$Lightning.global_position = random_position

	# Optional: slight visual variety
	$Lightning.scale = Vector2.ONE * randf_range(0.8, 1.2)
	$Lightning.rotation = randf_range(-0.1, 0.1)

	if lightning_anim_player.has_animation("flash"):
		lightning_anim_player.play("flash")

	randomize_lightning_timer()
