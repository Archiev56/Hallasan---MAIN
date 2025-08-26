extends CharacterBody2D
class_name Companion

signal direction_changed(new_direction: Vector2)
signal reached_player

# ---------------- CONFIG ----------------
@export var player_path: NodePath
@export var max_speed: float = 48.0
@export var acceleration: float = 420.0
@export var deceleration: float = 700.0
@export var follow_distance: float = 24.0
@export var rejoin_distance: float = 60.0    # small while debugging
@export var teleport_distance: float = 520.0
@export var path_refresh_time: float = 0.12

# Debug toggles
var DEBUG := true
var USE_NAV := false           # <--- set FALSE to ignore Navigation and direct-seek
var DEBUG_PRINT_EVERY := 0.25  # seconds between print batches

# -------------- NODES -------------------
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

# -------------- STATE -------------------
var player: Player
var cardinal_direction: Vector2 = Vector2.DOWN

var _path_timer := 0.0
var _last_seen_player_dir := Vector2.DOWN
var _resolve_cooldown := 0.0
var _debug_timer := 0.0

var _goal: Vector2
var _next_path: Vector2
var _has_path := false
var _moving := false
var _should_follow := false



# Only 4 cardinals; left/right share "side"
var DIR_4: Array[Vector2] = [
	Vector2.RIGHT,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.UP
]

# -------------- LIFECYCLE ---------------
func _ready() -> void:
	# Keep nav simple for debugging
	agent.avoidance_enabled = false
	agent.radius = 8.0
	agent.path_desired_distance = follow_distance
	agent.target_desired_distance = follow_distance

	_resolve_player()
	set_process(true)
	set_physics_process(true)

	if DEBUG:
		print("[Companion] READY. use_nav=%s" % [str(USE_NAV)])

func _process(delta: float) -> void:
	# Retry finding player spawned later
	if player == null:
		_resolve_cooldown -= delta
		if _resolve_cooldown <= 0.0:
			_resolve_player()
			_resolve_cooldown = 0.25

	# Redraw debug gizmos
	if DEBUG:
		queue_redraw()

func _physics_process(delta: float) -> void:
	if player == null:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		_idle_animation()
		_debug_log(delta, "no player")
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()

	# Safety tether
	if dist > teleport_distance:
		var behind := player.global_position - _safe_back_offset()
		global_position = behind
		velocity = Vector2.ZERO
		_set_facing(_last_seen_player_dir if _last_seen_player_dir != Vector2.ZERO else Vector2.DOWN)
		_idle_animation()
		_debug_log(delta, "teleport catch-up")
		return

	# Decide whether to follow
	_path_timer -= delta
	_should_follow = (dist > rejoin_distance) or (dist > follow_distance * 1.1)

	if _should_follow and _path_timer <= 0.0:
		_path_timer = path_refresh_time
		_set_destination_near_player()

	_moving = false
	_goal = player.global_position - _safe_back_offset()

	if USE_NAV:
		# PATHFIND
		_has_path = not agent.is_navigation_finished()
		if _has_path:
			_next_path = agent.get_next_path_position()
			var to_next := _next_path - global_position
			if to_next.length() > 1.0:
				var target_vel := to_next.normalized() * max_speed
				velocity = velocity.move_toward(target_vel, acceleration * delta)
				_moving = true
	else:
		# DIRECT SEEK (bypass nav)
		var to_goal := _goal - global_position
		if _should_follow and to_goal.length() > follow_distance:
			var target_vel2 := to_goal.normalized() * max_speed
			velocity = velocity.move_toward(target_vel2, acceleration * delta)
			_moving = true
		_has_path = false
		_next_path = global_position

	# Decelerate near goal if not moving
	if not _moving:
		if velocity.length() > 0.0:
			velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)

	# Facing & anim
	if velocity.length() > 0.1:
		_set_facing(velocity.normalized())
		_walk_animation()
	else:
		_idle_animation()

	move_and_slide()

	if dist <= follow_distance * 1.25:
		reached_player.emit()

	_debug_log(delta)

# -------------- PLAYER RESOLUTION --------------
func _resolve_player() -> void:
	# 1) explicit path
	if player == null and player_path != NodePath(""):
		player = get_node_or_null(player_path) as Player
	# 2) PlayerManager
	if player == null and PlayerManager.player != null:
		player = PlayerManager.player
	# 3) group "Player"
	if player == null:
		var candidates := get_tree().get_nodes_in_group("Player")
		if candidates.size() > 0:
			player = candidates[0] as Player

	if player != null:
		_last_seen_player_dir = player.cardinal_direction
		if not player.direction_changed.is_connected(_on_player_direction_changed):
			player.direction_changed.connect(_on_player_direction_changed)
		if DEBUG:
			print("[Companion] Player resolved: %s" % [player.name])
	else:
		if DEBUG and _resolve_cooldown <= 0.0:
			print("[Companion] Player NOT found yet (path/PlayerManager/'Player' group). Retrying...")

# -------------- GOAL / FACING / ANIM --------------
func _set_destination_near_player() -> void:
	var target := player.global_position - _safe_back_offset()
	agent.target_position = target

func _safe_back_offset() -> Vector2:
	var back_dir := player.cardinal_direction if player.cardinal_direction != Vector2.ZERO else _last_seen_player_dir
	if back_dir == Vector2.ZERO:
		back_dir = Vector2.DOWN
	return back_dir.normalized() * max(follow_distance * 0.85, 8.0)

func _set_facing(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	_last_seen_player_dir = dir

	# choose closest of 4
	var angle := dir.angle()
	var index := int(round(angle / TAU * DIR_4.size())) % DIR_4.size()
	var new_dir: Vector2 = DIR_4[index]

	if new_dir == cardinal_direction:
		return

	cardinal_direction = new_dir
	direction_changed.emit(new_dir)

	# flip for left/right
	if cardinal_direction == Vector2.LEFT:
		sprite.scale.x = 1
	elif cardinal_direction == Vector2.RIGHT:
		sprite.scale.x = -1

func _walk_animation() -> void:
	var name := "walk_" + _anim_dir()
	if anim.current_animation != name:
		anim.play(name)

func _idle_animation() -> void:
	var name := "idle_" + _anim_dir()
	if anim.current_animation != name:
		anim.play(name)

func _anim_dir() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "side"

func _on_player_direction_changed(new_dir: Vector2) -> void:
	if velocity.length() < 0.1:
		_set_facing(new_dir)

# -------------- DEBUG --------------
func _debug_log(delta: float, extra: String = "") -> void:
	if not DEBUG:
		return
	_debug_timer -= delta
	if _debug_timer > 0.0:
		return
	_debug_timer = DEBUG_PRINT_EVERY

	var dist_txt := "?"
	if player != null:
		dist_txt = "%.1f" % ((player.global_position - global_position).length())

	var parts := [
		"vel=%.2f" % velocity.length(),
		"follow=%s" % str(_should_follow),
		"moving=%s" % str(_moving),
		"use_nav=%s" % str(USE_NAV),
		"path=%s" % str(_has_path),
		"dist=%s" % dist_txt,
		"goal=(%.1f,%.1f)" % [_goal.x, _goal.y],
		"next=(%.1f,%.1f)" % [_next_path.x, _next_path.y]
	]
	if extra != "":
		parts.append("note=%s" % extra)
	print("[Companion] " + "; ".join(parts))
