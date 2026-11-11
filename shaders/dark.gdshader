shader_type canvas_item;
// Darkness laid over the scene, with pools of light cut out of it (a torch, embers, a shaft of moonlight).
uniform float amount = 0.0;
uniform int count = 0;
uniform vec3 lights[12];      // x, y in screen UV; z = radius as a share of the screen height
uniform float aspect = 1.7778;
uniform vec3 tint : source_color = vec3(0.01, 0.015, 0.04);

void fragment() {
	float lit = 0.0;
	for (int i = 0; i < count; i++) {
		vec2 d = UV - lights[i].xy;
		d.x *= aspect;
		float r = lights[i].z;
		lit = max(lit, 1.0 - smoothstep(r * 0.3, r, length(d)));
	}
	COLOR = vec4(tint, amount * (1.0 - lit));
}
