# v10 检查与边界

- `pose_source_lock`: pass。8张v08完整高清帧和8张原预览PNG的SHA256已锁定并回查；零生成、零改帧序、零换姿势。所有侧视几何变换均为(s,0,tx;0,s,ty)，没有旋转、剪切、非等比缩放或局部编辑。它只保持相对姿势，不宣称与v08像素完全相同。
- `packaging`: pass。32张128×128 RGBA、4张512×256图集回读一致；左右整帧镜像；安全透明留白；8份动图各8帧，原速580ms/半速1160ms。
- `display_stature`: 正视、右侧、左侧各8帧可见高度92px，头顶Y=20、地面参考Y=112。背视7帧92px、第7帧93px/底边Y=113，保留原有鞋底投影。侧视本轮固定离线尺寸修复不能变成游戏运行时逐帧包围盒缩放。
- `finish_alpha`: pass。统一RGB锐化radius=0.5、amount=0.45、每通道修正上限8；锐化前后alpha逐像素相同。所有方向共用采样方式，不增加生成细节。
- `gorest_source_edges`: pass，sourceEdgeRisks=[]。通用自动布局仅为诊断，最终注册以本轮明确记录为准。
- `runtime_files`: pass，运行资源/脚本/场景哈希未变；预览候选不接入游戏。

## 待目视验收项

- id=`source_body_proportion_variation`, status=`needs-visual-review`, value=`v08原有非等比体型差异保留`, threshold=null, files=[`side_contact.png`,`crossview_contact.png`,`preview.html`]。整帧缩放不能同时改变头/胸/腿的相对比例；本轮严格保留姿势，不偷偷修形。
- id=`source_painted_detail_variation`, status=`needs-visual-review`, value=`不同原始绘制批次仍有笔触/细节差异，已统一采样和有上限的锐化`, threshold=null, files=[`crossview_walk.webp`,`side_before_after.webp`,`preview.html`]。不能把统一128像素或统一滤镜等同于原生绘制分辨率一致。
- id=`back_frame7_projection`, status=`needs-visual-review`, value=`visible_height=93px, groundY=113`, threshold=null, files=[`back_walk_preview/frames/back_walk_06.png`]。其他帧92px；不为表面数字整齐改原背视姿态。

本轮没有运行新的模型能力检查或图像生成；没有新增模型/FFmpeg依赖，不引用旧能力警告为本轮图片质量通过依据。
