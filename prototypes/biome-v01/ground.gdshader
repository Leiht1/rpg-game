shader_type canvas_item;
uniform sampler2D ground_tex : filter_linear, repeat_enable;
void fragment(){
 vec2 p=UV*vec2(2400.,1320.);
 vec2 centers[5]={vec2(1000.,740.),vec2(490.,390.),vec2(1750.,340.),vec2(1950.,1010.),vec2(510.,1070.)};
 vec2 radii[5]={vec2(470.,410.),vec2(650.,480.),vec2(610.,460.),vec2(530.,390.),vec2(650.,390.)};
 vec3 tones[5]={vec3(1.02,1.02,.99),vec3(.83,.96,.88),vec3(.94,.94,.85),vec3(.88,1.,.98),vec3(1.05,1.03,.98)};
 vec3 tint=vec3(0.);float sum=0.;
 for(int i=0;i<5;i++){vec2 q=(p-centers[i])/radii[i];float w=exp(-dot(q,q)*2.4);tint+=tones[i]*w;sum+=w;}
 vec2 uv=p/vec2(1280.,720.);uv=1.-abs(mod(uv,2.)-1.);
 vec3 base=texture(ground_tex,uv).rgb*tint/sum;
 float lake=length((p-vec2(2180.,1080.))/vec2(330.,260.))+.045*sin(p.y*.017)+.03*sin(p.x*.023);
 base=mix(base,vec3(.57,.66,.49),1.-smoothstep(1.02,1.17,lake));
 base=mix(base,vec3(.35,.62,.65),1.-smoothstep(.98,1.035,lake));
 COLOR=vec4(base,1.);
}
