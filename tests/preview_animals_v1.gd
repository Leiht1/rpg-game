extends SceneTree
## Isolated review only: gifts and arranged animals never enter the player's save.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 Engine.set_meta("integration_seed",271828)
 var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 var s=w.item_service;var a=s.animals;var p=w.player.position
 while not w.stream.viewport_ready(p,Vector2(640,360)):await process_frame
 a.set_physics_process(false)
 for n in a.visuals.values():n.queue_free()
 a.visuals.clear();a.states.clear()
 var origin=Vector2.ZERO
 for y in range(-5,6):
  for x in range(-5,6):
   var base=Vector2(floor(p.x/96)*96,floor(p.y/64)*64)+Vector2(x*96,y*64)
   var clear=true
   for yy in range(-1,6):
    for xx in range(-1,6):
     if not a.clear_at(base+Vector2(xx*48,yy*32),16):clear=false;break
    if not clear:break
   if clear:origin=base;break
  if origin!=Vector2.ZERO:break
 if origin==Vector2.ZERO:origin=p-Vector2(96,96)
 for x in 2:
  add_build(s,"top%d"%x,"wood_fence",origin+Vector2(x*96+48,0))
  add_build(s,"bottom%d"%x,"fence_gate" if x==0 else "wood_fence",origin+Vector2(x*96+48,192))
 for y in 3:
  add_build(s,"left%d"%y,"wood_fence",origin+Vector2(0,y*64+32),true)
  add_build(s,"right%d"%y,"wood_fence",origin+Vector2(192,y*64+32),true)
 add_build(s,"bench","workbench",origin+Vector2(96,285))
 var sample=[["chicken",Vector2(50,65),false,false],["chicken",Vector2(58,134),true,false],["sheep",Vector2(143,65),true,false],["sheep",Vector2(143,130),true,true]]
 for i in sample.size():
  var spec=sample[i];var r=a.make_row(spec[0],origin+spec[1],spec[2],spec[3])
  if spec[0]=="sheep" and not spec[3]:r.product=2880.0
  a.states["preview:%d"%i]=r
 w.player.position=origin+Vector2(95,115);w.player.camera.reset_smoothing()
 for id in ["wild_berry","broad_leaf","carrot_seed","cabbage","copper_ore","silver_ore","wood"]:s.inventory.add(id,20)
 s.inventory.add("shears",1)
 a.sync_visuals();a.set_physics_process(true)
 # Keep preview animal identities fixed while visiting neighboring chunks.
 for coord in w.stream.loaded:a.generated["%d:%d"%[coord.x,coord.y]]=true
 w.title.text="动物养殖 V1 · 独立试玩（不写玩家存档）"
 s.notice.emit("选中浆果/种子或宽叶按 E 投喂；空格位切换跟随；装备羊毛剪后 E 剪毛")
func add_build(s:Node,id:String,kind:String,at:Vector2,vertical:bool=false)->void:
 var row=s.builds.candidate(kind,at,vertical,false,0);s.builds.states[id]=row;s.builds.install(s.world.stream.chunk_at(Vector2(row.x,row.y)))
