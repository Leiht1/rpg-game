shader_type canvas_item;
render_mode unshaded;
uniform sampler2D pure_ground : hint_screen_texture, repeat_disable, filter_linear;
uniform float bend=0.;
uniform float height=256.;
uniform float fixed_y=-32.;
uniform bool tree=true;
uniform float color_fit=0.;
uniform int surface_kind=0; // grass=0, forest=1, dry earth=2
uniform vec2 image_size=vec2(256.);
uniform float contact_extent=40.;
uniform vec2 left_lip=vec2(-28.,-15.);
uniform vec2 right_lip=vec2(15.,28.);
float luminance(vec3 c){return dot(c,vec3(.2126,.7152,.0722));}
float interval(float x,vec2 ends){return smoothstep(ends.x-2.,ends.x+2.,x)*(1.-smoothstep(ends.y-2.,ends.y+2.,x));}
void vertex(){
 float w=clamp((fixed_y-VERTEX.y)/max(1.,height-8.+fixed_y),0.,1.);
 if(tree){VERTEX.x+=bend*w*w;}
}
void fragment(){
 vec4 painted=texture(TEXTURE,UV);
 vec3 base=COLOR.rgb;
 vec2 p=UV*image_size;
 float from_bottom=image_size.y-p.y;
 float contact_zone=1.-smoothstep(contact_extent-6.,contact_extent,from_bottom);
 vec3 ground=textureLod(pure_ground,SCREEN_UV,0.).rgb;
 float gl=max(.05,luminance(ground));
 float pl=max(.03,luminance(painted.rgb));
 // Classify existing painted blades; never paint a procedural grass silhouette.
 float grass=smoothstep(.018,.065,painted.g-painted.r)*smoothstep(.055,.16,painted.g-painted.b);
 grass*=smoothstep(.10,.25,pl)*contact_zone;
 vec3 grass_hue=mix(painted.rgb/pl,ground/gl,.76);
 vec3 blade=grass_hue*gl*clamp(.78+pl*.35,.82,1.10);
 vec3 fitted=mix(base,blade,grass*.84*color_fit);
 // Earth lips/leaf fragments only. A protected trunk centre stays original brown.
 float brown=smoothstep(.025,.10,painted.r-painted.g)*smoothstep(.035,.12,painted.r-painted.b);
 float peripheral=tree?max(interval(p.x-image_size.x*.5,left_lip),interval(p.x-image_size.x*.5,right_lip)):1.;
 float low=1.-smoothstep(tree?9.:10.,tree?14.:15.,from_bottom);
 float ground_part=brown*peripheral*low*smoothstep(.13,.27,pl);
 vec3 earth=ground*clamp(pl/.46,.86,1.10);
 // Forest litter stays recognisably brown, but takes the local ground's light level.
 vec3 leaf_hue=mix(vec3(1.),painted.rgb/pl,.48);
 vec3 litter=mix(leaf_hue*gl*.94,ground,.14);
 vec3 target=surface_kind==2?earth:litter;
 float amount=surface_kind==2?.86:(surface_kind==1?.72:0.);
 COLOR.rgb=mix(fitted,target,ground_part*amount*color_fit);
 // COLOR.a already contains original painted alpha and whole-object fade.
}
