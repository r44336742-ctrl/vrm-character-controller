shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// --- WATER PROPERTIES ---
uniform vec3 albedo_shallow : source_color = vec3(0.03, 0.07, 0.18);
uniform vec3 albedo_deep    : source_color = vec3(0.01, 0.03, 0.08);
uniform float metallic  = 0.0; // Pure water is dielectric, specular handles reflections
uniform float roughness = 0.15; // Calm water base roughness

// --- TEXTURES ---
uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;

// --- MOONLIGHT ---
uniform vec3 moon_dir = normalize(vec3(-0.4, 0.6, -0.7));

// --- 6-WAVE GERSTNER CASCADE (Tuned for deep ocean swell + chop) ---
// dir_x, dir_y, steepness, wavelength
uniform vec4 wA = vec4(1.0,  0.3, 0.06, 65.0); // Large Swell
uniform vec4 wB = vec4(-0.4, 1.0, 0.08, 50.0); // Cross Swell
uniform vec4 wC = vec4(0.8, -0.7, 0.12, 25.0); // Mid Wave
uniform vec4 wD = vec4(-1.0,-0.2, 0.15, 18.0); // Mid Cross
uniform vec4 wE = vec4(0.2,  0.9, 0.18,  9.0); // Chop
uniform vec4 wF = vec4(-0.7, 0.6, 0.20,  5.5); // Micro Chop

// Random phases to break grid repetition
uniform float phaseA = 1.3;
uniform float phaseB = 2.7;
uniform float phaseC = 4.1;
uniform float phaseD = 5.9;
uniform float phaseE = 8.2;
uniform float phaseF = 11.5;

varying vec2 world_xz;
varying float wave_height;

vec3 gerstner(vec4 w, vec3 p, float t, float phase) {
    float k = 6.28318 / w.w;
    float c = sqrt(9.8 / k);
    vec2  d = normalize(w.xy);
    float f = k * (dot(d, p.xz) - c * t + phase);
    float a = w.z / k;
    
    // Returns (x_offset, y_height, z_offset)
    return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}

void vertex() {
    float t = TIME * 0.6; // Slowed time for atmospheric horror weight
    vec3 off = vec3(0.0);
    
    off += gerstner(wA, VERTEX, t, phaseA);
    off += gerstner(wB, VERTEX, t, phaseB);
    off += gerstner(wC, VERTEX, t, phaseC);
    off += gerstner(wD, VERTEX, t, phaseD);
    off += gerstner(wE, VERTEX, t, phaseE);
    off += gerstner(wF, VERTEX, t, phaseF);
    
    wave_height = off.y;
    VERTEX += off;
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

// High-quality 3D hash for scattered glitter points
float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
    // 1. MICRO-NORMAL MAPS (Scrolling ripples)
    vec2 uv1 = world_xz * 0.025 + TIME * vec2(0.015, -0.012);
    vec2 uv2 = world_xz * 0.05  + TIME * vec2(-0.014, -0.018);
    vec2 uv3 = world_xz * 0.12  + TIME * vec2(0.008, 0.022);
    
    vec3 n1 = texture(normalmap_a, uv1).rgb * 2.0 - 1.0;
    vec3 n2 = texture(normalmap_b, uv2).rgb * 2.0 - 1.0;
    vec3 n3 = texture(normalmap_a, uv3).rgb * 2.0 - 1.0; // High freq detail
    
    vec3 micro_n = normalize(n1 + n2 * 0.8 + n3 * 0.4);
    
    // Pour la macro-géométrie, on laisse Godot gérer ou on utilise NORMAL_MAP directement
    // Assigner une normale View-Space dans NORMAL_MAP cassait tout. On utilise l'espace tangent classique.
    NORMAL_MAP = micro_n * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 1.0;
    
    // 2. DEPTH & FOAM COLORING
    float h = clamp(wave_height * 1.5, -1.0, 1.0) * 0.5 + 0.5;
    vec3 col = mix(albedo_deep, albedo_shallow, h);
    
    float foam_noise = texture(normalmap_b, world_xz * 0.15 + TIME * 0.05).r;
    float foam = smoothstep(0.65, 0.85, wave_height * 1.2 + foam_noise * 0.15);
    col = mix(col, vec3(0.15, 0.2, 0.35), foam * 0.6);
    
    ALBEDO = col;
    METALLIC = metallic;
    ROUGHNESS = mix(roughness, 0.6, foam * 0.5);

    // 3. HIGH-FREQUENCY GLITTER (Sparkling micro-facets)
    // Convertir la direction de la lune (World Space) en View Space pour les calculs de spéculaire
    vec3 view_space_moon_dir = (VIEW_MATRIX * vec4(moon_dir, 0.0)).xyz;
    vec3 L = normalize(view_space_moon_dir);
    vec3 V = normalize(VIEW);
    vec3 H = normalize(V + L);
    
    // On doit utiliser NORMAL (qui est View Space et mis à jour par Godot après NORMAL_MAP) 
    // mais dans fragment(), NORMAL n'inclut pas encore NORMAL_MAP sauf si on l'applique.
    // On utilise une approximation View Space de la normale:
    vec3 approx_N = normalize(TANGENT * micro_n.x + BINORMAL * micro_n.y + NORMAL * micro_n.z);
    
    float NdotH = max(dot(approx_N, H), 0.0);
    float spec_lobe = pow(NdotH, 2048.0);
    
    // Points éparpillés
    vec3 grid_pos = vec3(world_xz * 12.0, TIME * 2.5);
    vec3 cell = floor(grid_pos);
    float h_val = hash13(cell);
    float active = step(0.92, h_val); // 8% des cellules
    
    vec3 cell_pos = fract(grid_pos) - 0.5;
    float dist = length(cell_pos);
    float dot_shape = smoothstep(0.15, 0.0, dist);
    float points = dot_shape * active;
    
    float glitter = points * spec_lobe * 150.0;

    // 4. EMISSION
    float broad_spec = pow(NdotH, 256.0) * 5.0 * (1.0 - foam);
    
    vec3 base_emission = vec3(0.002, 0.005, 0.01) * h;
    vec3 spec_emission = vec3(0.2, 0.35, 0.6) * broad_spec;
    vec3 glitter_emission = vec3(0.8, 0.95, 1.0) * glitter;
    
    // Éviter les explosions de bloom
    spec_emission = min(spec_emission, vec3(2.0));
    glitter_emission = min(glitter_emission, vec3(5.0));
    
    EMISSION = base_emission + spec_emission + glitter_emission;
}
