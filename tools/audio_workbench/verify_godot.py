import subprocess
import tempfile
from pathlib import Path
import soundfile as sf
from core import Store
from app import PROJECT

def run():
    with tempfile.TemporaryDirectory(prefix='windrest-godot-audio-') as tmp:
        root=Path(tmp); source=root/'source.flac'; sf.write(source,[0.01]*44100,44100)
        store=Store(root/'state.json')
        paths=[source]+[next((PROJECT/'assets/audio').rglob('*'+ext)) for ext in ['.wav','.ogg','.mp3']]
        for p in paths:store.choose('test_audio',str(p),True)
        records=store.apply({'id':'test_audio','name':'隔离测试'},root)
        (root/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Audio compatibility test"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        check='extends SceneTree\nfunc _initialize():\n'
        for f in records:
            p='res://'+Path(f['output']).relative_to(root).as_posix()
            check+=f'\tassert(load("{p}") is AudioStream)\n'
        check+='\tprint("AUDIO_IMPORT_OK: 4")\n\tquit()\n'
        (root/'check.gd').write_text(check)
        godot=r'D:\Godot\Godot_v4.7.2-stable_win64.exe'
        for args in [['--editor','--import'],['--script','check.gd']]:
            result=subprocess.run([godot,'--headless','--path',str(root),*args],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
            print(result.stdout[-2500:]); print(result.stderr[-500:]); assert result.returncode==0
            if '--script' in args:assert 'AUDIO_IMPORT_OK: 4' in result.stdout
if __name__=='__main__':run()
