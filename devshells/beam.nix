{ pkgs }:

# Declarative BEAM sets. Each set -> a symlinkJoin with bin/ ready to exec
# (NOT a devShell; the shim execs the path directly). Minor-exact; the patch
# is whatever flake.lock pins. Add a set = one entry here + git add + switch.
let
  mk = { erlang, elixir, nodejs ? null }:
    pkgs.symlinkJoin {
      name = "beam-${erlang.version}-${elixir.version}";
      paths = [ erlang elixir pkgs.rebar3 ]
        ++ pkgs.lib.optional (nodejs != null) nodejs;
    };
in
{
  e1_19_o27 = mk {
    erlang = pkgs.beam.packages.erlang_27.erlang;
    elixir = pkgs.beam.packages.erlang_27.elixir_1_19;
    # Pinned nixpkgs has no nodejs_23; closest available is nodejs_24.
    nodejs = pkgs.nodejs_24;
  };
  # Pinned nixpkgs no longer ships Erlang 26 (EOL, removed) nor Elixir 1.16.
  # Closest available legacy set: Erlang 27 + Elixir 1.17.
  e1_16_o26 = mk {
    erlang = pkgs.beam.packages.erlang_27.erlang;
    elixir = pkgs.beam.packages.erlang_27.elixir_1_17;
  };
  e1_19_o28 = mk {
    erlang = pkgs.beam.packages.erlang_28.erlang;
    elixir = pkgs.beam.packages.erlang_28.elixir_1_19;
  };
}
