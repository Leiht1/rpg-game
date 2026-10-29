extends Node
signal profile_changed
var config: Dictionary={}
var token:=""
var profile:Dictionary={}
var cursor:=0
var sync_tokens: Dictionary={}
var sync_state: Dictionary={}
var avatar_cache:Dictionary={}
var http_channels:Dictionary={}
func _init()->void:
	var pack:=OS.get_executable_path().get_base_dir().path_join("Candidates.pck")
	if FileAccess.file_exists(pack):ProjectSettings.load_resource_pack(pack)
func _ready()->void:
	var path:="res://config/network-client.json"
	var external:=OS.get_executable_path().get_base_dir().path_join("Config/network-client.json")
	if FileAccess.file_exists(external):path=external
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--network-config="):path=arg.trim_prefix("--network-config=")
	var value=JSON.parse_string(FileAccess.get_file_as_string(path))
	if value is Dictionary:config=value
	config["base_dir"]=path.get_base_dir()
func call_api(operation:String,data:Dictionary={})->Dictionary:
	var began:=Time.get_ticks_msec()
	if not str(config.get("server_url","")).begins_with("https://"):return {"ok":false,"error":"服务器地址须使用HTTPS"}
	var timeout:=190.0 if operation in ["create_world","character","game_snapshot","game_command"] else (8.0 if operation in ["login","activate"] else 30.0)
	var cert:=X509Certificate.new()
	var cert_value:String=str(config.get("certificate","server-public.crt")).replace("\\","/")
	var path:String=cert_value if cert_value.is_absolute_path() else config.base_dir.path_join(cert_value)
	if cert.load(path)!=OK:
		return {"ok":false,"error":"缺少服务器公开证书，请使用管理员发放的客户端配置"}
	var payload:=data.duplicate(true);payload.gameplay_revision=1;payload.protocol=config.get("protocol",1);payload.version=config.get("version","0.1.0")
	if Engine.has_meta("sync_trace"):payload.sync_timings=1
	if operation in ["resume","character"]:payload.sync_init=1
	var sync_base: Dictionary={}
	if operation in ["game_snapshot","game_command"]:
		payload.sync_delta=1;payload.sync_tokens=sync_tokens.duplicate()
		sync_base=sync_state.duplicate(true)
	var headers:=PackedStringArray(["Content-Type: application/json","Accept-Encoding: gzip","Authorization: Bearer "+token])
	var url:=str(config.server_url).trim_suffix("/")
	# LAN servers commonly listen on IPv4; do not let localhost's ::1 record
	# prevent connecting to their configured IPv4 listener.
	var authority:=url.get_slice("/",2)
	var host:=authority.get_slice(":",0)
	if host.to_lower()=="localhost":url=url.replace("https://"+host,"https://127.0.0.1")
	var lane:=operation if operation in ["move","poll","game_snapshot"] else ("game" if operation in ["game_snapshot","game_command"] else "account")
	if not http_channels.has(lane):http_channels[lane]=preload("res://scripts/network_http_channel.gd").new()
	var port:=int(authority.get_slice(":",1)) if authority.contains(":") else 443
	if host.to_lower()=="localhost":host="127.0.0.1"
	var identity:=url+"|"+path+"|"+str(config.get("server_name","windrest-server"))
	var serialize_start:=Time.get_ticks_usec()
	var request_body:=JSON.stringify(payload)
	var serialize_us:=Time.get_ticks_usec()-serialize_start
	var result:Array=await http_channels[lane].exchange(get_tree(),host,port,TLSOptions.client(cert,config.get("server_name","windrest-server")),identity,"/api/"+operation,headers,request_body,timeout)
	if Engine.has_meta("network_timings"):
		var timings: Dictionary=Engine.get_meta("network_timings")
		if not timings.has(operation):timings[operation]=[]
		timings[operation].append(Time.get_ticks_msec()-began)
	if Engine.get_meta("network_diagnostics",false):print("API_MS ",operation," ",Time.get_ticks_msec()-began," status=",result[1]," ",result[3].get_string_from_utf8().left(100) if result[1]!=200 else "")
	if result[0]!=HTTPRequest.RESULT_SUCCESS:return {"ok":false,"error":"无法连接服务器（"+str(config.server_url)+"）。请确认独立服务器已启动，且内网地址、端口及证书正确。"}
	var parse_start:=Time.get_ticks_usec()
	var response=JSON.parse_string(result[3].get_string_from_utf8())
	if Engine.has_meta("sync_trace"):
		var trace: Dictionary=http_channels[lane].last_trace.duplicate(true)
		trace.serialize_us=serialize_us;trace.parse_start_us=parse_start;trace.parsed_us=Time.get_ticks_usec();trace.operation=operation;trace.request_id=str(data.get("request_id",""))
		Engine.get_meta("sync_trace").requests.append(trace)
	if not response is Dictionary:return {"ok":false,"error":"服务器返回数据无效"}
	if response.get("ok",false) and operation in ["character","login","logout","join_world","create_world","permanent_leave"]:
		sync_tokens.clear();sync_state.clear()
	if response.get("ok",false) and response.get("snapshot_delta",false):
		for key in sync_base.keys():
			if not response.sync_tokens.has(key):sync_base.erase(key)
		for key in response.snapshot:sync_base[key]=response.snapshot[key]
		response.snapshot=sync_base
		# Capture this request's base, never a concurrently replaced cache.
		sync_state=sync_base.duplicate(true);sync_tokens=response.sync_tokens.duplicate()
	elif response.get("ok",false) and response.has("snapshot"):
		sync_state=response.snapshot.duplicate(true);sync_tokens.clear()
	if response.get("ok",false):
		if response.has("token"):token=response.token
		if response.has("chat_cursor"):cursor=int(response.chat_cursor)
		if response.has("profile"):profile=response.profile;profile_changed.emit()
	if Engine.has_meta("sync_trace"):Engine.get_meta("sync_trace").requests[-1].ready_us=Time.get_ticks_usec()
	return response
func avatar(id:String)->Texture2D:
	if avatar_cache.has(id):return avatar_cache[id]
	if id.is_empty():return null
	var response:=await call_api("avatar_get",{"avatar":id})
	if not response.get("ok",false):return null
	var image:=Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(response.image))!=OK:return null
	avatar_cache[id]=ImageTexture.create_from_image(image)
	return avatar_cache[id]
