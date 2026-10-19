shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float phase=0.0;
void fragment(){
 vec4 source=texture(TEXTURE,UV);
 vec2 center=vec2(.5,.577);
 vec2 half_size=vec2(.233,.123);
 vec2 q=abs(UV-center)-half_size+vec2(.025);
 float distance_to_glass=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-.025;
 float mask=1.0-smoothstep(-.010,.003,distance_to_glass);
 float halo=exp(-max(distance_to_glass,0.0)*65.0);
 float glow=.86+.085*sin(phase*2.3)+.025*sin(phase*5.1);
 vec2 normalized=(UV-center)/half_size;
 float core=1.0-smoothstep(.15,1.25,length(normalized));
 vec3 yellow=mix(vec3(1.0,.79,.045),vec3(1.0,.96,.20),core);
 // Add light to the existing glass rather than tinting it brown.
 // A narrow feathered halo reaches the inner frame; original PNG stays intact.
 COLOR=vec4(yellow*glow,(mask*.90+halo*.12)*source.a);
}
