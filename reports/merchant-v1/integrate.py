from pathlib import Path

def edit(p,old,new):
 f=Path(p);s=f.read_text(encoding='utf-8-sig');assert old in s,(p,old);f.write_text(s.replace(old,new,1),encoding='utf-8')
edit('scripts/item_database.gd','\tfor row in rows:', '\tif Engine.get_meta("merchant_preview",false):\n\t\trows.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://data/merchant_items.json")))\n\tfor row in rows:')
edit('scripts/item_service.gd','var database := ItemDatabase.new()', 'var database := ItemDatabase.new()\nvar merchant: Node=preload("res://scripts/merchant.gd").new()')
edit('scripts/item_service.gd','\tworld = owner_world','\tworld = owner_world\n\tadd_child(merchant);merchant.configure(self)')
edit('scripts/item_service.gd','return {"fishing":fishing_population.serialize()', 'return {"merchant":merchant.serialize(),"fishing":fishing_population.serialize()')
edit('scripts/item_service.gd','\tif value.has("fishing") and not fishing_population.valid', '\tif value.has("merchant") and not merchant.valid(value.merchant):writable=false;return\n\tif value.has("fishing") and not fishing_population.valid')
edit('scripts/item_service.gd','\tif value.has("fishing"): fishing_population.restore', '\tif value.has("merchant"):merchant.restore(value.merchant)\n\tif value.has("fishing"): fishing_population.restore')
edit('scripts/item_service.gd','\t\telif database.item(id).use_action=="light":', '\t\telif database.item(id).use_action=="solar_light": merchant.lights.toggle(int(effect.get("slot",-1)))\n\t\telif database.item(id).use_action=="light":')
edit('scripts/item_service.gd','\tif path.begins_with("res://assets/industry/v1/"):', '\tif path.begins_with("res://prototypes/merchant-v1/"):return preload("res://scripts/candidate_art.gd").texture(path)\n\tif path.begins_with("res://assets/industry/v1/"):')
edit('scripts/item_service.gd','\tentry["instance"]=slot.duplicate(true);entry.instance.count=amount', '\tentry["instance"]=slot.duplicate(true);entry.instance.count=amount\n\tif slot.item_id=="solar_flashlight":entry.instance.state.facing=world.player.facing')
edit('scripts/item_inventory.gd','\treturn value\n\nfunc normalize_durability','\tif id=="solar_flashlight":value.state=preload("res://scripts/solar_flashlight.gd").fresh()\n\treturn value\n\nfunc normalize_durability')
edit('scripts/item_inventory.gd','\tvar definition := database.item(str(value.get("item_id","")))\n\tif definition.get', '\tvar definition := database.item(str(value.get("item_id","")))\n\tif value.get("item_id")=="solar_flashlight" and not preload("res://scripts/solar_flashlight.gd").valid(value.get("state")):return false\n\tif definition.get')
edit('scripts/item_inventory.gd','if definition.use_action in ["light","place_campfire","place_sleeping_bag"]:', 'if definition.use_action in ["light","solar_light","place_campfire","place_sleeping_bag"]:')
edit('scripts/world.gd','\tmap_view.item_screen=item_ui', '\titem_service.merchant.ready_world()\n\tmap_view.item_screen=item_ui')
edit('scripts/item_ui.gd','func update_input_block() -> void:', 'func update_input_block() -> void:\n\tif service.merchant.interacting:world.player.input_blocked=true;return')
edit('scripts/item_ui.gd','func _input(event: InputEvent) -> void:', 'func _input(event: InputEvent) -> void:\n\tif service.merchant.interacting:\n\t\tservice.merchant.ui.handle_input(event)\n\t\tget_viewport().set_input_as_handled();return')
edit('scripts/item_ui.gd','\tuse_button.visible=index<40', '\tif modal_stack.item_id=="solar_flashlight":use_button.text="关闭" if modal_stack.state.on else "打开"\n\tuse_button.visible=index<40 or modal_stack.item_id=="solar_flashlight"')
edit('scripts/item_ui.gd','\telif not service.inventory.use_slot(index): show_notice(use_failure(index))', '\telif modal_stack.item_id=="solar_flashlight":service.merchant.lights.toggle(index)\n\telif not service.inventory.use_slot(index): show_notice(use_failure(index))')
edit('scripts/environment_view.gd','\t\tservice.camps.advance(step,', '\t\tservice.merchant.advance(step*1440.0/maxf(1.0,simulation.day_length_minutes*60.0))\n\t\tservice.camps.advance(step,')
edit('scripts/environment_view.gd','\tvar centers := PackedVector2Array()', '\tif world.item_service.merchant.enabled:world.item_service.merchant.lights.shader_parameters(material_effect)\n\tvar centers := PackedVector2Array()')
edit('scripts/world_environment.gdshader','uniform float hallucination = 0.0;', '''uniform float hallucination = 0.0;
uniform int torch_count = 0;
uniform vec2 torch_centers[32];
uniform vec2 torch_directions[32];
uniform float torch_length = 360.0;
uniform float torch_angle = 0.38;''')
edit('scripts/world_environment.gdshader',' // Slow hue drift', ''' float torch_glow = 0.0;
 for (int i=0;i<32;i++) {
  if (i>=torch_count) { break; }
  vec2 rel = (SCREEN_UV-torch_centers[i])/SCREEN_PIXEL_SIZE;
  float along = dot(rel,torch_directions[i]);
  float cross_distance = abs(rel.x*torch_directions[i].y-rel.y*torch_directions[i].x);
  float width = max(2.0,along*tan(torch_angle));
  float cone = (1.0-smoothstep(width*.70,width,cross_distance))*smoothstep(0.0,5.0,along)*(1.0-smoothstep(torch_length*.65,torch_length,along));
  torch_glow=max(torch_glow,cone);
 }
 color=mix(color,original*vec3(1.16,1.20,1.22)+vec3(.06,.09,.10),clamp(torch_glow*.96,0.0,1.0));
 // Slow hue drift''')
edit('scripts/held_tool.gd','\tif row.is_empty(): return\n\tvar path', '''\tif row.is_empty(): return
\tif row.has("views"):
\t\trow=row.duplicate(true)
\t\trow.merge(row.views.get("side" if facing in ["left","right"] else facing,{}),true)
\tvar path''')
edit('scripts/held_tool.gd','if not textures.has(path): textures[path]=load(path)', 'if not textures.has(path): textures[path]=preload("res://scripts/candidate_art.gd").texture(path) if path.begins_with("res://prototypes/") else load(path)')
edit('scripts/held_tool.gd','\tif facing=="back": show_behind_legs(character,tool)', '''\tif row.get("directional",false):
\t\tvar forward: Vector2={"front":Vector2.DOWN,"back":Vector2.UP,"left":Vector2.LEFT,"right":Vector2.RIGHT}[facing]
\t\tvar local_forward := arm.to_local(arm.global_position+forward)-arm.to_local(arm.global_position)
\t\ttool.rotation=local_forward.angle()-float(row.get("source_angle",-PI*.5))
\tif facing=="back": show_behind_legs(character,tool)''')
edit('scripts/held_tool.gd','var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/held_tools.json"))', '''var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/held_tools.json"))
func _init() -> void:
\tif Engine.get_meta("merchant_preview",false):
\t\tdefinitions["tool:solar_flashlight"]={"texture":"res://prototypes/merchant-v1/final/flashlight_side.png","grip_px":[128,170],"scale":0.14,"rotation_degrees":0,"hand_offset":[0,-2.75],"stance_degrees":{"side":-20,"front":-15,"back":-15},"directional":true,"source_angle":-PI*.5,"views":{"front":{"texture":"res://prototypes/merchant-v1/final/flashlight_front.png","source_angle":PI*.5},"back":{"texture":"res://prototypes/merchant-v1/final/flashlight_back.png"}}}''')
