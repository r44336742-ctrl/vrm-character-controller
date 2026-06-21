shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo_shallow : source_color = vec3(0.03, 0.07, 0.18);
uniform vec3 albedo_deep    : source_color = vec3(0.01, 0.03, 0.08);
uniform float metallic  = 0.0;
uniform float roughness = 0.1;

uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;
uniform vec3 moon_dir = normalize(vec3(-0.4, 0.6, -0.7));

varying vec2 world_xz;

void vertex() {
    // Océan plat (Point 1) : Plus de déplacement de sommets.
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    // 1. NORMALES FINES (Vagues uniquement via textures)
    vec2 uv1 = world_xz * 0.04 + TIME * vec2(0.01, -0.008);
    vec2 uv2 = world_xz * 0.08 + TIME * vec2(-0.007, -0.009);
    vec3 n1 = texture(normalmap_a, uv1).rgb * 2.0 - 1.0;
    vec3 n2 = texture(normalmap_b, uv2).rgb * 2.0 - 1.0;
    vec3 micro_n = normalize(n1 + n2 * 0.7);
    
    vec3 final_N = normalize(vec3(micro_n.x, 1.0, micro_n.z)); // Toujours plat à grande échelle
    
    // 2. COULEUR & FRESNEL
    vec3 col = mix(albedo_deep, albedo_shallow, 0.4);
    vec3 V = normalize(VIEW);
    float NdotV = max(dot(final_N, V), 0.0);
    float fresnel = pow(1.0 - NdotV, 4.0);
    col *= (1.0 - fresnel * 0.9);
    
    ALBEDO = col;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    NORMAL_MAP = final_N * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 1.5;

    // 3. SPÉCULAIRE EN BANDES (Toon Water - Point 2)
    vec3 L = normalize(moon_dir);
    vec3 H = normalize(V + L);
    float NdotH = max(dot(final_N, H), 0.0);
    
    // Quantifier la réflexion en 2 paliers nets
    float spec_base = smoothstep(0.98, 0.985, NdotH); // Bande large
    float spec_core = smoothstep(0.995, 0.999, NdotH); // Bande brillante
    float toon_spec = spec_base * 0.5 + spec_core * 1.5;
    
    // 4. SCINTILLEMENT STYLISÉ
    vec2 glitter_uv = world_xz * 20.0;
    float noise_val = hash12(floor(glitter_uv));
    float glitter_mask = step(0.95, noise_val);
    float glitter_flicker = step(0.7, hash12(floor(glitter_uv + TIME * 2.0)));
    float glitter = glitter_mask * glitter_flicker * spec_core * 2.0;
    
    // 5. ÉMISSION GLOW
    EMISSION = vec3(0.4, 0.6, 0.9) * toon_spec + vec3(0.9, 0.95, 1.0) * glitter;
}
