extends Node
signal profile_changed
var config: Dictionary={}
var token:=""
var profile:Dictionary={}
var cursor:=0
var avatar_cache:Dictionary={}
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
	if not str(config.get("server_url","")).begins_with("https://"):return {"ok":false,"error":"服务器地址须使用HTTPS"}
	var request:=HTTPRequest.new();add_child(request);request.use_threads=true;request.timeout=190 if operation in ["create_world","character","game_snapshot","game_command"] else (8 if operation in ["login","activate"] else 30)
	request.body_size_limit=8*1024*1024
	var cert:=X509Certificate.new()
	var cert_value:String=str(config.get("certificate","server-public.crt")).replace("\\","/")
	var path:String=cert_value if cert_value.is_absolute_path() else config.base_dir.path_join(cert_value)
	if cert.load(path)!=OK:
		request.queue_free();return {"ok":false,"error":"缺少服务器公开证书，请使用管理员发放的客户端配置"}
	request.set_tls_options(TLSOptions.client(cert,config.get("server_name","windrest-server")))
	var payload:=data.duplicate(true);payload.gameplay_revision=1;payload.protocol=config.get("protocol",1);payload.version=config.get("version","0.1.0")
	var headers:=PackedStringArray(["Content-Type: application/json","Authorization: Bearer "+token])
	var url:=str(config.server_url).trim_suffix("/")
	# LAN servers commonly listen on IPv4; do not let localhost's ::1 record
	# prevent connecting to their configured IPv4 listener.
	var authority:=url.get_slice("/",2)
	var host:=authority.get_slice(":",0)
	if host.to_lower()=="localhost":url=url.replace("https://"+host,"https://127.0.0.1")
	var error:=request.request(url+"/api/"+operation,headers,HTTPClient.METHOD_POST,JSON.stringify(payload))
	if error!=OK:request.queue_free();return {"ok":false,"error":"无法发起连接"}
	var result=await request.request_completed;request.queue_free()
	if result[0]!=HTTPRequest.RESULT_SUCCESS:return {"ok":false,"error":"无法连接服务器（"+str(config.server_url)+"）。请确认独立服务器已启动，且内网地址、端口及证书正确。"}
	var response=JSON.parse_string(result[3].get_string_from_utf8())
	if not response is Dictionary:return {"ok":false,"error":"服务器返回数据无效"}
	if response.get("ok",false):
		if response.has("token"):token=response.token
		if response.has("chat_cursor"):cursor=int(response.chat_cursor)
		if response.has("profile"):profile=response.profile;profile_changed.emit()
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
