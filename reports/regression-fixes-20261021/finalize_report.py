"""Publish only completed, serial validation results; retain failed attempts."""
from pathlib import Path
import csv
import json

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent

def main():
    path=OUT/'results.json';rows=json.loads(path.read_text(encoding='utf-8'))
    # These two entries came from the briefly overlapping batch, and have been
    # superseded by the explicit serial-final run. Preserve them, do not use them.
    for row in rows:
        if row.get('evidence') in ['evidence\\0094','evidence\\0095'] and row['label'] in ['test_crafting_v1','test_broadleaf_v1']:
            row.setdefault('status_at_execution',row['status']);row['status']='incomplete'
            row['review']='Excluded overlapping native run; replaced by serial-final verification.'
    latest={row['label']:row for row in rows}
    assert all(row['status']=='pass' and not row['errors'] for row in latest.values()),[(k,r['status'],r['errors']) for k,r in latest.items() if r['status']!='pass' or r['errors']]
    path.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    with (OUT/'LATEST.csv').open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.writer(f);writer.writerow(['suite','status','exit','summary','evidence'])
        for name,row in sorted(latest.items()):writer.writerow([name,row['status'],row['exit'],' | '.join(row['summaries']),row.get('evidence','')])
    report=(OUT/'REPORT.md').read_text(encoding='utf-8')
    report=report.replace('状态：进行中，尚未全部通过。','完成更新：2026-10-22。本轮46个现行验收入口的最新串行结果全部通过，最新日志无脚本/资源占用错误；这不等于重新执行原137组全量回归。')
    start=report.index('制作212、');end=report.index('## 历史生态V0.3',start)
    report=report[:start]+'''各组最新数量、完成摘要及证据入口见 [LATEST.csv](LATEST.csv)。包括联机规则29、资源4252、采集205、矿石50、身体182、装备75、工业248等；不把失败重试相加作为通过率。

V3分布此前缺口两组18项与本轮前四组36项完成，六组均有对应证据。前四组一次仅输出两份样本便退出，已保留并改判未完成；随后重跑获得最终完成标记，不以退出码0冒充通过。

早期重试沿用的四份旧脚本含多尺寸循环，最终已收敛为读取项目默认1280×720，并串行复测。期间两组原生测试短暂重叠，已保留 `overlap-results-unreliable.json` 且不采纳重叠结果；受影响组完整串行重跑，入口互斥检查亦已验证。

''' +report[end:]
    report=report.replace('默认窗口1280×720，测试在独立项目及用户目录进行；','最终验收窗口1280×720，测试在独立项目及用户目录进行；')
    report=report.replace('无自动提交或推送。','2026-10-22按用户明确要求提交并推送源码、测试及文字报告；不含私有配置、账号、证书、玩家档、缓存或临时媒体。另一台电脑仍须在那里执行独立配置，不能据此称已远程配置成功。')
    (OUT/'REPORT.md').write_text(report,encoding='utf-8')
    status=ROOT/'PROJECT_STATUS.md';text=status.read_text(encoding='utf-8').replace('更新：2026-10-21。','更新：2026-10-22。',1)
    marker='## 当前进度\n\n'
    text=text.replace(marker,marker+'- 2026-10-22 未通过项定向修复完成：工具耐久类型、临时服务节点释放、候选纹理资源读取及近距离射线修复；旧配方/数量/计时与测试前置按现行规范更新。46个本轮验收入口最新串行结果通过，联机规则29项通过；旧生态V0.3作为过期历史脚本单列，不冒称137组重跑全绿。20份玩家文件和独立服务器数据未变；按用户要求提交推送。详见[修复报告](reports/regression-fixes-20261021/REPORT.md)。\n\n',1)
    text=text.replace('仍非全量通过，详见[本设备报告]','该条为修复前阶段记录，后续结论见上方修复报告；阶段详情见[本设备报告]',1).replace('未提交推送。','后续修复按2026-10-22用户要求提交推送。',1)
    status.write_text(text,encoding='utf-8')
    with (ROOT/'DEVLOG.md').open('a',encoding='utf-8') as f:
        f.write('''\n## 2026-10-22 · 未通过项修复与用户授权推送

沿上一轮本设备补测继续修复。工具创建耐久统一整数；临时ItemService拥有商人子节点，避免后台分布服务释放后节点残留；候选贴图识别res/tres资源；交互射线按角色RID排除自身，避免12单位距离产生零长度物理射线。旧物品/配方数、稳定石料奖励、单击阔叶、当前料理/工业队列、正常睡眠时间、数量确认和界面反馈均按当前规范修订测试；原始失败证据保留。

Godot4.7.2/Compatibility/RTX5060，最终默认1280×720；46个现行验收入口最新串行记录均通过且无脚本/资源占用错误，详见修复报告与LATEST.csv。联机规则29项、六组V3分布覆盖、资源4252/采集205、身体182、装备75、工业248等通过。旧生态V0.3固定树ID/三地貌/旧全景地图用例单列为过期历史，未伪称重新通过；不是原137组全量重跑。早期遗留多尺寸循环已改默认尺寸；一次短暂并行测试不采纳并已串行重跑，新增入口互斥防护。

20份真实玩家文件集合/内容及本机独立服务器逻辑数据保持；隔夜停止的本机独立服务已使用原数据重启并验证TLS端点，未初始化覆盖。另一台电脑不可访问，仍需拉取后执行独立配置；本地新源码补丁包仅包含源码及工具，原包保留。未测长期人工平衡、16人/异机公网或新完整发行包。本轮依用户明确要求提交推送，私有配置/账号/证书/存档和临时媒体不进入Git。见[修复报告](reports/regression-fixes-20261021/REPORT.md)。
''')
    print('Finalized',len(latest),'passing validation entries.')

if __name__=='__main__':main()
