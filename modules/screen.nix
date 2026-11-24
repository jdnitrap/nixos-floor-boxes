# The screen box stays in /etc/nixos. Changing it rebuilds the setup.
# This is the window where a person picks the doors.
# labwc is used so other boxes (Firefox) can open windows on the same Wayland door.
# cage only runs one client, so it cannot show Firefox beside this window.
{ pkgs, lib, ... }:
let
  policy = builtins.fromJSON (builtins.readFile ../share/doors.json);
  screen = policy.screen;
  gui = pkgs.python3.withPackages (ps: [ ps.tkinter ]);
in
{
  containers.screen = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = screen.address.host;
    localAddress = screen.address.local;

    bindMounts."/dev/dri" = {
      hostPath = "/dev/dri";
      isReadOnly = false;
    };
    bindMounts."/dev/input" = {
      hostPath = "/dev/input";
      isReadOnly = false;
    };
    bindMounts."/run/floor-boxes/wayland" = {
      hostPath = "/run/floor-boxes/wayland";
      isReadOnly = false;
    };
    # The screen box asks the floor through this socket. It does not start boxes itself.
    bindMounts."/run/floor-boxes/door" = {
      hostPath = "/run/floor-boxes/door";
      isReadOnly = false;
    };
    # The mouse list lives on the floor. The screen box reads it so clicks work.
    bindMounts."/run/udev" = {
      hostPath = "/run/udev";
      isReadOnly = true;
    };

    # The floor keeps devices closed. The screen box is the one that may use them.
    allowedDevices = [
      { node = "char-drm"; modifier = "rwm"; }
      { node = "char-input"; modifier = "rw"; }
      { node = "/dev/dri/card0"; modifier = "rwm"; }
      { node = "/dev/dri/renderD128"; modifier = "rwm"; }
    ];

    config = { ... }: {
      system.stateVersion = "26.05";
      # wlrctl focuses open box windows for the Home / tab switcher in floorbox.
      environment.systemPackages = [ gui pkgs.labwc pkgs.wlrctl ];
      # These copies live inside the screen box. A link back to the floor would not open.
      environment.etc."floor-boxes/floorbox.py".source = ../manager/floorbox.py;
      environment.etc."floor-boxes/spin.py".source = ../manager/spin.py;
      environment.etc."floor-boxes/doors.json".source = ../share/doors.json;
      systemd.services.floor-screen = {
        description = "Screen window for the boxes";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-user-sessions.service" ];
        environment = {
          XDG_RUNTIME_DIR = "/run/floor-boxes/wayland";
          HOME = "/root";
          # The screen box has no text console. Do not wait for one.
          SEATD_VTBOUND = "0";
          # The pretend display draws in software.
          WLR_RENDERER = "pixman";
          # Open the window even when the mouse list is empty.
          WLR_LIBINPUT_NO_DEVICES = "1";
        };
        serviceConfig = {
          # -s starts the Boxes window. Other Wayland clients (Firefox) can join this compositor.
          ExecStart = "${pkgs.labwc}/bin/labwc -s ${lib.escapeShellArg "${gui}/bin/python3 /etc/floor-boxes/floorbox.py"}";
          Restart = "on-failure";
          RestartSec = "2s";
        };
      };
    };
  };

  environment.etc."floor-boxes/floorbox.py".source = ../manager/floorbox.py;
  environment.etc."floor-boxes/spin.py".source = ../manager/spin.py;
}
