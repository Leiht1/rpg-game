extends RefCounted
const VERSION='scene-contact-1.0.0'
const IDS=['tree_01','tree_03','tree_04','rock_01','rock_02','rock_03','rock_04','rock_05','rock_06']
const NAMES=['高瘦幼树','高大开展树','疏冠分叉树','低矮扁石','敦实孤石','楔形石','双肩连体石','窄高石','缺角碎石']
static func appearance(gen:WildGenerator,entry:Dictionary)->Dictionary:
	# Visual lookup only: existing positions, scale, IDs and generation RNG stay intact.
	var p:Vector2=entry.position
	var count:=3 if entry.kind<2 else 6
	var slot:=mini(count-1,int(gen.random_at(roundi(p.x),roundi(p.y),941)*count))
	var id:String=IDS[slot if entry.kind<2 else slot+3]
	var ground:=gen.sample(p)
	var surface:="dirt" if ground.z>.12 or ground.y>=maxf(ground.x,ground.w) else "forest" if ground.x>=ground.w else "grass"
	return {"id":id,"surface":surface}
static func footprint(id:String)->PackedVector2Array:
	match id:
		'tree_01':return PackedVector2Array([Vector2(-10,-3),Vector2(-7,-13),Vector2(7,-14),Vector2(12,-3),Vector2(8,5),Vector2(-8,5)])
		'tree_03':return PackedVector2Array([Vector2(-22,-4),Vector2(-16,-18),Vector2(14,-19),Vector2(23,-3),Vector2(16,6),Vector2(-15,6)])
		'tree_04':return PackedVector2Array([Vector2(-12,-3),Vector2(-7,-15),Vector2(10,-16),Vector2(17,-3),Vector2(11,6),Vector2(-9,5)])
		'rock_01':return PackedVector2Array([Vector2(-46,-3),Vector2(-36,-13),Vector2(31,-14),Vector2(45,-5),Vector2(30,5),Vector2(-31,6)])
		'rock_02':return PackedVector2Array([Vector2(-33,-4),Vector2(-23,-18),Vector2(20,-17),Vector2(35,-4),Vector2(23,5),Vector2(-22,6)])
		'rock_03':return PackedVector2Array([Vector2(-41,-3),Vector2(-29,-13),Vector2(30,-16),Vector2(42,-4),Vector2(26,5),Vector2(-28,6)])
		'rock_04':return PackedVector2Array([Vector2(-44,-4),Vector2(-29,-18),Vector2(-5,-15),Vector2(25,-16),Vector2(45,-3),Vector2(29,5),Vector2(-29,6)])
		'rock_05':return PackedVector2Array([Vector2(-25,-4),Vector2(-17,-15),Vector2(17,-17),Vector2(27,-3),Vector2(17,5),Vector2(-18,6)])
		'rock_06':return PackedVector2Array([Vector2(-30,-3),Vector2(-17,-12),Vector2(20,-13),Vector2(31,-2),Vector2(17,5),Vector2(-20,5)])
	return PackedVector2Array()
