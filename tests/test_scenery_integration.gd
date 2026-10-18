extends "res://tests/capture_world_v06.gd"
const Catalog=preload("res://scripts/scenery_catalog.gd")
const OUT="res://reports/environment-game-v01/"
var appearances:={}
var counts:={}
func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func advance(n:int)->void:
	for i in n:await physics_frame
func run()->void:
	Engine.set_meta("integration_seed",447349832)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	await settle();await shot("spawn")
	check(w.stream.ART_VERSION=="scene-contact-1.0.0","formal selected art active")
	check(w.generator.VERSION=="windrest-continent-0.6.0","same mainland generator and seed identity")
	for biome in 3:
		w.player.position=w.generator.region_cores[w.generator.region_kinds.find(biome)]
		w.player.reset_physics_interpolation();w.player.camera.reset_smoothing();await settle()
		await shot("biome-%d"%biome)
		for chunk in w.stream.loaded.values():
			for p in chunk.props:
				if p.kind>=4:continue
				appearances[p.variant_id]=true;counts[p.surface]=int(counts.get(p.surface,0))+1
				check(p.texture.resource_path.begins_with("res://assets/environment/contact_v01/"),"formal asset "+p.name)
				check(p.upper.material==p.contact.material and p.mat.get_shader_parameter("color_fit")==1.,"live contact fit "+p.name)
				var expected:=Catalog.footprint(p.variant_id)
				for i in expected.size():expected[i]*=p.display_size/p.texture.get_size()
				check(p.collision.polygon==expected,"individual footprint "+p.name)
	check(appearances.size()==9 and not appearances.has("tree_02"),"three chosen trees and six ordinary stones",appearances.keys())
	check(counts.has("grass") and counts.has("forest") and counts.has("dirt"),"all surface adapters used",counts)
	var coord:Vector2i=w.stream.chunk_at(w.player.position)
	var entries:Array=w.generator.props_for_chunk(coord)
	var before:Array=[]
	for e in entries:
		if e.kind<4:before.append(Catalog.appearance(w.generator,e))
	w.stream.unload_chunk(coord);await process_frame
	var packet:Dictionary=w.generator.build_chunk(coord)
	var stamps:Array[Dictionary]=[];packet["ground_stamps"]=stamps
	w.stream.install_chunk(packet)
	var after:Array=[]
	for e in w.generator.props_for_chunk(coord):
		if e.kind<4:after.append(Catalog.appearance(w.generator,e))
	check(before==after,"appearance and surface reproduce after chunk reload")
	var tree:Node2D=get_nodes_in_group("trees")[0]
	var rock:Node2D=get_nodes_in_group("rocks")[0]
	check(not w.stream.tree_in_reach(rock.position,rock),"ordinary stone cannot be chopped")
	var rock_transform:Transform2D=rock.global_transform;rock.hit()
	check(rock.state=="idle" and rock.global_transform==rock_transform,"ordinary stone has no hit animation")
	var transform_before:Transform2D=tree.global_transform
	var contact_before:Transform2D=tree.contact.global_transform
	w.stream.chop_tree(tree)
	var tween:Tween=tree.active;tween.pause()
	for i in 14:
		tween.custom_step(.04);await process_frame
		check(tree.global_transform==transform_before and tree.contact.global_transform==contact_before,"root fixed during hit %d"%i)
		check(tree.modulate==Color.WHITE and tree.upper.modulate.r==1.,"no hit flash %d"%i)
	check(tree.state=="idle" and absf(float(tree.mat.get_shader_parameter("bend")))<.001,"sway returns to rest")
	var required:int=tree.required_hits
	var id:String=tree.get_meta("prop_id")
	var drops_before:int=w.stream.drops.size()
	for i in range(1,required):w.stream.chop_tree(tree)
	await advance(24)
	check(w.stream.harvested.has(id) and not tree.visible and tree.modulate.a<.01,"chopped tree fades out in place")
	check(tree.collision.disabled and not tree.is_in_group("trees"),"removed tree stops collision and interaction")
	check(w.stream.drops.size()-drops_before==required/2,"original wood drop cadence retained")
	var drop:Node2D=w.stream.spawn_drop(w.player.position+Vector2(20,0),"scenery-pickup-test")
	var wood_before:int=w.stream.collected_wood
	w.player.try_interact();await advance(46)
	check(not is_instance_valid(drop) and w.stream.collected_wood==wood_before+1,"normal player active pickup works")
	w.player.cancel_action()
	# Use normal player movement against an actual stone footprint.
	w.player.position=rock.position+Vector2(-100,0);w.player.reset_physics_interpolation()
	w.player.input_override=Vector2.RIGHT;w.player.run_override=false;await advance(45)
	w.player.input_override=Vector2.ZERO
	check(w.player.position.x<rock.position.x-12.,"ordinary stone blocks physical movement")
	var failures:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"checks":checks,"failures":failures,"appearances":appearances.keys(),"surface_samples":counts,"max_install_ms":w.stream.max_install_ms,"note":"Actual formal scene; art variant selection does not mutate generator layout. No FPS claim."},"  "))
	w.queue_free();await process_frame
	print("SCENERY ",checks.size()," FAILURES ",failures);quit(1 if failures else 0)
