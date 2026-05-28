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
  # `inherit (pkgs) …` replaces `with pkgs;` (nix.dev best practice: no
  # `with` at scope that shadows lookups). Grouped per-category; per-pkg
  # rationale lives above each `inherit` block.
  home.packages = builtins.attrValues {
    # Modern core-utility replacements:
    #   eza (ls; aliases in zsh.nix), bat (cat w/ highlight; fzf-tab
    #   previews), fd (find; FZF backend), tree, ncdu (du TUI).
    inherit (pkgs) eza bat fd tree ncdu;

    # Search / navigation / history:
    #   ripgrep (rg), fzf (tmux popups), zoxide (z/zi), atuin (Ctrl-R).
    inherit (pkgs) ripgrep fzf zoxide atuin;

    # Git & review:
    #   gh, lazygit, git-town (workflow), git-sizer (repo size).
    inherit (pkgs) gh lazygit git-town git-sizer;

    # Containers & cloud:
    #   dive (image layers), kubectx (kube ctx/ns switch).
    inherit (pkgs) dive kubectx;

    # Language / build tooling:
    #   pre-commit, osv-scanner (vuln scan), luarocks (Neovim ecosystem),
    #   cloc (line counts), tldr (man).
    inherit (pkgs) pre-commit osv-scanner luarocks cloc tldr;

    # Data & utilities:
    #   jq, httpie, graphviz.
    # direnv owned by modules/direnv.nix (programs.direnv) — NOT here.
    # neovim owned by modules/editor/neovim.nix (programs.neovim) — NOT here.
    inherit (pkgs) jq httpie graphviz;

    # Editors / CLI:
    #   vim (legacy fallback editor).
    inherit (pkgs) vim;

    # NOTE: the following tools-report §3 entries are intentionally NOT
    # added here. They either have non-trivial/uncertain nixpkgs attrs to
    # confirm before adding, or belong to other modules / are managed
    # elsewhere:
    #   gnupg          # TODO: verify nixpkgs attr (gnupg) — GPG signing;
    #                  # likely belongs with git.nix signing setup, not cli.nix
    #   imagemagick    # TODO: verify nixpkgs attr (imagemagick)
    #   ffmpeg         # TODO: verify nixpkgs attr (ffmpeg / ffmpeg_7)
    #   whisper-cpp    # TODO: verify nixpkgs attr (whisper-cpp / openai-whisper-cpp)
    #   yt-dlp         # TODO: verify nixpkgs attr (yt-dlp)
    #   redis          # TODO: verify nixpkgs attr (redis) — runtime service,
    #                  # likely out of HM CLI scope (managed via docker today)
  };
}
