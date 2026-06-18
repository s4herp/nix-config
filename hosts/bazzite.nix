{ ... }:

# Pre-wired Bazzite host. NOT activated on macOS and BLOCKED on Bazzite by
# composefs until workaround A or C lands (dossier §6). The shared modules are
# identical to macbook; only host-level differences live here.
#   - homeDirectory canonical: /var/home/saherpinero (verify `echo $HOME`;
#     /home is a symlink).
#   - linuxbrew must be removed and PATH precedence controlled (shell phase).
#   - secrets cache: $XDG_RUNTIME_DIR/ring/secrets (tmpfs, 0600).
{
  imports = [
    ../modules/shell/zsh.nix
  ];

  home.username = "saherpinero";
  home.homeDirectory = "/var/home/saherpinero";
  home.stateVersion = "26.05";
  # See macbook.nix: silences the intentional unstable/master version
  # mismatch warning.
  home.enableNixpkgsReleaseCheck = false;
  programs.home-manager.enable = true;
}
