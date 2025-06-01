shader_type canvas_item;

uniform float amplitude : hint_range(0.0, 10.0) = 5.0;
uniform float speed : hint_range(0.0, 10.0) = 1.0;
uniform float frequency : hint_range(0.0, 10.0) = 1.0;
uniform float instance_offset = 0.0;  // Unique random per-instance value

void vertex() {
    // Wind sway with unique per-instance randomness
    float sway = sin(TIME * speed + VERTEX.y * frequency + instance_offset * 6.283) * amplitude;
    VERTEX.x += sway;
}
