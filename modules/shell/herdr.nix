{ config, ... }:

# herdr: agent-aware terminal multiplexer, run alongside tmux (not as a
# replacement -- see modules/shell/tmux.nix). It is kept for the multi-agent
# case: it reads every pane and marks each agent working / blocked / idle in a
# sidebar, which is the one thing tmux cannot report.
#
# WHY THE BINARY IS NOT INSTALLED BY NIX
# --------------------------------------
# herdr ships its own updater, and it is the only way to change versions
# without losing the running session: it downloads the release binary and hands
# the live server over to it (`herdr update --handoff`, or the
# `server.live_handoff` socket method with `import_exe`), keeping every pane
# alive. Against a read-only store path that cannot work, and herdr refuses it
# outright:
#
#   self-update is disabled for Nix installs; update with `nix profile upgrade`
#   or update the flake input that provides Herdr
#
# Meanwhile the in-app "update ready" badge stays lit for as long as nixpkgs
# lags upstream, and it does lag: 0.8.0 in nixpkgs vs 0.8.2 upstream on
# 2026-08-19, with no bump PR open. Following it by hand means an overlay
# carrying three hashes (src, cargoHash, zigDeps) on every release.
#
# So the binary is installed OUT of nix, with the official installer:
#
#   curl -fsSL https://herdr.dev/install.sh | sh    -> ~/.local/bin/herdr
#
# $HOME/.local/bin is already on PATH (modules/shell/zsh.nix), and the autostart
# hook there is a `command -v herdr` check, so it picks this binary up
# unchanged. Version bumps from then on are `herdr update --handoff`, with no
# switch and no lost panes.
#
# Trade-off accepted: herdr is no longer reproducible from this repo, and the
# shell completions the nixpkgs package used to install are gone (regenerate
# with `herdr completion zsh` if they are missed).
#
# WHY config.toml IS STILL MANAGED HERE, AND NOT VIA `settings`
# -------------------------------------------------------------
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
#     does need `herdr server reload-config` to hit the running server.
#   - Full option reference: `herdr --default-config`.

{
  xdg.configFile."herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Dev/nix-config/modules/shell/herdr/config.toml";
}
