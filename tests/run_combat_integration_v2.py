"""Existing dual-client combat scenario updated to the current free-PvP rule."""
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/network-integration-v2/combat-native'
RUNTIME=ROOT/'reports/.tmp/network-integration-v2/runtime'
OUT.mkdir(parents=True,exist_ok=True)
native=(ROOT/'tests/network_combat_native_v1.gd').read_text(encoding='utf-8')
native=native.replace('func press_f() -> void:\n', '''func press_f() -> void:
\t# Knockback changes range between strikes; approach through real movement.
\tvar peer=world.actors.values()[0]
\tfor step in 30:
\t\tvar offset: Vector2=peer.target_position-world.player.position
\t\tif offset.length()<34:break
\t\tvar code: int=(KEY_D if offset.x>0 else KEY_A) if absf(offset.x)>absf(offset.y) else (KEY_S if offset.y>0 else KEY_W)
\t\tvar walk:=InputEventKey.new();walk.physical_keycode=code;walk.keycode=code;walk.pressed=true;Input.parse_input_event(walk)
\t\tawait create_timer(.05).timeout
\t\twalk=walk.duplicate();walk.pressed=false;Input.parse_input_event(walk)
\tawait create_timer(.35).timeout
\tvar offset: Vector2=peer.target_position-world.player.position
\tprint("ATTACK_DISTANCE ",offset.length())
\tprint("ATTACK_CONTEXT phase=",world.item_service.combat.personal.phase," action=",world.player.action," blocked=",world.player.input_blocked," hp=",world.item_service.body.health," peer=",peer.target_position," self=",world.player.position)
\tverify(offset.length()<50,"attack target within actual range after knockback")
\tworld.player.facing=("right" if offset.x>0 else "left") if absf(offset.x)>absf(offset.y) else ("front" if offset.y>0 else "back")
''')
native=native.replace('await create_timer(1.3).timeout;await settle()', 'await create_timer(1.3).timeout;await settle();print("ATTACK_RESULT error=",world.last_error," attack=",world.item_service.combat.personal.attack," local_hp=",world.item_service.body.health)')
native=native.replace('print("ATTACK_RESULT error=",world.last_error," attack=",world.item_service.combat.personal.attack," local_hp=",world.item_service.body.health)', '''print("ATTACK_RESULT error=",world.last_error," attack=",world.item_service.combat.personal.attack," local_hp=",world.item_service.body.health)
\tfor confirmed in 300:
\t\tif world.item_service.combat.personal.attack.is_empty() and world.item_service.combat.attack_preview.is_empty():break
\t\tawait create_timer(.05).timeout
\tverify(world.item_service.combat.personal.attack.is_empty(),"authority completed attack before checking damage")''')
native=native.replace('await wait_mark("safe-attack");','await wait_mark("safe-attack");await settle();await world.sync_server();')
native=native.replace('await wait_mark("first-hit");','await wait_mark("first-hit");await settle();await world.sync_server();')
native=native.replace('await wait_mark("reply-hit")','await wait_mark("reply-hit");await settle();await world.sync_server()')
native=native.replace('await wait_mark("declined-attack")','await wait_mark("declined-attack");await settle();await world.sync_server()')
native=native.replace('verify(world.item_service.body.health==100,"no consent no damage")','print("FIRST_HIT_HP ",world.item_service.body.health);verify(world.item_service.body.health==100,"no consent no damage")')
native=native.replace('combat.duel(other,true);await settle();','await settle();').replace('combat.duel(other,false);await settle();','await settle();')
native=native.replace('accepted duel takes exactly one additional hit','second free PvP attack takes exactly one additional hit')
native=native.replace('ended duel restores free PvP damage','third free PvP strike remains authoritative')
native=native.replace('mark("login"+str(int(fixture.index)));await wait_mark("login"+str(1-int(fixture.index)))','mark("login"+str(int(fixture.index)))')
native=native.replace('world.item_service.body.health==100,"no consent no damage"','world.item_service.body.health<=91.2 and world.item_service.body.health>90,"free PvP takes exactly one hit without consent"')
native=native.replace('world.item_service.body.health<=91.2 and world.item_service.body.health>0,"accepted duel takes one hit"','world.item_service.body.health<=82.2 and world.item_service.body.health>81,"accepted duel takes exactly one additional hit"')
native=native.replace('world.item_service.body.health>90.9,"ended duel cannot damage"','world.item_service.body.health<=82.2 and world.item_service.body.health>81,"ended duel restores free PvP damage"')
native=native.replace('accepted duel takes exactly one additional hit','second free PvP attack takes exactly one additional hit').replace('ended duel restores free PvP damage','third free PvP strike remains authoritative')
native=native.replace('res://reports/.tmp/combat-v1/',str(OUT).replace('\\','/')+'/')
native=native.replace('verify(combat.personal.phase=="dying","boar causes formal death once")','print("DEATH_CONTEXT hp=",world.item_service.body.health," phase=",combat.personal.phase," boars=",combat.state.boars);verify(combat.personal.phase=="dying","boar causes formal death once")')
script=OUT/'native.gd';script.write_text(native,encoding='utf-8')
runner=(ROOT/'tests/run_combat_native_v1.py').read_text(encoding='utf-8')
runner=runner.replace('ROOT=Path(__file__).resolve().parents[1]', 'ROOT=Path('+repr(str(ROOT))+')')
runner=runner.replace("OUT=ROOT/'reports/combat-v1'",'OUT=Path('+repr(str(OUT))+')')
runner=runner.replace("ENGINE=Path('D:/Godot/Godot_v4.7.2-stable_win64_console.exe')",'ENGINE=Path('+repr(str(RUNTIME/'Client/Windrest.exe'))+')')
runner=runner.replace('godot=str(ENGINE),project=str(ROOT)', 'godot='+repr(str(RUNTIME/'Server/WorldWorker.exe'))+',project='+repr(str(RUNTIME/'Server')))
runner=runner.replace("\n   w=api('create_world'", "\n   svc.terrain_factory=lambda world:(world.update(seed=271828) or svc.make_terrain(world))\n   w=api('create_world'")
fixture_source=(ROOT/'tests/network_combat_server_v1.py').read_text(encoding='utf-8')
fixture_source=fixture_source.replace("str(Path(__file__).resolve().parents[1]/'tools/network')",repr(str(ROOT/'tools/network')))
fixture_source=fixture_source.replace("['health']=12","['health']=1").replace("target['x']-38","target['x']-32")
fixture_server=OUT/'fixture-server.py';fixture_server.write_text(fixture_source,encoding='utf-8')
runner=runner.replace("str(ROOT/'tests/network_combat_server_v1.py')",repr(str(fixture_server)))
runner=runner.replace("str(ENGINE),'--path',str(ROOT),'--script',str(ROOT/'tests/network_combat_native_v1.gd')", "str(ENGINE),'--path',"+repr(str(RUNTIME/'Client'))+",'--script',"+repr(str(script)))
generated=OUT/'runner.py';generated.write_text(runner,encoding='utf-8')
try:subprocess.run([sys.executable,str(generated),'--delay','.1'],check=True)
finally:
    for file in (script,script.with_suffix('.gd.uid'),generated,fixture_server):file.unlink(missing_ok=True)
