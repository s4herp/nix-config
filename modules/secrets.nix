{ pkgs, ... }:

# M3 secrets (dossier §7, decision D5). Secrets are resolved ON DEMAND by
# `secrets-refresh` (op inject), never at shell startup (zero prompts, zero
# latency regression). The materialized cache:
#   - lives at ${XDG_CACHE_HOME:-~/.cache}/ring/secrets, mode 0600
#   - is NEVER declared in HM, NEVER enters the nix store, NEVER versioned
#   - is sourced by modules/shell/zsh.nix only if present (shell never breaks
#     if it is absent)
# secrets/secrets.tpl holds op:// pointers only (safe in VCS).
#
# Trade-off accepted (§7): secret at rest in a local 0600 file, regenerable
# from 1Password; same posture as the legacy ~/.zsh_secrets but no longer
# hand-maintained. op is NOT invoked unless the user runs secrets-refresh.

let
  # Pointer template tracked in VCS; copied into the store (no secret values).
  secretsTpl = ../secrets/secrets.tpl;

  secrets-refresh = pkgs.writeShellScriptBin "secrets-refresh" ''
    set -eu
    umask 077
    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/ring"
    cache="$cache_dir/secrets"
    mkdir -p "$cache_dir"
    chmod 700 "$cache_dir"
    # op must be signed in (desktop app integration or `op signin`).
    ${pkgs._1password-cli}/bin/op inject -f -i ${secretsTpl} -o "$cache"
    chmod 600 "$cache"
    echo "secrets-refresh: wrote $cache (0600)"
    echo "open a new shell or: source \"$cache\""
  '';
in
{
  home.packages = [
    pkgs._1password-cli # `op`, nix-pinned (wins over Homebrew via PATH fix)
    secrets-refresh
  ];
}
