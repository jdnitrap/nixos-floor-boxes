# nixos-floor-boxes

A small NixOS **floor** plus disposable **boxes** (jobs) connected by **doors**.

- The **floor** boots, logs you in, and reaches the network.
- The **screen** box stays in the NixOS config (rebuild to change it).
- Other boxes are **templates**. Starting one does **not** rebuild NixOS.
- Changing doors or the screen **does** rebuild NixOS.

This is a flake. Install it on any NixOS machine you choose.

## Install with a flake

On the target computer, use a flake like this (plus the installer `hardware-configuration.nix`):

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-floor-boxes.url = "github:jdnitrap/nixos-floor-boxes";
  };

  outputs = { nixpkgs, nixos-floor-boxes, ... }: {
    nixosConfigurations.floor = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixos-floor-boxes.nixosModules.floorHost
        ./hardware-configuration.nix
        # Optional: set a password
        # ({ ... }: { users.users.floor.initialPassword = "change-me"; })
      ];
    };
  };
}
```

Then:

```bash
sudo nixos-rebuild switch --flake .#floor
```

### Modules

| Module | What it does |
|--------|----------------|
| `nixosModules.floor` | Policy, door service, screen box, templates |
| `nixosModules.floorHost` | Floor + hostname `floor`, user `floor`, NetworkManager, SSH |
| `nixosModules.default` | Same as `floor` |

## What lives where

- `modules/` — floor, screen, door, policy
- `share/doors.json` — which boxes may use which doors
- `templates/` — one NixOS config per job (firefox, files, mail, photos, sound, print)
- `manager/` — Boxes window (`floorbox.py`), door listener, spin script
- `hardware-configuration.nix` — placeholder; the installer writes the real one

## Boxes

| Box | Kind | Behavior |
|-----|------|----------|
| files, firefox, mail, photos | window | Opens a GUI on the screen door |
| sound, print | background | Services only (speakers / printer doors) |

In the Boxes window: **Home** returns to the control UI; tabs switch open window boxes. **Shut down floor** powers off the machine.

After editing templates:

```bash
python3 manager/check-templates.py
```

## Door meaning

The screen box owns the display. The sound box owns the speakers. The print box owns the printer. Other boxes reach those only through doors listed in `share/doors.json`.
