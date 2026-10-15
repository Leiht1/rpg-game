"""Register whole generated figures and package accepted skill-processed frames.

No cutout limbs, rig, deformation, or per-frame scaling. Source transforms and
the approved pose order are explicit in registration.json and retained.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'art/hero_rebuild_v01'
HERO=ROOT/'assets/hero'
ANCHOR=(64,112)

def write_json(path, data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def stage(config):
    for direction, spec in config['directions'].items():
        if args.direction and direction!=args.direction: continue
        if len({f['scale'] for f in spec['source_frames'][1:] if f.get('source_pose')!='edited_passing'})>1:
            raise ValueError('Walk sheet frames must use one source scale')
        sheet=Image.new('RGBA',(640*5,640))
        transforms=[]
        for i,frame in enumerate(spec['source_frames']):
            source=ROOT/frame['source']
            im=Image.open(source).convert('RGBA').crop(frame['rect'])
            scale=frame['scale']
            # One recorded scale for the entire neutral reference, one for each
            # generated action sheet. Every frame of a walk uses the SAME scale.
            im=im.convert('RGBa').resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS).convert('RGBA')
            at=(round(320-frame['root'][0]*scale),round(560-frame['root'][1]*scale))
            if at[0]<0 or at[1]<0 or at[0]+im.width>640 or at[1]+im.height>640:
                # Transparent source padding may leave the target, visible paint may not.
                box=im.getchannel('A').point(lambda x:255 if x>32 else 0).getbbox()
                if box and (at[0]+box[0]<0 or at[1]+box[1]<0 or at[0]+box[2]>640 or at[1]+box[3]>640):
                    raise ValueError(f'{direction}/{i}: visible paint would be clipped')
            cell=Image.new('RGBA',(640,640))
            cell.alpha_composite(im,at)
            sheet.alpha_composite(cell,(640*i,0))
            transforms.append({**frame,'source_sha256':digest(source),'staged_offset':at,'staged_root':[320,560]})
        path=WORK/'registered_source'/f'{direction}.png'
        path.parent.mkdir(parents=True,exist_ok=True)
        sheet.save(path)
        write_json(path.with_suffix('.json'),{'direction':direction,'canvas':[640,640],'root':[320,560],
                   'operation':'whole-figure uniform resample + rigid registration only','frames':transforms})

def publish(config):
    manifest={'schema':'generate2dsprite.animation_clips.v2','name':'windrest-hero','frames':[],
              'anchor_px':list(ANCHOR),'sampling':'linear','pixel_art':False,'art_source':'host_image',
              'body_height_px':88,'placeholder':False,'clips':{}}
    template={'schema':'windrest.character_template.v1','version':'windrest-character-template-1',
              'canvas':[128,128],'anchor':list(ANCHOR),'directions':{},'modules':['base_body','hair','top','bottom','shoes','accessory'],
              'rendering':'complete character frames; future modules must be redrawn per frame',
              'base_body_status':'proportions and poses fixed by complete-frame templates; hidden anatomy is a future redraw prerequisite',
              'timing':{'tick_hz':60,'idle_ticks_per_frame':60,'walk_ticks_per_frame':8,
                        'walk_cycle_frames':4,'speed_ref':80,'stride_world_units':config['stride_world_units']},
              'phase_semantics':['right_contact','right_support_left_passing','left_contact','left_support_right_passing'],
              'side_mirror':{'left':'full-frame flip_h','pivot_x':64,'asymmetry_requires_new_template':True}}
    review=Image.new('RGB',(5*256,3*280),(227,233,206))
    draw=ImageDraw.Draw(review)
    gifframes=[]
    per_direction={}
    for row,direction in enumerate(['front','back','side']):
        processed=WORK/'processed'/config['directions'][direction].get('processed_folder',direction)
        meta=json.loads((processed/'pipeline-meta.json').read_text(encoding='utf-8'))
        origin=meta['output_origin']
        shift=(round(64-origin[0]),round(112-origin[1]))
        # The skill uses one target for this sheet. This ONE whole-sheet offset
        # maps it to the project's unchanged world root. No individual feet fitting.
        frames=[]
        # The pipeline's frame manifest is authoritative; names are never guessed.
        records=meta['frames']
        for i,record in enumerate(records):
            input_file=processed/(meta['frame_labels'][i]+'.png')
            im=Image.open(input_file).convert('RGBA')
            out=Image.new('RGBA',(128,128)); out.alpha_composite(im,shift)
            a=np.asarray(out)[:,:,3]
            a_before=np.asarray(im)[:,:,3]
            if np.count_nonzero(a>32)!=np.count_nonzero(a_before>32):
                raise ValueError(f'{direction}/{i}: global root mapping clipped paint')
            name=f'{direction}_idle_00' if i==0 else f'{direction}_walk_{i-1:02}'
            path=HERO/'final_sprite'/f'{name}.png'
            out.save(path)
            frames.append(out)
            manifest['frames'].append({'name':name,'file':f'../final_sprite/{name}.png'})
            view=Image.new('RGBA',(128,128),(227,233,206));view.alpha_composite(out)
            review.paste(view.convert('RGB').resize((256,256),Image.Resampling.NEAREST),(i*256,row*280+24))
            draw.text((i*256+8,row*280+7),name,fill='#374533')
        for action,indices,ticks in [('idle',[0],60),('walk',[1,2,3,4],8)]:
            name=f'{direction}_{action}'
            clip={'frames':[f'{direction}_{action}_{i:02}' for i in range(len(indices))],
                  'ticks':ticks,'loop_policy':'cycle','role':'player','entry_frame':0}
            if action=='walk': clip.update({'stride_world_units':config['stride_world_units'],
                'speed_ref':80,'events':[{'at':0,'name':'step_r'},{'at':2,'name':'step_l'}]})
            manifest['clips'][name]=clip
        template['directions'][direction]={'neutral':f'../final_sprite/{direction}_idle_00.png',
            'frames':[{'key':f'{direction}_{"idle_00" if i==0 else "walk_%02d"%(i-1)}',
                'file':f'../final_sprite/{direction}_{"idle_00" if i==0 else "walk_%02d"%(i-1)}.png',
                'sha256':digest(HERO/'final_sprite'/f'{direction}_{"idle_00" if i==0 else "walk_%02d"%(i-1)}.png'),
                'anchor':list(ANCHOR),'phase':None if i==0 else (i-1)/4} for i in range(5)],
            'registration':f'../../../art/hero_rebuild_v01/registered_source/{direction}.json',
            'walk_source_order':config['directions'][direction]['walk_source_order']}
        per_direction[direction]=frames
    write_json(HERO/'animation/clips.json',manifest)
    write_json(HERO/'modular_plan/template.json',template)
    write_json(HERO/'animation/runtime.json',{'schema':'windrest.complete_actor.v1','canvas':[128,128],
        'anchor':list(ANCHOR),'stride_world_units':config['stride_world_units'],'template_version':template['version'],
        'direction_map':{'down':'front','up':'back','right':'side','left':'side + flip_h'},
        'walk_clock':'actual post-collision distance','idle_clock':'seconds','runtime_layers':1})
    review.save(HERO/'reference/frame-review.png')
    # Technical overlays retain final frame pixels; these are pose templates, not generated clothing.
    overlay=review.copy();od=ImageDraw.Draw(overlay)
    for row in range(3):
        for col in range(5):
            x,y=col*256+128,row*280+24+224
            od.line((x-24,y,x+24,y),fill='#c96545',width=1)
            od.line((x,y-220,x,y+12),fill='#d6ab44',width=1)
            od.ellipse((x-3,y-3,x+3,y+3),outline='#c96545',width=1)
    overlay.save(HERO/'modular_plan/pose-templates.png')
    for i in range(4):
        grid=Image.new('RGBA',(4*192,2*192),(210,223,183,255))
        for col,direction in enumerate(['front','back','side','left']):
            key='side' if direction=='left' else direction
            for row,idx in [(0,0),(1,i+1)]:
                im=per_direction[key][idx]
                if direction=='left': im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                grid.alpha_composite(im.resize((192,192),Image.Resampling.LANCZOS),(col*192,row*192))
        gifframes.append(grid.convert('RGB'))
    gifframes[0].save(HERO/'reference/animation-preview.webp',save_all=True,append_images=gifframes[1:],duration=[133,134,133,134],loop=0,lossless=True)
    shutil.copy2(ROOT/'CHARACTER_MODULAR_RULES.md',HERO/'modular_plan/CHARACTER_MODULAR_RULES.md')

parser=argparse.ArgumentParser()
parser.add_argument('step',choices=['stage','publish'])
parser.add_argument('--direction',choices=['front','back','side'])
args=parser.parse_args()
config=json.loads((WORK/'registration.json').read_text(encoding='utf-8'))
{'stage':stage,'publish':publish}[args.step](config)
