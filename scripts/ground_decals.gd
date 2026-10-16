extends Node2D
## One canvas per chunk; all decals share one atlas and stable world coordinates.
var preview_mode:=0
var preview_center:=Vector2.ZERO
var generator: WildGenerator
var coord := Vector2i.ZERO
var atlas: Texture2D
var stamps: Array[Dictionary]=[]
const STEP := 192
const REGIONS := [Rect2(0,0,512,512),Rect2(512,0,512,512),Rect2(1024,0,512,512),Rect2(0,512,512,512),Rect2(512,512,512,512),Rect2(1024,512,512,512)]

func configure(chunk:Vector2i,source:Texture2D,entries:Array[Dictionary])->void:
	coord=chunk
	atlas=source
	position=Vector2(coord)*WildGenerator.CHUNK_PX
	stamps=entries
	queue_redraw()

static func plan(gen:WildGenerator,chunk:Vector2i,props:Array)->Array[Dictionary]:
	var origin:=Vector2(chunk)*WildGenerator.CHUNK_PX
	var result:Array[Dictionary]=[]
	var first:=Vector2i(origin/STEP)
	for y in range(first.y,first.y+6):
		for x in range(first.x,first.x+6):
			var roll:=gen.random_at(x,y,451)
			var p:Vector2=Vector2(x+.18+gen.random_at(x,y,452)*.64,y+.18+gen.random_at(x,y,453)*.64)*STEP
			var v:=gen.sample(p)
			if v.z>.005:continue
			if roll<.34 and v.x<.4 and v.y<.35:continue
			var kind:=0 if roll<.5 else 1
			var width:=240.0+gen.random_at(x,y,454)*130.0
			if v.x>.40 and roll<.65:kind=2;width=220+roll*110
			if v.y>.35 and roll<.65:kind=5;width=210+roll*90
			if roll>.91:kind=3;width=160+roll*60
			if roll>.965 and v.y<.25:kind=4;width=170+roll*45
			# Decorative puddles are shallow ground art, never a new collision terrain.
			if not dry_footprint(gen,p,width*.55):continue
			result.append({"p":p-origin,"kind":kind,"width":width,"flip":gen.random_at(x,y,455)>.5,"alpha":.82 if kind<2 else .96})
	for entry in props:
		if entry.kind>3:continue
		var variant:=gen.random_at(roundi(entry.position.x),roundi(entry.position.y),457)
		if entry.kind<2 and variant<.25:continue
		var p:Vector2=entry.position
		var width:float=(120.0+variant*75.0 if entry.kind<2 else 115.0+variant*40.0)*entry.scale
		if dry_footprint(gen,p,width*.55):
			result.append({"p":p-origin+Vector2(0,8),"kind":(2 if variant>.52 else 1) if entry.kind<2 else 5,"width":width,"flip":gen.random_at(roundi(p.x),roundi(p.y),456)>.5,"alpha":.70 if entry.kind<2 else .86})
	# One visible shallow puddle in the existing demonstration clearing.
	var puddle:=gen.spawn+Vector2(20,255)
	if Vector2i(floori(puddle.x/WildGenerator.CHUNK_PX),floori(puddle.y/WildGenerator.CHUNK_PX))==chunk and dry_footprint(gen,puddle,100):
		result.append({"p":puddle-origin,"kind":4,"width":220.0,"flip":false,"alpha":1.0})
	return result

static func dry_footprint(gen:WildGenerator,p:Vector2,radius:float)->bool:
	for offset in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius),Vector2(radius*.71,radius*.71),Vector2(-radius*.71,radius*.71),Vector2(radius*.71,-radius*.71),Vector2(-radius*.71,-radius*.71)]:
		if gen.sample(p+offset).z>.005:return false
	return true

func _draw()->void:
	if atlas==null:return
	for stamp in stamps:
		if preview_mode>0 and (position+stamp.p).distance_to(preview_center)<1350:continue
		var width:float=stamp.width
		draw_set_transform(stamp.p,0,Vector2(-1 if stamp.flip else 1,1))
		var dest:=Rect2(-Vector2.ONE*width*.5,Vector2.ONE*width)
		draw_texture_rect_region(atlas,dest,REGIONS[stamp.kind],Color(1,1,1,stamp.alpha))
		draw_set_transform(Vector2.ZERO)
