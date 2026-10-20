"""Same native UI/decoder smoke test in source and packaged application."""
import tempfile
import time
from pathlib import Path
from PySide6.QtWidgets import QApplication
from PySide6.QtCore import QUrl
from PySide6.QtMultimedia import QMediaPlayer
from core import atomic

def run(window_class,project,report):
    def pump(seconds):
        end=time.monotonic()+seconds
        while time.monotonic()<end:QApplication.processEvents(); time.sleep(.01)
    results=[]
    with tempfile.TemporaryDirectory(prefix='windrest-packaged-check-') as tmp:
        w=window_class(Path(tmp)/'state.json'); w.show()
        try:
            w.tree.setCurrentItem(w.items['sfx_chop_hit']); w.start_scan(str(project/'assets/audio')); pump(1.5)
            assert len(w.rows)>10; results.append('native_window_recursive_scan')
            for ext in ['.wav','.mp3','.ogg']:
                p=next(Path(r['path']) for r in w.rows if Path(r['path']).suffix==ext)
                w.player.setSource(QUrl.fromLocalFile(str(p))); w.player.play(); pump(.4)
                assert w.player.error()==QMediaPlayer.Error.NoError
                assert w.player.position()>0
                results.append('decoder_progress'+ext)
            w.player.pause(); pump(.1); assert w.player.playbackState()==QMediaPlayer.PlaybackState.PausedState; results.append('pause')
            for r in w.rows[:3]:w.store.choose(w.key,r['path'],True)
            w.store.data['output']=str(Path(tmp)/'export'); w.apply(); assert w.store.status(w.key)=='✓'; results.append('three_variant_export')
            w.render(); pump(.2)
            screenshot=Path(report).parent/'window.png'; screenshot.parent.mkdir(parents=True,exist_ok=True); w.grab().save(str(screenshot))
            atomic(report,{'passed':results,'window':[w.width(),w.height()],'event_count':len(w.events)})
        finally:w.close(); pump(.2)
    return 0
