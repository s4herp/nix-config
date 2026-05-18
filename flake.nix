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
      mkHome = { system, username, homeDirectory }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            ({ pkgs, ... }: {
              home.username = username;
              home.homeDirectory = homeDirectory;
              home.stateVersion = "26.05";
              programs.home-manager.enable = true;
              home.packages = [ pkgs.hello ];   # smoke test
            })
          ];
        };
    in {
      homeConfigurations."saher@macbook" = mkHome {
        system = "aarch64-darwin";
        username = "saherpinero";
        homeDirectory = "/Users/saherpinero";
      };
      # Pre-cableado para el futuro (no se activa en macOS):
      homeConfigurations."saher@bazzite" = mkHome {
        system = "x86_64-linux";
        username = "saherpinero";
        homeDirectory = "/var/home/saherpinero";  # verificar en Bazzite
      };
    };
}
