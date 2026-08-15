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

    # GCP identity by location. This machine holds two accounts -- personal
    # (saherp145@gmail.com) and work (saher.pinero@shinkansen.finance) -- and
    # CLOUDSDK_CONFIG is what actually separates them, because it moves the
    # whole gcloud directory including application_default_credentials.json,
    # which `gcloud config configurations` does NOT touch.
    #
    # The default (variable unset) is the PERSONAL profile, deliberately: an
    # accidental command should cost a stray resource in a personal project,
    # never unexplained activity on a corporate identity that someone else
    # audits. So only work is switched on, and only by location.
    #
    # This belongs in stdlib rather than in an .envrc because direnv loads the
    # NEAREST .envrc and nothing above it: the monorail and every wt-* worktree
    # carry their own (sourcing .envrc.ai), so a file at ~/dev/shinkansen would
    # never be read inside them. stdlib runs before every .envrc, everywhere,
    # which is exactly the reach this needs. `[dD]ev` because the path is typed
    # both ways on a case-insensitive filesystem.
    stdlib = ''
      case "$PWD" in
        "$HOME"/[dD]ev/shinkansen/*)
          export CLOUDSDK_CONFIG="$HOME/.config/gcloud-work"
          ;;
      esac
    '';
  };
}
