extends "res://tests/preview_animals_v1.gd"
func run() -> void:
 await super.run()
 for i in 80:await process_frame
 var w=root.get_child(root.get_child_count()-1)
 var a=w.item_service.animals
 var ok=not w.persistent_world and a.states.has("preview:0") and a.visuals.has("preview:2")
 var f=FileAccess.open("res://reports/animals-v1/preview.json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":1,"failed":0 if ok else 1,"isolated_preview":ok}));f.close()
 root.get_texture().get_image().save_png("res://reports/animals-v1/preview.png")
 print("ANIMALS PREVIEW: ",ok)
 w.free();await process_frame;quit(0 if ok else 1)
