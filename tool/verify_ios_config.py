"""Fail if the built iOS app does not contain the configured Supabase host.

Dart const strings from --dart-define live in the AOT snapshot. The snapshot
layout is not guaranteed, so search every file in the bundle for both Latin-1
and UTF-16LE encodings. The anon key is never printed.
"""
import json
import sys
from pathlib import Path
from urllib.parse import urlparse

DEFINES = Path('build/codemagic/flutter-defines.json')
APP = Path('build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app')


def main():
    host = urlparse(json.loads(DEFINES.read_text(encoding='utf-8'))['SUPABASE_URL']).hostname
    if not host:
        raise SystemExit('SUPABASE_URL has no host')
    needles = {'latin-1': host.encode('latin-1'), 'utf-16le': host.encode('utf-16-le')}
    if not APP.is_dir():
        raise SystemExit(f'Built app not found: {APP}')
    files = [path for path in APP.rglob('*') if path.is_file()]
    for path in files:
        data = path.read_bytes()
        for encoding, needle in needles.items():
            if needle in data:
                print(f'Supabase host ({host}) found in {path.relative_to(APP)} as {encoding}')
                return
    print(f'Supabase host ({host}) not found in {len(files)} files. Largest files:')
    for path in sorted(files, key=lambda item: item.stat().st_size, reverse=True)[:8]:
        print(f'  {path.stat().st_size:>12}  {path.relative_to(APP)}')
    sys.exit(1)


if __name__ == '__main__':
    main()
