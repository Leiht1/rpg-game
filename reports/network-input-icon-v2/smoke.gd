extends SceneTree
var checks:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:push_error(message);quit(1)
 print("PASS ",message)
func _initialize():run.call_deferred()
func key(code:int,unicode_value:int=0):
 var event:=InputEventKey.new();event.keycode=code;event.unicode=unicode_value;event.pressed=true;Input.parse_input_event(event)
 await process_frame
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
 await process_frame
func run():
 var app=load("res://scenes/launcher.tscn").instantiate();root.add_child(app)
 await process_frame
 app.nickname(true)
 await create_timer(.2).timeout
 var field:LineEdit=app.fields.nickname
 check(field.has_focus(),"nickname initially focused")
 field.keep_editing_on_text_submit=false
 await key(KEY_ENTER)
 check(not field.is_editing(),"old Enter exits editing")
 await key(KEY_A,97)
 check(field.text.is_empty(),"old focused field swallows subsequent typing")
 field.keep_editing_on_text_submit=true;field.edit()
 await key(KEY_UNKNOWN,0x98ce)
 await key(KEY_ENTER)
 await key(KEY_UNKNOWN,0x6816)
 await key(KEY_A,97)
 check(field.text=="风栖a","Chinese commit and typing after Enter retained")
 await key(KEY_BACKSPACE)
 check(field.text=="风栖","backspace works")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://reports/network-input-icon-v2/nickname.png")
 await app.show_loading("正在连接世界…")
 check(app.loading_layer.visible,"loading visible before operation")
 var shade:Control=app.loading_layer.get_child(0)
 check(shade.mouse_filter==Control.MOUSE_FILTER_STOP,"loading blocks repeat clicks")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://reports/network-input-icon-v2/loading.png")
 app.hide_loading();check(not app.loading_layer.visible,"loading can close on failure or completion")
 app.root.hide();app.online_creation=false;app.create_character();app.add_local_return()
 await create_timer(.3).timeout
 var back:Button=app.get_node("LocalReturn").get_child(0)
 check(back.theme!=null and back.get_theme_stylebox("normal") is StyleBoxTexture,"return uses paper theme")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://reports/network-input-icon-v2/return.png")
 back.pressed.emit();await process_frame
 check(app.root.visible and app.creation==null,"return closes creation without saving a character")
 print("RESULT ",checks," checks")
 quit()
