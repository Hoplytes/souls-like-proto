// Shared by the ground and the water: where the shore runs. The map's land /
// water grid (one value per cell, upscaled smoothly) gives a curved
// coastline instead of the cells' edges; a little noise makes it irregular.

uniform sampler2D shore_mask : filter_linear, repeat_disable;  // 1 = land, 0 = water
uniform sampler2D shore_flags : filter_nearest, repeat_disable;  // 1 = the shore may move here
uniform float cells = 128.0;

varying vec2 world;

// World position -> map cell (cell (i, j) is drawn at ((i - j) * 48, (i + j) * 24)).
vec2 to_cell(vec2 p) {
	return vec2(p.y / 24.0 + p.x / 48.0, p.y / 24.0 - p.x / 48.0) * 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// How much of land there is here (0.5 = the water's edge), or -1 when the
// shore does not concern this point (away from the map, on planks).
float shore(vec2 cell) {
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= cells || cell.y >= cells) {
		return -1.0;
	}
	float m = texture(shore_mask, cell / cells).r;
	if (m > 0.97) {
		return m;  // inland
	}
	if (texture(shore_flags, cell / cells).r < 0.5) {
		return -1.0;  // planks of a bridge or of the pier
	}
	if (m < 0.03) {
		return m;  // open water
	}
	return m + (value_noise(cell * 3.1) - 0.5) * 0.22 + (value_noise(cell * 9.7) - 0.5) * 0.06;
}
