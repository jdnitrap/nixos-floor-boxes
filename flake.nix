{
  description = "NixOS floor and boxes: a small host OS with disposable job containers and doors";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }: {
    # Import on any NixOS host:
    #   imports = [ inputs.nixos-floor-boxes.nixosModules.floor ];
    nixosModules.floor = import ./modules/floor.nix;
    nixosModules.default = self.nixosModules.floor;

    # Optional host defaults (hostname, floor user, ssh, networkmanager).
    # Still import your own hardware-configuration.nix.
    nixosModules.floorHost = import ./modules/floor-host.nix;

    # Example full system: floor modules + host defaults.
    # Add hardware-configuration.nix on the target machine.
    nixosConfigurations.floor = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.floorHost
        ({ ... }: {
          # Replace with the installer-generated file on real hardware.
          imports = [ ./hardware-configuration.nix ];
        })
      ];
    };
  };
}
