"""Package the complete Godot source project without generated import caches."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "dist" / "风栖原野-V0.1.zip"
SKIP = {".godot", ".git", "__pycache__", "dist"}


def main():
    OUT.parent.mkdir(exist_ok=True)
    files = sorted(p for p in ROOT.rglob("*") if p.is_file()
                   and not any(x in SKIP for x in p.relative_to(ROOT).parts)
                   and not p.name.endswith(".tmp"))
    with zipfile.ZipFile(OUT, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p in files:
            z.write(p, "风栖原野-V0.1/" + p.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(OUT) as z:
        assert z.testzip() is None
        names = {n.split("/", 1)[1] for n in z.namelist()}
        for required in ("project.godot", "scenes/world.tscn", "ART_STYLE.md",
                         "AGENTS.md", "DEVLOG.md", "README.md", "assets/hero/animation/hero.tres",
                         "CHARACTER_MODULAR_RULES.md",
                         "reports/VALIDATION.md", "art/ASSET_MANIFEST.md"):
            assert required in names, required
        assert len(names) == len(files)
    report = {"file": OUT.name, "files": len(files), "bytes": OUT.stat().st_size,
              "sha256": hashlib.sha256(OUT.read_bytes()).hexdigest(),
              "archive_crc_check": "pass", "required_files": "pass"}
    (OUT.parent / "package.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=True))


if __name__ == "__main__":
    main()
