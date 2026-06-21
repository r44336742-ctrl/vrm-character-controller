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
    // 1. GEOMETRIC NORMAL (Fixes the "sand dune" look by using true surface curvature)
    vec3 dx = dFdx(VERTEX);
    vec3 dy = dFdy(VERTEX);
    vec3 geo_N = normalize(cross(dx, dy));
    if (geo_N.y < 0.0) geo_N = -geo_N; // Ensure pointing up
    
    // 2. MICRO-NORMAL MAPS (Scrolling ripples)
    vec2 uv1 = world_xz * 0.025 + TIME * vec2(0.015, -0.012);
    vec2 uv2 = world_xz * 0.05  + TIME * vec2(-0.014, -0.018);
    vec2 uv3 = world_xz * 0.12  + TIME * vec2(0.008, 0.022);
    
    vec3 n1 = texture(normalmap_a, uv1).rgb * 2.0 - 1.0;
    vec3 n2 = texture(normalmap_b, uv2).rgb * 2.0 - 1.0;
    vec3 n3 = texture(normalmap_a, uv3).rgb * 2.0 - 1.0; // High freq detail
    
    vec3 micro_n = normalize(n1 + n2 * 0.8 + n3 * 0.4);
    
    // Combine geometric large waves with micro ripples
    vec3 final_N = normalize(geo_N + micro_n * 0.35);
    
    // 3. DEPTH & FOAM COLORING
    float h = clamp(wave_height * 1.5, -1.0, 1.0) * 0.5 + 0.5;
    vec3 col = mix(albedo_deep, albedo_shallow, h);
    
    float foam_noise = texture(normalmap_b, world_xz * 0.15 + TIME * 0.05).r;
    float foam = smoothstep(0.65, 0.85, wave_height * 1.2 + foam_noise * 0.15);
    col = mix(col, vec3(0.15, 0.2, 0.35), foam * 0.6);
    
    // 4. FRESNEL WATER REFLECTIVITY
    vec3 V = normalize(VIEW);
    float NdotV = max(dot(final_N, V), 0.0);
    float fresnel = pow(1.0 - NdotV, 5.0);
    fresnel = mix(0.02, 1.0, fresnel); // 0.02 = base water reflectivity
    col *= (1.0 - fresnel * 0.8); // Darken body color where light passes through
    
    ALBEDO = col;
    METALLIC = metallic;
    ROUGHNESS = mix(roughness, 0.6, foam * 0.5);
    NORMAL_MAP = final_N * 0.5 + 0.5; // Output combined normal to lighting pipeline
    NORMAL_MAP_DEPTH = 1.0;

    // 5. HIGH-FREQUENCY GLITTER (Sparkling micro-facets)
    vec3 L = normalize(moon_dir);
    vec3 H = normalize(V + L);
    float NdotH = max(dot(final_N, H), 0.0);
    
    // Extremely sharp specular lobe for tight moon reflection
    float spec_lobe = pow(NdotH, 2048.0);
    
    // Scattered points in 3D space (moving slightly over time)
    vec3 grid_pos = vec3(world_xz * 12.0, TIME * 2.5);
    vec3 cell = floor(grid_pos);
    float h_val = hash13(cell);
    
    // Only 8% of grid cells contain a water droplet glint
    float active = step(0.92, h_val);
    
    // Tight dot shape within the cell
    vec3 cell_pos = fract(grid_pos) - 0.5;
    float dist = length(cell_pos);
    float dot_shape = smoothstep(0.15, 0.0, dist);
    float points = dot_shape * active;
    
    // Final glitter modulated by spec lobe
    float glitter = points * spec_lobe * 150.0;

    // 6. EMISSION & BLOOM TRIGGER
    // Broad, softer specular for the main moon path
    float broad_spec = pow(NdotH, 256.0) * 5.0 * (1.0 - foam);
    
    vec3 base_emission = vec3(0.002, 0.005, 0.01) * h;
    vec3 spec_emission = vec3(0.2, 0.35, 0.6) * broad_spec;
    vec3 glitter_emission = vec3(0.8, 0.95, 1.0) * glitter;
    
    // Push past 1.0 to trigger ACES tonemapper and bloom
    EMISSION = base_emission + spec_emission + glitter_emission;
}
