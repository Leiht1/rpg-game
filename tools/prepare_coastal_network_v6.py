from pathlib import Path
p=Path('tests/run_mine_scene_network_v2.py').read_text(encoding='utf-8')
p=p.replace('mine-scene-v2/network','coastal-route-v6/network').replace('tests/mine_scene_network_v2.gd','tests/coastal_route_network_v6.gd').replace('24872','24876')
p=p.replace("chapter['mine'].pop('puzzle',None)","chapter['mine']['puzzle']=json.loads((ROOT/'reports/coastal-route-v6/ready.json').read_text(encoding='utf-8'))['exploration_chapter']['mine']['puzzle'];chapter['mine']['puzzle'].update(claimed=False,chest_open=False,read=False,read_at=-1,next_due=-1)")
p=p.replace("point={'x':saved['player_position']['x']-190,'y':4096+130}","cfg=json.loads((ROOT/'data/mine_puzzle.json').read_text(encoding='utf-8'));point={'x':options.cells*48+4096+cfg['chest'][0],'y':4096+cfg['chest'][1]}")
p=p.replace("c['slots'][8]={'item_id':'miner_blast_pack','count':1}","# Empty inventory; real chest claim supplies the only record.")
p=p.replace('"MINE SCENE NETWORK"','"COASTAL ROUTE NETWORK"')
p=p.replace("assert all(r['solved'] for r in results), 'shared solve on both clients'","assert sum(r['records'] for r in results)==1, 'world-unique original record'\n                assert results[0]['hint']==results[1]['hint'], 'both clients agree on coastal clue'\n                assert results[0]['due']==results[1]['due'], 'same original shared wait'")
p=p.replace("print('MINE SCENE GLOBAL: shared lamps, simultaneous solve, new art, reconnect preserved')","print('COASTAL ROUTE GLOBAL: one original item; same coastal hint and wait; reread and reconnect')")
Path('tests/run_coastal_route_network_v6.py').write_text(p,encoding='utf-8')
base=Path('tests/mine_scene_network_v2.gd').read_text(encoding='utf-8');prefix=base.split('\tvar q=world.item_service.chapter;var m=q.mine')[0]
body='''	var s=world.item_service;var q=s.chapter;var m=q.mine;var p=q.puzzle;var ui=s.chapter_view
	verify(p.state.solved and not p.state.claimed,"existing completed world before real chest award")
	await barrier("loaded");m.interact("chest");await settled();await barrier("claimed")
	verify(p.state.claimed and p.state.chest_open,"shared existing chest settlement")
	if s.inventory.count_item(p.RECORD)>0:q.use_item(p.RECORD)
	else:m.interact("chest")
	await settled();await create_timer(.6).timeout
	verify(ui.route_visible and ui.route_paper.visible and not ui.words.visible,"actual painted route reading on both clients")
	verify(ui.route_paper.picture.texture.resource_path.contains("coastal-route-v6"),"new flat coastal route resource")
	var hint: Dictionary=p.route_hint.resolve(s);var due: float=p.state.next_due
	verify(hint.direction_resolved and hint.source_rock_region!=hint.connected_rock_region,"distinct coastal rock region resolved")
	verify(hint.terrain=="sea_eroded_ruins_plateau" and not hint.target_generated,"future platform contract without creating location")
	verify(ui.route_paper.hint==hint,"rendered compass uses same real world contract")
	verify(ui.reading_layer.layer>s.world.item_ui.obtained.layer,"reward UI stays behind map")
	ui.close_page()
	if s.inventory.count_item(p.RECORD)>0:q.use_item(p.RECORD)
	else:m.interact("chest")
	await settled();verify(p.state.next_due==due and ui.route_visible,"repeated reading does not restart original wait")
	await barrier("read");await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/coastal-route-v6/network/client"+str(int(fixture.index))+".png")
	world.stopping=true;network.token=""
	var login_again: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	verify(login_again.get("ok",false),"fresh authenticated session")
	var resumed: Dictionary=await network.call_api("resume",{})
	var entered_again: Dictionary=await network.call_api("character",{"appearance":resumed.character.appearance})
	verify(entered_again.get("ok",false),"resume original character")
	var final: Dictionary=await network.call_api("game_snapshot",{})
	verify(final.get("ok",false) and final.snapshot.exploration_chapter.mine.puzzle.read and final.snapshot.exploration_chapter.mine.puzzle.next_due==due,"read state and shared deadline survive authentication")
	var records:=0
	for slot in final.snapshot.slots:
		if slot.get("item_id")==p.RECORD:records+=int(slot.count)
	FileAccess.open("res://reports/coastal-route-v6/network/client"+str(int(fixture.index))+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"records":records,"hint":hint,"due":due,"inside":final.snapshot.mine_travel.inside,"failed":failed}))
	print("COASTAL ROUTE NETWORK ",fixture.index,": ",checks," checks failed=",failed)
	Engine.remove_meta("network_game_controller");world.queue_free();await process_frame;quit(1 if failed else 0)
func settled() -> void:
	for i in 200:
		if world.commands.is_empty():break
		await create_timer(.05).timeout
	await create_timer(.4).timeout
'''
suffix='func barrier(label: String) -> void:'+base.split('func barrier(label: String) -> void:')[1]
Path('tests/coastal_route_network_v6.gd').write_text(prefix+body+suffix,encoding='utf-8')
