shader_type canvas_item;

uniform float strength = 0.6;

void fragment() {
	float d = length((UV - 0.5) * vec2(1.15, 1.0));
	COLOR = vec4(0.02, 0.01, 0.05, smoothstep(0.38, 0.95, d) * strength);
}
