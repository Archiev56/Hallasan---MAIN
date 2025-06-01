shader_type canvas_item;

uniform float speed : hint_range(0.1, 10.0) = 3.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D noise_texture;

void fragment() {
    vec2 uv = UV;

    // Scrolling noise
    float noise = texture(noise_texture, uv + vec2(TIME * speed, 0.0)).r;

    // Electric effect
    float electric = smoothstep(0.5 - intensity, 0.5 + intensity, noise);

    COLOR = vec4(vec3(electric), texture(TEXTURE, uv).a);
}
