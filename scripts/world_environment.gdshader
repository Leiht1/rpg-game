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
uniform float camp_strengths[32];
uniform float hallucination = 0.0;
uniform int torch_count = 0;
uniform vec2 torch_centers[32];
uniform vec2 torch_directions[32];
uniform float torch_length = 360.0;
uniform float torch_angle = 0.38;
uniform sampler2D torch_player_mask : filter_nearest, repeat_disable;
uniform vec2 merchant_ground = vec2(-2.0);
uniform vec2 merchant_center = vec2(-2.0);
uniform float merchant_glow_scale = 0.0;
void fragment() {
 vec2 drift = vec2(sin(SCREEN_UV.y*15.0+TIME*.65),cos(SCREEN_UV.x*12.0+TIME*.48))*.007*hallucination;
 vec2 uv = clamp(SCREEN_UV+drift,vec2(0.0),vec2(1.0));
 vec3 original = texture(world_screen, uv).rgb;
 vec3 ghost = texture(world_screen,clamp(uv+vec2(.012*sin(TIME*.4),.004*cos(TIME*.32)),vec2(0.0),vec2(1.0))).rgb;
 original = mix(original,ghost,.28*hallucination);
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
  fire_glow = max(fire_glow,(1.0-smoothstep(12.0,max(13.0,camp_radii[i]),d))*camp_strengths[i]);
 }
 color = mix(color,original*vec3(1.06,.99,.86),clamp(fire_glow*.78,0.0,1.0));
 float torch_glow = 0.0;
 for (int i=0;i<32;i++) {
  if (i>=torch_count) { break; }
  vec2 rel = (SCREEN_UV-torch_centers[i])/SCREEN_PIXEL_SIZE;
  float along = dot(rel,torch_directions[i]);
  float cross_distance = abs(rel.x*torch_directions[i].y-rel.y*torch_directions[i].x);
  float width = max(2.0,along*tan(torch_angle));
  float cone = (1.0-smoothstep(width*.70,width,cross_distance))*smoothstep(0.0,5.0,along)*(1.0-smoothstep(torch_length*.65,torch_length,along));
  torch_glow=max(torch_glow,cone);
 }
 float player_alpha=smoothstep(0.01,0.95,texture(torch_player_mask,SCREEN_UV).a);
 color=mix(color,original*vec3(1.16,1.20,1.22)+vec3(.06,.09,.10),clamp(torch_glow*.96*(1.0-player_alpha),0.0,1.0));
 if (merchant_glow_scale>0.0) {
  vec2 local=(SCREEN_UV-merchant_center)/SCREEN_PIXEL_SIZE/merchant_glow_scale;
  float aura=max(1.0-smoothstep(8.0,44.0,length((local-vec2(-30.0,0.0))*vec2(1.0,.75))),1.0-smoothstep(8.0,44.0,length((local-vec2(30.0,0.0))*vec2(1.0,.75))));
  float pulse=.86+.14*sin(TIME*2.0);
  color=mix(color,original*vec3(.75,1.0,1.18)+vec3(.01,.12,.26),aura*pulse*.58);
  vec2 ground=(SCREEN_UV-merchant_ground)/SCREEN_PIXEL_SIZE/merchant_glow_scale;
  float ground_aura=1.0-smoothstep(18.0,76.0,length(ground*vec2(1.0,1.8)));
  color=mix(color,original*vec3(.78,1.02,1.22)+vec3(.01,.09,.20),ground_aura*.38);
 }
 // Slow hue drift around the neutral axis keeps gray neutral and avoids flashing.
 float hue_angle = (.45+.9*sin(TIME*.27+SCREEN_UV.y*1.4))*hallucination;
 vec3 neutral_axis = vec3(.577350269);
 vec3 shifted = color*cos(hue_angle)+cross(neutral_axis,color)*sin(hue_angle)
     +neutral_axis*dot(neutral_axis,color)*(1.0-cos(hue_angle));
 float shifted_lum = dot(shifted,vec3(.2126,.7152,.0722));
 shifted = mix(vec3(shifted_lum),shifted,1.0+.25*hallucination);
 color = clamp(shifted,vec3(0.0),vec3(1.0));
 color = mix(color,vec3(.97,.98,1.0),lightning);
 COLOR = vec4(color,1.);
}
