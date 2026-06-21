shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color;
uniform float saturation : hint_range(0.0, 1.0) = 0.3;
uniform vec3 tint_color : source_color = vec3(0.55, 0.6, 0.75);
uniform float darken_amount : hint_range(0.0, 1.0) = 0.35;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	float luminance = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(vec3(luminance), tex_color.rgb, saturation);
	vec3 tinted = desaturated * tint_color * (1.0 - darken_amount);

	ALBEDO = tinted;
	ALPHA = tex_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
