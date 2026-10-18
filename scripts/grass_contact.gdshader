shader_type canvas_item;
render_mode unshaded;
uniform sampler2D pure_ground : hint_screen_texture, repeat_disable, filter_linear;
void fragment(){
 vec4 original=texture(TEXTURE,UV);
 vec4 c=COLOR;
 vec3 ground=textureLod(pure_ground,SCREEN_UV,0.).rgb;
 // Only the existing painted foot-grass follows local ground hue. No new alpha/veil.
 float base=smoothstep(.80,.96,UV.y);
 float green=smoothstep(.015,.09,original.g-max(original.r,original.b));
 float detail=clamp(dot(original.rgb,vec3(.2126,.7152,.0722))/.48,.82,1.13);
 c.rgb=mix(c.rgb,ground*detail,base*green*.65);
 COLOR=c;
}
