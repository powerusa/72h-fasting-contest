"""Validate exact PNG dimensions and absence of alpha; uses the Python standard library."""
from pathlib import Path
import hashlib
import json
import struct

root = Path(__file__).resolve().parents[1]
creative = {
    'header-3840x1646.png': (3840, 1646),
    'universal-header-search-5244x2950.png': (5244, 2950),
    'search-results-3840x2560.png': (3840, 2560),
}
allowed_screenshots = {
    'iphone': {(1206, 2622)},
    'ipad': {(2064, 2752)},
    'duo': {(2007, 2853), (2853, 2007), (1398, 2034)},
}

def check(file, sizes):
    data = file.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', file
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    assert (width, height) in sizes, (file, width, height)
    assert depth == 8 and color == 2, f'{file}: expected 8-bit RGB without alpha, got {depth}/{color}'
    offset = 8
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        assert kind != b'tRNS', f'{file}: contains transparency'
        offset += length + 12
    print(f'PASS {file.relative_to(root)}: {width} × {height}, no alpha')
    return width, height, hashlib.sha256(data).hexdigest()

for name, size in creative.items():
    check(root / 'docs/app-store' / name, {size})
manifest = []
for file in sorted((root / 'docs/screenshots').rglob('*.png')):
    width, height, digest = check(file, allowed_screenshots[file.parent.name])
    manifest.append(dict(file=str(file.relative_to(root / 'docs/screenshots')), width=width, height=height, sha256=digest))
assert len(manifest) == 15, f'Expected 15 device captures, found {len(manifest)}'
(root / 'docs/screenshots/manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
large = list((root / 'docs/app-store/screenshots/iphone-large').glob('*.png'))
assert len(large) == 4
for file in sorted(large):
    check(file, {(1320, 2868)})
print('PASS: 3 creative assets, 15 native screenshots, 4 large-iPhone exports')
