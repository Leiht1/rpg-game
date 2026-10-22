extends Node
class TreeStub extends "res://scripts/scenery_prop.gd":
	func _draw() -> void: pass
	func hit() -> void: pass
	func fade_out() -> void: pass
class StreamStub extends "res://scripts/chunk_stream.gd":
	var batches: Array=[]
	func create_item_drop(entry: Dictionary) -> Node2D:
		batches.append(entry.duplicate(true))
		return null
	func refresh_grounding(_at: Vector2) -> void: pass
class InventoryStub extends RefCounted:
	var equipment: Dictionary={}
	func has_capability(_cap: String) -> bool: return true
	func wear_held(_id: String,_cap: String) -> void: pass
class BodyStub extends RefCounted:
	func can_labor(_cap: String,_active: bool) -> bool: return true
	func spend_labor(_cap: String) -> void: pass
class ItemsStub extends Node:
	var inventory=InventoryStub.new()
	var body=BodyStub.new()
	var world: Dictionary={"player":{"action":"chop"}}
	var dirty:=false
	var consumed: Dictionary={}
	var loose: Dictionary={}
	func save_state() -> bool: return true
func _ready() -> void: run.call_deferred()
func run() -> void:
	var checks:=0
	for variant in ["tree_01","tree_04","tree_03"]:
		var stream=StreamStub.new();get_tree().root.add_child(stream);stream.set_process(false)
		var items=ItemsStub.new();stream.add_child(items);stream.items=items
		var tree=TreeStub.new();tree.variant_id=variant;tree.set_meta("prop_id",variant)
		get_tree().root.add_child(tree);tree.add_to_group("trees")
		var required: int=8 if variant=="tree_03" else 4
		assert(tree.required_hits==required);checks+=1
		for hit in range(1,required+1):
			stream.chop_tree(tree)
			assert(stream.tree_hits[variant]==hit)
			assert(stream.batches.size()==hit/4)
			assert(stream.harvested.has(variant)==(hit==required))
			checks+=3
		for entry in stream.batches:
			assert(entry.count==6 and entry.item_id=="wood")
			assert(items.loose[entry.id].count==6);checks+=2
		stream.chop_tree(tree)
		assert(stream.tree_hits[variant]==required);checks+=1
		# Restored in-progress tree reaches the same next payout without replaying prior batches.
		stream.harvested.clear();stream.batches.clear();tree.add_to_group("trees")
		stream.tree_hits[variant]=required-1
		stream.chop_tree(tree)
		assert(stream.batches.size()==1 and stream.batches[0].count==6);checks+=1
		tree.free();stream.free()
	await get_tree().process_frame
	print("TREE_BALANCE_V2_PASS checks=",checks)
	get_tree().quit()

