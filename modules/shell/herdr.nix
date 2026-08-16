{ config, ... }:

# herdr: agent-aware terminal multiplexer, run alongside tmux (not as a
# replacement -- see modules/shell/tmux.nix). It is kept for the multi-agent
# case: it reads every pane and marks each agent working / blocked / idle in a
# sidebar, which is the one thing tmux cannot report.
#
# WHY `settings` IS NOT USED
# --------------------------
# programs.herdr.settings renders config.toml into the nix store and links
# $XDG_CONFIG_HOME/herdr/config.toml to it. That path is read-only, and herdr
# persists part of its own state THROUGH that same file: the settings UI
# writes back on every toggle (toast delivery, agent border labels, pane
# screen history, prefix ascii input source...). Against a store symlink every
# one of those writes fails with:
#
#   WARN failed to write config event="config.write" ... path=.../config.toml
#        context="toast setting" err="Permission denied (os error 13)"
#
# So the file is kept in-repo and linked OUT of the store instead: herdr
# writes through the symlink (verified -- it rewrites the target in place, it
# does not replace the link via a tmp+rename), which means the settings UI
# works and every change it makes shows up as a diff in this repo.
#
# Consequences to keep in mind:
#   - The repo path below is absolute and hardcoded. Cloning nix-config
#     somewhere else on macOS breaks the link (the switch still succeeds; the
#     symlink just dangles).
#   - Editing modules/shell/herdr/config.toml no longer needs a switch, but it
#     does need `herdr server reload-config` to hit the running server. The
#     module's own onChange hook is gone: with an out-of-store symlink the
#     link target never changes, so it would never fire.
#   - Full option reference: `herdr --default-config`.

{
  programs.herdr.enable = true;

  xdg.configFile."herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Dev/nix-config/modules/shell/herdr/config.toml";
}
