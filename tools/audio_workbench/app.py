import os
import sys
from pathlib import Path
if getattr(sys,'frozen',False):
    logdir=Path(os.environ.get('LOCALAPPDATA',str(Path(sys.executable).parent)))/'WindrestAudioWorkbench'
    logdir.mkdir(parents=True,exist_ok=True)
    sys.stderr=open(logdir/'diagnostic.log','a',encoding='utf-8',buffering=1)
    sys.stdout=sys.stderr
from PySide6.QtCore import Qt, QThread, Signal, QUrl, QTimer
from PySide6.QtGui import QShortcut, QKeySequence
from PySide6.QtMultimedia import QMediaPlayer, QAudioOutput
from PySide6.QtWidgets import (QApplication,QMainWindow,QWidget,QHBoxLayout,QVBoxLayout,QPushButton,QLabel,QLineEdit,QTreeWidget,QTreeWidgetItem,QTableWidget,QTableWidgetItem,QHeaderView,QFileDialog,QSlider,QComboBox,QMessageBox,QSplitter,QAbstractItemView)
from core import Store, sync_events, scan, atomic

HERE=Path(sys.executable).parent if getattr(sys,'frozen',False) else Path(__file__).resolve().parent
PROJECT=next((p for p in [HERE,*HERE.parents] if (p/'project.godot').exists()),HERE)
CATALOG=HERE/'events.json'

class Scanner(QThread):
    batch=Signal(int,list)
    done=Signal(int,list)
    def __init__(self,folder,token): super().__init__(); self.folder=folder; self.token=token
    def run(self):
        try:
            _,errors=scan(self.folder,self.isInterruptionRequested,lambda rows:self.batch.emit(self.token,rows))
        except Exception as e: errors=[str(e)]
        self.done.emit(self.token,errors)

class Window(QMainWindow):
    def __init__(self,state=None):
        super().__init__(); self.setWindowTitle('风栖原野 · 音效配置工作台'); self.resize(1280,720)
        self.store=Store(state or Path(os.environ.get('LOCALAPPDATA',str(HERE)))/'WindrestAudioWorkbench'/'state.json')
        self.events=sync_events(PROJECT,CATALOG); self.key=None; self.rows=[]; self.workers=[]; self.token=0; self.selected_only=False
        self.player=QMediaPlayer(self); self.audio=QAudioOutput(self); self.player.setAudioOutput(self.audio); self.audio.setVolume(.5)
        self.player.errorOccurred.connect(lambda *args:self.statusBar().showMessage('播放失败：'+self.player.errorString(),15000))
        self.player.positionChanged.connect(self.position); self.player.durationChanged.connect(lambda n:self.seek.setMaximum(n))
        self.render_timer=QTimer(self); self.render_timer.setSingleShot(True); self.render_timer.setInterval(150); self.render_timer.timeout.connect(self.render)
        shell=QWidget(); self.setCentralWidget(shell); outer=QVBoxLayout(shell)
        top=QHBoxLayout(); self.progress=QLabel(); top.addWidget(self.progress); top.addStretch()
        for label,fn in [('同步事件',self.sync),('输出目录',self.output),('检查导出',self.refresh_tree)]:
            b=QPushButton(label); b.clicked.connect(fn); top.addWidget(b)
        outer.addLayout(top); self.out_label=QLabel(); outer.addWidget(self.out_label)
        split=QSplitter(); outer.addWidget(split,1)
        self.tree=QTreeWidget(); self.tree.setHeaderLabel('全部声音 · 本轮重新配置'); self.tree.itemSelectionChanged.connect(self.switch); split.addWidget(self.tree)
        right=QWidget(); layout=QVBoxLayout(right); split.addWidget(right); split.setSizes([300,950])
        self.title=QLabel(); self.title.setStyleSheet('font-size:18px;font-weight:600'); layout.addWidget(self.title)
        folderbar=QHBoxLayout(); self.recent=QComboBox(); self.recent.setMinimumWidth(250); self.recent.addItems(self.store.data['recent']); self.recent.activated.connect(lambda _:self.start_scan(self.recent.currentText())); folderbar.addWidget(self.recent,1)
        for label,fn in [('选择素材文件夹',self.folder),('重新扫描',lambda:self.start_scan(self.recent.currentText())),('取消扫描',self.cancel)]:
            b=QPushButton(label); b.clicked.connect(fn); folderbar.addWidget(b)
        layout.addLayout(folderbar)
        filters=QHBoxLayout(); self.search=QLineEdit(); self.search.setPlaceholderText('按文件名搜索'); self.search.setText(self.store.data.get('filter','')); self.search.textChanged.connect(self.filter_changed); filters.addWidget(self.search,1)
        self.length=QComboBox(); self.length.addItems(['全部时长','短音 ≤ 3 秒','长音 > 3 秒']); self.length.setCurrentIndex(self.store.data.get('length',0)); self.length.currentIndexChanged.connect(self.filter_changed); filters.addWidget(self.length)
        self.count=QLabel(); filters.addWidget(self.count); layout.addLayout(filters)
        self.table=QTableWidget(0,5); self.table.setHorizontalHeaderLabels(['选择','试听','文件名','秒','目录']); self.table.setColumnWidth(0,45); self.table.setColumnWidth(1,45); self.table.setColumnWidth(2,270); self.table.setColumnWidth(3,65); self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows); self.table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers); self.table.horizontalHeader().setSectionResizeMode(4,QHeaderView.ResizeMode.Stretch); self.table.setSortingEnabled(True); self.table.itemChanged.connect(self.checked); self.table.cellClicked.connect(self.clicked); layout.addWidget(self.table,1)
        playbar=QHBoxLayout(); b=QPushButton('播放 / 暂停（空格）'); b.clicked.connect(self.toggle); playbar.addWidget(b)
        self.seek=QSlider(Qt.Orientation.Horizontal); self.seek.sliderMoved.connect(self.player.setPosition); playbar.addWidget(self.seek,1); self.time=QLabel('0.0 / 0.0'); playbar.addWidget(self.time)
        volume=QSlider(Qt.Orientation.Horizontal); volume.setRange(0,100); volume.setValue(self.store.data.get('volume',50)); volume.setMaximumWidth(100); self.audio.setVolume(volume.value()/100); volume.valueChanged.connect(self.volume); playbar.addWidget(QLabel('音量')); playbar.addWidget(volume); layout.addLayout(playbar)
        bottom=QHBoxLayout(); self.chosen=QLabel(); bottom.addWidget(self.chosen); bottom.addStretch()
        for label,fn in [('已选 / 扫描列表',self.show_chosen),('清空选择',self.clear),('确认应用',self.apply)]:
            b=QPushButton(label); b.clicked.connect(fn); bottom.addWidget(b)
        layout.addLayout(bottom)
        self.shortcut=QShortcut(QKeySequence('Space'),self); self.shortcut.activated.connect(self.toggle)
        self.refresh_tree(); self.tree.setCurrentItem(self.items.get(self.store.data.get('current'),next(iter(self.items.values()))))
        if self.recent.count(): QTimer.singleShot(0,lambda:self.start_scan(self.recent.currentText()))
    def volume(self,v): self.audio.setVolume(v/100); self.store.data['volume']=v; self.store.save()
    def current_event(self): return next(e for e in self.events if e['id']==self.key)
    def refresh_tree(self):
        key=self.key; self.tree.blockSignals(True); self.tree.clear(); groups={}; self.items={}; complete=0
        for e in self.events:
            group=groups.get(e['category'])
            if group is None: group=QTreeWidgetItem(self.tree,[e['category']]); groups[e['category']]=group
            status=self.store.status(e['id']); complete+=status=='✓'
            item=QTreeWidgetItem(group,[status+' '+e['name']]); item.setData(0,Qt.ItemDataRole.UserRole,e['id']); item.setToolTip(0,e['id']+'\n依据：'+', '.join(e['evidence'])); self.items[e['id']]=item
        self.tree.expandAll()
        if key in self.items: self.tree.setCurrentItem(self.items[key])
        self.tree.blockSignals(False); self.progress.setText(f'本轮已导出 {complete} / {len(self.events)}'); self.out_label.setText('输出：'+(self.store.data['output'] or '首次确认时选择'))
    def switch(self):
        item=self.tree.currentItem(); key=item.data(0,Qt.ItemDataRole.UserRole) if item else None
        if not key:return
        self.key=key; self.store.data['current']=key; self.store.save(); self.player.stop()
        e=self.current_event(); reference='有旧素材，仅供参考' if e.get('existing') else '尚无旧素材'
        self.title.setText(e['name']+'  ·  '+reference+'  ·  导出后待游戏接入'); self.render()
    def sync(self): self.events=sync_events(PROJECT,CATALOG); self.refresh_tree(); self.statusBar().showMessage('事件已同步；选择及导出记录保留',5000)
    def output(self):
        p=QFileDialog.getExistingDirectory(self,'选择输出文件夹',self.store.data['output'] or str(PROJECT/'assets/audio'))
        if p:self.store.data['output']=p; self.store.save(); self.refresh_tree()
    def folder(self):
        p=QFileDialog.getExistingDirectory(self,'选择素材文件夹',self.recent.currentText())
        if p:self.start_scan(p)
    def cancel(self):
        self.token+=1
        for w in self.workers:w.requestInterruption()
        self.statusBar().showMessage('扫描已取消，已选音效保留',4000)
    def start_scan(self,p):
        if not p:return
        self.cancel(); self.rows=[]; self.selected_only=False; self.render()
        recent=[p]+[x for x in self.store.data['recent'] if x!=p]; self.store.data['recent']=recent[:12]; self.store.save(); self.recent.clear(); self.recent.addItems(recent[:12])
        w=Scanner(p,self.token); self.workers.append(w); w.batch.connect(self.batch); w.done.connect(self.scan_done); w.finished.connect(lambda:self.finished_worker(w)); w.start(); self.statusBar().showMessage('正在后台扫描…')
    def finished_worker(self,w): self.workers.remove(w); w.deleteLater()
    def batch(self,token,rows):
        if token==self.token:
            self.rows.extend(rows)
            if not self.render_timer.isActive():self.render_timer.start()
    def scan_done(self,token,errors):
        if token!=self.token:return
        self.render_timer.stop(); self.render()
        atomic(self.store.path.parent/'scan-errors.json',errors); self.statusBar().showMessage(f'扫描结束：{len(self.rows)} 个音频，跳过 {len(errors)} 个错误（记录在 scan-errors.json）')
    def filter_changed(self,*args):
        self.store.data.update(filter=self.search.text(),length=self.length.currentIndex()); self.store.save(); self.render()
    def render(self):
        if not self.key:return
        selected=self.store.event(self.key)['selected']; rows=self.rows
        if self.selected_only:
            from core import inspect
            rows=[]
            for p in selected:
                try:rows.append(inspect(p))
                except Exception:rows.append({'path':p,'name':Path(p).name+'（源文件丢失）','duration':0,'folder':str(Path(p).parent)})
        query=self.search.text().casefold(); kind=self.length.currentIndex(); rows=[r for r in rows if query in r['name'].casefold() and (kind==0 or (r['duration']<=3 if kind==1 else r['duration']>3))]
        self.table.blockSignals(True); self.table.setSortingEnabled(False); self.table.setRowCount(len(rows))
        for i,r in enumerate(rows):
            check=QTableWidgetItem(); check.setFlags(check.flags()|Qt.ItemFlag.ItemIsUserCheckable); check.setCheckState(Qt.CheckState.Checked if r['path'] in selected else Qt.CheckState.Unchecked); check.setData(Qt.ItemDataRole.UserRole,r['path']); self.table.setItem(i,0,check)
            for j,text in [(1,'▶'),(2,r['name']),(4,r['folder'])]:self.table.setItem(i,j,QTableWidgetItem(text))
            duration=QTableWidgetItem(); duration.setData(Qt.ItemDataRole.DisplayRole,round(r['duration'],3)); self.table.setItem(i,3,duration)
        self.table.setSortingEnabled(True); self.table.blockSignals(False); self.mark_playing(); self.count.setText(f'{len(rows)} / {len(self.rows)}'); self.chosen.setText(f'已选 {len(selected)} 个'+(' · 候选列表' if self.selected_only else ''))
    def checked(self,item):
        if item.column()!=0:return
        self.store.choose(self.key,item.data(Qt.ItemDataRole.UserRole),item.checkState()==Qt.CheckState.Checked); self.chosen.setText(f'已选 {len(self.store.event(self.key)["selected"])} 个'); self.refresh_tree()
    def clicked(self,row,col):
        if col==1:
            if Path(self.player.source().toLocalFile())==Path(self.table.item(row,0).data(Qt.ItemDataRole.UserRole)):self.toggle()
            else:self.play(row)
    def mark_playing(self):
        self.table.blockSignals(True)
        current=Path(self.player.source().toLocalFile())
        for row in range(self.table.rowCount()):
            playing=Path(self.table.item(row,0).data(Qt.ItemDataRole.UserRole))==current
            self.table.item(row,1).setText('⏵ 当前' if playing else '▶')
            font=self.table.item(row,2).font(); font.setBold(playing); self.table.item(row,2).setFont(font)
        self.table.blockSignals(False)
    def play(self,row):
        if row<0:return
        path=self.table.item(row,0).data(Qt.ItemDataRole.UserRole)
        self.player.stop(); self.player.setSource(QUrl.fromLocalFile(path)); self.player.play(); self.mark_playing(); self.table.selectRow(row); self.statusBar().showMessage('试听：'+path)
    def toggle(self):
        row=self.table.currentRow()
        if row<0:return
        path=self.table.item(row,0).data(Qt.ItemDataRole.UserRole)
        if Path(self.player.source().toLocalFile())!=Path(path):self.play(row)
        elif self.player.playbackState()==QMediaPlayer.PlaybackState.PlayingState:self.player.pause()
        else:self.player.play()
    def position(self,n):
        if not self.seek.isSliderDown():self.seek.setValue(n)
        self.time.setText(f'{n/1000:.1f} / {self.player.duration()/1000:.1f}')
    def show_chosen(self): self.selected_only=not self.selected_only; self.render()
    def clear(self):
        self.store.event(self.key)['selected']=[]; self.store.save(); self.render(); self.refresh_tree()
    def apply(self):
        if not self.store.data['output']:self.output()
        if not self.store.data['output']:return
        try:
            records=self.store.apply(self.current_event(),self.store.data['output']); self.refresh_tree(); self.statusBar().showMessage(f'成功导出 {len(records)} 个音效；尚未绑定游戏事件',10000)
        except Exception as e:QMessageBox.warning(self,'导出未完成',str(e)); self.refresh_tree()
    def closeEvent(self,event):
        self.cancel(); self.player.stop(); self.player.setSource(QUrl())
        for w in list(self.workers):w.wait()
        self.store.save(); event.accept()

def main():
    app=QApplication(sys.argv); app.setStyle('Fusion'); app.setStyleSheet('QWidget {font-family:"Microsoft YaHei UI";font-size:12px;} QTreeWidget::item:selected,QTableWidget::item:selected {background:#34647b;color:white;} QPushButton {padding:6px 10px;}')
    try:
        if '--self-test' in sys.argv:
            import selfcheck
            return selfcheck.run(Window,PROJECT,PROJECT/'reports/.tmp/audio-workbench/packaged-check.json')
        w=Window(); w.show(); return app.exec()
    except Exception as e:
        import traceback
        traceback.print_exc()
        if '--self-test' not in sys.argv:QMessageBox.critical(None,'工作台启动失败',str(e))
        return 1

if __name__=='__main__':sys.exit(main())
