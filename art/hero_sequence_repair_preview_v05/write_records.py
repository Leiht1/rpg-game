from pathlib import Path
import json,hashlib
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1];OLD=OUT.parent/'hero_consistency_preview_v04'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,v):(OUT/name).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
baseline=json.loads((OLD/'game_files_after.json').read_text(encoding='utf-8'))
current={name:sha(ROOT/name) for name in baseline}
save('game_files_comparison.json',{'reference':'../hero_consistency_preview_v04/game_files_after.json',
    'count':len(baseline),'unchanged':current==baseline,'changed':[name for name in baseline if current[name]!=baseline[name]]})
qa=json.loads((OUT/'clips/animation-clips.json').read_text(encoding='utf-8'))['qa']
nonpass=[]
def walk(obj,path):
    if isinstance(obj,dict):
        if 'id' in obj and obj.get('status') in ['warn','fail','needs-visual-review']:
            nonpass.append({'file':'clips/animation-clips.json','jsonPath':path,**obj})
        for k,v in obj.items():walk(v,path+'.'+k)
    elif isinstance(obj,list):
        for i,v in enumerate(obj):walk(v,f'{path}[{i}]')
walk(qa,'$.qa');save('qc_nonpass.json',nonpass)
records=[]
for p in sorted(OUT.rglob('*.png')):
    if 'clips' not in p.parts and ('generated.png'==p.name or 'frames' in p.parts):records.append({'file':p.relative_to(OUT).as_posix(),'sha256':sha(p)})
save('provenance.json',{'artSource':'existing v04 + host_image edits','route':'host:image_gen + generate2dmedia adopt',
    'completedNewImageCalls':4,'videoCalls':0,'model':'not exposed by host','generationCost':'unknown; adopt receipts are not generation billing',
    'prompts':[{'file':p.name,'sha256':sha(p)} for p in OUT.glob('*prompt.txt')],
    'references':['../hero_consistency_preview_v04/references/side_walk_corrected_reference.png',
        'side_walk/take1/generated.png','side_walk/take2/cell_02.png'],
    'walkSelection':'side_walk/selection.json',
    'rejectedCandidates':{'take1':'Only frame 3 selected; other poses did not consistently preserve second-half near/far anatomy.',
        'take2':'No final frame selected; frame 7 provides the full-pose reference for take4, but its arm swing is too far back.',
        'take3':'Select only cells 0,1,3 (frames 5,6,8). Cell 2 still trails the near leg and was rejected.',
        'take4':'Selected full frame 7, moving near hand toward neutral and retaining foreground passing leg.'},
    'idleArt':'Existing v04 front take1 / side take2; no new idle drawing. Whole-frame foot-only rigid registration.',
    'license':'Generated under applicable tool/account terms; no third-party art added, no CC0/MIT art claim.',
    'files':records})
max_seam=next(c['value'] for c in qa['checks'] if c['id']=='loop_seam')
text='''# v05 手脚衔接与呼吸脚底修订预览

已更新 Gorest 原有五条未确认预览，名称含 v05；ID/顺序与其余 52 条素材保持不变。没有替换游戏资源。当前运行仍为 Godot 4.7.2 / windrest-character-template-3 / 100 px/s / 旧 3 秒呼吸。

- 侧视第 1、2、4 帧保留原图；第 3 帧改为前向经过姿势，第 5、6、7 帧重查近远手脚，第 8 帧恢复近手后摆接回第 1 帧。左侧逐帧整身镜像，不反转时间。完整选帧见 side_walk/selection.json。
- 手部按第 5 帧前摆、第 6 帧回落、第 7 帧髋侧下垂、第 8 帧后摆核对；第 7 帧另作完整人物编辑，避免沿用错误的后摆极限。没有剪贴、画肢体、局部变形或关节拼接。
- 正面、左右呼吸只重新注册原完整帧：双脚区域 y=96:115 优先，第一帧保留，不再把头部纳入拟合。背面所有帧保留。128×128 / (64,112)，呼吸 450 ms × 4，行走 12 FPS × 8。
- 最小检查已完成：32 PNG 的透明边界、图集回读、左右镜像；保留帧与背面原图对照；skill 6 clips / 32 frames、时间轴与拷贝检查。没有重跑 Godot、地图、碰撞、性能、网页 lint/build 或整页逐帧自动操作；遵循本轮用户要求，最终播放检查交由用户手动完成。

预览：side_walk.gif / side_walk_before_after.gif、side_frame_review.png、four_directions_idle.gif。Gorest 刷新后可在 v05 条目暂停、逐帧查看。原 v04 本地目录和本轮修改前 Gorest 素材库备份保留。

## 如实保留的边界

这是修订候选，confirmed=false / needs-visual-review。新整身图仍有细小头发/衣纹/手靴轮廓与相位间距变化；不同来源完整帧之间的投影、身长和步距仍需手动看循环，不据相位文字或技术检查宣称人体/流畅度最终通过。

鞋部图像匹配最大平移残差：正面由约 0.836 px 降至约 0.013 px，右侧由约 0.641 px 降至约 0.015 px。该数值是两靴合并区域的平移拟合估计，不能证明每只鞋轮廓像素完全固定或零滑步。重新以脚为基准后，上身原有收缩更明显，头部区域相对基准仍有约 1.31 px / 1.00 px 的竖向匹配差，保留为源图呼吸与重绘边界；没有剪贴冻结头部。

skill warnings=0，但 loop_seam 仍 needs-visual-review，value=SEAM，threshold=null，文件 clips/animation-clips.json，完整记录见 qc_nonpass.json。生成共 4 次内置 image_gen，底层模型和实际费用未知；源图、提示词、adopt 回执及所有选择/弃用原因已保留。无新视频或本轮游戏性能数据。
'''.replace('SEAM',str(max_seam))
(OUT/'RESULT.md').write_text(text,encoding='utf-8')
(OUT/'QC_FINDINGS.md').write_text('# v05 最小检查与待人工验收项\n\n'+json.dumps(nonpass,ensure_ascii=False,indent=2)+'\n\n技术检查不能证明解剖、手脚对应和流畅度。具体目视限制及呼吸头部残差见 RESULT.md。\n',encoding='utf-8')
print('Records written; running game files unchanged:',current==baseline,'count',len(baseline),'loop seam',max_seam)
