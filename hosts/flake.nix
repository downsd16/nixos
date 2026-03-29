{
  description = "HomeLab NixOS Flake for Creating Docker Swarm Manager and PI Workers";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs, ... }:
  let
    lib = nixpkgs.lib;
  in {
    nixosConfigurations = {
      # Reusable Pi worker configuration
      # Dynamic hostname via PI_HOSTNAME
      pi = lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ ./hosts/pi/default.nix ];
      };

      # Fixed-name swarm manager (x86_64)
      manager = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/manager/default.nix ];
      };
    };
  };
}