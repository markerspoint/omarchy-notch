import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('installer', ROOT / 'install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.config = Path(self.temp.name)
        self.shell = self.config / 'omarchy/shell.json'
        self.shell.parent.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def test_preserves_settings_and_backs_up_existing_plugin(self):
        config = {'version': 1, 'bar': {'transparent': True}, 'plugins': [{'id': 'other.plugin'}],
                  'disabledPlugins': ['mark.notch', 'another.plugin']}
        self.shell.write_text(json.dumps(config))
        old = self.config / 'omarchy/plugins/mark.notch'
        old.mkdir(parents=True)
        (old / 'Notch.qml').write_text('old plugin')
        target, backup = installer.install(self.config)
        updated = json.loads(self.shell.read_text())
        self.assertEqual(updated['bar'], config['bar'])
        self.assertEqual(updated['plugins'], [{'id': 'other.plugin'}, {'id': 'mark.notch'}])
        self.assertEqual(updated['disabledPlugins'], ['another.plugin'])
        self.assertEqual((backup / 'mark.notch/Notch.qml').read_text(), 'old plugin')
        self.assertEqual(json.loads((backup / 'shell.json').read_text()), config)
        self.assertTrue((target / 'ActivityPane.qml').is_file())
        self.assertNotIn('plugins', backup.parts)

    def test_reinstall_does_not_duplicate_plugin_or_glass_import(self):
        self.shell.write_text('{"version": 1, "plugins": []}')
        installer.install(self.config, glass=True)
        installer.install(self.config, glass=True)
        updated = json.loads(self.shell.read_text())
        self.assertEqual(updated['plugins'], [{'id': 'mark.notch'}])
        look = (self.config / 'hypr/looknfeel.lua').read_text()
        self.assertEqual(look.count('require("hypr.notch")'), 1)
        self.assertTrue((self.config / 'hypr/notch.lua').is_file())

    def test_invalid_config_is_rejected_before_mutation(self):
        self.shell.write_text('{"plugins": "not an array"}')
        original = self.shell.read_bytes()
        with self.assertRaises(ValueError):
            installer.install(self.config)
        self.assertEqual(self.shell.read_bytes(), original)
        self.assertFalse((self.config / 'omarchy/plugins').exists())

    def test_install_without_existing_shell_config(self):
        target, _ = installer.install(self.config)
        self.assertTrue((target / 'manifest.json').exists())
        self.assertEqual(json.loads(self.shell.read_text())['plugins'], [{'id': 'mark.notch'}])


if __name__ == '__main__':
    unittest.main()
