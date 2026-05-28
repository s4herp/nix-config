{
  description = "Saher's cross-platform Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Stable channel pinned solely to source neovim 0.11.x. nixos-unstable
    # currently ships neovim 0.12 (dev branch) whose treesitter API break
    # crashes pinned plugins (nvim-treesitter master, treesitter-context,
    # render-markdown.nvim). See overlay in mkHome below.
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, ... }:
    let
      # Scoped unfree allowance: only 1password-cli (op), needed by
      # modules/secrets.nix. Not a blanket allowUnfree.
      unfreePredicate = pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [ "1password-cli" ];

      # Centralized, reproducible nixpkgs import. Explicit `overlays`
      # prevents impure reads of ~/.config/nixpkgs/overlays.* (nix.dev
      # best practice).
      mkPkgs = nixpkgsInput: system: extraOverlays:
        import nixpkgsInput {
          inherit system;
          config = { allowUnfreePredicate = unfreePredicate; };
          overlays = extraOverlays;
        };

      neovimStableOverlay = system: final: prev: {
        neovim-unwrapped =
          (mkPkgs nixpkgs-stable system [ ]).neovim-unwrapped;
      };

      mkHome = { system, hostModule }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs nixpkgs system [ (neovimStableOverlay system) ];
          modules = [ hostModule ];
        };

      systems = [ "aarch64-darwin" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems
        (system: f (mkPkgs nixpkgs system [ ]));
      beamSets = pkgs: import ./devshells/beam.nix { inherit pkgs; };
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

      packages = forAllSystems (pkgs:
        nixpkgs.lib.mapAttrs' (name: drv:
          nixpkgs.lib.nameValuePair "beam-${name}" drv
        ) (beamSets pkgs));
    };
}
