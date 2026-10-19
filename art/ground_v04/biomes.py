from pathlib import Path
p=Path('scripts/chunk_stream.gd');s=p.read_text().replace('var preview_enabled := false','var preview_enabled := false\nvar preview_center:=Vector2.ZERO').replace('layer.configure(generator,coord,packet.props)','layer.configure(generator,coord,packet.props,preview_center)').replace('shared_material.set_shader_parameter("preview_center",generator.spawn)','shared_material.set_shader_parameter("preview_center",preview_center)').replace('entry.ground.preview_center=generator.spawn','entry.ground.preview_center=preview_center').replace('prop.position.distance_to(generator.spawn)<1350','prop.position.distance_to(preview_center)<1350');s+='''
func move_preview_center(p:Vector2)->void:
	preview_center=p
	for c in loaded:
		var entry:Dictionary=loaded[c]
		entry.candidate.queue_free()
		var layer=load("res://scripts/ground_candidate.gd").new()
		layer.z_index=-1
		layer.configure(generator,c,generator.props_for_chunk(c),p)
		add_child(layer)
		entry.candidate=layer
		for prop in entry.props:
			prop.candidate_mode=0
			prop.visible=true
			prop.queue_redraw()
	set_candidate(candidate_mode)
''';p.write_text(s)
p=Path('scripts/ground_candidate.gd');s=p.read_text().replace('props:Array)->void:', 'props:Array,center:Vector2=Vector2.ZERO)->void:').replace('\tgen=g','\tgen=g\n\tif center==Vector2.ZERO:center=g.spawn',1).replace('p.distance_to(g.spawn)','p.distance_to(center)').replace('prop.position.distance_to(g.spawn)','prop.position.distance_to(center)');p.write_text(s)
p=Path('scripts/ground_preview.gd');s=p.read_text('utf-8');s=s.replace('stream.preview_enabled=true','stream.preview_enabled=true\n\tstream.preview_center=generator.spawn');s=s.replace('· 0 返回出生点','· 0 出生点 · 4 森林 / 5 山地 / 6 水岸');s=s.replace('player.position=generator.spawn','stream.move_preview_center(generator.spawn)\n\t\t\tplayer.position=generator.spawn');s+='''
		if event.physical_keycode in [KEY_4,KEY_5,KEY_6]:
			var p:=generator.spawn
			if event.physical_keycode==KEY_6:
				p=Vector2(generator.river_x(p.y)-240,p.y)
			else:
				var found:=false
				for radius in [800,1500,2500,3500,5000]:
					for i in 32:
						var q:Vector2=generator.spawn+Vector2.from_angle(i*TAU/32)*radius
						var v:=generator.sample(q)
						if v.z<.005 and ((event.physical_keycode==KEY_4 and v.x>.65) or (event.physical_keycode==KEY_5 and v.y>.55)):
							p=q;found=true;break
					if found:break
			stream.move_preview_center(p)
			player.position=p
			player.camera.reset_smoothing()
			stream.update_target(p)
''';p.write_text(s,encoding='utf-8')
