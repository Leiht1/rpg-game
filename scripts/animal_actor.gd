extends CharacterBody2D
## Side-only cutout puppet: Skeleton2D + Bone2D joints, no whole-image sliding.
const ART="res://assets/animals/v2/"
static var textures={}
var part_sizes={}
static func fur_material(asset:String)->ShaderMaterial:
 if asset not in ["chicken_body","chicken_head","chicken_head_closed","chicken_wing","sheep_wool","sheep_head","sheep_leg"]:return null
 var m=ShaderMaterial.new();m.shader=load("res://assets/animals/v2/white_fur.gdshader")
 m.set_shader_parameter("all_pale",asset in ["chicken_body","chicken_wing","sheep_wool","sheep_leg"])
 return m
static func texture(asset:String)->Texture2D:
 if not textures.has(asset):
  var t=load(ART+asset+".png");t.set_meta("source",ART+asset+".png");textures[asset]=t
 return textures[asset]

var manager: Node
var animal_id := ""
var rig: Skeleton2D
var bones: Dictionary={}
var body_sprite: Sprite2D
var rng=RandomNumberGenerator.new()
var goal=Vector2.ZERO
var decision := 0.0
var phase := 0.0
var feeding := false
var feedback := 0.0
var travel := 0.0
var idle_tick := 0.0
var last_stage := -1
var feet: CircleShape2D

func row() -> Dictionary:return manager.states[animal_id]

func _ready() -> void:
 rng.seed=animal_id.hash()^manager.service.world.world_seed
 collision_layer=1;collision_mask=1;motion_mode=MOTION_MODE_FLOATING
 var shape=CollisionShape2D.new();var circle=CircleShape2D.new();circle.radius=9 if row().species=="chicken" else 13;feet=circle;shape.shape=circle;add_child(shape)
 add_to_group("world_interactables");set_meta("animal_id",animal_id);set_meta("interaction_action","animal");set_meta("interaction_range",68.0)
 rig=Skeleton2D.new();rig.name="SideSkeleton";add_child(rig)
 var chicken=row().species=="chicken"
 for n in (2 if chicken else 4):
  var x=(-10 if chicken else -22)+(n%2)*(18 if chicken else 40)
  var leg=part("Leg%d"%n,"chicken_leg" if chicken else "sheep_leg",Vector2(x,-12 if chicken else -18),Vector2(7,15) if chicken else Vector2(10,23),Vector2(.5,.1))
  if n>=2:leg.modulate=Color(.82,.82,.82);rig.move_child(leg,0)
 body_sprite=part("Body","chicken_body" if chicken else "sheep_wool",Vector2(0,-24 if chicken else -32),Vector2(42,31) if chicken else Vector2(69,43)).get_child(0)
 part("Head","chicken_head" if chicken else "sheep_head",Vector2(14,-35) if chicken else Vector2(28,-40),Vector2(21,27) if chicken else Vector2(31,28),Vector2(.25,.7))
 if chicken:part("Wing","chicken_wing",Vector2(-4,-25),Vector2(22,16),Vector2(.25,.25))
 goal=position;decision=rng.randf_range(.1,3)
 refresh()

func part(label:String,asset:String,at:Vector2,size:Vector2,pivot:Vector2=Vector2(.5,.5))->Bone2D:
 var chicken=row().species=="chicken"
 # Register joints against the smaller shorn torso, never the outer wool edge.
 if label=="Head" and not chicken:at=Vector2(14,-35);size=Vector2(38,35)
 if label.begins_with("Leg"):
  var n=int(label.trim_prefix("Leg"))
  if chicken:at.x=-1+n*10;size=Vector2(9,15)
  else:
   # Upper leg is buried in the bare torso; length preserves the ground line.
   at=Vector2(-12+(n%2)*24+(-2 if n>=2 else 0),-22+(-2 if n>=2 else 0));size=Vector2(13,25)
 var b=Bone2D.new();b.name=label;b.position=at;b.set_autocalculate_length_and_angle(false);b.length=10;b.rest=Transform2D(0,at);rig.add_child(b);bones[label]=b
 var sprite=Sprite2D.new();sprite.centered=false;b.add_child(sprite)
 var s:Sprite2D=b.get_child(0);s.texture=texture(asset);s.material=fur_material(asset)
 # Bodies share a registered canvas; other parts retain their generated aspect ratio.
 var natural=s.texture.get_size()
 var fit=minf(size.x/natural.x,size.y/natural.y)
 var final_size=natural*fit
 if label=="Body":final_size=size
 # Narrow only the sheep leg width; retain leg length and grounded soles.
 if not chicken and label.begins_with("Leg"):final_size.x*=.64
 s.scale=final_size/natural;s.position=-final_size*pivot
 part_sizes[label]=final_size
 return b

func refresh() -> void:
 var r=row();last_stage=manager.stage(r)
 var scale_value=[.48,.72,1.0][last_stage];feet.radius=(9 if r.species=="chicken" else 13)*scale_value
 set_meta("display_name","鸡" if r.species=="chicken" else "羊")
 rig.scale=Vector2(scale_value if rig.scale.x>=0 else -scale_value,scale_value)
 queue_redraw()
 if r.species=="sheep":
  var tex=texture("sheep_wool" if r.wool else "sheep_bare")
  if body_sprite.texture!=tex:body_sprite.material=fur_material("sheep_wool") if r.wool else null
  if body_sprite.texture!=tex:body_sprite.texture=tex;body_sprite.scale=Vector2(69,43)/tex.get_size()

func _physics_process(delta: float) -> void:
 if not manager.states.has(animal_id):return
 if manager.service.world.get_meta("network_game",false):
  var state=row();var previous=position;position=position.lerp(Vector2(state.x,state.y),minf(1,delta*12));refresh()
  phase+=delta;travel+=position.distance_to(previous)
  if absf(position.x-previous.x)>.01:rig.scale.x=absf(rig.scale.x)*signf(position.x-previous.x)
  for key in bones:
   if key.begins_with("Leg"):bones[key].rotation=sin(travel*.18+(0 if int(key.trim_prefix("Leg")) in [0,3] else PI))*.38 if position.distance_squared_to(previous)>.001 else sin(phase*2)*.025
  bones.Head.rotation=sin(phase*1.7)*.04
  return
 var r=row();var env=manager.service.world.environment_view
 if not manager.service.writable or env.simulation.paused or env.preview:return
 if r.departed:hide();return
 refresh();feedback=maxf(0,feedback-delta);decision-=delta;phase+=delta
 var player=manager.service.world.player
 var far=position.distance_to(player.position)>900
 idle_tick+=delta
 if far and idle_tick<.2:return
 var dt=idle_tick;idle_tick=0.0
 if decision<=0:
  feeding=rng.randf()<.35;decision=rng.randf_range(1.8,6.5)
  if r.tamed and r.mode=="follow" and position.distance_to(player.position)>65:
   goal=player.position+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(38,60);feeding=false;decision=.6
  elif r.wild_age>=manager.rules.wild_leave_minutes and (not r.tamed or r.mode=="stay"):
   goal=position+Vector2.from_angle(r.escape_angle)*240;feeding=false;decision=2
  elif rng.randf()<.35:goal=position
  else:
   var center=Vector2(r.home_x,r.home_y) if r.tamed else position
   goal=center+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(25,130)
 var direction=position.direction_to(goal)
 var speed=float(manager.rules[r.species].speed)*(1.35 if not r.tamed and r.wild_age>=manager.rules.wild_leave_minutes else 1.0)
 if r.tamed and r.mode=="follow" and position.distance_to(player.position)>100:speed*=2.5
 var being_sheared=player.action in ["shear","feed"] and player.action_target==self
 velocity=direction*speed if position.distance_to(goal)>8 and feedback<=0 and not feeding and not being_sheared else Vector2.ZERO
 # Remote actors move in bounded 0.2s sweeps, avoiding tunnelling through thin fences.
 var motion=velocity*dt
 if motion.length()>0:
  if not manager.service.world.generator.can_walk(position+motion,14) or manager.service.world.generator.sample(position+motion).z>.08:
   decision=0;velocity=Vector2.ZERO
  else:
   var hit=move_and_collide(motion)
   if hit:
    goal=position+direction.rotated(rng.randf_range(.8,2.1)*(1 if rng.randf()<.5 else -1))*80;decision=rng.randf_range(.5,1.2)
    velocity=Vector2.ZERO
   else:travel+=motion.length()
 if velocity.length()>0:
  rig.scale.x=absf(rig.scale.x)*(1 if velocity.x>=0 else -1)
  for key in bones:
   if key.begins_with("Leg"):bones[key].rotation=sin(travel*.18+(0 if int(key.trim_prefix("Leg")) in [0,3] else PI))*.38
 else:
  for key in bones:
   if key.begins_with("Leg"):bones[key].rotation=sin(phase*2)*.025
 bones.Head.rotation=sin(phase*5)*.12 if feedback>0 else .55+sin(phase*3)*.12 if feeding else sin(phase*1.7)*.04
 if bones.has("Wing"):bones.Wing.rotation=sin(phase*7)*.12 if feedback>0 else sin(phase*2)*.025
 r.x=position.x;r.y=position.y
 if motion.length()>0:manager.service.dirty=true
 # A trapped animal cannot reach its departure distance, and remains physically penned.
 if not r.tamed and r.wild_age>=manager.rules.wild_leave_minutes and position.distance_to(Vector2(r.home_x,r.home_y))>620:
  r.departed=true;hide();manager.service.dirty=true

func perform_interaction(_action: String, _player: Node2D) -> bool:
 return manager.interact(animal_id,self)

func _draw()->void:
 # Same small, soft contact ellipse as WildPlayer; never baked into source PNGs.
 var k=[.48,.72,1.0][maxi(0,last_stage)]
 draw_set_transform(Vector2(0,-2),0,Vector2(1,.35)*k)
 draw_circle(Vector2.ZERO,13 if row().species=="sheep" else 9,Color(.17,.23,.16,.19))
