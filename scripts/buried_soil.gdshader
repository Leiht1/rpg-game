shader_type canvas_item;
render_mode unshaded;
uniform sampler2D pure_ground : hint_screen_texture, repeat_disable, filter_linear;
uniform float progress=0.0;
float lum(vec3 c){return dot(c,vec3(.2126,.7152,.0722));}
void fragment(){
 vec4 paint=texture(TEXTURE,UV);
 // Reuse only the painted foreground earth from the original buried illustration.
 // Bone ivory/carrot orange and the upper pouch are excluded, not tinted as soil.
 bool warm_soil=paint.r>paint.g+.025 && paint.g>paint.b+.025;
 bool orange=paint.r>paint.g*1.55;
 bool ivory=lum(paint.rgb)>.67;
 float edge=.70+.27*progress;
 if(!warm_soil || orange || ivory || UV.y<edge){discard;}
 vec3 ground=textureLod(pure_ground,SCREEN_UV,0.).rgb;
 float pl=max(.04,lum(paint.rgb));
 float gl=max(.04,lum(ground));
 vec3 soil_hue=mix(paint.rgb/pl,ground/gl,.48);
 COLOR=vec4(soil_hue*gl*clamp(pl/.46,.82,1.04),COLOR.a);
}
