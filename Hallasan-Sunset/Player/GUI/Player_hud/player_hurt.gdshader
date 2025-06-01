shader_type canvas_item;

uniform float border_thickness : hint_range(0.0, 0.5) = 0.15;
uniform float fade : hint_range(0.0, 1.0) = 0.5;
uniform vec4 damage_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Red

void fragment() {
    // Distance to nearest edge (X and Y separately)
    float edge_dist_x = min(UV.x, 1.0 - UV.x);
    float edge_dist_y = min(UV.y, 1.0 - UV.y);

    // Smooth falloff for each axis
    float edge_fade_x = smoothstep(0.0, border_thickness, edge_dist_x);
    float edge_fade_y = smoothstep(0.0, border_thickness, edge_dist_y);

    // Combine fades (closer to edge = lower fade value)
    float edge_fade = min(edge_fade_x, edge_fade_y);
    float alpha = (1.0 - edge_fade) * fade;

    COLOR = damage_color;
    COLOR.a *= alpha;
}
