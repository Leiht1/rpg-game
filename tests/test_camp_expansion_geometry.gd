extends SceneTree
const Grid=preload("res://scripts/camp_grid.gd")
var manager: RefCounted
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func sample(id: String,enabled: bool) -> Dictionary:
	Engine.set_meta("camp_expansion_preview",enabled)
	var node=preload("res://scripts/camp_building.gd").new();node.manager=manager;node.building_id=id;root.add_child(node)
	var result={"shape":node.shape.shape.size if node.shape.shape else Vector2.ZERO,"shape_position":node.shape.position,"disabled":node.shape.disabled,"polygon":node.leaf.polygon,"children":node.get_child_count(),"body_layer":node.body.collision_layer,"footprint":manager.footprint_rect(manager.states[id])}
	if manager.states[id].layer=="edge":
		result.ends=Grid.ends(manager.states[id]);result.connections=Grid.connections(manager.states,Grid.ends(manager.states[id])[0])
	if manager.states[id].layer=="ground":result.south=node.floor_has_south()
	node.free();return result
func run() -> void:
	manager=load("res://scripts/camp_buildings.gd").new()
	for kind in ["wood_fence","fence_gate","stone_wall","stone_gate","wood_bed","straw_mat","sleeping_bag","wood_floor","stone_path"]:
		for vertical in [false,true]:
			if kind=="sleeping_bag" and vertical:continue
			var row: Dictionary=Grid.snap(Vector2(480,320),manager.definitions[kind].layer=="edge",vertical)
			row.merge({"kind":kind,"layer":manager.definitions[kind].layer,"open":false,"inward":false,"facing":0,"hits":0,"contents":[]})
			manager.states={"fixture":row}
			if row.layer=="ground":
				var next: Dictionary=row.duplicate(true);next.y+=64;next.gy+=1;next.kind="stone_path" if kind=="wood_floor" else "wood_floor";manager.states["neighbor"]=next
			for opened in ([false,true] if manager.definitions[kind].get("door",false) else [false]):
				row.open=opened
				var before:=sample("fixture",false);var after:=sample("fixture",true)
				var ok:=before==after
				checks.append({"name":"%s vertical=%s open=%s geometry, joints, collider, sleep footprint unchanged"%[kind,vertical,opened],"pass":ok})
				if not ok:push_error(checks.back().name)
	var failed:=checks.filter(func(v):return not v.pass).size()
	var output:=FileAccess.open("res://reports/camp-expansion-v2/geometry.json",FileAccess.WRITE);output.store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"\t"));output.close()
	print("EXPANSION GEOMETRY: ",checks.size()," checks, ",failed," failed")
	quit(0 if failed==0 else 1)
