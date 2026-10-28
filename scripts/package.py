#!/usr/bin/env python3
"""Build a deterministic, installable release archive and its checksum."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from install import PLUGIN_FILES

RELEASE_FILES = (*PLUGIN_FILES, 'README.md', 'LICENSE', 'install.py', 'hypr/notch.lua')


def build(output: Path, tag=None):
    version = json.loads((ROOT / 'manifest.json').read_text())['version']
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?', version):
        raise ValueError('manifest.json must contain a semantic version')
    if tag is not None and tag != f'v{version}':
        raise ValueError(f'Tag must match manifest version: v{version}')
    for name in RELEASE_FILES:
        if not (ROOT / name).is_file():
            raise ValueError(f'Missing release file: {name}')
    output.mkdir(parents=True, exist_ok=True)
    prefix = f'omarchy-notch-{version}'
    archive = output / f'{prefix}.tar.gz'
    with archive.open('wb') as raw:
        with gzip.GzipFile(fileobj=raw, filename='', mode='wb', mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode='w') as tar:
                for name in sorted(RELEASE_FILES):
                    source = ROOT / name
                    info = tar.gettarinfo(str(source), arcname=f'{prefix}/{name}')
                    info.uid = info.gid = info.mtime = 0
                    info.uname = info.gname = ''
                    info.mode = 0o755 if source.stat().st_mode & 0o111 else 0o644
                    with source.open('rb') as content:
                        tar.addfile(info, content)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / 'SHA256SUMS').write_text(f'{digest}  {archive.name}\n')
    return archive


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist')
    parser.add_argument('--tag', help='require this release tag to match manifest.json')
    args = parser.parse_args()
    try:
        print(build(args.output, args.tag))
    except (ValueError, OSError) as error:
        parser.exit(1, f'Packaging failed: {error}\n')
