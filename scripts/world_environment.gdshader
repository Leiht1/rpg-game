shader_type canvas_item;
render_mode unshaded;
uniform sampler2D world_screen : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 light_tint : source_color = vec4(1.0);
uniform float brightness = 1.0;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float lightning = 0.0;
uniform vec2 lantern_center = vec2(0.5);
uniform float lantern_radius = 150.0;
uniform float lantern_strength = 0.0;
uniform int camp_count = 0;
uniform vec2 camp_centers[32];
uniform float camp_radii[32];
void fragment() {
 vec3 original = texture(world_screen, SCREEN_UV).rgb;
 float lum = dot(original,vec3(.2126,.7152,.0722));
 vec3 color = mix(vec3(lum),original,saturation);
 color = ((color - vec3(.45))*contrast + vec3(.45))*light_tint.rgb*brightness;
 float distance_px = length((SCREEN_UV-lantern_center)/SCREEN_PIXEL_SIZE);
 float glow = (1.0-smoothstep(16.0,lantern_radius,distance_px))*lantern_strength;
 color = mix(color,original*vec3(1.08,1.01,.87),glow*.88);
 float fire_glow = 0.0;
 for (int i=0;i<32;i++) {
  if (i>=camp_count) { break; }
  float d = length((SCREEN_UV-camp_centers[i])/SCREEN_PIXEL_SIZE);
  fire_glow = max(fire_glow,1.0-smoothstep(12.0,max(13.0,camp_radii[i]),d));
 }
 color = mix(color,original*vec3(1.06,.99,.86),fire_glow*.78);
 color = mix(color,vec3(.97,.98,1.0),lightning);
 COLOR = vec4(color,1.);
}
