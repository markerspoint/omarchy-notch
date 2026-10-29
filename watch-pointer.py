#!/usr/bin/env python3
"""Report global pointer movement through Hyprland's local IPC socket."""
import json
import os
from pathlib import Path
import socket
import time


def main():
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'))
    signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
    if not signature:
        return
    path = runtime / 'hypr' / signature / '.socket.sock'
    previous = None
    try:
        while True:
            try:
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
                    connection.settimeout(0.5)
                    connection.connect(str(path))
                    connection.sendall(b'j/cursorpos')
                    chunks = []
                    while chunk := connection.recv(1024):
                        chunks.append(chunk)
                value = json.loads(b''.join(chunks))
                position = (int(value['x']), int(value['y']))
                if position != previous:
                    print(json.dumps({'x': position[0], 'y': position[1]}), flush=True)
                    previous = position
                time.sleep(0.12)
            except (OSError, ValueError, KeyError, TypeError):
                if previous is not None:
                    print('{"available": false}', flush=True)
                    previous = None
                time.sleep(1)
    except (BrokenPipeError, KeyboardInterrupt):
        pass


if __name__ == '__main__':
    main()
