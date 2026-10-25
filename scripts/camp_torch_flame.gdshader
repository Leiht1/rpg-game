shader_type canvas_item;
uniform float phase = 0.0;
uniform float source_height = 1.0;
const float OVERSCAN = 1.35;
void vertex() {
	VERTEX.x *= OVERSCAN;
	VERTEX.y = (VERTEX.y + source_height * 0.5) * OVERSCAN - source_height * 0.5;
}
void fragment() {
	vec2 source_uv = (UV - vec2(0.5)) * OVERSCAN + vec2(0.5);
	float upper = 1.0 - smoothstep(0.25, 0.82, source_uv.y);
	vec2 sample_uv = source_uv;
	sample_uv.x += (sin(phase * 5.6 + source_uv.y * 11.0) * 0.035
		+ sin(phase * 8.4 + source_uv.y * 19.0) * 0.015) * upper;
	sample_uv.y += sin(phase * 6.7 + source_uv.y * 9.0) * 0.012 * upper;
	if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, sample_uv);
	}
}
