extends RefCounted
## Read-only coastal clue contract. No special terrain or precise ruin is generated.
var cached_key:=""
var cached: Dictionary={}
var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/coastal_route_hint.json"))
func resolve(s: Node) -> Dictionary:
	if s.chapter.mine.state.site.is_empty():return {}
	var gen=s.world.generator;var start: Vector2=s.chapter.mine.at()
	var key: String="coastal-2:"+str(s.world.world_seed)+":"+str(gen.extent)+":"+str(start)
	if key==cached_key:return cached.duplicate(true)
	var forward:=Vector2(config.paper_forward[0],config.paper_forward[1]).normalized()
	var requirements: Dictionary={"special_terrain":config.terrain,"near_outer_sea":true,"connected_to_ordinary_rock":true,"different_rock_region_from_mine":true,"independent_special_terrain":true,"coast_max_distance":config.coast_max_distance,"landmarks":config.landmarks.duplicate()}
	cached={"version":2,"seed":s.world.world_seed,"precision":"feature_contract","target_generated":false,"direction_resolved":false,"origin":{"x":start.x,"y":start.y},"terrain":config.terrain,"requirements":requirements,"landmarks":requirements.landmarks.duplicate(),"paper_forward":{"x":forward.x,"y":forward.y}}
	cached_key=key
	var ecology: Variant=gen.get("ecology_field");var field: Variant=gen.get("field")
	if not ecology is Image or not field is Image:return cached.duplicate(true)
	var grid: int=ecology.get_width();var step: float=float(gen.extent)/float(grid-1)
	var labels:=PackedInt32Array();labels.resize(grid*grid);labels.fill(-1)
	for y in grid:
		for x in grid:
			var weight: Color=ecology.get_pixel(x,y)
			if weight.a<maxf(weight.r,maxf(weight.g,weight.b)) or field.get_pixel(x,y).a<32:continue
			var at:=Vector2(x,y)*step
			if gen.sample(at).z<=.12:labels[y*grid+x]=-2
	var counts: Array[int]=[]
	for index in labels.size():
		if labels[index]!=-2:continue
		var id: int=counts.size();var queue:=PackedInt32Array([index]);labels[index]=id;var head:=0
		while head<queue.size():
			var cell: int=queue[head];head+=1;var x: int=cell%grid;var y: int=cell/grid
			for offset in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
				var nx: int=x+offset.x;var ny: int=y+offset.y
				if nx<0 or ny<0 or nx>=grid or ny>=grid:continue
				var next: int=ny*grid+nx
				if labels[next]==-2:labels[next]=id;queue.append(next)
		counts.append(queue.size())
	var mine_region:=-1;var nearest:=INF
	var source_cell:=Vector2i(roundi(start.x/step),roundi(start.y/step))
	for y in range(maxi(0,source_cell.y-3),mini(grid,source_cell.y+4)):
		for x in range(maxi(0,source_cell.x-3),mini(grid,source_cell.x+4)):
			if labels[y*grid+x]<0:continue
			var distance: float=start.distance_squared_to(Vector2(x,y)*step)
			if distance<nearest:nearest=distance;mine_region=labels[y*grid+x]
	if mine_region<0:return cached.duplicate(true)
	var best:=INF;var selected: Dictionary={}
	var placements: Array=[]
	for index in labels.size():
		var region: int=labels[index]
		if region<0 or region==mine_region or counts[region]<int(config.min_region_cells):continue
		var x: int=index%grid;var y: int=index/grid;var coast: float=field.get_pixel(x,y).a
		if coast<float(config.coast_min_distance) or coast>float(config.coast_max_distance):continue
		var at:=Vector2(x,y)*step
		if at.distance_squared_to(start)<pow(float(config.min_distance_from_mine),2) or not gen.can_walk(at,24):continue
		placements.append({"x":at.x,"y":at.y,"region":region})
		var score: float=start.distance_squared_to(at)+pow(coast-320,2)*.1
		if score<best:best=score;selected={"at":at,"region":region,"coast":coast}
	placements.sort_custom(func(a,b):return start.distance_squared_to(Vector2(a.x,a.y))<start.distance_squared_to(Vector2(b.x,b.y)))
	cached.placement_candidates=placements
	if selected.is_empty():return cached.duplicate(true)
	var bearing: Vector2=(selected.at-start).normalized()
	var names: Array=["东","东南","南","西南","西","西北","北","东北"]
	cached.merge({"precision":"coastal_rock_region_sector","direction_resolved":true,"bearing":{"x":bearing.x,"y":bearing.y},"bearing_name":names[posmod(int(round(bearing.angle()/(PI/4))),8)],"north_rotation":forward.angle()-bearing.angle(),"source_rock_region":mine_region,"connected_rock_region":selected.region,"region_grid":grid,"search_area":{"center":{"x":selected.at.x,"y":selected.at.y},"radius":maxf(384,step*3)},"outer_coast_distance":selected.coast},true)
	return cached.duplicate(true)
