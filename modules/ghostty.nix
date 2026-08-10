{ ... }:

# Ghostty terminal configuration (closes the last reproducibility hole from
# the ~/.cfg bare-repo: this was the only tracked file not yet owned by HM).
# The app itself stays OUT of HM scope per dossier D6 (GUI apps are installed
# outside Nix on macOS); only the config file is managed here.
#
# The config is cross-platform: macos-* keys are no-ops on Linux, so the same
# module can be imported by bazzite.nix when that host activates.

{
  xdg.configFile."ghostty/config".text = ''
    theme = Vercel
    keybind = shift+enter=text:\n
    macos-titlebar-style = transparent
  '';
}
