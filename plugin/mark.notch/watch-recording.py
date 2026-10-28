#!/usr/bin/python
"""Observe the recorder without starting, stopping, or signaling it."""
import json
from pathlib import Path
import os
import time


def recording_state(proc=Path('/proc')):
    now = float((proc / 'uptime').read_text().split()[0])
    ticks = os.sysconf('SC_CLK_TCK')
    matches = []
    for entry in proc.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            args = (entry / 'cmdline').read_bytes().split(b'\0')
            if not args[0] or Path(os.fsdecode(args[0])).name != 'gpu-screen-recorder':
                continue
            fields = (entry / 'stat').read_text().rsplit(') ', 1)[1].split()
            start = int(fields[19]) / ticks
            matches.append((start, int(entry.name)))
        except (OSError, ValueError, IndexError):
            continue  # Process may exit between directory listing and reading.
    if not matches:
        return {'recording': False, 'seconds': 0, 'pid': 0}
    start, pid = min(matches)
    return {'recording': True, 'seconds': max(0, int(now - start)), 'pid': pid}


if __name__ == '__main__':
    try:
        while True:
            state = recording_state()
            directory = Path.home() / '.local/state/omarchy'
            state['stay_awake'] = (directory / 'indicators/stay-awake').exists()
            try:
                state['dnd'] = json.loads((directory / 'notifications.json').read_text()).get('dnd', False) is True
            except (OSError, ValueError):
                pass
            print(json.dumps(state), flush=True)
            time.sleep(1)
    except (BrokenPipeError, KeyboardInterrupt):
        pass
