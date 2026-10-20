shader_type canvas_item;
render_mode unshaded;
uniform sampler2D exploration_mask : filter_linear, repeat_disable;
uniform vec2 world_low;
uniform float span;
uniform float extent;
void fragment(){
 vec2 uv=(world_low+UV*span)/extent;
 vec2 step_uv=1.0/vec2(textureSize(exploration_mask,0));
 float explored=texture(exploration_mask,uv).r*0.40;
 explored+=(texture(exploration_mask,uv+vec2(step_uv.x,0)).r+texture(exploration_mask,uv-vec2(step_uv.x,0)).r+texture(exploration_mask,uv+vec2(0,step_uv.y)).r+texture(exploration_mask,uv-vec2(0,step_uv.y)).r)*0.15;
 float reveal=smoothstep(0.22,0.98,explored);
 float haze=sin(uv.x*61.0+sin(uv.y*39.0))*sin(uv.y*53.0)*0.009;
 COLOR=vec4(vec3(0.19+haze,0.255+haze,0.235+haze),1.0-reveal);
}
