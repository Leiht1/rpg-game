"""Publish the approved v04/v05/v06 whole-frame set without resampling."""
from pathlib import Path
import argparse,copy,hashlib,json,shutil
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1];HERO=ROOT/'assets/hero'
WORK=ROOT/'art/hero_approved_runtime_v04'
VERSION='windrest-character-template-4';ANCHOR=[64,112];STRIDE=200/3
SOURCES={'idle':'hero_sequence_repair_preview_v05','walk':'hero_consistency_preview_v04'}
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def source(d,a,i):
    sd='right' if d=='side' else d
    revision='hero_side_spacing_preview_v06' if d=='side' and a=='walk' else SOURCES[a]
    return ROOT/f'art/{revision}/{sd}_{a}_preview/frames/{sd}_{a}_{i:02}.png'

def stage():
    assert not WORK.exists(),'Preserve the integration snapshot; do not restage.'
    WORK.mkdir(parents=True);shutil.copytree(HERO,WORK/'previous_runtime')
    for path in ['scripts/player.gd','tests/test_player.gd','tests/capture_character.gd','tools/verify_character.py',
                 'CHARACTER_MODULAR_RULES.md','README.md','reports/CHARACTER_VALIDATION.md',
                 'reports/character-art-tests.json','reports/player-tests.json']:
        p=ROOT/path
        if p.exists():shutil.copy2(p,WORK/('previous_'+p.name))
    save(WORK/'unchanged_game_baseline.json',{str(p.relative_to(ROOT)).replace('\\','/'):sha(p)
        for folder,pattern in [('scripts','*.gd'),('scenes','*.tscn')] for p in (ROOT/folder).glob(pattern)
        if p.name!='player.gd'}|{'project.godot':sha(ROOT/'project.godot')})
    staged=WORK/'staged';final=staged/'final_sprite';final.mkdir(parents=True)
    manifest={'schema':'generate2dsprite.animation_clips.v2','name':'windrest-hero','frames':[],
        'anchor_px':ANCHOR,'sampling':'linear','pixel_art':False,'art_source':'existing',
        'body_height_px':92,'placeholder':False,'clips':{}}
    registration={'schema':'windrest.complete_registration.v3','template_version':VERSION,
        'source':'User-approved whole-frame v04/v05/v06 set on 2026-10-15; no new art',
        'canvas':[128,128],'anchor':ANCHOR,'source_canvas':[128,128],'source_root':ANCHOR,
        'scale_policy':'Copy every approved 128x128 RGBA PNG byte for byte, scale 1, offset [0,0].',
        'directions':{},'source_provenance':[f'art/{d}/provenance.json' for d in
            ['hero_consistency_preview_v04','hero_sequence_repair_preview_v05','hero_side_spacing_preview_v06']]}
    template=read(HERO/'modular_plan/template.json');template['version']=VERSION
    template['timing'].update({'tick_hz':60,'idle_ticks_per_frame':27,'idle_cycle_frames':4,'idle_cycle_ms':1800,
        'walk_ticks_per_frame':5,'walk_cycle_frames':8,'speed_ref':100,'movement_speed':115,
        'stride_world_units':STRIDE,'walk_fps_at_movement_speed':13.8})
    template['idle_phase_semantics']=['neutral','inhale','release','exhale']
    for d in ['front','back','side']:
        records=[];templates=[]
        for action,count,ticks in [('idle',4,27),('walk',8,5)]:
            for i in range(count):
                src=source(d,action,i);im=Image.open(src)
                assert im.mode=='RGBA' and im.size==(128,128),(src,im.mode,im.size)
                name=f'{d}_{action}_{i:02}';dst=final/f'{name}.png';shutil.copy2(src,dst)
                records.append({'name':name,'source':str(src.relative_to(ROOT)).replace('\\','/'),
                    'source_sha256':sha(src),'source_frame':i,'output_sha256':sha(dst),
                    'source_to_output_scale':1.0,'offset':[0,0],'source_root':ANCHOR,'output_anchor':ANCHOR,
                    'operation':'Byte-identical approved complete PNG; right canonical maps to side.'})
                t={'key':name,'file':f'../final_sprite/{name}.png','sha256':sha(dst),'anchor':ANCHOR,'phase':i/count}
                if action=='idle':t['phase_semantics']=template['idle_phase_semantics'][i]
                templates.append(t);manifest['frames'].append({'name':name,'file':f'../final_sprite/{name}.png'})
            clip={'frames':[f'{d}_{action}_{i:02}' for i in range(count)],'ticks':ticks,
                'loop_policy':'cycle','role':'player','entry_frame':0}
            if action=='walk':clip.update({'speed_ref':100,'stride_world_units':STRIDE})
            manifest['clips'][f'{d}_{action}']=clip
        registration['directions'][d]={'frames':records}
        template['directions'][d].update({'frames':templates,'walk_source_order':list(range(8)),
            'idle_source_order':list(range(4)),'registration':'../animation/registration.json'})
    runtime=read(HERO/'animation/runtime.json');runtime.update({'template_version':VERSION,
        'idle_cycle_ms':1800,'walk_reference_speed':100,'movement_speed':115})
    for p,v in [('animation/clips.json',manifest),('animation/registration.json',registration),
                ('animation/runtime.json',runtime),('modular_plan/template.json',template)]:save(staged/p,v)
    review=Image.new('RGB',(12*128,3*148),'#e3e9ce');draw=ImageDraw.Draw(review)
    for row,d in enumerate(['front','back','side']):
        for col,name in enumerate([f'{d}_idle_{i:02}' for i in range(4)]+[f'{d}_walk_{i:02}' for i in range(8)]):
            f=Image.open(final/f'{name}.png');review.paste(f,(col*128,row*148+20),f)
            draw.text((col*128+3,row*148+4),name,fill='#374533')
    (staged/'reference').mkdir(parents=True);review.save(staged/'reference/frame-review.png')
    overlay=review.copy();draw=ImageDraw.Draw(overlay)
    for row in range(3):
        for col in range(12):
            x,y=col*128+64,row*148+132
            draw.line((x-15,y,x+15,y),fill='#c96545');draw.line((x,y-105,x,y+5),fill='#d6ab44')
    overlay.save(staged/'modular_plan/pose-templates.png')
    # Reference preview follows authored idle and distance-driven 115 px/s walk clocks.
    preview=[]
    for tick in range(0,216,3):
        im=Image.new('RGB',(512,296),'#e3e9ce');draw=ImageDraw.Draw(im)
        for col,d in enumerate(['front','back','side','side']):
            for row,action,index in [(0,'idle',tick//27%4),(1,'walk',int(tick/60*115/STRIDE*8)%8)]:
                f=Image.open(final/f'{d}_{action}_{index:02}.png')
                if col==3:f=f.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                im.paste(f,(col*128,row*148+20),f)
                draw.text((col*128+4,row*148+4),['front','back','right','left'][col]+' '+action,fill='#374533')
        preview.append(im)
    preview[0].save(staged/'reference/animation-preview.webp',save_all=True,append_images=preview[1:],duration=50,loop=0,lossless=True)
    save(WORK/'acceptance.json',{'date':'2026-10-15','userApproval':'好多了，把这一版都接入游戏吧，另外把游戏里的移动速度再调快一点',
        'sourceMap':{'front/back walk':'hero_consistency_preview_v04','side walk':'hero_side_spacing_preview_v06',
            'front/back/side idle':'hero_sequence_repair_preview_v05'},'template':VERSION,
        'art_source':'existing','newImageCalls':0,'newVideoCalls':0,'speedBefore':100,'speedAfter':115,
        'stride_world_units':STRIDE,'idle_cycle_ms':1800})
    print(json.dumps({'staged':str(staged),'frames':36,'clips':6,'template':VERSION,'movementSpeed':115}))

def publish():
    staged=WORK/'staged';engine=WORK/'engine/godot'
    assert (engine/'hero.tres').exists(),'Export through generate2dsprite first.'
    for folder in ['final_sprite','animation','modular_plan','reference']:
        for file in (staged/folder).iterdir():shutil.copy2(file,HERO/folder/file.name)
    for file in engine.iterdir():
        if file.is_file():shutil.copy2(file,HERO/'animation'/file.name)
    shutil.copy2(ROOT/'CHARACTER_MODULAR_RULES.md',HERO/'modular_plan/CHARACTER_MODULAR_RULES.md')
    print(json.dumps({'published':str(HERO),'frames':36,'template':VERSION}))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('step',choices=['stage','publish']);args=p.parse_args()
    {'stage':stage,'publish':publish}[args.step]()
