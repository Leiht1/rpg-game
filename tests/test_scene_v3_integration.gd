extends SceneTree
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures.append(message);push_error(message)
func _initialize() -> void: call_deferred("run")
func tick(p:WildPlayer,n:int) -> void:
 for i in n:
  p._physics_process(1.0/60)
  await physics_frame
func run() -> void:
 var world=load("res://scenes/world.tscn").instantiate()
 root.add_child(world)
 var p:WildPlayer=world.player
 p.automated=true
 p.set_physics_process(false)
 var deadline=Time.get_ticks_msec()+20000
 while not world.started and Time.get_ticks_msec()<deadline: await process_frame
 check(world.started,"World starts")
 if not world.started: quit(1);return
 var origin=p.position
 var art_ok:=true
 var size_ok:=true
 var contact_ok:=true
 var quiet_ok:=true
 for entry in world.stream.loaded.values():
  check(entry.ground.stamps.is_empty(),"Legacy ground stamps disabled")
  for prop in entry.props:
   art_ok=art_ok and prop.texture.resource_path.begins_with("res://assets/environment/stylized_v3/")
   var old=load("res://assets/environment/cartoon_v2/%s.png"%world.stream.FILES[prop.kind])
   size_ok=size_ok and prop.texture.get_size()==old.get_size()
   contact_ok=contact_ok and prop.candidate_mode==1
   if prop.kind>=4 and prop.position.distance_to(origin)<=160:quiet_ok=quiet_ok and not prop.visible
 check(art_ok,"Approved art used for streamed props")
 check(size_ok,"Original logical texture canvases retained")
 check(contact_ok,"No legacy prop grass/soil halo")
 check(quiet_ok,"Central activity area clear of decoration")
 var tree:Node2D
 for node in get_nodes_in_group("trees"):
  if node.get_meta("prop_id")=="clearing:0":tree=node
 check(tree!=null,"Test clearing tree")
 if tree!=null:
  var at=tree.position
  p.position=at+Vector2(-100,0)
  p.input_override=Vector2.RIGHT;p.run_override=true
  await tick(p,40)
  check(p.position.x<at.x-18 and p.position.x>at.x-36,"Run blocks at trunk, not crown")
  p.position=at+Vector2(-65,-75)
  await tick(p,24)
  check(p.position.x>at.x+50,"Crown can be traversed")
  p.position=at+Vector2(-48,0)
  p.input_override=Vector2.ZERO
  await physics_frame
  p.try_interact()
  check(p.action=="chop","Chop chooses reachable tree")
  await tick(p,101)
  check(int(world.stream.tree_hits.get("clearing:0",0))==1,"One hit per action")
  p.try_interact();await tick(p,101)
  check(world.stream.harvested.has("clearing:0"),"Second hit fells tree")
  check(not tree.is_in_group("trees"),"Felled tree not interactable")
  var drop:Node2D=world.stream.drops.back()
  p.position=drop.position+Vector2(-18,12)
  await physics_frame
  p.try_interact()
  check(p.action=="pickup","Pickup chooses wood")
  await tick(p,134)
  check(world.stream.collected_wood==1,"Pickup exactly once")
  p.input_override=Vector2.RIGHT;p.position=at+Vector2(-65,0)
  await tick(p,25)
  check(p.position.x>at.x+45,"Felled trunk releases collider")
 var rock:Node2D
 for node in get_nodes_in_group("rocks"):
  if node.get_meta("prop_id")=="clearing:5":rock=node
 check(rock!=null,"Test rock")
 if rock!=null:
  p.position=rock.position+Vector2(-95,0);p.input_override=Vector2.RIGHT
  await tick(p,40)
  check(p.position.x<rock.position.x-20 and p.position.x>rock.position.x-55,"Rock base contact")
  p.position=rock.position+Vector2(-95,-60)
  await tick(p,37)
  check(p.position.x>rock.position.x+70,"Rock top is not an oversized blocker")
 check(not world.generator.can_walk(Vector2(1,1)),"World border blocks feet")
 var gen=load("res://scripts/world_generator.gd").new(world.world_seed,world.map_cells)
 var coord=world.stream.chunk_at(origin)
 check(gen.props_for_chunk(coord)==world.generator.props_for_chunk(coord),"Same seed reproduces clearing props")
 p.position=origin;p.input_override=Vector2.ZERO;p.running=false;p.action="";p.moving=false;p.facing="front";p.update_animation()
 p.camera.reset_smoothing()
 await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://reports/scene-v3-after-interaction.png")
 var report={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"walk_speed":200,"run_speed":310,"scope":"approved art references and canvas sizes, empty legacy stamps, quiet center, trunk/crown/rock collisions, chop/drop/pickup, deterministic clearing; no unrelated regression or performance benchmark"}
 var f=FileAccess.open("res://reports/scene-v3-integration-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
 print("SCENE CARTOON ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
func make_key(code:Key) -> InputEventKey:
 var event:=InputEventKey.new();event.physical_keycode=code;return event
