extends RefCounted
## Independent construction lattice: terrain CELL=48; actor working reach=62–90.
## A 96x64 world footprint leaves a usable single-cell passage for the actor.
## Origin is global zero, never chunk/camera/spawn relative.
const STEP := Vector2(96,64)
static func snap(at: Vector2, edge: bool, vertical: bool = false) -> Dictionary:
	var cell := Vector2i(floori(at.x/STEP.x),floori(at.y/STEP.y))
	if edge:
		if vertical: cell.x=roundi(at.x/STEP.x)
		else: cell.y=roundi(at.y/STEP.y)
	var center := Vector2(cell)*STEP
	center+=Vector2(0,STEP.y*.5) if edge and vertical else Vector2(STEP.x*.5,0) if edge else STEP*.5
	return {"gx":cell.x,"gy":cell.y,"vertical":vertical,"x":center.x,"y":center.y}
static func key(row: Dictionary, edge: bool) -> String:
	return ("v" if row.vertical else "h")+":%d:%d"%[row.gx,row.gy] if edge else "g:%d:%d"%[row.gx,row.gy]
static func ends(row: Dictionary) -> Array[Vector2i]:
	var a := Vector2i(int(row.gx),int(row.gy))
	return [a,a+(Vector2i.DOWN if row.vertical else Vector2i.RIGHT)]
static func connections(objects: Dictionary, vertex: Vector2i) -> int:
	var mask := 0
	for row in objects.values():
		if row.get("layer")!="edge": continue
		var pair := ends(row)
		if pair[0]==vertex: mask |= 4 if row.vertical else 2
		if pair[1]==vertex: mask |= 1 if row.vertical else 8
	return mask

static func junction(objects: Dictionary, vertex: Vector2i) -> Dictionary:
	var owner := ""
	var stone := false
	for id in objects:
		var row: Dictionary=objects[id]
		if row.get("layer")!="edge" or not ends(row).has(vertex): continue
		var is_stone := str(row.kind).begins_with("stone")
		if owner.is_empty() or (is_stone and not stone) or (is_stone==stone and str(id)<owner): owner=str(id);stone=is_stone
	return {"owner":owner,"stone":stone}

static func enclosed(start: Vector2i, edges: Dictionary) -> bool:
	# A bounded flood fill distinguishes a closed pen from its open exterior.
	# Large/open areas use the explicit side selected by the player.
	var queue: Array[Vector2i]=[start]
	var seen := {start:true}
	var head := 0
	while head<queue.size():
		var cell: Vector2i=queue[head];head+=1
		var neighbors: Array[Vector2i]=[cell+Vector2i.LEFT,cell+Vector2i.RIGHT,cell+Vector2i.UP,cell+Vector2i.DOWN]
		var borders := ["v:%d:%d"%[cell.x,cell.y],"v:%d:%d"%[cell.x+1,cell.y],"h:%d:%d"%[cell.x,cell.y],"h:%d:%d"%[cell.x,cell.y+1]]
		for i in 4:
			if edges.has(borders[i]) or seen.has(neighbors[i]): continue
			seen[neighbors[i]]=true;queue.append(neighbors[i])
			if seen.size()>1024: return false
	return true

static func swing(objects: Dictionary, row: Dictionary) -> int:
	var edges := {}
	for r in objects.values():
		if r.get("layer")=="edge": edges[key(r,true)]=true
	var c := Vector2i(int(row.gx),int(row.gy))
	var positive := c+Vector2i.LEFT if row.vertical else c
	var negative := c if row.vertical else c+Vector2i.UP
	var plus_inside := enclosed(positive,edges)
	var minus_inside := enclosed(negative,edges)
	var normal := -1 if minus_inside and not plus_inside else 1
	return normal*(1 if row.inward else -1)

# Optional persisted alternate hinge; missing in older snapshots means original endpoint.
static func gate_hinge(row: Dictionary) -> Vector2:
	var sign_value := -1.0 if int(row.get("hinge_end",0))==0 else 1.0
	return Vector2(0,32*sign_value) if row.vertical else Vector2(48*sign_value,0)

static func gate_base(row: Dictionary) -> float:
	return (PI*.5 if row.vertical else 0.0)+(PI if int(row.get("hinge_end",0))==1 else 0.0)
