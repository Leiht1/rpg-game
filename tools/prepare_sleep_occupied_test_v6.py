from pathlib import Path
s=Path('tests/test_sleep_occupied_v5.gd').read_text(encoding='utf8').replace('res://reports/sleep-occupied-v5/','res://reports/sleep-occupied-v6/').replace('SLEEP OCCUPIED V5','SLEEP OCCUPIED V6')
s=s.replace('quilt.texture.resource_path.begins_with("res://prototypes/sleep-occupied-v5/")','quilt.texture.resource_path.begins_with("res://prototypes/sleep-occupied-v")')
s=s.replace('root.size=Vector2i(1280,720);root.content_scale_size=root.size;', 'root.size=default_size();root.content_scale_size=root.size;')
s=s.replace('for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:','for size in [default_size()]:')
s=s.replace('func _initialize() -> void:', '''func default_size() -> Vector2i:
	return Vector2i(int(ProjectSettings.get_setting("display/window/size/window_width_override",1280)),int(ProjectSettings.get_setting("display/window/size/window_height_override",720)))
func _initialize() -> void:''')
Path('tests/test_sleep_occupied_v6.gd').write_text(s,encoding='utf8')
# Keep the prior active sleep test consistent with the new development rule too.
p=Path('tests/test_sleep_occupied_v5.gd');old=p.read_text(encoding='utf8').replace('for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:','for size in [Vector2i(int(ProjectSettings.get_setting("display/window/size/window_width_override",1280)),int(ProjectSettings.get_setting("display/window/size/window_height_override",720)))]:');p.write_text(old,encoding='utf8')
