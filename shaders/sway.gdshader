shader_type canvas_item;
// Wind: the top of the image leans back and forth while its base stays planted.
uniform float amp = 0.03;      // how far the top travels, as a share of the image width
uniform float speed = 1.3;
uniform float ripple = 0.0;    // > 0 for long strips: neighbouring stretches move out of step
varying vec4 tint;
varying float phase;

void vertex() {
	tint = COLOR;
	phase = MODEL_MATRIX[3].x * 0.013;
}

void fragment() {
	float h = 1.0 - UV.y;
	float p = phase + UV.x * ripple;
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + p * 0.2);
	float lean = (sin(TIME * speed + p) + 0.45 * sin(TIME * speed * 2.3 + p * 1.7)) * amp * gust * h * h;
	COLOR = texture(TEXTURE, vec2(UV.x + lean, UV.y)) * tint;
}
