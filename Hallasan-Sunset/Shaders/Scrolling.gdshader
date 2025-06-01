shader_type canvas_item;

uniform sampler2D pattern_sampler : repeat_enable, filter_linear_mipmap;
uniform vec4 Top_Color : source_color; // Color at position 0 (includes alpha)
uniform vec4 Mid_Color : source_color; // Color at position 0.5 (includes alpha)
uniform vec4 Bot_Color : source_color; // Color at position 1 (includes alpha)
uniform vec4 pattern_color : source_color;
uniform float scale = 2.0;
uniform float ratio = 1.0;

void fragment() {
    // Calculate the vertical position of the fragment
    float gradient_position = UV.y;

    // Define positions for each color stop
    float position1 = 0.0;
    float position2 = 0.5;
    float position3 = 1.0;

    // Interpolate between colors based on position
    vec4 bg_color;
    if (gradient_position < position2) {
        bg_color = mix(Top_Color, Mid_Color, gradient_position / position2);
    } else {
        bg_color = mix(Mid_Color, Bot_Color, (gradient_position - position2) / (position3 - position2));
    }

    // Sample the pattern texture
    float pattern_factor = texture(pattern_sampler, UV * vec2(1.0, ratio) * scale + TIME * 0.025).x;

    // Blend the pattern color and background while preserving transparency
    vec4 final_color = mix(pattern_color, bg_color, pattern_factor);

    // Preserve transparency (ensure correct alpha blending)
    COLOR = final_color * final_color.a;
}
