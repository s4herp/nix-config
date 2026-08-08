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

    # Installed by modules/fonts.nix. Ghostty's default is an embedded
    # JetBrains Mono NL, so leaving font-family unset means the terminal
    # silently depends on what the app bundle happens to ship.
    font-family = Maple Mono NF
    font-size = 14

    # Ligatures left ON, unlike the rest of the config's bias toward literal
    # rendering: the ligature set and the italics are most of what makes this
    # family look different from a stock mono. To go back to strict
    # one-glyph-per-character, add: font-feature = -calt / -liga / -dlig.
  '';
}
