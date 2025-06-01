extends StaticBody2D


@onready var interact_label = $X  # Reference to the "Press C to talk" label

var player_in_range = false  # Track if the player is within range to talk

func _ready():
	interact_label.visible = false  # Hide "Press C to talk" by default


# Function that gets triggered when player enters interaction area
func _on_area_2d_body_entered(body):
	if body.name == "Player":  # Check if the player enters the area
		player_in_range = true
		interact_label.visible = true  # Show "Press C to talk" message

# Function that gets triggered when player leaves interaction area
func _on_area_2d_body_exited(body):
	if body.name == "Player":  # Check if the player leaves the area
		player_in_range = false
		interact_label.visible = false  # Hide "Press C to talk"
		
		
	

# Function to handle player input for interaction
func _process(delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
	
		interact_label.visible = false

# Function to start the conversation
