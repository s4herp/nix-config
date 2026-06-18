{ ... }:

{
  imports = [
    ../modules/shell/zsh.nix
    ../modules/shell/tmux.nix
    ../modules/editor/neovim.nix
    ../modules/direnv.nix
    ../modules/cli.nix
    ../modules/git.nix
    ../modules/secrets.nix
  ];

  home.username = "saherpinero";
  home.homeDirectory = "/Users/saherpinero";
  home.stateVersion = "26.05";
  # nixpkgs follows unstable (26.11) while home-manager follows master (26.05)
  # by design (flake.nix). The release-check warning for that intentional
  # mismatch is silenced here.
  home.enableNixpkgsReleaseCheck = false;
  programs.home-manager.enable = true;
}
