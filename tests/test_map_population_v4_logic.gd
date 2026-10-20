extends SceneTree
const OUT:='res://reports/map-cache-population-v4/'
var checks: Array=[]
var stats: Dictionary={}
func _initialize() -> void:call_deferred('run')
func check(ok: bool,label: String) -> void:
	checks.append({'name':label,'pass':ok})
	if not ok:push_error(label)
func baseline(file: String) -> GDScript:
	var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(OUT+file+'.before.txt')
	check(script.reload()==OK,'compile pre-task baseline '+file)
	return script
func run() -> void:
	var Gen=preload('res://scripts/world_generator.gd')
	var Pop=preload('res://scripts/fishing_population.gd')
	var old_script:=baseline('fishing_population.gd')
	var cases: Array=[]
	for pair in [[81273,1536],[271828,1536],[902106,1536],[81273,1024]]:
		var gen=Gen.new(pair[0],pair[1]);var pop=Pop.new();pop.configure(gen)
		var fresh_count: int=pop.spots.size()
		var limit:=56 if pair[1]>1024 else 40
		check(fresh_count==limit,"sample seeds reach doubled school count "+str(pair))
		check(pop.max_schools==limit and pop.spots.size()<=limit,'global fish limit '+str(pair))
		check(pop.valid(JSON.parse_string(JSON.stringify(pop.serialize()))),'new fish JSON roundtrip '+str(pair))
		var lakes:={};var coast:=0
		for spot in pop.spots:
			check(gen.can_walk(spot.stand,20),'fish dry shore '+spot.id+' '+str(pair))
			if spot.lake>=0:lakes[spot.lake]=int(lakes.get(spot.lake,0))+1
			else:coast+=1
		check(lakes.values().all(func(n):return n<=6),'lake cap 6 '+str(pair))
		check(coast>0,'ocean schools retained '+str(pair))
		var old=old_script.new();old.configure(gen)
		var legacy: Dictionary=old.serialize()
		legacy.schools[0].remaining=0;legacy.schools[0].respawn_minutes=3600.
		legacy.schools[1].remaining=2
		check(pop.valid(legacy),'old population accepted '+str(pair))
		pop.restore(legacy)
		var found:={}
		for row in pop.serialize().schools:found[row.id]=row
		check(legacy.schools.all(func(row):return found.has(row.id) and found[row.id].remaining==row.remaining and found[row.id].respawn_minutes==row.respawn_minutes),'migration preserves every fish remaining/deadline '+str(pair))
		check(pop.spots.size()>=old.spots.size() and pop.spots.size()<=limit,'migration adds only bounded extra schools '+str(pair))
		var upgraded: Dictionary=pop.serialize();pop.restore(JSON.parse_string(JSON.stringify(upgraded)))
		check(JSON.stringify(pop.serialize())==JSON.stringify(upgraded),'revision prevents repeat fish top-up '+str(pair))
		check(pop.valid(pop.serialize()),'migrated spacing/IDs/lake caps valid '+str(pair))
		var invalid: Dictionary=pop.serialize();invalid.population_revision=3
		check(not pop.valid(invalid),'unknown fish revision rejected '+str(pair))
		cases.append({'seed':pair[0],'cells':pair[1],'fresh_schools':fresh_count,'actual_after_migration':pop.spots.size(),'max_schools':limit,'lake_counts':lakes,'coast':coast,'old_schools':old.spots.size()})
		# Isolate one depleted slot; retain the original finite refill mechanics.
		var index:=0;var previous_id: String=pop.spots[index].id
		var duration: float=pop.spots[index].respawn_minutes
		check(duration==3600. and pop.spots[index].remaining==0,'old empty school not refilled by migration '+str(pair))
		pop.advance(duration)
		check(pop.spots[index].remaining==6 and pop.spots[index].id!=previous_id and pop.valid(pop.serialize()),'delayed refill uses different legal shore '+str(pair))
	stats.populations=cases
	var failed:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+'logic.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failed':failed,'stats':stats},'  '));print('V4 POPULATION LOGIC ',checks.size(),' checks ',failed,' failures');quit(0 if failed==0 else 1)
