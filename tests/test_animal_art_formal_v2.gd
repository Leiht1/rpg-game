extends SceneTree
const Candidate=preload("res://scripts/animal_actor.gd")
const OUT="res://reports/animals-art-formal-v2/"
var w
var animals=[]
var bases=[]
var ready_review=false
var clock=0.0
var last_action=-1
var page=0
var review_paused=false
var capture=false
var checks=[]
var status:Label
var studio:CanvasLayer
var plain:Node2D
var parts:Node2D
var copies=[]
var phase_samples={}
var held_keys={}
var review_start_frame=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func run()->void:
 capture="--capture" in OS.get_cmdline_user_args()
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.set_process(false);w.player.set_physics_process(false);w.item_service.set_process(false);w.environment_view.set_process(false)
 var a=w.item_service.animals;a.set_physics_process(false)
 for v in a.visuals.values():v.queue_free()
 a.visuals.clear();a.states.clear()
 # Use the existing terrain's original open landing area, not a new map or save.
 var origin=w.generator.spawn
 w.player.position=origin;w.player.camera.position_smoothing_enabled=false
 w.player.camera.zoom=Vector2.ONE;w.player.camera.reset_smoothing()
 w.stream.update_target(origin)
 while not w.stream.viewport_ready(origin,Vector2(640,360)):await process_frame
 w.ui.visible=false;w.item_ui.visible=false
 var spots=[Vector2(-220,25),Vector2(-60,25),Vector2(110,25)]
 w.player.position=origin+Vector2(-365,25);w.player.facing="side";w.player.update_animation()
 # Camera is a child of the player; compensate to centre the review lineup.
 w.player.camera.position=Vector2(365,-25)
 for i in 3:
  var id="art-review:%d"%i;var r=a.make_row("chicken" if i==0 else "sheep",origin+spots[i],true)
  if i==2:r.wool=false
  a.states[id]=r
  var v=Candidate.new();v.manager=a;v.animal_id=id;v.position=origin+spots[i];w.object_root.add_child(v);v.set_physics_process(false)
  animals.append(v);bases.append(v.position)
 check(not w.persistent_world,"isolated fixture never writes player save")
 check(root.size==Vector2i(1280,720),"project default native window 1280x720")
 check(animals[0].bones.Leg1.position.x-animals[0].bones.Leg0.position.x==10,"chicken feet narrowed 18 to 10 world units")
 check(animals[0].bones.Leg0.position.x==-1 and animals[0].bones.Leg1.position.x==9,"chicken feet shifted right together by four")
 check(is_equal_approx(animals[2].part_sizes.Head.y,35) and animals[2].part_sizes.Head.x>34,"sheep head enlarged within 38x35 aspect preserving fit")
 check(animals[2].part_sizes.Leg0.x<8.5,"sheep leg narrowed without shortening")
 check(animals[1].bones.Head.position==animals[2].bones.Head.position,"wool and bare sheep share head pivot")
 for key in ["Head","Leg0","Leg1","Leg2","Leg3"]:
  var wool=animals[1].bones[key];var bare=animals[2].bones[key]
  check(wool.position==bare.position and wool.get_child(0).scale==bare.get_child(0).scale and wool.get_child(0).position==bare.get_child(0).position,"identical wool/bare attachment geometry "+key)
 for i in 3:
  var v=animals[i]
  check(v.rig is Skeleton2D and v.bones.size()==(5 if i==0 else 6),"existing skeletal structure %d"%i)
  for stage in 3:
   var r=v.row();r.age=[0.0,float(a.rules.half_growth),float(a.rules.adult_growth)][stage];v.refresh()
   check(is_equal_approx(v.rig.scale.y,[.48,.72,1.0][stage]),"same assets growth stage %d/%d"%[i,stage])
  v.row().age=float(a.rules.adult_growth);v.refresh()
 for v in [animals[1],animals[2]]:
  var original_wool=v.row().wool
  v.row().wool=false;v.refresh()
  check(v.body_sprite.texture.resource_path=="res://assets/animals/v2/sheep_bare.png" and v.body_sprite.material==null,"formal sheared body retains skin without fur material")
  v.row().wool=true;v.refresh()
  check(v.body_sprite.texture.resource_path=="res://assets/animals/v2/sheep_wool.png" and v.body_sprite.material is ShaderMaterial,"formal regrown body restores white wool material")
  v.row().wool=original_wool;v.refresh()
 build_pages()
 export_sheep_profile()
 for i in 8:await process_frame
 ready_review=true
 review_start_frame=Engine.get_process_frames()
func export_sheep_profile()->void:
 var profile={}
 var v=animals[2]
 for key in v.bones:
  var b=v.bones[key];var s=b.get_child(0)
  profile[key]={"joint":[b.position.x,b.position.y],"offset":[s.position.x,s.position.y],"size":[s.texture.get_width()*s.scale.x,s.texture.get_height()*s.scale.y],"asset":str(s.texture.get_meta("source")).get_file()}
 var f=FileAccess.open(OUT+"sheep-rig-profile.json",FileAccess.WRITE);f.store_string(JSON.stringify(profile,"\t"));f.close()
func label(text:String,at:Vector2,parent:Node,font_size:int=22)->Label:
 var l=Label.new();l.text=text;l.position=at;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",Color("493627"));parent.add_child(l);return l
func build_pages()->void:
 studio=CanvasLayer.new();studio.layer=20;root.add_child(studio)
 plain=Node2D.new();parts=Node2D.new();studio.add_child(plain);studio.add_child(parts)
 for pg in [plain,parts]:
  var bg=ColorRect.new();bg.color=Color("f3e6cd");bg.size=Vector2(1280,720);pg.add_child(bg)
 var hero=w.player.character.duplicate();plain.add_child(hero);hero.position=Vector2(100,164);hero.scale=Vector2.ONE*3
 var ap=hero.get_node("AnimationPlayer");ap.play("side_breathe");ap.seek(.4,true);ap.pause()
 for i in 3:
  var copy=animals[i].rig.duplicate();plain.add_child(copy);copy.position=Vector2(550+i*260,500);copy.scale=Vector2.ONE*3;copies.append(copy)
 label("正式主角",Vector2(220,550),plain)
 for i in 3:label(["鸡 · 双脚收近","有毛羊","无毛羊"][i],Vector2(485+i*260,550),plain)
 label("放大 3 倍检查轮廓与关节 · 同一骨骼 / 成年素材",Vector2(60,115),plain,20)
 var names=["chicken_body","chicken_head","chicken_wing","chicken_leg","sheep_wool","sheep_bare","sheep_head","sheep_leg","chicken_head_closed"]
 var captions=["鸡身体","鸡头 / 颈","鸡翅膀","鸡脚（复用双脚）","有毛身体","无毛身体","羊头（无脖子）","羊腿（复用四肢）","鸡闭眼头（备用）"]
 for i in 9:
  var tex=Candidate.texture(names[i]);var s=Sprite2D.new();s.texture=tex;s.material=Candidate.fur_material(names[i]);s.position=Vector2(245+(i%3)*390,205+(i/3)*180);s.scale=Vector2.ONE*minf(210.0/tex.get_width(),125.0/tex.get_height());parts.add_child(s)
  label(captions[i],Vector2(155+(i%3)*390,275+(i/3)*180),parts,19)
 var controls=CanvasLayer.new();controls.layer=30;root.add_child(controls)
 var bar=ColorRect.new();bar.color=Color(.96,.91,.81,.96);bar.size=Vector2(1280,92);controls.add_child(bar)
 label("鸡羊统一画风 V2 · 正式采用",Vector2(28,10),controls,25)
 status=label("",Vector2(28,49),controls,19)
 show_page(0)
func show_page(n:int)->void:
 page=n;plain.visible=n==1;parts.visible=n==2
func _process(delta:float)->bool:
 if not ready_review:return false
 for key in [KEY_1,KEY_2,KEY_3,KEY_SPACE]:
  var down=Input.is_key_pressed(key)
  if down and not held_keys.get(key,false):
   if key==KEY_SPACE:review_paused=not review_paused
   else:show_page(key-KEY_1)
  held_keys[key]=down
 if not review_paused:clock+=delta
 var action=int(clock/3.0)%5
 status.text="%s · 正常速度 1×　　1 实景　2 纯色完整造型　3 独立部件　空格 暂停"%["待机","走动","觅食 / 低头","投喂 / 点头","跟随移动"][action]
 if action!=last_action:
  for i in 3:
   animals[i].position=bases[i];animals[i].travel=0;animals[i].decision=0
   animals[i].row().mode="follow" if action==4 else "stay"
  last_action=action
 for i in 3:
  var v=animals[i]
  if action!=4:v.decision=100;v.goal=v.position+Vector2(200,0) if action==1 else v.position
  v.feeding=action==2;v.feedback=1.0 if action==3 else 0.0
  if not review_paused:v._physics_process(delta)
  var copy=copies[i]
  copy.scale.x=3.0 if v.rig.scale.x>=0 else -3.0
  for key in v.bones:copy.get_node(NodePath(key)).rotation=v.bones[key].rotation
 if capture:
  if not phase_samples.has(action) and fmod(clock,3.0)>.7:
   phase_samples[action]=true;call_deferred("snapshot",action)
  if clock>=15.0:
   ready_review=false;call_deferred("finish")
 return false
func snapshot(action:int)->void:
 await process_frame
 root.get_texture().get_image().save_png(OUT+"scene-%d.png"%action)
 for i in 3:
  var v=animals[i]
  check(v.bones.Head.rotation>0.4 if action==2 else is_finite(v.bones.Head.rotation),"finite inherited head / forage motion %d/%d"%[action,i])
  check(str(v.body_sprite.texture.get_meta("source","")).begins_with(Candidate.ART),"candidate texture retained through action %d/%d"%[action,i])
  check(v.bones.Body.scale==Vector2.ONE,"stable body bone scale %d/%d"%[action,i])
  if action==4:check(v.rig.scale.x<0 and v.row().mode=="follow","inherited follow turns left with mirrored joints %d"%i)
func finish()->void:
 for copy in copies:
  copy.scale=Vector2.ONE*3
  for bone in copy.get_children():bone.rotation=0
 show_page(1)
 await process_frame;await process_frame
 root.get_texture().get_image().save_png(OUT+"plain.png")
 show_page(2)
 await process_frame;await process_frame
 root.get_texture().get_image().save_png(OUT+"parts.png")
 var failed=checks.filter(func(c):return not c.pass)
 var file=FileAccess.open(OUT+"results.json",FileAccess.WRITE);file.store_string(JSON.stringify({"godot":Engine.get_version_info().string,"checks":checks,"count":checks.size(),"failed":failed.size(),"review_start_frame":review_start_frame,"capture_fps":30},"\t"));file.close()
 print("ANIMAL ART V2: ",checks.size()," checks, ",failed.size()," failed")
 quit(0 if failed.is_empty() else 1)
