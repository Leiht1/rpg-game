extends SceneTree
var app:Node
var checks:=0
func verify(ok:bool,message:String):
 checks+=1
 if not ok:push_error(message);quit(1);return
 print("PASS ",message)
func _initialize():run.call_deferred()
func key(code:int,pressed:bool):
 var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e)
 await process_frame
func run():
 var network=root.get_node("Network")
 var fixture_path:="res://reports/network-v01/private/fixture0.json"
 var output_path:="res://reports/network-movement-v3/shortcut.png"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--fixture="):fixture_path=arg.trim_prefix("--fixture=")
  if arg.begins_with("--output="):output_path=arg.trim_prefix("--output=")
 var f=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
 var r=await network.call_api("login",{"username":f.username,"password":f.password})
 verify(r.get("ok",false),"isolated TLS login")
 app=load("res://scenes/launcher.tscn").instantiate();root.add_child(app);await process_frame
 await app.resume_online()
 var world=app.active_world
 verify(is_instance_valid(world),"online world entry")
 verify(world.actors[network.profile.player_id].get_node("Nickname").position.y==-105,"nickname directly above head")
 var own=world.actors[network.profile.player_id]
 await create_timer(.5).timeout
 # Suppress new requests briefly to measure response-independent rendering.
 world.set_process(false)
 while world.moving_request or world.polling:await process_frame
 own.confirmed_at=Time.get_ticks_msec()
 var start:Vector2=own.position
 await key(KEY_D,true)
 await physics_frame;await physics_frame
 verify(own.position.x>start.x+1,"local movement starts within two physics frames without a reply")
 var target:Vector2=own.target_position
 var old=world.session_data.character.duplicate(true)
 old.merge({"player_id":network.profile.player_id,"nickname":"娴嬭瘯","avatar":""},true)
 old.x=target.x-500
 world.apply_character(old)
 verify(own.target_position==target,"stale poll cannot rewind own movement")
 await create_timer(1.15).timeout
 verify(own.position.distance_to(own.target_position)<=305,"prediction duration capped without acknowledgements")
 verify(not own.moving,"prediction stops after acknowledgement timeout")
 await key(KEY_D,false)
 world.set_process(true)
 await create_timer(.4).timeout
 print("SYNC_STATUS ",world.notice.text," pending=",own.pending_inputs.size()," failures=",world.failures)
 var moved_from:Vector2=own.position
 var travel:=Vector2.ZERO
 var travel_key:=KEY_D
 for candidate in [[Vector2.RIGHT,KEY_D],[Vector2.LEFT,KEY_A],[Vector2.UP,KEY_W],[Vector2.DOWN,KEY_S]]:
  var safe:=true
  for step in range(0,601,24):
   var sample_at:Vector2=(moved_from+candidate[0]*step)/48.0
   sample_at=Vector2(floorf(sample_at.x)+.5,floorf(sample_at.y)+.5)*48.0
   if world.generator.sample(sample_at).z>.03 or world.generator.coast_distance(sample_at)<24:safe=false;break
  if safe:travel=candidate[0];travel_key=candidate[1];break
 verify(not travel.is_zero_approx(),"clear corridor for movement benchmark")
 await key(travel_key,true)
 var backwards:=0
 var samples:=0
 var last_position:Vector2=own.position
 var until:=Time.get_ticks_msec()+1200
 while Time.get_ticks_msec()<until:
  await physics_frame
  if (own.position-last_position).dot(travel)<-.5:backwards+=1
  samples+=1;last_position=own.position
 await key(travel_key,false)
 print("MOVEMENT_METRICS samples=",samples," backwards=",backwards," distance=",(own.position-moved_from).dot(travel))
 verify((own.position-moved_from).dot(travel)>100,"sustained real HTTPS movement")
 verify(backwards<=2,"no repeated backwards correction on clear ground")
 var stopped_at:Vector2=own.position
 await create_timer(.7).timeout
 verify(own.position.distance_to(stopped_at)<2,"stop does not produce delayed pullback")
 await key(KEY_SHIFT,true);await key(travel_key,true)
 var sprint_start:Vector2=own.position
 await create_timer(.5).timeout
 await key(travel_key,false);await key(KEY_SHIFT,false)
 verify((own.position-sprint_start).dot(travel)>120,"running remains responsive with latency")
 var reverse_key:int=KEY_A if travel_key==KEY_D else KEY_D if travel_key==KEY_A else KEY_S if travel_key==KEY_W else KEY_W
 await key(reverse_key,true)
 var reverse_start:Vector2=own.position
 await create_timer(.5).timeout
 await key(reverse_key,false)
 verify((own.position-reverse_start).dot(-travel)>75,"direction changes replay pending inputs correctly")
 await create_timer(.6).timeout
 # Real pointer click on an empty shortcut slot must show selection without a blank panel.
 var empty:=7
 var button:Button=world.hotbar_buttons[empty]
 var motion:=InputEventMouseMotion.new();motion.position=button.get_global_rect().get_center();Input.parse_input_event(motion)
 await process_frame
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=button.get_global_rect().get_center();Input.parse_input_event(down)
 await process_frame
 down=down.duplicate();down.pressed=false;Input.parse_input_event(down)
 await process_frame
 await process_frame
 verify(world.selected_hotbar==empty,"pointer selects shortcut slot 8")
 verify(not world.object_panel.visible,"empty shortcut does not open a blank panel")
 await key(KEY_2,true);await key(KEY_2,false)
 verify(world.selected_hotbar==1,"number 2 selects matching slot")
 # UI-only item fixture; no server mutation or player data.
 var original=world.own_character.slots[0].duplicate(true)
 world.own_character.slots[0]={"item_id":"wood","count":1};world.select_hotbar(0)
 verify(world.object_panel.visible and world.object_rows.get_child_count()>1,"filled shortcut opens item actions")
 verify(world.hotbar_buttons[0].icon!=null,"shortcut icon visible")
 world.own_character.slots[0]=original;world.object_panel.hide()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output_path)
 world.set_process(false)
 while world.moving_request or world.polling:await process_frame
 await world.close_world()
 app.queue_free();await process_frame;await process_frame
 print("RESULT ",checks," checks")
 quit()
