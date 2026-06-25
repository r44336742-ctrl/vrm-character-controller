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
// On restaure les longueurs d'ondes originales pour retrouver les belles vagues asymétriques !
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
	
	// Perturbation spatiale pour casser définitivement le "damier" (checkerboard)
	// On utilise des sinus avec des fréquences très basses et irrationnelles pour déformer la phase.
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
	// Calcul de la distance pour adoucir très légèrement les détails au loin (LOD dynamique)
	float dist = length(VERTEX); 
	float lod = clamp((dist - 150.0) / 800.0, 0.0, 3.0); 

	// On lit la texture avec le LOD calculé pour éviter l'effet "bruit blanc trop parfait"
	vec3 n1 = textureLod(normalmap_a, uv1, lod).rgb;
	vec3 n2 = textureLod(normalmap_b, uv2, lod).rgb;
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
	SPECULAR   = 0.0; // On désactive le spéculaire standard car on va créer le nôtre dans light() !
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 5.0;

	// Émission de base très légère pour l'ambiance nocturne de l'eau
	EMISSION = vec3(0.005, 0.010, 0.025) + vec3(0.010, 0.020, 0.04) * h;
}

void light() {
	// --- LUMIÈRE DIFFUSE STANDARD ---
	float NdotL = max(0.0, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += clamp(NdotL, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR * ALBEDO;
	
	// --- REFLET SPÉCULAIRE UNIFORME SUR TOUTE LA SURFACE ---
	// On utilise le half-vector standard (sans écrasement horizontal) pour que les normalmaps
	// produisent du clapotis visible partout sur l'eau, pas seulement dans un ovale centré sur la lune.
	vec3 H = normalize(VIEW + LIGHT);

	// Spéculaire modulé par la normalmap (qui encode le clapotis micro-vague)
	float spec = pow(max(dot(NORMAL, H), 0.0), 80.0);

	// CORRECTION BUG ÉCRAN BLANC :
	// On annule le reflet si la caméra tourne le dos à la lumière (quand la lumière passe derrière la caméra)
	// En espace vue (VIEW), l'axe Z pointe vers l'arrière de la caméra.
	// Si LIGHT.z > 0, la lumière est derrière nous !
	float facing_light = smoothstep(0.2, -0.2, LIGHT.z);
	spec *= facing_light;

	// --- OMBRES DOUCES (Réduction de 20% à 35% aléatoire) ---
	// On crée un bruit très basse fréquence basé sur la position mondiale de l'eau
	// pour simuler d'immenses nuages invisibles qui masquent légèrement la lune.
	// La fréquence est très basse pour que les transitions (fondus) fassent des centaines de mètres.
	float cloud_shadow = sin(world_xz.x * 0.002 + TIME * 0.01) * cos(world_xz.y * 0.0015 - TIME * 0.015);

	// cloud_shadow varie de -1 à 1. On le convertit en un multiplicateur d'opacité entre 0.65 et 0.80
	// (0.65 = baisse de 35%, 0.80 = baisse de 20%)
	float opacity_multiplier = mix(0.65, 0.80, (cloud_shadow + 1.0) * 0.5);

	// On conserve un final_power plus modeste maintenant que le reflet est réparti sur tout l'océan
	float final_power = 1.1 * opacity_multiplier;

	// On ajoute ce reflet nuancé à la lumière spéculaire
	SPECULAR_LIGHT += spec * LIGHT_COLOR * ATTENUATION * final_power;
}
