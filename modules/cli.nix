{ pkgs, ... }:

# CLI toolset as declarative home.packages (dossier §5.3 cli.nix bullet).
# Authoritative tool inventory: §3 of the tools report
# (~/Dev/shinkansen/useful-analysis/2026-05-17-herramientas-de-desarrollo.md,
# dossier Appendix B). Replaces the Homebrew `brew leaves` set; language
# runtimes stay on asdf (dossier M4, not duplicated here).
#
# Out of scope on purpose: docker/gcloud/awscli/ngrok/redis are managed
# outside HM today (Docker Desktop / OrbStack, cloud SDK installers) and the
# dossier-listed core set does not include them; left to the existing tooling.
# GUI apps (DBeaver, Obsidian, Raycast) are out of HM scope per dossier D6.

{
  home.packages = with pkgs; [
    # --- Modern core-utility replacements ---
    eza # ls replacement (aliases ls/ll/lt in zsh.nix)
    bat # cat with syntax highlighting; used in fzf-tab previews
    fd # fast find; FZF_DEFAULT_COMMAND backend
    tree # directory tree listing
    ncdu # disk usage TUI

    # --- Search / navigation / history ---
    ripgrep # rg; code search (provides the `rg` binary)
    fzf # fuzzy finder, integrated with tmux popups
    zoxide # frequency-based directory jumping (z, j/ji)
    atuin # synced, searchable shell history (replaces Ctrl-R)

    # --- Git & review ---
    gh # GitHub CLI: PRs, CI, review comments
    lazygit # git TUI (also wired into Neovim)
    git-town # branch-workflow automation (tools report §3)
    git-sizer # repository size analysis (tools report §3)

    # --- Containers & cloud ---
    dive # Docker image layer inspection
    kubectx # kube context/namespace switching (tools report §3)

    # --- Language / build tooling ---
    pre-commit # validation hooks
    osv-scanner # dependency vulnerability scanning (tools report §3)
    luarocks # Lua package manager (Neovim ecosystem; tools report §3)
    cloc # source line counting (tools report §3)
    tldr # simplified man pages (tools report §3)

    # --- Data & utilities ---
    jq # JSON processor
    httpie # human-friendly HTTP client
    graphviz # graph rendering (tools report §3)
    # direnv owned by modules/direnv.nix (programs.direnv) — NOT here
    # neovim owned by modules/editor/neovim.nix (programs.neovim) — NOT here

    # --- Editors / CLI ---
    vim # legacy fallback editor (tools report §3)

    # NOTE: the following tools-report §3 entries are intentionally NOT added
    # here. They either have non-trivial/uncertain nixpkgs attrs to confirm
    # before adding, or belong to other modules / are managed elsewhere:
    #   gnupg          # TODO: verify nixpkgs attr (gnupg) — GPG signing;
    #                  # likely belongs with git.nix signing setup, not cli.nix
    #   imagemagick    # TODO: verify nixpkgs attr (imagemagick)
    #   ffmpeg         # TODO: verify nixpkgs attr (ffmpeg / ffmpeg_7)
    #   whisper-cpp    # TODO: verify nixpkgs attr (whisper-cpp / openai-whisper-cpp)
    #   yt-dlp         # TODO: verify nixpkgs attr (yt-dlp)
    #   redis          # TODO: verify nixpkgs attr (redis) — runtime service,
    #                  # likely out of HM CLI scope (managed via docker today)
  ];
}
