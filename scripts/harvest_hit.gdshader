shader_type canvas_item;
render_mode unshaded;
uniform sampler2D pure_ground : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D damage_texture : filter_linear;
uniform vec2 impact_uv=vec2(0.5,0.55);
uniform float strength=0.0;
uniform float damage_amount=0.0;
uniform bool buried=false;
uniform bool mineral_contact=false;
uniform bool crack_overlay=false;
uniform float exposure=0.0;
float lum(vec3 c){return dot(c,vec3(.2126,.7152,.0722));}
void fragment(){
 vec4 original=texture(TEXTURE,UV);
 vec4 c=COLOR;
 vec3 ground=textureLod(pure_ground,SCREEN_UV,0.).rgb;
 // One immutable subject silhouette. Damage supplies only darker interior marks.
 vec4 damage=texture(damage_texture,UV);
 float darkening=smoothstep(.09,.23,lum(original.rgb)-lum(damage.rgb));
 float interior=smoothstep(.08,.18,UV.x)*(1.-smoothstep(.82,.92,UV.x));
 float rock_zone=1.-smoothstep(.72,.84,UV.y);
 if(crack_overlay){
   c.rgb=mix(c.rgb,damage.rgb,damage.a*interior*rock_zone*damage_amount*.78);
 }else{
   c.rgb=mix(c.rgb,min(c.rgb,damage.rgb),darkening*interior*rock_zone*damage.a*damage_amount*.88);
 }
 // Reveal the same buried object in place. Never exchange its drawing or its root.
 float earth=smoothstep(.025,.11,original.r-original.g)*smoothstep(.035,.13,original.r-original.b);
 float edge=1.-smoothstep(.14,.28,abs(UV.x-.5));
 float low= smoothstep(.76,.94,UV.y);
 float lip=earth*low*(1.-edge*.45);
 if(mineral_contact){
   // Restrict adaptation to the warm painted soil rim; never recolor ore veins.
   float warm_soil=smoothstep(.008,.055,original.r-original.g)*smoothstep(.025,.09,original.r-original.b);
   lip=warm_soil*smoothstep(.86,.94,UV.y);
 }
 // Solid silhouette occlusion. No translucent green veil over the collectible.
 if(buried){
   float progress=clamp((exposure-.35)/.65,0.,1.);
   if(UV.y>.77+.23*progress){discard;}
 }
 // Same pure-ground screen copy used by accepted tree/rock contact adaptation.
 // Retain the painted earth's form and small luminance variation, fit local hue/light.
 float pl=max(.04,lum(original.rgb));
 vec3 earth_fit=ground*clamp(pl/.44,.88,1.09);
 c.rgb=mix(c.rgb,earth_fit,lip*.94);
 float fringe=low*(1.-smoothstep(.10,.40,original.a));
 c.rgb=mix(c.rgb,ground,fringe*.7);
 float local=1.0-smoothstep(0.02,0.23,distance(UV,impact_uv));
 c.rgb=mix(c.rgb,vec3(.94,.91,.80),strength*local*.55);
 COLOR=c;
}

