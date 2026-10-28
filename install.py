#!/usr/bin/env python3
"""Install the user-owned notch without modifying packaged Omarchy files."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import sys

PROJECT = Path(__file__).resolve().parent
PLUGIN_ID = 'mark.notch'


def install(config_dir: Path, glass: bool = False):
    source = PROJECT / 'plugin' / PLUGIN_ID
    shell_path = config_dir / 'omarchy/shell.json'
    config = json.loads(shell_path.read_text()) if shell_path.exists() else {'version': 1}
    if not isinstance(config, dict):
        raise ValueError('shell.json must contain an object')
    plugins = config.setdefault('plugins', [])
    if not isinstance(plugins, list):
        raise ValueError('shell.json plugins must be an array')
    # Validate before writing or replacing anything.
    disabled = config.get('disabledPlugins', [])
    if not isinstance(disabled, list):
        raise ValueError('shell.json disabledPlugins must be an array')
    if not any((entry.get('id') if isinstance(entry, dict) else entry) == PLUGIN_ID for entry in plugins):
        plugins.append({'id': PLUGIN_ID})
    if PLUGIN_ID in disabled:
        config['disabledPlugins'] = [entry for entry in disabled if entry != PLUGIN_ID]

    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    backup = config_dir / 'omarchy/backups' / ('notch-' + stamp)
    backup.mkdir(parents=True)
    if shell_path.exists():
        shutil.copy2(shell_path, backup / 'shell.json')
    target = config_dir / 'omarchy/plugins' / PLUGIN_ID
    if target.exists():
        shutil.copytree(target, backup / PLUGIN_ID)
    # Overlay only project files, retaining any unrelated user additions.
    shutil.copytree(source, target, dirs_exist_ok=True, ignore=shutil.ignore_patterns('__pycache__'))
    shell_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = shell_path.with_name('shell.json.notch-tmp')
    temporary.write_text(json.dumps(config, indent=2) + '\n')
    temporary.replace(shell_path)

    if glass:
        lua_target = config_dir / 'hypr/notch.lua'
        look = config_dir / 'hypr/looknfeel.lua'
        for existing in (lua_target, look):
            if existing.exists():
                shutil.copy2(existing, backup / existing.name)
        lua_target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PROJECT / 'hypr/notch.lua', lua_target)
        content = look.read_text() if look.exists() else ''
        marker = '-- Omarchy Notch glass'
        if marker not in content:
            # Exact marker ensures repeat installs do not duplicate imports.
            content += '\n' + marker + '\nrequire("hypr.notch")\n'
            look.write_text(content)
    return target, backup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--glass', action='store_true', help='install Hyprland blur rules and load them from looknfeel.lua')
    parser.add_argument('--config-dir', type=Path, default=Path.home() / '.config', help='configuration root (default: ~/.config)')
    args = parser.parse_args()
    try:
        target, backup = install(args.config_dir.expanduser().resolve(), args.glass)
    except (OSError, ValueError) as error:
        parser.exit(1, f'Install failed: {error}\n')
    print(f'Installed: {target}\nBackup: {backup}')
    if args.glass:
        print('Apply and validate blur: hyprctl reload && hyprctl configerrors')
    print('Load the notch: omarchy restart shell')


if __name__ == '__main__':
    main()
