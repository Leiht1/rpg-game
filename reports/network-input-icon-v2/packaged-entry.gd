extends SceneTree
var app:Node
var seen_loading:=false
func _initialize():run.call_deferred()
func _process(_delta):
 if is_instance_valid(app) and is_instance_valid(app.loading_layer) and app.loading_layer.visible:seen_loading=true
 return false
func run():
 var network=root.get_node("Network")
 var fixtures=JSON.parse_string(FileAccess.get_file_as_string("D:/codex项目/rpg/reports/network-v01/private/clients.json"))
 var response=await network.call_api("login",{"username":fixtures[0].username,"password":fixtures[0].password})
 if not response.get("ok",false):push_error("test login failed");quit(1);return
 app=load("res://scenes/launcher.tscn").instantiate();root.add_child(app)
 await process_frame
 await app.resume_online()
 if not is_instance_valid(app.active_world) or not seen_loading or app.loading_layer.visible or app.active_world.stream.loaded.is_empty():
  push_error("loading/entry assertion failed");quit(1);return
 print("PASS packaged HTTPS entry: loading shown, chunks ready, loading closed")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("D:/codex项目/rpg/reports/network-input-icon-v2/packaged-world.png")
 await app.active_world.close_world()
 await create_timer(.4).timeout
 # Failure feedback: unreachable endpoint must release overlay and busy flag.
 network.config.server_url="https://127.0.0.1:24999"
 var failure=await app.send("resume",{})
 if failure.get("ok",false) or app.loading_layer.visible or app.busy or app.status.text.is_empty():
  push_error("failure cleanup assertion failed");quit(1);return
 print("PASS failed entry: loading closed, error visible, retry allowed")
 app.queue_free();await process_frame;await process_frame
 quit()

