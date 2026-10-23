extends SceneTree
func _initialize() -> void:
	var db=preload("res://scripts/item_database.gd").new()
	var inv=preload("res://scripts/item_inventory.gd").new(db)
	inv.slots[8]={"item_id":"roasted_carrot","count":2,"spoilage":0.7}
	assert(inv.add_value({"item_id":"roasted_carrot","count":3,"spoilage":0.1})==0)
	assert(inv.slots[8].count==5 and inv.slots[8].spoilage==0.7)
	inv.slots[9]={"item_id":"roasted_carrot","count":2,"spoilage":0.9}
	assert(inv.move_slot(9,8))
	assert(inv.slots[8].count==7 and inv.slots[8].spoilage==0.9 and inv.slots[9].is_empty())
	inv.slots[9]={"item_id":"roasted_carrot","count":1,"spoilage":1.0}
	var organized=inv.organized_bag_slots()
	assert(organized[8].count==8 and organized[8].spoilage==1.0)
	assert(inv.slots[8].spoilage==0.9)
	print("COOKED STACKING: add, drag, organize, freshness and source isolation passed")
	quit()
