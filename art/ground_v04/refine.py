from pathlib import Path
p=Path('scripts/ground_decals.gd');s=p.read_text().replace('var generator:','var preview_mode:=0\nvar preview_center:=Vector2.ZERO\nvar generator:',1).replace('\t\tvar width:float=stamp.width','\t\tif preview_mode>0 and (position+stamp.p).distance_to(preview_center)<1350:continue\n\t\tvar width:float=stamp.width');p.write_text(s)
p=Path('scripts/chunk_stream.gd');s=p.read_text().replace('entry.ground.visible=candidate_mode==0 or (Vector2(c)*Gen.CHUNK_PX+Vector2.ONE*Gen.CHUNK_PX*.5).distance_to(generator.spawn)>2100','entry.ground.preview_mode=candidate_mode\n\tentry.ground.preview_center=generator.spawn\n\tentry.ground.queue_redraw()');p.write_text(s)
p=Path('scripts/ground_candidate.gd');s=p.read_text().replace('\tfor prop in props:', '''	# Reject tufts under authored soil patches, with enough margin for the blade width.
	var grass_only:Array[Dictionary]=[]
	for tuft in tufts:
		var soil:=false
		for patch in patches:
			if tuft.p.distance_to(patch.p)<patch.w*.58:soil=true;break
		if not soil:grass_only.append(tuft)
	tufts=grass_only
	for prop in props:''');p.write_text(s)
