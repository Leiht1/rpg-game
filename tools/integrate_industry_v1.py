from pathlib import Path
R=Path(__file__).resolve().parents[1]
def edit(p,fn):
 f=R/p;s=f.read_text(encoding='utf-8');f.write_text(fn(s),encoding='utf-8')
def inv(s):
 s=s.replace('const SLOT_COUNT := 40','const Fresh=preload("res://scripts/food_freshness.gd")\nconst SLOT_COUNT := 40')
 s=s.replace('elif id=="field_lantern": slots[i]={"item_id":id,"count":1,"lamp_id":str(ResourceUID.create_id()),"fuel":1800.0}','elif database.item(id).get("use_action","")=="light": slots[i]={"item_id":id,"count":1,"lamp_id":str(ResourceUID.create_id()),"fuel":float(definition.get("lamp_lifetime",1800.0))}')
 s=s.replace('and slot.item_id == id):','and slot.item_id == id and not slot.has("spoilage")):')
 s=s.replace('left -= amount','if Fresh.cooked(database,id): slots[i].spoilage=0.0\n\t\t\t\t\tleft -= amount',1)
 s=s.replace('and not database.item(source.item_id).get("equippable",false):','and Fresh.same(source,target):')
 s=s.replace('var effect: Dictionary = definition.get("effects",{}).duplicate(true)','var effect: Dictionary = Fresh.effects(database,get_slot(index))')
 s=s.replace('slots[target]={"item_id":slots[index].item_id,"count":count}','slots[target]=slots[index].duplicate(true);slots[target].count=count')
 s=s.replace('elif id=="field_lantern":','elif definition.get("use_action","")=="light":')
 s=s.replace('float(fuel)>1800:','float(fuel)>float(definition.get("lamp_lifetime",1800.0)):')
 s=s.replace('else: next.append({"item_id":id,"count":count})','else:\n\t\t\tvar restored: Dictionary=value.duplicate(true)\n\t\t\tif not Fresh.normalize(database,restored): return false\n\t\t\trestored.count=count;next.append(restored)')
 s+='''
func add_value(value: Dictionary) -> int:
	if value.is_empty():return 0
	var incoming := value.duplicate(true)
	if not Fresh.normalize(database,incoming):return int(incoming.count)
	var left := int(incoming.count)
	var limit := int(database.item(incoming.item_id).max_stack)
	for empty_pass in [false,true]:
		for i in range(8 if empty_pass else 0,SLOT_COUNT):
			var target: Dictionary=slots[i]
			if (empty_pass and target.is_empty()) or (not empty_pass and Fresh.same(target,incoming)):
				var amount := mini(left,limit-int(target.get("count",0)))
				if amount<=0:continue
				if target.is_empty():slots[i]=incoming.duplicate(true);slots[i].count=amount
				else:slots[i].count+=amount
				left-=amount
				if left==0:return 0
	return left

func labor_speed() -> float:
	var held: Dictionary=equipment.get("main_hand",{})
	return float(database.item(str(held.get("item_id",""))).get("stats",{}).get("labor_speed",1.0))
'''
 return s
edit('scripts/item_inventory.gd',inv)
def service(s):
 s=s.replace('var storage_ui: Control','var industry: RefCounted=preload("res://scripts/industry_service.gd").new()\nvar industry_ui: Control\nvar storage_ui: Control')
 s=s.replace('builds.service=self','builds.service=self\n\tindustry.service=self\n\tif industry.enabled():\n\t\tfor row in camps.build_book.recipes.values():\n\t\t\tif row.get("industry_candidate",false):row.default_unlocked=true')
 s=s.replace('float(fuel)>1800:', 'float(fuel)>3600:')
 s=s.replace('row.item_id=="field_lantern"','database.item(row.item_id).get("use_action","")=="light"')
 s=s.replace('slot.get("item_id","")!="field_lantern"','database.item(str(slot.get("item_id",""))).get("use_action","")!="light"')
 s=s.replace('float(fuel_value)>1800:', 'float(fuel_value)>float(database.item(slot.item_id).get("lamp_lifetime",1800.0)):')
 s=s.replace('or item_id=="field_lantern"','or database.item(item_id).get("use_action","")=="light"')
 s=s.replace('else: left=staged.add(item_id,count)','else:\n\t\tvar value: Dictionary=loose.get(id,{}).get("instance",{"item_id":item_id,"count":count}).duplicate(true);value.count=count\n\t\tleft=staged.add_value(value)')
 s=s.replace('if database.item(slot.item_id).get("equippable",false) or slot.item_id=="field_lantern": entry["instance"]=slot.duplicate(true)','entry["instance"]=slot.duplicate(true);entry.instance.count=amount')
 s=s.replace('if lantern_remaining<=0: lantern.hide()','''if lantern_remaining<=0:
		lantern.hide()
		if database.item(slot.item_id).get("expire_remove",false):
			for i in inventory.slots.size():
				if inventory.slots[i].get("lamp_id","")==active_lamp:inventory.slots[i]={}
			active_lamp="";inventory.changed.emit()''')
 return s
edit('scripts/item_service.gd',service)
def buildings(s):
 s=s.replace('if row.get("layer") in ["edge","ground"]:','if row.get("layer") in ["edge","ground","overlay"]:')
 s=s.replace('var k := Grid.key(row,d.layer=="edge")','var k := str(d.layer)+":"+Grid.key(row,d.layer=="edge")')
 s=s.replace('if not row.get("contents") is Array or row.contents.size()!=12:','if not row.get("contents") is Array or row.contents.size()!=int(d.get("storage_slots",12)):')
 s=s.replace('row.kind!="wood_chest" and row.contents.any','row.kind!="wood_chest" and not d.has("storage_slots") and row.contents.any')
 s=s.replace('if row.open and row.kind!="wood_chest" and not d.get("door",false):','if not service.industry.valid(row):return false\n\t\tif row.open and row.kind!="wood_chest" and not d.has("storage_slots") and not d.get("door",false):')
 s=s.replace('row.contents[i] if i<12 else {}','row.contents[i] if i<row.contents.size() else {}').replace('for i in 12: row.contents[i]=inv.slots[i]','for i in row.contents.size(): row.contents[i]=inv.slots[i]')
 s=s.replace('for i in 12: row.contents.append({})','for i in int(d.get("storage_slots",12)): row.contents.append({})\n\tif service.industry.machine(kind):row.machine=service.industry.initial(kind)')
 s=s.replace('if not service.writable: return "存档受保护，不能建造"','''if not service.writable: return "存档受保护，不能建造"
	if definitions[row.kind].get("industry_candidate",false) and not service.industry.enabled():return "候选设施尚未开放"
	if row.kind=="wool_carpet":
		var floor_found := false
		for base in states.values():
			if base.kind in ["wood_floor","stone_path"] and Grid.key(base,false)==Grid.key(row,false):floor_found=true;break
		if not floor_found:return "需要已有地板"''')
 s=s.replace('if row.layer=="ground": offsets=', 'if row.layer in ["ground","overlay"]: offsets=')
 s=s.replace('if row.layer!="ground" and world.player','if row.layer not in ["ground","overlay"] and world.player')
 s=s.replace('Vector2(84,52) if row.layer=="ground"','Vector2(84,52) if row.layer in ["ground","overlay"]')
 s=s.replace('if row.layer=="ground" and hit.collider','if row.layer in ["ground","overlay"] and hit.collider').replace('row.layer in ["edge","ground"]','row.layer in ["edge","ground","overlay"]')
 s=s.replace('if states[id].contents.any', '''if states[id].kind in ["wood_floor","stone_path"]:
			for over in states.values():
				if over.kind=="wool_carpet" and Grid.key(over,false)==Grid.key(states[id],false):return "请先拆除地毯"
		if states[id].has("machine"):
			var m: Dictionary=states[id].machine
			if not m.feed.is_empty() or not m.queue.is_empty() or m.jobs.any(func(j):return not j.is_empty()):return "设施内还有物品"
		if states[id].contents.any''')
 s=s.replace('states[id].kind!="wood_chest"','not storage_kind(str(states[id].kind))')
 s=s.replace('states[key].kind=="wood_chest"','storage_kind(str(states[key].kind))')
 s=s.replace('chest_index>=12','chest_index>=states[id].contents.size()').replace('source>=12','source>=states[id].contents.size()')
 s=s.replace('if chest_index>=9 and not expected_player.is_empty():','if states[id].kind=="wood_chest" and chest_index>=9 and not expected_player.is_empty():')
 s=s.replace('if not inv.accepts(player_index,expected_chest):','''if states[id].kind=="refrigerator" and not expected_player.is_empty() and service.database.item(str(expected_player.item_id)).get("food_kind","") not in ["raw","cooked"]:return "冰箱只能存放食物"
	if not inv.accepts(player_index,expected_chest):''')
 s=s.replace('and a.item_id==b.item_id and not a.has("instance_id") and not a.has("lamp_id")','and preload("res://scripts/food_freshness.gd").same(a,b)')
 s=s.replace('for i in 9:', 'for i in storage_capacity(id):')
 s=s.replace('contents[empty]={"item_id":expected.item_id,"count":quantity}','contents[empty]=expected.duplicate(true);contents[empty].count=quantity')
 s=s.replace('target>=9','target>=storage_capacity(id)').replace('if source>=9 and','if source>=storage_capacity(id) and')
 s=s.replace('and other.item_id==expected.item_id and not expected.has("instance_id") and not expected.has("lamp_id")','and preload("res://scripts/food_freshness.gd").same(other,expected)')
 s=s.replace('service.body.can_eat(definition.get("effects",{}))','service.body.can_eat(preload("res://scripts/food_freshness.gd").effects(service.database,expected))').replace('service.body.eat(definition.get("effects",{}))','service.body.eat(preload("res://scripts/food_freshness.gd").effects(service.database,expected))')
 s+='''
func storage_kind(kind: String) -> bool:
	return kind=="wood_chest" or definitions.get(kind,{}).has("storage_slots")

func storage_capacity(id: String) -> int:
	return 9 if states[id].kind=="wood_chest" else int(definitions[states[id].kind].get("storage_slots",12))
'''
 return s
edit('scripts/camp_buildings.gd',buildings)
def actor(s):
 s=s.replace('row.kind in ["wood_chest","workbench"]','row.kind in ["wood_chest","workbench"] or d.get("industry_candidate",false)')
 s=s.replace('if row.layer=="ground": z_index=-1','if row.layer=="ground": z_index=-1\n\tif row.layer=="overlay":z_index=0')
 s=s.replace('if row.layer!="ground":','if row.layer not in ["ground","overlay"]:')
 s=s.replace('if r.kind=="signpost":\n', '''if d.get("industry_candidate",false):
		var path: String=d.art
		if ResourceLoader.exists(path):
			var image: Texture2D=load(path)
			var extent: Vector2=image.get_size()*minf(88.0/image.get_width(),96.0/image.get_height())
			draw_texture_rect(image,Rect2(Vector2(-extent.x*.5,8-extent.y),extent),false)
		return
	if r.kind=="signpost":
''',1)
 s=s.replace('if r.kind=="workbench": manager.service.world.item_ui', '''if manager.storage_kind(r.kind):manager.service.storage_ui.open(building_id);return true
	if r.kind=="copper_lamp":
		var reason: String=manager.service.industry.act(building_id,"toggle")
		if not reason.is_empty():manager.service.notice.emit(reason)
		return reason.is_empty()
	if manager.service.industry.machine(r.kind):manager.service.industry_ui.open(building_id);return true
	if r.kind=="workbench": manager.service.world.item_ui''')
 return s
edit('scripts/camp_building.gd',actor)
def storage(s):
 s=s.replace('for i in 9:\n\t\tvar cell','for i in 24:\n\t\tvar cell')
 s=s.replace('for i in range(9,12):','for i in range(9,12) if service.builds.states[current].kind=="wood_chest" else []:')
 s=s.replace('panel.size.y=220 if overflow else 184','''var cap: int=service.builds.storage_capacity(current)
	panel.get_node("ChestTitle").text=service.builds.definitions[service.builds.states[current].kind].name
	panel.size.y=220 if overflow else 38+int(ceil(cap/3.0))*48+2''')
 s=s.replace('cell.visible=not legacy_page or i<3','cell.visible=(not legacy_page and i<cap) or (legacy_page and i<3)')
 s=s.replace('index<12','index<service.builds.states.get(current,{}).get("contents",[]).size()')
 s=s.replace('row.kind=="wood_chest" and row.open','service.builds.storage_kind(row.kind) and row.open')
 return s
edit('scripts/camp_storage_ui.gd',storage)
def env(s):
 s=s.replace('260.0*viewport.get_canvas_transform()', 'float(world.item_service.database.item(str(world.item_service.lamp_slot().get("item_id",""))).get("light_radius",260.0))*viewport.get_canvas_transform()')
 s=s.replace('if world.item_service.builds.states[id].kind!="camp_torch": continue','if world.item_service.builds.states[id].kind!="camp_torch" and not (world.item_service.builds.states[id].kind=="copper_lamp" and world.item_service.builds.states[id].machine.enabled): continue')
 s=s.replace('service.planting.advance(step*', 'if service.industry.enabled():service.industry.advance(step,step*1440.0/maxf(1.0,simulation.day_length_minutes*60.0))\n\t\tservice.planting.advance(step*')
 return s
edit('scripts/environment_view.gd',env)
def inter(s):
 s=s.replace('if row.kind=="workbench": return "E 制作"','if row.kind=="copper_lamp":return "E 关闭" if row.machine.enabled else "E 开启"\n\t\tif row.kind=="workbench": return "E 制作"')
 return s
edit('scripts/world_interaction.gd',inter)
def body(s):
 s=s.replace('var health := 100.0','var discomfort := 0.0\nvar health := 100.0')
 s=s.replace('func eat(effect: Dictionary) -> void:', 'func eat(effect: Dictionary) -> void:\n\tdiscomfort=maxf(discomfort,float(effect.get("discomfort",0)))')
 return s
edit('scripts/body_state.gd',body)
def player(s):
 s=s.replace('action_clock+=delta', 'action_clock+=delta') # exact expression located separately
 return s
edit('scripts/player.gd',player)
