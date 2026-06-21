shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Océan bleu sombre
uniform vec3 albedo : source_color = vec3(0.02, 0.04, 0.10);
uniform float metallic = 0.6;
uniform float roughness = 0.15;

// Normal Maps
uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;

uniform vec2 scroll_a = vec2(0.02, 0.02);
uniform vec2 scroll_b = vec2(-0.015, 0.01);
uniform float wave_scale = 0.08;

// Houle de fond (3 vagues pour du relief)
uniform vec4 wave1 = vec4(1.0, 0.5, 0.12, 50.0);
uniform vec4 wave2 = vec4(0.8, 1.2, 0.08, 30.0);
uniform vec4 wave3 = vec4(-0.5, 1.0, 0.06, 20.0);

// Écume blanche sur les crêtes
uniform float foam_threshold = 0.6;

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
    
    return vec3(
        d.x * (a * cos(f)),
        a * sin(f),
        d.y * (a * cos(f))
    );
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
    vec3 n_a = texture(normalmap_a, uv_a).rgb;
    vec3 n_b = texture(normalmap_b, uv_b).rgb;
    
    // Couleur de base
    vec3 ocean_col = albedo;
    
    // Variation de profondeur (zones plus profondes = plus sombres)
    float depth_var = smoothstep(-0.5, 0.5, wave_height);
    ocean_col = mix(ocean_col * 0.6, ocean_col * 1.3, depth_var);
    
    // Écume blanche sur les crêtes des vagues
    float foam = smoothstep(foam_threshold, foam_threshold + 0.3, wave_height);
    ocean_col = mix(ocean_col, vec3(0.15, 0.2, 0.3), foam * 0.4);
    
    ALBEDO = ocean_col;
    METALLIC = metallic;
    ROUGHNESS = mix(roughness, 0.6, foam * 0.5); // Écume moins réfléchissante
    NORMAL_MAP = mix(n_a, n_b, 0.5);
    NORMAL_MAP_DEPTH = 1.8;
    
    // Auto-éclairage bleu pour que les détails soient visibles de partout
    EMISSION = vec3(0.01, 0.02, 0.06) + vec3(0.015, 0.02, 0.04) * depth_var;
}
