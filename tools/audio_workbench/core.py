"""Independent audio selection store; never modifies gameplay configuration."""
import copy
import hashlib
import json
import os
import re
import shutil
import tempfile
import soundfile as sf
from pathlib import Path
from mutagen import File as AudioFile

FORMATS = {'.wav', '.mp3', '.ogg', '.flac'}

def read(path, default):
    if not Path(path).exists(): return copy.deepcopy(default)
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def atomic(path, data):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=path.parent, suffix='.tmp')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2); f.flush(); os.fsync(f.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name): os.unlink(name)

def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1024*1024), b''): h.update(block)
    return h.hexdigest()

def inspect(path):
    path = Path(path)
    a = AudioFile(path)
    if a is None or a.info.length <= 0: raise ValueError('无法读取音频时长')
    return {'path': str(path.resolve()), 'name': path.name, 'duration': float(a.info.length), 'folder': str(path.parent)}

def scan(folder, cancelled=lambda: False, emit=lambda rows: None):
    batch=[]; errors=[]; count=0
    def walk_error(e): errors.append(str(e))
    for base, dirs, files in os.walk(folder, followlinks=False, onerror=walk_error):
        dirs.sort()
        for name in sorted(files):
            if cancelled(): return count, errors
            p=Path(base)/name
            if p.suffix.lower() not in FORMATS: continue
            try: batch.append(inspect(p)); count+=1
            except Exception as e: errors.append(f'{p}: {e}')
            if len(batch)>=80: emit(batch); batch=[]
    if batch: emit(batch)
    return count, errors

def sync_events(project, catalog):
    """Curated evidence + live AudioFX IDs; interface has no hard-coded events."""
    project=Path(project)
    existing=read(project/'data/audio.json', {})
    rows=read(catalog, [])
    ids={r['id'] for r in rows}
    for key in existing:
        if key not in ids:
            rows.append({'id':key,'name':key,'category':'待命名（现有配置）','evidence':['data/audio.json']})
    for p in [project/'scripts/audio_fx.gd', *[project/'scripts'/n for n in ['player.gd','item_service.gd','item_inventory.gd','camp_grid.gd']]]:
        if not p.exists(): continue
        for key in re.findall(r'play_sfx\("([a-z0-9_]+)"', p.read_text(encoding='utf-8-sig')):
            if key.endswith('_') or any(r['id']==key for r in rows): continue
            rows.append({'id':key,'name':key,'category':'待命名（代码事件）','evidence':[str(p.relative_to(project))]})
    for r in rows:
        if not re.fullmatch('[a-z][a-z0-9_]+',r['id']): raise ValueError('非法事件ID')
        r['existing']=existing.get(r['id'], {})
    return rows

class Store:
    def __init__(self, path):
        self.path=Path(path)
        self.data=read(path, {'version':1,'events':{},'recent':[],'output':'','filter':''})
    def save(self): atomic(self.path,self.data)
    def event(self,key): return self.data['events'].setdefault(key,{'selected':[], 'exports':[]})
    def choose(self,key,path,on):
        row=self.event(key); path=str(Path(path).resolve())
        if on and path not in row['selected']: row['selected'].append(path)
        if not on and path in row['selected']: row['selected'].remove(path)
        self.save()
    def status(self,key):
        row=self.event(key)
        if not row['exports']: return '○'
        for f in row['exports']:
            try:
                if digest(f['output'])!=f['sha256']: return '⚠'
            except OSError: return '⚠'
        return '✓' if row.get('confirmed_selection')==row['selected'] else '◐'
    def apply(self,event,output):
        key=event['id']; row=self.event(key)
        if not row['selected']: raise ValueError('请先选择音效')
        root=Path(output).resolve()
        # Immutable content-addressed variants + atomic manifest: failed exports never replace good files.
        target=root/'selected'/event.get('output_group','other')/key
        target.mkdir(parents=True,exist_ok=True)
        old=copy.deepcopy(self.data); created=[]
        try:
            records=[]
            for source in row['selected']:
                src=Path(source); inspect(src); sha=digest(src)
                prior=next((f for f in row['exports'] if f['source']==source and f.get('source_sha256',f['sha256'])==sha),None)
                variant=prior['variant'] if prior else row.setdefault('next_variant',1)
                if not prior: row['next_variant']=variant+1
                ext='.wav' if src.suffix.lower()=='.flac' else src.suffix.lower()
                dest=target/f'{key}_{variant:02d}_{sha[:10]}{ext}'
                if dest.exists():
                    expected=prior['sha256'] if prior else sha
                    if digest(dest)!=expected: raise ValueError(f'目标文件内容冲突：{dest}')
                else:
                    fd,tmp=tempfile.mkstemp(dir=target,suffix='.tmp'); os.close(fd)
                    try:
                        if src.suffix.lower()=='.flac':
                            with sf.SoundFile(src) as audio, sf.SoundFile(tmp,'w',samplerate=audio.samplerate,channels=audio.channels,format='WAV',subtype='PCM_16') as converted:
                                for block in audio.blocks(blocksize=65536):converted.write(block)
                        else:
                            shutil.copyfile(src,tmp)
                            if digest(tmp)!=sha: raise ValueError('复制校验失败')
                        if digest(src)!=sha: raise ValueError('源文件在导出时发生变化')
                        os.replace(tmp,dest); created.append(dest)
                    finally:
                        if os.path.exists(tmp): os.unlink(tmp)
                records.append({'source':source,'source_sha256':sha,'output':str(dest),'filename':dest.name,'sha256':digest(dest),'variant':variant,'format':ext[1:]})
            manifest=root/'audio-workbench-manifest.json'
            mapping=read(manifest,{'version':1,'binding_status':'exported_only','events':{}})
            mapping['events'][key]={'id':key,'name':event['name'],'complete':True,'files':records}
            # State can be recovered from output manifest if local save fails; rollback manifest on failure.
            previous=manifest.read_bytes() if manifest.exists() else None
            atomic(manifest,mapping)
            row.update(exports=records,confirmed_selection=list(row['selected']))
            try: self.save()
            except Exception:
                if previous is None: manifest.unlink()
                else: manifest.write_bytes(previous)
                raise
        except Exception:
            self.data=old
            for p in created: p.unlink(missing_ok=True)
            raise
        # Only remove obsolete files owned by this event and matching recorded hashes.
        for f in old['events'][key]['exports']:
            p=Path(f['output'])
            if str(p) in {x['output'] for x in records}: continue
            try:
                if p.parent==target and digest(p)==f['sha256']: p.unlink()
            except OSError: pass
        return records
