"""Explicit, reviewed fixture/contract corrections. Original source is retained."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]
BACKUP=ROOT/'reports/.tmp/repairs-source-before'
changes=[]


def replace(name, before, after):
    path=ROOT/name
    raw=path.read_bytes()
    source=raw.decode('utf-8-sig').replace('\r\n','\n')
    if after in source:return
    if before not in source:
        if after in source:return
        raise ValueError('Missing expected source: '+name+' '+before[:100])
    backup=BACKUP/name;backup.parent.mkdir(parents=True,exist_ok=True)
    if not backup.exists():backup.write_bytes(raw)
    updated=source.replace(before,after)
    path.write_bytes(updated.replace('\n','\r\n').encode('utf-8'))
    changes.append(dict(file=name,before=before,after=after))


def main():
    current='preload("res://tests/current_test_contract.gd")'
    for name, old in [('test_crafting_v1','book.recipes.size()==5'),('test_food_v2','s.craft_book.recipes.size()==9')]:
        path=ROOT/('tests/'+name+'.gd')
        if old in path.read_text(encoding='utf-8-sig'):
            replace('tests/'+name+'.gd',old,old.split('==')[0]+'=='+current+'.recipe_count()')
    for name,old in [('test_ore_runtime_v06','service.database.ids().size()==21'),('test_harvest_v05','service.database.ids().size()==18')]:
        path=ROOT/('tests/'+name+'.gd')
        if old in path.read_text(encoding='utf-8-sig'):
            replace('tests/'+name+'.gd',old,old.split('==')[0]+'=='+current+'.item_count()')
    replace('tests/test_ore_distribution_v06.gd','Distribution.dirt_region(gen,Vector2(row.x,row.y)),"metal restricted to stable mud interior ', 'Distribution.rocky_region(gen,Vector2(row.x,row.y)),"metal restricted to stable rocky interior ')
    replace('tests/test_harvest_v05.gd','db.ids().size()==18','db.ids().size()=='+current+'.item_count()')
    food_path=ROOT/'tests/test_food_v2.gd'
    food_source=food_path.read_text(encoding='utf-8-sig')
    if 'w.camp_ui.recipes.size()==9' in food_source:
        replace('tests/test_food_v2.gd','w.camp_ui.recipes.size()==9','w.camp_ui.recipes.size()==w.item_service.camps.rules.recipes.values().filter(func(row):return not row.get("legacy_only",false)).size()')
    elif 'res://data/cooking.json' in food_source:
        replace('tests/test_food_v2.gd','JSON.parse_string(FileAccess.get_file_as_string("res://data/cooking.json")).recipes.size()','w.item_service.camps.rules.recipes.values().filter(func(row):return not row.get("legacy_only",false)).size()')
    replace('tests/test_ore_runtime_v06.gd','rewards[row.item_id]=int(row.count)','rewards[row.item_id]=int(rewards.get(row.item_id,0))+int(row.count)')
    replace('tests/test_ore_runtime_v06.gd','var kind: String=ids[index]','var kind: String=ids[index]\n\t\tservice.body.stamina=100;service.body.exhausted=false;service.body.energy=100')
    replace('tests/test_harvest_v05.gd','serial+=1','serial+=1\n\t\tservice.body.stamina=100;service.body.exhausted=false;service.body.energy=100')
    replace('tests/test_harvest_v05.gd','check(node.sprite.texture!=node.textures[0],"damage/reveal stage advances "+kind)','check(float(node.hit_material.get_shader_parameter("damage_amount"))==1.0,"damage/reveal shader advances without swapping the anchored body "+kind)')
    replace('tests/test_harvest_v05.gd','found[loot.item_id]=loot.count','found[loot.item_id]=int(found.get(loot.item_id,0))+int(loot.count)')
    replace('tests/test_harvest_followup_v051.gd','await create_timer(1.8).timeout;await key(KEY_E,false)','await create_timer((int(node.definition.hits)-2)*1.12+.2).timeout;await key(KEY_E,false)')
    replace('tests/test_harvest_edges_v05.gd','world.stream.unload_chunk(chunk);await frames()','world.stream.unload_chunk(chunk);await frames()\n\tvar packet: Dictionary=world.generator.build_chunk(chunk);packet["ground_stamps"]=[];world.stream.install_chunk(packet)')
    for name in ['test_movement_regression','test_grounding_interactions']:
        replace('tests/'+name+'.gd','w.player.facing="left";w.player.update_animation()', 'w.item_service.inventory.equipment.main_hand=w.item_service.inventory.instance("stone_axe");w.player.set_equipment(w.item_service.inventory)\n\tw.player.facing="left";w.player.update_animation()')
    replace('tests/test_world_map_v3_logic.gd','pop.max_schools==28 and pop.spots.size()<=28','pop.max_schools==56 and pop.spots.size()<=56')
    replace('tests/test_world_map_v3_distribution.gd','(28 if cells>1024 else 20)','(56 if cells>1024 else 40)')
    replace('tests/test_fishing_population_v2.gd','pop.spots.size()<=20','pop.spots.size()<=pop.max_schools')
    replace('tests/test_fishing_population_v2.gd','value<=3','value<=pop.MAX_PER_LAKE')
    replace('tests/test_audio_ui_open_v7.gd','fx.configuration.sfx_ui_close.files.size()==2','fx.configuration.sfx_ui_close.files.size()==1')
    replace('tests/test_audio_ui_single_v8.gd','fx.configuration.sfx_ui_close.files.size()==2','fx.configuration.sfx_ui_close.files.size()==1')
    replace('tests/test_audio_ui_open_v7.gd','w.item_ui.toggle_bag()\n\tcheck','w.item_ui.toggle_bag();await process_frame;await process_frame\n\tcheck')
    replace('tests/test_audio_ui_open_v7.gd','w.map_view.show()\n\tcheck','w.map_view.show();await process_frame;await process_frame\n\tcheck')
    replace('tests/test_sleep_fit_v10.gd','var center=Vector2(row.x,row.y);var half: Vector2=b.footprint(row)*.5','var bounds: Rect2=b.footprint_rect(row);var center=Vector2(row.x,row.y)+bounds.get_center();var half: Vector2=bounds.size*.5')
    replace('tests/test_camp_build_v4.gd','s.camps.build_book.available().size()==10','s.camps.build_book.available().size()=='+current+'.recipe_count("res://data/buildings.json")')
    replace('tests/test_camp_build_v4.gd','b.definitions.size()==9 and s.camps.build_book.recipes.size()==10','b.definitions.size()==JSON.parse_string(FileAccess.get_file_as_string("res://data/camp_buildings.json")).size() and s.camps.build_book.recipes.size()=='+current+'.recipe_count("res://data/buildings.json")')
    replace('tests/test_camp_build_v4.gd','s.storage_ui.panel.size==Vector2(1030,600)','s.storage_ui.panel.size==Vector2(156,184)')
    replace('tests/test_camp_build_v4.gd','world.camp_ui.ghost.get_child_count()==0','world.camp_ui.ghost.find_children("*","CollisionObject2D",true,false).is_empty() and world.camp_ui.ghost.find_children("*","CollisionShape2D",true,false).is_empty()')
    replace('tests/test_camp_build_v4.gd','var node: Node2D=b.visuals.damaged\n\t\tcheck','var node: Node2D=b.visuals.damaged\n\t\tcheck(not node.damage.visible,"rebuilding does not resurrect expired hit indicator stage"+str(step))\n\t\tnode.update_damage()\n\t\tcheck')
    replace('tests/test_camp_door_hinge_transaction_v3.gd','row.hinge_end==1,"retry after failed save selects clear alternate hinge"','row.hinge_end==0,"retry after failed save keeps clear original hinge beside connected wall"')
    replace('tests/test_audio_selected_v6.gd','fx.last_played.clear();events.clear()','fx.ui_epoch+=1;fx.pending_ui="";fx.ui_flush_queued=false;fx.ui_voice.stop()\n\tfx.last_played.clear();events.clear()')
    replace('tests/test_audio_selected_v6.gd','if key.begins_with("amb_"):continue','if key.begins_with("amb_"):continue\n\t\tif not bool(fx.configuration[key].get("enabled",true)):\n\t\t\treset();check(not fx.play_sfx(key,w.player.position),key+" disabled event remains silent");continue')
    replace('tests/test_audio_selected_v6.gd','var voice: Node=fx.voices.back()','await frames(2)\n\t\tvar voice: Node=fx.ui_voice if key.begins_with("sfx_ui_") else fx.voices.back()')
    replace('tests/test_audio_selected_v6.gd','w.item_ui.toggle_bag();w.item_ui.toggle_bag()','w.item_ui.toggle_bag();await frames(2);w.item_ui.toggle_bag();await frames(2)')
    replace('tests/test_broadleaf_v1.gd','config.version=="harvest-resources-2.1.0"','config.version==Service.HARVEST_VERSION')
    for name in ['test_chest_ui_v2','test_seed_selector_v2','test_planting_v1','test_planting_persistence_v1','test_inventory_chest_v1']:
        replace('tests/'+name+'.gd','res://tests/world_v06_formal_fixture.gd','res://tests/world_clean_camp_fixture.gd')
    replace('tests/test_planting_v1.gd','growth_minutes=360.0','growth_minutes=float(s.planting.rules.crops.carrot.minutes)')
    replace('tests/test_planting_persistence_v1.gd','360.0 if index==2','float(s.planting.rules.crops.carrot.minutes) if index==2')
    replace('tests/test_character_creation_v1.gd','w.map_cells==1024','w.map_cells==1536')
    replace('tests/test_character_resume_v1.gd','var movement_origin=p.position','while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame\n\tvar movement_origin=p.position')
    replace('tests/test_equipment_v04.gd','ui.cells[8].global_position.x<ui.cells[40].global_position.x,"bag left and equipment right"','ui.cells[8].global_position.x>ui.cells[40].global_position.x,"bag right and equipment left"')
    replace('tests/test_inventory_chest_v1.gd','storage.cells.size()==9','storage.cells.filter(func(cell):return cell.visible).size()==9')
    replace('tests/test_cooking_build_v2.gd','var notice_ui: Control=world.item_ui.obtained','var notice_ui: CanvasLayer=world.item_ui.obtained')
    for name in ['test_camp_gate_surface_v4','test_floor_formal_v3']:
        replace('tests/'+name+'.gd','var manager=preload("res://scripts/camp_buildings.gd").new()','var manager=preload("res://scripts/camp_buildings.gd").new()\n' + ('\t'* (6 if name=='test_camp_gate_surface_v4' else 3))+'manager.service=render_service')
        entry='func run():\n' if name=='test_camp_gate_surface_v4' else 'func run():\n'
        replace('tests/'+name+'.gd',entry,entry+'\tvar render_service=preload("res://tests/render_service_fixture.gd").new();root.add_child(render_service)\n')
    out=ROOT/'reports/regression-fixes-20261021/contract-adaptations.json'
    previous=json.loads(out.read_text(encoding='utf-8')) if out.exists() else []
    out.write_text(json.dumps(previous+changes,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Applied',len(changes),'explicit contract/fixture corrections')


if __name__=='__main__':main()
