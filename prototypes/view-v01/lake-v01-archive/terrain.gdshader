shader_type canvas_item;
uniform vec2 ground_origin=vec2(0.);
uniform sampler2D forest_tex:filter_linear,repeat_enable;
uniform sampler2D rock_tex:filter_linear,repeat_enable;
uniform sampler2D meadow_tex:filter_linear,repeat_enable;
uniform sampler2D shore_tex:filter_linear,repeat_enable;
uniform sampler2D spawn_tex:filter_linear,repeat_enable;
uniform vec2 world_size=vec2(6144.,4096.);
varying vec2 world_p;
void vertex(){world_p=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
vec3 tile_sample(sampler2D tex,vec2 v,vec2 cell){
 // Stay inside each painted plate: no wrapping or reflected rock shapes.
 vec2 uv=(v-cell)*.4+vec2(.45)+vec2(hash(cell),hash(cell+19.))*.1;
 return texture(tex,uv).rgb;
}
vec3 sample_ground(sampler2D tex,vec2 p){
 vec2 v=p/510.;vec2 cell=floor(v);vec2 f=fract(v);f=f*f*(3.-2.*f);
 vec3 a=tile_sample(tex,v,cell);
 vec3 b=tile_sample(tex,v,cell+vec2(1,0));
 vec3 c=tile_sample(tex,v,cell+vec2(0,1));
 vec3 d=tile_sample(tex,v,cell+vec2(1,1));
 return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}

void fragment(){
 vec2 p=world_p;
 vec4 w=texture(TEXTURE,UV);
 vec3 grass=sample_ground(meadow_tex,p);
 vec3 forest=sample_ground(forest_tex,p);
 vec3 rock=sample_ground(rock_tex,p);
 vec3 shore=sample_ground(shore_tex,p);
 vec3 base=(forest*w.r+rock*w.g+grass*w.b)/max(.001,w.r+w.g+w.b);

 // Existing horizontal water mask and ground plates stay in world coordinates.
 float wet=smoothstep(.025,.19,w.a);
 vec3 sand=mix(shore,vec3(.62,.57,.40),.38);
 base=mix(base,sand,wet*.90);
 // Far (north) shore has a short inward slope; near shore reads as a lip.
 float south=texture(TEXTURE,UV+vec2(0.,TEXTURE_PIXEL_SIZE.y*.65)).a;
 float north=texture(TEXTURE,UV-vec2(0.,TEXTURE_PIXEL_SIZE.y*.65)).a;
 float far_bank=smoothstep(.002,.025,south-north);
 float bank_patch=smoothstep(-.65,.65,sin(p.x*.016+sin(p.y*.011)*1.7))*.65+.20;
 float bank_band=smoothstep(.19,.25,w.a)*(1.-smoothstep(.32,.37,w.a));
 base=mix(base,sand*vec3(.78,.80,.77),bank_band*far_bank*.55*bank_patch);
 vec3 shallow=mix(vec3(.43,.67,.62),sand,.40);
 vec3 deep=vec3(.22,.47,.54);
 vec3 water=mix(shallow,deep,smoothstep(.43,.91,w.a));
 // Quiet submerged marks use the approved shore painting, no new texture source.
 float bottom=(1.-smoothstep(.47,.72,w.a))*.34;
 water=mix(water,shore*vec3(.78,.95,.91),bottom);
 vec2 cell=floor(p/vec2(145.,90.));
 vec2 local=fract(p/vec2(145.,90.))*vec2(145.,90.);
 vec2 center=vec2(38.+hash(cell+7.)*65.,25.+hash(cell+11.)*35.);
 float dx=(local.x-center.x)/(18.+hash(cell+23.)*16.);
 float dy=(local.y-center.y+dx*dx*.8)/1.7;
 float glint=exp(-dy*dy)*pow(max(0.,1.-dx*dx),2.)*step(.74,hash(cell+31.));
 water+=vec3(.055,.070,.061)*glint*smoothstep(.46,.65,w.a);
 // Short low bank and thin damp contact edge, never a continuous cliff ring.
 float edge=smoothstep(.29,.32,w.a)*(1.-smoothstep(.34,.365,w.a));
 base=mix(base,sand*.72,edge*far_bank*.28*bank_patch);
 base=mix(base,water,smoothstep(.355,.435,w.a));
 COLOR=vec4(base,1.);
}
