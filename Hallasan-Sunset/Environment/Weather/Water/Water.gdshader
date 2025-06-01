shader_type canvas_item;

// We'll use a screen texture to render what is underwater
uniform sampler2D screen_texture : hint_screen_texture;

// A noise texture will be used to apply the distortion effect
uniform sampler2D noise_texture : filter_nearest, repeat_enable;

uniform vec2 speed = vec2(0.5, 0.2);


// Strength of the distortion effect
uniform float distortion = 0.01;

// Called for every vertex the material is visible on.
void vertex() {
}

// Called for every pixel the material is visible on.
void fragment() {

	vec2 uv = UV + speed * TIME;

	vec2 noise = 2.0 * texture(noise_texture, uv).rg - vec2(1.0);
    // Sample the water texture
    COLOR = texture(TEXTURE, UV);

    // Multiply the color with the screen texture
    COLOR *= texture(screen_texture, SCREEN_UV + noise * distortion);

}
