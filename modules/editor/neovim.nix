{ pkgs, lib, config, ... }:

# Neovim under Home Manager — decision D4 / dossier §5.3, "Option 2b":
#
#   * HM installs and PINS Neovim (the binary version is anchored by
#     flake.lock -> nixpkgs, NOT by a system package manager).
#   * The Lua configuration tree is VENDORED into this repo at ./nvim and
#     delivered verbatim via xdg.configFile."nvim".source. HM does NOT
#     render or rewrite the Lua; it ships the directory as-is.
#   * lazy.nvim stays the runtime plugin manager (init.lua ->
#     require 'config.lazy'); plugins are NOT packaged through Nix.
#   * lazy-lock.json is the reproducibility anchor for plugins and is
#     COMMITTED inside the vendored tree (see vendoring note below).
#
# This is deliberately NOT nixvim and NOT programs.neovim plugin
# management: the existing kickstart-style config (init.lua + lua/, 45
# plugins via lazy.nvim) is reused unchanged so behaviour matches the
# legacy ~/.cfg setup on day one.
#
# Source of truth for the Lua tree: github.com/s4herp/dotfiles, path
# .config/nvim/ (on macOS the files already live in ~/.config/nvim, the
# origin of the legacy ~/.cfg bare-repo).

#
# NEOVIM VERSION PIN (2026-05-19)
# -------------------------------
# `pkgs.neovim-unwrapped` is overlaid in flake.nix to the `nixos-25.05`
# channel so we ship neovim 0.11.x instead of the 0.12 dev build that
# nixos-unstable currently exposes. Rationale:
#   * 0.12 changed the treesitter API (TSNode:range, LanguageTree internals)
#     which crashes the plugin versions pinned in lazy-lock.json
#     (nvim-treesitter master, nvim-treesitter-context, render-markdown.nvim).
#   * The vendored lazy-lock.json is read-only via xdg.configFile, so a
#     fast `:Lazy sync` recovery is not viable; pinning the binary is the
#     conservative fix until the plugin set is migrated to nvim-treesitter
#     `main` branch.
# Remove the overlay once the lua tree is upgraded for 0.12.

{
  programs.neovim = {
    enable = true; # pinned via HM/nixpkgs (flake.lock anchors the version)

    # Default editor: EDITOR/VISUAL/MANPAGER are already exported by
    # modules/shell/zsh.nix (initContent, section 3). Do NOT duplicate
    # them here. defaultEditor would re-export EDITOR via HM's session
    # vars and collide with the zsh module, so it is left off on purpose.
    defaultEditor = false;
    viAlias = false; # `vi`/`vim`/`v` aliases are owned by zsh.nix
    vimAlias = false;

    withNodeJs = true; # Node provider (lazy.nvim plugins, markdown-preview)
    withPython3 = true; # Python3 provider
    withRuby = false; # no Ruby provider in this config

    # No HM-managed plugins/extraLuaConfig: the vendored tree owns 100% of
    # the configuration. Anything here would fight init.lua.
  };

  # Vendored Lua tree, shipped verbatim. The ./nvim directory is added to
  # this repo in a FOLLOW-UP step (see "Vendoring steps" at the bottom of
  # this file); referencing it before it exists will fail `nix flake
  # show`, which is expected and intentional for this task's scope.
  xdg.configFile."nvim".source = ../../nvim;

  # Runtime deps the config expects on PATH. lazy.nvim clones plugins at
  # runtime (git), and Telescope/grep pickers need ripgrep + fd; the
  # config also references Node/Python providers (enabled above).
  #
  # TODO(dossier §5.3 / cli.nix): ripgrep, fd, git, lazygit and friends
  # are part of the shared CLI set declared in modules/cli.nix. Do NOT
  # re-declare them here to avoid duplicate home.packages entries across
  # modules. If a future audit shows cli.nix lacks one of these, add it
  # THERE, not in this module. Listed here only as documentation:
  #   - ripgrep  (Telescope live_grep, :checkhealth telescope)
  #   - fd       (Telescope find_files, FZF_DEFAULT_COMMAND in zsh.nix)
  #   - git      (lazy.nvim bootstrap clone in lua/config/lazy.lua)
  #   - node, python3 providers -> covered by withNodeJs/withPython3 above
  home.packages = [ ];

  # ---------------------------------------------------------------------
  # VENDORING STEPS (coordinator follow-up — NOT performed by this task)
  # ---------------------------------------------------------------------
  # The Lua tree is currently only in ~/.config/nvim and lazy-lock.json is
  # git-IGNORED by ~/.config/nvim/.gitignore (line 7), so it is NOT tracked
  # in the s4herp/dotfiles bare-repo. To satisfy D4 ("lazy-lock.json
  # committed") it must be force-copied into THIS repo:
  #
  #   1. mkdir -p <repo>/nvim
  #   2. Copy the tracked tree + the ignored lock, excluding cruft:
  #        rsync -a --delete \
  #          --exclude '.git' --exclude '.DS_Store' \
  #          --exclude 'spell/' --exclude 'tags' --exclude 'test.sh' \
  #          --exclude '.luarc.json' \
  #          ~/.config/nvim/ <repo>/nvim/
  #      (Keep .config/nvim/.gitignore OUT of the vendored copy, or strip
  #       its `lazy-lock.json` line — otherwise nix-config's own git would
  #       also ignore the lock and D4 would silently fail.)
  #   3. Force-add the lock so it lands in nix-config history:
  #        git -C <repo> add -f nvim/lazy-lock.json
  #        git -C <repo> add nvim/
  #   4. Verify the lock is tracked here (the dossier §4/§9 open risk):
  #        git -C <repo> ls-files nvim/lazy-lock.json   # must print the path
  #   5. Flakes only see git-tracked files: `git add` BEFORE `nix flake
  #      show` / `nix build`, else xdg.configFile."nvim".source is empty.
  # ---------------------------------------------------------------------
}
