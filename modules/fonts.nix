{ pkgs, ... }:

# Fonts declared as home.packages. On darwin, Home Manager symlinks the
# `share/fonts` tree of every package in home.packages into
# ~/Library/Fonts/HomeManager, which CoreText scans; no fontconfig needed.
# On Linux the same module requires fonts.fontconfig.enable, so it is imported
# by macbook.nix only until bazzite.nix activates.
#
# This closes the last manual-install hole left by the ~/.cfg bare-repo:
# Hack Nerd Font and MesloLGS NF were dropped into ~/Library/Fonts by hand
# (the p10k installer's doing) and were the only fonts not owned by HM.
#
# The NF (Nerd Font) build is not cosmetic: two consumers need the glyphs.
#   - modules/shell/tmux.nix status-left/right (Material Design codepoints:
#     wifi, calendar, clock, plus the battery icons substituted by
#     tmuxPlugins.battery).
#   - the p10k prompt (p10k.zsh).
# Ghostty embeds Symbols Nerd Font Mono as a fallback, so those glyphs render
# even without this package, but the fallback is invisible to every other
# consumer of the font (and to Bazzite later).

{
  home.packages = [ pkgs.nerd-fonts.sauce-code-pro ];
}
