shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float saturation : hint_range(0.0, 1.0) = 0.52;
uniform float brightness : hint_range(0.75, 1.35) = 1.08;
uniform float warm_mix : hint_range(0.0, 0.65) = 0.22;
uniform vec3 warm_palette = vec3(0.55, 0.64, 0.43);

void fragment() {
	vec3 source = COLOR.rgb;
	float luminance = dot(source, vec3(0.2126, 0.7152, 0.0722));
	vec3 softened = mix(vec3(luminance), source, saturation);
	ALBEDO = clamp(mix(softened, warm_palette, warm_mix) * brightness,
		vec3(0.0), vec3(1.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.12;
}
