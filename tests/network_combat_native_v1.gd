extends SceneTree
var fixture: Dictionary
var folder: String
var world: Node
var checks:=0
func verify(ok: bool, label: String) -> void:
	checks+=1
	if not ok:push_error("COMBAT NATIVE FAIL "+label);quit(1);assert(ok,label)
	print("PASS ",label)
func mark(label: String) -> void:
	var file:=FileAccess.open(folder.path_join(label),FileAccess.WRITE);file.store_string("ready");file.close()
func wait_mark(label: String) -> void:
	for i in 1000:
		if FileAccess.file_exists(folder.path_join(label)):return
		await create_timer(.05).timeout
	verify(false,"marker timeout "+label)
func settle() -> void:
	for i in 200:
		await create_timer(.05).timeout
		if world.commands.is_empty() and not world.requesting:return
	verify(false,"command queue timeout")
func press_f() -> void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_F;event.pressed=true;Input.parse_input_event(event)
	await process_frame;event.pressed=false;Input.parse_input_event(event)
	await create_timer(1.3).timeout;await settle()
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			folder=arg.trim_prefix("--fixture=").get_base_dir();fixture=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--fixture=")))
	var network=root.get_node("Network")
	var login: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	verify(login.get("ok",false),"login");mark("login"+str(int(fixture.index)));await wait_mark("login"+str(1-int(fixture.index)))
	var resume: Dictionary=await network.call_api("resume",{})
	var entered: Dictionary=await network.call_api("character",{"gameplay_revision":1,"appearance":resume.character.appearance})
	verify(entered.get("ok",false),"enter original network world")
	var initial: Dictionary=await network.call_api("game_snapshot",{});verify(initial.get("ok",false),"server snapshot")
	entered.initial_snapshot=initial.snapshot
	world=load("res://scripts/network_game_world.gd").new();world.session_data=entered;root.add_child(world);current_scene=world
	for i in 800:
		await create_timer(.05).timeout
		if world.started and world.actors.size()==1:break
	verify(world.started and world.actors.size()==1,"two real clients and remote rig")
	mark("loaded"+str(int(fixture.index)));await wait_mark("loaded"+str(1-int(fixture.index)))
	var combat=world.item_service.combat;var inv=world.item_service.inventory
	world.player.facing="right" if int(fixture.index)==0 else "left"
	var remote: Node=world.actors.values()[0];var other:=str(remote.get_meta("combat_id"))
	verify(inv.equipment.main_hand.item_id=="wood_club","server weapon instance")
	if int(fixture.index)==0:
		await press_f();mark("safe-attack");await wait_mark("safe-checked")
		combat.duel(other,true);await settle();mark("offer");await wait_mark("accepted")
		await press_f();mark("first-hit");await wait_mark("reply-hit")
		verify(world.item_service.body.health<=91.2 and world.item_service.body.health>0,"peer attack authoritative damage")
		combat.duel(other,false);await settle();mark("duel-ended");await wait_mark("declined-attack")
		verify(world.item_service.body.health>90.9,"ended duel cannot damage")
		mark("release-boar")
		for i in 500:
			await create_timer(.05).timeout
			if combat.personal.phase=="dying":break
		verify(combat.personal.phase=="dying","boar causes formal death once")
		verify(inv.count_item("wood")==0 and inv.count_item("plaster")==2,"death resource retention")
		var serial: int=int(combat.personal.serial)
		await create_timer(.6).timeout
		get_root().get_texture().get_image().save_png("res://reports/.tmp/combat-v1/network-death.png")
		for i in 500:
			await create_timer(.05).timeout
			if combat.personal.phase=="alive":break
		verify(combat.personal.phase=="alive" and int(combat.personal.serial)==serial,"one respawn unlock")
		verify(inv.equipment.main_hand.item_id=="wood_club","weapon retained after death")
		verify(combat.state.relics.size()==1,"one shared persisted relic")
		mark("death-done")
	else:
		await wait_mark("safe-attack");verify(world.item_service.body.health==100,"no consent no damage");mark("safe-checked")
		await wait_mark("offer");combat.duel(other,true);await settle();mark("accepted")
		await wait_mark("first-hit");verify(world.item_service.body.health<=91.2 and world.item_service.body.health>0,"accepted duel takes one hit")
		await press_f();mark("reply-hit");await wait_mark("duel-ended")
		await press_f();mark("declined-attack");await wait_mark("death-done")
		verify(inv.count_item("wood")==7,"other player's inventory untouched")
		verify(combat.state.relics.size()==1,"remote relic synchronized")
	world.stopping=true
	if int(fixture.index)==1:
		var old_token: String=network.token
		var relogin: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
		verify(relogin.get("ok",false) and network.token!=old_token,"new session reconnects after old client stops")
		var reenter: Dictionary=await network.call_api("character",{"gameplay_revision":1,"appearance":resume.character.appearance})
		verify(reenter.get("ok",false),"reconnect reenters existing character")
		var restored: Dictionary=await network.call_api("game_snapshot",{})
		verify(restored.get("ok",false) and restored.snapshot.combat_world.relics.size()==1,"reconnect restores shared relic")
		var wood:=0
		for value in restored.snapshot.slots:
			if value.get("item_id")=="wood":wood+=int(value.count)
		verify(wood==7,"reconnect retains personal inventory")
		await network.call_api("leave_lobby",{})
	else:await network.call_api("leave_lobby",{})
	world.queue_free();await process_frame
	print("COMBAT_NATIVE_PASS ",checks);quit()
