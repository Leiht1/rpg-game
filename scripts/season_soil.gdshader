shader_type canvas_item;
uniform float snow_amount=0.;
void fragment(){
 vec4 soil=texture(TEXTURE,UV);
 float light=dot(soil.rgb,vec3(.299,.587,.114));
 vec3 frost=vec3(.86,.90,.89)*(.8+.2*light);
 COLOR=vec4(mix(soil.rgb,frost,snow_amount*.42),soil.a);
}
