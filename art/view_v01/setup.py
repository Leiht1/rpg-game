from pathlib import Path
import hashlib,json
p=Path('prototypes/view-v01'); a=Path('art/view_v01')
paths=['scripts/world_generator.gd','scripts/terrain.gdshader','scripts/chunk_stream.gd','scripts/world.gd','scripts/player.gd','scripts/nature_prop.gd','scenes/world.tscn','project.godot']+list(map(str,Path('assets/environment/stylized_v3').glob('*.png')))
(a/'baseline.json').write_text(json.dumps({f:hashlib.sha256(Path(f).read_bytes()).hexdigest() for f in paths},indent=2))
f=Path('ART_STYLE.md');s=f.read_text(encoding='utf-8');s=s.replace('版本 3.0 ·','版本 3.1 ·',1).replace('基于当前cartoon_v2树形改进。','基于当前正式stylized_v3树形改进。');s+='''
## 唯一空间观察规范（3.1 / 2026-10-16）
统一为 2.5D 斜俯视（3/4 Top-down）轻手绘 Stylized；2.5D仅指画面空间表达，Godot仍为2D，世界XY、相机缩放及角色四方向部件动画保持。以正式白T短裤角色和实际1280×720游戏镜头为尺度基准，不为追求物理透视而重画角色。
采用正交或近似正交：从画面南侧上方向北下看，屏幕上方为远处、下方为近处；世界竖直向屏幕上方。建议环境绘制相机俯角约40°（距水平面），允许结构解释约35–45°，此数值是统一制作辅助，不声称角色具有精确三维标定。水平圆面在参考样板中短轴/长轴约0.64，竖直高度投影约0.77；平行边不汇聚，不使用等距菱形地块，不更改游戏坐标。实际物件顶面可见面积随物件结构变化，不能强制所有树、岩石、屋顶采用相同面积比。
统一画面左上柔光，亮面左上、暗面右下；投影向画面右下短距离展开，接触阴影贴地、小而柔，无黑色大圆底座；不得把顶面亮色等同于纯正面高光。环境轮廓与细节弱于角色，不重做配色或已确认森林/山地/原野地表。
- 树木：保持正式两树种轮廓、绿色体系与枝干识别；重画可见的上层冠面和向下前覆的叶群，远侧枝干被冠遮住，近侧树干进入冠下，根部落在现有脚底支点。避免正面扇形层叠、圆球树和逐叶写实。
- 岩石：顶面朝向同一上方相机，前/右侧面建立高度与厚度，后侧被顶面遮挡；不规则边与少量裂纹保留，不变成正面立板或纯顶视色块。
- 建筑/家具/道具（未来制作）：看见屋顶/台面及朝南的前侧面，必要时少量右侧面；不为展示而任意转相机，允许物体自身转向。基座接地，背后物体按脚底世界Y排序。新资源不能扩展本轮玩法范围。
- 植被/道路：低矮草叶、花叶和道路沿同一水平地面展开，直立茎叶有高度；道路不画成面向观众的立面，地面纹理不整体倾斜或压缩。
- 水体：湖面是水平面，保留程序岸线世界坐标；浅水见低对比沙石，向深水自然降亮/偏冷，少量水平短反光；远岸可见窄的向水侧泥沙坡，近岸以边缘/接触遮挡为主，岸坡厚度局部变化，不整圈高墙、不画大坑、不仅绿蓝模糊混合。水面与岸的光照遵循同一左上光源。
- 锚点与遮挡：沿用nature_prop原逻辑画布，底中心为绘制对齐参考（绘制矩形底端为脚底Y+8），树干根部/石底落在原接地点；只等比整理生成原图，不以旋转、倾斜、非等比缩放冒充重绘。保留原碰撞与交互，树冠仍通过现有遮挡淡化/Y排序处理。
制作/检查入口统一为本文件 → SCENE_ART_WORKFLOW.md → VIEW_REFERENCE.md；禁止另立互相冲突的视角。原规范中“front slightly overhead”提示词仅属历史来源，不再用于新制作。每次生成必须读取最新规范并实际附上已确认角色及正式树石/场景。具体候选经同镜头、同尺度检查视角/比例/接地/光照，状态pending_user；本轮不接入正式世界。
出生点仅为安全坐标，不是生态类型：地表继承原宏区域权重，无独立草地图覆盖、无权重转草原。仅按必要脚底活动范围稀疏/排除障碍，边缘通过坐标噪声打散，不制造规则空地。减少湖泊采用独立Seed寻址筛选原湖泊，保持宏生态、剩余湖泊轮廓/位置；候选生成器独立版本，待确认再升级正式版。
''';f.write_text(s,encoding='utf-8')
f=Path('SCENE_ART_WORKFLOW.md');f.write_text('''# 场景美术生产入口
2026-10-16 · 3.1 · ART_STYLE.md为唯一视觉标准，VIEW_REFERENCE.md为同一标准的参考样板。
1. 定位正式运行引用，读取最新ART_STYLE.md和VIEW_REFERENCE.md；保留当前角色、地表及游戏镜头尺度。不得沿用历史提示词的偏正面观察要求。
2. generate2dsprite能力检查与route_media受控生成；实际reference附上正式角色同屏、两树两石。明确3/4斜俯视近正交、左上光照；重画空间结构，不能旋转压扁现图。
3. 保存提示词、参考哈希、route、回执、原图、整理参数。费用/精确模型未知如实记录。少量候选分别检查透明边缘、轮廓、顶面/侧面、根部/石底、阴影和实际游戏显示尺寸。
4. 使用真实Godot场景、原角色和原相机，旧/新同Seed同位置同尺度切换。湖岸保留原世界岸线和自然地表过渡，用局部岸坡、沙石浅水、深水与克制反光建立空间；不改成3D或等距地图。
5. 本轮prototypes/view-v01是独立候选：树石、水岸、取消出生草地覆盖及减少湖泊。状态pending_user；旧正式资源/生成器不覆盖。地表类型恢复继承与必要净空单独验证，宏生态权重不得改动；生成规则更改写入候选生成器版本。
6. 交付同镜头前后截图、湖泊同Seed分布图、运行入口、来源与遗留问题；按视角、比例、接地、光照、遮挡和碰撞检查。数值检查不替代用户视觉验收。
7. 用户确认具体候选并授权推广后才正式接入；V0.7/V0.2的历史授权不适用于新候选。完成本轮预览即停止，不开发踏草或无关系统。
''',encoding='utf-8')
f=Path('AGENTS.md');s=f.read_text(encoding='utf-8');s+='\n- 场景统一使用 ART_STYLE.md 3.1 的2.5D斜俯视近正交体系；VIEW_REFERENCE.md为唯一附属视角样板。每次新制作检查顶部/侧面/接地/左上光照及角色同屏关系；不通过旋转挤压旧图修视角，未确认候选不得正式接入。\n';f.write_text(s,encoding='utf-8')
(a/'prompt-props.txt').write_text('''Redraw the FOUR referenced environment assets in their SAME recognizable hand-painted stylized game art style and color family, correcting their drawn spatial structure to a consistent 3/4 top-down NEAR ORTHOGRAPHIC camera, elevation 40 degrees above horizon, viewing north from south. Reference 1 is current real Godot scene with the unchanged white-shirt short-legged hero, references 2-5 are the exact existing broad tree, slender tree, broad rock and small rock identities. Do NOT redraw the hero. Do NOT make the environment realistic or 3D rendered.
Output one transparent RGBA atlas 1536x1024, exactly TWO columns and TWO rows; each cell 768x512 with 40 px transparent margins. Top left broad tree; top right slender tree; bottom left broad gray rock; bottom right small gray wedge rock. Each object fully isolated, no ground, no text, no grid, no shadow plate. Trees fill their cell HEIGHT, rocks take about 65% cell height. Keep tree shapes broad irregular and slender upright respectively, NOT round bubble trees. Preserve muted natural green leaf masses, warm brown branching trunks and roots, few light hand-drawn bark marks and clear leaf group edges. Increase canopy visible upper surfaces with overlapping rear-to-front leaf group structure viewed from ABOVE; shorten exposure of far branches by canopy occlusion, near trunk enters underside correctly. Do not merely squeeze or rotate references. No individual realistic leaves or excessive fine texture.
Rocks preserve irregular angular low silhouette, cold gray / warm gray respectively, several large top planes seen from above, shorter south/front and right side planes with believable volume; no front-facing boulders or flat overhead patches. Very sparse cracks, no realism. All four share soft upper-left lighting, lighter upward planes and muted right/down facing planes. Soft fine dark gray-green/brown outlines. Painterly restraint as references, a little more structure than hero, never photorealistic, PBR, glossy, voxel, pixel art, isometric diamonds or camera convergence. Root/rock base bottom center, no perspective vanishing point. Native alpha transparency only, no checkerboard.''',encoding='utf-8')
print('docs and generation contract written')
