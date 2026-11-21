shader_type canvas_item;
// Still water in a trough: the painted surface moves very slightly and catches small glints.
// In fragment() COLOR already holds the texture times the modulate, so the modulate is taken in vertex() and the
// rippled texture is multiplied by it alone (multiplying by COLOR there counted the painting twice).
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec2 uv = UV;
	uv.y += sin(uv.x * 46.0 + TIME * 1.2) * 0.0035 + sin(uv.x * 19.0 - TIME * 0.8) * 0.004;
	uv.x += sin(uv.y * 90.0 + TIME * 0.9) * 0.0015;
	vec4 c = texture(TEXTURE, uv);
	float keep = texture(TEXTURE, UV).a;          // never spill outside the painted surface
	float glint = smoothstep(0.93, 1.0, sin(uv.x * 70.0 + uv.y * 40.0 + TIME * 1.7) * 0.5 + 0.5);
	c.rgb += glint * 0.10;
	COLOR = vec4(c.rgb, min(c.a, keep)) * tint;
}
