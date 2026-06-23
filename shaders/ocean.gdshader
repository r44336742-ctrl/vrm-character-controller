shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo_shallow : source_color = vec3(0.03, 0.07, 0.18);
uniform vec3 albedo_deep    : source_color = vec3(0.01, 0.03, 0.08);
uniform float metallic  = 0.05;
uniform float roughness = 0.45;

uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;

// Longueurs d'onde GIGANTESQUES pour détruire le motif "damier" au loin !
// On a divisé la pente (z) par 15 pour garder exactement la même hauteur de vague qu'avant !
uniform vec4 wA = vec4( 1.000,  0.000, 0.0107, 915.0);
uniform vec4 wB = vec4(-0.737,  0.675, 0.0093, 645.0);
uniform vec4 wC = vec4( 0.087, -0.996, 0.0080, 435.0);
uniform vec4 wD = vec4( 0.605,  0.795, 0.0060, 285.0);
uniform vec4 wE = vec4(-0.983, -0.183, 0.0040, 165.0);
uniform vec4 wF = vec4( 0.843, -0.536, 0.0026, 105.0);

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
	
	// --- REFLET SPÉCULAIRE "ÉLARGI FOIS MILLE" ---
	// Pour que la lumière frappe PARTOUT et révèle les détails de l'eau sur toute la largeur,
	// on ignore complètement l'axe horizontal (X) dans le calcul du reflet !
	// Ainsi, le reflet ne dépend que de l'inclinaison verticale des vagues.
	vec3 mod_VIEW = normalize(vec3(0.0, VIEW.y, VIEW.z));
	vec3 mod_LIGHT = normalize(vec3(0.0, LIGHT.y, LIGHT.z));
	vec3 mod_H = normalize(mod_VIEW + mod_LIGHT);
	
	// On calcule le reflet spéculaire avec une forte concentration (brillance)
	float spec = pow(max(dot(NORMAL, mod_H), 0.0), 30.0);
	
	// On ajoute ce reflet gigantesque à la lumière spéculaire (opacité baissée de 30% : 2.0 -> 1.4)
	SPECULAR_LIGHT += spec * LIGHT_COLOR * ATTENUATION * 1.4;
}
