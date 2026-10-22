extends RefCounted
## World-owned monotonic bitset. Local merge is an offline utility, not a network API.
const CELL := 96.0
const RADIUS := 1152.0
var world_id := ""
var extent := 0.0
var width := 0
var bits := PackedByteArray()
var revision := 0
var mask_cache: Image
var last_position := Vector2(-1e9,-1e9)

func configure(id: String, world_extent: float) -> void:
	world_id=id;extent=world_extent;width=ceili(extent/CELL)
	bits.resize(ceili(width*width/8.0));bits.fill(0)
	mask_cache=Image.create(width,width,false,Image.FORMAT_L8)

func explored(p: Vector2) -> bool:
	if not Rect2(Vector2.ZERO,Vector2.ONE*extent).has_point(p):return false
	var c:=Vector2i(p/CELL);var index:=c.y*width+c.x
	return (bits[index>>3] & (1<<(index&7)))!=0

func reveal(p: Vector2, force: bool=false) -> bool:
	if not is_finite(p.x) or not is_finite(p.y) or not Rect2(Vector2.ZERO,Vector2.ONE*extent).has_point(p):return false
	if not force and p.distance_to(last_position)<CELL*.25:return false
	# Never connect teleports with an artificial explored corridor.
	last_position=p
	var lo:=Vector2i(((p-Vector2.ONE*RADIUS)/CELL).floor()).max(Vector2i.ZERO)
	var hi:=Vector2i(((p+Vector2.ONE*RADIUS)/CELL).ceil()).min(Vector2i.ONE*(width-1))
	var changed:=false
	for y in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			if (Vector2(x,y)+Vector2.ONE*.5).distance_to(p/CELL)>RADIUS/CELL:continue
			var index:=y*width+x;var mask:=1<<(index&7)
			if bits[index>>3]&mask:continue
			bits[index>>3]|=mask;changed=true
			mask_cache.set_pixel(x,y,Color.WHITE)
	if changed:revision+=1
	return changed

func serialize() -> Dictionary:
	return {"version":1,"world_id":world_id,"extent":extent,"cell":CELL,"width":width,"bits":Marshalls.raw_to_base64(bits),"sha256":bits.hex_encode().sha256_text()}

func valid(value: Variant) -> bool:
	if not value is Dictionary:return false
	if value.get("version")!=1 or value.get("world_id")!=world_id or value.get("extent")!=extent or value.get("cell")!=CELL or value.get("width")!=width:return false
	if not value.get("bits") is String or value.bits.length()!=4*ceili(bits.size()/3.0):return false
	var decoded:=Marshalls.base64_to_raw(value.bits)
	if decoded.size()!=bits.size() or Marshalls.raw_to_base64(decoded)!=value.bits:return false
	if decoded.hex_encode().sha256_text()!=value.get("sha256"):return false
	var unused:=bits.size()*8-width*width
	if unused>0 and (decoded[-1]>>(8-unused))!=0:return false
	return true

func restore(value: Dictionary) -> bool:
	if not valid(value):return false
	var incoming:=Marshalls.base64_to_raw(value.bits)
	# A network reveal usually changes only a few cells. Preserve the image and
	# update changed bits instead of scanning every map pixel on the main thread.
	for byte_index in incoming.size():
		var difference: int=bits[byte_index]^incoming[byte_index]
		if difference==0:continue
		for bit in 8:
			if difference&(1<<bit):
				var index:=byte_index*8+bit
				mask_cache.set_pixel(index%width,index/width,Color.WHITE if incoming[byte_index]&(1<<bit) else Color.BLACK)
	bits=incoming;revision+=1
	last_position=Vector2(-1e9,-1e9)
	return true

func merge_local(value: Dictionary) -> bool:
	if not valid(value):return false
	var incoming:=Marshalls.base64_to_raw(value.bits)
	var changed:=false
	for i in bits.size():
		var combined:=bits[i]|incoming[i]
		if combined!=bits[i]:bits[i]=combined;changed=true
	if changed:revision+=1;rebuild_mask()
	return true

func rebuild_mask() -> void:
	mask_cache.fill(Color.BLACK)
	for y in width:
		for x in width:
			var i:=y*width+x
			if bits[i>>3]&(1<<(i&7)):mask_cache.set_pixel(x,y,Color.WHITE)

func mask_image() -> Image:
	return mask_cache

func intersects(area: Rect2) -> bool:
	var lo:=Vector2i((area.position/CELL).floor()).max(Vector2i.ZERO)
	var hi:=Vector2i((area.end/CELL).ceil()).min(Vector2i.ONE*(width-1))
	for y in range(lo.y,hi.y+1):
		var start: int=y*width+lo.x
		var stop: int=y*width+hi.x
		# Skip bytes that cannot contain any explored cells.
		for byte_index in range(start>>3,(stop>>3)+1):
			if bits[byte_index]==0:continue
			for i in range(maxi(start,byte_index*8),mini(stop+1,byte_index*8+8)):
				if bits[byte_index]&(1<<(i&7)):return true
	return false
