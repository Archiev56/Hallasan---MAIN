shader_type canvas_item;        // 2-D / pixel-art shader

// --- Uniforms you can tweak in the Inspector ---
uniform float glow_strength = 2.0;   // how bright the bloom is
uniform int   glow_radius   = 4;     // how many pixels to sample outwards

void fragment() {
    // Base pixel colour
    vec4 base = texture(TEXTURE, UV);

    // Accumulate blurred samples for the glow
    vec4 glow  = vec4(0.0);
    float total = 0.0;

    // Convert radius from int to float once
    float r = float(glow_radius);

    // Loop over a small square kernel around the current pixel
    for (int x = -glow_radius; x <= glow_radius; x++) {
        for (int y = -glow_radius; y <= glow_radius; y++) {
            vec2 offset = vec2(float(x), float(y)) * SCREEN_PIXEL_SIZE;
            float weight = glow_strength / (1.0 + float(x*x + y*y)); // fade with distance
            glow  += texture(TEXTURE, UV + offset) * weight;
            total += weight;
        }
    }

    glow /= total;           // normalize
    COLOR = max(base, glow); // combine: keep whichever component is brighter
}
