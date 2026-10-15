shader_type canvas_item;
render_mode unshaded;

uniform sampler2D brush_texture : repeat_enable, filter_linear;
varying vec2 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 field = texture(TEXTURE, UV);
	vec3 brush = texture(brush_texture, world_point / 760.0).rgb;
	vec3 brush2 = texture(brush_texture, world_point / 413.0 + vec2(.21,.68)).rgb;
	float pigment = dot(brush, vec3(.299,.587,.114));
	float pigment2 = dot(brush2, vec3(.299,.587,.114));
	vec3 land = field.rgb * (.91 + pigment * .20 + (pigment2-.55)*.08);
	float ripple = sin(world_point.x*.022 + world_point.y*.031 + TIME*.7)
		* sin(world_point.y*.011 - TIME*.45);
	vec3 water = mix(vec3(.48,.73,.75), vec3(.36,.63,.66), .35+pigment*.35);
	water += ripple * .012;
	float rim = (1.0-smoothstep(.06,.45,field.a)) * smoothstep(.0,.08,field.a);
	vec3 result = mix(land,water,field.a);
	result += vec3(.05,.055,.035)*rim;
	COLOR = vec4(result, 1.0);
}
