#!/usr/bin/env bash
# Start the built floor VM and keep a copy of what it does.
# Console text and the guest report both land in vm-output/.
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$root/vm-output"
export SHARED_DIR="$root/vm-output"
export QEMU_OPTS="-serial file:${root}/vm-output/console.log ${QEMU_OPTS:-}"
if [[ ! -x "$root/result/bin/run-floor-vm" ]]; then
  echo "Build the VM first: nixos-rebuild build-vm --flake .#floor" >&2
  exit 1
fi
exec "$root/result/bin/run-floor-vm" "$@"
