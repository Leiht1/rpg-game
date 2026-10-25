shader_type canvas_item;
render_mode unshaded;
uniform sampler2D next_frame : filter_linear, repeat_disable;
uniform float frame_blend : hint_range(0.0,1.0)=0.0;
varying vec4 sprite_tint;
void vertex(){sprite_tint=COLOR;}
void fragment(){
	vec4 a=texture(TEXTURE,UV);
	vec4 b=texture(next_frame,UV);
	vec4 p=mix(vec4(a.rgb*a.a,a.a),vec4(b.rgb*b.a,b.a),smoothstep(0.0,1.0,frame_blend));
	COLOR=vec4(p.rgb/max(p.a,0.00001),p.a)*sprite_tint;
}
