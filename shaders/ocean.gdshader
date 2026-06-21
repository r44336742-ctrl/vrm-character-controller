shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo_shallow : source_color = vec3(0.03, 0.07, 0.18);
uniform vec3 albedo_deep    : source_color = vec3(0.01, 0.03, 0.08);
uniform float metallic  = 0.05;
uniform float roughness = 0.45;

uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;

// --- 6 VAGUES GERSTNER (cascade multi-échelle) ---
// vec4(dir_x, dir_z, steepness, wavelength)

// Houle longue (background swell)
uniform vec4 wA = vec4(1.0,   0.3,  0.035, 80.0);
uniform vec4 wB = vec4(0.7,   1.0,  0.030, 65.0);

// Vagues moyennes (sea waves)
uniform vec4 wC = vec4(1.0,   0.6,  0.06,  22.0);
uniform vec4 wD = vec4(-0.5,  1.0,  0.05,  18.0);
uniform vec4 wE = vec4(0.9,  -0.4,  0.05,  14.0);

// Courtes (chop)
uniform vec4 wF = vec4(-0.8,  0.6,  0.04,   7.0);

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
	float t = TIME * 0.55; // Vitesse légèrement réduite pour plus de naturel

	vec3 off = vec3(0.0);
	off += gerstner(wA, VERTEX, t);
	off += gerstner(wB, VERTEX, t);
	off += gerstner(wC, VERTEX, t);
	off += gerstner(wD, VERTEX, t);
	off += gerstner(wE, VERTEX, t);
	off += gerstner(wF, VERTEX, t);

	wave_height = off.y;
	VERTEX += off;

	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Normal maps scrollant à des vitesses différentes
	vec2 uv1 = world_xz * 0.07 + TIME * vec2(0.04,  0.025);
	vec2 uv2 = world_xz * 0.13 + TIME * vec2(-0.03, 0.02);

	vec3 n1 = texture(normalmap_a, uv1).rgb;
	vec3 n2 = texture(normalmap_b, uv2).rgb;
	vec3 nm = mix(n1, n2, 0.5);

	// Couleur : plus sombre dans les creux, plus claire sur les crêtes
	float h = clamp(wave_height * 0.8, -1.0, 1.0) * 0.5 + 0.5;
	vec3 col = mix(albedo_deep, albedo_shallow, h);

	// Écume sur les crêtes hautes
	float foam = smoothstep(0.55, 0.85, wave_height);
	col = mix(col, vec3(0.15, 0.22, 0.35), foam * 0.5);

	ALBEDO     = col;
	METALLIC   = metallic;
	ROUGHNESS  = mix(roughness, 0.7, foam * 0.3);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 2.0;

	// Émission douce — assure la lisibilité même sans lumière directe
	EMISSION = vec3(0.008, 0.016, 0.045) + vec3(0.012, 0.02, 0.04) * h;
}
