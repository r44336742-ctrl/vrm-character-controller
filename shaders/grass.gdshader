shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 color_top : source_color = vec3(0.2, 0.4, 0.2);
uniform vec3 color_bottom : source_color = vec3(0.05, 0.15, 0.05);

uniform float wind_speed = 1.5;
uniform float wind_strength = 0.3;
uniform float wind_scale = 0.5;

// Global position of the player, updated via script
uniform vec3 player_position = vec3(0.0, -1000.0, 0.0);
uniform float push_radius = 1.5;
uniform float push_strength = 0.8;

void vertex() {
	// 1. Calculate wind
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// A simple pseudo-random wind wave
	float wind_noise = sin(world_pos.x * wind_scale + TIME * wind_speed) 
					 + cos(world_pos.z * wind_scale + TIME * wind_speed * 0.8);
	
	// UV.y goes from 0 at the bottom to 1 at the top of the quad
	float bend_factor = UV.y;
	
	// Apply wind bending
	VERTEX.x += wind_noise * wind_strength * bend_factor;
	VERTEX.z += wind_noise * wind_strength * bend_factor;
	
	// 2. Player interaction
	// Calculate distance in the XZ plane (ignore Y to create a cylinder of influence)
	float dist = distance(world_pos.xz, player_position.xz);
	
	if (dist < push_radius) {
		vec2 push_dir = normalize(world_pos.xz - player_position.xz);
		float push_factor = 1.0 - (dist / push_radius);
		// Smooth curve for pushing
		push_factor = smoothstep(0.0, 1.0, push_factor);
		
		VERTEX.x += push_dir.x * push_factor * push_strength * bend_factor;
		VERTEX.z += push_dir.y * push_factor * push_strength * bend_factor;
		
		// Push grass down slightly when stepped on
		VERTEX.y -= push_factor * push_strength * 0.5 * bend_factor;
	}
}

void fragment() {
	// Gradient color from bottom to top
	vec3 color = mix(color_bottom, color_top, UV.y);
	ALBEDO = color;
	ROUGHNESS = 0.8;
}
