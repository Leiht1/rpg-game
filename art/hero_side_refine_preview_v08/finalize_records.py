from pathlib import Path
import json,hashlib,subprocess,shutil
from PIL import Image
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1];ART=OUT.parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,v):(OUT/name).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
sources=[
    ('../hero_consistency_preview_v04/side_walk/take1/generated.png','../hero_consistency_preview_v04/side_walk/normalization.json',0),
    ('../hero_side_phase_preview_v07/take2/generated.png','../hero_side_phase_preview_v07/take2/registration.json',0),
    ('../hero_side_phase_preview_v07/take3/generated.png','../hero_side_phase_preview_v07/take3/registration.json',0),
    ('../hero_consistency_preview_v04/side_walk/take1/generated.png','../hero_consistency_preview_v04/side_walk/normalization.json',3),
    ('edit_frame5/generated.png',None,0),('edit_frame6/generated.png',None,0),
    ('../hero_sequence_repair_preview_v05/side_walk/take4/generated.png','../hero_sequence_repair_preview_v05/side_walk/take4/registration.json',0),
    ('../hero_sequence_repair_preview_v05/side_walk/take3/generated.png','../hero_sequence_repair_preview_v05/side_walk/take3/registration.json',3)]
selection=[{'frameOneBased':i+1,'outputIndexZeroBased':i,'source':p,'sourceSha256':sha(OUT/p),'registration':r,'sourceCellIndexZeroBased':index,'sizeCalibration':'registration.json'} for i,(p,r,index) in enumerate(sources)]
save('selection.json',{'frames':selection,'redrawnFramesOneBased':[5,6],'sizeAndRootCalibratedFramesOneBased':list(range(1,9)),'frameCount':8,'root':[64,112],'canvas':[128,128],'previewOnly':True,'left':'Whole-frame mirror in identical phase order'})
commit=subprocess.check_output(['git','-C',str(ROOT/'.forge/agent-sprite-forge'),'rev-parse','HEAD'],text=True).strip()
save('installation.json',{'repository':'https://github.com/0x0funky/agent-sprite-forge','commit':commit,'version':'0.4.0','license':'MIT','localCheckout':'.forge/agent-sprite-forge','installedSkillRoot':'C:/Users/雷/.codex/skills','skills':['generate2dsprite','generate2dmedia','video2dsprite','generate2dmap','codeart2d'],'installer':'skill-installer/scripts/install-skill-from-github.py','python':'3.12.14','numpy':'2.3.5','Pillow':'12.3.0','capabilities':'doctor.json'})
shutil.copy2(ROOT/'.forge/agent-sprite-forge/LICENSE',OUT/'TOOL_LICENSE.txt')
save('provenance.json',{'art_source':'host_image','route':'host:image_gen + generate2dmedia cli_media.py adopt','imageCalls':2,'videoCalls':0,'model':'not exposed','estimateUsd':None,'costNote':'Adoption receipt estimate 0 only records a copy with no new provider call; actual generation price unknown.','prompts':['prompt_frame5.txt','prompt_frame6.txt'],'references':['../hero_side_phase_preview_v07/take4/high_frame_04.png','../hero_side_phase_preview_v07/take6/high_frame_05.png'],'sources':[{'file':f'edit_frame{i}/generated.png','sha256':sha(OUT/f'edit_frame{i}/generated.png'),'receipt':f'edit_frame{i}/job.json'} for i in [5,6]],'inheritedProvenance':'../hero_side_phase_preview_v07/provenance.json','toolInstallation':'installation.json','selection':'selection.json','normalization':'registration.json','license':'Original generated character; subject to generation provider/account terms. No claim of public-domain or MIT license on the generated art. Forge and Gorest software are MIT; no external game art used.','status':'needs-visual-review','previewOnly':True})
v=json.loads((OUT/'verification.json').read_text(encoding='utf-8'));m=v['measuredRegistration']
lo=min(f['registeredHeadHeightPx'] for f in m);hi=max(f['registeredHeadHeightPx'] for f in m)
doctor=json.loads((OUT/'doctor.json').read_text(encoding='utf-8'))
warnings=[c for c in doctor['checks'] if c['status'] in ['WARN','FAIL','MISSING','UNKNOWN']]
qc='''# v08 检查与限制

- 包装检查 pass：16 张不同方向 PNG，128×128 RGBA、安全透明边界、图集逐像素回读、左右整帧镜像、8 个动图各八帧解码。原速 580 ms、半速 1160 ms；Gorest 使用 13.8 FPS。
- Gorest 实际网格/alpha 诊断 sourceEdgeRisks=[]。`gorest_diagnostic.png` 是通用自动布局的诊断输出，最终采用有记录的手动语义注册；通用脚部重心对齐不适合直接抵消交替步态。
- 8 帧共享 (64,112) 原点，支撑地面线 Y=112。已按本轮用户“统一每帧大小尺寸”对高分辨率整帧作等比源尺度校准，依据固定头顶至下颌区域，不按全身动作包围盒高度拟合、不拉伸或拼贴肢体。最终显示缩放共同为 1/4；每个源校准值在 registration.json 中公开，不能误称源图原始缩放完全相同。
'''
qc+=f'- 重新测量注册后的头部尺寸 {lo:.3f}～{hi:.3f} px，差 {hi-lo:.3f} px；头部水平中心 61.125～61.250 px。完整姿势可见高度 90～94 px，包含屈膝/迈步起伏及原图比例差异，不能等同体型缩放误差。\n'
qc+='''- 原第5帧的右腿过度折叠已减轻，第6帧远侧左手已从前方移到背后少量露出；完整图片编辑仍有轻微线条/细节重绘差异，不能宣称未编辑区域逐像素一致。
- visualStatus=needs-visual-review：循环的解剖自然度、余留比例差异及实际节奏仍需用户验收。没有把数值检查当成动作通过。
- 没有接入游戏、导出新的运行 SpriteFrames 或更改动作模板；没有本轮 Godot/地图/性能测试。

## 能力检查原始警告与缺失

以下逐项沿用 doctor.json 的 id/status/detail（无数值 threshold 的能力检查保留 null）。不把可选视频、代码绘画或 API 能力缺失当成本轮 PNG 流程失败：

'''
for c in warnings:qc+=f'- `{c["id"]}` status={c["status"]}; value={c["detail"]}; threshold=null; files=[doctor.json]\n'
(OUT/'QC_FINDINGS.md').write_text(qc,encoding='utf-8')
(OUT/'RESULT.md').write_text(f'''# 侧视 v07 的 v08 修订预览

本轮完成第5帧右腿减轻弯曲、第6帧远侧左手移到身后少量露出，并对全部8帧统一角色尺度和地面定位。左侧由右侧整帧镜像。

`side_walk_game_speed.gif` / `.webp` 为原速左右预览，580 ms / 八帧；上方2倍明底，下方1:1暗底。`side_walk_game_speed_slow` 为半速，`side_walk_compare` 为 v07/v08 原速对照，`side_walk_slow` 为半速新旧对照。`all_frames_contact.png` 可逐帧检查。

所有帧为128×128 RGBA，脚底原点(64,112)。依据固定头部解剖尺寸等比校准每个来源；注册后头部尺寸 {lo:.3f}～{hi:.3f} px，头部X中心差0.125 px；支撑地面线一致为112。姿势高度90～94 px，保留自然屈膝变化。尺度并非通过逐帧全身包围盒归一化取得，所有实际变换见 registration.json。

使用 generate2dsprite、内置 image_gen 和 generate2dmedia adopt。2次完整图片编辑，0视频；模型未公开，实际费用未知。源图、逐字提示词、来源哈希、回执和选帧均保存。生成美术遵循账户/供应方条款，未使用外部商业游戏资源。

Gorest 更新本机两条未确认侧视候选，保留ID和顺序，显示版本v08；原v07目录、原图集及修改前库快照均保留。运行游戏仍是 Godot4.7.2 / windrest-character-template-4 / v06侧面行走 / 115px/s / 1.8秒呼吸；地图生成器windrest-0.1.0。未接入游戏或升级运行模板。

包装/动图检查通过，目视仍 needs-visual-review；轻微重绘轮廓、身长差异及左侧镜像光照保留。本轮无游戏性能数据。完整检查边界和能力警告见 QC_FINDINGS.md。
''',encoding='utf-8')
print('Saved exact prompts, provenance, source hashes, installation and review records.')
