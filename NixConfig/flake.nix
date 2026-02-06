{
  description = "NixOS configuration with multiple hosts";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    quickshell.url = "github:outfoxxed/quickshell";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: 
  let
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
  in {
    nixosConfigurations = {
      generic = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          ./common.nix
          { 
            networking.hostName = "nixos";
            fileSystems."/" = {
              device = "/dev/disk/by-label/nixos";
              fsType = "ext4";
            };
          }
        ];
      };

      wolverine = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          ./common.nix
          ./wolverine.nix
        ];
      };

      mentalist = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          ./common.nix
          ./mentalist.nix
        ];
      };
    };
  };
}
