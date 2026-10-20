"""Rebuild curated catalog from the project's audited collection and current implementations."""
import re
from pathlib import Path
from core import atomic
ROOT=Path(__file__).resolve().parents[2]
groups={
 '移动与采集':('角色与采集',['scripts/audio_fx.gd','scripts/harvest_node.gd','scripts/player.gd'],'resource'),
 '背包、装备与界面':('背包与界面',['scripts/item_ui.gd','scripts/item_inventory.gd'],'ui'),
 '建造与营地家具':('营地建造',['scripts/camp_grid.gd','scripts/item_service.gd'],'building'),
 '制作、火焰、料理与工业':('料理与工业',['scripts/campfire.gd','scripts/industry_service.gd','scripts/item_service.gd'],'building'),
 '种植':('种植',['scripts/planting.gd'],'resource'),
 '鸡羊与养殖':('动物',['scripts/animals.gd','scripts/animal_feed.gd'],'animal'),
 '食用、睡眠与身体':('食用与睡眠',['scripts/item_service.gd','scripts/environment_view.gd'],'player'),
 '天气与自然环境':('天气与环境',['scripts/environment_view.gd','scripts/world_environment.gd','scripts/world_chunk.gd'],'ambience')}

def build():
    rows=[]; group=None
    for line in (ROOT/'AUDIO_COLLECTION.md').read_text(encoding='utf-8-sig').splitlines():
        if line.startswith('## '):
            group=next((v for k,v in groups.items() if k in line),None)
        if not group or not line.startswith('|'):continue
        m=re.search(r'`((?:sfx|amb)_[a-z0-9_]+)\.(?:wav|ogg)`',line)
        if not m:continue
        key=re.sub('_01$','',m[1]); cells=[c.strip().replace('~','').replace('**','') for c in line.split('|')]
        # The discomfort and decorative bird suggestions have no discrete gameplay event.
        if key in ['sfx_body_discomfort','sfx_bird_distant']:continue
        name=cells[3]
        names={'sfx_chop_hit':'砍树命中','sfx_step_grass':'草地脚步（走 / 跑）','sfx_step_dirt':'泥地脚步（走 / 跑）','sfx_step_stone':'石面 / 石路脚步（走 / 跑）','sfx_step_wood':'木地板脚步（走 / 跑）'}
        rows.append({'id':key,'name':names.get(key,name),'category':group[0],'output_group':'player' if key.startswith('sfx_step_') else group[2],'evidence':[p for p in group[1] if (ROOT/p).exists()],'description':cells[4]})
    for key,name,category,source,token in [
        ('sfx_fishing_cast','钓鱼抛竿','钓鱼','fishing.gd','try_start'),('sfx_fishing_bite','鱼咬钩','钓鱼','fishing.gd','bite'),('sfx_fishing_success','钓鱼成功','钓鱼','fishing.gd','commit_reward'),('sfx_fishing_failure','钓鱼失败','钓鱼','fishing.gd','failure'),
        ('sfx_merchant_trade','商人交易成功','交易','merchant.gd','buy'),('sfx_crop_fertilize','施肥成功','种植','planting.gd','fertilize'),
        ('sfx_compost_add','堆肥投料','料理与工业','camp_expansion.gd','compost'),('sfx_smoker_start','熏制开始','料理与工业','camp_expansion.gd','smok'),('sfx_build_repair','维修建筑','营地建造','camp_expansion.gd','repair')]:
        p=ROOT/'scripts'/source
        if p.exists() and token in p.read_text(encoding='utf-8-sig'):
            rows.append({'id':key,'name':name,'category':category,'output_group':'building' if category in ['料理与工业','营地建造'] else 'resource','evidence':['scripts/'+source]})
    atomic(Path(__file__).with_name('events.json'),rows)
    print(f'{len(rows)} events')
if __name__=='__main__':build()
