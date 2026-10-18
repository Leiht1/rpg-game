extends 'res://scripts/chunk_stream.gd'
## Only the specimen arena uses this adapter. No formal distribution is changed.
func chop_tree(tree:Node2D)->void:
	if not is_instance_valid(tree) or not tree.is_in_group('trees'):return
	var id:String=tree.get_meta('prop_id')
	if harvested.has(id):return
	tree_hits[id]=int(tree_hits.get(id,0))+1
	tree.hit()
	var hits:=int(tree_hits[id]);var required:=int(tree.get_meta('required_hits',2))
	if hits%2==0:spawn_drop(tree.position+Vector2(-28 if hits==2 else 28,18),id+':hit%d'%hits)
	if hits<required:return
	harvested[id]=true;tree.remove_from_group('trees')
	tree.fade_out()
