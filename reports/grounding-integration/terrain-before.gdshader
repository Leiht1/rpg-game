shader_type canvas_item;
uniform sampler2D environment_tex:filter_linear,repeat_disable;
uniform vec2 chunk_origin=vec2(0.);
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

 // Smooth world-space subenvironment field, shared with tree/rock placement.
 vec2 env=texture(environment_tex,((p-chunk_origin)/48.+vec2(1.5))/26.).rg;
 float clearing=1.-smoothstep(.24,.58,env.x);
 float exposed=smoothstep(.58,.88,env.y)*clearing;
 base=mix(base,grass,w.r*clearing*.19);
 base=mix(base,shore,(w.b*.18+w.g*.12)*exposed);
 base*=1.+(.5-env.x)*.075;

 // A horizontal water plane bounded by the new world-space natural contour.
 // Look 14 world units north: the far bank hides a short strip of water below it.
 float up=texture(TEXTURE,UV-vec2(0.,TEXTURE_PIXEL_SIZE.y*1.75)).a;
 float down=texture(TEXTURE,UV+vec2(0.,TEXTURE_PIXEL_SIZE.y*1.75)).a;
 float far_facing=smoothstep(.005,.075,down-up);
 float near_facing=smoothstep(.005,.075,up-down);
 float patch=.5+.5*sin(p.x*.014+sin(p.y*.021)*1.8);
 float bank_height=mix(5.,14.,patch)*far_facing;
 float water_mask=texture(TEXTURE,UV-vec2(0.,TEXTURE_PIXEL_SIZE.y*bank_height/8.)).a;
 vec3 sand=mix(shore,vec3(.65,.59,.43),.12);
 float beach=smoothstep(.055,.22,w.a);
 base=mix(base,sand,beach);
 // Upper dry lip, visible south-facing soil, then tight contact at the water foot.
 float slope=smoothstep(.30,.41,w.a)*(1.-smoothstep(.43,.53,water_mask));
 vec3 soil=mix(sand*.74,vec3(.46,.41,.29),.26);
 base=mix(base,soil,slope*far_facing*(.70+.20*patch));
 float lip=smoothstep(.22,.28,w.a)*(1.-smoothstep(.30,.34,w.a));
 base=mix(base,sand*1.10,lip*far_facing*.52);
 float contact=smoothstep(.40,.46,water_mask)*(1.-smoothstep(.48,.54,water_mask));
 base=mix(base,soil*.78,contact*far_facing*.70);
 // Broad shallow shelves vary in width, rather than concentric colored rings.
 float shelf_depth=smoothstep(.46,.91,water_mask+sin(p.x*.009+p.y*.005)*.065);
 vec3 bottom_tex=sample_ground(shore_tex,p+vec2(27.,19.));
 vec3 shallow=mix(vec3(.44,.67,.63),bottom_tex*vec3(.85,1.02,.94),.47);
 vec3 deep=vec3(.22,.47,.54);
 vec3 water=mix(shallow,deep,shelf_depth);
 float near_lip=smoothstep(.36,.43,w.a)*(1.-smoothstep(.46,.50,w.a));
 // Near bank is a thin overlapping edge, not a visible vertical wall.
 base=mix(base,sand*.80,near_lip*near_facing*.45);
 vec2 cell=floor(p/vec2(145.,90.));
 vec2 local=fract(p/vec2(145.,90.))*vec2(145.,90.);
 vec2 center=vec2(38.+hash(cell+7.)*65.,25.+hash(cell+11.)*35.);
 float dx=(local.x-center.x)/(18.+hash(cell+23.)*16.);
 float dy=(local.y-center.y+dx*dx*.8)/1.7;
 float glint=exp(-dy*dy)*pow(max(0.,1.-dx*dx),2.)*step(.74,hash(cell+31.));
 water+=vec3(.055,.070,.061)*glint*smoothstep(.46,.65,w.a);
 base=mix(base,water,smoothstep(.47,.53,water_mask));
 COLOR=vec4(base,1.);
}
