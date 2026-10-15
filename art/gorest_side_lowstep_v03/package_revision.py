"""Deterministic complete-frame cleanup, packing and comparison; no limb drawing."""
from pathlib import Path
import copy
import hashlib
import importlib.util
import json
import shutil
import zipfile

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
OLD = ROOT.parent / 'gorest_directions_v02'
FRONT = ROOT.parent / 'gorest_walk_trial_v01'
spec = importlib.util.spec_from_file_location('previous_packaging', OLD / 'package_directions.py')
packaging = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packaging)
packaging.ROOT = ROOT
save_json = packaging.save_json
CHANGED = [2, 6]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    raw_path = ROOT / 'take1/generated.png'
    raw = Image.open(raw_path).convert('RGBA')
    w, h = raw.size
    assert w == h * 2, 'The paired complete-frame template must remain 2:1.'
    scale = 256 / h
    source_geometry = []
    for j in range(2):
        cell_alpha = np.array(raw.crop((j*h, 0, (j+1)*h, h)).getchannel('A'))
        box = Image.fromarray((cell_alpha>8).astype('uint8')*255).getbbox()
        assert box and min(box[0],box[1],h-box[2],h-box[3])>2
        source_geometry.append({'sourcePanel':j,'foregroundBbox':list(box),
                                'minimumMargin':min(box[0],box[1],h-box[2],h-box[3])})
    old = [Image.open(OLD / 'right/frames' / f'right_walk_{i:02d}.png').convert('RGBA') for i in range(8)]
    right = [frame.copy() for frame in old]
    cleanup = []
    for j, i in enumerate(CHANGED):
        cell = raw.crop((j*h, 0, (j+1)*h, h))
        pixels = np.array(cell)
        removed_source = int(((pixels[:, :, 3] > 0) & (pixels[:, :, 3] <= 8)).sum())
        pixels[pixels[:, :, 3] <= 8] = 0
        cell = Image.fromarray(pixels).resize((256, 256), Image.Resampling.LANCZOS)
        pixels = np.array(cell)
        removed_final = int(((pixels[:, :, 3] > 0) & (pixels[:, :, 3] <= 8)).sum())
        pixels[pixels[:, :, 3] <= 8] = 0
        right[i] = Image.fromarray(pixels)
        cleanup.append({'frameOneBased': i+1, 'sourceFaintAlphaPixelsRemoved': removed_source,
                        'finalFaintAlphaPixelsRemoved': removed_final})
    all_frames = {'right': right, 'left': [f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in right]}
    source_cells = [[0, 0, h, h], [h, 0, w, h]]
    edit = {'route': 'host image_gen image editing, adopted via generate2dmedia cli_media.py',
            'underlyingModel': 'not exposed', 'sourceImage': 'take1/generated.png',
            'sourceSha256': sha(raw_path), 'sourceSize': [w,h], 'sourceCells': source_cells,
            'template': 'references/side_frames_03_07_edit_target.png',
            'prompt': 'edit_prompt.txt', 'changedFramesOneBased': [3,7],
            'globalUniformScale': scale, 'translation': [0,0],
            'registration': 'retain whole-frame positions from the approved paired canvas template',
            'alphaCleanup': cleanup, 'cutoff': 8,
            'sourceGeometry':source_geometry,
            'gridPolicy':'known 2:1 paired edit-template cells verified against actual foreground clusters and safe boundaries',
            'creativeLocalPixelEdits': False, 'perFrameBboxScaling': False}
    reports = {}
    for direction in ['right','left']:
        meta = json.loads((OLD / direction / 'normalization.json').read_text(encoding='utf-8'))
        meta['previousVersion'] = str(OLD / direction)
        meta['targetedEdit'] = edit
        meta['sourceTake'] = 'v02_unchanged+v03_lowstep_edit'
        meta['sourceTakes'] = list(meta['sourceTakes']) + ['v03_lowstep_edit']
        meta['sourceGlobalScales']['v03_lowstep_edit'] = scale
        meta['sourceSheetSizes']['v03_lowstep_edit'] = [w,h]
        for j,i in enumerate(CHANGED):
            meta['sourceCells'][i] = source_cells[j]
        meta['sourceFrameRefs'] = [({'take':'v03_lowstep_edit','frame':CHANGED.index(i)} if i in CHANGED else
                                   {'take':'v02_unchanged','frame':i}) for i in range(8)]
        meta['sourceFrameOrder'] = list(range(8))
        meta['frameBboxes'] = []
        for f in all_frames[direction]:
            x0,y0,x1,y1 = f.getchannel('A').getbbox()
            meta['frameBboxes'].append([x0,y0,x1-x0,y1-y0])
        meta['normalization'] = 'retain six original frames; complete edited frames 3 and 7 share one uniform canvas scale; left mirrors complete right frames'
        meta['rootAnchorPolicy'] = 'retain original normalized canvas registration; edited upper-body placement follows the paired reference template'
        meta['phaseOrderPolicy'] = 'Preserve original eight-frame chronological order; replace only one-based frames 3 and 7.'
        meta['frames'] = [s.replace(f'windrest_hero_{direction}_walk_v02.png',
                                  f'windrest_hero_{direction}_walk_lowstep_v03.png') for s in meta['frames']]
        if direction == 'left':
            meta['derivation'] = {'operation':'mirror_each_complete_right_frame_horizontally',
                                  'source':'../right/right_walk_sheet.png','frameOrderReversed':False,
                                  'sourceSha256':sha(ROOT/'right/right_walk_sheet.png')}
        reports[direction] = packaging.package(direction, all_frames[direction], meta)
        # Preserve byte identity for all six untouched PNGs in each direction.
        for i in range(8):
            if i not in CHANGED:
                file = f'{direction}_walk_{i:02d}.png'
                shutil.copy2(OLD / direction / 'frames' / file, ROOT / direction / 'frames' / file)

    for direction, source in [('front',FRONT),('back',OLD/'back')]:
        target = ROOT / direction
        (target/'frames').mkdir(parents=True,exist_ok=True)
        for i in range(8):
            file=f'{direction}_walk_{i:02d}.png'
            shutil.copy2(source/'frames'/file,target/'frames'/file)
        for file in [f'{direction}_walk_sheet.png',f'{direction}_walk_preview.gif',
                     f'{direction}_walk_preview.webp','normalization.json','qa.json']:
            shutil.copy2(source/file,target/file)
        all_frames[direction]=[Image.open(target/'frames'/f'{direction}_walk_{i:02d}.png').convert('RGBA') for i in range(8)]

    compare=[]
    overview=[]
    for i in range(8):
        panel=Image.new('RGB',(512,288),'#f6efdf')
        d=ImageDraw.Draw(panel)
        d.rectangle((256,0,511,287),fill='#e7eddf')
        for j,(label,frame) in enumerate([('原版',old[i]),('降低抬腿',right[i])]):
            d.text((j*256+12,5),f'{label} · 第 {i+1} 帧',font=packaging.FONT,fill='#405346')
            panel.paste(frame,(j*256,28),frame)
        compare.append(panel)
        panel=Image.new('RGB',(512,568),'#f6efdf')
        d=ImageDraw.Draw(panel)
        for j,(direction,label) in enumerate([('front','正面'),('back','背面'),('left','左侧 · 低抬腿'),('right','右侧 · 低抬腿')]):
            x,y=j%2*256,j//2*284
            if j in [1,2]:
                d.rectangle((x,y,x+255,y+283),fill='#e7eddf')
            d.text((x+12,y+6),label,font=packaging.FONT,fill='#405346')
            f=all_frames[direction][i]
            panel.paste(f,(x,y+28),f)
        overview.append(panel)
    packaging.save_animation(compare,ROOT/'side_before_after')
    packaging.save_animation(overview,ROOT/'four_directions_preview')
    compare[2].save(ROOT/'side_before_after_frame03.png')
    overview[0].save(ROOT/'four_directions_still.png')
    contact=Image.new('RGB',(1024,288),'#f6efdf')
    d=ImageDraw.Draw(contact)
    for j,i in enumerate(CHANGED):
        for n,f in enumerate([old[i],right[i]]):
            x=(j*2+n)*256
            d.text((x+10,5),f'第 {i+1} 帧 · '+('原版' if n==0 else '降低抬腿'),font=packaging.FONT,fill='#405346')
            contact.paste(f,(x,28),f)
    contact.save(ROOT/'frames_03_07_comparison.png')
    atlas=Image.new('RGBA',(1024,2048))
    for j,direction in enumerate(['front','back','left','right']):
        atlas.paste(packaging.pack(all_frames[direction]),(0,j*512))
    atlas.save(ROOT/'four_directions_sheet.png')

    verification={'changedFramesOneBased':[3,7], 'unchangedFramesByteIdentical':{},
                  'leftExactlyMirrorsRight':True,'sheetCellsMatchFrames':True,
                  'gifFrameCount':8,'cycleMs':1000,'gameIntegrated':False}
    for direction in ['front','back','left','right']:
        source=FRONT if direction=='front' else OLD/direction
        expected=list(range(8)) if direction in ['front','back'] else [i for i in range(8) if i not in CHANGED]
        verification['unchangedFramesByteIdentical'][direction]=all(
            sha(source/'frames'/f'{direction}_walk_{i:02d}.png')==sha(ROOT/direction/'frames'/f'{direction}_walk_{i:02d}.png') for i in expected)
        sheet=Image.open(ROOT/direction/f'{direction}_walk_sheet.png').convert('RGBA')
        verification['sheetCellsMatchFrames'] &= all(np.array_equal(np.asarray(f),np.asarray(all_frames[direction][i])) for i,f in enumerate(packaging.split(sheet)))
    verification['leftExactlyMirrorsRight']=all(np.array_equal(np.asarray(r.transpose(Image.Transpose.FLIP_LEFT_RIGHT)),np.asarray(l)) for r,l in zip(right,all_frames['left']))
    assert all(verification['unchangedFramesByteIdentical'].values())
    assert verification['leftExactlyMirrorsRight'] and verification['sheetCellsMatchFrames']
    for name in ['side_before_after.gif','four_directions_preview.gif']:
        gif=Image.open(ROOT/name)
        durations=[]
        for i in range(gif.n_frames):
            gif.seek(i)
            durations.append(gif.info['duration'])
        assert len(durations)==8 and sum(durations)==1000
    save_json(ROOT/'edit_provenance.json',edit)
    save_json(ROOT/'qa_summary.json',reports)
    save_json(ROOT/'export_verification.json',verification)
    manifest={'status':'preview_not_game_integrated','fps':8,'frameSize':[256,256],
              'frameCountPerDirection':8,'directions':['front','back','left','right'],
              'changedFramesOneBased':[3,7],'unchanged':['front','back','other six side frames'],
              'sideCanonical':'right','leftDerivation':'whole-frame horizontal mirror without frame-order reversal',
              'source':'edit_provenance.json','atlasSize':[1024,2048],
              'atlasDirectionRows':{'front':[0,1],'back':[2,3],'left':[4,5],'right':[6,7]}}
    save_json(ROOT/'export_manifest.json',manifest)
    with zipfile.ZipFile(ROOT/'hero_four_directions_lowstep_v03.zip','w',zipfile.ZIP_DEFLATED) as z:
        for direction in manifest['directions']:
            for file in sorted((ROOT/direction/'frames').glob('*.png')):
                z.write(file,file.relative_to(ROOT))
            for file in [ROOT/direction/f'{direction}_walk_sheet.png',ROOT/direction/f'{direction}_walk_preview.gif']:
                z.write(file,file.relative_to(ROOT))
        for name in ['export_manifest.json','edit_provenance.json','export_verification.json','edit_prompt.txt',
                     'four_directions_sheet.png','four_directions_preview.gif','side_before_after.gif','frames_03_07_comparison.png']:
            z.write(ROOT/name,name)
    print(json.dumps({'verification':verification,'rightHeights':reports['right']['fullBodyHeights'],
                      'rightMargin':reports['right']['minimumAlphaMargin'],'editScale':scale},ensure_ascii=False))


if __name__=='__main__':
    main()
