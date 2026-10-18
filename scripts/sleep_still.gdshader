shader_type canvas_item;
uniform float breath = 0.0;
uniform vec2 chest = vec2(0.5, 0.56);
uniform vec2 envelope = vec2(0.19, 0.12);
varying vec4 tint;
void vertex() { tint = COLOR; }
// A continuous, localized displacement of ONE painted body. Head/feet stay fixed.
void fragment() {
	vec2 delta = UV - chest;
	vec2 q = delta / envelope;
	float weight = pow(max(0.0, 1.0 - dot(q, q)), 2.0);
	vec2 sample_uv = UV - delta * (0.045 * breath * weight);
	COLOR = texture(TEXTURE, sample_uv) * tint;
}
