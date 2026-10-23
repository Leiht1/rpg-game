shader_type canvas_item;
uniform bool lit = true;
uniform float phase = 0.0;
const float OVERSCAN = 1.25;
varying vec4 sprite_tint;
void vertex() {
	sprite_tint = COLOR;
	VERTEX *= OVERSCAN;
}
void fragment() {
	vec2 source_uv = (UV - vec2(0.5)) * OVERSCAN + vec2(0.5);
	// Only the flame above the cup moves; cup, rope and wooden shaft stay fixed.
	float flame = 1.0 - smoothstep(0.08, 0.31, source_uv.y);
	vec2 sample_uv = source_uv;
	sample_uv.x += (sin(phase * 5.6 + source_uv.y * 11.0) * 0.065
		+ sin(phase * 8.4 + source_uv.y * 19.0) * 0.025) * flame;
	sample_uv.y += sin(phase * 6.7 + source_uv.y * 9.0) * 0.012 * flame;
	if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, sample_uv) * sprite_tint;
		if (!lit) COLOR.a *= smoothstep(0.20, 0.31, source_uv.y);
	}
}
