#!/usr/bin/env python3
"""The floor listens here. The screen box asks to start and stop boxes, or shut down."""

import json
import os
import socket
import subprocess
import sys
from pathlib import Path

SOCK = Path("/run/floor-boxes/door/door.sock")
SPIN = Path("/etc/floor-boxes/spin.py")
DOORS = Path("/etc/floor-boxes/doors.json")


def reply(conn, text):
    if not text.endswith("\n"):
        text += "\n"
    conn.sendall(text.encode())


def running_boxes(policy):
    names = []
    for name in policy.get("boxes", {}):
        completed = subprocess.run(
            ["/run/current-system/sw/bin/systemctl", "is-active", f"container@{name}"],
            text=True,
            capture_output=True,
        )
        if completed.returncode == 0 and completed.stdout.strip() == "active":
            names.append(name)
    return names


def handle(conn):
    with conn:
        line = conn.makefile("r", encoding="utf-8").readline().strip()
        parts = line.split()
        if len(parts) == 1 and parts[0] == "shutdown":
            reply(conn, "Shutting down the floor.")
            subprocess.Popen(
                ["/run/current-system/sw/bin/systemctl", "poweroff"],
                start_new_session=True,
            )
            return
        if len(parts) == 1 and parts[0] == "list":
            try:
                policy = json.loads(DOORS.read_text(encoding="utf-8"))
            except OSError as err:
                reply(conn, json.dumps({"error": str(err), "running": []}))
                return
            reply(conn, json.dumps({"running": running_boxes(policy)}))
            return
        if len(parts) != 2 or parts[0] not in ("start", "stop"):
            reply(conn, "Use start or stop BOX, list, or shutdown.")
            return
        action, name = parts
        try:
            policy = json.loads(DOORS.read_text(encoding="utf-8"))
        except OSError as err:
            reply(conn, f"The floor could not read the door list: {err}")
            return
        if name == "screen" or name not in policy.get("boxes", {}):
            reply(conn, "The floor does not start that box from the window.")
            return
        env = os.environ.copy()
        env["FLOOR_BOX_APPLY"] = "1"
        env["PATH"] = "/run/current-system/sw/bin:/run/wrappers/bin:" + env.get("PATH", "")
        completed = subprocess.run(
            [sys.executable, str(SPIN), action, name],
            text=True,
            capture_output=True,
            env=env,
        )
        text = (completed.stdout or "") + (completed.stderr or "")
        text = text.rstrip()
        if completed.returncode == 0:
            end = "Started." if action == "start" else "Stopped."
            text = (text + "\n" if text else "") + f"{end} {name}."
        elif not text:
            text = f"Could not {action} {name}."
        reply(conn, text)


def main():
    SOCK.parent.mkdir(parents=True, exist_ok=True)
    if SOCK.exists():
        SOCK.unlink()
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(SOCK))
    os.chmod(SOCK, 0o666)
    server.listen(4)
    while True:
        conn, _addr = server.accept()
        handle(conn)


if __name__ == "__main__":
    main()
