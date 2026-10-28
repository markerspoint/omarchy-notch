import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('recording', ROOT / 'plugin/mark.notch/watch-recording.py')
recording = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recording)


class RecordingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.proc = Path(self.temp.name)
        (self.proc / 'uptime').write_text('120.00 100.00')

    def tearDown(self):
        self.temp.cleanup()

    def process(self, pid, executable, started):
        entry = self.proc / str(pid)
        entry.mkdir()
        (entry / 'cmdline').write_bytes(executable.encode() + b'\0-w\0screen\0')
        fields = ['0'] * 20
        fields[19] = str(started * os.sysconf('SC_CLK_TCK'))
        (entry / 'stat').write_text(f'{pid} (recorder with spaces) ' + ' '.join(fields))

    def test_idle(self):
        self.assertEqual(recording.recording_state(self.proc), {'recording': False, 'seconds': 0, 'pid': 0})

    def test_real_process_name_and_elapsed_time(self):
        self.process(100, '/usr/bin/gpu-screen-recorder', 90)
        self.assertEqual(recording.recording_state(self.proc), {'recording': True, 'seconds': 30, 'pid': 100})

    def test_multiple_recorders_selects_oldest(self):
        self.process(100, 'gpu-screen-recorder', 90)
        self.process(200, '/usr/bin/gpu-screen-recorder', 110)
        self.assertEqual(recording.recording_state(self.proc)['pid'], 100)

    def test_unrelated_and_exiting_processes(self):
        self.process(100, '/usr/bin/not-gpu-screen-recorder', 90)
        self.process(200, 'gpu-screen-recorder', 110)
        (self.proc / '200/cmdline').unlink()
        self.assertFalse(recording.recording_state(self.proc)['recording'])


if __name__ == '__main__':
    unittest.main()
