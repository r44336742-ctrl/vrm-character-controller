shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo_shallow : source_color = vec3(0.03, 0.07, 0.18);
uniform vec3 albedo_deep    : source_color = vec3(0.01, 0.03, 0.08);
uniform float metallic  = 0.05;
uniform float roughness = 0.45;

uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;

// --- 5 VAGUES GERSTNER RÉALISTES ---
// Directions désalignées pour éviter l'effet quadrillage (grid/rhombus pattern)
// Steepness modéré pour des vagues réalistes sans chevauchement excessif
uniform vec4 wA = vec4(1.0,   0.35, 0.18, 45.0);  // Houle dominante
uniform vec4 wB = vec4(0.2,   1.0,  0.15, 30.0);  // Houle croisée
uniform vec4 wC = vec4(-0.6,  0.8,  0.12, 18.0);  // Vague moyenne
uniform vec4 wD = vec4(0.85, -0.4,  0.09, 11.0);  // Contre-vague
uniform vec4 wE = vec4(-0.5, -0.9,  0.06,  7.0);  // Chop

varying vec2 world_xz;
varying float wave_height;

vec3 gerstner(vec4 w, vec3 p, float t) {
	float k = 6.28318 / w.w;
	float c = sqrt(9.8 / k);
	vec2  d = normalize(w.xy);
	float f = k * (dot(d, p.xz) - c * t);
	float a = w.z / k;
	return vec3(d.x * a * cos(f),
	            a * sin(f),
	            d.y * a * cos(f));
}

void vertex() {
	float t = TIME * 0.5;

	vec3 off = vec3(0.0);
	off += gerstner(wA, VERTEX, t);
	off += gerstner(wB, VERTEX, t);
	off += gerstner(wC, VERTEX, t);
	off += gerstner(wD, VERTEX, t);
	off += gerstner(wE, VERTEX, t);

	wave_height = off.y;
	VERTEX += off;

	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv1 = world_xz * 0.07 + TIME * vec2(0.04,  0.025);
	vec2 uv2 = world_xz * 0.13 + TIME * vec2(-0.03, 0.02);

	vec3 n1 = texture(normalmap_a, uv1).rgb;
	vec3 n2 = texture(normalmap_b, uv2).rgb;
	vec3 nm = mix(n1, n2, 0.5);

	float h = clamp(wave_height * 1.2, -1.0, 1.0) * 0.5 + 0.5;
	vec3 col = mix(albedo_deep, albedo_shallow, h);

	// Écume sur les crêtes pointues
	float foam = smoothstep(0.35, 0.65, wave_height);
	col = mix(col, vec3(0.18, 0.25, 0.4), foam * 0.6);

	ALBEDO     = col;
	METALLIC   = metallic;
	ROUGHNESS  = mix(roughness, 0.75, foam * 0.4);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 2.0;

	// --- SCINTILLEMENT SPÉCULAIRE (Glitter) ---
	// Bruit haute fréquence pour créer des milliers de points
	vec2 glitter_uv = world_xz * 6.0;
	float noise_val = fract(sin(dot(glitter_uv, vec2(12.9898, 78.233))) * 43758.5453);
	
	// Seuil animé pour que les points scintillent
	float glitter_thresh = 0.985 + sin(TIME * 6.0 + noise_val * 15.0) * 0.01;
	float glitter = step(glitter_thresh, noise_val);
	
	// Aligner avec la lune (-35, -30 en Euler -> approché ici)
	vec3 view_dir = normalize(VIEW);
	vec3 moon_dir = normalize(vec3(-0.6, 0.6, -0.8)); // Direction depuis l'océan vers la lune
	vec3 half_vec = normalize(view_dir + moon_dir);
	
	// Utilisation de la normale perturbée (NORMAL_MAP n'est appliqué qu'après fragment(), 
	// mais on peut utiliser l'onde ou la normale approximative de base)
	// Pour simplifier et être performant, on utilise vec3(0, 1, 0) modulé par la vague :
	vec3 base_normal = normalize(vec3(-nm.x, 2.0, -nm.z));
	
	float spec_align = pow(max(dot(base_normal, half_vec), 0.0), 512.0); // Spéculaire très fin
	float final_glitter = glitter * spec_align * 15.0; // Forte émission ciblée

	// Émission globale (ambiance) + Scintillement
	vec3 base_emission = vec3(0.005, 0.01, 0.03) + vec3(0.01, 0.015, 0.03) * h;
	vec3 glitter_emission = vec3(0.6, 0.8, 1.0) * final_glitter;
	
	EMISSION = base_emission + glitter_emission;
}
