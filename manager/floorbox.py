#!/usr/bin/env python3
"""Window for the boxes. Starting a box does not rebuild NixOS."""

import json
import os
import shutil
import socket
import subprocess
import sys
import threading
import tkinter as tk
from pathlib import Path
from tkinter import messagebox

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DOORS = ROOT / "share" / "doors.json"
ACTIVE_DOORS = Path("/etc/floor-boxes/doors.json")
SPIN = Path(__file__).with_name("spin.py")
FLOOR_DOOR = Path("/run/floor-boxes/door/door.sock")
DOOR_CHOICES = ("screen", "sound", "print", "network")

# How to find each box's window on the shared Wayland screen.
# wlrctl: same attribute listed twice means "match any of these values".
WINDOW_FOCUS = {
    "files": ["app_id:pcmanfm", "app_id:floor-files", "title:pcmanfm"],
    "firefox": ["app_id:firefox", "app_id:floor-firefox", "title:Firefox"],
    "mail": ["app_id:thunderbird", "app_id:floor-mail", "title:Thunderbird"],
    "photos": ["app_id:imv", "app_id:floor-photos", "title:imv"],
}


def read_json(path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def ask_floor(line, timeout=1800):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(timeout)
        client.connect(str(FLOOR_DOOR))
        client.sendall((line + "\n").encode())
        client.shutdown(socket.SHUT_WR)
        chunks = []
        while True:
            piece = client.recv(4096)
            if not piece:
                break
            chunks.append(piece)
    return b"".join(chunks).decode(errors="replace").rstrip()


class FloorWindow(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Boxes")
        self.active_path = ACTIVE_DOORS if ACTIVE_DOORS.exists() else SOURCE_DOORS
        self.active = read_json(self.active_path)
        self.pending = json.loads(json.dumps(self.active))
        self.checks = {}
        self.log = None
        self.tab_bar = None
        self.tab_buttons = {}
        self.running = []
        self._build()
        self.after(500, self.refresh_tabs)
        self.after(2000, self._poll_tabs)

    def _build(self):
        # Home + open-box tabs stay at the top so you can switch while several boxes run.
        self.tab_bar = tk.Frame(self, bg="#1e1e1e")
        self.tab_bar.pack(fill="x", side="top")
        tk.Button(
            self.tab_bar,
            text="Home",
            command=self.go_home,
            padx=10,
            pady=4,
        ).pack(side="left", padx=(8, 4), pady=6)
        self.tabs_frame = tk.Frame(self.tab_bar, bg="#1e1e1e")
        self.tabs_frame.pack(side="left", fill="x", expand=True)

        tk.Label(
            self,
            text="The screen stays in the floor. The other boxes spin up from here.",
            wraplength=520,
            justify="left",
        ).pack(anchor="w", padx=12, pady=(12, 4))
        tk.Label(
            self,
            text="Starting a box does not rebuild NixOS. Saving a door change does. "
            "Use Home and the tabs above to switch between open box windows.",
            wraplength=520,
            justify="left",
        ).pack(anchor="w", padx=12, pady=(0, 8))

        body = tk.Frame(self)
        body.pack(fill="both", expand=True, padx=12)

        names = tk.Frame(body)
        names.pack(side="left", fill="y")
        tk.Label(names, text="Screen", anchor="w").pack(fill="x")
        tk.Label(names, text="Part of /etc/nixos", anchor="w").pack(fill="x", pady=(0, 8))
        for name in self.pending["boxes"]:
            row = tk.Frame(names)
            row.pack(fill="x", pady=2)
            kind = "window" if self.box_shows_window(name) else "background"
            tk.Label(row, text=f"{name}", width=10, anchor="w").pack(side="left")
            tk.Label(row, text=kind, width=10, anchor="w", fg="#666666").pack(side="left")
            tk.Button(row, text="Start", command=lambda n=name: self.spin("start", n)).pack(side="left")
            tk.Button(row, text="Stop", command=lambda n=name: self.spin("stop", n)).pack(side="left")

        doors = tk.Frame(body)
        doors.pack(side="left", fill="both", expand=True, padx=(16, 0))
        tk.Label(doors, text="Doors", anchor="w").pack(fill="x")
        for name, box in self.pending["boxes"].items():
            line = tk.Frame(doors)
            line.pack(fill="x", pady=2)
            tk.Label(line, text=name, width=10, anchor="w").pack(side="left")
            self.checks[name] = {}
            current = set(box.get("doors", []))
            for door in DOOR_CHOICES:
                var = tk.BooleanVar(value=door in current)
                self.checks[name][door] = var
                tk.Checkbutton(line, text=door, variable=var).pack(side="left")

        actions = tk.Frame(self)
        actions.pack(anchor="w", padx=12, pady=8, fill="x")
        tk.Button(actions, text="Save door changes for a rebuild", command=self.save_doors).pack(
            side="left"
        )
        tk.Button(actions, text="Shut down floor", command=self.shutdown_floor).pack(
            side="left", padx=(12, 0)
        )

        self.log = tk.Text(self, height=10, width=72)
        self.log.pack(fill="both", expand=True, padx=12, pady=(0, 12))
        self.write(f"Active door list: {self.active_path}")

    def write(self, text):
        self.log.insert("end", text + "\n")
        self.log.see("end")

    def box_shows_window(self, name):
        box = self.pending["boxes"].get(name, {})
        if "window" in box:
            return bool(box["window"])
        return "screen" in box.get("doors", [])

    def gui_boxes(self):
        """Boxes that open a window on the screen door."""
        return [name for name in self.pending["boxes"] if self.box_shows_window(name)]

    def refresh_tabs(self):
        running = []
        if FLOOR_DOOR.exists():
            try:
                raw = ask_floor("list", timeout=5)
                data = json.loads(raw)
                running = [n for n in data.get("running", []) if n in self.gui_boxes()]
            except (OSError, json.JSONDecodeError, TimeoutError) as err:
                self.write(f"Could not list running boxes: {err}")
        if running == self.running and self.tab_buttons:
            return
        self.running = running
        for child in self.tabs_frame.winfo_children():
            child.destroy()
        self.tab_buttons = {}
        for name in running:
            btn = tk.Button(
                self.tabs_frame,
                text=name,
                command=lambda n=name: self.focus_box(n),
                padx=10,
                pady=4,
            )
            btn.pack(side="left", padx=2, pady=6)
            self.tab_buttons[name] = btn
        if not running:
            tk.Label(
                self.tabs_frame,
                text="(no open boxes)",
                fg="#aaaaaa",
                bg="#1e1e1e",
            ).pack(side="left", padx=8)

    def _poll_tabs(self):
        self.refresh_tabs()
        self.after(2000, self._poll_tabs)

    def go_home(self):
        self.deiconify()
        self.lift()
        self.focus_force()
        self._wlrctl_focus(["title:Boxes"])
        self.write("Home — Boxes window.")

    def focus_box(self, name):
        matches = WINDOW_FOCUS.get(name, [f"app_id:{name}", f"title:{name}"])
        if self._wlrctl_focus(matches):
            self.write(f"Switched to {name}.")
        else:
            self.write(f"Could not find a window for {name}. Is the box still starting?")

    def _wlrctl_focus(self, matches):
        wlrctl = shutil.which("wlrctl")
        if not wlrctl:
            self.write("wlrctl is not on PATH in the screen box.")
            return False
        env = os.environ.copy()
        env.setdefault("XDG_RUNTIME_DIR", "/run/floor-boxes/wayland")
        env.setdefault("WAYLAND_DISPLAY", "wayland-0")
        completed = subprocess.run(
            [wlrctl, "toplevel", "focus", *matches],
            text=True,
            capture_output=True,
            env=env,
        )
        if completed.returncode != 0 and completed.stderr:
            self.write(completed.stderr.rstrip())
        return completed.returncode == 0

    def spin(self, action, name):
        self.write(f"{action} {name}")
        if action == "start" and not self.box_shows_window(name):
            self.write(f"{name} is a background box. It will start with no window.")
        if FLOOR_DOOR.exists():
            self.write("Asking the floor to do that. The first start can take a while.")
            threading.Thread(target=self._ask_floor_spin, args=(f"{action} {name}", name, action), daemon=True).start()
            return
        snapshot = Path("/tmp/floor-boxes-active-doors.json")
        snapshot.write_text(json.dumps(self.active), encoding="utf-8")
        completed = subprocess.run(
            [sys.executable, str(SPIN), action, name, str(snapshot)],
            text=True,
            capture_output=True,
        )
        if completed.stdout:
            self.write(completed.stdout.rstrip())
        if completed.stderr:
            self.write(completed.stderr.rstrip())
        self.refresh_tabs()

    def shutdown_floor(self):
        ok = messagebox.askyesno(
            "Shut down floor",
            "Shut down this practice machine?\n\n"
            "The Boxes window and the VM will power off.",
        )
        if not ok:
            return
        self.write("Asking the floor to shut down.")
        if FLOOR_DOOR.exists():
            threading.Thread(target=self._ask_floor_spin, args=("shutdown", None, None), daemon=True).start()
            return
        self.write("No floor door. Run poweroff on the floor host instead.")

    def _ask_floor_spin(self, line, name, action):
        try:
            text = ask_floor(line)
        except OSError as err:
            text = f"The floor door did not answer: {err}"
        if text:
            self.after(0, lambda msg=text: self.write(msg))
        self.after(0, self.refresh_tabs)
        if action == "start" and name and name in self.gui_boxes():
            # Give the window a moment to appear, then switch to it.
            self.after(1500, lambda n=name: self.focus_box(n))

    def save_doors(self):
        for name, picks in self.checks.items():
            self.pending["boxes"][name]["doors"] = [
                door for door in DOOR_CHOICES if picks[door].get()
            ]
        SOURCE_DOORS.write_text(json.dumps(self.pending, indent=2) + "\n", encoding="utf-8")
        self.write(f"Saved {SOURCE_DOORS}")
        self.write("The running door list did not change.")
        messagebox.showinfo(
            "Rebuild to apply",
            "The door list is saved.\n\n"
            "NixOS has to be rebuilt before the floor uses it.\n"
            "Starting a box still uses the old door list.",
        )


if __name__ == "__main__":
    FloorWindow().mainloop()
