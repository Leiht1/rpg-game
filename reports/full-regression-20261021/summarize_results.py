"""Build a durable, per-suite index without counting retries as new coverage."""
from pathlib import Path
from collections import Counter
import csv
import json
import re

OUT = Path(__file__).resolve().parent


def main():
    attempts = json.loads((OUT / "results.json").read_text(encoding="utf-8"))
    latest = {row["label"]: row for row in attempts}
    rows = []
    for label, result in latest.items():
        errors = [e for e in result["errors"] if "still in use at exit" not in e]
        status = result["status"]
        if label == "audio-workbench":
            status = "blocked-dependencies"
        elif result["exit"] in ("timeout", "script_error_stall"):
            status = "incomplete"
        counts = [r["checks"] for r in result["reports"]]
        failures = [f for r in result["reports"] for f in r["failures"]]
        rows.append({"suite": label, "category": result["category"], "status": status,
                     "seconds": result["seconds"], "exit": result["exit"],
                     "recorded_checks": sum(counts) if counts else "",
                     "failed_assertions": len(failures) if counts else "",
                     "details": " | ".join(failures or errors),
                     "log": result["log"],
                     "reports": " | ".join(r["source"] for r in result["reports"]),
                     "attempts": sum(r["label"] == label for r in attempts)})
    with (OUT / "suites.csv").open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    states = Counter(row["status"] for row in rows)
    summary = {"unique_suites": len(rows), "attempts": len(attempts),
               "statuses": dict(states),
               "categories": dict(Counter(row["category"] for row in rows)),
               "latest_seconds": round(sum(r["seconds"] for r in rows), 2),
               "all_attempt_seconds": round(sum(r["seconds"] for r in attempts), 2),
               "structured_assertions_recorded": sum(r["recorded_checks"] or 0 for r in rows),
               "structured_assertions_failed": sum(r["failed_assertions"] or 0 for r in rows),
               "note": "Structured counts omit scripts with other report formats; incomplete suites are not passes. Counts include distinct suite phases, not retries."}
    (OUT / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = ["# 本轮逐组测试结果", "", "同名重试仅展示最后一次结果；全部尝试保留在 results.json。不同重启阶段分别计组。", "",
             "pass 表示该组断言/退出结果通过，仍需查看报告中的资源清理和延迟回调诊断。incomplete 表示超时或脚本中止；未执行部分不算通过。", "",
             "| 测试组 | 结果 | 秒 | 已记录断言/失败 | 失败或诊断摘要 |", "|---|---|---:|---:|---|"]
    for row in rows:
        count = "—" if row["recorded_checks"] == "" else f"{row['recorded_checks']}/{row['failed_assertions']}"
        detail = row["details"].replace("|", ";").replace("\n", " ")
        if len(detail) > 500:
            detail = detail[:500] + "…（完整内容见 results.json / suites.csv）"
        lines.append(f"| {row['suite']} | {row['status']} | {row['seconds']} | {count} | {detail or '—'} |")
    lines += ["", "完整失败断言、报告位置、重试次数与原始日志相对路径见 suites.csv。日志和截图按项目规则仅本地临时保留。", ""]
    (OUT / "SUITES.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
