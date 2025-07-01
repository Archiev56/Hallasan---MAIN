class_name PlayerAbilities
extends Node
# ============================================================
#  CONSTANTS & PRELOADS
# ============================================================
const BOOMERANG  = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist.tscn")
const ARROW      = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist_projectile/fist_projectile.tscn")
const SPIKE      = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist Spike/Fist Spike.tscn")
const AIR_STRIKE = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist Air Strike/Fist Air Strike.tscn")

# ============================================================
#  ONREADY NODES
# ============================================================
@onready var animation_player        = $"../AnimationPlayer"
@onready var smash_animation_player  = $"../Sprite2D/Smash Effect/Smash Effect/AnimationPlayer"
@onready var hurt_box: HurtBox       = $"../Interactions/HurtBox"
@onready var player_sprite: Sprite2D = $"../Sprite2D"      # kept for reference – never rotated

# ============================================================
#  STATE
# ============================================================
var abilities := ["BOOMERANG", "GRAPPLE", "BOW", "BOMB", "AIR_STRIKE"]
var selected_ability: int = 0

enum ActionState { IDLE, FIRING, AIMING }
var action_state: ActionState = ActionState.IDLE

var player: Player
var active_boomerangs: Array = []
var last_throw_direction := Vector2.RIGHT

# Arrow
var can_fire_arrow := true
var is_aiming      := false
var aim_direction  := Vector2.RIGHT
var aim_line: Line2D
var min_aim_time   := 0.2
var max_aim_time   := 2.0
var aim_start_time := 0.0
var aim_power      := 0.0

# Time-scale
var normal_time_scale := 1.0
var aim_time_scale    := 0.3
var time_scale_transition_speed := 3.0

# Recoil
var recoil_force    := 150.0
var recoil_duration := 0.15

# ============================================================
#  READY
# ============================================================
func _ready() -> void:
	player = PlayerManager.player
	PlayerHud.update_arrow_count(player.arrow_count)
	PlayerHud.update_bomb_count(player.bomb_count)
	_setup_aim_line()

func _setup_aim_line() -> void:
	aim_line = Line2D.new()
	aim_line.width = 3.0
	aim_line.default_color = Color.YELLOW
	aim_line.visible = false
	player.add_child(aim_line)

# ============================================================
#  INPUT
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	# swap ability any time
	if event.is_action_pressed("switch_ability"):
		_toggle_ability()
		return
	
	# bow handling
	if selected_ability == 2:
		if event.is_action_pressed("ability") and can_fire_arrow:
			_start_aiming()
		elif event.is_action_released("ability") and is_aiming:
			_fire_arrow()
		return
	
	# other abilities
	if event.is_action_pressed("ability"):
		match selected_ability:
			0:
				_fire_fist()
				player.UpdateAnimation("attack")
			1:
				animation_player.play("Hands_Smash")
				player.UpdateAnimation("Hands_Smash")
				var smash_scene = preload("res://Hallasan-Sunset/Player/Technical/Abilities/Fist Smash/smash_effect.tscn")
				var smash       = smash_scene.instantiate()
				get_tree().current_scene.add_child(smash)
				smash.global_position = player.global_position
				smash.get_node("Smash Effect/AnimationPlayer").play("Smash_effect")
				player.velocity = Vector2.ZERO
			3:
				animation_player.play("Summon")
				_spawn_spike()
				player.UpdateAnimation("attack")
			4:
				animation_player.play("Summon")
				_air_strike()
				player.UpdateAnimation("attack")

# ============================================================
#  AIMING
# ============================================================
func _start_aiming() -> void:
	if not can_fire_arrow or action_state != ActionState.IDLE:
		return
	is_aiming      = true
	action_state   = ActionState.AIMING
	aim_start_time = _get_now_seconds()
	aim_direction  = last_throw_direction.normalized()
	aim_line.visible = true
	
	if player.has_method("set_aiming_mode"):
		player.set_aiming_mode(true)
	else:
		player.velocity = Vector2.ZERO
	
	create_tween().tween_method(_set_time_scale, Engine.time_scale, aim_time_scale, 0.5)
	player.UpdateAnimation("aim")

func _set_time_scale(v: float) -> void:
	Engine.time_scale = v

func _update_aiming() -> void:
	if not is_aiming:
		return
	
	if player.has_method("set_aiming_mode"):
		player.set_aiming_mode(true)
	else:
		player.velocity = Vector2.ZERO
	
	var aim_in := Vector2(
		int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")),
		int(Input.is_action_pressed("ui_down"))  - int(Input.is_action_pressed("ui_up"))
	)
	if aim_in != Vector2.ZERO:
		aim_direction = _normalize_to_8_dirs(aim_in)
	
	var hold = _get_now_seconds() - aim_start_time
	aim_power = clamp((hold - min_aim_time) / (max_aim_time - min_aim_time), 0.0, 1.0)
	_update_aim_line()

func _normalize_to_8_dirs(v: Vector2) -> Vector2:
	var step = PI / 4.0
	return Vector2.from_angle(round(v.angle() / step) * step)

func _update_aim_line() -> void:
	if not aim_line or not is_aiming:
		return
	aim_line.clear_points()

	var base_len = 50.0
	var mult     = 1.0 + aim_power * 1.5
	var end_pos  = aim_direction * base_len * mult
	
	var segs = 5
	for i in range(segs):
		var t1 = float(i) / segs
		var t2 = float(i + 0.6) / segs
		if t2 <= 1.0:
			var p1 = Vector2.ZERO.lerp(end_pos, t1)
			var p2 = Vector2.ZERO.lerp(end_pos, t2)
			if i == 0: aim_line.add_point(p1)
			aim_line.add_point(p2)
	
	var c = 0.5 + aim_power * 0.5
	aim_line.default_color = Color(1.0, c, 0.0, 0.8)

# ============================================================
#  FIRE ARROW
# ============================================================
func _fire_arrow() -> void:
	if not is_aiming or not can_fire_arrow:
		return
	
	var hold = _get_now_seconds() - aim_start_time
	if hold < min_aim_time:
		_cancel_aiming()
		return
	
	can_fire_arrow = false
	is_aiming      = false
	action_state   = ActionState.FIRING
	aim_line.visible = false
	
	if player.has_method("set_aiming_mode"):
		player.set_aiming_mode(false)
	
	create_tween().tween_method(_set_time_scale, Engine.time_scale, normal_time_scale, 0.1)
	
	# -------- instantiate arrow ----------
	var arrow = ARROW.instantiate()
	player.get_parent().add_child(arrow)
	arrow.global_position = player.global_position
	arrow.direction       = aim_direction
	# --------------------------------------
	
	# -------- rotation + flip logic -------
	if arrow.has_node("Sprite2D"):
		var spr: Sprite2D = arrow.get_node("Sprite2D")
		spr.rotation = aim_direction.angle()
		
		# horizontal flip for all left directions
		spr.flip_h = aim_direction.x < 0
		
		# extra vertical flip ONLY on right-hand diagonals
		spr.flip_v = (aim_direction.x > 0 and aim_direction.y != 0)
	else:
		arrow.rotation = aim_direction.angle()
		var sx = abs(arrow.scale.x)
		arrow.scale.x = -sx if aim_direction.x < 0 else sx
		if aim_direction.x > 0 and aim_direction.y != 0:
			arrow.scale.y *= -1
	# --------------------------------------
	
	if arrow.has_method("set_power"):
		arrow.set_power(1.0 + aim_power)
	elif arrow.has_method("set_speed_multiplier"):
		arrow.set_speed_multiplier(1.0 + aim_power * 0.5)
	
	arrow.fire()
	_apply_recoil()
	player.UpdateAnimation("attack")
	action_state = ActionState.IDLE
	
	await get_tree().create_timer(3.0).timeout
	can_fire_arrow = true

func _cancel_aiming() -> void:
	is_aiming     = false
	action_state  = ActionState.IDLE
	aim_line.visible = false
	if player.has_method("set_aiming_mode"):
		player.set_aiming_mode(false)
	create_tween().tween_method(_set_time_scale, Engine.time_scale, normal_time_scale, 0.3)

# ============================================================
#  RECOIL
# ============================================================
func _apply_recoil() -> void:
	var dir = -aim_direction.normalized()
	var vel = dir * recoil_force
	player.velocity += vel
	
	var start_vel = player.velocity
	create_tween()\
		.tween_property(player, "velocity", start_vel * 0.2, recoil_duration)\
		.from(start_vel)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

# ============================================================
#  PROCESS
# ============================================================
func _process(delta: float) -> void:
	if Engine.time_scale != normal_time_scale and not is_aiming:
		Engine.time_scale = lerp(Engine.time_scale, normal_time_scale, time_scale_transition_speed * delta)
		if abs(Engine.time_scale - normal_time_scale) < 0.01:
			Engine.time_scale = normal_time_scale
	
	if is_aiming:
		_update_aiming()
		return
	
	var move := Vector2(
		int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")),
		int(Input.is_action_pressed("ui_down"))  - int(Input.is_action_pressed("ui_up"))
	)
	if move != Vector2.ZERO:
		last_throw_direction = move.normalized()

# ============================================================
#  OTHER ABILITIES
# ============================================================
func _toggle_ability() -> void:
	if selected_ability == 2 and is_aiming:
		_cancel_aiming()
	selected_ability = wrapi(selected_ability + 1, 0, abilities.size())
	PlayerHud.update_ability_ui(selected_ability)

func _fire_fist() -> void:
	if active_boomerangs.size() >= 2:
		action_state = ActionState.IDLE
		return
	
	action_state = ActionState.FIRING
	var b := BOOMERANG.instantiate() as Boomerang
	player.add_sibling(b)
	b.global_position = player.global_position + Vector2(10 if active_boomerangs.size() == 0 else -10, 0)
	
	var dir = last_throw_direction
	if active_boomerangs.size() == 1:
		var sprite = b.get_node("Sprite2D")
		var anim   = b.get_node("AnimationPlayer")
		if abs(dir.y) > abs(dir.x):
			anim.play("fist_up" if dir.y < 0 else "fist_down")
		else:
			anim.play("fist_side")
		sprite.scale.x = -1 if dir.x < 0 else 1
	
	b.throw(dir)
	active_boomerangs.append(b)
	b.connect("tree_exited", Callable(self, "_on_boomerang_freed").bind(b))
	action_state = ActionState.IDLE

func _on_boomerang_freed(b: Boomerang) -> void:
	active_boomerangs.erase(b)

func _spawn_spike() -> void:
	var enemy = _closest_enemy()
	var spike = SPIKE.instantiate()
	player.get_parent().add_child(spike)
	spike.global_position = enemy.global_position if enemy else player.global_position

func _air_strike() -> void:
	var enemy  = _closest_enemy()
	var strike = AIR_STRIKE.instantiate()
	player.get_parent().add_child(strike)
	var off = Vector2(-17, -38)
	strike.global_position = (enemy.global_position if enemy else player.global_position) + off

func _closest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for e in get_tree().get_nodes_in_group("Enemy"):
		if e is Node2D:
			var d = player.global_position.distance_to(e.global_position)
			if d < best_dist:
				best_dist = d
				best = e
	return best

# ============================================================
#  UTIL
# ============================================================
func _get_now_seconds() -> float:
	var t = Time.get_time_dict_from_system()
	return t["minute"] * 60 + t["second"]
