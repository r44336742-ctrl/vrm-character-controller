shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo : source_color = vec3(0.02, 0.04, 0.10);
uniform float metallic = 0.3;
uniform float roughness = 0.3;

uniform vec4 wave1 = vec4(1.0, 0.5, 0.12, 50.0);
uniform vec4 wave2 = vec4(0.8, 1.2, 0.08, 30.0);
uniform vec4 wave3 = vec4(-0.5, 1.0, 0.06, 20.0);

varying float wave_height;
varying vec3 world_pos_v;

// --- BRUIT LISSE (quintic interpolation, pas de grille visible) ---
vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}

float gradient_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Quintic interpolation (ultra-lisse, pas de discontinuité)
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    
    float a = dot(hash22(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
    float b = dot(hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
    float c = dot(hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
    float d = dot(hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
    
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}

float fbm(vec2 p) {
    float val = 0.0;
    float amp = 0.5;
    mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)); // Rotation entre octaves
    for (int i = 0; i < 4; i++) {
        val += amp * gradient_noise(p);
        p = rot * p * 2.1;
        amp *= 0.45;
    }
    return val;
}

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
    world_pos_v = wp.xyz;
    
    vec3 p_offset = vec3(0.0);
    p_offset += get_gerstner_wave(wave1, VERTEX);
    p_offset += get_gerstner_wave(wave2, VERTEX);
    p_offset += get_gerstner_wave(wave3, VERTEX);
    wave_height = p_offset.y;
    VERTEX += p_offset;
}

void fragment() {
    vec2 wpos = world_pos_v.xz;
    
    // Deux couches de bruit lisse qui scrollent
    vec2 uv1 = wpos * 0.08 + TIME * vec2(0.06, 0.04);
    vec2 uv2 = wpos * 0.12 + TIME * vec2(-0.04, 0.03);
    
    float n1 = fbm(uv1);
    float n2 = fbm(uv2);
    
    // Dérivées pour la perturbation de normales (petit epsilon)
    float eps = 0.02;
    float n1_dx = fbm(uv1 + vec2(eps, 0.0)) - fbm(uv1 - vec2(eps, 0.0));
    float n1_dz = fbm(uv1 + vec2(0.0, eps)) - fbm(uv1 - vec2(0.0, eps));
    float n2_dx = fbm(uv2 + vec2(eps, 0.0)) - fbm(uv2 - vec2(eps, 0.0));
    float n2_dz = fbm(uv2 + vec2(0.0, eps)) - fbm(uv2 - vec2(0.0, eps));
    
    // Perturbation douce (pas trop agressive)
    float dx = (n1_dx + n2_dx * 0.6) * 3.0;
    float dz = (n1_dz + n2_dz * 0.6) * 3.0;
    vec3 perturbed_normal = normalize(vec3(-dx, 1.0, -dz));
    
    // --- COULEUR ---
    float depth_var = smoothstep(-0.5, 0.5, wave_height);
    vec3 ocean_col = mix(albedo * 0.7, albedo * 1.4, depth_var);
    
    // Variation de couleur lisse
    float color_var = (n1 + n2) * 0.5;
    ocean_col *= mix(0.9, 1.1, color_var);
    
    // Écume
    float foam = smoothstep(0.5, 0.9, wave_height);
    ocean_col = mix(ocean_col, vec3(0.12, 0.18, 0.28), foam * 0.4);
    
    ALBEDO = ocean_col;
    METALLIC = metallic;
    ROUGHNESS = mix(roughness, 0.5, foam * 0.5);
    NORMAL = perturbed_normal;
    
    // --- EMISSION : Détail visible partout ---
    float surface_detail = color_var;
    
    float fresnel = 1.0 - abs(dot(normalize(VIEW), perturbed_normal));
    fresnel = pow(fresnel, 2.0);
    
    vec3 base_emit = vec3(0.015, 0.025, 0.07);
    vec3 detail_emit = vec3(0.015, 0.025, 0.05) * surface_detail;
    vec3 fresnel_emit = vec3(0.01, 0.02, 0.04) * fresnel;
    vec3 crest_emit = vec3(0.015, 0.025, 0.04) * depth_var;
    
    EMISSION = base_emit + detail_emit + fresnel_emit + crest_emit;
}
