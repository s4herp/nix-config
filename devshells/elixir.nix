{ pkgs }:

# Elixir/Phoenix devShell (dossier §5.5, M4). Activated per project via an
# .envrc containing:
#   use flake ~/dev/shinkansen/local/nix-config#elixir
# nix-direnv (modules/direnv.nix) caches it with a GC root so it does not
# re-evaluate on every cd.
#
# Coexists with the monorail asdf toolchain: this only engages where an
# .envrc opts in; the shared monorail repo keeps using asdf (dossier §5.5,
# not replaced here). Versions mirror the host stack (Erlang 27 active,
# Node 23.10 from ~/.tool-versions); bump deliberately, flake.lock anchors
# the rest.

let
  erlang = pkgs.beam.packages.erlang_27;
  elixir = erlang.elixir_1_18;
in
pkgs.mkShell {
  packages = [
    erlang.erlang
    elixir
    erlang.rebar3
    pkgs.nodejs_23
    pkgs.postgresql_16
    pkgs.git
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
    pkgs.inotify-tools # file-watching for Phoenix live reload on Linux
  ];

  shellHook = ''
    export MIX_HOME="$PWD/.nix-mix"
    export HEX_HOME="$PWD/.nix-hex"
    export PATH="$MIX_HOME/bin:$HEX_HOME/bin:$PATH"
    export ERL_AFLAGS="-kernel shell_history enabled"
    echo "elixir devShell: $(elixir --version | tail -1), node $(node --version), pg $(pg_config --version)"
  '';
}
