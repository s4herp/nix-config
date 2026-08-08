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
    #
    # "Mono" rather than the bare / "Propo" families: it forces every Nerd
    # Font glyph into one cell. The proportional variants render the tmux
    # status icons double-width, which shifts the `#[fg=...]│` separators in
    # status-left/right out of alignment.
    #
    # Pairs with `theme = Vercel` above: Geist is Vercel's own typeface.
    #
    # Ligatures are left at their default (on). To render one glyph per
    # character instead, add: font-feature = -calt / -liga / -dlig.
    font-family = GeistMono Nerd Font Mono
    font-size = 14
  '';
}
