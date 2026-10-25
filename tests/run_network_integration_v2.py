"""Reuse real-window scenarios with fresh outputs and no login ordering barrier."""
from pathlib import Path
import argparse
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'reports/network-integration-v2'

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--mode', choices=['gameplay', 'season', 'weather', 'gear', 'ice'], required=True)
    p.add_argument('--runtime', type=Path)
    p.add_argument('--delay', type=float, default=0)
    p.add_argument('--cells', type=int, default=1536)
    args = p.parse_args()
    modes = {
        'gameplay': ('run_network_gameplay.py', 'network_gameplay_native.gd', 'network-gameplay-v5'),
        'season': ('run_season_features_network.py', 'season_features_network_native.gd', 'season-features-v1'),
        'weather': ('run_weather_network.py', 'weather_network_native.gd', 'weather-v1'),
        'gear': ('run_season_features_network.py', 'season_features_network_native.gd', 'season-features-v1'),
        'ice': ('run_season_features_network.py', 'season_features_network_native.gd', 'season-features-v1'),
    }
    runner_name, native_name, old = modes[args.mode]
    label = args.mode + ('-delay' if args.delay else '')
    folder = OUT / label
    folder.mkdir(parents=True, exist_ok=True)
    native = (ROOT/'tests'/native_name).read_text(encoding='utf-8')
    begin = native.index('\tvar ready:=FileAccess.open(folder.path_join("login"')
    end = native.index('\tresponse=await network.call_api("resume",{})', begin)
    native = native[:begin] + '\t# Each client proceeds immediately after its own login.\n' + native[end:]
    native = native.replace('Engine.set_meta("season_features_preview",true)', 'pass # Normal runtime assets only.')
    native = native.replace('reports/'+old+'/', 'reports/network-integration-v2/'+label+'/')
    if args.mode == 'gameplay':
        marker='\tverify(world.actors.size()==1,"second real player visible")'
        native=native.replace(marker,marker+'''
\tfor entry_tick in 400:
\t\tif world.item_service.combat.personal.phase=="alive" and not world.player.input_blocked:break
\t\tawait create_timer(.025).timeout
\tverify(world.item_service.combat.personal.phase=="alive","authority completed entry before gameplay input")
''')
        native=native.replace('\tawait key(KEY_E,true);await key(KEY_E,false)', '\tprint("PICKUP_CONTEXT phase=",world.item_service.combat.personal.phase," blocked=",world.player.input_blocked," action=",world.player.action)\n\tawait key(KEY_E,true);await key(KEY_E,false)')
    if args.mode == 'gear':
        steps=(ROOT/'tests/network_gear_steps_v2.txt').read_text(encoding='utf-8')
        native=native.replace('\tvar output={"checks":checks', steps+'\n\tvar output={"checks":checks')
    if args.mode == 'ice':
        subprocess.run(['D:/Godot/Godot_v4.7.2-stable_win64.exe','--headless','--path',str(ROOT),'--script',str(ROOT/'tests/network_ice_fixture_v2.gd'),'--',str(folder/'point.json')],check=True)
        native=native.replace('\tworld.player.set_physics_process(false)','\t# Real player physics remains active on the frozen lake.')
        native=native.replace('\tvar output={"checks":checks',(ROOT/'tests/network_ice_steps_v2.txt').read_text(encoding='utf-8')+'\n\tvar output={"checks":checks')
    # res:// belongs to the exported PCK, which deliberately excludes reports.
    # Write test evidence to the source workspace's absolute report directory.
    native=native.replace('res://reports/', (str(ROOT/'reports').replace('\\','/')+'/'))
    script = folder / 'native.gd'
    script.write_text(native, encoding='utf-8')
    runner = (ROOT/'tests'/runner_name).read_text(encoding='utf-8')
    runner = runner.replace('ROOT = Path(__file__).resolve().parents[1]', 'ROOT = Path('+repr(str(ROOT))+')')
    runner = runner.replace('D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe', 'D:/Godot/Godot_v4.7.2-stable_win64.exe')
    runner = runner.replace('reports/'+old+'/', 'reports/network-integration-v2/'+label+'/')
    runner = runner.replace('tests/'+native_name, str(script.relative_to(ROOT)).replace('\\','/'))
    runner = runner.replace('["python", str(ROOT/', '[sys.executable, str(ROOT/')
    runner = runner.replace('if options.runtime else [sys.executable, str(ROOT/"tests/network_gameplay_delay_server.py")', 'if options.runtime and not options.delay else [sys.executable, str(ROOT/"tests/network_gameplay_delay_server.py")')
    if args.mode == 'gear':
        runner=runner.replace('"gender": "male", "hair_id": "male_natural"', '"gender": "male" if i==0 else "female", "hair_id": "male_natural" if i==0 else "female_bob"')
        runner=runner.replace("        for label in ('sync-first','sync-second'):", """        for index, token in enumerate(tokens):
            c=service.character(service.state['accounts'][service.sessions[token]['account']])
            c['slots'][14]={'item_id':'wool','count':30}
            c['slots'][15]={'item_id':'plant_fiber','count':80}
            c['slots'][1]={'item_id':'stone_axe','count':1,'instance_id':'gear-axe-'+str(index),'durability':100,'state':{}}
            c['slots'][2]={'item_id':'stone_pickaxe','count':1,'instance_id':'gear-pick-'+str(index),'durability':100,'state':{}}
            c['gameplay']['slots']=c['slots']
            c['x']+=index*110
        for label in ('sync-first','sync-second'):""")
    if args.mode == 'ice':
        runner=runner.replace("        for label in ('sync-first','sync-second'):", """        ice=json.loads((ROOT/'reports/network-integration-v2/ice/point.json').read_text())
        for index, token in enumerate(tokens):
            c=service.character(service.state['accounts'][service.sessions[token]['account']])
            c.update(x=ice['x']+index*90,y=ice['y'])
            c['gameplay']['combat_personal']['phase']='alive'
            c['gameplay']['body']['weather_body'].update(wetness=0,cold_level=0,extreme_minutes=0)
        for label in ('sync-first','sync-second'):""")
    # Delay both gameplay and movement replies in the source-service delay run.
    runner = runner.replace('"--delay", str(options.delay), "--config"', '"--delay", str(options.delay), "--delay-scope", "gameplay", "--config"')
    generated = folder / 'runner.py'
    generated.write_text(runner, encoding='utf-8')
    command = [sys.executable, str(generated), '--cells', str(args.cells), '--delay', str(args.delay)]
    if args.runtime: command += ['--runtime', str(args.runtime)]
    try:
        subprocess.run(command, check=True)
    finally:
        for file in (script, script.with_suffix('.gd.uid'), generated):
            file.unlink(missing_ok=True)

if __name__ == '__main__': main()
