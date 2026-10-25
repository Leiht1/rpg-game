extends "res://tests/coastal_route_network_v6.gd"
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="):
			folder=argument.trim_prefix("--fixture=").get_base_dir();fixture=JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--fixture=")))
	var network=root.get_node("Network")
	var response: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	verify(response.get("ok",false),"login")
	await barrier("login")
	response=await network.call_api("resume",{})
	var entered: Dictionary=await network.call_api("character",{"appearance":response.character.appearance})
	verify(entered.get("ok",false),"character")
	await barrier("entered")
	var snapshot: Dictionary=await network.call_api("game_snapshot",{})
	verify(snapshot.get("ok",false),"authoritative snapshot")
	if not snapshot.get("ok",false):quit(1);return
	entered.initial_snapshot=snapshot.snapshot;world=load("res://scripts/network_game_world.gd").new();world.session_data=entered;root.add_child(world);current_scene=world
	for i in 500:
		if world.started and world.actors.size()==1:break
		await create_timer(.05).timeout
	verify(world.started and world.actors.size()==1,"two native clients see each other")
	world.player.set_physics_process(false)
	var s=world.item_service;var f=s.chapter.finale
	s.notice.connect(func(message):print("NOTICE ",message))
	print("BATTLE_START ",JSON.stringify({"boss":f.state.boss,"player":world.player.position,"weapon":s.combat.weapon(),"phase":s.combat.personal.phase}))
	verify(not f.state.defeated and not f.state.chest_open,"boss and locked chest shared before battle")
	await barrier("loaded")
	for i in 20:
		if f.state.defeated:break
		var result: String=s.combat.attack((f.boss_at()-world.player.position).normalized());await settled();await create_timer(.75).timeout
		print("BATTLE_STEP ",i," result=",result," hp=",f.state.boss.health," mode=",f.state.boss.mode," at=",f.boss_at()," player=",world.player.position," personal=",s.combat.personal.phase)
	verify(f.state.defeated,"real melee attacks defeat shared guardian")
	await barrier("dead")
	# Disconnect after the victory transaction and before either reward is taken.
	world.stopping=true
	for i in 200:
		if not world.requesting and not world.moving_request and not world.polling:break
		await create_timer(.03).timeout
	network.token="";var victory_login: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password});verify(victory_login.get("ok",false),"reconnect immediately after victory before loot")
	var victory_resume: Dictionary=await network.call_api("resume",{});await network.call_api("character",{"appearance":victory_resume.character.appearance})
	var victory_snapshot: Dictionary=await network.call_api("game_snapshot",{})
	verify(victory_snapshot.get("ok",false) and victory_snapshot.snapshot.exploration_chapter.finale.defeated and not victory_snapshot.snapshot.exploration_chapter.finale.core_claimed and not victory_snapshot.snapshot.exploration_chapter.finale.chest_open,"victory survives disconnect with unclaimed rewards intact")
	world.apply_snapshot(victory_snapshot.snapshot);world.stopping=false;await barrier("victory-reconnected")
	s.chapter.mine.interact("final:core");await settled();await barrier("core")
	s.chapter.mine.interact("final:chest");await settled();await barrier("chest")
	for i in 100:
		if f.state.core_claimed and f.state.chest_open:break
		await create_timer(.1).timeout
	verify(f.state.core_claimed and f.state.chest_open,"concurrent loot intents settle once")
	if s.inventory.count_item(f.LETTER)>0:
		s.chapter.use_item(f.LETTER);await settled();verify(s.chapter_view.route_visible,"illustrated ocean record on receiving client");s.chapter_view.close_page()
	if s.inventory.count_item(f.BLUEPRINT)>0:s.chapter.use_item(f.BLUEPRINT)
	await settled();await barrier("blueprint");await create_timer(.7).timeout
	verify(f.state.dock_unlocked,"dock unlock shared across both clients")
	# Repeated intents after settlement and a fresh authenticated connection.
	s.chapter.mine.interact("final:core");s.chapter.mine.interact("final:chest");await settled();world.stopping=true
	network.token="";var again: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password});verify(again.get("ok",false),"fresh authentication")
	var resumed: Dictionary=await network.call_api("resume",{});await network.call_api("character",{"appearance":resumed.character.appearance})
	var final: Dictionary=await network.call_api("game_snapshot",{});verify(final.get("ok",false),"restored snapshot")
	var last: Dictionary=final.snapshot.exploration_chapter.finale
	verify(last.defeated and last.core_claimed and last.chest_open and last.dock_unlocked,"death and all rewards survive reconnect")
	var counts: Dictionary={"cores":0,"letters":0,"blueprints":0}
	for slot in final.snapshot.slots:
		if slot.get("item_id")==f.CORE:counts.cores+=int(slot.count)
		if slot.get("item_id")==f.LETTER:counts.letters+=int(slot.count)
		if slot.get("item_id")==f.BLUEPRINT:counts.blueprints+=int(slot.count)
	counts.merge({"checks":checks,"failed":failed,"defeated":last.defeated,"chest_open":last.chest_open,"dock_unlocked":last.dock_unlocked})
	FileAccess.open("res://reports/final-chapter-v1/network/client"+str(int(fixture.index))+".json",FileAccess.WRITE).store_string(JSON.stringify(counts))
	print("FINAL CHAPTER NETWORK ",fixture.index,": ",checks," checks failed=",failed)
	Engine.remove_meta("network_game_controller");world.queue_free();await process_frame;quit(1 if failed else 0)
