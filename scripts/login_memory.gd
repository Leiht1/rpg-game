extends RefCounted

static func path(config:Dictionary)->String:
	return str(config.get("login_cache","user://login-memory.json"))

static func helper_path()->String:
	var helper:=OS.get_executable_path().get_base_dir().path_join("LoginVault.exe")
	if FileAccess.file_exists(helper):return helper
	helper=ProjectSettings.globalize_path("res://dist/network-v0.1.0/Client/LoginVault.exe")
	if FileAccess.file_exists(helper):return helper
	# Source runs have no adjacent packaged helper. Build the same DPAPI helper
	# into user data; exported clients keep using their bundled executable.
	var source:=ProjectSettings.globalize_path("res://tools/network/LoginVault.cs")
	if OS.get_name()!="Windows" or not FileAccess.file_exists(source):return ""
	helper=ProjectSettings.globalize_path("user://LoginVault-v1.exe")
	if FileAccess.file_exists(helper):return helper
	var compiler:=OS.get_environment("WINDIR").path_join("Microsoft.NET/Framework64/v4.0.30319/csc.exe")
	if not FileAccess.file_exists(compiler):return ""
	var output: Array=[]
	if OS.execute(compiler,PackedStringArray(["/nologo","/reference:System.Security.dll","/out:"+helper.replace("/","\\"),source.replace("/","\\")]),output)!=0:return ""
	return helper if FileAccess.file_exists(helper) else ""

static func crypt(value:PackedByteArray,mode:String)->PackedByteArray:
	var helper:=helper_path()
	if helper.is_empty():return PackedByteArray()
	var process:=OS.execute_with_pipe(helper,PackedStringArray([mode]))
	if process.is_empty():return PackedByteArray()
	var pipe:FileAccess=process.stdio
	pipe.store_line(Marshalls.raw_to_base64(value));pipe.flush()
	var result:=pipe.get_line()
	pipe.close()
	return Marshalls.base64_to_raw(result)

static func read(config:Dictionary)->Dictionary:
	if not FileAccess.file_exists(path(config)):return {}
	var row=JSON.parse_string(FileAccess.get_file_as_string(path(config)))
	if not row is Dictionary or row.get("server")!=config.get("server_url"):return {}
	var result:={"username":str(row.get("username","")),"password":"","remember":false}
	if not str(row.get("secret","")).is_empty():
		result.password=crypt(Marshalls.base64_to_raw(row.secret),"unprotect").get_string_from_utf8()
		result.remember=not result.password.is_empty()
	return result

static func save(config:Dictionary,username:String,password:String,remember:bool)->bool:
	var secret:=crypt(password.to_utf8_buffer(),"protect") if remember else PackedByteArray()
	if remember and secret.is_empty():return false
	var file:=FileAccess.open(path(config),FileAccess.WRITE)
	if not file:return false
	file.store_string(JSON.stringify({"server":config.get("server_url"),"username":username,"secret":Marshalls.raw_to_base64(secret) if not secret.is_empty() else ""}))
	file.close()
	return not remember or not secret.is_empty()
