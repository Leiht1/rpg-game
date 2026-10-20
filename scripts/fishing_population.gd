extends RefCounted
## Mutable resource state shares the existing atomic item snapshot.
const MAX_SCHOOLS := 40
const FISH_PER_SCHOOL := 6
const MAX_PER_LAKE := 6
const COAST_SPACING := 1800.0
const LAKE_SPACING := 320.0
const RESPAWN_MIN_MINUTES := 2880.0
const RESPAWN_MAX_MINUTES := 4320.0
var max_schools := MAX_SCHOOLS
var candidates: Array[Dictionary]=[]
var spots: Array[Dictionary]=[]
var rng := RandomNumberGenerator.new()

func configure(generator: WildGenerator) -> void:
	spots.clear()
	max_schools=56 if generator.map_cells>1024 else MAX_SCHOOLS
	candidates=preload("res://scripts/fishing_spots.gd").new().candidates(generator)
	rng.seed=generator.world_seed^918721
	fill_population(generator.lakes.size())

func fill_population(lake_count: int) -> void:
	var choices := shuffled_candidates()
	for lake in lake_count:
		var target := rng.randi_range(0,MAX_PER_LAKE)
		var count := 0
		for existing in spots:
			if existing.lake==lake and existing.remaining>0:count+=1
		for candidate in choices:
			if count>=target or spots.size()>=max_schools: break
			if candidate.lake==lake and eligible(candidate,-1):
				spots.append(fresh(candidate));count+=1
	for candidate in choices:
		if spots.size()>=max_schools: break
		if candidate.lake==-1 and eligible(candidate,-1): spots.append(fresh(candidate))

func fresh(candidate: Dictionary) -> Dictionary:
	var spot := candidate.duplicate(true)
	spot.remaining=FISH_PER_SCHOOL;spot.respawn_minutes=0.0
	return spot

func shuffled_candidates() -> Array[Dictionary]:
	var choices: Array[Dictionary]=candidates.duplicate()
	for i in range(choices.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var old: Dictionary=choices[i];choices[i]=choices[j];choices[j]=old
	return choices

func eligible(candidate: Dictionary, replacing: int) -> bool:
	var lake_count := 0
	for i in spots.size():
		if i==replacing: continue
		var other: Dictionary=spots[i]
		if candidate.id==other.id: return false
		if int(other.remaining)<=0: continue
		if candidate.lake>=0 and other.lake==candidate.lake: lake_count+=1
		var spacing := COAST_SPACING if candidate.lake==-1 or other.lake==-1 else LAKE_SPACING
		if Vector2(other.water).distance_to(candidate.water)<spacing: return false
	return candidate.lake==-1 or lake_count<MAX_PER_LAKE

func consume(index: int) -> void:
	spots[index].remaining-=1
	if spots[index].remaining==0:
		spots[index].respawn_minutes=rng.randf_range(RESPAWN_MIN_MINUTES,RESPAWN_MAX_MINUTES)

func advance(minutes: float) -> bool:
	if minutes<=0: return false
	var changed := false
	for i in spots.size():
		var spot: Dictionary=spots[i]
		if spot.remaining>0: continue
		changed=true
		spot.respawn_minutes=maxf(0,float(spot.respawn_minutes)-minutes)
		if spot.respawn_minutes>0: continue
		var replacement: Dictionary={}
		for candidate in shuffled_candidates():
			# Do not refill the old point; select a new valid shore position.
			if Vector2(candidate.water).distance_to(spot.water)>=LAKE_SPACING and eligible(candidate,i):
				replacement=fresh(candidate);break
		if replacement.is_empty(): spot.respawn_minutes=60.0
		else: spots[i]=replacement
	return changed

func serialize() -> Dictionary:
	var rows: Array=[]
	for spot in spots: rows.append({"id":spot.id,"remaining":spot.remaining,"respawn_minutes":spot.respawn_minutes})
	return {"version":1,"population_revision":2,"rng_state":str(rng.state),"schools":rows}

func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not value.get("schools") is Array or value.schools.size()>max_schools: return false
	var revision=value.get("population_revision",1)
	if not (revision is int or revision is float) or not is_finite(float(revision)) or revision!=floor(revision) or revision<1 or revision>2:return false
	if not value.get("rng_state") is String or not value.rng_state.is_valid_int(): return false
	var by_id := {}
	for candidate in candidates: by_id[candidate.id]=candidate
	var seen := {};var active: Array[Dictionary]=[];var lakes := {}
	for row in value.schools:
		if not row is Dictionary or not row.get("id") is String or not by_id.has(row.id) or seen.has(row.id): return false
		seen[row.id]=true
		var remaining=row.get("remaining");var delay=row.get("respawn_minutes")
		if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or remaining!=floor(remaining) or remaining<0 or remaining>FISH_PER_SCHOOL: return false
		if not (delay is int or delay is float) or not is_finite(float(delay)) or delay<0 or delay>RESPAWN_MAX_MINUTES: return false
		if (remaining>0 and delay!=0) or (remaining==0 and delay<=0): return false
		var candidate: Dictionary=by_id[row.id]
		if remaining<=0: continue
		if candidate.lake>=0:
			lakes[candidate.lake]=int(lakes.get(candidate.lake,0))+1
			if lakes[candidate.lake]>MAX_PER_LAKE: return false
		for other in active:
			var spacing := COAST_SPACING if candidate.lake==-1 or other.lake==-1 else LAKE_SPACING
			if Vector2(candidate.water).distance_to(other.water)<spacing: return false
		active.append(candidate)
	return true

func restore(value: Dictionary) -> void:
	var by_id := {}
	for candidate in candidates: by_id[candidate.id]=candidate
	spots.clear()
	for row in value.schools:
		var spot := fresh(by_id[row.id])
		spot.remaining=int(row.remaining);spot.respawn_minutes=float(row.respawn_minutes)
		spots.append(spot)
	rng.state=int(value.rng_state)
	if int(value.get("population_revision",1))<2:
		var lake_count:=0
		for candidate in candidates:lake_count=maxi(lake_count,int(candidate.lake)+1)
		fill_population(lake_count)
