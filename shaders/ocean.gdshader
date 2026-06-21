shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo_shallow : source_color = vec3(0.03, 0.07, 0.18);
uniform vec3 albedo_deep    : source_color = vec3(0.01, 0.03, 0.08);
uniform float metallic  = 0.05;
uniform float roughness = 0.45;

uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;

// --- 5 VAGUES GERSTNER RÉALISTES ---
// Steepness élevé = crêtes pointues, creux plats (vagues réelles)
// Total steepness ~0.75 (proche du max, avant looping)
uniform vec4 wA = vec4(1.0,   0.2,  0.22, 40.0);  // Houle dominante
uniform vec4 wB = vec4(0.8,   1.0,  0.18, 28.0);  // Houle croisée
uniform vec4 wC = vec4(1.0,   0.7,  0.14, 16.0);  // Vague moyenne
uniform vec4 wD = vec4(-0.4,  1.0,  0.12, 10.0);  // Contre-vague
uniform vec4 wE = vec4(0.6,  -0.8,  0.09,  6.0);  // Chop

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

	EMISSION = vec3(0.008, 0.016, 0.045) + vec3(0.015, 0.025, 0.05) * h;
}
