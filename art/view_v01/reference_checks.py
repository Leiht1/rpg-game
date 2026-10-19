from pathlib import Path
p=Path('prototypes/view-v01')
Path('VIEW_REFERENCE.md').write_text('''# 统一视角参考样板
2026-10-16 · ART_STYLE.md 3.1 的附属说明，不另立视角标准。

- 正式身份/尺度参考：assets/hero/cartoon/character.tscn、assets/environment/stylized_v3/tree_0.png、tree_1.png、rock_0.png、rock_1.png。
- 正式同屏参照：reports/ecology-v03-271828-region-0.png；实际1280×720、原Camera2D，白T短腿角色不重绘。
- 几何辅助图：prototypes/view-v01/view-reference.svg。此图只解释水平面、竖向、接地与光照，非游戏美术，不作为新配色/造型。
- 候选真实同屏：prototypes/view-v01/index.html；Start-View-Preview.cmd可以切换旧版/候选、出生/湖岸/森林/山地。具体图像pending_user，不因本规范入库而获批。

从南上方向北下看，约40°俯角、近正交，地面圆面Y/X约0.64，竖直高度投影约0.77。相同体系允许不同结构显露不同顶面面积；不把几何参考椭圆比例套作整棵树或湖泊图像压缩。无消失点，不强制等距菱形。

| 类型 | 顶部和侧面 | 接地/遮挡 | 检查失败示例 |
|---|---|---|---|
| 树 | 可见上方冠面，近叶群覆远枝，树干入冠下 | 原根部，冠后角色用原淡化机制 | 正面扇形叶层、球团、压扁旧树 |
| 石 | 不规则顶面，较短前/右侧面 | 原石底、原碰撞，不按新可见边扩大 | 正面立板、纯顶视平块 |
| 建筑家具道具 | 同相机下屋顶/台面和前侧面，自身允许转向 | 地基/腿脚落地，脚底Y排序 | 单独换成正面相机/强透视 |
| 植被道路 | 低物贴水平面，竖茎有高度 | 不规则柔接触阴影 | 道路立面化、贴纸底盘 |
| 湖水岸坡 | 水平水面，局部远岸向水坡/近岸遮边 | 泥沙-浅水-深水连续，局部低厚度 | 整圈高墙、大坑、绿蓝模糊边 |

同镜头核查顺序：角色与原相机 → 树/石逻辑画布和根部 → 冠顶/岩顶结构 → 左上光源/右下短影 → 同水平面水岸 → 近远遮挡。不可仅凭参数通过宣称美术已确认。
''',encoding='utf-8')
(p/'view-reference.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="960" height="420" viewBox="0 0 960 420"><rect width="960" height="420" fill="#f2f0e5"/><g font-family="Microsoft YaHei, sans-serif" fill="#334737"><text x="30" y="38" font-size="22">3/4 斜俯视 · 近正交空间辅助图（非游戏素材）</text><ellipse cx="190" cy="258" rx="100" ry="64" fill="#b9c5b0" stroke="#526753"/><text x="90" y="360">水平圆面 Y/X ≈ 0.64</text><path d="M390 210 L480 168 L565 210 L475 252 Z" fill="#bdc6c1" stroke="#526753"/><path d="M390 210 L475 252 L475 310 L390 268 Z" fill="#83938c" stroke="#526753"/><path d="M475 252 L565 210 L565 268 L475 310 Z" fill="#6e8277" stroke="#526753"/><text x="365" y="360">顶面 / 前侧 / 右侧 · 原底部接地</text><path d="M705 115 L775 185 M765 166 L775 185 L755 178" fill="none" stroke="#b28d45" stroke-width="5"/><text x="680" y="95">左上柔光</text><path d="M690 265 Q740 255 795 265 L795 276 Q740 266 690 276 Z" fill="#a29373"/><path d="M690 276 Q740 266 795 276 L855 315 L720 325 Z" fill="#87b1ab"/><text x="670" y="360">局部低岸坡 → 水平水面</text><text x="30" y="400" font-size="15">约40°为制作辅助；顶面比例随物件结构变化。不能用此比例挤压现有素材或倾斜湖泊。</text></g></svg>''',encoding='utf-8')
(p/'checks.gd').write_text('''extends SceneTree
var checks:Array=[]
func _initialize()->void:call_deferred("run")
func check(name:String,pass_value:bool,detail:Variant="")->void:
	checks.append({"name":name,"pass":pass_value,"detail":detail})
func run()->void:
	var Candidate=load("res://prototypes/view-v01/generator.gd")
	var counts=[]
	for seed_value in [271828,81273,902106]:
		Engine.set_meta("view_before",false)
		var old=WildGenerator.new(seed_value,1024)
		var gen=Candidate.new(seed_value,1024)
		var same=Candidate.new(seed_value,1024)
		counts.append({"seed":seed_value,"before":old.lakes.size(),"after":gen.lakes.size(),"spawn_biome":gen.biome(gen.spawn)})
		check("lake thinning %d"%seed_value,gen.lakes.size()<old.lakes.size() and gen.lakes.size()>0,counts[-1])
		check("same seed lake retention %d"%seed_value,gen.lakes==same.lakes)
		var unchanged=true
		for lake in gen.lakes:
			if not old.lakes.has(lake):unchanged=false
		check("retained lake geometry %d"%seed_value,unchanged)
		check("macro sites unchanged %d"%seed_value,gen.region_sites==old.region_sites)
		check("spawn inherits macro ground %d"%seed_value,gen.sample(gen.spawn)==old.sample(old.spawn,false))
		check("spawn safe movement %d"%seed_value,gen.can_walk(gen.spawn,30) and gen.can_walk(gen.spawn+Vector2(75,0),30) and gen.can_walk(gen.spawn+Vector2(0,75),30))
		var coord=Vector2i(gen.spawn/WildGenerator.CHUNK_PX)
		var props=gen.props_for_chunk(coord)
		check("props reproducible %d"%seed_value,props==same.props_for_chunk(coord))
		var safe=true
		for prop in props:
			if str(prop.id).begins_with("clearing:") or prop.position.distance_to(gen.spawn)<105:safe=false
		check("no fixed spawn samples / obstacle clearance %d"%seed_value,safe)
		# Small world-coordinate overview; underlying macro fields retain exact original sites.
		for before in [true,false]:
			var source=old if before else gen
			var img=Image.create(512,512,false,Image.FORMAT_RGB8)
			for y in 512:
				for x in 512:
					var v=source.sample(Vector2(x+.5,y+.5)*source.extent/512.0)
					var col=Color(.30,.43,.24)*v.x+Color(.57,.55,.47)*v.y+Color(.51,.64,.34)*v.w
					if v.z>.4:col=col.lerp(Color(.24,.49,.56),smoothstep(.4,.7,v.z))
					img.set_pixel(x,y,col)
			img.save_png("res://prototypes/view-v01/map-%d-%s.png"%[seed_value,"before" if before else "after"])
	var fail=0
	for item in checks:
		if not item.pass:fail+=1
	var result={"candidate_version":"windrest-view-0.1.0","engine":Engine.get_version_info().string,"checks":checks,"failures":fail,"lake_counts":counts,"note":"Map images are generated data visualization, not new painted terrain assets. No full regression or performance benchmark."}
	FileAccess.open("res://prototypes/view-v01/checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	quit(1 if fail else 0)
''',encoding='utf-8')
print('reference and targeted checks written')
