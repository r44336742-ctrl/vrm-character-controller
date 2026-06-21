shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color_grass : source_color = vec3(0.01, 0.01, 0.012); // Herbe cendre/noire
uniform vec3 color_dirt  : source_color = vec3(0.015, 0.01, 0.01); // Terre calcinée
uniform vec3 color_rock  : source_color = vec3(0.005, 0.005, 0.01); // Roche obsidienne

varying float world_y;

void vertex() {
    world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
    float slope = 1.0 - NORMAL.y; // 0 = plat, 1 = vertical
    
    vec3 col = color_grass;
    
    // Terre sur les pentes moyennes
    col = mix(col, color_dirt, smoothstep(0.1, 0.25, slope));
    
    // Roche sur les pentes raides
    col = mix(col, color_rock, smoothstep(0.3, 0.6, slope));
    
    // Forcer la roche si on descend bas (la falaise)
    col = mix(col, color_rock, smoothstep(-5.0, -15.0, world_y));
    
    // Ajouter un peu de bruit pour la texture
    // Un bruit simple basé sur les UVs/Position
    vec2 p = UV * 150.0;
    float noise = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
    col *= mix(0.9, 1.1, noise); // Léger grain de surface
    
    ALBEDO = col;
    ROUGHNESS = 0.95;
    METALLIC = 0.0;
}
