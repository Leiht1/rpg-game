extends RefCounted
## Separate world-sort anchors for canopy and each pole; original art is not edited.
var building: Node2D
var roof: Node2D
var image: Texture2D
var scale_value := 1.0
var top := 0.0
var faded := false
var fade: Tween
var parts: Array[Node2D]=[]
var roof_regions: Array=[]
var pixels: Image
const Config=preload("res://scripts/weather_body_rules.gd")
func configure(owner_node: Node2D) -> void:
 building=owner_node;building.y_sort_enabled=true
 var vertical: bool=building.manager.states[building.building_id].get("vertical",false)
 image=load("res://assets/weather/v2/shelter_vertical.png" if vertical else "res://assets/weather/v1/shelter.png")
 pixels=image.get_image()
 scale_value=float(Config.data.shelter_visual_width)/image.get_width()
 if vertical:scale_value=.3
 top=float(Config.data.shelter_visual_bottom)-image.get_height()*scale_value
 if vertical:top=140.0-1160*scale_value
 # Every source pixel belongs to exactly one part. Blank pixels remain blank.
 var regions: Array=[
  [Rect2(35,0,55,45),Rect2(46,240,274,image.get_height()-240)],
  [Rect2(550,0,55,45),Rect2(320,240,275,image.get_height()-240)],
  [Rect2(0,166,64,74),Rect2(0,240,46,image.get_height()-240)],
  [Rect2(576,166,64,74),Rect2(595,240,image.get_width()-595,image.get_height()-240)]]
 if vertical:
  regions=[[Rect2(400,0,100,200)],[Rect2(750,0,100,200)],[Rect2(240,590,120,image.get_height()-590)],[Rect2(900,590,120,image.get_height()-590)]]
 for i in 4:
  var foot: Array=preload("res://scripts/weather_exposure.gd").posts(building.manager.states[building.building_id])[i]
  var node := Node2D.new();node.name="ShelterPole"+str(i);node.position=Vector2(foot[0],foot[1]);building.add_child(node)
  if vertical and i<2:node.draw.connect(draw_vertical_back_pole.bind(node,i))
  node.draw.connect(draw_regions.bind(node,regions[i]))
  parts.append(node)
 roof=Node2D.new();roof.name="ShelterRoof";roof.position=Vector2(0,float(Config.data.shelter_visual_bottom));building.add_child(roof)
 roof_regions=[Rect2(0,0,35,45),Rect2(90,0,460,45),Rect2(605,0,35,45),Rect2(0,45,640,121),Rect2(64,166,512,74)]
 if vertical:
  roof.position.y=14
  roof_regions=[]
  var cuts: Array=[0,240,360,400,500,750,850,900,1020,image.get_width()]
  var rows: Array=[0,200,590,image.get_height()]
  for xx in cuts.size()-1:
   for yy in rows.size()-1:
    var cell:=Rect2(cuts[xx],rows[yy],cuts[xx+1]-cuts[xx],rows[yy+1]-rows[yy])
    if not regions.any(func(group):return group.any(func(rect):return rect.has_point(cell.get_center()))):roof_regions.append(cell)
 roof.draw.connect(draw_regions.bind(roof,roof_regions))
 roof.modulate.a=1.0
func draw_regions(node: Node2D, regions: Array) -> void:
 for region in regions:draw_part(node,region)
func draw_part(node: Node2D, source: Rect2) -> void:
 var destination := Rect2(Vector2(-image.get_width()*.5*scale_value,top)+source.position*scale_value-node.position,source.size*scale_value)
 node.draw_texture_rect_region(image,destination,source)
func update_occlusion(point: Vector2) -> void:
 if building.preview:return
 var next:=covers_head(point)
 var world=building.manager.service.world
 if not next and world.get_meta("network_game",false):
  for actor in world.actors.values():
   if is_instance_valid(actor) and actor.visible and covers_head(actor.global_position):next=true;break
 if next==faded:return
 faded=next
 if is_instance_valid(fade):fade.kill()
 fade=building.create_tween()
 fade.tween_property(roof,"modulate:a",float(Config.data.shelter_roof_occluded_alpha) if faded else 1.0,float(Config.data.shelter_roof_fade_seconds))
func covers_head(point: Vector2) -> bool:
 var p: Vector2=point-building.global_position
 var head := Rect2(p+Vector2(-16,-84),Vector2(32,54))
 var next := false
 # Visual occlusion is independent of gameplay rain coverage, including the eaves.
 if p.y<=roof.position.y:
  for region in roof_regions:
   var rect := Rect2(Vector2(-image.get_width()*.5*scale_value,top)+region.position*scale_value,region.size*scale_value)
   if not head.intersects(rect):continue
   var overlap: Rect2=head.intersection(rect)
   for x in [overlap.position.x,overlap.get_center().x,overlap.end.x-.01]:
    for y in [overlap.position.y,overlap.get_center().y,overlap.end.y-.01]:
     var uv:=Vector2i((Vector2(x,y)-Vector2(-image.get_width()*.5*scale_value,top))/scale_value)
     if pixels.get_pixelv(uv.clamp(Vector2i.ZERO,pixels.get_size()-Vector2i.ONE)).a>.2:next=true
 return next

func draw_vertical_back_pole(node: Node2D, index: int) -> void:
 var center: float=455 if index==0 else 795
 var destination:=Rect2(Vector2(center-26,200)*scale_value+Vector2(-image.get_width()*.5*scale_value,top)-node.position,Vector2(52,493)*scale_value)
 node.draw_texture_rect_region(image,destination,Rect2(274,750,52,390))
