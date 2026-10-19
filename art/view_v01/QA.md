# 统一视角 V0.1 候选 QA
- 状态 pending_user；真实图像生成 route local:codex-cli / model codex-image_gen，art_source=host_image；底层模型精确版本与实际费用未知，estimateUsd=0仅订阅路线回执估计。
- 提示词prompt-props.txt；5个实际附图哈希、裁片所有权、等比整理及脚底对齐参数见processing.json；原图与job回执在props/。
- WARN 原文：raw_sheet: requested equal grid not respected; manual ownership rectangles required
- WARN 原文：raw_sheet: colored translucent glow; alpha<210 discarded during cleanup
- 实际原图1536×1024 RGBA，树石上下排不遵守512行边界，已按所有权矩形切割；透明彩色光晕剔除。未用旋转/非等比缩放修视角。
- 原逻辑画布四项全部相同：177×190 / 177×198 / 77×65 / 54×48。底中心对齐，沿用绘制底端rootY+8；原碰撞安装/交互未覆盖。
- 真Godot4.7.2 Stable / Compatibility / RTX3060渲染8张1280×720截图。位置与camera_zoom见runtime.json，旧/新相同。逐张检查森林/山地/出生/水岸；湖岸首次过柔且规则反光，后修窄水线/局部低坡与稀疏反光；最后局部岸坡强度改为不连续分布，仅重新渲染受影响湖岸，capture-lake.log无脚本/资源/Shader错误。
- 24项生成专项通过：3 Seed复现、湖泊减少、保留几何、宏站点一致、出生继承、近点水域可行走及无固定样例/障碍净空。真实角色出生20物理帧移动63.3457单位。没有新增碰撞/交互代码，未做无关全量回归或新性能保证。
- review.json：正式脚本/场景/工程配置/现有stylized_v3资源哈希不变。可玩预览独立，不保存正式世界身份；worker使用候选生成器以避免主线程/后台规则混用。
- 视觉限制：宽树保持画布但可见冠顶略矮；细树叶群层叠仍明显，需用户判断；湖岸为静态近正交表现，非真实地形高度，浅水沙石来自已确认shore纹理。湖泊任意Seed总体疏密仍需视觉验收，不保证全陆地连通。
- doctor警告：python.path（PATH有另一个python）、paths.cwd（非ASCII目录）。缺少resvg/API keys/Grok不是本轮图像路线依赖，无安装新依赖。


## 湖岸复审 V0.2
- 本轮无新图像生成；复用已确认shore纹理及上一轮树石候选，修改候选水域生成与材质绘制。art_source=existing（地表）+procedural shader（水岸表现），不新增代码绘制的PNG美术资源。
- 用户否决V0.1椭圆与纯顶视观感。重建不对称湖湾/岬角，远岸通过向南可见坡面/接触阴影表达局部5–14世界单位高度，近岸薄边遮挡；不对整片水面做缩放旋转。旧候选归档lake-v01-archive。
- 21项专项通过，3 Seed湖泊数不变（133/134/149），宏站点/陆地生态权重保持，不规则岸线同Seed复现；每Seed前8湖×24方向采样有110/112/107点与旧椭圆水域显著不同。不是美术验收通过声明。
- 实际1280×720、zoom1同镜头完整湖形与角色/树石参照，前后角色和相机偏移一致，见lake-runtime.json。capture-lake.log无脚本/资源/Shader错误；review.json确认正式文件无变化。总览图已按新水域重生成，其他对比图保留前轮结果。
- 局限：岸坡高度仅静态绘制，无真实高度物理；当前轮廓有较大的叶状湖湾，仍需用户判断自然度。局部泥沙/水线仍有柔边。未做无关全量回归或性能测试。


## 2026-10-16 · 已确认并正式接入
用户明确确认湖泊并授权将刚才全部修改接入游戏。正式树石使用 assets/environment/view_v01 四张原候选，湖岸使用 scripts/terrain.gdshader 的已确认坡面/浅深水/反光表现；美术版本 scene-view-0.2.0。沿用大型生态生成器 windrest-biome-0.4.0、减湖和自然出生，不回退候选0.3布局。角色、地表画稿、树石逻辑尺寸/脚底/碰撞与交互保持。接入时修复岸坡跨区块采样边缘接缝：将权重采样边框扩至3像素并仅绘制区块内部，避免岸坡偏移超出边框及相邻区块重复覆盖。旧资源及候选截图保留追溯；后续新素材仍须依最新规范制作并确认。
