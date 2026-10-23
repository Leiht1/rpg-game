shader_type canvas_item;
uniform vec4 skin_color : source_color = vec4(1.0,.75,.47,1.0);
uniform bool skin_enabled = true;
uniform vec2 skin_region = vec2(0.0,1.0);
uniform bool blue_outfit = false;
uniform float closure = 0.0;
uniform vec2 side_eye_center = vec2(.79,.57);
vec4 close_eye(vec4 c, vec4 skin, vec2 uv) {
	vec2 d=(uv-side_eye_center)/vec2(.06,.11);
	float patch=1.0-smoothstep(.85,1.0,length(d));
	float arc=side_eye_center.y+.008+.022*(1.0-pow(clamp(d.x,-1.0,1.0),2.0));
	float ink=(1.0-smoothstep(.006,.014,abs(uv.y-arc)))*(1.0-smoothstep(.7,.92,abs(d.x)));
	return mix(c,mix(skin,vec4(.13,.055,.026,skin.a),ink),patch*closure);
}
varying vec4 actor_tint;
void vertex() { actor_tint = COLOR; }
void fragment() {
	vec4 c=close_eye(texture(TEXTURE,UV),texture(TEXTURE,vec2(UV.x,side_eye_center.y+.13)),UV);
	// Recolour only the teal jacket pigment; retain skin, ink and fabric shading.
	if (blue_outfit) {
		float jacket=smoothstep(.015,.08,min(c.g,c.b)-c.r);
		float light=clamp(c.g/.56,.18,1.6);
		c.rgb=mix(c.rgb,vec3(.16,.28,.72)*light,jacket);
	}
	// Only warm peach pigment, retaining ink, eyes, white cloth and their shadows.
	float mask=smoothstep(.18,.35,c.r)*smoothstep(.035,.10,c.r-c.g)*smoothstep(.025,.07,c.g-c.b);
	mask*=step(skin_region.x,UV.y)*step(UV.y,skin_region.y);
	float shade=clamp(c.r/.98,.2,1.12);
	if(skin_enabled) c.rgb=mix(c.rgb,skin_color.rgb*shade,mask);
	COLOR=c*actor_tint;
}
