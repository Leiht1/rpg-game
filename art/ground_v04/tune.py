from pathlib import Path
p=Path('scripts/terrain.gdshader');s=p.read_text().replace('vec3 blocks=floor(field.rgb*18.0+0.5)/18.0;','vec3 blocks=field.rgb;');p.write_text(s)
p=Path('scripts/ground_candidate.gd');s=p.read_text().replace('if r<.14:','if r<.045:').replace('"w":100+r*130','"w":65+r*130').replace('"w":(55 if prop.kind<2 else 65)','"w":(38 if prop.kind<2 else 48)');p.write_text(s)
p=Path('tests/test_ground_v04.gd');s=p.read_text('utf-8-sig').replace('w.stream.set_candidate(mode)','w.stream.set_candidate(mode)\n\t\tw.update_comparison()');p.write_text(s,encoding='utf-8')
