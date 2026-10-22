shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 viewport_size = vec2(1280.0,720.0);
void fragment() {
	vec2 edge_px = min(UV,vec2(1.0)-UV)*viewport_size;
	float edge = 1.0-smoothstep(0.0,min(viewport_size.x,viewport_size.y)*0.115,min(edge_px.x,edge_px.y));
	COLOR=vec4(0.75,0.04,0.035,strength*0.4*edge*edge);
}
