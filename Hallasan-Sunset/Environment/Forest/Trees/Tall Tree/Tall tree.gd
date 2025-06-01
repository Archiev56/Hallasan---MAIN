extends StaticBody2D


# Declare a shader parameter to adjust the phase.
@export var phase_offset: float = 0.0

func _ready():
	# Assign a random phase offset to the shader
	phase_offset = randf() * 2.0 * PI  # Random phase offset between 0 and 2π (a full wave cycle)
	shader.set_shader_param("Wind Strength", phase_offset)
