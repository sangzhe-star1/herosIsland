shader_type canvas_item;
// Paint a crop a different colour without redrawing it.
//
// modulate MULTIPLIES, so it can only ever darken -- a green modulate on a red
// strawberry gives dark brown-red, and dark red says OVERripe to a child, which
// is the exact opposite of what an unripe berry has to say. Two attempts went
// that way before this file existed.
//
// This mixes towards a flat colour and keeps the picture's own alpha, so the
// berry goes green and the space around it stays empty.
uniform vec4 wash : source_color = vec4(0.32, 0.72, 0.28, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.8;

// NOT multiplied by COLOR at the end. In a canvas_item shader COLOR already
// holds texture * modulate when fragment() starts, so multiplying by it applies
// the picture a second time -- red times green, and the berry came out dark
// brown. The node's modulate is set to white wherever this shader is used, so
// the colour here is the whole colour.
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	COLOR = vec4(mix(base.rgb, wash.rgb, amount), base.a);
}
