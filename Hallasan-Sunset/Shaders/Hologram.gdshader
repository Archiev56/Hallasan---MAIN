shader_type canvas_item;

uniform float scanline_speed : hint_range(0.1, 10.0) = 3.0;
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    vec2 uv = UV;

    // Scanline effect
    float scanline = sin(uv.y * 100.0 + TIME * scanline_speed) * 0.1;

    // Flicker effect
    float flicker = (fract(sin(TIME * 10.0) * 43758.5453123) - 0.5) * flicker_intensity;

    COLOR = texture(TEXTURE, uv) + vec4(scanline + flicker);
}
