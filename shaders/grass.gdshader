shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 color_top : source_color = vec3(0.08, 0.12, 0.25); // Bleu nuit sombre
uniform vec3 color_bottom : source_color = vec3(0.01, 0.02, 0.05); // Presque noir à la base

uniform float wind_speed = 1.2;
uniform float wind_strength = 0.25;
uniform float wind_scale = 0.5;

// Global position of the player, updated via script
uniform vec3 player_position = vec3(0.0, -1000.0, 0.0);
uniform float push_radius = 1.2;
uniform float push_strength = 0.8;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// UV.y goes from 0 at the bottom to 1 at the top of the blade
	float bend_factor = UV.y * UV.y; // Parabolic bending (bends more at the top)
	
	// 1. Calculate macroscopic wind (waves across the field)
	float wind_noise = sin(world_pos.x * wind_scale + TIME * wind_speed) 
					 + cos(world_pos.z * wind_scale + TIME * wind_speed * 0.8);
					 
	// 2. Micro-wind (unique wobble per blade/cluster)
	float micro_wind = sin(TIME * 3.5 + world_pos.x * 15.0 + world_pos.z * 22.0) * 0.08;
	
	// Apply combined wind bending
	VERTEX.x += (wind_noise * wind_strength + micro_wind) * bend_factor;
	VERTEX.z += (wind_noise * wind_strength + micro_wind) * bend_factor;
	
	// 3. Player interaction (Optimized with squared distance)
	vec2 diff = world_pos.xz - player_position.xz;
	float dist_sq = dot(diff, diff);
	
	if (dist_sq < push_radius * push_radius) {
		float dist = sqrt(dist_sq);
		vec2 push_dir = diff / dist; // Fast normalize
		float push_factor = 1.0 - (dist / push_radius);
		push_factor = smoothstep(0.0, 1.0, push_factor);
		
		VERTEX.x += push_dir.x * push_factor * push_strength * bend_factor;
		VERTEX.z += push_dir.y * push_factor * push_strength * bend_factor;
		VERTEX.y -= push_factor * push_strength * 0.4 * bend_factor;
	}
}

void fragment() {
	// Gradient color from bottom to top
	vec3 color = mix(color_bottom, color_top, UV.y);
	
	ALBEDO = color;
	
	// Fake Subsurface Scattering (lumière traversante)
	// Les pointes de l'herbe sont "luminescentes" par rapport au fond
	EMISSION = color * UV.y * 0.15;
	
	// TRICK PRO : Forcer la normale vers le haut et légèrement vers la caméra.
	// Supprime les ombres dures sur les milliers de petits polygones
	// et donne un effet soyeux (volumétrique).
	NORMAL = vec3(0.0, 1.0, 0.0);
	ROUGHNESS = 0.5;
}
