extends "res://scripts/world.gd"
const PREVIEW_PATH := "user://world-map-v3-preview/state.json"
var preview_protected := false
func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
	set_meta('map_art_v3',true)
	set_meta('isolated_environment',true)
	set_meta('character_save_path',PREVIEW_PATH)
	world_seed=int(Time.get_unix_time_from_system()*1000)%2147483646+1;map_cells=1536;persistent_world=true
	world_id=str(ResourceUID.create_id())
	if FileAccess.file_exists(PREVIEW_PATH):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
		if saved is Dictionary and saved.get('generator')==Gen.VERSION and saved.get('map_cells')==1536 and (saved.get('seed') is float or saved.get('seed') is int) and is_finite(float(saved.seed)) and saved.seed==floor(saved.seed) and saved.seed>0 and saved.seed<2147483647:
			world_seed=int(saved.seed)
			world_id=str(saved.get("world_id","map-v3-preview:%d"%world_seed))
		else:preview_protected=true;persistent_world=false;migration_notice='试玩存档无法读取，原文件已保留'
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW_PATH.get_base_dir()))
func save_world_identity(_path: String=WORLD_ID_PATH) -> void:pass
func parse_arguments() -> void:pass
func _ready() -> void:
	super._ready()
	get_tree().auto_accept_quit=false
	title.text='风栖原野 · 世界与地图 V3 候选'
	if preview_protected or not item_service.writable:
		preview_protected=true;item_service.writable=false;title.text+=" · 存档受保护"
	else:
		item_service.exploration.reveal(player.position)
		item_service.dirty=true
		item_service.save_state()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if preview_protected or item_service.save_state():get_tree().quit()
		else:item_ui.show_notice('保存失败，请稍后再次关闭重试')
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode==KEY_N:
		get_viewport().set_input_as_handled();return
	super._unhandled_input(event)
func _process(delta: float) -> void:
	super._process(delta)
	hint.text=hint.text.replace(' · N 新世界','')
