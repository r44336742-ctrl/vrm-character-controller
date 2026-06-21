shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Océan bleu sombre — DIFFUSE (pas métallique = bumps visibles par l'ambient)
uniform vec3 albedo : source_color = vec3(0.03, 0.06, 0.14);
uniform float metallic = 0.05; // Quasi-zéro = l'ambient éclaire les bumps
uniform float roughness = 0.55; // Diffus = les normales se voient sous TOUTE lumière

uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;

uniform vec2 scroll_a = vec2(0.02, 0.02);
uniform vec2 scroll_b = vec2(-0.015, 0.01);
uniform float wave_scale = 0.08;

uniform vec4 wave1 = vec4(1.0, 0.5, 0.12, 50.0);
uniform vec4 wave2 = vec4(0.8, 1.2, 0.08, 30.0);
uniform vec4 wave3 = vec4(-0.5, 1.0, 0.06, 20.0);

varying vec2 uv_a;
varying vec2 uv_b;
varying float wave_height;

vec3 get_gerstner_wave(vec4 wave, vec3 p) {
    float steepness = wave.z;
    float wavelength = wave.w;
    float k = 2.0 * 3.14159 / wavelength;
    float c = sqrt(9.8 / k);
    vec2 d = normalize(wave.xy);
    float f = k * (dot(d, p.xz) - c * TIME * 0.4);
    float a = steepness / k;
    return vec3(d.x * (a * cos(f)), a * sin(f), d.y * (a * cos(f)));
}

void vertex() {
    vec2 world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    uv_a = world_xz * wave_scale + TIME * scroll_a;
    uv_b = world_xz * wave_scale + TIME * scroll_b;
    
    vec3 p_offset = vec3(0.0);
    p_offset += get_gerstner_wave(wave1, VERTEX);
    p_offset += get_gerstner_wave(wave2, VERTEX);
    p_offset += get_gerstner_wave(wave3, VERTEX);
    wave_height = p_offset.y;
    VERTEX += p_offset;
}

void fragment() {
    // Normal maps (scrolling, blendées)
    vec3 n_a = texture(normalmap_a, uv_a).rgb;
    vec3 n_b = texture(normalmap_b, uv_b).rgb;
    vec3 blended = mix(n_a, n_b, 0.5);
    
    // Couleur avec variation de profondeur
    float depth_var = smoothstep(-0.5, 0.5, wave_height);
    vec3 ocean_col = mix(albedo * 0.7, albedo * 1.3, depth_var);
    
    // Écume sur les crêtes
    float foam = smoothstep(0.5, 0.9, wave_height);
    ocean_col = mix(ocean_col, vec3(0.1, 0.15, 0.25), foam * 0.4);
    
    ALBEDO = ocean_col;
    METALLIC = metallic;
    ROUGHNESS = mix(roughness, 0.7, foam * 0.3);
    NORMAL_MAP = blended;
    NORMAL_MAP_DEPTH = 2.5; // Fort pour que les bumps soient bien visibles
    
    // Emission faible pour que la mer ne disparaisse jamais
    EMISSION = vec3(0.01, 0.02, 0.05) * (0.5 + 0.5 * depth_var);
}
