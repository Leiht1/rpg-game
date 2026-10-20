"""Adopt the user's confirmed workbench export, preserving every source byte."""
import hashlib
import json
import shutil
from pathlib import Path
import numpy as np
import soundfile as sf

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio/v3'
REPORT=ROOT/'reports/audio-selected-v6'
TARGETS={
 'sfx_step_grass':-34,'sfx_step_dirt':-34,'sfx_step_stone':-34,'sfx_step_wood':-34,
 'sfx_ui_click':-33,'sfx_ui_open':-32,'sfx_ui_close':-32,'sfx_ui_error':-31,
 'sfx_item_move':-34,'sfx_drop_land':-34,'sfx_tool_swing':-36,
 'sfx_chop_hit':-27,'sfx_mine_hit':-27,'sfx_dig_soil':-28,'sfx_demolish_hit':-28,
 'sfx_tree_fall':-27,'sfx_ore_break':-27,
 'sfx_equip':-31,'sfx_bag_organize':-31,'sfx_map_mark':-32,
 'sfx_pickup':-31,'sfx_gather_plant':-31,'sfx_eat':-32,
 'sfx_door_open':-29,'sfx_door_close':-29,'sfx_chest_open':-30,'sfx_chest_close':-30,
 'sfx_fridge_open':-30,'sfx_fridge_close':-30,'sfx_build_stone':-29,'sfx_build_wood':-29,
 'sfx_lantern_on':-33,'sfx_lantern_off':-33,
 'sfx_fishing_cast':-32,'sfx_fishing_bite':-29,'sfx_merchant_trade':-29,
 'sfx_chicken_idle':-32,'sfx_fire_ignite':-29,'sfx_thunder':-28,
 'amb_rain_light_loop':-39,'amb_rain_storm_loop':-34,
}

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,data):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def measure(p):
    x,rate=sf.read(p,always_2d=True,dtype='float64')
    energy=np.mean(x*x,axis=1); hop=max(1,int(rate*.02))
    chunks=[float(np.mean(energy[i:i+hop])) for i in range(0,len(x),hop)]
    # Ignore silence and very quiet tails without boosting narrow transients to full scale.
    gate=max(max(chunks)*.001,10**(-70/10))
    active=np.concatenate([energy[i:i+hop] for i in range(0,len(x),hop) if chunks[i//hop]>=gate])
    return {'seconds':len(x)/rate,'sample_rate':rate,'channels':x.shape[1],
            'active_rms_dbfs':float(10*np.log10(max(float(np.mean(active)),1e-12))),
            'peak_dbfs':float(20*np.log10(max(float(np.max(np.abs(x))),1e-12)))}

def main():
    manifest=json.loads((ROOT/'assets/audio/audio-workbench-manifest.json').read_text(encoding='utf-8-sig'))
    config=json.loads((ROOT/'data/audio.json').read_text(encoding='utf-8-sig'))
    before=json.loads(json.dumps(config)); provenance=[]; measurements=[]
    # Validate the complete batch before changing any runtime mapping.
    for key,event in manifest['events'].items():
        for f in event['files']:
            p=Path(f['output']).resolve()
            if not p.is_relative_to((ROOT/'assets/audio/selected').resolve()):raise ValueError(f'Outside selected root: {p}')
            if sha(p)!=f['sha256']:raise ValueError(f'Export hash mismatch: {p}')
            measure(p)
    for key,event in manifest['events'].items():
        paths=[]
        for f in event['files']:
            src=Path(f['output']); dest=OUT/'runtime'/src.name;dest.parent.mkdir(parents=True,exist_ok=True)
            if dest.exists() and sha(dest)!=f['sha256']:raise ValueError(f'Runtime collision: {dest}')
            shutil.copyfile(src,dest);path='res://'+dest.relative_to(ROOT).as_posix();paths.append(path)
            provenance.append({'event':key,'selected':src.relative_to(ROOT).as_posix(),'runtime':path,'sha256':sha(dest),'original_source':f['source'],'source_sha256':f.get('source_sha256'), 'processing':'byte-identical copy; playback gain only'})
        entry=config.setdefault(key,{'cooldown':.1})
        entry['files']=paths;entry['enabled']=True
        if key in ['sfx_chicken_idle','sfx_thunder']:entry['cooldown']=8.0 if key=='sfx_chicken_idle' else 2.0
    for key,entry in config.items():
        rows=[];target=TARGETS[key]
        for path in entry['files']:
            m=measure(ROOT/path.removeprefix('res://'))
            gain=round(min(target-m['active_rms_dbfs'],-5.0-m['peak_dbfs']),2)
            rows.append({'event':key,'file':path,**m,'target_active_rms_dbfs':target,'gain_db':gain,'result_active_rms_dbfs':m['active_rms_dbfs']+gain,'result_peak_dbfs':m['peak_dbfs']+gain})
        base=round(float(np.median([r['gain_db'] for r in rows])),2)
        entry['volume_db']=base
        entry['file_gain_db']={r['file']:round(r['gain_db']-base,2) for r in rows}
        measurements.extend(rows)
    write(OUT/'provenance.json',{'date':'2026-10-20','authorization':'这一轮我选了这些，放在这个文件夹了，你替换一些，然后主要音量的平衡，脚步声先启用','scope':'33 selected events; 35 byte-identical runtime files; existing unsupplied events retained and gain balanced; four footsteps re-enabled','files':provenance})
    write(REPORT/'before.json',before);write(REPORT/'levels.json',measurements)
    write(ROOT/'data/audio.json',config)
    print(f'{len(provenance)} adopted files, {len(manifest["events"])} selected events, {len(config)} total configured events')
if __name__=='__main__':main()
