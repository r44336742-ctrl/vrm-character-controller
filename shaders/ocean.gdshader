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

// --- BRUIT PROCÉDURAL (pas de texture nécessaire) ---
float hash2D(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep
    float a = hash2D(i);
    float b = hash2D(i + vec2(1.0, 0.0));
    float c = hash2D(i + vec2(0.0, 1.0));
    float d = hash2D(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float val = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        val += amp * noise2D(p);
        p *= 2.1;
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
    // --- BRUIT DE SURFACE PROCÉDURAL (remplace les normal maps) ---
    vec2 wpos = world_pos_v.xz;
    
    // Deux couches de bruit qui scrollent dans des directions différentes
    vec2 uv1 = wpos * 0.15 + TIME * vec2(0.08, 0.06);
    vec2 uv2 = wpos * 0.22 + TIME * vec2(-0.05, 0.04);
    vec2 uv3 = wpos * 0.4 + TIME * vec2(0.03, -0.07); // Détail fin
    
    float n1 = fbm(uv1);
    float n2 = fbm(uv2);
    float n3 = noise2D(uv3); // Couche fine
    
    // Combiner en perturbation de normale (dérivées finies)
    float eps = 0.1;
    float n1_dx = fbm(uv1 + vec2(eps, 0.0)) - n1;
    float n1_dz = fbm(uv1 + vec2(0.0, eps)) - n1;
    float n2_dx = fbm(uv2 + vec2(eps, 0.0)) - n2;
    float n2_dz = fbm(uv2 + vec2(0.0, eps)) - n2;
    float n3_dx = noise2D(uv3 + vec2(eps, 0.0)) - n3;
    float n3_dz = noise2D(uv3 + vec2(0.0, eps)) - n3;
    
    // Perturbation de normale composite
    float dx = (n1_dx + n2_dx * 0.7 + n3_dx * 0.3) * 8.0;
    float dz = (n1_dz + n2_dz * 0.7 + n3_dz * 0.3) * 8.0;
    vec3 perturbed_normal = normalize(vec3(-dx, 1.0, -dz));
    
    // --- COULEUR ---
    float depth_var = smoothstep(-0.5, 0.5, wave_height);
    vec3 ocean_col = mix(albedo * 0.7, albedo * 1.4, depth_var);
    
    // Variation de couleur par le bruit (casse l'uniformité)
    float color_noise = (n1 + n2) * 0.5;
    ocean_col *= mix(0.85, 1.15, color_noise);
    
    // Écume sur les crêtes
    float foam = smoothstep(0.5, 0.9, wave_height);
    ocean_col = mix(ocean_col, vec3(0.12, 0.18, 0.28), foam * 0.5);
    
    ALBEDO = ocean_col;
    METALLIC = metallic;
    ROUGHNESS = mix(roughness, 0.5, foam * 0.5);
    NORMAL = perturbed_normal;
    
    // --- EMISSION : Détail visible PARTOUT ---
    // Le bruit de surface crée le détail dans l'émission directement
    float surface_detail = (n1 * 0.5 + n2 * 0.3 + n3 * 0.2);
    
    // Fresnel : bords des vagues brillent
    float fresnel = 1.0 - abs(dot(normalize(VIEW), perturbed_normal));
    fresnel = pow(fresnel, 2.0);
    
    vec3 base_emit = vec3(0.015, 0.025, 0.07);
    vec3 detail_emit = vec3(0.02, 0.03, 0.06) * surface_detail;
    vec3 fresnel_emit = vec3(0.015, 0.025, 0.05) * fresnel;
    vec3 crest_emit = vec3(0.02, 0.03, 0.05) * depth_var;
    
    EMISSION = base_emit + detail_emit + fresnel_emit + crest_emit;
}
