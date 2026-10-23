extends SceneTree
var checks:=0
var failed:=false
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failed=true
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.set_process(false);w.player.set_physics_process(false);w.item_service.set_process(false)
	var s=w.item_service;var p=w.player;var c=s.combat
	for view in ["front","back","left","right"]:
		for item in ["wood_club","tusk_club"]:
			s.inventory.equipment={"main_hand":s.inventory.instance(item)};p.facing=view;p.combat_render_state={}
			c.personal.phase="alive";c.personal.attack={"weapon":c.rules.weapons[item],"elapsed":.24,"direction":{"x":1,"y":0},"targets":{}}
			p.update_animation()
			var arm=p.character.get_node("Visual/Pelvis/ArmR");var grip=arm.get_node("Grip");var tool=arm.get_node("HeldTool")
			check(tool.position.distance_to(grip.position+Vector2(0,-2.75))<.001,"registered grip "+view+" "+item)
			check(absf(tool.rotation+arm.rotation-PI)<.001 if view=="front" else absf(tool.rotation-grip.rotation)<.001,"front forward strike or native mining wrist "+view+" "+item)
			if view=="front":check(not arm.show_behind_parent and tool.get_index()==arm.get_child_count()-1 and p.held_tool.front_free_hand.visible,"front tool and both arms "+item)
			elif view=="back":check(not tool.visible and p.held_tool.rear_tool.visible and p.held_tool.rear_tool.show_behind_parent and p.held_tool.rear_tool.get_index()==0,"back tool behind legs "+item)
			else:check(tool.visible and (not is_instance_valid(p.held_tool.rear_tool) or not p.held_tool.rear_tool.visible),"side tool restored "+view+" "+item)
			c.personal.attack={};p.update_animation()
			check(p.character.get_node("Visual/Pelvis/ArmR").scale==Vector2.ONE,"idle scale restores "+view+" "+item)
	print("CLUB_LAYERS_PASS ",checks) if not failed else print("CLUB_LAYERS_FAIL")
	quit(1 if failed else 0)
