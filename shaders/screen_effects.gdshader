shader_type canvas_item;

// --- FILM GRAIN + VIGNETTE ---
uniform float grain_intensity : hint_range(0.0, 0.2) = 0.04;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.45;

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
    vec2 center = UV - vec2(0.5);
    float dist = length(center);
    float vignette = smoothstep(vignette_softness, vignette_softness + 0.3, dist);
    col.rgb *= 1.0 - vignette * vignette_intensity;
    
    COLOR = col;
}
