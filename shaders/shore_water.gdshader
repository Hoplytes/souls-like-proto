shader_type canvas_item;
// The water: lighter in the shallows, a line of foam lapping at the shore.
#include "res://shaders/shore_common.gdshaderinc"

uniform vec4 shallow : source_color = vec4(0.27, 0.55, 0.58, 1.0);
uniform vec4 foam : source_color = vec4(0.86, 0.93, 0.95, 1.0);

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 cell = to_cell(world);
	float m = shore(cell);
	if (m > 0.0) {
		COLOR.rgb = mix(COLOR.rgb, shallow.rgb, smoothstep(0.05, 0.5, m) * 0.55);
		float lap = 0.035 * sin(TIME * 1.3 + value_noise(cell * 2.0) * 6.28);
		float f = smoothstep(0.38 + lap, 0.47 + lap, m) * (1.0 - smoothstep(0.49, 0.5, m));
		COLOR.rgb = mix(COLOR.rgb, foam.rgb, f * 0.75);
	}
}
