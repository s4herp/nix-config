{
  description = "Saher's cross-platform Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Stable channel pinned solely to source neovim 0.11.x. nixos-unstable
    # ships neovim 0.12, whose treesitter API break crashes pinned plugins
    # (nvim-treesitter master, treesitter-context, render-markdown.nvim).
    # See overlay in mkHome below.
    #
    # Branch choice (2026-07-25): nixos-25.11 is the NEWEST branch still on
    # neovim 0.11.x (0.11.7). Both older and newer are unusable here:
    # nixos-25.05 is EOL and frozen since 2026-01-01 (stuck on 0.11.5),
    # while nixos-26.05 has already moved to 0.12.4. 25.11 is itself EOL
    # (frozen 2026-06-30) — there is no supported branch left on 0.11.x, so
    # this pin has an expiry date: it must go away when the lua tree is
    # migrated for 0.12.
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
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

      # devshells/ (beam sets + elixir devShell) removed 2026-07-24: zero
      # consumers after two months — the monorail toolchain contract is asdf
      # (.tool-versions) + devcontainers, and the deps/_build copy trick for
      # review worktrees requires the exact same toolchain binaries, which a
      # Nix shell would break. Recover from git history if a personal
      # (non-monorail) project ever needs a pinned BEAM devShell.
    };
}
