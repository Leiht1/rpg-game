extends "res://scripts/launcher.gd"
var reject_delete:=true
var deletes:=0
func send(op:String,_data:Dictionary)->Dictionary:
	if op=="admin_delete_world":
		deletes+=1
		if reject_delete:
			status.text="世界不存在或仍有在线玩家"
			return {"ok":false}
		return {"ok":true}
	return {"ok":true,"worlds":[{"id":"fixture","name":"测试原野","online":0}],"accounts":[]}
