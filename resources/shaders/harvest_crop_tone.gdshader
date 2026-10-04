shader_type canvas_item;

// Harvest-only palette adaptation for the existing crop catalogue artwork.
// It preserves the source silhouette and alpha while softening near-black
// ink, slightly reducing saturation, and keeping maturity wash in this pass.
uniform vec3 ink_tint : source_color = vec3(0.21, 0.30, 0.17);
uniform float saturation : hint_range(0.0, 1.0) = 0.74;
uniform float brightness : hint_range(0.0, 0.12) = 0.025;
uniform vec4 maturity_tint : source_color = vec4(1.0);
uniform vec4 wash : source_color = vec4(0.32, 0.72, 0.28, 1.0);
uniform float wash_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool palette_adaptation = true;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 tinted = base.rgb * maturity_tint.rgb;
	vec3 pigment = tinted;
	if (palette_adaptation) {
		float luminance = dot(tinted, vec3(0.2126, 0.7152, 0.0722));
		pigment = mix(vec3(luminance), tinted, saturation);
		float ink = 1.0 - smoothstep(0.04, 0.24, luminance);
		pigment = mix(pigment, ink_tint, ink * 0.82);
		pigment = min(pigment + vec3(brightness), vec3(1.0));
	}
	pigment = mix(pigment, wash.rgb, wash_amount);
	COLOR = vec4(pigment, base.a);
}
