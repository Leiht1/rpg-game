shader_type canvas_item;
uniform float closure : hint_range(0.0,1.0) = 0.0;
uniform bool front_view = false;
uniform vec2 side_eye_center = vec2(.714,.622);
vec4 closed_eye(vec4 original, vec4 skin, vec2 uv, vec2 center) {
	vec2 d=(uv-center)/vec2(.064,.102);
	float patch=1.0-smoothstep(.84,1.0,length(d));
	// Reuse the original face's adjacent skin and original ink; no new head image.
	float arc=center.y+.006+.020*(1.0-pow(clamp(d.x,-1.0,1.0),2.0));
	float ink=(1.0-smoothstep(.006,.014,abs(uv.y-arc)))*(1.0-smoothstep(.72,.92,abs(d.x)));
	vec4 eyelid=mix(skin,vec4(.13,.055,.026,skin.a),ink);
	return mix(original,eyelid,patch*closure);
}
void fragment() {
	vec4 color=texture(TEXTURE,UV);
	if(front_view) {
		vec4 skin=texture(TEXTURE,vec2(UV.x,.751));
		color=closed_eye(color,skin,UV,vec2(.321,.639));
		color=closed_eye(color,skin,UV,vec2(.692,.639));
	} else { color=closed_eye(color,texture(TEXTURE,vec2(UV.x,side_eye_center.y+.112)),UV,side_eye_center); }
	COLOR=color;
}
