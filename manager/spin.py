#!/usr/bin/env python3
"""Start or stop a template box. This never rebuilds NixOS."""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# When installed as /etc/floor-boxes/spin.py, parents[1] is /etc. Prefer the etc tree.
if (Path("/etc/floor-boxes") / "templates").is_dir():
    ROOT = Path("/etc/floor-boxes")
CONF_DIR = Path("/etc/nixos-containers")
ACTIVE_DOORS = Path("/etc/floor-boxes/doors.json")
SOURCE_DOORS = Path("/etc/floor-boxes/doors.json")
if not SOURCE_DOORS.exists():
    SOURCE_DOORS = ROOT / "share" / "doors.json"
KNOWN_DOORS = ("screen", "sound", "print", "network")


def load_policy(path):
    chosen = Path(path) if path else (ACTIVE_DOORS if ACTIVE_DOORS.exists() else SOURCE_DOORS)
    with chosen.open(encoding="utf-8") as handle:
        return json.load(handle), chosen


def template_for(policy, name):
    box = policy["boxes"][name]
    template = Path("/etc/floor-boxes/templates") / box["template"]
    if not template.exists():
        template = ROOT / "templates" / box["template"]
    return template


def box_flags(policy, name):
    box = policy["boxes"][name]
    flags = ["--bind-ro=/etc/floor-boxes/doors.json:/etc/floor-doors.json"]
    if box.get("owns") == "speakers":
        flags.append("--bind=/dev/snd:/dev/snd")
    if box.get("owns") == "printer":
        flags.append("--bind=/dev/bus/usb:/dev/bus/usb")
    if box.get("owns") == "files":
        flags.append("--bind=/var/lib/floor-boxes/files:/srv/files")
    if "screen" in box.get("doors", []):
        flags.append("--bind=/run/floor-boxes/wayland:/run/floor-wayland")
    return flags


def write_flags(name, flags):
    conf = CONF_DIR / f"{name}.conf"
    lines = []
    if conf.exists():
        for line in conf.read_text(encoding="utf-8").splitlines():
            if not line.startswith("EXTRA_NSPAWN_FLAGS="):
                lines.append(line)
    lines.append("EXTRA_NSPAWN_FLAGS=" + " ".join(flags))
    conf.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run(cmd):
    if os.environ.get("FLOOR_BOX_APPLY") != "1" or shutil.which("nixos-container") is None:
        print("Not run. Set FLOOR_BOX_APPLY=1 on the spare computer to run it.")
        print(" ".join(cmd))
        return 0
    completed = subprocess.run(cmd, text=True, capture_output=True)
    if completed.stdout:
        print(completed.stdout, end="" if completed.stdout.endswith("\n") else "\n")
    if completed.stderr:
        print(completed.stderr, end="" if completed.stderr.endswith("\n") else "\n")
    return completed.returncode


def container_active(name):
    if os.environ.get("FLOOR_BOX_APPLY") != "1" or shutil.which("systemctl") is None:
        return False
    completed = subprocess.run(
        ["systemctl", "is-active", f"container@{name}"],
        text=True,
        capture_output=True,
    )
    return completed.returncode == 0 and completed.stdout.strip() == "active"


def create(policy, name):
    box = policy["boxes"][name]
    template = template_for(policy, name)
    address = box["address"]
    return run([
        "nixos-container", "create", name,
        "--config-file", str(template),
        "--host-address", address["host"],
        "--local-address", address["local"],
    ])


def update(policy, name):
    template = template_for(policy, name)
    return run([
        "nixos-container", "update", name,
        "--config-file", str(template),
    ])


def start(policy, name):
    if name == "screen":
        print("The screen box stays in /etc/nixos. Starting it is a rebuild, not a spin-up.")
        return 1
    if name not in policy["boxes"]:
        print(f"Unknown box: {name}")
        return 1
    unknown = [door for door in policy["boxes"][name].get("doors", []) if door not in KNOWN_DOORS]
    if unknown:
        print("Blocked. Unknown door: " + ", ".join(unknown))
        return 1
    conf = CONF_DIR / f"{name}.conf"
    if conf.exists():
        # The box was built with the floor. Start it again. Do not rebuild it.
        if os.access(conf, os.W_OK):
            write_flags(name, box_flags(policy, name))
    else:
        code = create(policy, name)
        if code != 0:
            return code
        print("Doors for this start: " + " ".join(box_flags(policy, name)))
    # Restart when already up so a new template service (like Firefox) actually runs.
    if container_active(name):
        code = run(["nixos-container", "stop", name])
        if code != 0:
            return code
    code = run(["nixos-container", "start", name])
    if code == 0:
        box = policy["boxes"][name]
        shows = box.get("window")
        if shows is None:
            shows = "screen" in box.get("doors", [])
        if shows:
            service = box.get("service", f"floor-{name}")
            print(f"Window box. Inside the container, service {service} should open on the screen door.")
        else:
            print("Background box. No window — this box has no screen door.")
    return code


def stop(name):
    if name == "screen":
        print("The screen box stays in /etc/nixos. This command does not stop it.")
        return 1
    return run(["nixos-container", "stop", name])


def main(argv):
    if len(argv) < 3:
        print("Usage: spin.py start|stop BOX [doors.json]")
        return 1
    action, name = argv[1], argv[2]
    policy, chosen = load_policy(argv[3] if len(argv) > 3 else None)
    print(f"Using door list {chosen}")
    if action == "start":
        return start(policy, name)
    if action == "stop":
        return stop(name)
    print("Use start or stop.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
