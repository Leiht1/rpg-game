shader_type canvas_item;
// Candidate palette only: recolour pale fur/feathers, retaining outlines and skin.
uniform bool all_pale = false;
varying vec4 part_tint;
void vertex() {part_tint=COLOR;}
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 vec4 vertex_tint = part_tint;
 float lightness = dot(source.rgb, vec3(0.2126,0.7152,0.0722));
 float pale = all_pale ? smoothstep(0.18,0.55,source.b) : smoothstep(0.48,0.72,source.b);
 if (!all_pale) {
  pale *= 1.0-smoothstep(0.10,0.20,source.r-source.g);
  pale *= 1.0-smoothstep(0.23,0.34,source.g-source.b);
 }
 vec3 white_fur = vec3(1.0,0.998,0.99)*(0.76+0.24*lightness);
 COLOR = vec4(mix(source.rgb,white_fur,pale),source.a)*vertex_tint;
}
