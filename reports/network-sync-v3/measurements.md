# 最终测量（P50 / P95 / 最大，耗时单位 ms）

分位数线性插值；具体样本数见 summary.json。仅计成功的四类普通命令，争抢单列；不包含设计中的制作耗时。

|阶段|客户端|操作确认|首帧显示|帧时间|状态应用|
|---|---|---|---|---|---|
|before-single-final|result0.json|258.83 / 470.22 / 506.25|270.30 / 482.49 / 517.65|16.67 / 39.26 / 97.93|32.15 / 41.89 / 44.42|
|after-single-entities|result0.json|219.49 / 335.84 / 500.70|227.67 / 348.18 / 511.46|16.67 / 29.53 / 78.77|17.25 / 24.51 / 44.27|
|before-double-final|result0.json|320.48 / 461.74 / 623.45|331.30 / 471.28 / 630.76|16.66 / 38.69 / 159.81|33.09 / 46.90 / 73.18|
|before-double-final|result1.json|313.36 / 531.28 / 584.30|325.64 / 546.47 / 593.81|16.67 / 40.17 / 123.85|33.77 / 46.49 / 102.95|
|after-double-entities|result0.json|258.27 / 426.61 / 502.05|268.32 / 433.24 / 510.96|16.66 / 27.35 / 100.04|18.65 / 25.52 / 42.38|
|after-double-entities|result1.json|236.43 / 435.16 / 455.35|243.61 / 444.35 / 462.18|16.65 / 27.50 / 110.71|18.32 / 24.70 / 46.02|
|before-single-ui|result0.json|414.47 / 638.61 / 745.84|426.26 / 650.33 / 757.74|16.68 / 46.11 / 128.06|30.99 / 46.31 / 59.05|
|after-single-ui|result0.json|382.01 / 657.54 / 698.44|391.93 / 668.67 / 711.88|16.66 / 32.25 / 129.56|17.73 / 38.08 / 46.31|

## 四类操作确认与服务器业务时间

|阶段/客户端|操作|成功数|确认 P50/P95/max|服务端处理 P50/P95/max|
|---|---|---|---|---|
|before-single-final/result0.json|interact|6|441.26 / 498.88 / 506.25|100.31 / 133.23 / 142.77|
|before-single-final/result0.json|inventory|12|227.88 / 278.93 / 297.24|100.56 / 144.84 / 150.71|
|before-single-final/result0.json|craft|6|227.36 / 336.15 / 343.13|107.29 / 193.92 / 195.33|
|before-single-final/result0.json|building_place|6|272.43 / 430.09 / 453.50|144.06 / 275.88 / 313.07|
|after-single-entities/result0.json|interact|6|269.36 / 461.64 / 500.70|99.29 / 137.82 / 142.46|
|after-single-entities/result0.json|inventory|12|197.65 / 296.29 / 312.26|77.16 / 179.31 / 196.21|
|after-single-entities/result0.json|craft|6|219.71 / 241.43 / 247.53|88.95 / 111.39 / 117.78|
|after-single-entities/result0.json|building_place|6|217.30 / 310.29 / 325.31|97.33 / 178.66 / 202.67|
|before-double-final/result0.json|interact|6|391.53 / 585.60 / 623.45|96.00 / 196.66 / 227.38|
|before-double-final/result0.json|inventory|12|317.77 / 431.23 / 432.25|157.12 / 314.12 / 318.72|
|before-double-final/result0.json|craft|6|343.18 / 428.58 / 431.01|181.21 / 290.40 / 298.05|
|before-double-final/result0.json|building_place|4|238.70 / 255.90 / 257.65|103.17 / 111.27 / 112.61|
|before-double-final/result1.json|interact|6|472.62 / 572.77 / 584.30|212.23 / 257.92 / 260.50|
|before-double-final/result1.json|inventory|12|235.22 / 368.96 / 381.33|94.97 / 250.55 / 258.02|
|before-double-final/result1.json|craft|6|271.30 / 411.97 / 419.22|162.87 / 273.05 / 284.01|
|before-double-final/result1.json|building_place|5|341.86 / 433.42 / 446.34|163.64 / 266.44 / 268.10|
|after-double-entities/result0.json|interact|6|363.32 / 487.11 / 502.05|152.71 / 258.76 / 273.50|
|after-double-entities/result0.json|inventory|12|221.62 / 377.29 / 388.10|104.35 / 265.12 / 303.17|
|after-double-entities/result0.json|craft|6|231.46 / 295.16 / 300.21|109.57 / 184.84 / 189.60|
|after-double-entities/result0.json|building_place|5|261.60 / 389.55 / 403.10|145.93 / 281.40 / 301.37|
|after-double-entities/result1.json|interact|6|394.23 / 435.73 / 441.15|150.50 / 262.62 / 274.42|
|after-double-entities/result1.json|inventory|12|200.10 / 421.59 / 455.35|88.69 / 317.29 / 347.26|
|after-double-entities/result1.json|craft|6|188.57 / 380.85 / 426.18|90.24 / 272.41 / 316.79|
|after-double-entities/result1.json|building_place|5|256.14 / 398.75 / 399.77|119.62 / 274.53 / 276.28|
|before-single-ui/result0.json|interact|6|402.14 / 435.15 / 438.34|124.25 / 149.71 / 155.10|
|before-single-ui/result0.json|inventory|12|345.64 / 520.25 / 527.53|76.49 / 190.58 / 198.24|
|before-single-ui/result0.json|craft|6|479.56 / 527.28 / 529.55|108.08 / 166.99 / 177.28|
|before-single-ui/result0.json|building_place|6|539.26 / 721.60 / 745.84|122.17 / 276.76 / 304.74|
|after-single-ui/result0.json|interact|6|347.95 / 385.39 / 388.78|109.10 / 152.96 / 156.77|
|after-single-ui/result0.json|inventory|12|300.45 / 539.20 / 550.75|82.52 / 191.81 / 203.65|
|after-single-ui/result0.json|craft|6|429.42 / 456.44 / 462.82|124.02 / 135.31 / 135.49|
|after-single-ui/result0.json|building_place|6|618.80 / 695.09 / 698.44|150.08 / 179.65 / 182.19|

## 消息大小、频率与解析

大小列均为中位数 bytes；Hz 是该阶段实际观察值，初始身份消息只各发一次，不把它当作周期频率。

|阶段/客户端|消息|条数|Hz|请求体|响应体|解压 JSON|请求序列化 P50/P95/max|JSON 解析 P50/P95/max|
|---|---|---|---|---|---|---|---|---|
|before-single-final/result0.json|game_command|51|1.256|223|17078|174636|未记录|3.203/4.732/5.542|
|before-single-final/result0.json|game_snapshot|113|1.748|82|17014|174352|未记录|3.177/4.123/8.044|
|before-single-final/result0.json|move|400|8.084|319.0|943.0|943.0|未记录|0.032/0.062/0.126|
|before-single-final/result0.json|poll|402|8.127|67.0|1049.0|1049.0|未记录|0.044/0.080/0.201|
|before-single-final/result0.json|resume|1|3.76|56|262913|262913|未记录|7.494/7.494/7.494|
|before-single-final/result0.json|character|1|0.056|131|263218|263218|未记录|4.517/4.517/4.517|
|after-single-entities/result0.json|game_command|49|1.356|2141|5008|28729|0.062/0.092/0.143|0.899/1.769/2.212|
|after-single-entities/result0.json|game_snapshot|102|1.706|1988.0|4839.5|23248.0|0.052/0.105/0.140|0.749/2.388/6.859|
|after-single-entities/result0.json|move|380|8.437|310.0|945.0|945.0|0.033/0.066/0.147|0.032/0.063/0.163|
|after-single-entities/result0.json|poll|368|8.164|67.0|1050.0|1050.0|0.013/0.031/0.128|0.044/0.078/0.132|
|after-single-entities/result0.json|resume|1|6.726|70|1062|1062|0.021/0.021/0.021|0.246/0.246/0.246|
|after-single-entities/result0.json|character|1|0.055|145|1399|1399|0.016/0.016/0.016|0.158/0.158/0.158|
|before-double-final/result0.json|game_command|55|1.259|235|17090|174536|0.026/0.061/0.084|3.087/3.738/5.169|
|before-double-final/result0.json|game_snapshot|111|1.597|82|17068|174729|0.013/0.028/0.039|3.218/4.881/6.748|
|before-double-final/result0.json|move|384|7.237|275.0|1627.0|1627.0|0.033/0.064/0.162|0.058/0.113/0.164|
|before-double-final/result0.json|poll|366|6.898|67.0|1732.0|1732.0|0.013/0.029/0.051|0.075/0.141/0.255|
|before-double-final/result0.json|resume|1|5.023|56|262913|262913|0.012/0.012/0.012|4.682/4.682/4.682|
|before-double-final/result0.json|character|1|0.056|131|263218|263218|0.014/0.014/0.014|4.029/4.029/4.029|
|before-double-final/result1.json|game_command|53|1.207|235|17083|174707|0.027/0.050/0.067|3.077/5.067/5.493|
|before-double-final/result1.json|game_snapshot|109|1.57|82|17061|174613|0.014/0.030/0.050|3.237/4.866/6.995|
|before-double-final/result1.json|move|387|7.288|275|1628|1628|0.034/0.066/0.144|0.056/0.107/0.166|
|before-double-final/result1.json|poll|374|7.043|67.0|1732.0|1733.0|0.013/0.027/0.048|0.072/0.142/0.192|
|before-double-final/result1.json|resume|1|7.46|56|262913|262913|0.017/0.017/0.017|4.373/4.373/4.373|
|before-double-final/result1.json|character|1|0.056|131|263218|263218|0.017/0.017/0.017|3.688/3.688/3.688|
|after-double-entities/result0.json|game_command|52|1.308|2141.0|5115.0|29254.5|0.069/0.094/0.162|0.945/1.859/2.410|
|after-double-entities/result0.json|game_snapshot|106|1.624|1988.0|6837.5|37510.0|0.053/0.091/0.126|1.323/2.329/3.772|
|after-double-entities/result0.json|move|390|7.911|275.0|1631.0|1631.0|0.032/0.066/0.129|0.060/0.112/0.218|
|after-double-entities/result0.json|poll|355|7.201|67|1735|1735|0.012/0.034/0.107|0.073/0.141/0.236|
|after-double-entities/result0.json|resume|1|7.616|70|1062|1062|0.017/0.017/0.017|0.049/0.049/0.049|
|after-double-entities/result0.json|character|1|0.055|145|1399|1399|0.023/0.023/0.023|0.071/0.071/0.071|
|after-double-entities/result1.json|game_command|54|1.349|2141.0|5140.5|29782.5|0.064/0.104/0.126|0.948/2.026/2.337|
|after-double-entities/result1.json|game_snapshot|107|1.635|1988|8306|44379|0.054/0.087/0.111|1.377/2.476/3.752|
|after-double-entities/result1.json|move|377|7.659|275|1630|1631|0.033/0.061/0.160|0.062/0.105/0.202|
|after-double-entities/result1.json|poll|352|7.164|67.0|1735.0|1735.0|0.013/0.028/0.054|0.073/0.131/0.331|
|after-double-entities/result1.json|resume|1|6.757|70|1062|1062|0.020/0.020/0.020|0.108/0.108/0.108|
|after-double-entities/result1.json|character|1|0.056|145|1399|1399|0.019/0.019/0.019|0.133/0.133/0.133|
|before-single-ui/result0.json|game_command|70|2.327|193.0|17066.5|174714.0|0.021/0.050/0.116|3.030/4.772/5.996|
|before-single-ui/result0.json|game_snapshot|77|1.423|82|17031|174772|0.013/0.044/0.058|3.016/4.008/4.788|
|before-single-ui/result0.json|move|321|8.22|274|942|942|0.031/0.076/0.149|0.032/0.061/0.171|
|before-single-ui/result0.json|poll|314|8.04|67.0|1049.0|1049.0|0.013/0.044/0.187|0.043/0.096/0.232|
|before-single-ui/result0.json|resume|1|4.644|56|262913|262913|0.012/0.012/0.012|4.183/4.183/4.183|
|before-single-ui/result0.json|character|1|0.058|131|263218|263218|0.015/0.015/0.015|3.789/3.789/3.789|
|after-single-ui/result0.json|game_command|67|2.207|2087|4984|28986|0.064/0.150/0.206|0.943/1.814/2.630|
|after-single-ui/result0.json|game_snapshot|81|1.497|1988|1130|2131|0.053/0.091/0.122|0.149/2.691/4.813|
|after-single-ui/result0.json|move|320|8.152|304.5|944.0|944.0|0.032/0.069/0.141|0.032/0.078/0.149|
|after-single-ui/result0.json|poll|309|7.869|67|1049|1049|0.013/0.032/0.079|0.044/0.093/0.213|
|after-single-ui/result0.json|resume|1|7.64|70|1062|1062|0.020/0.020/0.020|0.126/0.126/0.126|
|after-single-ui/result0.json|character|1|0.055|145|1399|1399|0.023/0.023/0.023|0.103/0.103/0.103|

## 服务器响应编码与准备

按阶段汇总全部连接的成功消息。准备包含组件摘要比较、JSON编码与压缩；JSON耗时是其子项，不再次累加。

|阶段|消息|条数|JSON编码 P50/P95/max|业务结束至响应准备好 P50/P95/max|
|---|---|---|---|---|
|before-single-final|game_command|43|1.99 / 3.06 / 4.15|3.20 / 4.80 / 7.74|
|before-single-final|game_snapshot|117|1.83 / 2.77 / 4.81|2.72 / 3.93 / 10.10|
|before-single-final|resume|2|4.86 / 6.35 / 6.52|4.89 / 6.38 / 6.55|
|before-single-final|character|2|3.80 / 4.37 / 4.43|3.86 / 4.46 / 4.53|
|after-single-entities|game_command|43|0.60 / 0.96 / 5.94|3.70 / 5.61 / 9.63|
|after-single-entities|game_snapshot|106|0.66 / 2.26 / 6.79|3.85 / 10.10 / 27.24|
|after-single-entities|resume|2|0.04 / 0.05 / 0.05|0.17 / 0.19 / 0.19|
|after-single-entities|character|2|0.06 / 0.06 / 0.06|0.24 / 0.28 / 0.28|
|before-double-final|game_command|82|1.90 / 3.30 / 15.85|3.07 / 8.61 / 30.27|
|before-double-final|game_snapshot|228|1.84 / 2.79 / 4.72|2.82 / 7.92 / 18.20|
|before-double-final|resume|4|3.45 / 3.68 / 3.72|3.47 / 3.71 / 3.74|
|before-double-final|character|4|4.12 / 5.02 / 5.07|4.15 / 5.06 / 5.10|
|after-double-entities|game_command|83|0.80 / 1.32 / 1.85|4.60 / 15.52 / 26.01|
|after-double-entities|game_snapshot|222|0.66 / 1.28 / 3.67|3.58 / 13.77 / 38.27|
|after-double-entities|resume|4|0.04 / 0.05 / 0.05|0.17 / 0.23 / 0.24|
|after-double-entities|character|4|0.05 / 0.06 / 0.06|0.15 / 0.19 / 0.20|
|before-single-ui|game_command|64|1.58 / 3.27 / 4.59|2.74 / 5.42 / 5.96|
|before-single-ui|game_snapshot|81|1.56 / 2.56 / 3.73|2.66 / 4.45 / 20.06|
|before-single-ui|resume|2|2.99 / 3.16 / 3.18|3.01 / 3.19 / 3.21|
|before-single-ui|character|2|3.82 / 4.99 / 5.12|3.85 / 5.03 / 5.16|
|after-single-ui|game_command|64|0.52 / 2.24 / 2.89|3.80 / 8.65 / 17.91|
|after-single-ui|game_snapshot|85|0.05 / 1.39 / 3.48|3.70 / 6.40 / 22.76|
|after-single-ui|resume|2|0.04 / 0.05 / 0.05|0.17 / 0.18 / 0.18|
|after-single-ui|character|2|0.06 / 0.06 / 0.06|0.20 / 0.20 / 0.20|

## 实测连接往返

同一 TLS 持久连接 21 次微小请求，剔除第一次冷连接；请求/应答 85/59 bytes，应用层往返含 SSH 和服务端拒绝处理，不是单向传播时间。另给减去服务端同请求处理时间后的残差；没有跨机器减系统时间。

|阶段|RTT P50/P95/max|减服务端处理后的往返残差 P50/P95/max|
|---|---|---|
|before-single-final|66.42 / 162.48 / 173.57|41.05 / 133.10 / 133.30|
|after-single-entities|118.73 / 155.27 / 169.62|97.06 / 130.15 / 130.83|
|before-double-final|100.27 / 170.35 / 171.39|81.25 / 133.85 / 133.99|
|after-double-entities|125.82 / 171.04 / 171.65|123.96 / 131.29 / 131.30|
|before-single-ui|100.79 / 170.54 / 171.25|77.96 / 130.55 / 130.77|
|after-single-ui|124.59 / 170.65 / 171.26|123.67 / 131.11 / 132.54|

## 一次成功交互的完整分解

以下从修改后单人各操作选最接近其中位数的一条。服务器几列嵌套于 HTTP 等待，不能再与 HTTP 等待相加；每条原始关联记录见 lifecycle.csv。

|操作/请求 ID|发送前排队/移动边界/重试|连接发送等待|HTTP 发出至收完|解压|JSON解析|增量合并/缓存|完整世界/界面应用|确认|首帧|服务端业务|服务端准备响应|服务端写出|
|---|---|---|---|---|---|---|---|---|---|---|---|---|
|interact/d9c3585ed9738fb03057685454989652|47.275|0.084|180.603|0.113|1.305|0.996|20.685|269.622|277.540|93.733|3.685|0.029|
|inventory/d0ad000b93bdbead0e42eae2e215a019|2.545|0.085|160.871|0.096|1.586|1.641|14.391|197.783|212.207|66.982|4.188|0.065|
|craft/1e6646927a994bfd18835dcf38d3a9a8|2.461|0.090|189.089|0.079|0.857|1.025|17.394|221.841|229.011|92.209|3.381|0.026|
|building_place/eecccb484d56624659c38f65103f2cf8|2.378|0.149|178.697|0.111|0.899|1.202|16.809|213.194|221.034|84.049|4.655|0.026|

发送前包含请求序列化和（拾取）移动确认。HTTP 收完到确认还包含 UTF-8 转换、调用衔接、UI/事件回调和等待下一次主循环；CSV 中未列的残差不能归为纯网络。服务器响应准备包含组件摘要比较、JSON 序列化与压缩；序列化子阶段另见原始 wire 日志。

## 同步附近帧与节点/界面更新

|阶段/客户端|同步附近帧 P50/P95/max|物理监控 P50/P95/max|库存 UI 回调 P50/P95/max|每次应用创建/待删根节点 max|碰撞对象创建 max（含子树）|超过50/100ms帧数|
|---|---|---|---|---|---|---|
|before-single-final/result0.json|49.14 / 60.14 / 64.08|未记录|0.00 / 1.30 / 11.18|37/36|未记录|70/0|
|after-single-entities/result0.json|31.34 / 40.92 / 44.53|1.36 / 4.62 / 14.78|0.00 / 1.22 / 13.03|9/9|9|22/0|
|before-double-final/result0.json|49.15 / 59.36 / 62.83|1.52 / 2.91 / 5.52|0.01 / 1.19 / 13.28|42/41|未记录|86/2|
|before-double-final/result1.json|49.02 / 61.78 / 123.85|1.31 / 5.41 / 13.99|0.01 / 1.42 / 13.16|42/42|未记录|85/3|
|after-double-entities/result0.json|31.17 / 42.70 / 44.90|1.60 / 4.53 / 13.65|0.00 / 1.29 / 11.56|10/10|10|19/1|
|after-double-entities/result1.json|34.18 / 42.57 / 47.01|2.55 / 5.35 / 15.13|0.00 / 1.47 / 12.44|10/10|10|20/1|
|before-single-ui/result0.json|46.42 / 64.65 / 78.29|1.82 / 7.42 / 13.92|0.00 / 5.77 / 12.03|39/38|未记录|66/8|
|after-single-ui/result0.json|30.83 / 54.65 / 57.62|3.87 / 12.45 / 14.94|0.00 / 5.69 / 15.11|39/38|未记录|38/4|

物理监控是引擎整帧统计，不能等同碰撞注册独占耗时；早期轮次只记录根节点类型，没有记录子树碰撞对象，表内按未记录处理；新一轮记录碰撞对象子树，数量不是注册独占耗时。没有把节点计数当作渲染流畅的证明。

## 一致性与恢复

见 consistency.json：逐客户端按成功数校验 branch=30+成功拾取+竞争获胜，wood=99−4×成功建造，broad_leaf=30−2×成功制作，plant_fiber=30+3×成功制作；两客户端建筑 ID 一致且总量=88+成功建造。每轮竞争只允许一个获胜。原生进程不调用 leave_lobby 直接结束，再用新进程登录、获取全量权威状态和实际绘制，核对库存/装备/建筑保留。协议单测另覆盖丢弃回复后基线恢复及旧客户端。并未模拟每一种半包断开或服务器崩溃。
