{
  description = "NixOS configuration with multiple hosts";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quickshell = {
      url = "github:outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
          ./modules/common.nix
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
          ./modules/common.nix
          ./hosts/Wolverine/default.nix
        ];
      };

      mentalist = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          ./modules/common.nix
          ./hosts/Mentalist/default.nix
        ];
      };
    };
  };
}
