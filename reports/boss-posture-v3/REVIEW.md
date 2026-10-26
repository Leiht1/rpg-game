# V2 返工：旧版问题定位

旧版保留在 reports/boss-posture-v2、prototypes/boss-posture-v2 及 ancient_lord_posture.gd，本轮另建候选，不能覆盖正式素材。

- Neutral：球形肩、小臂和腿部形成串珠；完整金色胸框、腰带和裙摆主导人体装甲阅读，岩石只是填充材料。
- 侧面：胸口向前突出为箱形，近远腿重合；手臂的多个圆块缺少明确承重方向。
- Contact：侧面双足仍重合，正背没有可辨的纵深步距；双肘几乎沿用站姿。
- Down：支撑膝屈曲和骨盆下降不足；侧面与 Contact 几乎同形，不能表现接地后的压重。
- Passing：脚抬高但腿仍短缩重合，正背用了投影缩短却缺少明确膝部轮廓。
- 旧版结构测试通过只说明节点和约束满足旧阈值，不能作为本轮视觉通过依据。

顺序：必要岩块局部修订 → Neutral 真实拆件装配检查 → Contact → Down → Passing → 同尺度对照、关节及实际场景检查。

实际场景验证使用 tests/world_v06_formal_fixture.gd：独立 Seed、非持久世界、空保存路径，载入仓库内 ready.json 测试快照；正式相机 zoom=1，候选尺寸保持 0.8。
