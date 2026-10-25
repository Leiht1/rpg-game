extends Node2D
const ART="res://assets/exploration/mine-scene-v2/"
const LAMP_ROCK_ART="res://assets/exploration/mine-lamps-rocks-v3/"
const Geometry=preload("res://scripts/mine_puzzle_geometry.gd")
var visual_config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LAMP_ROCK_ART+"visuals.json"))
var s: Node
var targets: Dictionary={}
var art: Dictionary={}
var ores: Dictionary={}
var rubble: Node2D
var initialized:=false
var previous_solved:=false
var previous_progress:=0
var clock:=10.0
var failure_time:=0.0
var dust: Array=[]
var barrier: StaticBody2D
var rubble_parts: Array[Sprite2D]=[]
var heap_base:=Vector2.ZERO
var shaking:=false
var camera_base:=Vector2.ZERO
var lamp_textures: Dictionary={}
var puzzle: RefCounted:
	get:return s.chapter.puzzle
func sprite(file: String, width: float, position: Vector2, parent: Node2D) -> Sprite2D:
	var node:=Sprite2D.new();node.texture=load(file);node.scale=Vector2.ONE*width/node.texture.get_width();node.position=position;parent.add_child(node);return node
func target(kind: String, at: Vector2, caption: String) -> Node2D:
	var node:=Node2D.new();node.position=at;node.set_meta("mine_kind",kind);node.set_meta("display_name",caption.trim_prefix("E "));node.set_meta("mine_caption",caption)
	node.set_meta("interaction_action","inspect");node.set_meta("interaction_range",float(puzzle.config.range));node.add_to_group("world_interactables");s.world.object_root.add_child(node);targets[kind]=node;return node
func build() -> void:
	for i in 4:
		var lamp:=target("lamp:"+str(i),puzzle.point("lamps",i),"E 触碰石灯")
		lamp_textures[i]={"on":load(LAMP_ROCK_ART+"lamp-%d-on.png"%i),"off":load(LAMP_ROCK_ART+"lamp-%d-off.png"%i)}
		var pic:=sprite(LAMP_ROCK_ART+"lamp-%d-off.png"%i,float(visual_config.lamp.width),Vector2.ZERO,lamp);art[i]=pic
		pic.centered=false;pic.position=-Vector2(visual_config.lamp.anchor[0],visual_config.lamp.anchor[1])*pic.scale
		pic.set_meta("rest",pic.position)
		Geometry.body(lamp,"lamp")
		# The reference stone and engraved recess are identical in both textures.
		# Only the actual chamber contains or loses its flame; no whole-stone tint.
		var clue:=target("carving:"+str(i),puzzle.point("carvings",i),"E 调查岩壁")
		var at: Array=puzzle.config.wall_art[i]
		var carving:=sprite(ART+"glyph-%d.png"%i,48,Vector2(at[0],at[1])-(clue.position-s.chapter.mine.origin()),clue);carving.name="WallEtching";carving.modulate=Color(.68,.65,.59,.82);carving.z_index=-5
	var chest:=target("chest",puzzle.point("chest"),"E 打开旧木箱")
	art.chest=sprite(ART+"chest-closed.png",94,Vector2(0,-33),chest)
	var chest_body:=Geometry.body(chest,"chest");chest_body.name="ChestVolume"
	heap_base=puzzle.point("rubble")
	rubble=Node2D.new();rubble.position=heap_base+Vector2(0,107);s.world.object_root.add_child(rubble)
	# Build the heap from whole independently generated rocks, never heap slices.
	for spec in visual_config.stones:
		var part:=sprite(LAMP_ROCK_ART+str(spec.texture),float(spec.width),Vector2(spec.at[0],spec.at[1]),rubble)
		part.position.y-=part.texture.get_height()*part.scale.y*.5+107
		part.set_meta("rest",part.position);part.set_meta("fixed_scale",part.scale);rubble_parts.append(part)
	barrier=Geometry.body(rubble,"rubble",Vector2(0,-107))
	previous_solved=puzzle.state.solved;previous_progress=puzzle.state.progress;initialized=true
func sync() -> void:
	if s.chapter.mine.state.site.is_empty():return
	if not initialized:build()
	var inside: bool=s.chapter.mine.travel.inside
	visible=inside
	for kind in targets:
		var node: Node2D=targets[kind];node.visible=inside
		var active: bool=inside and (kind!="chest" or puzzle.state.solved)
		if active and not node.is_in_group("world_interactables"):node.add_to_group("world_interactables")
		elif not active and node.is_in_group("world_interactables"):node.remove_from_group("world_interactables")
	if puzzle.state.solved and not previous_solved:
		clock=0.0 if inside else 10.0
		if inside:
			camera_base=s.world.player.camera.offset;shaking=true;AudioFX.play_sfx("sfx_ore_break",puzzle.point("rubble"))
	if previous_progress>0 and puzzle.state.progress==0:
		failure_time=.4
		if inside:AudioFX.play_sfx("sfx_mine_hit",s.chapter.mine.origin())
	previous_progress=puzzle.state.progress;previous_solved=puzzle.state.solved
	for i in 4:
		var lit: bool=i in puzzle.state.order
		art[i].texture=lamp_textures[i]["on" if lit else "off"];art[i].modulate=Color.WHITE
		art[i].position=art[i].get_meta("rest")+Vector2(sin(failure_time*75)*1.2 if failure_time>0 else 0.0,0)
	var revealed: bool=puzzle.state.solved and clock>=float(puzzle.config.reveal_seconds)
	barrier.get_child(0).set_deferred("disabled",puzzle.state.solved)
	targets.chest.get_node("ChestVolume").get_child(0).set_deferred("disabled",not puzzle.state.solved)
	# Rewards are physically behind the overlapping stones, not faded into empty space.
	var reveal_alpha: float=1.0 if puzzle.state.solved else 0.0
	targets.chest.visible=inside and puzzle.state.solved
	targets.chest.modulate.a=reveal_alpha
	if not revealed:targets.chest.remove_from_group("world_interactables")
	art.chest.texture=load(ART+("chest-open.png" if puzzle.state.chest_open else "chest-closed.png"))
	for i in 3:
		var active: bool=inside and puzzle.state.solved and puzzle.state.ores[i].hits<int(puzzle.config.hits)
		if ores.has(i) and (not is_instance_valid(ores[i]) or ores[i].get_meta("spent",false)):ores.erase(i)
		if ores.has(i) and not active:ores[i].queue_free();ores.erase(i)
		if active and not ores.has(i):
			var node:=preload("res://scripts/mine_crystal.gd").new();node.service=s;node.resource_id="mine_crystal_"+str(i);node.kind="crystal_ore";node.position=puzzle.point("ores",i);node.set_meta("crystal_index",i);s.world.object_root.add_child(node);ores[i]=node
		if ores.has(i):
			ores[i].refresh_stage();ores[i].modulate.a=reveal_alpha
			if revealed and not ores[i].is_in_group("world_interactables"):ores[i].add_to_group("world_interactables")
			elif not revealed and ores[i].is_in_group("world_interactables"):ores[i].remove_from_group("world_interactables")
func _process(delta: float) -> void:
	sync()
	if not initialized:return
	clock+=delta;failure_time=maxf(0,failure_time-delta)
	var duration: float=puzzle.config.reveal_seconds
	var animating: bool=puzzle.state.solved and clock<duration and visible
	rubble.visible=visible and (not puzzle.state.solved or animating)
	for i in rubble_parts.size():
		var part: Sprite2D=rubble_parts[i];part.visible=not puzzle.state.solved or animating
		if animating:
			var spec: Dictionary=visual_config.stones[i]
			var t: float=clampf((clock-float(spec.start))/float(spec.duration),0,1)
			part.position=part.get_meta("rest")+Vector2(float(spec.slide[0])*t,float(spec.slide[1])*t*t)+Vector2(sin(clock*45+i)*.65*(1-t),0)
			part.rotation=float(spec.rotation)*t
			part.modulate.a=1-smoothstep(.72,1,t);part.visible=t<1
		elif not puzzle.state.solved:
			part.position=part.get_meta("rest");part.rotation=0;part.modulate.a=1.0
	if animating:
		var t: float=clampf((clock-.35)/(duration-.35),0,1)
		s.world.player.camera.offset=camera_base+Vector2(sin(clock*43),cos(clock*37))*1.6*maxf(0,1-clock/1.1)
		queue_redraw()
	else:
		if shaking:s.world.player.camera.offset=camera_base;shaking=false
		if not dust.is_empty():dust.clear();queue_redraw()
func _draw() -> void:
	if not visible or not initialized or not puzzle.state.solved or clock>=float(puzzle.config.reveal_seconds):return
	var t: float=clock/float(puzzle.config.reveal_seconds)
	for i in 26:
		var seed_value: float=float(i)*19.73
		var start: Vector2=puzzle.point("rubble")+Vector2(sin(seed_value)*180,-135-cos(seed_value*2)*45)
		var p: Vector2=start+Vector2(sin(seed_value*3)*clock*35,clock*clock*75)
		draw_circle(p,2.0+float(i%3),Color(.45,.42,.36,(1-t)*.7))
	for i in 8:
		draw_circle(puzzle.point("rubble")+Vector2(sin(i*8.7)*170,-15)+Vector2(sin(i*2.7)*clock*22,-clock*35),16+clock*17,Color(.53,.48,.39,(1-t)*.13))
	dust=[true]
func _exit_tree() -> void:
	for node in targets.values()+ores.values()+[rubble]:
		if is_instance_valid(node):node.queue_free()
