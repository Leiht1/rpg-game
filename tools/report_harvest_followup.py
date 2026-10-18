from pathlib import Path
import json
root=Path('reports/harvest-fix-v051')
body='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>采集接地、连采与快捷装备修订</title><style>body{max-width:1100px;margin:35px auto;padding:24px;background:#f4ebd8;color:#443a2e;font:16px/1.75 system-ui}img{max-width:100%;border-radius:12px;border:1px solid #bba47d}section{background:#fff8e9;border-radius:14px;padding:22px;margin:20px 0}a{color:#76501d}td,th{padding:9px;border-bottom:1px solid #d6c4a1;text-align:left}table{border-collapse:collapse;width:100%}</style><h1>采集接地、连续采集与快捷装备</h1><p>2026-10-17 · Godot 4.7.2 Stable / Compatibility / RTX 5060</p>
<section><h2>本轮修改</h2><ul><li>矿点始终绘制同一张完整主体，阶段图只供内部暗裂纹叠加；埋藏物始终绘制同一张完整物体，用固定位置的遮挡/显露参数推进进度。贴图、轮廓、显示变换和世界脚底不随阶段切换，因此不会在采集时跳位。</li><li>沿用树石使用的纯地表BackBufferCopy，在原画土唇/边缘上逐像素适配脚下真实地面颜色与亮度；保留主体颜色和轮廓，不生成程序草、底盘或新PNG。同时修正旧命中Shader重复乘贴图导致的暗化。矿石只叠加局部裂纹、命中高亮，不发生整体晃动。</li><li>石镐、铲子支持按住E对同一锁定资源逐次执行完整动作；每个动作仅提交一次。松开后完成当前动作并停止；资源耗尽、工具失效或失去目标时停止，不自动串到邻近资源。</li><li>快捷栏0–7可保留已装备实例的快捷引用。按1–8装备/切换，同一实例仍显示在原格；切换时上一件绑定工具回到原快捷格。库存、装备和地面之间始终只有一份物品，引用单独存档。非装备的快捷使用行为保持。</li><li>侧面采矿/挖掘把原工具和右手以原纹理/全局变换绘制在当前目标前方的局部世界Y层；原重复显示隐藏，手掌继续压住柄部。不是抬高整个人物或设置越过世界景物的全局Z。左右镜像保留，取消/结束/卸下恢复原绘制，背包独立正面预览保持。</li></ul></section>
<section><h2>侧面命中实景</h2><p>真实Godot运行画面，左右侧各自保持原生持握轨迹。</p><img src="contact-mine-right.png" alt="右向镐头位于矿石前"><img src="contact-mine-left.png" alt="左向镐头位于矿石前"><img src="contact-dig-right.png" alt="铲子右向插入"><img src="contact-dig-left.png" alt="铲子左向插入"></section>
<section><h2>实际地表与阶段</h2><p>每列同一资源类型、三行依次为初始/中途/完成状态对照。正式单个资源的主体不再切换位置或轮廓。底部原画边缘读取当前画面的纯地表，不按生态套统一颜色。</p><img src="grounded-stages.png" alt="接地与静止显露阶段"><h2>快捷装备</h2><img src="hotbar-equipped.png" alt="已装备工具保留快捷图标"></section>
<section><h2>验证</h2><table><tr><th>检查</th><th>结果</th></tr><tr><td><a href="tests.json">采集/快捷装备专项</a></td><td>72项，0失败</td></tr><tr><td><a href="layer-tests.json">原生左右侧工具/右手层级</a></td><td>20项，0失败</td></tr><tr><td><a href="item-actions-headless.json">原背包交互共享依赖</a></td><td>51项，0失败（无头原生Control输入）</td></tr></table><p>合计143项通过。覆盖长按/松开、单目标单次命中、装备实例不重复、快捷键切换/图标、原子存档读回、参考失效处理、原生镜像/握点、取消恢复，以及原拖拽/右键/拆分/销毁。</p><p><a href="runtime.log">采集/装备窗口日志</a> · <a href="layer.log">层级实景日志</a> · <a href="item-actions-headless.log">背包无头输入日志</a></p><p>窗口版旧拖拽测试有不稳定输入失败，日志item-actions.log保留；调试窗口曾51项通过，最终以隔离桌面鼠标的无头原生界面输入51项通过作为共享交互验证。首次长按夹具未把按键状态交给Input、后有矿石掉落抢占新测试目标，已修正夹具；不把这些失败写成通过。不进行无关全量回归或新增FPS压力测试。</p></section>
<section><h2>代码与边界</h2><p>修改scripts/harvest_node.gd、harvest_hit.gdshader、player.gd、held_tool.gd、item_inventory.gd、item_service.gd、item_ui.gd。新增hotbar_equipment存档字段仅保存引用，旧档缺字段按空映射读入；未知/悬空引用忽略，不放宽原装备实例重复校验。当前激活的快捷引用按装备保护，需先卸下后拖地丢弃/销毁；仍可拖回背包或调整空快捷格位置。</p><p>没有生成/重绘/修改PNG，没有改变角色原动作资产、地图生成、碰撞尺寸或资源掉落数量；资源耗尽与次数存档保持。实际视觉手感待用户复查。本轮完成停止。</p></section></html>'''
(root/'index.html').write_text(body,encoding='utf-8')
intro='''## 2026-10-17 · 采集固定主体、接地、长按与快捷装备
用户最新要求采集阶段不得跳位、资源像树石一样适配地形、镐/铲长按E连续采集、快捷栏装备后仍显示并能数字键切换；另明确侧面镐头不能被矿石盖住。当前矿点固定完整主体+内部裂纹叠加，埋藏物固定完整主体+显露遮挡，贴图/轮廓/脚底不切换。底部原画土边通过原纯地表拷贝逐像素适配真实地面。mine/dig长按复用完整动作且只对锁定目标逐次结算，松开完成当前动作后停。快捷装备使用hotbar_equipment实例引用（非复制物品），1–8切换，旧装备回原快捷格；旧档缺映射合法。侧面工具和右手保持原变换，按当前目标前方局部世界Y绘制，原重复显示隐藏，手掌压柄和左右镜像保持，结束恢复。新规则覆盖早期“快捷键不装备/装备后格消失”和阶段换图说明。无新增PNG/地图规则/玩法。143项相关断言通过，窗口旧拖拽输入不稳定失败留档、最终无头原生界面51项通过；实景/日志reports/harvest-fix-v051。本轮完成停止。

'''
for name in ['AGENTS.md','ITEM_SYSTEM.md','EQUIPMENT_SYSTEM.md','HARVEST_SYSTEM.md','CHARACTER_MODULAR_RULES.md']:
 p=Path(name);s=p.read_text('utf-8-sig');first,_,rest=s.partition('\n');p.write_text(first+'\n\n'+intro+rest.lstrip('\n'),encoding='utf-8')
p=Path('DEVLOG.md');s=p.read_text('utf-8-sig');s+='''

## 2026-10-17 · 采集位移/接地、长按E、快捷装备与侧面持握修正

- 用户实图指出阶段换图跳位、草地资源贴图感，并要求镐/铲长按E和快捷栏装备保留；后续补充侧面镐头跑到石后。本轮直接修正这四处，不扩展其他玩法。根因是原生成三阶段的主体位置/轮廓有差异，共用画布仍会跳动；改为矿点固定完整主体、阶段只叠加内部暗裂纹；埋藏物固定完整主体并用原地遮挡显露。阶段不再换Sprite纹理/轮廓/变换，节点/碰撞/世界脚底保持。
- harvest_hit.gdshader复用正式树石的pure-ground BackBufferCopy，底部原画土唇/边缘逐像素跟随真实地表颜色/明度；不整图染色、不画程序底盘/草，不修改PNG。修正旧Shader重复乘纹理造成的主体暗化。实际三行阶段/五类型同屏已核图；主观接地和动作手感仍待用户复查，不称用户已视觉验收。
- mine/dig纳入原长按完整动作循环：同一action_target、每周期一次命中，松开完成当前周期后停止；目标耗尽/失效/工具能力取消停止，不接管邻近资源。原石斧时序/移动速度/角色动作资产不改。
- ItemInventory新增hotbar_equipment实例引用；快捷格装备后保留图标，1–8调用装备，上一件已绑定工具返回原快捷格。原实例只在slots或equipment持有一份，引用不参与物品数量/能力；来源背包与快捷格替换、满包退回、拖回背包/移动空快捷格、卸下和旧档兼容保持。ItemService同一原子快照增加该映射，加载先通过原重复实例校验再恢复合法引用。活动引用采用装备保护，先卸下再拖地/销毁；普通食物/材料快捷使用与拖拽保持。
- 侧面mine/dig使用局部Y排序的ActiveToolContactLayer绘制原HeldTool和原右手Sprite，全局变换/贴图/镜像精确复制；手掌在柄后绘制次序之上，原重复Sprite暂藏，左手仍身体最底层。仅当前动作在目标前方排序，不提高整个角色或全局Z，不让工具盖到远处景物；取消/结束/卸下/退出恢复并清理。左右采矿/挖掘真实命中截图已核查。
- Godot4.7.2 Stable / Compatibility / RTX5060：新采集/快捷装备72项0失败；侧面原生层级20项0失败；原背包交互必要依赖51项0失败（最终无头原生Control输入），合计143项。覆盖固定主体、长按/松开、同目标结算、三工具反复切换/一份实例、数字键图标/磁盘读回、全局握点/镜像/手掌次序与取消恢复、拖拽/拆分/销毁。窗口版旧拖拽测试有多次不稳定输入失败，调试窗口曾51项0失败，相关日志全部保留；最终无头输入51项通过且实景窗口层级/快捷72+20通过，不隐去失败。首次长按夹具未更新Input状态及前一矿石奖励抢占后续夹具目标，已修正夹具后72项通过。
- 无新美术模型调用/PNG修改、外部依赖、地图生成/资源次数/碰撞/掉落变化；未做新FPS/全图压力测试。报告reports/harvest-fix-v051/index.html，更新相关规则。最终代码检查/专项日志无脚本错误；完成本轮后停止。
''';p.write_text(s,encoding='utf-8')
