extends SceneTree
var checks: Array=[]
func check(ok: bool,label: String):checks.append({"pass":ok,"name":label})
func _initialize():call_deferred("run")
func run():
	var db=ItemDatabase.new();check(not db.item("modern_outfit").equippable,"formal modern outfit definition remains collectible")
	var inv=ItemInventory.new(db);inv.add("stone_axe",1);check(inv.equip(8),"formal inventory equip fallback unchanged");check(inv.unequip(40),"formal unequip fallback unchanged")
	var candidate=ItemInventory.new(ItemDatabase.new());load("res://scripts/character_catalog.gd").enable_candidate(candidate.database);candidate.add("modern_outfit",1)
	var value=candidate.slots[8].duplicate(true);candidate.commit_equipment=func():return false
	check(not candidate.equip(8) and candidate.slots[8]==value and candidate.equipment.get("outfit",{}).is_empty(),"failed equip commit restores inventory and equipment")
	candidate.commit_equipment=func():return true
	check(candidate.move_slot(8,0) and candidate.equip(0),"hotbar alias uses original equipment path")
	candidate.commit_equipment=func():return false
	var links=candidate.hotbar_equipment.duplicate(true)
	check(not candidate.unequip(42) and candidate.hotbar_equipment==links and candidate.slots[0].is_empty(),"failed hotbar unequip restores alias and instance")
	candidate.commit_equipment=Callable()
	check(candidate.unequip(42) and candidate.slots[0].instance_id==value.instance_id,"successful alias unequip returns same original instance")
	var prov=JSON.parse_string(FileAccess.get_file_as_string("res://art/character-creation-v1/provenance.json"))
	var hashes=true
	for path in prov.references:hashes=hashes and FileAccess.get_sha256("res://"+path.replace("\\","/"))==prov.references[path]
	check(hashes,"all nine approved original body PNGs unchanged")
	hashes=true
	for path in prov.candidate_sha256:hashes=hashes and FileAccess.get_sha256("res://"+path)==prov.candidate_sha256[path]
	check(hashes,"all sixty candidate hashes match source record")
	var fails=checks.filter(func(row):return not row.pass)
	var file=FileAccess.open("res://reports/character-creation-v1/contracts-checks.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"total":checks.size(),"failed":fails.size()},"\t"));file.close()
	print("CONTRACT CHECKS ",checks.size()," FAILED ",fails.size());quit(0 if fails.is_empty() else 1)
