extends "res://tests/hat_motion_v2.gd"
func run() -> void:
 s=DataOnly.new();root.add_child(s);root.size=default_size();root.content_scale_size=root.size
 await visual_tests()
 var failed: Array=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open("res://reports/hat-motion-v2/static-results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"\t"));f.close()
 print("HAT_STATIC ",checks.size()," checks ",failed.size()," failed")
 s.queue_free();await frames();quit(1 if not failed.is_empty() else 0)
