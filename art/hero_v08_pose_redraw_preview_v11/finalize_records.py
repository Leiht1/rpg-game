from pathlib import Path
import json,hashlib,zipfile
import numpy as np
from PIL import Image
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1]
def read(n):return json.loads((OUT/n).read_text(encoding='utf-8'))
def save(n,v):(OUT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
reg=read('registration.json');diag=read('pose_and_scale_diagnostics.json');summary=diag['summary'];selected=reg['selectedTake'];assert selected=='take2'
save('selection.json',{'selectedCompleteSheet':selected,'frameIndicesZeroBased':list(range(8)),'frameOrderChanged':False,'sourcePoseVersion':'v08','rejectedCandidates':[{'take':'take1','reason':'Pose arrangement followed v08, but head width44.5-45.75px and stance/body length varied more; take2 refines complete sheet with fixed original poses.'}],'review':'pose_comparison_contact.png','status':'needs-visual-review','noV09Art':True,'noMixedTakes':True})
sources=[]
for take in ['take1','take2']:
    p=OUT/take/'generated.png';im=Image.open(p)
    sources.append({'file':f'{take}/generated.png','sha256':sha(p),'size':list(im.size),'mode':im.mode,'job':f'{take}/job.json','prompt':f'prompt_{take}.txt'})
save('provenance.json',{'art_source':'host_image','route':'host:image_gen + generate2dmedia cli_media.py adopt','imageCalls':2,'videoCalls':0,'requestedModel':'codex-image_gen (host tool)','returnedModel':'not exposed','estimateUsd':None,'costNote':'Actual image price unknown; adoption receipts estimate0 reflects copying with no new image call, not free image generation.','authorization':'User explicitly requested a new complete sequence following all current v08 poses after body/hand/foot inconsistency feedback.','sources':sources,'poseReferences':'pose_reference.json','references':['references/v08_exact_eight_poses.png','references/side_body_master.png','references/crossview_reference.png','references/pose_landmark_guide.png'],'selection':'selection.json','registration':'registration.json','inheritedIdentityAndArtLicense':'../hero_side_refine_preview_v08/provenance.json','license':'Original generated character; subject to provider/account terms. Not asserted MIT or public domain. No commercial game or external third-party art used. Forge/Gorest software under their own MIT terms.','status':'needs-visual-review','previewOnly':True})
oldareas=[r['oldHead']['area'] for r in diag['frames']];newareas=[r['newHead']['area'] for r in diag['frames']]
oldcv=float(np.std(oldareas)/np.mean(oldareas));newcv=float(np.std(newareas)/np.mean(newareas))
newWidth=summary['headWidthRange'];newHeight=summary['headHeightRange'];maxArm=summary['maximumArmCentroidDelta'];maxFoot=max(abs(v) for r in diag['frames'] for v in r['footExtentDeltaPx'])
runtime=read('game_files_before.json');assert all(sha(ROOT/p)==h for p,h in runtime.items())
poses=read('pose_reference.json');assert all(sha(ROOT/p)==h for p,h in poses['sourceHashes'].items())
decoded=[]
for p in sorted(OUT.glob('*.webp'))+sorted(OUT.glob('*.gif')):
    a=Image.open(p);assert a.n_frames==8;ms=0
    for i in range(8):a.seek(i);a.load();ms+=a.info.get('duration',0)
    assert ms==(1160 if '_slow' in p.stem else 580);decoded.append({'file':p.name,'frames':8,'cycleMs':ms})
save('review_metrics.json',{'sourcePoseReference':'v08 unchanged','selectedSheet':selected,'selectedSideGlobalScale':reg['directions']['right']['globalScale'],'headWidthPx':newWidth,'headHeightPx':newHeight,'oldHeadAlphaAreaCV':oldcv,'newHeadAlphaAreaCV':newcv,'maximumDominantArmSkinCentroidDeltaPx':maxArm,'maximumFootExtentDeltaPx':maxFoot,'diagnosticLimits':'Head skin/alpha regions are estimated; arm skin centroids/foot extents change with size correction and occlusion, not exact joint measurements. No metric alone certifies anatomy or pose.','animationChecks':decoded,'runtimeAndReferenceHashesUnchanged':True})
qc=f'''# v11 检查与边界

- 包装 pass：32张128×128 RGBA、4张512×256图集，8个不同完整姿势/方向；透明留白、图集逐像素回读、左右整帧镜像通过。8份GIF/WebP各8帧，原速580ms、半速1160ms，重新解码已核对。
- 来源 pass：v08八帧姿势及高清参考哈希保持，原运行文件{len(runtime)}项哈希保持。最终8帧全部取take2同一张完整源图索引0..7，没有混用不同take、拼贴头手脚、倒放、复制半周期或代码绘制姿态。
- 尺度整理：take2整个4×2源图只有一个等比scale={reg['directions']['right']['globalScale']:.12f}，整帧头部X/顶边刚性注册；无每帧尺寸拟合或非等比变形。正背视仍使用原批准源图与注册，仅作为对照。Gorest sourceEdgeRisks=[]。
- 可见头部轮廓宽{newWidth[0]:.2f}～{newWidth[1]:.2f}px、高{newHeight[0]:.2f}～{newHeight[1]:.2f}px；alpha面积CV由v08的{oldcv:.6f}降至{newcv:.6f}。这是诊断值，不等于全部身体/姿态已获验收。
- 新侧视完整可见高度91～93px，主要地面参考Y111～113；头顶参考Y20。保留源姿势投影，没有通过每帧身体缩放强行得到同样bbox数字。

## 必须保留的目视复核项

- id=`pose_redraw_variation`, status=`needs-visual-review`, value=`dominant_arm_skin_centroid_max_delta={maxArm:.6f}px; foot_extent_max_delta={maxFoot:.6f}px`, threshold=null, files=[`pose_and_scale_diagnostics.json`,`pose_comparison_contact.png`,`side_before_after_slow.webp`]。色块重心和鞋部范围会受体型/手鞋尺寸修正、袖口和遮挡变化影响，不是关节定位器；完整重绘与原v08并非像素相同，不能保证每条轮廓和关节角度数值完全一致。
- id=`anatomical_part_consistency`, status=`needs-visual-review`, value=`head/body/hands/boots checked by complete-frame and loop review; no automatic anatomy approval`, threshold=null, files=[`crossview_contact.png`,`side_contact.png`,`preview.html`]。已按同一身体样板统一重绘，但需要用户看实际循环确认。
- id=`loop_and_contact`, status=`needs-visual-review`, value=`8-frame redraw, original order; minor contact/rhythm/outline differences possible`, threshold=null, files=[`crossview_walk.webp`,`side_before_after.webp`]。

没有发布新的WARN/FAIL质量包；上列needs-visual-review保持原状态。没有游戏性能数据、Godot新模板或引擎验收。本轮是预览候选。
'''
(OUT/'QC_FINDINGS.md').write_text(qc,encoding='utf-8')
(OUT/'RESULT.md').write_text(f'''# v11 · 按v08逐帧姿势统一重绘

按用户最新授权，重新绘制完整侧视8帧，沿用v08的动作相位、原顺序、近远手脚安排，保留第5帧低位收腿和第6帧左手在背后少量露出的要求。用同一身体样板统一头、躯干、手掌、腿和靴子的尺寸及绘制清晰度。正/背视采用已确认原图作为尺度与画风参考，没有另设计一套行走动作。

新增2次内置image_gen完整图片编辑，经generate2dmedia adopt留存；0视频。首版take1保留，最后8帧全部取take2，不混版。模型未公开、实际费用未知；源图、逐字提示词、回执、姿势参考、来源/许可和变换齐全。

最终右/左侧各8张128×128 RGBA，共用脚底原点(64,112)；左向整帧镜像。正/背视各8张对照，同样使用预乘alpha和共同采样方式。新侧视整个源图共用scale={reg['directions']['right']['globalScale']:.12f}，仅整帧刚性注册，不逐帧变大小、不拉伸局部或拼接身体。

实测头部宽{newWidth[0]:.2f}～{newWidth[1]:.2f}px、高{newHeight[0]:.2f}～{newHeight[1]:.2f}px；头部面积CV约{newcv*100:.2f}%（原v08约{oldcv*100:.2f}%）。全身可见高度91～93px，姿势及鞋底投影保留。数字只找症状，不能替代动作和全身体型验收。

preview.html支持v08原姿势/新重绘与正背视同步、原速/半速、暂停逐帧、1:1及2倍、明暗底及对齐线。side_contact.png为八帧编号图，pose_comparison_contact.png为逐帧新旧放大对照，crossview_walk为三视图动图，side_before_after为新旧动图；原速580ms/半速1160ms。

包装检查通过；仍needs-visual-review。完整重绘存在轮廓、手掌/鞋子尺寸修正所带来的细小位置差异，手臂肤色色块重心最大差{maxArm:.2f}px、鞋部范围最大差{maxFoot:.2f}px，指标含遮挡与尺寸影响，不能解读为所有关节一致或动作自动通过。完整边界在QC_FINDINGS.md。

本版仅预览。游戏仍Godot4.7.2 / windrest-character-template-4 / v06侧面行走 / 115px/s / 1.8秒呼吸；地图生成器windrest-0.1.0。原v08及已接受运行资源全部保留。无本轮运行性能数据，不接入下一阶段。
''',encoding='utf-8')
files=[]
for di in ['front','back','right','left']:
    files.extend((OUT/f'{di}_walk_preview/frames').glob('*.png'));files.append(OUT/f'{di}_walk_preview/{di}_walk_sheet.png')
for name in ['RESULT.md','QC_FINDINGS.md','provenance.json','selection.json','registration.json','pose_reference.json','review_metrics.json','prompt_take1.txt','prompt_take2.txt','take2/generated.png','take2/job.json']:
    files.append(OUT/name)
with zipfile.ZipFile(OUT/'frames_and_records.zip','w',zipfile.ZIP_DEFLATED) as z:
    for p in files:z.write(p,p.relative_to(OUT).as_posix())
with zipfile.ZipFile(OUT/'frames_and_records.zip') as z:assert z.testzip() is None
print(json.dumps({'selected':selected,'sourceSizes':[s['size'] for s in sources],'headWidth':newWidth,'headHeight':newHeight,'oldHeadCV':oldcv,'newHeadCV':newcv,'runtimeFiles':len(runtime),'zipFiles':len(files),'previewOnly':True}))
