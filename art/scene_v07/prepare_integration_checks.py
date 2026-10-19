from pathlib import Path
s=Path('tests/test_scene_cartoon.gd').read_text(encoding='utf-8-sig')
a=s.index(' check(p.animation_player');b=s.index(' var tree:Node2D')
s=s[:a]+''' var art_ok:=true
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
''' +s[b:]
s=s.replace('reports/scene-cartoon-v2.png','reports/scene-v3-after-interaction.png').replace('reports/scene-cartoon-tests.json','reports/scene-v3-integration-tests.json')
s=s.replace('native clips, shift binding, normalized walk/run, actual distance phase, trunk/crown/rock collisions, chop events, drop pickup, released trunk, border, deterministic clearing; no broad performance benchmark','approved art references and canvas sizes, empty legacy stamps, quiet center, trunk/crown/rock collisions, chop/drop/pickup, deterministic clearing; no unrelated regression or performance benchmark')
Path('tests/test_scene_v3_integration.gd').write_text(s,encoding='utf-8')
s=Path('tests/capture_v03_environment.gd').read_text(encoding='utf-8-sig').replace('reports/v03-%s.png','reports/scene-v3-%s.png')
s=s.replace('w.player.automated=true;w.player.set_physics_process(false)','w.player.automated=true;w.player.set_physics_process(false)\n\tw.player.camera.position_smoothing_enabled=false\n\tw.ui.hide()')
s=s.replace('var forest:=Vector2.ZERO','await capture(w,w.generator.spawn+Vector2(640,0),"surface-join")\n\tvar forest:=Vector2.ZERO')
Path('tests/capture_scene_v3.gd').write_text(s,encoding='utf-8')
