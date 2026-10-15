# v04 QA 原始状态与限制

- 最终有效 clip 包为 `clips_final/`；`clips_take1/` 是首轮候选，保留原始 QA，不用它宣称最终图像检查。原图各 take、first_candidate_qa 和前后哈希可追溯。
- `clips_final/animation-clips.json`：PNG byte copy=48、WebP timeline=8、tick_grid 最大偏差=0.333 ms、near_duplicate_holds=0、manifest_lint=0；均 pass。telegraph 不适用于本轮，skipped。
- `loop_seam`：status=`needs-visual-review`，value=1.577771，threshold=null，file=`clips_final/animation-clips.json`。该状态原样保留，详见 qc_nonpass.json 和原始 QA 的每帧 seam/transitions。
- 静止区域估计相对位移上限 front 0.766 / back 0.030 / right、left 0.599 px。它们是图像匹配残差，包含重绘和采样，不等于解剖运动；没有证明零脚滑或零点头。
- front breathe take2 未优于 take1（最大残差 0.852 vs 0.766 px），未采用。side take2 仅小幅改善（0.599 vs 0.652 px）。不删除未选结果，不将尝试当作改进。
- 图片模型按提示匹配了新 walk 的比例和配色，但不是像素同色或绝对同一形状；需看 `idle_walk_switch` 和 1:1 对照。左右整帧镜像会同时翻转画中光照。
- 自定义 GIF 用累计边界对齐 10 ms；walk=670 ms、走停=3130 ms，对应 WebP 667 / 3133 ms。idle 两种格式均精确 1800 ms。不能将 GIF 的时间量化当作游戏真实时序。
- `verification.json` 的 technical_checks_pass_visual_review_pending 不表示用户批准；新 Gorest 素材均 confirmed=false。新素材尚未进入 Godot，原运行版本不变。
- 网页早期连续切换后的截图存在上一页面/帧残影，保留在 early_capture_*，不作为帧编号证据。分开操作与截图后重新核对，最终有效证据为 gorest-front-verified.png（正面第2帧）与 gorest-right-walk-verified.png（侧面第4帧）；网页状态记录同时保留。
