from pathlib import Path
p=Path('scripts/ground_candidate.gd');s=p.read_text().replace('if r<.045:', 'if r<.045 and preload("res://scripts/ground_decals.gd").dry_footprint(g,p,75):');p.write_text(s)
