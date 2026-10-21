extends SceneTree
func _initialize():run.call_deferred()
func run():
 var app=load("res://scenes/launcher.tscn").instantiate();root.add_child(app)
 await process_frame
 root.title="昵称输入专项"
 app.nickname(true)
 var field:LineEdit=app.fields.nickname
 field.text_changed.connect(func(value):print("TEXT=",value))
 field.editing_toggled.connect(func(value):print("EDIT=",value))
 field.focus_entered.connect(func():print("FOCUS"))
 await create_timer(600).timeout
 quit()
