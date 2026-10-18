extends SceneTree
const Gen = preload("res://scripts/world_generator.gd")
const Service = preload("res://scripts/item_service.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func run() -> void:
	var total := 0
	var flints := 0
	for seed_value in [271828,447349832]:
		var gen := Gen.new(seed_value,1024)
		var layer := Service.new(); layer.world={"generator":gen,"Gen":Gen}
		layer.patch_noise.seed=seed_value^87361; layer.patch_noise.frequency=1.0/float(layer.rules.noise_scale); layer.patch_noise.fractal_octaves=2; layer.prepare_navigation()
		var coords := {}
		for room in gen.rooms:
			var center := Vector2i(room.p/Gen.CHUNK_PX)
			for y in range(-1,2):
				for x in range(-1,2): coords[center+Vector2i(x,y)]=true
		var seed_flints := 0
		for coord in coords:
			var rows := layer.entries(coord)
			check(rows.all(func(row):return row.item_id != "stone"),"ordinary ground stone remains disabled")
			for row in rows:
				total += 1
				if row.item_id != "flint": continue
				flints += 1; seed_flints += 1
				check(row.mode=="pickup" and row.count==1,"flint is a single basic pickup")
				check(preload("res://scripts/world_interaction.gd").allowed(layer.inventory,"pickup"),"no equipped tool required")
				check(layer.entries(coord)==rows,"same seed and chunk reproduce flint")
				layer.consumed[row.id]=true
				check(layer.entries(coord).all(func(candidate):return candidate.id != row.id),"collected flint does not respawn")
				layer.consumed.erase(row.id)
		check(seed_flints>0,"seed contains ground flint")
		layer.free()
	check(flints>0 and flints<float(total)*0.1,"ground flint remains sparse")
	print("Ground flint: %d / %d visible resources; %d checks, %d failures" % [flints,total,checks,failures])
	quit(1 if failures else 0)
