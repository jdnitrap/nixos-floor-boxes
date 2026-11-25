# Sensible floor host defaults. Import floor modules plus login/network basics.
# Pair with hardware-configuration.nix from the NixOS installer.
{ pkgs, ... }:
{
  imports = [ ./floor.nix ];

  networking.hostName = "floor";
  networking.networkmanager.enable = true;
  services.openssh.enable = true;

  users.users.floor = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    description = "Floor login";
  };

  # python3 helps local debugging; the door service already bundles its own interpreter.
  environment.systemPackages = [ pkgs.vim pkgs.python3 ];

  # No desktop and no AI on the floor. The screen is its own box.
  system.stateVersion = "26.05";

  # Only the qemu test VM. 20 GB, so building the boxes is not killed for memory.
  virtualisation.vmVariant.virtualisation.memorySize = 20480;

  # A real floor install does not write this report.
  # /tmp/shared is the host directory passed in as SHARED_DIR.
  virtualisation.vmVariant.systemd.services.floor-vm-report = {
    description = "Write what this VM did so it can be read on the host";
    serviceConfig.Type = "oneshot";
    script = ''
      set +e
      out=/tmp/shared/floor-vm-report.txt
      mkdir -p /tmp/shared
      {
        echo "floor vm report $(${pkgs.coreutils}/bin/date -Is)"
        echo
        echo "=== running ==="
        ${pkgs.systemd}/bin/systemctl is-system-running
        echo
        echo "=== failed units ==="
        ${pkgs.systemd}/bin/systemctl --failed --no-pager
        echo
        echo "=== floor units ==="
        ${pkgs.systemd}/bin/systemctl is-active floor-box-door.service container@screen.service container@network.service container@firefox.service container@sound.service
        echo
        echo "=== boxes ==="
        /run/current-system/sw/bin/nixos-container list 2>/dev/null || true
        echo
        if [ -f /var/lib/floor-boxes/build.log ]; then
          echo "=== box build ==="
          ${pkgs.coreutils}/bin/cat /var/lib/floor-boxes/build.log
          echo
        fi
        echo "=== recent errors ==="
        ${pkgs.systemd}/bin/journalctl -b -p err --no-pager -n 80
      } > "$out"
    '';
  };
  virtualisation.vmVariant.systemd.timers.floor-vm-report = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15s";
      OnUnitActiveSec = "30s";
      AccuracySec = "5s";
    };
  };
}
