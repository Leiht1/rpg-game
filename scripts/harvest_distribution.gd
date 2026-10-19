extends RefCounted
## Deterministic extra resources in the existing ItemService worker, with no terrain edits.
const CONFIG = preload("res://scripts/harvest_node.gd")
static func legacy_candidates(layer: Node, coord: Vector2i) -> Dictionary:
	var cfg: Dictionary=CONFIG.configuration()
	var span := float(cfg.cell_size)
	var chunk_px: float=layer.world.Gen.CHUNK_PX
	var rect := Rect2(Vector2(coord)*chunk_px,Vector2.ONE*chunk_px)
	var low := Vector2i(floori((rect.position.x-400)/span),floori((rect.position.y-400)/span))
	var high := Vector2i(floori((rect.end.x+400)/span),floori((rect.end.y+400)/span))
	var candidates: Array[Dictionary]=[]
	var gen = layer.world.generator
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for attempt in int(cfg.attempts):
				var salt := 19031+attempt*61
				var p := (Vector2(x,y)+Vector2(gen.random_at(x,y,salt),gen.random_at(x,y,salt+1)))*span
				if p.distance_to(gen.spawn)<160 or not gen.can_walk(p,52): continue
				var eco: Dictionary=layer.ecology(p)
				if float(eco.shore)>.08: continue
				# Stable weighted choice with explicit empty probability.
				var roll: float=gen.random_at(x,y,salt+2)*2.0
				var chosen := ""
				for kind in cfg.legacy_order:
					var w: Array=cfg.resources[kind].weights
					roll-=float(w[0])*float(eco.forest)+float(w[1])*float(eco.mountain)+float(w[2])*float(eco.meadow)
					if roll<0: chosen=kind;break
				if chosen.is_empty(): continue
				var props: Array[Dictionary]=layer.nearby_props(p)
				if not layer.ground_clear(p,40,props) or not layer.has_approach(p,props): continue
				# Existing natural resources win; their original distribution is unchanged.
				var occupied := false
				for ny in range(y-1,y+2):
					for nx in range(x-1,x+2):
						for row in layer.raw_cell(Vector2i(nx,ny)):
							if str(row.reason).is_empty() and p.distance_to(Vector2(row.x,row.y))<110: occupied=true
				if occupied: continue
				candidates.append({"id":"harvest:1:%d:%d:%d"%[x,y,attempt],"kind":chosen,"x":p.x,"y":p.y,"priority":gen.random_at(x,y,salt+3)})
	var result: Array[Dictionary]=[]
	for row in candidates:
		var p := Vector2(row.x,row.y)
		var accepted := true
		for other in candidates:
			if other.id==row.id: continue
			var higher: bool=other.priority<row.priority or (other.priority==row.priority and str(other.id)<str(row.id))
			var own_spacing: float=160.0 if cfg.resources[row.kind].action=="mine" else float(cfg.resources[row.kind].spacing)
			var neighbor_spacing: float=160.0 if cfg.resources[other.kind].action=="mine" else float(cfg.resources[other.kind].spacing)
			var spacing := maxf(own_spacing,neighbor_spacing)
			if higher and p.distance_to(Vector2(other.x,other.y))<spacing: accepted=false;break
		if accepted and cfg.resources[row.kind].action=="dig": result.append(row)
	return {"accepted":result,"raw":candidates.filter(func(row):return cfg.resources[row.kind].action=="dig")}

static func dirt_region(gen: WildGenerator, p: Vector2) -> bool:
	# Matches the dominant brown highland plate in terrain.gdshader, not wet banks.
	for offset in [Vector2.ZERO,Vector2(72,0),Vector2(-72,0),Vector2(0,72),Vector2(0,-72)]:
		var ground: Vector4=gen.sample(p+offset)
		if ground.y<.65 or ground.z>.03: return false
	return true

static func rocky_region(gen: WildGenerator, p: Vector2) -> bool:
	for offset in [Vector2.ZERO,Vector2(72,0),Vector2(-72,0),Vector2(0,72),Vector2(0,-72)]:
		if gen.rocky_weight(p+offset)<.55 or gen.sample(p+offset).z>.03:return false
	return true

static func mineral_kind(cfg: Dictionary, gen: WildGenerator, cell: Vector2i, attempt: int, rocky: bool) -> String:
	var rule: Dictionary=cfg.mineral_generation
	var salt := 29093+attempt*73
	if gen.random_at(cell.x,cell.y,salt+2)>(float(rule.density_rocky) if rocky else float(rule.density_other)): return ""
	var weights: Dictionary=rule.rocky_weights if rocky else rule.other_weights
	var roll: float=gen.random_at(cell.x,cell.y,salt+3)*100.0
	for kind in weights:
		roll-=float(weights[kind])
		if roll<0: return str(kind)
	return ""

static func build(layer: Node, coord: Vector2i) -> Array[Dictionary]:
	var cfg: Dictionary=CONFIG.configuration()
	var span := float(cfg.cell_size)
	var rect := Rect2(Vector2(coord)*layer.world.Gen.CHUNK_PX,Vector2.ONE*layer.world.Gen.CHUNK_PX)
	var gen = layer.world.generator
	var legacy := legacy_candidates(layer,coord)
	var buried: Array=legacy.accepted
	var blockers: Array=legacy.raw
	var result: Array[Dictionary]=[]
	for row in buried:
		if rect.has_point(Vector2(row.x,row.y)): result.append(row)
	var low := Vector2i(floori((rect.position.x-200)/span),floori((rect.position.y-200)/span))
	var high := Vector2i(floori((rect.end.x+200)/span),floori((rect.end.y+200)/span))
	var candidates: Array[Dictionary]=[]
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for attempt in int(cfg.mineral_generation.attempts):
				var salt := 29093+attempt*73
				var p := (Vector2(x,y)+Vector2(gen.random_at(x,y,salt),gen.random_at(x,y,salt+1)))*span
				if p.distance_to(gen.spawn)<160 or not gen.can_walk(p,52): continue
				var rocky := rocky_region(gen,p)
				var kind := mineral_kind(cfg,gen,Vector2i(x,y),attempt,rocky)
				if kind.is_empty() or float(layer.ecology(p).shore)>.08: continue
				var props: Array[Dictionary]=layer.nearby_props(p)
				if not layer.ground_clear(p,48,props) or not layer.has_approach(p,props): continue
				var occupied := false
				for row in blockers:
					if p.distance_to(Vector2(row.x,row.y))<185: occupied=true;break
				for ny in range(y-1,y+2):
					for nx in range(x-1,x+2):
						for row in layer.raw_cell(Vector2i(nx,ny)):
							if str(row.reason).is_empty() and str(row.get("item_id","")) not in ["stone","flint"] and p.distance_to(Vector2(row.x,row.y))<110: occupied=true
				if occupied: continue
				candidates.append({"id":"mineral:2:%d:%d:%d"%[x,y,attempt],"kind":kind,"x":p.x,"y":p.y,"rocky":rocky,"priority":gen.random_at(x,y,salt+4)})
	for row in candidates:
		var p := Vector2(row.x,row.y)
		if not rect.has_point(p): continue
		var accepted := true
		for other in candidates:
			if row.id==other.id: continue
			var higher: bool=other.priority<row.priority or (other.priority==row.priority and str(other.id)<str(row.id))
			if higher and p.distance_to(Vector2(other.x,other.y))<185: accepted=false;break
		if accepted:result.append(row)
	result.append_array(broadleaf_candidates(layer,coord,blockers+candidates))
	return result

static func grass_region(gen: WildGenerator, p: Vector2) -> bool:
	# Same meadow weight used by the painted grass plate; exclude mixed dirt/banks.
	for offset in [Vector2.ZERO,Vector2(40,0),Vector2(-40,0),Vector2(0,40),Vector2(0,-40)]:
		var ground: Vector4=gen.sample(p+offset)
		if ground.w<.65 or ground.z>.03: return false
	return true

static func broadleaf_candidates(layer: Node, coord: Vector2i, obstacles: Array) -> Array[Dictionary]:
	var cfg: Dictionary=CONFIG.configuration().broadleaf_generation
	var span := float(cfg.cell_size)
	var spacing := float(cfg.spacing)
	var rect := Rect2(Vector2(coord)*layer.world.Gen.CHUNK_PX,Vector2.ONE*layer.world.Gen.CHUNK_PX)
	var low := Vector2i(((rect.position-Vector2.ONE*spacing)/span).floor())
	var high := Vector2i(((rect.end+Vector2.ONE*spacing)/span).floor())
	var gen = layer.world.generator
	var candidates: Array[Dictionary]=[]
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for attempt in int(cfg.attempts):
				var salt := 39121+attempt*83
				if gen.random_at(x,y,salt)>float(cfg.probability):continue
				var p := (Vector2(x,y)+Vector2(gen.random_at(x,y,salt+1),gen.random_at(x,y,salt+2)))*span
				if p.distance_to(gen.spawn)<160 or not grass_region(gen,p):continue
				# Reuse natural grass-resource patch field, without rerolling existing resources.
				if smoothstep(-.28,.32,layer.patch_noise.get_noise_2dv(p))<float(cfg.patch_min):continue
				candidates.append({"id":"broadleaf:1:%d:%d:%d"%[x,y,attempt],"kind":"broadleaf_clump","x":p.x,"y":p.y,"priority":gen.random_at(x,y,salt+3)})
	var result: Array[Dictionary]=[]
	for row in candidates:
		var p := Vector2(row.x,row.y)
		if not rect.has_point(p):continue
		var blocked := false
		# Potential higher-priority plants also reserve space: order-independent at seams.
		for other in candidates:
			if other.id==row.id:continue
			if (other.priority<row.priority or (other.priority==row.priority and str(other.id)<str(row.id))) and p.distance_to(Vector2(other.x,other.y))<spacing:blocked=true;break
		for other in obstacles:
			if p.distance_to(Vector2(other.x,other.y))<110:blocked=true;break
		var cell := Vector2i((p/float(layer.rules.cell_size)).floor())
		for y in range(cell.y-1,cell.y+2):
			for x in range(cell.x-1,cell.x+2):
				for other in layer.raw_cell(Vector2i(x,y)):
					if str(other.reason).is_empty() and p.distance_to(Vector2(other.x,other.y))<110:blocked=true
		if blocked:continue
		var props: Array[Dictionary]=layer.nearby_props(p)
		if gen.can_walk(p,32) and layer.ground_clear(p,28,props) and layer.has_approach(p,props):result.append(row)
	return result


# Reconstruct only old, already-worked points, not a second generated resource layer.
static func preserve_worked(layer: Node, previous_ecology: bool = false) -> void:
	var gen = layer.world.generator
	var cfg: Dictionary=CONFIG.configuration()
	var weights := {"stone_outcrop":[.14,.72,.26],"flint_outcrop":[.06,.42,.08],"buried_root":[.2,.03,.36],"buried_bone":[.08,.16,.08],"buried_supply":[.055,.045,.055]}
	for id in layer.resource_hits:
		if layer.consumed.has(id) or layer.ore_nodes.has(id):continue
		var parts: PackedStringArray=str(id).split(":")
		var mineral := parts.size()==5 and parts[0]=="mineral" and parts[1]=="2"
		var buried := parts.size()==5 and parts[0]=="harvest" and parts[1]=="1"
		if not mineral and not buried:continue
		if not parts[2].is_valid_int() or not parts[3].is_valid_int() or not parts[4].is_valid_int():continue
		var x := int(parts[2]);var y := int(parts[3]);var attempt := int(parts[4])
		var salt := 29093+attempt*73 if mineral else 19031+attempt*61
		var point := (Vector2(x,y)+Vector2(gen.random_at(x,y,salt),gen.random_at(x,y,salt+1)))*float(cfg.cell_size)
		var kind := ""
		if mineral:
			var dirt := true
			for offset in [Vector2.ZERO,Vector2(72,0),Vector2(-72,0),Vector2(0,72),Vector2(0,-72)]:
				var at:Vector2=point+offset
				var macro:Vector3=gen.macro_weights(at)
				var water:float=gen.sample(at).z
				var old_rocky:float=smoothstep(.30,.62,macro.y)*smoothstep(-.20,.12,gen.elevation.get_noise_2dv(at))*(1.-smoothstep(.01,.10,water))
				if water>.03 or (old_rocky<.55 if previous_ecology else macro.y<.65):dirt=false
			var roster: Dictionary={"stone_outcrop":42,"flint_outcrop":30,"copper_outcrop":16,"silver_outcrop":8,"gold_outcrop":4} if dirt else {"stone_outcrop":75,"flint_outcrop":25}
			var roll: float=gen.random_at(x,y,salt+3)*100
			for name in roster:
				roll-=float(roster[name])
				if roll<0:kind=name;break
		else:
			var eco: Vector3=gen.macro_weights(point)
			if previous_ecology:
				var water:float=gen.sample(point).z
				var old_rocky:float=smoothstep(.30,.62,eco.y)*smoothstep(-.20,.12,gen.elevation.get_noise_2dv(point))*(1.-smoothstep(.01,.10,water))
				var shore:=0.0
				for offset in [Vector2.ZERO,Vector2(110,0),Vector2(-110,0),Vector2(0,110),Vector2(0,-110)]:shore=maxf(shore,gen.sample(point+offset).z)
				eco*=(1.-old_rocky)*(1.-smoothstep(.03,.6,shore))
				for name in weights:
					weights[name]=cfg.resources[name].weights
			var roll: float=gen.random_at(x,y,salt+2)*2
			for name in cfg.legacy_order:
				var w: Array=weights[name]
				roll-=float(w[0])*eco.x+float(w[1])*eco.y+float(w[2])*eco.z
				if roll<0:kind=name;break
		if not kind.is_empty():layer.ore_nodes[id]={"id":id,"kind":kind,"x":point.x,"y":point.y,"ecology_preserved":true}

# New candidates may win spacing arbitration. Already-worked old points stay present.
static func preserve_current_minerals(layer: Node) -> void:
	var gen=layer.world.generator
	var cfg:Dictionary=CONFIG.configuration()
	for id in layer.resource_hits:
		if layer.consumed.has(id) or layer.ore_nodes.has(id):continue
		var parts:PackedStringArray=str(id).split(":")
		if parts.size()!=5 or parts[0]!="mineral" or parts[1]!="2":continue
		if not parts[2].is_valid_int() or not parts[3].is_valid_int() or not parts[4].is_valid_int():continue
		var x:=int(parts[2]);var y:=int(parts[3]);var attempt:=int(parts[4]);var salt:=29093+attempt*73
		var at:Vector2=(Vector2(x,y)+Vector2(gen.random_at(x,y,salt),gen.random_at(x,y,salt+1)))*float(cfg.cell_size)
		var kind:=mineral_kind(cfg,gen,Vector2i(x,y),attempt,rocky_region(gen,at))
		if not kind.is_empty():layer.ore_nodes[id]={"id":id,"kind":kind,"x":at.x,"y":at.y,"ecology_preserved":true}
