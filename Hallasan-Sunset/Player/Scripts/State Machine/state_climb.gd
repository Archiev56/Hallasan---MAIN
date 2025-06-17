class_name State_Climb extends State

@export var climb_speed: float = 40.0
@export var climb_accel: float = 800.0
@export var climb_friction: float = 800.0

@onready var idle: State = $"../Idle"
@onready var walk: State = $"../Walk"
@onready var attack: State = $"../Attack"

var input: Vector2 = Vector2.ZERO
var is_near_ladder: bool = false

func enter() -> void:
	player.UpdateAnimation("climb")
	# Stop horizontal momentum when starting to climb
	if abs(player.velocity.x) > abs(player.velocity.y):
		player.velocity.x *= 0.5

func exit() -> void:
	pass

func Process(_delta: float) -> State:
	# Check if we're still near a ladder
	if not check_ladder_proximity():
		# If no ladder nearby, return to appropriate state
		if player.direction != Vector2.ZERO:
			return walk
		else:
			return idle
	
	# If no input, stay in climb state but don't move
	if player.direction == Vector2.ZERO:
		return null
	
	return null

func Physics(_delta: float) -> State:
	# Update ladder proximity
	is_near_ladder = check_ladder_proximity()
	
	if not is_near_ladder:
		# Exit climbing if no ladder nearby
		if player.direction != Vector2.ZERO:
			return walk
		else:
			return idle
	
	handle_climbing(_delta)
	player.move_and_slide()
	return null

func handle_input(_event: InputEvent) -> State:
	if _event.is_action_pressed("attack"):
		return attack
	
	# Allow exiting climb state by pressing climb again or moving away
	if _event.is_action_pressed("climb"):
		if player.direction != Vector2.ZERO:
			return walk
		else:
			return idle
	
	return null

func handle_climbing(delta: float):
	input = get_input()
	
	# Apply friction if there's no input, otherwise accelerate
	if input == Vector2.ZERO:
		if player.velocity.length() > (climb_friction * delta):
			player.velocity -= player.velocity.normalized() * (climb_friction * delta)
		else:
			player.velocity = Vector2.ZERO
	else:
		player.velocity += input * climb_accel * delta
		player.velocity = player.velocity.limit_length(climb_speed)
	
	# Update player animation direction
	if player.set_direction():
		player.UpdateAnimation("climb")

func get_input() -> Vector2:
	var direction = Vector2(
		int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")),
		int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	)
	return direction.normalized()

func check_ladder_proximity() -> bool:
	# Find the ladder TileMapLayer using a group (similar to stairs)
	var ladder_tilemap = get_tree().get_first_node_in_group("ladder")
	
	if not ladder_tilemap:
		return false
	
	# Check a small area around the player for ladder tiles
	var player_pos = player.global_position
	var check_radius = 24  # Pixels to check around player
	
	# Check multiple points around the player
	var check_points = [
		Vector2.ZERO,  # Player center
		Vector2(0, -check_radius),  # Above
		Vector2(0, check_radius),   # Below
		Vector2(-check_radius, 0),  # Left
		Vector2(check_radius, 0),   # Right
	]
	
	for offset in check_points:
		var check_pos = player_pos + offset
		var local_pos = ladder_tilemap.to_local(check_pos)
		var tile_pos = ladder_tilemap.local_to_map(local_pos)
		var source_id = ladder_tilemap.get_cell_source_id(tile_pos)
		
		if source_id != -1:  # Found a ladder tile
			return true
	
	return false
