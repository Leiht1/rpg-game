from pathlib import Path
import shutil
p=Path('prototypes/view-v01');b=p/'lake-v01-archive';b.mkdir(exist_ok=True)
for f in ['generator.gd','terrain.gdshader','lake-after.png','checks.json']:
 if not (b/f).exists():shutil.copy2(p/f,b/f)
s=(p/'generator.gd').read_text(encoding='utf-8').replace('windrest-view-0.1.0','windrest-view-0.2.0').replace('# Candidate only. Coordinate-addressed thinning preserves every retained lake\'s geometry.','# Candidate only. Keep lake centers/count thinning; redraw irregular shoreline in world space.')
s=s.replace('Vector2(lake.z,lake.w)*1.3','Vector2(lake.z,lake.w)*1.9')
s=s.replace('return super.sample(p,spawn_clearance if before else false)','''if before:return super.sample(p,spawn_clearance)
	var field:=super.sample(p,false)
	var q:=p+Vector2(warp.get_noise_2d(p.x,p.y),warp.get_noise_2d(p.y+1200,p.x))*240
	var water:=0.0
	for lake in lake_bins.get(Vector2i(q/2048),[]):
		var rel:Vector2=(q-Vector2(lake.x,lake.y))/Vector2(lake.z,lake.w)
		var angle:=atan2(rel.y,rel.x)
		var phase_value:=random_at(roundi(lake.x),roundi(lake.y),951)*TAU
		# Unequal broad lobes, a pronounced inlet and small bank breaks, not an ellipse.
		var radius:=.93+.19*sin(angle*3.0+phase_value)+.13*sin(angle*5.0-phase_value*.73)+.055*sin(angle*9.0+phase_value*1.6)
		var bay_angle:=angle_difference(angle,phase_value)
		radius-=.25*exp(-bay_angle*bay_angle/.19)
		var signed_distance:float=(rel.length()-radius)*minf(lake.z,lake.w)
		# World-unit shore widths, independent of overall lake size.
		water=maxf(water,1.0-smoothstep(-65.0,45.0,signed_distance))
	field.z=water
	return field''')
(p/'generator.gd').write_text(s,encoding='utf-8')
s=(p/'terrain.gdshader').read_text(encoding='utf-8');i=s.index(' // Existing horizontal');j=s.index(' vec2 cell=',i)
s=s[:i]+''' // A horizontal water plane bounded by the new world-space natural contour.
 // Look 14 world units north: the far bank hides a short strip of water below it.
 float up=texture(TEXTURE,UV-vec2(0.,TEXTURE_PIXEL_SIZE.y*1.75)).a;
 float down=texture(TEXTURE,UV+vec2(0.,TEXTURE_PIXEL_SIZE.y*1.75)).a;
 float far_facing=smoothstep(.005,.075,down-up);
 float near_facing=smoothstep(.005,.075,up-down);
 float patch=.5+.5*sin(p.x*.014+sin(p.y*.021)*1.8);
 float bank_height=mix(5.,14.,patch)*far_facing;
 float water_mask=texture(TEXTURE,UV-vec2(0.,TEXTURE_PIXEL_SIZE.y*bank_height/8.)).a;
 vec3 sand=mix(shore,vec3(.65,.59,.43),.12);
 float beach=smoothstep(.055,.22,w.a);
 base=mix(base,sand,beach);
 // Upper dry lip, visible south-facing soil, then tight contact at the water foot.
 float slope=smoothstep(.30,.41,w.a)*(1.-smoothstep(.43,.53,water_mask));
 vec3 soil=mix(sand*.74,vec3(.46,.41,.29),.26);
 base=mix(base,soil,slope*far_facing*(.70+.20*patch));
 float lip=smoothstep(.22,.28,w.a)*(1.-smoothstep(.30,.34,w.a));
 base=mix(base,sand*1.10,lip*far_facing*.52);
 float contact=smoothstep(.40,.46,water_mask)*(1.-smoothstep(.48,.54,water_mask));
 base=mix(base,soil*.78,contact*far_facing*.70);
 // Broad shallow shelves vary in width, rather than concentric colored rings.
 float shelf_depth=smoothstep(.46,.91,water_mask+sin(p.x*.009+p.y*.005)*.065);
 vec3 bottom_tex=sample_ground(shore_tex,p+vec2(27.,19.));
 vec3 shallow=mix(vec3(.44,.67,.63),bottom_tex*vec3(.85,1.02,.94),.47);
 vec3 deep=vec3(.22,.47,.54);
 vec3 water=mix(shallow,deep,shelf_depth);
 float near_lip=smoothstep(.36,.43,w.a)*(1.-smoothstep(.46,.50,w.a));
 // Near bank is a thin overlapping edge, not a visible vertical wall.
 base=mix(base,sand*.80,near_lip*near_facing*.45);
'''+s[j:]
s=s.replace(' // Short low bank and thin damp contact edge, never a continuous cliff ring.\n float edge=smoothstep(.29,.32,w.a)*(1.-smoothstep(.34,.365,w.a));\n base=mix(base,sand*.72,edge*far_bank*.28*bank_patch);\n base=mix(base,water,smoothstep(.355,.435,w.a));',' base=mix(base,water,smoothstep(.47,.53,water_mask));')
(p/'terrain.gdshader').write_text(s,encoding='utf-8')
# Shore outline changed: choose a stable full-lake review camera and ground anchor.
s=(p/'preview.gd').read_text(encoding='utf-8');s=s.replace('point=Vector2(lake.x,lake.y-lake.w*.95)','point=Vector2(lake.x,lake.y-lake.w*1.65)');(p/'preview.gd').write_text(s,encoding='utf-8')
print('candidate shoreline and directional bank updated')
