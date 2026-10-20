extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.max_fps=60;Engine.remove_meta("merchant_preview")
	var world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	for i in 12:await process_frame
	var service=world.item_service;var merchant=service.merchant
	var legacy=service.snapshot().duplicate(true);legacy.erase("merchant")
	var path="user://merchant-formal-legacy-test-only.json"
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(legacy));file.close()
	merchant.state={};service.load_state(path)
	var ok: bool=service.writable and merchant.state.is_empty() and merchant.migrate() and merchant.valid(merchant.serialize())
	var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://assets/merchant/v1/provenance.json"))
	var matching := 0
	for name in provenance.files:
		if FileAccess.get_sha256("res://assets/merchant/v1/"+name)==provenance.files[name] and FileAccess.get_sha256("res://prototypes/merchant-v1/final/"+name)==provenance.files[name]:matching+=1
	print("FORMAL old snapshot without merchant migrates: ",ok," approved PNG hashes: ",matching,"/8")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	world.queue_free()
	for i in 5:await process_frame
	quit(0 if ok and matching==8 else 1)
