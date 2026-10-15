"""Import approved whole-character frames without redrawing or fitting individual poses."""
from pathlib import Path
import argparse, hashlib, json, shutil
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
HERO=ROOT/'assets/hero'
WORK=ROOT/'art/hero_gorest_runtime_v02'
APPROVED=ROOT/'art/gorest_side_lowstep_v03'
ANCHOR=[64,112]
SCALE=140/256
OFFSET=[-6,7]
STRIDE=200/3
VERSION='windrest-character-template-2'

def save(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def stage():
    backup=WORK/'previous_runtime'
    if not backup.exists():
        shutil.copytree(HERO,backup)
        shutil.copy2(ROOT/'scripts/player.gd',WORK/'previous_player.gd')
        shutil.copy2(ROOT/'CHARACTER_MODULAR_RULES.md',WORK/'previous_character_rules.md')
    staged=WORK/'staged'
    manifest={'schema':'generate2dsprite.animation_clips.v2','name':'windrest-hero',
        'frames':[],'anchor_px':ANCHOR,'sampling':'linear','pixel_art':False,
        'art_source':'existing','body_height_px':89,'placeholder':False,'clips':{}}
    registration={'schema':'windrest.complete_registration.v2','template_version':VERSION,
        'source':'user-approved Gorest complete-frame preview; no new image generation',
        'canvas':[128,128],'anchor':ANCHOR,'source_canvas':[256,256],
        'source_root':[128,192],'walk_scale':SCALE,'walk_offset':OFFSET,
        'scale_policy':'one common whole-canvas uniform scale and translation for every walk frame in all directions',
        'sampling':'premultiplied-alpha LANCZOS','directions':{}}
    template={'schema':'windrest.character_template.v1','version':VERSION,'canvas':[128,128],
        'anchor':ANCHOR,'directions':{},'modules':['base_body','hair','top','bottom','shoes','accessory'],
        'rendering':'complete character frames; future modules must be redrawn per frame',
        'base_body_status':'hidden anatomy remains a future redraw prerequisite',
        'timing':{'tick_hz':60,'idle_ticks_per_frame':60,'walk_ticks_per_frame':5,
            'walk_cycle_frames':8,'speed_ref':100,'stride_world_units':STRIDE},
        'phase_semantics':['contact_a','down_a','passing_a','up_a','contact_b','down_b','passing_b','up_b'],
        'side_mirror':{'left':'full-frame flip_h','pivot_x':64,'asymmetry_requires_new_template':True}}
    final=staged/'final_sprite'
    final.mkdir(parents=True,exist_ok=True)
    for direction,source_direction in [('front','front'),('back','back'),('side','right')]:
        records=[]
        idle=f'{direction}_idle_00'
        shutil.copy2(backup/'final_sprite'/f'{idle}.png',final/f'{idle}.png')
        records.append({'name':idle,'source':str((backup/'final_sprite'/f'{idle}.png').relative_to(ROOT)),
            'source_sha256':sha(backup/'final_sprite'/f'{idle}.png'),
            'operation':'preserve existing neutral idle byte for byte','source_to_output_scale':1.0})
        for i in range(8):
            source=APPROVED/source_direction/'frames'/f'{source_direction}_walk_{i:02d}.png'
            im=Image.open(source).convert('RGBA')
            assert im.size==(256,256)
            # All 24 complete source canvases use this SAME mapping; no per-frame fitting.
            scaled=im.convert('RGBa').resize((140,140),Image.Resampling.LANCZOS).convert('RGBA')
            frame=Image.new('RGBA',(128,128))
            frame.alpha_composite(scaled,tuple(OFFSET))
            assert np.count_nonzero(np.asarray(scaled)[:,:,3]>16)==np.count_nonzero(np.asarray(frame)[:,:,3]>16), 'visible art clipped'
            name=f'{direction}_walk_{i:02d}'
            frame.save(final/f'{name}.png')
            records.append({'name':name,'source':str(source.relative_to(ROOT)),
                'source_sha256':sha(source),'source_frame':i,'source_to_output_scale':SCALE,
                'source_root':[128,192],'output_anchor':ANCHOR,'offset':OFFSET,
                'output_sha256':sha(final/f'{name}.png')})
        registration['directions'][direction]={'frames':records}
        template_records=[]
        for i,record in enumerate(records):
            name=record['name']
            manifest['frames'].append({'name':name,'file':f'../final_sprite/{name}.png'})
            template_records.append({'key':name,'file':f'../final_sprite/{name}.png',
                'sha256':sha(final/f'{name}.png'),'anchor':ANCHOR,'phase':None if i==0 else (i-1)/8})
        for action,count,ticks in [('idle',1,60),('walk',8,5)]:
            clip={'frames':[f'{direction}_{action}_{i:02d}' for i in range(count)],
                'ticks':ticks,'loop_policy':'cycle','role':'player','entry_frame':0}
            if action=='walk': clip.update({'stride_world_units':STRIDE,'speed_ref':100})
            manifest['clips'][f'{direction}_{action}']=clip
        template['directions'][direction]={'neutral':f'../final_sprite/{idle}.png','frames':template_records,
            'registration':'../animation/registration.json','walk_source_order':list(range(8))}
    save(staged/'animation/clips.json',manifest)
    save(staged/'animation/registration.json',registration)
    save(staged/'modular_plan/template.json',template)
    save(staged/'animation/runtime.json',{'schema':'windrest.complete_actor.v1','canvas':[128,128],
        'anchor':ANCHOR,'stride_world_units':STRIDE,'template_version':VERSION,
        'direction_map':{'down':'front','up':'back','right':'side','left':'side + flip_h'},
        'walk_clock':'actual post-collision distance','idle_clock':'seconds','runtime_layers':1})
    review=Image.new('RGB',(9*192,3*208),'#e3e9ce')
    draw=ImageDraw.Draw(review)
    for row,direction in enumerate(['front','back','side']):
        for col in range(9):
            name=f'{direction}_idle_00' if col==0 else f'{direction}_walk_{col-1:02d}'
            im=Image.open(final/f'{name}.png').convert('RGBA').resize((192,192),Image.Resampling.LANCZOS)
            review.paste(im,(col*192,row*208+16),im)
            draw.text((col*192+8,row*208+3),name,fill='#374533')
    (staged/'reference').mkdir(parents=True,exist_ok=True)
    review.save(staged/'reference/frame-review.png')
    overlay=review.copy(); draw=ImageDraw.Draw(overlay)
    for row in range(3):
        for col in range(9):
            x,y=col*192+96,row*208+184
            draw.line((x-18,y,x+18,y),fill='#c96545')
            draw.line((x,y-160,x,y+8),fill='#d6ab44')
    overlay.save(staged/'modular_plan/pose-templates.png')
    previews=[]
    for i in range(8):
        preview=Image.new('RGBA',(4*192,2*208),'#e3e9ce')
        labels=ImageDraw.Draw(preview)
        for col,direction in enumerate(['front','back','side','side']):
            for row,action in enumerate(['idle','walk']):
                name=f'{direction}_{action}_{0 if action=="idle" else i:02d}'
                im=Image.open(final/f'{name}.png').convert('RGBA')
                if col==3: im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                im=im.resize((192,192),Image.Resampling.LANCZOS)
                preview.alpha_composite(im,(col*192,row*208+16))
                labels.text((col*192+8,row*208+3),['front','back','right','left'][col]+' '+action,fill='#374533')
        previews.append(preview)
    previews[0].save(staged/'reference/animation-preview.webp',save_all=True,
        append_images=previews[1:],duration=[83,84,83,83,84,83,83,84],loop=0,lossless=True)
    print(json.dumps({'staged':str(staged),'walk_frames':24,'preserved_idle_frames':3,
        'uniform_scale':SCALE,'offset':OFFSET,'stride_world_units':STRIDE}))

def publish():
    staged=WORK/'staged'; engine=WORK/'engine/godot'
    assert (engine/'hero.tres').exists(), 'Export through the skill before publishing.'
    for folder in ['final_sprite','animation','modular_plan','reference']:
        for file in (staged/folder).iterdir(): shutil.copy2(file,HERO/folder/file.name)
    for file in engine.iterdir():
        if file.is_file(): shutil.copy2(file,HERO/'animation'/file.name)
    shutil.copy2(ROOT/'CHARACTER_MODULAR_RULES.md',HERO/'modular_plan/CHARACTER_MODULAR_RULES.md')
    print(json.dumps({'published':str(HERO),'template_version':VERSION,'whole_frames':27}))

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('step',choices=['stage','publish'])
    args=parser.parse_args(); {'stage':stage,'publish':publish}[args.step]()
