shader_type canvas_item;

// ============================================================
//  UNIFORMS - Customize these in the inspector
// ============================================================
uniform float sway_strength = 0.008;
uniform float sway_speed = 0.7;
uniform float breathing_strength = 0.015;
uniform float breathing_speed = 1.2;

uniform float glow_intensity = 0.3;
uniform float glow_speed = 1.5;
uniform vec4 glow_color = vec4(0.9, 0.7, 0.3, 1.0); // Warm mystical glow

uniform float pulse_strength = 0.1;
uniform float pulse_speed = 2.0;

uniform float ancient_noise_strength = 0.03;
uniform float ancient_noise_speed = 0.5;

uniform bool enable_mystical_particles = true;
uniform float particle_density = 8.0;
uniform vec4 particle_color = vec4(1.0, 0.9, 0.6, 0.7);

// ============================================================
//  VERTEX SHADER - Handle position transformations
// ============================================================
void vertex() {
    float time_factor = TIME;

    // Gentle swaying motion - more at the top
    float sway_amount = sin(time_factor * sway_speed) * sway_strength;
    float height_factor = (1.0 - UV.y); // More sway at top
    sway_amount *= height_factor * height_factor;

    // Breathing effect - gentle scaling
    float breathing = sin(time_factor * breathing_speed) * breathing_strength;

    // Apply transformations
    VERTEX.x += sway_amount * 100.0; // Scale for pixel movement
    VERTEX += VERTEX * breathing; // Breathing scale effect
}

// ============================================================
//  NOISE FUNCTIONS
// ============================================================
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;

    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// ============================================================
//  FRAGMENT SHADER - Handle colors and effects
// ============================================================
void fragment() {
    vec2 uv = UV;
    vec4 original_color = texture(TEXTURE, uv);

    // Don't process transparent pixels
    if (original_color.a < 0.01) {
        COLOR = original_color;

    }

    float time_factor = TIME;

    // ============================================================
    //  ANCIENT MYSTICAL GLOW
    // ============================================================
    float glow_pulse = sin(time_factor * glow_speed) * 0.5 + 0.5;
    float glow_noise = fbm(uv * 3.0 + time_factor * 0.2) * 0.3;
    float glow_factor = (glow_pulse + glow_noise) * glow_intensity;

    // Add warm glow to the totem
    vec3 glowing_color = mix(original_color.rgb, glow_color.rgb, glow_factor);

    // ============================================================
    //  BREATHING PULSE EFFECT
    // ============================================================
    float pulse = sin(time_factor * pulse_speed) * 0.5 + 0.5;
    float brightness_pulse = 1.0 + (pulse * pulse_strength);
    glowing_color *= brightness_pulse;

    // ============================================================
    //  ANCIENT TEXTURE DISTORTION
    // ============================================================
    vec2 noise_offset = vec2(
        fbm(uv * 4.0 + time_factor * ancient_noise_speed),
        fbm(uv * 4.0 + vec2(100.0) + time_factor * ancient_noise_speed)
    ) * ancient_noise_strength;

    vec4 distorted_color = texture(TEXTURE, uv + noise_offset);
    glowing_color = mix(glowing_color, distorted_color.rgb, 0.3);

    // ============================================================
    //  MYSTICAL PARTICLES OVERLAY
    // ============================================================
    if (enable_mystical_particles) {
        vec2 particle_uv = uv * particle_density;
        vec2 particle_grid = fract(particle_uv);
        vec2 particle_id = floor(particle_uv);

        // Animate particles
        float particle_time = time_factor * 0.8 + random(particle_id) * 6.28;
        vec2 particle_pos = vec2(
            0.5 + sin(particle_time) * 0.3,
            0.5 + cos(particle_time * 1.3) * 0.3
        );

        float particle_dist = length(particle_grid - particle_pos);
        float particle_size = 0.1 + sin(particle_time * 2.0) * 0.05;

        if (particle_dist < particle_size) {
            float particle_alpha = (1.0 - particle_dist / particle_size) * particle_color.a;
            glowing_color = mix(glowing_color, particle_color.rgb, particle_alpha);
        }
    }

    // ============================================================
    //  EDGE MYSTICAL AURA
    // ============================================================
    // Create aura around the edges
    float edge_detection = 1.0 - smoothstep(0.0, 0.1, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
    float aura_pulse = sin(time_factor * 3.0) * 0.5 + 0.5;
    vec3 aura_glow = glow_color.rgb * edge_detection * aura_pulse * 0.4;
    glowing_color += aura_glow;

    // ============================================================
    //  ANCIENT ENERGY LINES
    // ============================================================
    // Vertical energy lines that pulse
    float line_pattern = sin(uv.x * 20.0 + time_factor * 2.0) * 0.5 + 0.5;
    line_pattern *= sin(uv.y * 8.0 + time_factor * 1.5) * 0.5 + 0.5;
    line_pattern = smoothstep(0.7, 1.0, line_pattern);

    vec3 energy_lines = glow_color.rgb * line_pattern * 0.2;
    glowing_color += energy_lines;

    // ============================================================
    //  FINAL COLOR OUTPUT
    // ============================================================
    COLOR = vec4(glowing_color, original_color.a);
}