#!/usr/bin/env python3
"""Fail if a screen-door box has no window service, or doors.json disagrees with templates."""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOORS = ROOT / "share" / "doors.json"
TEMPLATES = ROOT / "templates"


def main():
    policy = json.loads(DOORS.read_text(encoding="utf-8"))
    errors = []
    for name, box in policy["boxes"].items():
        template = TEMPLATES / box["template"]
        if not template.exists():
            errors.append(f"{name}: missing template {template}")
            continue
        text = template.read_text(encoding="utf-8")
        wants_window = bool(box.get("window")) or ("screen" in box.get("doors", []))
        service = box.get("service", "")
        if wants_window:
            if "screen" not in box.get("doors", []):
                errors.append(f"{name}: window=true but no screen door")
            if not service.startswith("floor-"):
                errors.append(f"{name}: window box needs service floor-* in doors.json")
            if f"systemd.services.{service}" not in text and f'systemd.services."{service}"' not in text:
                # allow floor-name with attribute path
                if not re.search(rf"systemd\.services\.{re.escape(service)}\s*=", text):
                    errors.append(f"{name}: template {template.name} has no systemd.services.{service}")
            if "WAYLAND_DISPLAY" not in text:
                errors.append(f"{name}: template missing WAYLAND_DISPLAY for a window box")
            if "/run/floor-wayland" not in text:
                errors.append(f"{name}: template missing XDG_RUNTIME_DIR=/run/floor-wayland")
            if "common-nspawn.nix" not in text and "wayland-app.nix" not in text:
                if "system.nssModules" not in text:
                    errors.append(f"{name}: template should import wayland-app.nix or set nssModules")
        else:
            if "screen" in box.get("doors", []):
                errors.append(f"{name}: has screen door but window=false")
            if service.startswith("floor-"):
                errors.append(f"{name}: background box should not use a floor-* window service name")

        # imports for shared fragments must exist
        for fragment in ("common-nspawn.nix", "wayland-app.nix"):
            if fragment in text and not (TEMPLATES / fragment).exists():
                errors.append(f"{name}: imports {fragment} but file is missing")

    if errors:
        print("Template check failed:")
        for err in errors:
            print(f"  - {err}")
        return 1
    print("Template check passed for", len(policy["boxes"]), "boxes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
