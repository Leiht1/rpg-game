extends SceneTree
## Reuse original item instance, stack, equipment and hotbar rules on the server.
func _initialize()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var request=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var db:=preload("res://scripts/item_database.gd").new()
	preload("res://scripts/character_catalog.gd").enable_candidate(db)
	var inv:=preload("res://scripts/item_inventory.gd").new(db)
	var state:Dictionary=request.get("state",{})
	var ok:=true
	if not state.is_empty():
		ok=inv.restore(state.slots) and inv.restore_equipment(state.equipment)
		inv.restore_hotbar_links(state.get("hotbar_equipment",{}))
	var contents:Array=request.get("contents",[]).duplicate(true)
	var dropped:Dictionary={}
	if ok:
		match str(request.operation):
			"create":pass
			"equip":ok=inv.equip(int(request.index))
			"unequip":ok=inv.unequip(int(request.index))
			"move":ok=inv.move_slot(int(request.index),int(request.to))
			"drop":
				var index:=int(request.index);var amount:=int(request.amount)
				ok=index>=0 and index<40 and not inv.slots[index].is_empty() and int(inv.slots[index].count)>=amount
				if ok:
					dropped=inv.slots[index].duplicate(true);dropped.count=amount
					inv.slots[index].count=int(inv.slots[index].count)-amount
					if int(inv.slots[index].count)==0:inv.slots[index]={}
			"transfer":
				var index:=int(request.index);var amount:=int(request.amount)
				if request.taking:
					ok=index>=0 and index<contents.size() and not contents[index].is_empty() and int(contents[index].count)>=amount
					if ok:
						var value:Dictionary=contents[index].duplicate(true);value.count=amount
						ok=inv.add_value(value)==0
						if ok:
							contents[index].count=int(contents[index].count)-amount
							if int(contents[index].count)==0:contents[index]={}
				else:
					ok=index>=0 and index<40 and not inv.slots[index].is_empty() and int(inv.slots[index].count)>=amount
					if ok:
						var value:Dictionary=inv.slots[index].duplicate(true);value.count=amount
						var destination:=preload("res://scripts/item_inventory.gd").new(db)
						for i in contents.size():destination.slots[i+8]=contents[i].duplicate(true)
						# Restrict destination to the existing nine chest slots.
						for i in range(8+contents.size(),40):destination.slots[i]={"item_id":"wood","count":99}
						ok=destination.add_value(value)==0
						if ok:
							for i in contents.size():contents[i]=destination.slots[i+8].duplicate(true)
							inv.slots[index].count=int(inv.slots[index].count)-amount
							if int(inv.slots[index].count)==0:inv.slots[index]={}
			_:ok=false
	var result:={"ok":ok,"slots":inv.slots,"equipment":inv.equipment,"hotbar_equipment":inv.hotbar_equipment,"contents":contents,"dropped":dropped}
	var output:=FileAccess.open(args[1],FileAccess.WRITE)
	if not output:quit(3);return
	output.store_string(JSON.stringify(result));output.close();quit()
