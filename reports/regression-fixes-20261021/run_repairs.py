"""Targeted repairs: keep all preceding evidence and real user data intact."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('continuation',ROOT/'reports/full-regression-device-20261021/continue_tests.py')
previous=importlib.util.module_from_spec(spec);spec.loader.exec_module(previous)
r=previous.r
previous.OUT=OUT;r.OUT=OUT
r.WORK=r.WORK/'repair-round'
r.WORK.mkdir(exist_ok=True)
r.RESULTS=json.loads((OUT/'results.json').read_text(encoding='utf-8')) if (OUT/'results.json').exists() else []
for row in r.RESULTS:
    log=OUT/row.get('log','')
    if row['label']=='test_world_map_v3_distribution' and log.is_file() and 'DISTRIBUTION ' not in log.read_text(encoding='utf-8',errors='replace'):
        row.setdefault('status_at_execution',row['status'])
        row['status']='incomplete'
        row['review']='Missing final completion marker; partial sample records are not a full pass.'
shutil.copy2(ROOT/'reports/full-regression-20261021/bootstrap.gd',OUT/'bootstrap.gd')


def main():
    import msvcrt
    lock=open(r.WORK/'active-run.lock','a+b')
    if lock.seek(0,2)==0:lock.write(b'0');lock.flush()
    lock.seek(0)
    try:msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
    except OSError:raise RuntimeError('Another repair batch is active; run native tests serially.')
    r.RESULTS=json.loads((OUT/'results.json').read_text(encoding='utf-8'))
    p=argparse.ArgumentParser()
    p.add_argument('suite')
    p.add_argument('--headless',action='store_true')
    p.add_argument('--timeout',type=int,default=150)
    options,args=p.parse_known_args()
    baseline=r.WORK/'player-before.json'
    private=r.WORK/'independent-before.private.json'
    if not baseline.exists():r.write_json(baseline,r.fingerprints())
    if not private.exists():r.write_json(private,previous.independent_fingerprint())
    # Only copy changed runtime/test files, not media, data or unrelated reports.
    names=subprocess.check_output(['git','ls-files','-m','-o','--exclude-standard','-z'],cwd=ROOT).decode('utf-8').split('\0')
    for name in names:
        if name.startswith(('scripts/','tests/','data/')) and (ROOT/name).is_file():
            target=r.PROJECT/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
    if options.suite=='network-rules':
        r.execute('game-rules-final-repairs',[sys.executable,'-m','unittest','discover','-s','tests','-p','test_network_game_host.py','-v'],240,category='service')
    groups={
        'network-rules':[],
        'serial-final':[(n,a,False,150) for n,a in [('test_movement_regression',[]),('test_cooking_discovery_v1',[]),('test_crafting_v1',[]),('test_broadleaf_v1',[]),('test_camp_build_v4',['--formal']),('test_floor_formal_v3',[])]],
        'default-only':[(n,a,False,150) for n,a in [('test_crafting_v1',[]),('test_broadleaf_v1',[]),('test_camp_build_v4',['--formal']),('test_floor_formal_v3',[])]],
        'exit-rechecks':[(n,[],False,150) for n in ['test_crafting_v1','test_food_v2','test_broadleaf_v1','test_audio_ui_open_v7','test_audio_ui_single_v8','test_floor_formal_v3','test_camp_h_damage_window_v4','test_camp_door_hinge_transaction_v3','test_sleep_fit_v10','test_movement_regression','test_cooking_discovery_v1']],
        'final-safety':[(n,a,False,180) for n,a in [('test_camp_build_v4',['--formal']),('test_harvest_edges_v05',[]),('test_body_v2',[])]],
        'batch-contracts':[(n,[],False,150) for n in ['test_crafting_v1','test_food_v2','test_broadleaf_v1','test_audio_ui_open_v7','test_audio_ui_single_v8','test_camp_gate_surface_v4','test_floor_formal_v3','test_camp_h_damage_window_v4','test_camp_door_hinge_transaction_v3','test_sleep_fit_v10','test_inventory_chest_v1']],
        'batch-resources':[(n,[],False,240) for n in ['test_harvest_v05','test_harvest_edges_v05','test_harvest_followup_v051','test_movement_regression','test_grounding_interactions','test_resources_v031']],
        'batch-ecology':[(n,[],True,240) for n in ['test_ore_distribution_v06','test_world_map_v3_logic','test_fishing_population_v2']],
        'batch-current':[(n,[],False,180) for n in ['test_runtime_exit','test_inventory_chest_v1','test_animals_v1','test_cooking_build_v2','test_industry_refine_v2','test_body_v2','test_equipment_v04','test_fishing_formal_v1','test_item_actions_followup_v051','test_campfire_drag_v1','test_audio_selected_v6']],
        'batch-resource-repairs':[(n,[],False,240) for n in ['test_harvest_v05','test_harvest_edges_v05','test_resources_v031','test_movement_regression','test_grounding_interactions','test_ore_runtime_v06']],
        'batch-recheck':[(n,[],False,180) for n in ['test_inventory_chest_v1','test_cooking_build_v2','test_body_v2','test_equipment_v04','test_fishing_formal_v1','test_campfire_drag_v1','test_audio_selected_v6','test_player','test_campfire_flame_v2','test_scissors_exploration_v1','test_shear_sign_map_v1','test_animals_edges_v1','test_ecology_signpost_revision_v1','test_ecology_signpost_revision_ui_v1']],
        'batch-final-contracts':[(n,a,False,180) for n,a in [('test_player',[]),('test_equipment_v04',[]),('test_campfire_flame_v2',[]),('test_cooking_discovery_v1',[]),('test_cooking_discovery_v1',['--restart-read']),('test_industry_v1',['formal']),('test_industry_v1',['formal','read']),('test_camp_build_v4',['--formal']),('test_camp_effects_v11',[])]],
        'batch-remaining':[(n,a,False,t) for n,a,t in [('test_movement_regression',[],90),('test_grounding_interactions',[],90),('test_resources_v031',[],120),('test_harvest_v05',[],240),('test_industry_v1',['formal'],120),('test_camp_effects_v11',[],90),('test_ore_distribution_v06',[],180),('test_world_map_v3_logic',[],90),('test_fishing_population_v2',[],120)]],
    }
    for name,forwarded,headless,timeout in groups.get(options.suite,[(options.suite,args,options.headless,options.timeout)]):
        tag='-logic' if '--logic' in forwarded else '-restart' if '--restart-read' in forwarded or 'read' in forwarded else ''
        r.godot(name,forwarded,headless=headless,timeout=timeout,tag=tag)
        if name=='test_world_map_v3_distribution' and 'DISTRIBUTION ' not in (OUT/r.RESULTS[-1]['log']).read_text(encoding='utf-8',errors='replace'):
            r.RESULTS[-1]['status_at_execution']=r.RESULTS[-1]['status']
            r.RESULTS[-1]['status']='incomplete'
            r.RESULTS[-1]['review']='Missing final distribution completion marker; exit zero alone is insufficient.'
            r.write_json(OUT/'results.json',r.RESULTS)
    before=json.loads(baseline.read_text(encoding='utf-8'));after=r.fingerprints()
    r.write_json(OUT/'save-protection.json',dict(before_count=len(before),after_count=len(after),
                 changed=[p for p in before if before[p]!=after.get(p)],added=[p for p in after if p not in before],
                 independent_server_unchanged=json.loads(private.read_text(encoding='utf-8'))==previous.independent_fingerprint()))


if __name__=='__main__':main()
