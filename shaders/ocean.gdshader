shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo_shallow : source_color = vec3(0.03, 0.07, 0.18);
uniform vec3 albedo_deep    : source_color = vec3(0.01, 0.03, 0.08);
uniform float metallic  = 0.05;
uniform float roughness = 0.45;

uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;

// --- 6 VAGUES GERSTNER ULTRA-IRRÉGULIÈRES ---
// Directions basées sur l'Angle d'Or (~137.5 degrés) pour briser la symétrie.
// Longueurs d'ondes multipliées par 4 pour détruire le damier, et pentes divisées par 4 pour garder LA MÊME hauteur !
uniform vec4 wA = vec4( 1.000,  0.000, 0.040, 244.0);
uniform vec4 wB = vec4(-0.737,  0.675, 0.035, 172.0);
uniform vec4 wC = vec4( 0.087, -0.996, 0.030, 116.0);
uniform vec4 wD = vec4( 0.605,  0.795, 0.022,  76.0);
uniform vec4 wE = vec4(-0.983, -0.183, 0.015,  44.0);
uniform vec4 wF = vec4( 0.843, -0.536, 0.010,  28.0);

varying vec2 world_xz;
varying float wave_height;

vec3 gerstner(vec4 w, float phase, vec3 p, float t) {
	float k = 6.28318 / w.w;
	float c = sqrt(9.8 / k);
	vec2  d = normalize(w.xy);
	float f = k * (dot(d, p.xz) - c * t) + phase;
	float a = w.z / k;
	return vec3(d.x * a * cos(f),
	            a * sin(f),
	            d.y * a * cos(f));
}

void vertex() {
	float t = TIME * 0.4; // Légèrement ralenti pour donner un effet de masse d'eau lourde

	vec3 off = vec3(0.0);
	
	// Perturbation spatiale pour casser définitivement le "damier" (checkerboard)
	float distortion = sin(VERTEX.x * 0.00314 + VERTEX.z * 0.00271) * 2.0 
	                 + cos(VERTEX.x * 0.00192 - VERTEX.z * 0.00412) * 1.5;

	// Ajout de phases asymétriques pour décaler les vagues + la distorsion aléatoire
	off += gerstner(wA, 0.00 + distortion, VERTEX, t);
	off += gerstner(wB, 1.23 - distortion * 0.8, VERTEX, t);
	off += gerstner(wC, 2.71 + distortion * 1.2, VERTEX, t);
	off += gerstner(wD, 3.14 - distortion, VERTEX, t);
	off += gerstner(wE, 5.05 + distortion * 0.5, VERTEX, t);
	off += gerstner(wF, 0.88 - distortion * 1.5, VERTEX, t);

	wave_height = off.y;
	VERTEX += off;

	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv1 = world_xz * 0.07 + TIME * vec2(0.04,  0.025);
	vec2 uv2 = world_xz * 0.13 + TIME * vec2(-0.03, 0.02);

	// --- DÉTAILS DYNAMIQUES (Moins parfait au loin) ---
	float dist = length(VERTEX); 
	float lod = clamp((dist - 150.0) / 800.0, 0.0, 3.0); 

	vec3 n1 = textureLod(normalmap_a, uv1, lod).rgb;
	vec3 n2 = textureLod(normalmap_b, uv2, lod).rgb;
	vec3 nm = mix(n1, n2, 0.5);

	float h = clamp(wave_height * 1.2, -1.0, 1.0) * 0.5 + 0.5;
	vec3 col = mix(albedo_deep, albedo_shallow, h);

	float foam = smoothstep(0.35, 0.65, wave_height);
	col = mix(col, vec3(0.18, 0.25, 0.4), foam * 0.6);

	ALBEDO     = col;
	METALLIC   = metallic;
	ROUGHNESS  = mix(0.15, 0.75, foam * 0.4);
	SPECULAR   = 0.0; 
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 5.0;

	// --- DÉTAILS PARTOUT (Même dans l'obscurité) ---
	// On extrait la pente des micro-vagues pour les illuminer artificiellement !
	vec3 un_mix = normalize(nm * 2.0 - 1.0);
	float slope = length(un_mix.xy); // 0 quand plat, > 0 quand pentu
	// On crée une lueur ambiante qui révèle les vagues partout, indépendamment de la lumière
	float ambient_details = smoothstep(0.1, 0.8, slope);

	// Émission de base + détails des vagues révélés PARTOUT
	EMISSION = vec3(0.005, 0.010, 0.025) + vec3(0.010, 0.020, 0.04) * h 
	         + vec3(0.1, 0.15, 0.25) * ambient_details;
}

void light() {
	// --- LUMIÈRE DIFFUSE STANDARD ---
	float NdotL = max(0.0, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += clamp(NdotL, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR * ALBEDO;
	
	// --- REFLET SPÉCULAIRE GIGANTESQUE ---
	vec3 H = normalize(VIEW + LIGHT);
	float base_spec = max(dot(NORMAL, H), 0.0);
	
	// Au lieu d'utiliser pow() qui concentre la lumière en une ligne fine,
	// on utilise smoothstep pour que TOUTE vague un peu alignée s'illumine !
	// Cela crée une "autoroute" immense qui prend presque tout l'écran.
	float spec = smoothstep(0.4, 0.95, base_spec);
	
	// --- OMBRES DOUCES (Réduction de 20% à 35% aléatoire) ---
	float cloud_shadow = sin(world_xz.x * 0.002 + TIME * 0.01) * cos(world_xz.y * 0.0015 - TIME * 0.015);
	float opacity_multiplier = mix(0.65, 0.80, (cloud_shadow + 1.0) * 0.5);
	
	float final_power = 1.0 * opacity_multiplier;
	SPECULAR_LIGHT += spec * LIGHT_COLOR * ATTENUATION * final_power;
}
