{
  description = "Saher's cross-platform Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      mkHome = { system, hostModule }:
        home-manager.lib.homeManagerConfiguration {
          # Scoped unfree allowance: only 1password-cli (op), needed by
          # modules/secrets.nix. Not a blanket allowUnfree.
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [ "1password-cli" ];
          };
          modules = [ hostModule ];
        };
    in {
      homeConfigurations."saher@macbook" = mkHome {
        system = "aarch64-darwin";
        hostModule = ./hosts/macbook.nix;
      };
      # Pre-cableado para el futuro (no se activa en macOS):
      homeConfigurations."saher@bazzite" = mkHome {
        system = "x86_64-linux";
        hostModule = ./hosts/bazzite.nix;
      };
    };
}
