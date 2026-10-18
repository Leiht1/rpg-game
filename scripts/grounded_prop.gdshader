shader_type canvas_item;
render_mode unshaded;
// One viewport copy is explicitly taken after terrain and before all props/shadows.
uniform sampler2D ground_screen : hint_screen_texture, repeat_disable, filter_linear;
void fragment(){
 if(UV.x < -.5){
  COLOR.rgb=textureLod(ground_screen,SCREEN_UV,0.).rgb;
 }
}
