shader_type canvas_item;
uniform float bend=0.;
uniform float height=190.;
uniform float fixed_y=-16.;
uniform bool tree=true;
void vertex(){
 // Fixed contact band has zero weight; displacement and slope join smoothly.
 float w=clamp((fixed_y-VERTEX.y)/max(1.,height-8.+fixed_y),0.,1.);
 if(tree){VERTEX.x+=bend*w*w;}
}
