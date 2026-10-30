import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which('bash')


class AudioTests(unittest.TestCase):
    def run_audio(self, bin_dir, config):
        return subprocess.run(
            [BASH, str(ROOT / 'watch-audio.sh'), str(config)],
            env={**os.environ, 'PATH': str(bin_dir)},
            capture_output=True, text=True, timeout=5,
        )

    def test_without_cava_exits_quietly(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_audio(Path(directory), ROOT / 'cava.conf')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')
        self.assertEqual(result.stderr, '')

    def test_cava_receives_config_path_and_streams_output(self):
        with tempfile.TemporaryDirectory() as directory:
            bin_dir = Path(directory)
            config = bin_dir / 'config with spaces.conf'
            cava = bin_dir / 'cava'
            cava.write_text(
                '#!/bin/bash\n'
                '[[ $# == 2 && $1 == -p && $2 == "$EXPECTED_CONFIG" ]] || exit 42\n'
                'printf "10;20;30;\\n"\n'
            )
            cava.chmod(0o755)
            result = subprocess.run(
                [BASH, str(ROOT / 'watch-audio.sh'), str(config)],
                env={**os.environ, 'PATH': str(bin_dir), 'EXPECTED_CONFIG': str(config)},
                capture_output=True, text=True, timeout=5,
            )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '10;20;30;\n')
        self.assertEqual(result.stderr, '')


if __name__ == '__main__':
    unittest.main()
