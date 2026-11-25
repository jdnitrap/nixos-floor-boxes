# nixos-floor-boxes

**Work in progress.** The pieces below boot in a test virtual machine, and bugs remain. Stop and start, sound, and the network door are still being worked out. Do not treat this as a finished install.

This project is a small NixOS computer, the **floor**, that runs separate jobs called **boxes**. Each box is its own NixOS container. A **door** is the only permission for one box to use something another box owns.

- The **screen** box owns the display and shows the Boxes window. It starts with the floor.
- **Firefox** is a window box. It does not start until you press Start. It may use the screen, the speakers, and the network.
- **Sound** owns the speakers and has no window.
- **Network** owns the way out. It resolves names. Start it before Firefox if you want a search to work.

The boxes are built on the host when the floor system is built. The test VM only starts those finished systems. Starting or stopping a box does not rebuild NixOS. Changing a door does.

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

## Look at a test VM

Build and start a virtual machine without installing it on the computer you are using. The VM gets 20 GB of RAM.

```bash
./rebuild-vm.sh
./run-vm.sh
```

While it runs, `vm-output/console.log` is the serial console. About 15 seconds after boot, and every 30 seconds after that, the guest rewrites `vm-output/floor-vm-report.txt`. Those files are for reading problems. They are not part of a real floor install.

### Modules

| Module | What it does |
|--------|----------------|
| `nixosModules.floor` | Policy, door service, screen box, templates |
| `nixosModules.floorHost` | Floor + hostname `floor`, user `floor`, NetworkManager, SSH |
| `nixosModules.default` | Same as `floor` |

## What lives where

- `modules/` — floor, screen, door, policy
- `share/doors.json` — which boxes may use which doors
- `templates/` — one NixOS config per box (firefox, sound, network, and older unused jobs)
- `rebuild-vm.sh` and `run-vm.sh` — build and start the test VM
- `manager/` — Boxes window (`floorbox.py`), door listener, spin script
- `hardware-configuration.nix` — placeholder; the installer writes the real one

## Boxes

| Box | Kind | Behavior |
|-----|------|----------|
| firefox | window | Opens on the screen door. May use sound and network |
| sound | background | Owns the speakers. No window |
| network | background | Owns the way out. Resolves names for boxes with that door |

In the Boxes window: **Home** returns to the control UI; tabs switch open window boxes. **Shut down floor** powers off the machine.

After editing templates:

```bash
python3 manager/check-templates.py
```

## Door meaning

The screen box owns the display. The sound box owns the speakers. The network box owns the way out. Other boxes reach those only through doors listed in `share/doors.json`.
