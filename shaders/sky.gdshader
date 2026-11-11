shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.2, 0.3, 0.6, 1.0);
uniform vec4 mid_color : source_color = vec4(0.9, 0.6, 0.4, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform vec2 sun_pos = vec2(0.7, 0.55);
uniform vec4 sun_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float sun_size = 0.07;
uniform float stars = 0.0;
uniform float aspect = 1.7778;

void fragment() {
	float t = UV.y;
	vec3 c = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, 0.55, t));
	c = mix(c, bottom_color.rgb, smoothstep(0.45, 1.0, t));

	vec2 d = (UV - sun_pos) * vec2(aspect, 1.0);
	float dist = length(d);
	float disc = smoothstep(sun_size, sun_size * 0.9, dist);
	float halo = exp(-dist * 5.0) * 0.55 + exp(-dist * 1.6) * 0.18;
	c += sun_color.rgb * (disc * 0.9 + halo) * sun_color.a;

	vec2 g = floor(UV * vec2(aspect, 1.0) * 240.0);
	float h = fract(sin(dot(g, vec2(12.9898, 78.233))) * 43758.5453);
	float tw = 0.6 + 0.4 * sin(TIME * 1.5 + h * 60.0);
	c += vec3(step(0.9935, h)) * stars * tw * (1.0 - t * 1.1);

	COLOR = vec4(c, 1.0);
}
