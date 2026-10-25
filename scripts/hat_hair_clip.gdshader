shader_type canvas_item;
uniform sampler2D hat_mask : filter_linear;
uniform sampler2D hat_join : filter_nearest;
uniform vec2 hair_size;
uniform vec2 hat_size;
uniform vec2 hat_position;
uniform float clip_below = 0.0;
uniform float join_overlap = 3.0;
uniform float closure = 0.0;
uniform bool front_view = false;
uniform vec2 side_eye_center = vec2(.714,.622);
vec4 closed_eye(vec4 c, vec4 skin, vec2 uv) {
 vec2 d=(uv-side_eye_center)/vec2(.064,.102);
 float patch=1.0-smoothstep(.84,1.0,length(d));
 float arc=side_eye_center.y+.006+.020*(1.0-pow(clamp(d.x,-1.0,1.0),2.0));
 float ink=(1.0-smoothstep(.006,.014,abs(uv.y-arc)))*(1.0-smoothstep(.72,.92,abs(d.x)));
 return mix(c,mix(skin,vec4(.13,.055,.026,skin.a),ink),patch*closure);
}
varying vec4 actor_tint;
void vertex() { actor_tint=COLOR; }
void fragment() {
	vec4 c=closed_eye(texture(TEXTURE,UV),texture(TEXTURE,vec2(UV.x,side_eye_center.y+.112)),UV);
	vec2 point=(UV-vec2(.5))*hair_size;
	vec2 hat_uv=(point-hat_position)/hat_size+vec2(.5);
	float join_y=texture(hat_join,vec2(clamp(hat_uv.x,0.,1.),.5)).r;
	bool in_column=hat_uv.x>=0. && hat_uv.x<=1.;
	// Upper hair is tucked inside the hat, including the part above a far brim.
	// Keep a tiny overlap UNDER the near rim so filtering cannot open a seam.
	if((in_column && hat_uv.y<join_y-join_overlap/hat_size.y) || (!in_column && point.y<clip_below-join_overlap))c.a=0.;
	COLOR=c*actor_tint;
}
