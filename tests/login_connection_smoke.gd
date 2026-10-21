extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var network=root.get_node("Network")
	var response:Dictionary=await network.call_api("login",{"username":"__connection_probe_missing__","password":"invalid-probe-password"})
	assert(not response.get("ok",false))
	assert(not str(response.get("error","")).contains("无法连接"),"Local TLS server must answer login")
	print("LOGIN_SERVER_RESPONSE_PASS")
	network.config.server_url="https://192.0.2.1:24870"
	var app=load("res://scenes/launcher.tscn").instantiate();root.add_child(app);current_scene=app
	var started:=Time.get_ticks_msec()
	response=await app.send("login",{"username":"probe","password":"invalid"})
	assert(not response.get("ok",false))
	assert(Time.get_ticks_msec()-started<11000,"Login must stop waiting within bounded timeout")
	assert(not app.busy,"Failure must unlock buttons")
	assert(app.status.text.contains("无法连接服务器"))
	print("LOGIN_TIMEOUT_RECOVERY_PASS ",Time.get_ticks_msec()-started)
	quit()
