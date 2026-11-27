shader_type canvas_item;
// The ground near water: cut along the curved shore, with a strip of wet
// earth at the water's edge.
#include "res://shaders/shore_common.gdshaderinc"

uniform vec4 wet : source_color = vec4(0.30, 0.25, 0.17, 1.0);
uniform vec4 mud : source_color = vec4(0.50, 0.42, 0.29, 1.0);

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float m = shore(to_cell(world));
	if (m >= 0.0 && m < 0.97) {
		if (m < 0.5) {
			discard;
		}
		float s = smoothstep(0.5, 0.68, m);  // 0 at the water's edge, 1 inland
		vec3 bank = mix(wet.rgb, mud.rgb, smoothstep(0.0, 0.45, s));
		COLOR.rgb = mix(bank, COLOR.rgb, smoothstep(0.35, 1.0, s));
	}
}
