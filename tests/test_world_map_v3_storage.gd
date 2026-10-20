extends SceneTree
var checks: Array=[]
var metrics: Dictionary={}
func _initialize() -> void:call_deferred('run')
func check(ok: bool,name: String) -> void:
	checks.append({'pass':ok,'name':name})
	if not ok:push_error(name)
func run() -> void:
	var base=load('res://scripts/world.gd').new()
	var path:='res://reports/world-map-v3/identity-save.json'
	for cells in [1024,1536]:
		var identity:={'generator':base.Gen.VERSION,'seed':81273,'map_cells':cells}
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(identity))
		base.persistent_world=true;base.load_world_identity(path)
		check(base.map_cells==cells and base.world_seed==81273,'read fixed identity %d'%cells)
		var id: String=base.world_id
		base.save_world_identity(path)
		check(base.last_identity_saved,'atomic identity saved %d'%cells)
		base.load_world_identity(path)
		check(base.persistent_world and base.world_id==id and base.map_cells==cells,'identity roundtrip %d'%cells)
	for bad in [0,1537,1024.5,'1536']:
		var text:=JSON.stringify({'generator':base.Gen.VERSION,'seed':81273,'map_cells':bad})
		FileAccess.open(path,FileAccess.WRITE).store_string(text)
		base.persistent_world=true;base.load_world_identity(path);base.save_world_identity(path)
		check(not base.persistent_world and FileAccess.get_file_as_string(path)==text,'invalid identity protected '+str(bad))
	base.persistent_world=true
	base.save_world_identity('res://reports/world-map-v3/missing-directory/identity.json')
	check(not base.last_identity_saved,'identity failure reported to caller')
	var creator=load('res://scripts/character_creation.gd').new()
	var look: Dictionary=preload('res://scripts/character_catalog.gd').default_look()
	for cells in [1024,1536]:
		var value:={'seed':123,'map_cells':cells,'equipment':{},'player_state_owner':'player','character_session':{'version':1,'seed':123,'map_cells':cells,'active_character_id':'player','world_id':'world','characters':{'player':{'world_id':'world','appearance':look,'test_outfit_granted':true,'outfit_id':''}}}}
		check(creator.valid_session(JSON.parse_string(JSON.stringify(value))),'creation accepts saved size %d'%cells)
	# Create a heavily explored synthetic WORLD, independently from gameplay saves.
	var ex=preload('res://scripts/world_exploration.gd').new();ex.configure('synthetic-shared-world',73728)
	var start:=Time.get_ticks_usec()
	for i in 2500:ex.reveal(Vector2((i*379)%73728,(i*919)%73728))
	metrics.reveal_2500_ms=(Time.get_ticks_usec()-start)/1000.
	start=Time.get_ticks_usec();var encoded:=JSON.stringify(ex.serialize());metrics.serialize_ms=(Time.get_ticks_usec()-start)/1000.;metrics.json_bytes=encoded.to_utf8_buffer().size()
	var restore=preload('res://scripts/world_exploration.gd').new();restore.configure('synthetic-shared-world',73728)
	start=Time.get_ticks_usec();check(restore.restore(JSON.parse_string(encoded)),'large exploration JSON restore');metrics.restore_ms=(Time.get_ticks_usec()-start)/1000.
	check(restore.bits==ex.bits,'large exploration exact bits')
	var length:=encoded.length()
	for i in 100:ex.merge_local(restore.serialize())
	check(JSON.stringify(ex.serialize()).length()==length,'100 union merges constant save size')
	var far:=Vector2(70000,70000)
	check(not ex.reveal(Vector2.INF) and not ex.reveal(Vector2(-100,-100)),'illegal explorer positions rejected')
	for n in [base.object_root,base.ui,base.title,base.hint,base.debug_label,base.loading_cover,base.loading_label]:n.free()
	base.free()
	for n in [creator.canvas,creator.screen,creator.panel,creator.status,creator.enter,creator.hair,creator.gender,creator.view]:
		if is_instance_valid(n):n.free()
	creator.free()
	var failed:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open('res://reports/world-map-v3/storage.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failed':failed,'metrics':metrics},'  '))
	print('STORAGE ',checks.size(),' checks ',failed,' failures ',JSON.stringify(metrics));quit(0 if failed==0 else 1)
