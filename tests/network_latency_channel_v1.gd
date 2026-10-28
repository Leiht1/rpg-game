extends "res://scripts/network_http_channel.gd"
var audit_rows: Array=[]
var record_roster:=false
func exchange(tree: SceneTree, host: String, port: int, tls: TLSOptions, identity: String, path: String, headers: PackedStringArray, body: String, timeout: float) -> Array:
	var data: Dictionary=JSON.parse_string(body)
	var row:={"operation":path.get_file(),"request_id":str(data.get("request_id","")),"queued_us":Time.get_ticks_usec(),"sent_us":0,"completed_us":0}
	audit_rows.append(row)
	var result: Array=await super.exchange(tree,host,port,tls,identity,path,headers,body,timeout)
	row.completed_us=Time.get_ticks_usec();row.status=result[1]
	row.received_at_us=Time.get_unix_time_from_system()*1000000
	row.decoded_bytes=result[3].size()
	if record_roster or path.ends_with("game_command"):
		var reply=JSON.parse_string(result[3].get_string_from_utf8())
		if reply is Dictionary:
			row.game_operation=str(data.get("operation",""))
			row.command_ok=reply.get("ok",false)
			row.reply_attack=reply.get("snapshot",{}).get("combat_personal",{}).get("attack",{}).duplicate(true)
			if record_roster:
				row.players=[]
				for player in reply.get("players",[]):row.players.append({"id":player.id,"attacking":not player.get("combat",{}).get("attack",{}).is_empty(),"elapsed":player.get("combat",{}).get("attack",{}).get("elapsed",-1)})
	for header in result[2]:
		if str(header).to_lower().begins_with("content-length:"):row.http_body_bytes=int(str(header).get_slice(":",1))
	return result
func perform(tree: SceneTree, host: String, port: int, tls: TLSOptions, identity: String, path: String, headers: PackedStringArray, body: String, deadline: int) -> Array:
	var data: Dictionary=JSON.parse_string(body)
	for row in audit_rows:
		if row.sent_us==0 and row.operation==path.get_file() and row.request_id==str(data.get("request_id","")):
			row.sent_us=Time.get_ticks_usec();break
	return await super.perform(tree,host,port,tls,identity,path,headers,body,deadline)
