#!/usr/bin/env bash
# Rebuild the floor test VM. Does not install it on this computer.
set -euo pipefail
cd "$(dirname "$0")"
nixos-rebuild build-vm --flake .#floor
echo "VM rebuilt. Start it with ./run-vm.sh"
echo "Logs: vm-output/floor-vm-report.txt and vm-output/console.log"
