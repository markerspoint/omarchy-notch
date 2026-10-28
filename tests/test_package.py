import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('packager', ROOT / 'scripts/package.py')
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)


class PackageTests(unittest.TestCase):
    def test_archive_is_reproducible_and_installs(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            first = packager.build(base / 'one')
            second = packager.build(base / 'two')
            self.assertEqual(first.read_bytes(), second.read_bytes())
            checksum = (first.parent / 'SHA256SUMS').read_text().split()[0]
            self.assertEqual(checksum, hashlib.sha256(first.read_bytes()).hexdigest())
            extracted = base / 'extracted'
            with tarfile.open(first) as archive:
                members = archive.getnames()
                prefix = first.name.removesuffix('.tar.gz')
                self.assertEqual(set(members), {f'{prefix}/{name}' for name in packager.RELEASE_FILES})
                archive.extractall(extracted, filter='data')
            config = base / 'config'
            subprocess.run([sys.executable, str(extracted / prefix / 'install.py'),
                            '--config-dir', str(config), '--glass'], check=True, capture_output=True)
            manifest = json.loads((config / 'omarchy/plugins/mark.notch/manifest.json').read_text())
            self.assertEqual(manifest['id'], 'mark.notch')
            self.assertTrue((config / 'hypr/notch.lua').is_file())

    def test_release_tag_must_match_manifest(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaises(ValueError):
                packager.build(Path(temp), 'v999.0.0')
