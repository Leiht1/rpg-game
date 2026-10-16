extends Node2D
## Static original decorations only; the shader supplies surface colour layers.
const VERSION="ground-preview-0.5.0"
var mode:=1
var tufts:Array[Dictionary]=[]
var textures:Array[Texture2D]=[]
func configure(g:WildGenerator,c:Vector2i,props:Array,center:Vector2=Vector2.ZERO)->void:
	if center==Vector2.ZERO:center=g.spawn
	position=Vector2(c)*WildGenerator.CHUNK_PX
	for i in 3:textures.append(load("res://assets/environment/cartoon_v2/tuft_%d.png"%i))
	# Reuse original map positions in sparse groups, keeping the clearing clean.
	for prop in props:
		if prop.kind<4 or prop.position.distance_to(center)<210:continue
		if prop.position.distance_to(center)>1300:continue
		var cluster:=Vector2i((prop.position-center)/240.0)
		if not str(prop.id).begins_with("clearing:") and g.random_at(cluster.x,cluster.y,681)>.28:continue
		tufts.append({"p":prop.position-position,"kind":prop.kind-4,"w":28.0*prop.scale})
func _draw()->void:
	if mode==0:return
	for t in tufts:
		var texture:Texture2D=textures[t.kind]
		var h:float=t.w*texture.get_height()/texture.get_width()
		draw_texture_rect(texture,Rect2(t.p+Vector2(-t.w*.5,-h+8),Vector2(t.w,h)),false)
