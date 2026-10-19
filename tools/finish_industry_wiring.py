from pathlib import Path
R=Path(__file__).resolve().parents[1]
def edit(p,fn):
 f=R/p;s=f.read_text(encoding='utf-8');f.write_text(fn(s),encoding='utf-8')
edit('scripts/world.gd',lambda s:s.replace('item_service.planting_ui=preload', 'item_service.industry_ui=preload("res://scripts/industry_ui.gd").new()\n\tui.add_child(item_service.industry_ui);item_service.industry_ui.configure(item_service)\n\titem_service.planting_ui=preload'))
edit('scripts/item_ui.gd',lambda s:s.replace('func update_input_block() -> void:', 'func update_input_block() -> void:\n\tif is_instance_valid(service.industry_ui) and service.industry_ui.visible:world.player.input_blocked=true;return'))
edit('scripts/player.gd',lambda s:s.replace('action_clock+=delta*','action_clock+=delta*(equipment_inventory.labor_speed() if equipment_inventory!=null and action in ["chop","mine","dig","demolish"] else 1.0)*').replace('func update_animation() -> void:', '''func update_animation() -> void:
	if body!=null:
		body.discomfort=maxf(0,body.discomfort-get_physics_process_delta_time())
		queue_redraw()''')+'''
func _draw() -> void:
	if body==null or body.discomfort<=0 or not action.is_empty() or body.sleep_active():return
	# Small sweat marks use no pose or input overrides.
	var offset := Vector2(12,-88)
	draw_circle(offset+Vector2(0,sin(body.discomfort*6)*2),2.0,Color(.4,.72,.9,.9))
	draw_circle(offset+Vector2(5,-5),1.3,Color(.4,.72,.9,.8))
''')
edit('scripts/item_service.gd',lambda s:s.replace('func texture(id: String, kind: String)', '''func stack_texture(value: Dictionary, kind: String) -> Texture2D:
	if preload("res://scripts/food_freshness.gd").rotten(value):
		var path := "res://prototypes/industry-v1/final/rotten_"+str(value.item_id)+".png"
		if ResourceLoader.exists(path):return load(path)
	return texture(str(value.get("item_id","")),kind)

func texture(id: String, kind: String)'''))
edit('scripts/item_slot.gd',lambda s:s.replace('screen.service.texture(slot.item_id,"icon")','screen.service.stack_texture(slot,"icon")'))
edit('scripts/camp_storage_slot.gd',lambda s:s.replace('owner_ui.service.texture(v.item_id,"icon")','owner_ui.service.stack_texture(v,"icon")'))
edit('scripts/chunk_stream.gd',lambda s:s.replace('items.texture(str(entry.item_id),"loose" if gathered else "world")','items.stack_texture(entry.get("instance",entry),"loose" if gathered else "world")'))
# Reduce only unused frame and container spacing. Existing widget/font sizes stay.
edit('scripts/item_ui_style.gd',lambda s:s.replace('maxi(inset,24)','maxi(inset,16)').replace('maxi(inset,28)','maxi(inset,18)').replace('maxi(28,inset)','maxi(18,inset)'))
edit('scripts/craft_ui.gd',lambda s:s.replace('Vector2(1030,600)','Vector2(980,540)').replace('"separation",14','"separation",8').replace('"separation",20','"separation",10').replace('"separation",18','"separation",12').replace('mode_hint=label("徒手制作 · 进度满后完成",13)','mode_hint=label("",13)').replace('header.add_child(mode_hint)','mode_hint.hide();header.add_child(mode_hint)').replace('footer_safe.add_child(mode_footer)','footer_safe.add_child(mode_footer);footer_safe.hide()'))
