shader_type canvas_item;
// Blend a continuous painted surface into the real terrain, without a cutout rim.
uniform vec2 display_size=vec2(2100.0,1400.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
 vec2 cell=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
void fragment(){
 vec4 paint=texture(TEXTURE,UV);
 float gray=dot(paint.rgb,vec3(.299,.587,.114));
 paint.rgb=mix(paint.rgb,vec3(gray),.42)*vec3(.96,1.01,1.065)+vec3(.035,.044,.049);
 vec2 p=(UV-vec2(.5))*display_size;
 float erosion=(noise(p/135.0)-.5)*100.0+(noise(p/43.0)-.5)*24.0;
 float distance_to_edge=length(p)+erosion;
 float coverage=1.0-smoothstep(350.0,645.0,distance_to_edge);
 // The original ground remains visible through the weathered transition.
 COLOR=vec4(paint.rgb,paint.a*coverage*.91)*COLOR;
}
