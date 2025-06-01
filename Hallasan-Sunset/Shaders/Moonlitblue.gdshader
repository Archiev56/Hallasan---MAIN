shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.7; // How strong the moonlit effect is

void fragment() {
    vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);

    // Convert color to grayscale to simulate nighttime lighting
    float grayscale = dot(color.rgb, vec3(0.3, 0.59, 0.11));

    // Moonlit blue tint (deep blue tone)
    vec3 moonlit_blue = mix(color.rgb, vec3(0.2, 0.3, 0.6), intensity);

    // Blend between original color and moonlit tint based on grayscale
    vec3 final_color = mix(moonlit_blue, vec3(grayscale * 0.6, grayscale * 0.7, grayscale * 1.0), 0.5);

    COLOR = vec4(final_color, color.a); // Preserve alpha channel
}
