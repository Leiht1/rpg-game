"""Publish approved breathing frames while preserving every existing walk PNG."""
from pathlib import Path
import argparse, copy, hashlib, json, shutil
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
HERO=ROOT/'assets/hero'; WORK=ROOT/'art/hero_breathe_runtime_v03'
APPROVED=ROOT/'art/hero_idle_breathe_preview_v02'
VERSION='windrest-character-template-3'; ANCHOR=[64,112]

def read(p): return json.loads(p.read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def stage():
    assert not WORK.exists(), 'Keep the original integration backup; do not restage.'
    WORK.mkdir(parents=True)
    shutil.copytree(HERO,WORK/'previous_runtime')
    for path in ['scripts/player.gd','tests/test_player.gd','tests/capture_character.gd',
                 'tools/verify_character.py','CHARACTER_MODULAR_RULES.md','reports/CHARACTER_VALIDATION.md',
                 'reports/character-art-tests.json','reports/player-tests.json']:
        shutil.copy2(ROOT/path,WORK/('previous_'+Path(path).name))
    save(WORK/'unchanged_game_baseline.json',{str(p.relative_to(ROOT)).replace('\\','/'):sha(p)
        for folder in ['scripts','scenes'] for p in (ROOT/folder).rglob('*')
        if p.is_file() and p.suffix not in ['.uid'] and p.name!='player.gd'} |
        {'project.godot':sha(ROOT/'project.godot')})
    staged=WORK/'staged'; final=staged/'final_sprite'
    shutil.copytree(HERO/'final_sprite',final)
    manifest=read(HERO/'animation/clips.json'); manifest['frames']=[]
    manifest['name']='windrest-hero'; manifest['art_source']='existing'
    registration=read(HERO/'animation/registration.json'); registration['template_version']=VERSION
    registration['idle_source']='user accepted hero_idle_breathe_preview_v02 on 2026-10-15'
    registration['idle_policy']='copy the approved 128x128 complete PNGs byte for byte; no resampling or local edits'
    template=read(HERO/'modular_plan/template.json'); template['version']=VERSION
    template['timing'].update({'idle_ticks_per_frame':45,'idle_cycle_frames':4,'idle_cycle_ms':3000})
    template['idle_phase_semantics']=['neutral','inhale','release','exhale']
    for d,sd in [('front','front'),('back','back'),('side','right')]:
        walks=[r for r in registration['directions'][d]['frames'] if '_walk_' in r['name']]
        walk_templates=[r for r in template['directions'][d]['frames'] if '_walk_' in r['key']]
        records=[]; templates=[]
        for i in range(4):
            src=APPROVED/sd/'frames'/f'{sd}_idle_breathe_{i:02}.png'; name=f'{d}_idle_{i:02}'
            im=Image.open(src); assert im.mode=='RGBA' and im.size==(128,128)
            shutil.copy2(src,final/f'{name}.png')
            records.append({'name':name,'source':str(src.relative_to(ROOT)).replace('\\','/'),
                'source_sha256':sha(src),'source_frame':i,'output_sha256':sha(final/f'{name}.png'),
                'source_to_output_scale':1.0,'offset':[0,0],'source_root':ANCHOR,'output_anchor':ANCHOR,
                'operation':'byte-identical approved breathing frame; right canonical used for side'})
            templates.append({'key':name,'file':f'../final_sprite/{name}.png','sha256':sha(final/f'{name}.png'),
                'anchor':ANCHOR,'phase':i/4,'phase_semantics':template['idle_phase_semantics'][i]})
        registration['directions'][d]['frames']=records+walks
        template['directions'][d]['frames']=templates+walk_templates
        for action,count in [('idle',4),('walk',8)]:
            manifest['frames'] += [{'name':f'{d}_{action}_{i:02}','file':f'../final_sprite/{d}_{action}_{i:02}.png'} for i in range(count)]
        manifest['clips'][f'{d}_idle']={'frames':[f'{d}_idle_{i:02}' for i in range(4)],
            'ticks':45,'loop_policy':'cycle','role':'player','entry_frame':0}
    runtime=read(HERO/'animation/runtime.json'); runtime['template_version']=VERSION
    runtime['idle_action']='idle_breathe'; runtime['idle_cycle_ms']=3000
    for p,v in [('animation/clips.json',manifest),('animation/registration.json',registration),
                ('animation/runtime.json',runtime),('modular_plan/template.json',template)]: save(staged/p,v)
    review=Image.new('RGB',(12*192,3*208),'#e3e9ce'); draw=ImageDraw.Draw(review)
    for row,d in enumerate(['front','back','side']):
        names=[f'{d}_idle_{i:02}' for i in range(4)]+[f'{d}_walk_{i:02}' for i in range(8)]
        for col,name in enumerate(names):
            im=Image.open(final/f'{name}.png').convert('RGBA').resize((192,192),Image.Resampling.LANCZOS)
            review.paste(im,(col*192,row*208+16),im); draw.text((col*192+6,row*208+3),name,fill='#374533')
    (staged/'reference').mkdir(parents=True); review.save(staged/'reference/frame-review.png')
    overlay=review.copy(); draw=ImageDraw.Draw(overlay)
    for row in range(3):
        for col in range(12):
            x,y=col*192+96,row*208+184
            draw.line((x-18,y,x+18,y),fill='#c96545'); draw.line((x,y-160,x,y+8),fill='#d6ab44')
    overlay.save(staged/'modular_plan/pose-templates.png')
    # Six seconds: two breathing cycles and nine walk cycles, from complete PNGs.
    preview=[]
    for tick in range(0,360,5):
        im=Image.new('RGB',(4*192,2*208),'#e3e9ce'); labels=ImageDraw.Draw(im)
        for col,d in enumerate(['front','back','side','side']):
            for row,action,index in [(0,'idle',tick//45%4),(1,'walk',tick//5%8)]:
                f=Image.open(final/f'{d}_{action}_{index:02}.png').convert('RGBA')
                if col==3: f=f.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                f=f.resize((192,192),Image.Resampling.LANCZOS); im.paste(f,(col*192,row*208+16),f)
                labels.text((col*192+6,row*208+3),['front','back','right','left'][col]+' '+action,fill='#374533')
        preview.append(im)
    durations=[round((i+1)*1000/12)-round(i*1000/12) for i in range(72)]
    preview[0].save(staged/'reference/animation-preview.webp',save_all=True,append_images=preview[1:],duration=durations,loop=0,lossless=True)
    save(WORK/'acceptance.json',{'userApproval':'可以 这一版可以接入游戏了','date':'2026-10-15',
        'approved':'art/hero_idle_breathe_preview_v02','newImageCalls':0,'newVideoCalls':0,'art_source':'existing',
        'sourceProvenance':'../hero_idle_breathe_preview_v02/provenance.json','runtimeTemplate':VERSION,
        'scope':'Replace idle holds with approved 4-frame 3-second breathing; walk pixels/speed/stride preserved.'})
    print(json.dumps({'staged':str(staged),'idle_frames':12,'preserved_walk_frames':24,'template':VERSION}))

def publish():
    staged=WORK/'staged'; engine=WORK/'engine/godot'
    assert (engine/'hero.tres').exists(), 'Export through generate2dsprite before publishing.'
    for folder in ['final_sprite','animation','modular_plan','reference']:
        for file in (staged/folder).iterdir(): shutil.copy2(file,HERO/folder/file.name)
    for file in engine.iterdir():
        if file.is_file(): shutil.copy2(file,HERO/'animation'/file.name)
    shutil.copy2(ROOT/'CHARACTER_MODULAR_RULES.md',HERO/'modular_plan/CHARACTER_MODULAR_RULES.md')
    print(json.dumps({'published':str(HERO),'whole_frames':36,'template':VERSION}))

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('step',choices=['stage','publish']); args=p.parse_args()
    {'stage':stage,'publish':publish}[args.step]()
