from pathlib import Path
import json
p=Path('data/sleep_rules.json');d=json.loads(p.read_text(encoding='utf8'))
for kind,normal,vertical in [('wood_bed',[-87.5,-73.4375,175,71.875],[-43.75,-126.5625,87.5,140.234375]),('straw_mat',[-87.5,-36.71875,175,48.046875],[-43.75,-107.03125,87.5,126.171875]),('sleeping_bag',[-87.5,-42.96875,175,60.546875],None)]:
 d['facilities'][kind]['collision_rect']=normal
 if vertical:d['facilities'][kind]['vertical_collision_rect']=vertical
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
