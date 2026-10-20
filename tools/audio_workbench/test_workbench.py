import json
import shutil
import sys
import tempfile
import time
import unittest
import wave
import soundfile as sf
from pathlib import Path
from PySide6.QtWidgets import QApplication
from PySide6.QtCore import Qt, QUrl, QTimer
from PySide6.QtMultimedia import QMediaPlayer
from core import Store, scan, digest, sync_events
from app import Window, PROJECT, CATALOG

app=QApplication.instance() or QApplication([])

def pump(seconds):
    end=time.monotonic()+seconds
    while time.monotonic()<end:app.processEvents(); time.sleep(.01)

class WorkbenchTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='windrest-audio-'); self.root=Path(self.tmp.name)
        self.a=self.root/'素材A'/'子文件夹'; self.a.mkdir(parents=True); self.b=self.root/'素材B'; self.b.mkdir()
        self.paths=[]
        for i,base in enumerate([self.a,self.a,self.b,self.b]):
            p=base/f'sound{i}.wav'
            with wave.open(str(p),'wb') as f:f.setnchannels(1); f.setsampwidth(2); f.setframerate(22050); f.writeframes(b'\x10\x00'*22050*2)
            self.paths.append(str(p.resolve()))
        self.event=next(e for e in sync_events(PROJECT,CATALOG) if e['id']=='sfx_chop_hit')
        self.store=Store(self.root/'state.json'); self.out=self.root/'输出'
    def tearDown(self):self.tmp.cleanup()
    def test_scan_and_cancel(self):
        (self.a/'bad.wav').write_bytes(b'not audio'); batches=[]
        n,errors=scan(self.a.parent,emit=batches.extend); self.assertEqual(n,2); self.assertEqual(len(errors),1); self.assertEqual(batches[0]['duration'],2)
        self.assertEqual(scan(self.a.parent,cancelled=lambda:True)[0],0)
    def test_cross_folder_export_restart_replace(self):
        key=self.event['id']
        for p in self.paths[:3]:self.store.choose(key,p,True)
        records=self.store.apply(self.event,self.out); self.assertEqual(len(records),3); self.assertEqual(self.store.status(key),'✓')
        restored=Store(self.store.path); self.assertEqual(restored.event(key)['selected'],self.paths[:3]); self.assertEqual(restored.status(key),'✓')
        self.assertEqual(records,self.store.apply(self.event,self.out))
        other={'id':'sfx_ui_click','name':'点击','output_group':'ui'}; self.store.choose(other['id'],self.paths[0],True); other_record=self.store.apply(other,self.out)[0]
        self.store.choose(key,self.paths[1],False); self.store.choose(key,self.paths[3],True); changed=self.store.apply(self.event,self.out)
        self.assertFalse(Path(records[1]['output']).exists()); self.assertEqual(len(changed),3); self.assertTrue(Path(other_record['output']).exists())
        manifest=json.loads((self.out/'audio-workbench-manifest.json').read_text(encoding='utf-8')); self.assertEqual(len(manifest['events']),2)
        Path(changed[0]['output']).write_bytes(b'changed'); self.assertEqual(self.store.status(key),'⚠')
    def test_failure_rollback_and_source_loss(self):
        key=self.event['id']; self.store.choose(key,self.paths[0],True); record=self.store.apply(self.event,self.out)[0]
        Path(self.paths[0]).unlink(); self.assertEqual(self.store.status(key),'✓')
        with self.assertRaises(Exception):self.store.apply(self.event,self.out)
        self.assertEqual(self.store.status(key),'✓'); self.assertTrue(Path(record['output']).exists())
        self.store.choose(key,self.paths[1],True); blocker=self.root/'不能写入'; blocker.write_text('file')
        with self.assertRaises(Exception):self.store.apply(self.event,blocker)
        self.assertEqual(self.store.status(key),'◐')
    def test_real_formats_playback_and_flac_export(self):
        flac=self.b/'真实.flac'; samples,rate=sf.read(self.paths[0]); sf.write(flac,samples,rate)
        sources=[Path(self.paths[0]),flac]
        for ext in ['.ogg','.mp3']:
            sources.append(next(p for p in (PROJECT/'assets/audio').rglob('*'+ext) if 'runtime' in str(p) or 'v2' in str(p)))
        w=Window(self.root/'formats-state.json'); w.show()
        try:
            for p in sources:
                w.player.stop(); w.player.setSource(QUrl.fromLocalFile(str(p))); w.player.play(); pump(.65)
                self.assertEqual(w.player.error(),QMediaPlayer.Error.NoError,str(p)); self.assertGreater(w.player.position(),0,str(p))
            self.store.choose(self.event['id'],str(flac),True); result=self.store.apply(self.event,self.out)[0]
            self.assertEqual(Path(result['output']).suffix,'.wav'); self.assertEqual(sf.info(result['output']).subtype,'PCM_16')
            self.assertEqual(result['sha256'],digest(result['output']))
        finally:w.close(); pump(.2)
    def test_large_pack_and_long_audio(self):
        pack=self.root/'大量音效'; pack.mkdir()
        for i in range(600):
            with wave.open(str(pack/f'a{i:04d}.wav'),'wb') as f:
                f.setnchannels(1); f.setsampwidth(2); f.setframerate(22050); f.writeframes(b'\x00\x00'*441)
        w=Window(self.root/'large-state.json'); w.show(); ticks=[]; timer=QTimer(); timer.setInterval(20); timer.timeout.connect(lambda:ticks.append(1)); timer.start()
        try:
            w.start_scan(str(pack)); pump(2)
            self.assertEqual(len(w.rows),600); self.assertGreater(len(ticks),5)
            long=self.root/'long.wav'
            with wave.open(str(long),'wb') as f:
                f.setnchannels(1); f.setsampwidth(2); f.setframerate(22050); f.writeframes(b'\x00\x00'*22050*180)
            w.player.setSource(QUrl.fromLocalFile(str(long))); w.player.play(); pump(.3); w.player.pause(); w.player.setPosition(120000); pump(.2)
            self.assertGreaterEqual(w.player.duration(),180000); self.assertAlmostEqual(w.player.position(),120000,delta=300); self.assertEqual(w.player.error(),QMediaPlayer.Error.NoError)
        finally:timer.stop(); w.close(); pump(.2)
    def test_ui_scan_select_player_and_restart(self):
        w=Window(self.root/'ui-state.json'); w.show(); w.tree.setCurrentItem(w.items['sfx_chop_hit']); w.start_scan(str(self.a.parent)); pump(.8)
        self.assertEqual(len(w.rows),2)
        for row in range(2):w.table.item(row,0).setCheckState(Qt.CheckState.Checked)
        w.start_scan(str(self.b)); pump(.8); w.table.item(0,0).setCheckState(Qt.CheckState.Checked)
        self.assertEqual(len(w.store.event(w.key)['selected']),3)
        w.play(0); pump(.5); self.assertEqual(w.player.error(),QMediaPlayer.Error.NoError); self.assertGreater(w.player.position(),0)
        w.toggle(); self.assertEqual(w.player.playbackState(),QMediaPlayer.PlaybackState.PausedState)
        w.player.setPosition(900); w.volume(23); self.assertAlmostEqual(w.audio.volume(),.23,places=2); w.toggle(); pump(.2)
        w.play(1); pump(.2); self.assertEqual(Path(w.player.source().toLocalFile()),Path(w.table.item(1,0).data(Qt.ItemDataRole.UserRole)))
        w.store.data['output']=str(self.out); w.apply(); self.assertEqual(w.store.status(w.key),'✓')
        w.start_scan(str(self.a.parent)); w.start_scan(str(self.b)); pump(.8); self.assertEqual(len(w.rows),2); self.assertTrue(all(str(self.b) in r['path'] for r in w.rows))
        w.close(); pump(.2); w2=Window(self.root/'ui-state.json'); self.assertEqual(w2.key,'sfx_chop_hit'); self.assertEqual(len(w2.store.event(w2.key)['selected']),3); w2.close(); pump(.2)

if __name__=='__main__':unittest.main(verbosity=2)
