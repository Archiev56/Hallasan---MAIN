shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0);

void fragment() {
    vec2 center = vec2(0.5, 0.5); // Center of the screen
    float dist = distance(UV, center); // Distance from current pixel to the center

    if (dist > radius) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0); // Black outside the circle
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Transparent inside the circle
    }
}
