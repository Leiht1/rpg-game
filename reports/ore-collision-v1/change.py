from pathlib import Path
import json
p=Path('data/harvest_resources.json');d=json.loads(p.read_text(encoding='utf-8-sig'))
shapes={
'stone_outcrop':[[-49,-14],[-40,-31],[-20,-37],[5,-34],[27,-25],[36,-12],[31,-1],[9,3],[-16,2],[-40,-4]],
'flint_outcrop':[[-39,-12],[-32,-30],[-17,-39],[5,-39],[24,-29],[34,-12],[29,0],[7,3],[-18,1],[-32,-4]],
'copper_outcrop':[[-43,-13],[-36,-32],[-17,-43],[8,-42],[29,-28],[38,-11],[31,0],[7,3],[-20,1],[-37,-5]],
'silver_outcrop':[[-43,-13],[-35,-32],[-16,-41],[10,-40],[29,-27],[38,-10],[30,1],[5,3],[-21,0],[-37,-5]],
'gold_outcrop':[[-43,-13],[-35,-32],[-16,-41],[10,-40],[29,-27],[38,-10],[30,1],[5,3],[-21,0],[-37,-5]]}
for k,v in shapes.items():d['resources'][k]['collision_outline']=v;d['resources'][k]['collision_outline_width']=192
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
p=Path('scripts/harvest_node.gd');s=p.read_text(encoding='utf-8-sig');s=s.replace('for i in 12: points.append(Vector2(cos(TAU*i/12)*float(definition.collision[0]),sin(TAU*i/12)*float(definition.collision[1])))','''if definition.has("collision_outline"):
			var factor: float=float(definition.width)/float(definition.collision_outline_width)
			for point in definition.collision_outline:points.append(Vector2(float(point[0]),float(point[1]))*factor)
		else:
			for i in 12: points.append(Vector2(cos(TAU*i/12)*float(definition.collision[0]),sin(TAU*i/12)*float(definition.collision[1])))''');p.write_text(s,encoding='utf8')
