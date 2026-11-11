shader_type canvas_item;
// Fades an image out towards its edges so a cut-in never ends on a hard line.
uniform float bottom = 0.3;
uniform float sides = 0.08;
uniform float top = 0.03;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * tint;
	float a = smoothstep(0.0, bottom, 1.0 - UV.y) * smoothstep(0.0, top, UV.y);
	a *= smoothstep(0.0, sides, UV.x) * smoothstep(0.0, sides, 1.0 - UV.x);
	COLOR = vec4(c.rgb, c.a * a);
}
