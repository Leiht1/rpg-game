from pathlib import Path
import json
p=Path('data/sleep_rules.json');d=json.loads(p.read_text(encoding='utf8'))
for name in ['wood_bed','straw_mat','sleeping_bag']:
 f=d['facilities'][name];f['visual_scale']=.390625
 f['footprint']=[round(v/ .64) for v in f['footprint']]
 if 'vertical_footprint' in f:f['vertical_footprint']=[round(v/.64) for v in f['vertical_footprint']]
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
p=Path('scripts/sleep_head_cover.gd');s=p.read_text(encoding='utf8');s=s.replace('group=Node2D.new();group.name="SleepHeadCover";player.add_child(group)','group=Node2D.new();group.name="SleepHeadCover";group.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;player.add_child(group)')
s=s.replace('pivot.position=anchor;pivot.rotation=0 if vertical else -PI/2','anchor/= .64\n\tpivot.position=anchor;pivot.rotation=0 if vertical else -PI/2').replace('pivot.scale=Vector2.ONE*.64','pivot.scale=Vector2.ONE')
s=s.replace('cover.scale=Vector2.ONE*.25','cover.position/= .64\n\tcover.scale=Vector2.ONE*float(preload("res://scripts/sleep_rules.gd").facility(source).visual_scale)')
s=s.replace('if node is Node2D: value+=str(node.transform)','if node is Sprite2D: value+=str(node.scale)')
p.write_text(s,encoding='utf8')
