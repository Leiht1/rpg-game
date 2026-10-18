extends RefCounted
## Visual only; no mutation of generator layout or RNG. Eight-unit world grid,
## three-sample apron matches terrain. Neighbour objects are queried independently
## of loaded chunks, so border masks do not depend on worker completion order.
static func build(gen:WildGenerator,coord:Vector2i,removed:Dictionary)->Image:
	var size:=WildGenerator.TEX_RES+6
	var mask:=Image.create(size,size,false,Image.FORMAT_R8)
	var origin:=Vector2(coord)*WildGenerator.CHUNK_PX-Vector2.ONE*24.
	for cy in range(coord.y-1,coord.y+2):
		for cx in range(coord.x-1,coord.x+2):
			for entry in gen.props_for_chunk(Vector2i(cx,cy)):
				if entry.kind>=4 or removed.has(entry.id):continue
				var p:Vector2=entry.position
				var lo:=Vector2i(((p-Vector2.ONE*100.-origin)/8.).floor()).max(Vector2i.ZERO)
				var hi:=Vector2i(((p+Vector2.ONE*100.-origin)/8.).ceil()).min(Vector2i.ONE*(size-1))
				for y in range(lo.y,hi.y+1):
					for x in range(lo.x,hi.x+1):
						var value:=1.-smoothstep(22.,100.,(origin+Vector2(x,y)*8.).distance_to(p))
						if value>mask.get_pixel(x,y).r:mask.set_pixel(x,y,Color(value,0,0))
	return mask
