extends "res://tests/test_camp_refine_v5.gd"
func shot(label: String):
	if "--capture" not in OS.get_cmdline_user_args(): return
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/back-layer-floor-v6/"+label+".png")
