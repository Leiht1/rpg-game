shader_type canvas_item;
uniform sampler2D region_field:filter_linear,repeat_disable;
uniform sampler2D forest_tex:filter_linear,repeat_enable;
uniform sampler2D rock_tex:filter_linear,repeat_enable;
uniform sampler2D meadow_tex:filter_linear,repeat_enable;
uniform sampler2D shore_tex:filter_linear,repeat_enable;
uniform sampler2D spawn_tex:filter_linear,repeat_enable;
uniform vec2 world_size=vec2(6144.,4096.);
varying vec2 world_p;
void vertex(){world_p=VERTEX;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
vec3 sample_ground(sampler2D tex,vec2 p){
 vec2 v=p/510.; vec2 cell=floor(v);vec2 f=fract(v);f=f*f*(3.-2.*f);
 vec3 a=texture(tex,p/730.+vec2(hash(cell),hash(cell+19.))).rgb;
 vec3 b=texture(tex,p/730.+vec2(hash(cell+vec2(1,0)),hash(cell+vec2(1,0)+19.))).rgb;
 vec3 c=texture(tex,p/730.+vec2(hash(cell+vec2(0,1)),hash(cell+vec2(0,1)+19.))).rgb;
 vec3 d=texture(tex,p/730.+vec2(hash(cell+1.),hash(cell+20.))).rgb;
 return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
void fragment(){
 vec2 p=world_p;
 vec4 w=texture(region_field,(p+vec2(8.))/(world_size+vec2(16.)));
 vec3 grass=sample_ground(meadow_tex,p);
 vec3 forest=sample_ground(forest_tex,p);
 vec3 rock=sample_ground(rock_tex,p);
 vec3 shore=sample_ground(shore_tex,p);
 vec3 base=(forest*w.r+rock*w.g+grass*w.b)/max(.001,w.r+w.g+w.b);
 float safe=1.-smoothstep(200.,470.,distance(p,world_size*.5));
 base=mix(base,sample_ground(spawn_tex,p),safe);
 base=mix(base,shore,smoothstep(.015,.28,w.a));
 vec3 water=mix(vec3(.40,.67,.66),vec3(.22,.47,.54),smoothstep(.48,.93,w.a));
 float ripple=sin(p.x*.025+sin(p.y*.035)*1.5)*sin(p.y*.11)*.007;
 base=mix(base,water+ripple,smoothstep(.34,.65,w.a));
 COLOR=vec4(base,1.);
}
