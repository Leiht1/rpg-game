shader_type canvas_item;
uniform float phase = 0.0;
// Extend only the draw quad, preserving the source image's original scale/anchor.
// The extra transparent border leaves room for the tips to move without clipping.
const float OVERSCAN = 1.25;
void vertex() {
 VERTEX *= OVERSCAN;
}
void fragment() {
 vec2 source_uv = (UV - vec2(0.5)) * OVERSCAN + vec2(0.5);
 // Exact zero displacement in the bottom 18%: the seated base never slides.
 float upper = 1.0 - smoothstep(0.28, 0.82, source_uv.y);
 vec2 sample_uv = source_uv;
 // Two rising waves bend the tongues independently instead of pulsing the image.
 float drift = sin(phase * 5.6 + source_uv.y * 8.0) * 0.037;
 float flutter = sin(phase * 8.4 + source_uv.y * 15.0) * 0.013;
 sample_uv.x += (drift + flutter) * upper;
 sample_uv.y += sin(phase * 6.7 + source_uv.y * 9.0 + source_uv.x * 6.0) * 0.024 * upper;
 if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
  COLOR = vec4(0.0);
 } else {
  COLOR = texture(TEXTURE, sample_uv);
 }
}
