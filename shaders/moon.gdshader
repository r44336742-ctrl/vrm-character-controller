shader_type spatial;
render_mode unshaded, cull_back;

// --- LUNE DÉTAILLÉE AVEC CRATÈRES PROCÉDURAUX ---

uniform vec3 moon_color : source_color = vec3(0.85, 0.88, 0.95);
uniform float glow_intensity = 3.5;

// Bruit pour les cratères
vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}

float voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float min_dist = 1.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash22(i + neighbor) * 0.5 + 0.5;
			float d = length(neighbor + point - f);
			min_dist = min(min_dist, d);
		}
	}
	return min_dist;
}

float gradient_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(hash22(i), f);
	float b = dot(hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}

void fragment() {
	// Coordonnées depuis le centre du quad/sphere
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	
	// Disque de la lune
	if (dist > 1.0) {
		discard;
	}
	
	// Projection sphérique (UV → surface de la sphère)
	float z_sphere = sqrt(1.0 - dist * dist);
	vec2 sphere_uv = uv * 0.5 + 0.5;
	
	// --- SURFACE LUNAIRE HAUTE DÉFINITION ---
	// Grands cratères (Voronoi)
	float crater_large = voronoi(sphere_uv * 15.0 + vec2(42.0, 17.0));
	crater_large = smoothstep(0.1, 0.35, crater_large);
	
	// Cratères moyens
	float crater_med = voronoi(sphere_uv * 35.0 + vec2(13.0, 7.0));
	crater_med = smoothstep(0.12, 0.3, crater_med);
	
	// Petits cratères
	float crater_small = voronoi(sphere_uv * 75.0 + vec2(5.0, 31.0));
	crater_small = smoothstep(0.15, 0.35, crater_small);
	
	// Micro cratères (extra détails)
	float crater_micro = voronoi(sphere_uv * 150.0 + vec2(88.0, 12.0));
	crater_micro = smoothstep(0.2, 0.4, crater_micro);
	
	// Texture de surface (taches/maria)
	float maria = gradient_noise(sphere_uv * 8.0 + vec2(100.0, 200.0));
	float detail = gradient_noise(sphere_uv * 25.0 + vec2(50.0, 80.0));
	float micro_detail = gradient_noise(sphere_uv * 60.0 + vec2(10.0, 20.0)); // extra texture
	
	// Combiner
	float surface = 1.0;
	surface *= mix(0.7, 1.0, crater_large);   // Grands cratères sombres
	surface *= mix(0.8, 1.0, crater_med);      // Cratères moyens
	surface *= mix(0.9, 1.0, crater_small);    // Petits cratères
	surface *= mix(0.95, 1.0, crater_micro);   // Micro cratères
	surface *= mix(0.6, 1.0, maria);           // Mers lunaires (zones sombres)
	surface *= mix(0.85, 1.15, detail);        // Détail fin
	surface *= mix(0.9, 1.1, micro_detail);    // Micro rugosité
	
	// Éclairage : limb darkening (bords plus sombres)
	float limb = z_sphere;
	limb = pow(limb, 0.6); // Doux
	
	// Couleur finale
	vec3 col = moon_color * surface * limb;
	
	// Halo lumineux sur les bords
	float edge_glow = 1.0 - smoothstep(0.85, 1.0, dist);
	float outer_glow = 1.0 - smoothstep(0.7, 1.0, dist);
	
	ALBEDO = col;
	EMISSION = col * glow_intensity * outer_glow;
	ALPHA = edge_glow;
}
