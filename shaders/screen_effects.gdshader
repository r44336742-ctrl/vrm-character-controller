shader_type canvas_item;

// --- FILM GRAIN + VIGNETTE ---
uniform float grain_intensity : hint_range(0.0, 0.2) = 0.04;
uniform float vignette_inner_radius : hint_range(0.0, 200.0) = 28.0;
uniform float vignette_outer_radius : hint_range(0.0, 200.0) = 100.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 1.0;

// Hash pour le grain (rapide, pseudo-aléatoire)
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    // --- FILM GRAIN ---
    float noise = hash(UV * 1000.0 + TIME * 7.13) * 2.0 - 1.0;
    col.rgb += noise * grain_intensity;
    
    // --- VIGNETTE ---
    // Calculate distance from center (UV is 0 to 1, center is 0.5)
    // To match standard inner/outer radius, we treat the distance in percentages (0 to 100)
    // where 50 is the edge of the screen (from center to edge = 0.5, multiplied by 100 = 50)
    // Actually, usually radius is based on full size, let's map distance 0.0 to 1.0 = center to corner.
    vec2 center = UV - vec2(0.5);
    // Multiply by 2.0 so distance from center to edge (vertically/horizontally) is 1.0. 
    // Multiply by 100.0 to scale it to the "0-100" range requested by user.
    float dist = length(center) * 200.0; 
    
    float vignette = smoothstep(vignette_inner_radius, vignette_outer_radius, dist);
    col.rgb *= 1.0 - vignette * vignette_intensity;
    
    COLOR = col;
}
