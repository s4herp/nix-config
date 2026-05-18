{ ... }:

# direnv + nix-direnv (dossier §5.3 `direnv.nix` bullet, §5.5 M4 devShells).
#
# nix-direnv provides the fast, caching `use flake` implementation consumed by
# per-project .envrc files (devshells/elixir.nix). It coexists with the
# monorail asdf toolchain: nix-direnv only activates where a flake/.envrc is
# present, so it does not replace asdf in the shared repo (see dossier §5.5).
#
# HM's programs.direnv automatically injects the `direnv hook zsh` into the
# zsh integration, so the shell hook is owned here, not in shell/zsh.nix.

{
  programs.direnv = {
    enable = true;

    # nix-direnv: persistent, GC-rooted caching of `use flake` so devShells
    # don't re-evaluate on every cd into a project directory.
    nix-direnv.enable = true;

    # Keep direnv's "loading"/"unloading" messages visible: useful while
    # M4 devShells are still being introduced, so it is obvious when a
    # project .envrc actually takes effect.
    silent = false;
  };
}
