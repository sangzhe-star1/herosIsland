shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform float saturation : hint_range(0.0, 1.0) = 0.52;
uniform float brightness : hint_range(0.75, 1.35) = 1.08;
uniform float warm_mix : hint_range(0.0, 0.65) = 0.22;
uniform vec3 warm_palette = vec3(0.55, 0.64, 0.43);
uniform bool soil_plot_enabled = false;
uniform vec2 soil_plot_center_xz = vec2(0.0);
uniform vec2 soil_plot_right_axis = vec2(1.0, 0.0);
uniform vec2 soil_plot_depth_axis = vec2(0.0, 1.0);
uniform vec2 soil_plot_half_size = vec2(1.0);
uniform vec3 soil_plot_color = vec3(0.43, 0.25, 0.15);
uniform float soil_plot_strength : hint_range(0.0, 1.0) = 0.58;
uniform float soil_plot_edge_softness : hint_range(0.01, 0.30) = 0.035;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float soil_hash(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float soil_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float lower = mix(soil_hash(cell), soil_hash(cell + vec2(1.0, 0.0)), local.x);
	float upper = mix(soil_hash(cell + vec2(0.0, 1.0)),
		soil_hash(cell + vec2(1.0, 1.0)), local.x);
	return mix(lower, upper, local.y);
}

void fragment() {
	vec3 source = COLOR.rgb;
	float luminance = dot(source, vec3(0.2126, 0.7152, 0.0722));
	vec3 softened = mix(vec3(luminance), source, saturation);
	vec3 meadow = clamp(mix(softened, warm_palette, warm_mix) * brightness,
		vec3(0.0), vec3(1.0));
	vec3 albedo = meadow;
	if (soil_plot_enabled) {
		vec2 offset = world_position.xz - soil_plot_center_xz;
		vec2 plot_point = vec2(dot(offset, soil_plot_right_axis),
			dot(offset, soil_plot_depth_axis)) / max(soil_plot_half_size, vec2(0.001));
		float shape = pow(abs(plot_point.x), 4.0) + pow(abs(plot_point.y), 4.0);
		float edge_noise = (soil_noise(world_position.xz * 1.4) - 0.5) * 0.12;
		float soil_mask = 1.0 - smoothstep(0.98 - soil_plot_edge_softness,
			1.02 + soil_plot_edge_softness, shape + edge_noise);
		float broad_grain = soil_noise(world_position.xz * 3.8) - 0.5;
		float fine_grain = soil_noise(world_position.xz * 20.0) - 0.5;
		vec3 textured_soil = soil_plot_color * (0.98 + broad_grain * 0.12
			+ fine_grain * 0.055);
		albedo = mix(meadow, textured_soil, soil_mask * soil_plot_strength);
	}
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.12;
}
