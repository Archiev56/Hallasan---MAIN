class_name Boomerang
extends Sprite2D

# ============================================================
#  ENUMS & EXPORTS
# ============================================================
enum State { INACTIVE, THROW, RETURN }

@export var acceleration: float = 500.0
@export var max_speed: float = 400.0
@export var catch_audio: AudioStream

# Push/Pull system exports
@export var push_force: float = 120.0
@export var pull_force: float = 100.0
@export var push_range: float = 70.0
@export var shove_impulse: float = 200.0  # Initial burst of force

# ============================================================
#  STATE VARIABLES
# ============================================================
var player: Player
var direction: Vector2
var speed: float = 0
var state

# Visual/Audio
var frame_width: float = 0
var frame_height: float = 0
var frame_index: int = 0

# Push/Pull tracking
var currently_pushing: Array[PushableStatue] = []
var push_pull_mode := false  # false = push, true = pull
var is_holding_push := false  # Track if player is holding push button
var objects_in_range: Array[PushableStatue] = []  # Objects in range but not necessarily being pushed
var is_attached_to_object := false  # Whether fist is stuck to an object
var attached_object: PushableStatue = null  # The object we're attached to
var attachment_offset: Vector2 = Vector2.ZERO  # Offset from object center
var last_player_position: Vector2 = Vector2.ZERO  # Track player movement

# Visual connection line
var connection_line: Line2D = null

# ============================================================
#  ONREADY NODES
# ============================================================
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var fist_grab: Area2D = $Fist_Grab
@onready var push_area: Area2D = $PushArea  # Add this as a child node in your scene

# ============================================================
#  READY
# ============================================================
func _ready() -> void:
	visible = false
	state = State.INACTIVE
	player = PlayerManager.player
	PlayerManager.INVENTORY_DATA.equipment_changed.connect(_on_equipment_changed)
	SaveManager.game_loaded.connect(_on_equipment_changed)
	
	# Setup connection line
	_setup_connection_line()
	
	# Setup push area if it exists
	if push_area:
		push_area.body_entered.connect(_on_pushable_entered)
		push_area.body_exited.connect(_on_pushable_exited)
	else:
		# Create push area if it doesn't exist
		_setup_push_area()

# ============================================================
#  SETUP FUNCTIONS
# ============================================================
func _setup_connection_line() -> void:
	# Try to find existing Line2D in the scene first
	connection_line = get_tree().current_scene.get_node_or_null("ConnectionLine")
	
	if not connection_line:
		# Create one if it doesn't exist
		connection_line = Line2D.new()
		connection_line.name = "ConnectionLine"
		connection_line.width = 5.0  # Make it thicker for testing
		connection_line.default_color = Color.YELLOW  # More visible color for testing
		connection_line.z_index = 10  # Put it in front for testing
		get_tree().current_scene.add_child(connection_line)
		print("📏 Connection line created and added to scene")
	else:
		print("📏 Found existing connection line in scene")
	
	connection_line.visible = false

func _setup_push_area() -> void:
	push_area = Area2D.new()
	push_area.name = "PushArea"
	add_child(push_area)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = push_range
	collision.shape = shape
	push_area.add_child(collision)
	
	# Set collision layers/masks for pushable objects (layer 5)
	push_area.collision_layer = 0
	push_area.collision_mask = 16  # Layer 5 = 2^4 = 16
	
	# Connect signals
	push_area.body_entered.connect(_on_pushable_entered)
	push_area.body_exited.connect(_on_pushable_exited)

# ============================================================
#  PHYSICS PROCESS
# ============================================================
func _physics_process(delta: float) -> void:
	# Handle push/pull input
	_handle_push_pull_input()
	
	# If attached to an object, handle attachment behavior
	if is_attached_to_object and attached_object and is_instance_valid(attached_object):
		_handle_attachment_behavior()
		return
	
	if state == State.THROW:
		speed -= acceleration * delta
		position += direction * speed * delta
		if speed <= 0:
			state = State.RETURN
			push_pull_mode = true  # Switch to pull mode when returning
			_update_push_direction_for_all()
			
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
	
	# Update push/pull effects on objects
	_update_pushable_objects()
	
	# Audio and animation scaling
	var speed_ratio = speed / max_speed
	audio.pitch_scale = speed_ratio * 0.75 + 0.75
	animation_player.speed_scale = 1 + (speed_ratio * 0.25)

# ============================================================
#  THROW FUNCTION
# ============================================================
func throw(throw_direction: Vector2) -> void:
	_on_equipment_changed()
	player.UpdateAnimation("attack")
	direction = throw_direction
	speed = max_speed
	state = State.THROW
	push_pull_mode = false  # Start in push mode
	
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

# ============================================================
#  PUSH/PULL INPUT HANDLING
# ============================================================
func _handle_push_pull_input() -> void:
	if state == State.INACTIVE:
		return
		
	# Check if push/pull button is being held
	var was_holding = is_holding_push
	is_holding_push = Input.is_action_pressed("push_pull")  # Add this action to your input map
	
	# If we just started holding and have objects in range
	if is_holding_push and not was_holding and objects_in_range.size() > 0:
		# Find the closest object to attach to
		var closest_object = _get_closest_object_in_range()
		if closest_object:
			_attach_to_object(closest_object)
			_apply_initial_shove(closest_object)
	
	# If we just released the button, detach and return
	if not is_holding_push and was_holding and is_attached_to_object:
		_detach_from_object()
	
	# Update what objects are being actively pushed
	_update_active_pushing()

func _get_closest_object_in_range() -> PushableStatue:
	var closest: PushableStatue = null
	var closest_distance = INF
	
	for obj in objects_in_range:
		if is_instance_valid(obj):
			var distance = global_position.distance_to(obj.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest = obj
	
	return closest

func _attach_to_object(obj: PushableStatue) -> void:
	is_attached_to_object = true
	attached_object = obj
	attachment_offset = global_position - obj.global_position
	speed = 0  # Stop fist movement
	last_player_position = player.global_position  # Initialize player position tracking
	
	# Tell the statue to start following the player
	obj.start_following_player(player)
	
	# Show the connection line
	_show_connection_line()
	
	# Play grab animation based on direction
	_play_grab_animation()
	
	print("🔗 Fist attached to: ", obj.name)

func _play_grab_animation() -> void:
	print("🎬 _play_grab_animation() called")
	
	if not animation_player:
		print("❌ AnimationPlayer not found!")
		return
	
	print("✅ AnimationPlayer found: ", animation_player.name)
	
	# Check what animations are available
	if animation_player.has_animation_library(""):
		var library = animation_player.get_animation_library("")
		print("🎭 Available animations: ", library.get_animation_list())
	
	# Determine grab direction based on the fist's current direction or last movement
	var grab_direction: Vector2
	
	# Use the current direction if the fist was moving, otherwise use attachment offset
	if direction != Vector2.ZERO:
		grab_direction = direction
		print("📍 Using movement direction: ", direction)
	else:
		# If no movement direction, use the direction from object to fist
		grab_direction = attachment_offset.normalized()
		print("📍 Using attachment offset direction: ", grab_direction)
	
	# Determine which grab animation to play
	var grab_animation: String
	
	if abs(grab_direction.x) > abs(grab_direction.y):
		# Horizontal grab
		grab_animation = "grab_side"
	elif grab_direction.y > 0:
		# Downward grab
		grab_animation = "grab_down"
	else:
		# Upward grab
		grab_animation = "grab_up"
	
	print("🎯 Selected grab animation: ", grab_animation)
	print("🎭 Current animation: ", animation_player.current_animation)
	
	# Check if the animation exists
	if animation_player.has_animation(grab_animation):
		print("✅ Animation '", grab_animation, "' exists, playing...")
		animation_player.play(grab_animation)
		print("🎬 Animation started, current: ", animation_player.current_animation)
	else:
		print("❌ Animation '", grab_animation, "' does not exist!")
		print("🎭 Available animations: ")
		if animation_player.has_animation_library(""):
			var library = animation_player.get_animation_library("")
			for anim_name in library.get_animation_list():
				print("  - ", anim_name)
	
	print("🎬 Grab animation setup complete")

func _handle_attachment_behavior() -> void:
	if not player or not attached_object:
		return
	
	# Keep fist positioned relative to the object
	global_position = attached_object.global_position + attachment_offset
	
	# Update the visual connection line
	_update_connection_line()
	
	# The statue handles its own movement toward the player
	# We just need to update the fist position

func _detach_from_object() -> void:
	if not is_attached_to_object:
		return
		
	is_attached_to_object = false
	print("🔓 Fist detached from: ", attached_object.name if attached_object else "unknown")
	
	# Hide the connection line
	_hide_connection_line()
	
	# Stop any movement on the attached object
	if attached_object and is_instance_valid(attached_object):
		attached_object.stop_pushing()
		attached_object.stop_following_player()
	
	attached_object = null
	attachment_offset = Vector2.ZERO
	last_player_position = Vector2.ZERO
	
	# Resume normal return behavior
	if state != State.RETURN:
		state = State.RETURN
		push_pull_mode = true
	
	# Set return speed
	speed = max_speed * 0.8

func _update_active_pushing() -> void:
	# When attached, we don't use the traditional pushing system
	# Movement is handled by player movement instead
	if is_attached_to_object:
		# Clear any traditional pushing forces
		for pushable in currently_pushing:
			if is_instance_valid(pushable):
				pushable.stop_pushing()
		currently_pushing.clear()
	else:
		# Normal pushing behavior when not attached
		if is_holding_push and attached_object:
			if attached_object not in currently_pushing:
				currently_pushing.append(attached_object)
		else:
			# Stop pushing all objects if not holding button or not attached
			for pushable in currently_pushing:
				if is_instance_valid(pushable):
					pushable.stop_pushing()
			currently_pushing.clear()

func _apply_initial_shove(pushable: PushableStatue) -> void:
	var to_object = (pushable.global_position - global_position)
	var distance = to_object.length()
	if distance == 0:
		return
		
	var direction_to_object = to_object.normalized()
	
	# Apply initial shove impulse (8-directional for smooth movement)
	var impulse_force = shove_impulse
	if push_pull_mode:
		# Pull towards fist
		pushable.apply_shove(-direction_to_object * impulse_force)
	else:
		# Push away from fist  
		pushable.apply_shove(direction_to_object * impulse_force)

# ============================================================
#  PUSH/PULL SYSTEM
# ============================================================
func _on_pushable_entered(body: Node2D) -> void:
	if body is PushableStatue and body not in objects_in_range:
		objects_in_range.append(body)
		print("🎯 Object in push/pull range: ", body.name)
		
		# If we're NOT holding the push button, apply a regular shove on contact
		if not is_holding_push:
			_apply_contact_shove(body)
		# If we're already holding the button, start pushing immediately
		elif is_holding_push and not is_attached_to_object:
			_attach_to_object(body)
			currently_pushing.append(body)
			_apply_initial_shove(body)

func _apply_contact_shove(pushable: PushableStatue) -> void:
	"""Apply a shove when fist makes contact without holding push button"""
	var to_object = (pushable.global_position - global_position)
	var distance = to_object.length()
	if distance == 0:
		return
		
	var direction_to_object = to_object.normalized()
	
	# Apply contact shove based on fist speed and direction (8-directional, smooth)
	var contact_force = shove_impulse * 0.7  # Slightly less than manual shove
	var speed_multiplier = clamp(speed / max_speed, 0.4, 1.0)
	contact_force *= speed_multiplier
	
	if push_pull_mode:
		# Pull towards fist (when returning)
		pushable.apply_shove(-direction_to_object * contact_force)
		print("🪃 Contact pull applied: ", -direction_to_object)
	else:
		# Push away from fist (when throwing)
		pushable.apply_shove(direction_to_object * contact_force)
		print("👊 Contact push applied: ", direction_to_object)

func _on_pushable_exited(body: Node2D) -> void:
	if body is PushableStatue:
		if body in objects_in_range:
			objects_in_range.erase(body)
		if body in currently_pushing:
			currently_pushing.erase(body)
			body.stop_pushing()
		
		# If we were attached to this object, detach
		if is_attached_to_object and attached_object == body:
			_detach_from_object()
		
		print("👋 Object left push/pull range: ", body.name)

func _update_pushable_objects() -> void:
	if state == State.INACTIVE:
		return
	
	# When attached, movement is handled by player movement tracking
	# No continuous push forces needed
	if is_attached_to_object:
		return
	
	# Apply continuous push if we're holding button AND attached to object (for non-attached mode)
	if is_holding_push and attached_object:
		_apply_continuous_push_pull(attached_object)

func _apply_continuous_push_pull(pushable: PushableStatue) -> void:
	if not is_instance_valid(pushable):
		return
	
	var to_object = (pushable.global_position - global_position)
	var distance = to_object.length()
	if distance == 0:
		return
		
	var direction_to_object = to_object.normalized()
	
	# Convert to 4-directional movement
	var cardinal_direction = _get_cardinal_direction(direction_to_object)
	
	# Calculate distance-based force falloff
	var force_multiplier = clamp(1.0 - (distance / push_range), 0.2, 1.0)
	
	# Apply speed-based force multiplier (for dynamic feel)
	var speed_multiplier = clamp(speed / max_speed, 0.3, 1.0)
	force_multiplier *= speed_multiplier
	
	if push_pull_mode:
		# Pull mode (when returning)
		var pull_direction = -cardinal_direction * pull_force / 100.0
		pushable.push_direction = pull_direction * force_multiplier
	else:
		# Push mode (when throwing)
		var push_direction = cardinal_direction * push_force / 100.0
		pushable.push_direction = push_direction * force_multiplier

func _get_cardinal_direction(direction: Vector2) -> Vector2:
	# Convert any direction to the nearest cardinal direction (4-way movement)
	var abs_x = abs(direction.x)
	var abs_y = abs(direction.y)
	
	if abs_x > abs_y:
		# Horizontal movement
		return Vector2(1.0 if direction.x > 0 else -1.0, 0.0)
	else:
		# Vertical movement
		return Vector2(0.0, 1.0 if direction.y > 0 else -1.0)

func _update_push_direction_for_all() -> void:
	# Update all currently affected objects when mode changes
	for pushable in currently_pushing:
		if is_instance_valid(pushable):
			_apply_continuous_push_pull(pushable)

# ============================================================
#  VISUAL CONNECTION LINE
# ============================================================
func _show_connection_line() -> void:
	if connection_line:
		connection_line.visible = true
		_update_connection_line()
		print("🔗 Showing connection line")

func _hide_connection_line() -> void:
	if connection_line:
		connection_line.visible = false
		connection_line.clear_points()
		print("🚫 Hiding connection line")

func _update_connection_line() -> void:
	if not connection_line:
		print("❌ Connection line is null!")
		return
	if not is_attached_to_object or not attached_object or not player:
		print("❌ Missing attachment components!")
		return
	
	# Clear existing points
	connection_line.clear_points()
	
	# Get positions
	var start_pos = player.global_position
	var end_pos = attached_object.global_position
	var distance = start_pos.distance_to(end_pos)
	
	# Create a smooth curved line with dynamic sag
	var mid_point = (start_pos + end_pos) / 2.0
	var sag_amount = clamp(distance * 0.15, 10.0, 50.0)
	var curve_offset = Vector2(0, sag_amount)  # Downward curve like a rope
	mid_point += curve_offset
	
	# Create smooth curve
	var segments = 12
	for i in range(segments + 1):
		var t = float(i) / segments
		var point = _bezier_curve(start_pos, mid_point, end_pos, t)
		connection_line.add_point(point)
	
	# Dynamic color and width based on distance
	var time = Time.get_time_dict_from_system()["second"]
	var pulse = sin(time * 3.0) * 0.15 + 0.85
	var distance_fade = clamp(1.0 - (distance / 300.0), 0.4, 1.0)
	
	# Color based on distance
	if distance < 100:
		connection_line.default_color = Color(1.0, 0.9, 0.3, pulse * distance_fade)
	elif distance < 200:
		connection_line.default_color = Color(1.0, 0.7, 0.2, pulse * distance_fade)
	else:
		connection_line.default_color = Color(1.0, 0.4, 0.2, pulse * distance_fade)
	
	# Dynamic width
	var base_width = 5.0
	var width_multiplier = clamp(1.2 - (distance / 250.0), 0.6, 1.2)
	connection_line.width = base_width * width_multiplier * pulse
	
	connection_line.visible = true
	print("📏 Updated connection line from ", start_pos, " to ", end_pos)

func _bezier_curve(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	"""Create a quadratic bezier curve"""
	var u = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

# ============================================================
#  EQUIPMENT & VISUAL FUNCTIONS
# ============================================================
func _on_equipment_changed() -> void:
	var equipment: Array[SlotData] = PlayerManager.INVENTORY_DATA.equipment_slots()
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

# ============================================================
#  CLEANUP
# ============================================================
func _exit_tree() -> void:
	# Clean up connection line
	if connection_line and is_instance_valid(connection_line):
		connection_line.queue_free()
	
	# Stop all pushing when fist is destroyed
	for pushable in currently_pushing:
		if is_instance_valid(pushable):
			pushable.stop_pushing()
	currently_pushing.clear()
	objects_in_range.clear()
	
	# Clear attachment
	if is_attached_to_object and attached_object:
		attached_object.stop_pushing()
		attached_object.stop_following_player()
	is_attached_to_object = false
	attached_object = null
