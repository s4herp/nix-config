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

    # The font itself is installed by modules/fonts.nix; naming it here only
    # pins which family Ghostty picks. Without this key Ghostty falls back to
    # its embedded JetBrains Mono, which renders identically but is not
    # declared anywhere.
    #
    # "Mono" (not the bare "Nerd Font" / "Propo" families) forces every Nerd
    # Font glyph into a single cell. The proportional variants render the
    # tmux status icons double-width, which shifts the `#[fg=...]│` separators
    # in status-left/right out of alignment.
    font-family = JetBrainsMono Nerd Font Mono
    font-size = 14

    # Ligatures off: `!=`, `->` and `=>` collapsed into one glyph misreport
    # column positions when reading diffs and compiler/stack-trace output.
    font-feature = -calt
    font-feature = -liga
    font-feature = -dlig
  '';
}
