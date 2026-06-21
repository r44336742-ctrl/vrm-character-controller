shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

// --- TEXTURE & COULEUR ---
uniform sampler2D albedo_texture : source_color;
uniform vec4 dress_color : source_color = vec4(0.02, 0.02, 0.04, 1.0); // Noir gothique profond

// --- PARAMÈTRES VOLUME (Vertex) ---
uniform float flare_amount : hint_range(0.0, 1.0) = 0.15; // Gonflement de la robe
uniform float top_cutoff : hint_range(-2.0, 2.0) = 1.0; // Hauteur où la robe commence (Y)
uniform float bottom_cutoff : hint_range(-2.0, 2.0) = -0.5; // Hauteur où elle s'arrête (chevilles)

// --- PARAMÈTRES DENTELLE (Fragment) ---
uniform float lace_scale : hint_range(5.0, 50.0) = 20.0;
uniform float lace_thickness : hint_range(0.01, 0.5) = 0.08;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

// --- ANIMATION ---
uniform float movement_intensity = 0.0;
uniform float sway_speed : hint_range(0.0, 10.0) = 3.0;

void vertex() {
    // 1. Calculer un facteur basé sur la hauteur (Y) du vertex
    // 1.0 en bas (jambes), 0.0 en haut (torse)
    float dress_factor = 1.0 - smoothstep(bottom_cutoff, top_cutoff, VERTEX.y);
    
    // 2. Gonfler le mesh vers l'extérieur (le long de sa normale) pour faire le volume de la robe
    vec3 displaced = VERTEX + NORMAL * flare_amount * dress_factor;
    
    // 3. Ajouter un balancement (sway) en bas de la robe pendant la marche
    float sway = sin(TIME * sway_speed + VERTEX.y * 3.0) * 0.05 * movement_intensity * dress_factor;
    displaced.x += sway;
    displaced.z += sway * 0.5;
    
    VERTEX = displaced;
}

void fragment() {
    // 1. Récupérer la couleur de base
    vec4 tex_color = texture(albedo_texture, UV);
    
    // 2. Générer le motif de dentelle (Réseau hexagonal de cercles superposés)
    vec2 uv = UV * lace_scale;
    
    // Déformer légèrement les UV pour un aspect organique
    uv.x += sin(UV.y * 10.0) * 0.1;
    
    // Grille 1
    vec2 grid1 = fract(uv) - 0.5;
    float circle1 = length(grid1);
    
    // Grille 2 (décalée pour créer des intersections de dentelle)
    vec2 grid2 = fract(uv + 0.5) - 0.5;
    float circle2 = length(grid2);
    
    // Combiner : on garde les lignes (edges) pour faire les "fils" de la dentelle
    float pattern = min(circle1, circle2);
    
    // 3. Appliquer la transparence : on garde ce qui est proche des lignes (pattern < épaisseur)
    float lace_alpha = smoothstep(lace_thickness, lace_thickness + 0.02, pattern);
    
    // 4. Masquer le haut du corps (ne garder que la robe)
    // Si le vertex est trop haut, on le rend transparent
    float visibility_mask = step(VERTEX.y, top_cutoff) * step(bottom_cutoff, VERTEX.y);
    
    // 5. Output final
    ALBEDO = dress_color.rgb;
    ALPHA = (1.0 - lace_alpha) * visibility_mask * tex_color.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
