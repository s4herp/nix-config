{ ... }:

{
  imports = [
    ../modules/shell/zsh.nix
  ];

  home.username = "saherpinero";
  home.homeDirectory = "/Users/saherpinero";
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;
}
