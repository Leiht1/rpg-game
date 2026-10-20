extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var bg=ColorRect.new();bg.color=Color("f3e6cd");bg.size=Vector2(1280,720);root.add_child(bg)
 for i in 2:
  var c=load("res://assets/hero/cartoon/character.tscn").instantiate();root.add_child(c);c.scale=Vector2.ONE*4;c.position=Vector2(220+i*480,50)
  var ap=c.get_node("AnimationPlayer");ap.play("front_breathe" if i==0 else "side_breathe");ap.seek(.4,true);ap.pause()
 for i in 4:await process_frame
 root.get_texture().get_image().save_png("res://art/animals-style-v2/hero-reference.png");quit()
