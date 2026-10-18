from pathlib import Path
p=Path('scripts/sleep_head_cover.gd');s=p.read_text(encoding='utf8')
s=s.replace('var anchor := Vector2(0,-69) if vertical else Vector2(-25,-31 if source=="wood_bed" else -15)','var anchor := Vector2(0,-67) if vertical else Vector2(-34,-31 if source=="wood_bed" else -8)')
s=s.replace('if source=="straw_mat": anchor.y=-61 if vertical else -15','if source=="straw_mat": anchor=Vector2(0,-60) if vertical else Vector2(-35,-8)')
s=s.replace('if source=="forced": anchor=Vector2(-25,-15)','if source=="sleeping_bag": anchor=Vector2(-36,-8)')
a=s.index('\tvar kind :=');b=s.index('\t# All face/head layers',a)
s=s[:a]+'''	var name_value := source+("-vertical" if vertical else "")
	var path := "res://assets/sleep/occupied-v5/"+name_value+".png"
	if not ResourceLoader.exists(path): path="res://prototypes/sleep-occupied-v5/final/"+name_value+".png" if Engine.get_meta("sleep_preview",false) and source!="forced" else ""
	if path.is_empty():
		group.hide();player.character.show();return Vector2(0,-60)
	cover.show();cover.texture=load(path);cover.region_enabled=false;cover.centered=true
	cover.position=Vector2(0,-36 if source=="wood_bed" else -28) if vertical else Vector2(0,-24 if source=="wood_bed" else -8)
	cover.scale=Vector2.ONE*.25
	group.move_child(cover,0)
	if quilt_material==null:
		quilt_material=ShaderMaterial.new();quilt_material.shader=preload("res://scripts/sleep_still.gdshader")
	cover.material=quilt_material
	quilt_material.set_shader_parameter("chest",Vector2(.5,.47) if vertical else Vector2(.55,.47))
	quilt_material.set_shader_parameter("envelope",Vector2(.30,.17) if vertical else Vector2(.23,.28))
	quilt_material.set_shader_parameter("breath",sin(float(session.clock)*TAU/3.6))
	# Replace only the occupied drawing; the original collider/state stays live.
	var manager=player.get_parent().item_service.builds
	if manager.visuals.has(session.id) and is_instance_valid(manager.visuals[session.id]): manager.visuals[session.id].hide()
'''+s[b:]
p.write_text(s,encoding='utf8')
p=Path('scripts/sleep_controller.gd');s=p.read_text(encoding='utf8')
s=s.replace('\tif not row.is_empty() and not service.builds.states.has(s.id): service.builds.refresh_around(row)','''	if not row.is_empty() and not service.builds.states.has(s.id): service.builds.refresh_around(row)
	elif service.builds.visuals.has(s.id) and is_instance_valid(service.builds.visuals[s.id]): service.builds.visuals[s.id].show()''')
p.write_text(s,encoding='utf8')
p=Path('tests/test_sleep_cover_v4.gd');s=p.read_text(encoding='utf8').replace('res://reports/sleep-cover-v4/','res://reports/sleep-occupied-v5/').replace('SLEEP HEAD COVER V4','SLEEP OCCUPIED V5')
s=s.replace('"body fully hidden and only current head plus quilt displayed "+label','"body fully hidden and only current head plus rounded occupied prop displayed "+label')
s=s.replace('\t\tvar fixed: Vector2=w.player.position;', '''		check(not b.visuals[id].visible and not quilt.region_enabled and quilt.texture.resource_path.begins_with("res://prototypes/sleep-occupied-v5/"),"complete painted occupied silhouette replaces flat base without crop "+label)
		var fixed: Vector2=w.player.position;''')
s=s.replace('\t\tif kind!="sleeping_bag":\n\t\t\tcheck(s.sleep.start(id)', '\t\tif kind!="sleeping_bag":\n\t\t\tcheck(b.visuals[id].visible,"empty facility drawing restored on wake "+label)\n\t\t\tcheck(s.sleep.start(id)')
Path('tests/test_sleep_occupied_v5.gd').write_text(s,encoding='utf8')
