shader_type canvas_item;
render_mode unshaded, skip_vertex_transform;

// 📺 Adjustable screen distortion strength
uniform float curvature : hint_range(1.0, 20.0) = 7.0;

// 🌘 Vignette darkness strength
uniform float vignette_multiplier : hint_range(0.0, 5.0) = 2.0;

// 📡 Scanline frequency multiplier
uniform float scanline_frequency : hint_range(0.0, 800.0) = 800.0;

// 🎞️ Mipmapped screen texture
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 centered_uv = SCREEN_UV * 2.0 - 1.0;
	vec2 uv_offset = centered_uv.yx / curvature;
	vec2 warped_uv = centered_uv + centered_uv * uv_offset * uv_offset;

	vec3 cutoff = vec3(step(abs(warped_uv.x), 1.0) * step(abs(warped_uv.y), 1.0));
	vec3 scanlines = vec3(sin(2.0 * warped_uv.y * scanline_frequency) * 0.1 + 0.9);
	vec3 vignette = vec3(length(pow(abs(centered_uv), vec2(4.0)) / 3.0));

	vec3 screen_color = textureLod(screen_texture, (warped_uv + 1.0) / 2.0, 0.2).rgb;
	screen_color *= cutoff * scanlines;
	screen_color -= vignette * vignette_multiplier;

	COLOR = vec4(screen_color, 1.0);
}
