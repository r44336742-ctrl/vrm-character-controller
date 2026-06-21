shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Couleurs de base
uniform vec3 color_grass : source_color = vec3(0.08, 0.08, 0.10);
uniform vec3 color_dirt  : source_color = vec3(0.10, 0.10, 0.12);
uniform vec3 color_rock  : source_color = vec3(0.06, 0.06, 0.08);
uniform vec3 color_stone_tile : source_color = vec3(0.12, 0.12, 0.14); // Dalle claire
uniform vec3 color_stone_joint : source_color = vec3(0.04, 0.04, 0.05); // Joint entre dalles

varying float world_y;
varying vec3 world_pos;

void vertex() {
    vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
    world_y = wp.y;
    world_pos = wp.xyz;
}

// Bruit simple pour varier la surface
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    float slope = 1.0 - NORMAL.y;
    
    vec3 col = color_grass;
    col = mix(col, color_dirt, smoothstep(0.1, 0.25, slope));
    col = mix(col, color_rock, smoothstep(0.3, 0.6, slope));
    col = mix(col, color_rock, smoothstep(-5.0, -15.0, world_y));
    
    // --- DALLES DE PIERRE (zone plate du domaine) ---
    // Distance au centre du domaine (capsule de Z=-30 à Z=50)
    float closest_z = clamp(world_pos.z, -30.0, 50.0);
    float dist_estate = length(vec2(world_pos.x, world_pos.z - closest_z));
    
    if (dist_estate < 25.0 && slope < 0.15) {
        // Grille de dalles 2x2m
        vec2 tile_uv = world_pos.xz / 2.0;
        vec2 f = fract(tile_uv);
        
        // Joint entre les dalles (bordures étroites plus sombres)
        float joint = step(0.05, f.x) * step(f.x, 0.95) * step(0.05, f.y) * step(f.y, 0.95);
        
        // Variation par dalle (chaque dalle a une teinte légèrement différente)
        vec2 tile_id = floor(tile_uv);
        float tile_var = hash(tile_id) * 0.15;
        
        vec3 tile_col = mix(color_stone_joint, color_stone_tile + tile_var, joint);
        
        // Blend progressif avec le terrain naturel
        float blend = smoothstep(25.0, 15.0, dist_estate);
        col = mix(col, tile_col, blend);
    }
    
    // Grain de surface
    vec2 p = UV * 150.0;
    float noise = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
    col *= mix(0.92, 1.08, noise);
    
    ALBEDO = col;
    ROUGHNESS = 0.88;
    METALLIC = 0.0;
}
