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
// Longueurs d'onde basées sur des nombres premiers pour empêcher le bouclage du motif.
uniform vec4 wA = vec4( 1.000,  0.000, 0.16, 61.0);
uniform vec4 wB = vec4(-0.737,  0.675, 0.14, 43.0);
uniform vec4 wC = vec4( 0.087, -0.996, 0.12, 29.0);
uniform vec4 wD = vec4( 0.605,  0.795, 0.09, 19.0);
uniform vec4 wE = vec4(-0.983, -0.183, 0.06, 11.0);
uniform vec4 wF = vec4( 0.843, -0.536, 0.04,  7.0);

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
	// Ajout de phases asymétriques pour décaler les vagues
	off += gerstner(wA, 0.00, VERTEX, t);
	off += gerstner(wB, 1.23, VERTEX, t);
	off += gerstner(wC, 2.71, VERTEX, t);
	off += gerstner(wD, 3.14, VERTEX, t);
	off += gerstner(wE, 5.05, VERTEX, t);
	off += gerstner(wF, 0.88, VERTEX, t);

	wave_height = off.y;
	VERTEX += off;

	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv1 = world_xz * 0.07 + TIME * vec2(0.04,  0.025);
	vec2 uv2 = world_xz * 0.13 + TIME * vec2(-0.03, 0.02);

	// On force la lecture de la texture à pleine résolution partout (Mipmap 0.0)
	// Cela garantit que les détails des vagues ne disparaissent jamais au loin !
	vec3 n1 = textureLod(normalmap_a, uv1, 0.0).rgb;
	vec3 n2 = textureLod(normalmap_b, uv2, 0.0).rgb;
	vec3 nm = mix(n1, n2, 0.5);

	float h = clamp(wave_height * 1.2, -1.0, 1.0) * 0.5 + 0.5;
	vec3 col = mix(albedo_deep, albedo_shallow, h);

	// Écume sur les crêtes pointues
	float foam = smoothstep(0.35, 0.65, wave_height);
	col = mix(col, vec3(0.18, 0.25, 0.4), foam * 0.6);

	ALBEDO     = col;
	METALLIC   = metallic;
	// L'eau est très lisse (roughness faible) pour un effet mouillé/réfléchissant
	ROUGHNESS  = mix(0.15, 0.75, foam * 0.4);
	SPECULAR   = 0.8; // Reflet spéculaire très fort pour bien capter la lune
	NORMAL_MAP = nm;
	
	// En augmentant énormément la profondeur de la normale (bumpiness),
	// on force la lumière de la lune à s'accrocher sur les côtés des vagues.
	// Cela "éclate" naturellement le reflet spéculaire pour le rendre super large
	// et créer des milliers de paillettes réalistes sur toute la mer !
	NORMAL_MAP_DEPTH = 5.0;

	// Émission de base très légère pour l'ambiance nocturne de l'eau
	EMISSION = vec3(0.005, 0.010, 0.025) + vec3(0.010, 0.020, 0.04) * h;
}
