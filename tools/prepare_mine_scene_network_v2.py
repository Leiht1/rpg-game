from pathlib import Path
p=Path('tests/run_mine_network_v1.py').read_text(encoding='utf-8')
p=p.replace('reports/mine-v1/network','reports/mine-scene-v2/network').replace('tests/mine_network_v1.gd','tests/mine_scene_network_v2.gd')
p=p.replace("chapter['mine'].update(phase='sealed',recipe=True,investigated=True,fuse_due=-1,opened_at=-1,entered=False)","chapter['mine'].update(phase='open',recipe=True,investigated=True,fuse_due=0,opened_at=0,entered=True,fuse_remaining_seconds=0)\n        chapter['mine'].pop('puzzle',None)")
p=p.replace("point=chapter['mine']['site']", "point={'x':saved['player_position']['x']-190,'y':4096+130}")
p=p.replace("c['gameplay']['mine_travel']={'inside':False,'serial':0}","c['gameplay']['mine_travel']={'inside':True,'serial':1}")
p=p.replace("c['y']=point['y']+115","c['y']=point['y']+55")
p=p.replace('"MINE NETWORK"','"MINE SCENE NETWORK"')
p=p.replace("assert sum(r['packs'] for r in results)==1, 'exactly one shared placement cost'", "assert all(r['solved'] for r in results), 'shared solve on both clients'")
p=p.replace("assert results[0]['inside'] and not results[1]['inside'], 'personal region isolation'", "assert all(r['inside'] for r in results), 'both clients remain in original mine region'")
p=p.replace("print('MINE GLOBAL: one cost; personal region isolation; fresh authentication preserved')", "print('MINE SCENE GLOBAL: shared lamps, simultaneous solve, new art, reconnect preserved')")
Path('tests/run_mine_scene_network_v2.py').write_text(p,encoding='utf-8')
base=Path('tests/mine_network_v1.gd').read_text(encoding='utf-8')
prefix=base.split('\tvar q=world.item_service.chapter;var m=q.mine')[0]
body='''	var q=world.item_service.chapter;var m=q.mine;var p=q.puzzle
	var view=world.item_service.chapter_view.get_node("PuzzleView")
	verify(m.travel.inside and not p.state.solved,"old mine state migrates inside without reset")
	verify(view.targets.size()==10 and view.ores.is_empty(),"new layout hidden reward on both clients")
	verify(view.art.chest.texture.resource_path.contains("mine-scene-v2"),"new buried chest on both clients")
	await barrier("loaded")
	# Two real authenticated E intents at the same first lamp: one advances, next resets.
	m.interact("lamp:0")
	await settled();await barrier("same-first");await create_timer(1).timeout
	verify(p.state.progress==0,"simultaneous same lamp produces one shared reset")
	if int(fixture.index)==0:
		for i in 3:
			await walk_to(p.point("lamps",i)+Vector2(0,52));m.interact("lamp:"+str(i));await settled()
	await barrier("three-lit");await create_timer(1).timeout
	verify(p.state.progress==3,"both clients see three matching persistent lamps")
	await walk_to(p.point("lamps",3)+Vector2(-8+int(fixture.index)*16,52))
	await barrier("last-ready");m.interact("lamp:3");await settled();await create_timer(3).timeout
	verify(p.state.solved and p.state.progress==4,"simultaneous final lamp commits once permanently")
	verify(not view.rubble.visible and view.rubble_parts.all(func(n):return not n.visible),"both clients finish same side collapse")
	verify(view.ores.size()==3 and view.targets.chest.visible,"both clients reveal three ores and buried chest")
	verify(not view.art.chest.texture.resource_path.contains("buildings/"),"reward chest does not reuse camp visuals")
	verify(world.player.camera.offset==Vector2.ZERO,"camera shake restores original coordinates")
	await barrier("solved")
	world.stopping=true;network.token=""
	var login_again: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	verify(login_again.get("ok",false),"fresh authentication")
	var resumed: Dictionary=await network.call_api("resume",{})
	var entered_again: Dictionary=await network.call_api("character",{"appearance":resumed.character.appearance})
	verify(entered_again.get("ok",false),"reenter original world")
	var final: Dictionary=await network.call_api("game_snapshot",{})
	verify(final.get("ok",false) and final.snapshot.exploration_chapter.mine.puzzle.solved,"reconnect preserves completed puzzle")
	verify(final.snapshot.mine_travel.inside,"reconnect preserves original personal region")
	FileAccess.open("res://reports/mine-scene-v2/network/client"+str(int(fixture.index))+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"solved":p.state.solved,"inside":m.travel.inside,"failed":failed}))
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/mine-scene-v2/network/client"+str(int(fixture.index))+".png")
	print("MINE SCENE NETWORK ",fixture.index,": ",checks," checks failed=",failed)
	Engine.remove_meta("network_game_controller");world.queue_free();await process_frame;quit(1 if failed else 0)
func settled() -> void:
	for i in 200:
		if world.commands.is_empty():break
		await create_timer(.05).timeout
	await create_timer(.25).timeout
func walk_to(target: Vector2) -> void:
	world.player.automated=true;world.player.set_physics_process(true)
	for i in 500:
		var delta: Vector2=target-world.player.position
		if delta.length()<12:break
		world.player.input_override=delta.normalized();await create_timer(.035).timeout
	world.player.input_override=Vector2.ZERO;await create_timer(.5).timeout;world.player.set_physics_process(false)
	verify(world.player.position.distance_to(target)<35,"original network movement reaches lamp")
'''
suffix='func barrier(label: String) -> void:'+base.split('func barrier(label: String) -> void:')[1]
Path('tests/mine_scene_network_v2.gd').write_text(prefix+body+suffix,encoding='utf-8')
