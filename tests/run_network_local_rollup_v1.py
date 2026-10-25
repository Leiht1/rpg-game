"""Extend the existing isolated two-window runner without replacing old evidence."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "reports/network-local-rollup-v1"
OUT.mkdir(parents=True, exist_ok=True)
native = (ROOT / "tests/season_features_network_native.gd").read_text(encoding="utf-8")
native = native.replace('Engine.set_meta("season_features_preview",true)', 'pass # Normal online entry; candidate art stays disabled.')
native = native.replace('reports/season-features-v1/network/', 'reports/network-local-rollup-v1/network/')
marker = '\tvar output={"checks":checks'
insertion = '''
	world.item_service.inventory.equip(0)
	world.item_service.toggle_lantern(1)
	for i in 300:
		var actor=world.actors.values()[0]
		if actor.lamp_item=="silver_lantern" and actor.network_equipment.get("main_hand",{}).get("item_id","")=="rain_umbrella":break
		await create_timer(.05).timeout
	var remote=world.actors.values()[0]
	verify(remote.lamp_item=="silver_lantern","other client's active lamp arrives through server roster")
	verify(remote.network_equipment.get("main_hand",{}).get("item_id","")=="rain_umbrella","remote left umbrella equipment synchronized")
	for i in 120:
		if world.environment_view.material_effect.get_shader_parameter("camp_count")>0:break
		await create_timer(.05).timeout
	verify(world.environment_view.material_effect.get_shader_parameter("camp_count")>0,"remote lamp reaches actual world lighting shader pos="+str(remote.position)+" self="+str(world.player.position))
	for direction in ["front","back","left","right"]:
		world.player.facing=direction;world.player.action="pickup";world.player.action_clock=.25;world.player.action_committed=true
		for i in 120:
			if remote.facing==direction and remote.action=="pickup":break
			await create_timer(.05).timeout
		verify(remote.facing==direction and remote.action=="pickup","remote original pickup pose "+direction)
		await process_frame
		verify(is_instance_valid(remote.held_tool.canopy) and remote.held_tool.canopy.visible,"remote canopy preserved during pickup "+direction)
		verify(remote.character.get_node("Visual/Pelvis/ArmL/HeldTool").visible,"remote native left arm holds umbrella "+direction)
		var done:=FileAccess.open(folder.path_join("pose-"+direction+str(int(fixture.index))),FileAccess.WRITE);done.store_string("ready");done.close()
		for i in 300:
			if FileAccess.file_exists(folder.path_join("pose-"+direction+str(1-int(fixture.index)))):break
			await create_timer(.05).timeout
	world.player.action=""
	world.item_service.toggle_lantern(1)
	for i in 200:
		if remote.lamp_item.is_empty():break
		await create_timer(.05).timeout
	verify(remote.lamp_item.is_empty(),"remote lamp switch off synchronized")
'''
native = native.replace(marker, insertion + marker)
script = OUT / "native.gd"
script.write_text(native, encoding="utf-8")
runner = (ROOT / "tests/run_season_features_network.py").read_text(encoding="utf-8")
runner = runner.replace('ROOT = Path(__file__).resolve().parents[1]', 'ROOT = Path('+repr(str(ROOT))+')')
runner = runner.replace('reports/season-features-v1/network/private', 'reports/network-local-rollup-v1/network/private')
runner = runner.replace('tests/season_features_network_native.gd', 'reports/network-local-rollup-v1/native.gd')
marker = "        for label in ('sync-first','sync-second'):"
runner = runner.replace(marker, '''        for token in tokens:
            c=service.character(service.state['accounts'][service.sessions[token]['account']])
            c['slots'][1]={'item_id':'silver_lantern','count':1,'lamp_id':'rollup-'+c['id'],'fuel':3600.0}
            c['gameplay']['slots']=c['slots']
''' + marker)
runner_path = OUT / "runner.py"
runner_path.write_text(runner, encoding="utf-8")
try:
    subprocess.run([sys.executable, str(runner_path)], check=True)
finally:
    script.unlink(missing_ok=True)
    script.with_suffix(".gd.uid").unlink(missing_ok=True)
    runner_path.unlink(missing_ok=True)
