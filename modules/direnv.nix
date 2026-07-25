{ ... }:

# direnv + nix-direnv (dossier §5.3 `direnv.nix` bullet).
#
# direnv is what the monorail workflow actually consumes (.envrc sourcing
# .envrc.ai, `direnv exec . mix ...` in worktrees). nix-direnv stays enabled
# at zero cost: it only engages if an .envrc ever says `use flake`, which no
# project does today (devshells/ was removed 2026-07-24, see flake.nix).
#
# HM's programs.direnv automatically injects the `direnv hook zsh` into the
# zsh integration, so the shell hook is owned here, not in shell/zsh.nix.

{
  programs.direnv = {
    enable = true;

    # nix-direnv: persistent, GC-rooted caching of `use flake`. No consumer
    # today; kept because it is inert without a flake-using .envrc.
    nix-direnv.enable = true;

    # Keep direnv's "loading"/"unloading" messages visible so it is obvious
    # when a project .envrc takes effect (monorail worktrees rely on it).
    silent = false;
  };
}
