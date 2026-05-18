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
  # secret-add NAME [--generate]: create the op item AND append the op://
  # pointer to the repo's secrets/secrets.tpl in one step. The secret value
  # is read with `read -rs` (never in argv / `ps`) unless --generate.
  secret-add = pkgs.writeShellScriptBin "secret-add" ''
    set -eu
    name="''${1:-}"
    mode="''${2:-}"
    if [ -z "$name" ]; then
      echo "usage: secret-add NAME [--generate]" >&2
      echo "  reads the value from stdin (hidden) unless --generate" >&2
      exit 2
    fi
    case "$name" in
      *[!A-Za-z0-9_]*) echo "NAME must be [A-Za-z0-9_] (env var safe)" >&2; exit 2 ;;
    esac
    repo="''${NIX_CONFIG_DIR:-$HOME/dev/shinkansen/local/nix-config}"
    tpl="$repo/secrets/secrets.tpl"
    [ -f "$tpl" ] || { echo "tpl not found: $tpl (set NIX_CONFIG_DIR)" >&2; exit 1; }
    op=${pkgs._1password-cli}/bin/op

    if [ "$mode" = "--generate" ]; then
      "$op" item create --category password --title "$name" \
        --vault Personal --generate-password >/dev/null
    else
      printf 'value for %s (hidden): ' "$name" >&2
      stty -echo 2>/dev/null || true
      IFS= read -r val
      stty echo 2>/dev/null || true
      echo >&2
      [ -n "$val" ] || { echo "empty value, aborted" >&2; exit 1; }
      "$op" item create --category password --title "$name" \
        --vault Personal "password=$val" >/dev/null
      unset val
    fi

    line="export $name=\"op://Personal/$name/password\""
    if grep -qF "op://Personal/$name/password" "$tpl"; then
      echo "pointer already in $tpl"
    else
      printf '%s\n' "$line" >> "$tpl"
      echo "appended pointer to $tpl"
    fi
    echo
    echo "next:"
    echo "  cd $repo && git add secrets/secrets.tpl && git commit -m \"secrets: add $name pointer\""
    echo "  nix run home-manager/master -- switch -b backup --flake .#\"saher@macbook\""
    echo "  secrets-refresh   # then open a new shell"
  '';
  # secret-set NAME [--generate]: update an EXISTING item's value. No tpl
  # change (pointer is unchanged), so no nix switch needed — just refresh.
  secret-set = pkgs.writeShellScriptBin "secret-set" ''
    set -eu
    name="''${1:-}"; mode="''${2:-}"
    [ -n "$name" ] || { echo "usage: secret-set NAME [--generate]" >&2; exit 2; }
    op=${pkgs._1password-cli}/bin/op
    if [ "$mode" = "--generate" ]; then
      "$op" item edit "$name" --vault Personal --generate-password >/dev/null
    else
      printf 'new value for %s (hidden): ' "$name" >&2
      stty -echo 2>/dev/null || true; IFS= read -r val; stty echo 2>/dev/null || true; echo >&2
      [ -n "$val" ] || { echo "empty, aborted" >&2; exit 1; }
      "$op" item edit "$name" --vault Personal "password=$val" >/dev/null
      unset val
    fi
    echo "updated $name in op. next: secrets-refresh ; new shell"
  '';

  # secret-rm NAME: delete the op item AND drop its pointer from the tpl.
  secret-rm = pkgs.writeShellScriptBin "secret-rm" ''
    set -eu
    name="''${1:-}"
    [ -n "$name" ] || { echo "usage: secret-rm NAME" >&2; exit 2; }
    repo="''${NIX_CONFIG_DIR:-$HOME/dev/shinkansen/local/nix-config}"
    tpl="$repo/secrets/secrets.tpl"
    op=${pkgs._1password-cli}/bin/op
    printf 'delete op item "%s" and its tpl pointer? [y/N] ' "$name" >&2
    read -r ans; [ "$ans" = y ] || [ "$ans" = Y ] || { echo aborted >&2; exit 1; }
    "$op" item delete "$name" --vault Personal >/dev/null && echo "deleted op item $name"
    if [ -f "$tpl" ] && grep -qF "op://Personal/$name/password" "$tpl"; then
      tmp=$(mktemp)
      grep -vF "op://Personal/$name/password" "$tpl" > "$tmp" && mv "$tmp" "$tpl"
      echo "removed pointer from $tpl"
    fi
    echo
    echo "next: cd $repo && git add secrets/secrets.tpl && git commit -m \"secrets: drop $name\""
    echo "  nix run home-manager/master -- switch -b backup --flake .#\"saher@macbook\""
    echo "  rm -f \"''${XDG_CACHE_HOME:-$HOME/.cache}/ring/secrets\" ; secrets-refresh ; new shell"
  '';

  # secret-ls: list the pointers currently declared (names only, no values).
  secret-ls = pkgs.writeShellScriptBin "secret-ls" ''
    set -eu
    repo="''${NIX_CONFIG_DIR:-$HOME/dev/shinkansen/local/nix-config}"
    tpl="$repo/secrets/secrets.tpl"
    [ -f "$tpl" ] || { echo "no tpl at $tpl" >&2; exit 1; }
    grep -oE 'op://Personal/[A-Za-z0-9_]+/' "$tpl" | sed 's|op://Personal/||;s|/||' | sort
  '';
in
{
  home.packages = [
    pkgs._1password-cli # `op`, nix-pinned (wins over Homebrew via PATH fix)
    secrets-refresh
    secret-add
    secret-set
    secret-rm
    secret-ls
  ];
}
