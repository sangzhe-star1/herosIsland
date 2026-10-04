shader_type spatial;
render_mode shadow_to_opacity, ambient_light_disabled, cull_disabled, specular_disabled, depth_draw_never;

uniform vec3 shadow_color : source_color = vec3(0.09, 0.11, 0.15);

void fragment() {
	ALBEDO = shadow_color;
	ROUGHNESS = 1.0;
}
