shader_type canvas_item;
render_mode unshaded;
uniform float snow_amount=0.;
uniform float snow_depth=.28;
uniform bool ground_surface=false;
uniform float ground_threshold=.77;
uniform float ground_growth=.08;
uniform sampler2D snow_grain:filter_linear,repeat_disable;
varying vec4 vertex_tint;
varying vec2 ground_point;
varying float local_y;
void vertex(){vertex_tint=COLOR;ground_point=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;local_y=VERTEX.y;}
float noise_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float cover_noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(noise_hash(i),noise_hash(i+vec2(1.,0.)),f.x),mix(noise_hash(i+vec2(0.,1.)),noise_hash(i+vec2(1.,1.)),f.x),f.y);}
void fragment(){
 vec4 paint=texture(TEXTURE,UV);
 // Snow rests on the painted upper silhouette, rather than bleaching a band of facade.
 float lump=.76+.16*sin(UV.x*29.)+.08*sin(UV.x*67.+2.);
 float thickness=(.035+.055*snow_amount)*lump;
 float above=texture(TEXTURE,UV-vec2(0.,thickness)).a;
 float upper=1.-smoothstep(snow_depth-.05,snow_depth+.06,UV.y);
 vec4 snow=texture(snow_grain,vec2(UV.x,UV.y*.8+.1));
 float coverage=(1.-smoothstep(.05,.55,above))*upper*smoothstep(.03,.25,snow_amount);
 float alpha=paint.a;
 if(ground_surface){coverage=smoothstep(ground_threshold-snow_amount*ground_growth,ground_threshold+.045-snow_amount*ground_growth,cover_noise(ground_point/42.))*smoothstep(.03,.25,snow_amount)*(1.-smoothstep(31.,33.,local_y));alpha=paint.a;}
 float depth=mix(.91,1.,1.-smoothstep(0.,.8,above));
 vec3 snow_color=mix(vec3(.94,.95,.91),snow.rgb,snow.a*.12)*depth;
 COLOR=vec4(mix(paint.rgb,snow_color,coverage*.98),alpha)*vertex_tint;
}
