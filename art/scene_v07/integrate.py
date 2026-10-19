from pathlib import Path
import json,hashlib,shutil
from PIL import Image
out=Path('assets/environment/stylized_v3');out.mkdir(exist_ok=True)
src=Path('prototypes/scene-study-v07')
for name in ['tree_0','tree_1','rock_0','rock_1']:
 shutil.copy2(src/(name+'.png'),out/(name+'.png'))
shutil.copy2(src/'ground.png',out/'grass.png')
for name,source,size in [('tuft_0','flowers',(35,22)),('tuft_1','leaves',(34,26)),('tuft_2','flowers',(35,22))]:
 im=Image.open(src/(source+'.png')).convert('RGBa').resize(size,Image.Resampling.LANCZOS).convert('RGBA')
 im.save(out/(name+'.png'))
Path('art/scene_v07/integration-before.json').write_text(json.dumps({p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in ['scripts/player.gd','scripts/world_generator.gd','scripts/world.gd','scenes/world.tscn','project.godot','assets/hero/cartoon/character.tscn']},indent=2),encoding='utf-8')
p=Path('scripts/chunk_stream.gd');s=p.read_text(encoding='utf-8-sig')
s=s.replace('const FILES :=', 'const ART_VERSION := "scene-stylized-3.0"\nconst FILES :=')
s=s.replace('assets/environment/cartoon_v2/%s.png','assets/environment/stylized_v3/%s.png')
s=s.replace('assets/environment/ground_v03/grass.png','assets/environment/stylized_v3/grass.png')
s=s.replace('shared_material.set_shader_parameter("seed_offset",float(generator.world_seed%10000))','shared_material.set_shader_parameter("seed_offset",float(generator.world_seed%10000))\n\tshared_material.set_shader_parameter("ground_origin",generator.spawn)')
s=s.replace('packet["ground_stamps"]=Ground.plan(local_gen,coord,packet.props)','packet["ground_stamps"]=[] # Approved surface replaces legacy grass/soil/puddle stamps.')
s=s.replace('prop.kind=entry.kind','prop.kind=entry.kind\n\t\tprop.candidate_mode=1 # Tight contact shadow, no legacy grass blades/soil halo.\n\t\tif entry.kind>=4:\n\t\t\tprop.visible=entry.position.distance_to(generator.spawn)>160 and (str(entry.id).begins_with("clearing:") or generator.random_at(roundi(entry.position.x),roundi(entry.position.y),682)<.20)')
p.write_text(s,encoding='utf-8')
p=Path('scripts/terrain.gdshader');s=p.read_text(encoding='utf-8-sig')
s=s.replace('uniform float seed_offset = 0.0;','uniform float seed_offset = 0.0;\nuniform vec2 ground_origin = vec2(0.0);')
a=s.index('\t// Authored grass surface');b=s.index('\tfloat area =',a)
s=s[:a]+'''\t// Approved plate at its reviewed world scale, anchored to the spawn view.
\t// Triangle-wave addressing joins reflected edges continuously across chunks.
\tvec2 plate_uv=(world_point-ground_origin)/vec2(1280.0,720.0)+vec2(.5);
\tvec2 grass_uv=vec2(1.0)-abs(mod(plate_uv,vec2(2.0))-vec2(1.0));
\tvec3 grass = texture(grass_texture,grass_uv).rgb;
\t// Keep biome shading restrained; do not reintroduce large colour patches.
\tvec3 tint=clamp(field.rgb/vec3(.66,.80,.47),vec3(.86),vec3(1.08));
\tland=grass*mix(vec3(1.0),tint,.18);
''' +s[b:]
p.write_text(s,encoding='utf-8')
p=Path('ART_STYLE.md');s=p.read_text(encoding='utf-8-sig');s=s.replace('只在出生点测试场景制作候选，保持同Seed、同镜头、相同角色及树石位置、显示尺度和脚底支点；不改变地图结构、生成规则、碰撞或交互。方向已确认，具体新资产仍待用户视觉验收；不全图推广。本轮输出地面、树、石、少量装饰同屏真实Godot预览。','2026-10-16 用户确认 V0.7 并明确授权接入游戏。正式场景使用 assets/environment/stylized_v3 的树、石、地表及花叶装饰；保留旧资源。相同角色、树石位置、逻辑显示画布和脚底支点，不改变地图结构、生成规则、碰撞或交互。地表按1280×720世界尺寸镜像连续采样；低密度花叶复用原装饰坐标并进行纯视觉筛选，中央160px留净。美术版本scene-stylized-3.0；地图生成器版本不变。')
s=s.replace('真实场景对照、pending_user。','真实场景对照；V0.7已获用户确认并授权接入。')
p.write_text(s,encoding='utf-8')
p=Path('SCENE_ART_WORKFLOW.md');s=p.read_text(encoding='utf-8-sig');s+='\n2026-10-16：用户已确认V0.7并授权正式接入；本次可推广已确认树石/地表/花叶，不再适用V0.7 pending_user限制。后续未确认新素材仍执行候选门槛。\n';p.write_text(s,encoding='utf-8')
