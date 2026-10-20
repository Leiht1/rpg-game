extends "res://prototypes/view-v01/formal_v03.gd"
# Candidate only. Keep lake centers/count thinning; redraw irregular shoreline in world space.
const CANDIDATE_VERSION="windrest-view-0.2.0"
var before:bool=false
var original_lake_count:int=0
func _init(seed_value:int=271828,size_cells:int=1024)->void:
	super._init(seed_value,size_cells)
	before=Engine.get_meta("view_before",false)
	original_lake_count=lakes.size()
	if before:return
	var kept:Array[Vector4]=[]
	lake_bins.clear()
	for lake in lakes:
		if random_at(roundi(lake.x),roundi(lake.y),934)>=.5:continue
		kept.append(lake)
		var point:=Vector2(lake.x,lake.y)
		var lo:=Vector2i((point-Vector2(lake.z,lake.w)*1.9)/2048)
		var hi:=Vector2i((point+Vector2(lake.z,lake.w)*1.9)/2048)
		for y in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				var key:=Vector2i(x,y)
				if not lake_bins.has(key):lake_bins[key]=[]
				lake_bins[key].append(lake)
	lakes=kept
func sample(p:Vector2,spawn_clearance:bool=true)->Vector4:
	if before:return super.sample(p,spawn_clearance)
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
	return field
func props_for_chunk(coord:Vector2i)->Array[Dictionary]:
	var old:=super.props_for_chunk(coord)
	if before:return old
	var result:Array[Dictionary]=[]
	for entry in old:
		if not str(entry.id).begins_with("clearing:"):result.append(entry)
	# Replace historical 480-radius exclusion/sample ring with the same ordinary grid,
	# except a small irregular safe footprint. No special ground or decoration layout.
	var first:=Vector2i(Vector2(coord)*CHUNK_PX/PROP_STEP)
	for y in range(first.y,first.y+CHUNK_PX/PROP_STEP):
		for x in range(first.x,first.x+CHUNK_PX/PROP_STEP):
			var point:=Vector2((x+.18+random_at(x,y,1)*.64)*PROP_STEP,(y+.18+random_at(x,y,2)*.64)*PROP_STEP)
			var distance:=point.distance_to(spawn)
			if distance>=480 or distance<105+random_at(x,y,910)*75:continue
			var v:=sample(point)
			if v.z>.03:continue
			var roll:=random_at(x,y,3)
			var cluster:=smoothstep(-.4,.35,detail.get_noise_2dv(point))
			var kind:=-1
			if roll<(.025+v.x*.65)*cluster:kind=0 if random_at(x,y,7)<.7 else 1
			elif roll>.72 and roll<.75+v.y*.22*cluster:kind=2 if random_at(x,y,7)<.7 else 3
			elif roll>.96:kind=4+mini(2,int(random_at(x,y,8)*3))
			if kind>=0:result.append({"position":point,"kind":kind,"scale":.8+random_at(x,y,5)*.35,"id":"%d:%d"%[x,y]})
	return result
