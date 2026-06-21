shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo : source_color = vec3(0.02, 0.04, 0.10);
uniform float metallic = 0.4;
uniform float roughness = 0.25;

uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;

uniform vec2 scroll_a = vec2(0.02, 0.02);
uniform vec2 scroll_b = vec2(-0.015, 0.01);
uniform float wave_scale = 0.08;

uniform vec4 wave1 = vec4(1.0, 0.5, 0.12, 50.0);
uniform vec4 wave2 = vec4(0.8, 1.2, 0.08, 30.0);
uniform vec4 wave3 = vec4(-0.5, 1.0, 0.06, 20.0);

uniform float foam_threshold = 0.6;

varying vec2 uv_a;
varying vec2 uv_b;
varying float wave_height;
varying vec3 world_vertex;

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
    vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
    world_vertex = wp.xyz;
    vec2 world_xz = wp.xz;
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
    // Normal maps blendées
    vec3 n_a = texture(normalmap_a, uv_a).rgb * 2.0 - 1.0;
    vec3 n_b = texture(normalmap_b, uv_b).rgb * 2.0 - 1.0;
    vec3 blended_normal = normalize(n_a + n_b);
    
    // --- COULEUR DE BASE ---
    vec3 ocean_col = albedo;
    float depth_var = smoothstep(-0.5, 0.5, wave_height);
    ocean_col = mix(ocean_col * 0.7, ocean_col * 1.4, depth_var);
    
    // Écume sur les crêtes
    float foam = smoothstep(foam_threshold, foam_threshold + 0.3, wave_height);
    ocean_col = mix(ocean_col, vec3(0.12, 0.18, 0.28), foam * 0.5);
    
    ALBEDO = ocean_col;
    METALLIC = metallic;
    ROUGHNESS = mix(roughness, 0.5, foam * 0.5);
    NORMAL_MAP = blended_normal * 0.5 + 0.5; // Remettre en 0-1
    NORMAL_MAP_DEPTH = 2.0;
    
    // --- EMISSION : Détail des vagues visible de PARTOUT ---
    // Utilise la perturbation des normales pour créer un éclairage propre
    // Les faces tournées vers le haut captent plus de "lumière lunaire simulée"
    float normal_y = blended_normal.y; // -1 à 1, plus haut = face vers le ciel
    float wave_detail = normal_y * 0.5 + 0.5; // 0 à 1
    
    // Fresnel simulé (les bords des vagues brillent plus)
    float fresnel = 1.0 - abs(dot(normalize(VIEW), NORMAL));
    fresnel = pow(fresnel, 2.0);
    
    // Emission de base + détail des normales + fresnel
    vec3 base_emission = vec3(0.015, 0.025, 0.07); // Bleu sombre constant
    vec3 detail_emission = vec3(0.01, 0.02, 0.05) * wave_detail; // Vagues visibles
    vec3 fresnel_emission = vec3(0.02, 0.03, 0.06) * fresnel; // Bords des vagues
    vec3 crest_emission = vec3(0.02, 0.03, 0.05) * depth_var; // Crêtes
    
    EMISSION = base_emission + detail_emission + fresnel_emission + crest_emission;
}
