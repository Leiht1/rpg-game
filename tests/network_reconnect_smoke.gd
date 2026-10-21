extends SceneTree
var checks:=0
func verify(value:bool,label:String)->bool:
	checks+=1
	if not value:push_error("FAIL "+label);quit(1)
	return value
func _initialize()->void:run.call_deferred()
func run()->void:
	var fixture:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):fixture=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--fixture=")))
	var network:=root.get_node("Network")
	var login:Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	if not verify(login.get("ok",false),"login after actual server restart"):return
	var resume:Dictionary=await network.call_api("resume",{})
	if not verify(resume.get("ok",false),"resume after restart"):return
	verify(resume.world.id==fixture.expected_world.id and resume.world.seed==fixture.expected_world.seed,"stable world and seed")
	verify(resume.character.id==fixture.expected_character.id and resume.character.appearance==fixture.expected_character.appearance,"stable character and appearance")
	verify(resume.character.slots==fixture.expected_character.slots and resume.character.equipment==fixture.expected_character.equipment,"inventory and equipped instance restored")
	verify(resume.character.x==fixture.expected_character.x and resume.character.y==fixture.expected_character.y,"last server position restored")
	var messages:Dictionary=await network.call_api("poll",{"cursor":0})
	verify(messages.get("messages",[]).is_empty(),"no chat history after restart")
	print("NETWORK_RESTART_CHECKS ",checks," PASS");quit()
