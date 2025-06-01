shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec2 center;
uniform float force;
uniform float size;

void fragment() {
    float ratio = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;

    // Correct the UV scaling so the center is properly aligned
    vec2 scaledUV = (SCREEN_UV - vec2(0.5)) / vec2(ratio, 1.0) + vec2(0.5);

    // Distance mask calculation (shockwave effect)
    float dist = length(scaledUV - center);
    float mask = (1.0 - smoothstep(size - 0.1, size, dist)) *
                 smoothstep(size - 0.2, size - 0.1, dist);

    // Apply displacement to create the shockwave effect
    vec2 disp = normalize(scaledUV - center) * force * mask;

    // Sample the screen texture with the displacement
    COLOR = texture(SCREEN_TEXTURE, SCREEN_UV - disp);
}
