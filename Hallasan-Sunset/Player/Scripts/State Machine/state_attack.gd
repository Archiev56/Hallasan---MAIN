class_name State_Attack
extends State

var attacking : bool = false
var can_combo : bool = false
var combo_requested : bool = false
var combo_step : int = 0  # Tracks combo step (0 = first attack, then 1 and 2)
var stored_attack_direction : Vector2  # Store the direction when attack starts
@onready var attack_animation_player = $"../../Sprite2D/AttackEffectSprite/AnimationPlayer"
@export var attack_sound : AudioStream
@export_range(0,1,0.05) var decelerate_speed : float = 0.1

# Kept for inspector compatibility; no longer used for backward motion
@export var drawback_force : float = 150.0
@export var thrust_force : float = 300.0      # Forward lunge impulse per hit
@export var drawback_duration : float = 0.08  # Unused now
@export var thrust_duration : float = 0.12    # Optional smoothing time (not required)
@onready var attack_effect_sprite = $"../../Sprite2D/AttackEffectSprite"

# === Crit settings ===
@export_range(0.0, 1.0, 0.01) var crit_chance : float = 0.15
@export var crit_multiplier : float = 2.0
@export var crit_popup_time : float = 1.5

@onready var idle : State = $"../Idle"
@onready var walk : State = $"../Walk"
@onready var attack_timer = $"../../Timers/AttackTimer"
@onready var animation_player : AnimationPlayer = $"../../AnimationPlayer"
@onready var attack_anim : AnimationPlayer = $"../../Sprite2D/AttackEffectSprite/AnimationPlayer"
@onready var audio : AudioStreamPlayer2D = $"../../Audio/AudioStreamPlayer2D"
@onready var hurt_box : HurtBox = $"../../Interactions/HurtBox"

# === per-swing crit tracking ===
var _pending_crit_popup: bool = false
var _hit_confirmed_this_swing: bool = false
var _using_area_entered_fallback: bool = false

func enter() -> void:
	attacking = true
	can_combo = false
	combo_requested = false
	_pending_crit_popup = false
	_hit_confirmed_this_swing = false
	player.UpdateAnimation("attack")

	# Connect hit confirmation once per entry
	_connect_hit_confirm_signal()

	# Update attack effect sprite with direction and combo step
	attack_effect_sprite.cardinal_direction = player.cardinal_direction
	attack_effect_sprite.UpdateAnimation("attack", combo_step)

	# Store the attack direction when entering the state
	stored_attack_direction = _determine_attack_direction()

	# Start or continue combo
	if combo_step == 0 or attack_timer.is_stopped():
		combo_step = 0
	else:
		combo_step += 1

	# Play main attack animation
	animation_player.play("attack_" + player.AnimDirection() + ("_" + str(combo_step) if combo_step > 0 else ""))
	attack_timer.start()
	animation_player.animation_finished.connect(_end_attack)

	# Apply a forward lunge immediately for snappy feel
	_apply_forward_lunge()

	# Enable the hit after a brief windup and set damage roll (±1 variance + crit)
	await get_tree().create_timer(0.075).timeout
	if attacking:
		var roll := _roll_attack_damage()
		hurt_box.damage = roll["damage"]
		_pending_crit_popup = roll["crit"]   # show only if we actually land a hit
		_hit_confirmed_this_swing = false
		hurt_box.monitoring = true
	await get_tree().create_timer(0.1).timeout
	can_combo = true

# --- signal wiring for hit confirm ---
func _connect_hit_confirm_signal() -> void:
	_using_area_entered_fallback = false
	# Prefer a custom "hit" or "hit_confirmed" signal if your HurtBox exposes one
	if hurt_box.has_signal("hit"):
		if not hurt_box.hit.is_connected(_on_hurt_box_landed_hit):
			hurt_box.hit.connect(_on_hurt_box_landed_hit)
	elif hurt_box.has_signal("hit_confirmed"):
		if not hurt_box.hit_confirmed.is_connected(_on_hurt_box_landed_hit):
			hurt_box.hit_confirmed.connect(_on_hurt_box_landed_hit)
	else:
		# Fallback: rely on Area2D contact
		_using_area_entered_fallback = true
		if not hurt_box.area_entered.is_connected(_on_hurt_box_area_entered):
			hurt_box.area_entered.connect(_on_hurt_box_area_entered)

func _disconnect_hit_confirm_signal() -> void:
	if hurt_box.has_signal("hit") and hurt_box.hit.is_connected(_on_hurt_box_landed_hit):
		hurt_box.hit.disconnect(_on_hurt_box_landed_hit)
	if hurt_box.has_signal("hit_confirmed") and hurt_box.hit_confirmed.is_connected(_on_hurt_box_landed_hit):
		hurt_box.hit_confirmed.disconnect(_on_hurt_box_landed_hit)
	if _using_area_entered_fallback and hurt_box.area_entered.is_connected(_on_hurt_box_area_entered):
		hurt_box.area_entered.disconnect(_on_hurt_box_area_entered)

# Called when a hit is confirmed via custom signal (no params needed)
func _on_hurt_box_landed_hit() -> void:
	_try_show_crit_popup_once()

# Fallback: called when our hurt box touches another area
func _on_hurt_box_area_entered(area: Area2D) -> void:
	# Skip self
	if area == hurt_box:
		return
	# If enemies' receivers are HurtBox, this keeps it specific
	if area is HurtBox and area != hurt_box:
		_try_show_crit_popup_once()
		return
	# Otherwise, assume anything not owned by us could be a valid hit
	if area.get_owner() != player:
		_try_show_crit_popup_once()

func _try_show_crit_popup_once() -> void:
	if not attacking:
		return
	if _hit_confirmed_this_swing:
		return
	_hit_confirmed_this_swing = true
	if _pending_crit_popup:
		_show_crit_popup()

# Simple forward lunge: adds a small impulse in stored attack direction.
# Uses current velocity model (Player does move_and_slide() elsewhere).
func _apply_forward_lunge(multiplier: float = 1.0) -> void:
	var dir := stored_attack_direction
	if dir == Vector2.ZERO:
		return
	player.velocity += dir * thrust_force * multiplier

# Roll base damage with ±1 variance and optional crit
func _roll_attack_damage() -> Dictionary:
	var base := player.attack + PlayerManager.INVENTORY_DATA.get_attack_bonus()
	var variance := randi_range(-1, 1)  # -1, 0, +1
	var dmg := clampi(base + variance, 1, 1_000_000)

	var crit := randf() < crit_chance
	if crit:
		dmg = int(round(dmg * crit_multiplier))

	return {"damage": dmg, "crit": crit}

# Simple on-screen popup for crits (top-center HUD float)
func _show_crit_popup() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var layer := scene.get_node_or_null("CritPopupLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "CritPopupLayer"
		scene.add_child(layer)

	var label := Label.new()
	label.text = "CRITICAL HIT!"
	label.modulate = Color(1.0, 0.85, 0.2, 1.0)
	label.add_theme_font_size_override("font_size", 48)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	layer.add_child(label)

	var vp_size := get_viewport().get_visible_rect().size
	label.position = Vector2(vp_size.x * 0.5 - label.size.x * 0.5, 60.0)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 22.0, crit_popup_time).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, crit_popup_time).set_ease(Tween.EASE_OUT)
	await tw.finished
	if is_instance_valid(label):
		label.queue_free()

func _determine_attack_direction() -> Vector2:
	if player.direction != Vector2.ZERO:
		return player.direction.normalized()

	var anim_name = "attack_" + player.AnimDirection()

	if "up" in anim_name:
		if "right" in anim_name:
			return Vector2(1, -1).normalized()
		elif "left" in anim_name:
			return Vector2(-1, -1).normalized()
		else:
			return Vector2.UP
	elif "down" in anim_name:
		if "right" in anim_name:
			return Vector2(1, 1).normalized()
		elif "left" in anim_name:
			return Vector2(-1, 1).normalized()
		else:
			return Vector2.DOWN
	elif "side" in anim_name:
		# You use LEFT sprites for "side" and flip to face RIGHT via scale.x.
		# Left is scale.x == 1, Right is scale.x == -1.
		if player.sprite.scale.x < 0.0:
			return Vector2.RIGHT
		else:
			return Vector2.LEFT
	elif "left" in anim_name:
		return Vector2.LEFT
	elif "right" in anim_name:
		return Vector2.RIGHT

	return Vector2.DOWN

func _apply_movement_force(_force: Vector2) -> void:
	# Legacy hook kept to avoid breaking references; not used anymore.
	pass

func _get_attack_direction() -> Vector2:
	return stored_attack_direction

func exit() -> void:
	if animation_player.animation_finished.is_connected(_end_attack):
		animation_player.animation_finished.disconnect(_end_attack)
	_disconnect_hit_confirm_signal()
	attacking = false
	hurt_box.monitoring = false
	can_combo = false
	combo_requested = false
	_pending_crit_popup = false
	_hit_confirmed_this_swing = false

func Process(_delta : float) -> State:
	player.velocity -= player.velocity * decelerate_speed * _delta
	if not attacking:
		if player.direction == Vector2.ZERO:
			return idle
		else:
			return walk
	return null

func Physics(_delta : float) -> State:
	return null

func handle_input(_event: InputEvent) -> State:
	if _event.is_action_pressed("attack"):
		combo_requested = true
	return null

func _end_attack(_newAnimName : String) -> void:
	if can_combo and combo_requested:
		if combo_step == 0:
			# Second hit (combo)
			combo_step = 1
			animation_player.play("attack_" + player.AnimDirection() + "_1")

			# Update effect sprite for combo step
			attack_effect_sprite.cardinal_direction = player.cardinal_direction
			attack_effect_sprite.UpdateAnimation("attack", combo_step)

			var combo_multiplier = 1.0 + combo_step * 0.3
			# Forward lunge again for the combo follow-up (slightly stronger)
			_apply_forward_lunge(combo_multiplier)

			# Second hit: roll damage again (variance + crit)
			await get_tree().create_timer(0.075).timeout
			var roll := _roll_attack_damage()
			hurt_box.damage = roll["damage"]
			_pending_crit_popup = roll["crit"]
			_hit_confirmed_this_swing = false
			hurt_box.monitoring = true
		elif combo_step == 1:
			combo_step = 0
			state_machine.change_state(idle)
			return

		return
	else:
		combo_step = 0
		await get_tree().create_timer(0.1).timeout
		state_machine.change_state(idle)

	attacking = false
	combo_requested = false
	hurt_box.monitoring = false
