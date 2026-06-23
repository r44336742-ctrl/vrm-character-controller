shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform sampler2D moon_texture : source_color, filter_linear_mipmap;
uniform vec3 moon_color : source_color = vec3(0.85, 0.88, 0.95);
uniform float glow_intensity = 3.5;
uniform vec3 fog_color : source_color = vec3(0.03, 0.05, 0.12);
uniform float fog_blend = 0.4;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	
	// Masque circulaire parfait
	if (dist > 1.0) {
		discard;
	}
	
	// Lecture de la texture haute qualité générée
	vec4 tex_color = texture(moon_texture, UV);
	
	// La texture est sur fond noir, on l'utilise pour assombrir et colorer
	// On applique la teinte `moon_color` par-dessus l'image en niveaux de gris
	vec3 base_color = tex_color.rgb * moon_color;
	
	// Bords lumineux pour un effet atmosphérique
	float edge_glow = smoothstep(0.7, 1.0, dist);
	vec3 final_color = mix(base_color, vec3(1.0), edge_glow * 0.3);
	
	// Mélange manuel avec le brouillard pour conserver 60% d'immunité
	final_color = mix(final_color, fog_color, fog_blend);
	
	ALBEDO = final_color;
	EMISSION = final_color * glow_intensity;
}
