extends SceneTree
var checks := 0
func _initialize() -> void:
 call_deferred("verify")
func verify() -> void:
 for kind in ["bear", "wolf"]:
  var packed = load("res://godot/" + kind + ".tscn")
  assert(packed is PackedScene)
  var actor = packed.instantiate()
  root.add_child(actor)
  var player: AnimationPlayer = actor.get_node("AnimationPlayer")
  assert(player.get_animation_list().size() == 2)
  for clip in player.get_animation_list():
   var duration = player.get_animation(clip).length
   player.play(clip)
   player.seek(0.0, true)
   var initial = {}
   for node in actor.get_children():
    if node is Node2D:
     initial[node.name] = node.transform
   for i in range(97):
    player.seek(float(i) / 96.0 * duration, true)
    var visible_count = 0
    for node in actor.get_children():
     if node is Node2D and node.visible:
      visible_count += 1
      assert(node.position.is_finite())
      assert(is_finite(node.rotation))
      assert(node.get_node("Sprite").texture != null)
    assert(visible_count >= 14)
    checks += 1
   player.seek(duration, true)
   for node in actor.get_children():
    if node is Node2D:
     assert(node.transform.is_equal_approx(initial[node.name]), str(kind, clip, node.name, " loop seam"))
   checks += 1
  actor.queue_free()
 print("BEAST_CANDIDATE_QA ", checks, " sampled animation / seam checks passed")
 quit()
