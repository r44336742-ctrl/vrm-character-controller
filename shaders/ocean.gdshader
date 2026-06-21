shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Océan bleu sombre
uniform vec3 albedo : source_color = vec3(0.02, 0.04, 0.10); // Bleu sombre visible
uniform float metallic = 0.6;
uniform float roughness = 0.15;

// Normal Maps générées procéduralement
uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;

uniform vec2 scroll_a = vec2(0.02, 0.02);
uniform vec2 scroll_b = vec2(-0.015, 0.01);
uniform float wave_scale = 0.08;

// Houle de fond (grandes vagues douces)
uniform vec4 wave1 = vec4(1.0, 0.5, 0.06, 60.0);
uniform vec4 wave2 = vec4(0.8, 1.2, 0.04, 35.0);

varying vec2 uv_a;
varying vec2 uv_b;

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
    VERTEX += p_offset;
}

void fragment() {
    vec3 n_a = texture(normalmap_a, uv_a).rgb;
    vec3 n_b = texture(normalmap_b, uv_b).rgb;
    
    ALBEDO = albedo;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    NORMAL_MAP = mix(n_a, n_b, 0.5);
    NORMAL_MAP_DEPTH = 1.5;
    
    // Auto-éclairage bleu subtil pour rester visible dans le noir total
    EMISSION = vec3(0.005, 0.01, 0.03);
}
