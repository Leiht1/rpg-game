# v11 检查与边界

- 包装 pass：32张128×128 RGBA、4张512×256图集，8个不同完整姿势/方向；透明留白、图集逐像素回读、左右整帧镜像通过。8份GIF/WebP各8帧，原速580ms、半速1160ms，重新解码已核对。
- 来源 pass：v08八帧姿势及高清参考哈希保持，原运行文件59项哈希保持。最终8帧全部取take2同一张完整源图索引0..7，没有混用不同take、拼贴头手脚、倒放、复制半周期或代码绘制姿态。
- 尺度整理：take2整个4×2源图只有一个等比scale=0.274626865672，整帧头部X/顶边刚性注册；无每帧尺寸拟合或非等比变形。正背视仍使用原批准源图与注册，仅作为对照。Gorest sourceEdgeRisks=[]。
- 可见头部轮廓宽42.00～43.00px、高34.50～35.50px；alpha面积CV由v08的0.023798降至0.011321。这是诊断值，不等于全部身体/姿态已获验收。
- 新侧视完整可见高度91～93px，主要地面参考Y111～113；头顶参考Y20。保留源姿势投影，没有通过每帧身体缩放强行得到同样bbox数字。

## 必须保留的目视复核项

- id=`pose_redraw_variation`, status=`needs-visual-review`, value=`dominant_arm_skin_centroid_max_delta=2.601155px; foot_extent_max_delta=5.000000px`, threshold=null, files=[`pose_and_scale_diagnostics.json`,`pose_comparison_contact.png`,`side_before_after_slow.webp`]。色块重心和鞋部范围会受体型/手鞋尺寸修正、袖口和遮挡变化影响，不是关节定位器；完整重绘与原v08并非像素相同，不能保证每条轮廓和关节角度数值完全一致。
- id=`anatomical_part_consistency`, status=`needs-visual-review`, value=`head/body/hands/boots checked by complete-frame and loop review; no automatic anatomy approval`, threshold=null, files=[`crossview_contact.png`,`side_contact.png`,`preview.html`]。已按同一身体样板统一重绘，但需要用户看实际循环确认。
- id=`loop_and_contact`, status=`needs-visual-review`, value=`8-frame redraw, original order; minor contact/rhythm/outline differences possible`, threshold=null, files=[`crossview_walk.webp`,`side_before_after.webp`]。

没有发布新的WARN/FAIL质量包；上列needs-visual-review保持原状态。没有游戏性能数据、Godot新模板或引擎验收。本轮是预览候选。
