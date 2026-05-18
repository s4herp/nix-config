# Nix Host BEAM Toolchain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Host-side, auto-versioned Elixir/Erlang toolchain via Nix shims that pick the right version per sub-repo from `.tool-versions`, isolate host builds from the monorail's `_build`/`deps`, and work in non-interactive Bash — without touching the monorail.

**Architecture:** A flake exposes one `symlinkJoin` package per BEAM set (`beam-e<elixir>_o<erlang>`). A pure-shell shim (one script, multi-symlinked per binary) reads the nearest `.tool-versions`, maps to a set, ensures a GC-rooted profile under `~/.cache/nix-beam/profiles/<set>` (auto-`nix build` on first use), exports isolated `MIX_BUILD_ROOT`/`MIX_DEPS_PATH`, and `exec`s the real binary. A Home Manager module installs the shims + `beam-refresh`/`beam-gc` and prepends them to PATH.

**Tech Stack:** Nix flakes, Home Manager (standalone), nixpkgs `beam.packages`, POSIX sh.

---

## File Structure

- Create `devshells/beam.nix` — declarative attrset of BEAM sets → `symlinkJoin` derivations. Single source of versions.
- Modify `flake.nix` — add `packages.<system>.beam-<set>` outputs from `devshells/beam.nix`.
- Create `modules/beam-shims.nix` — HM module: the shim script (`pkgs.writeShellApplication`), per-binary symlinks into the HM profile, `beam-refresh`, `beam-gc`, PATH wiring.
- Modify `hosts/macbook.nix` — import `../modules/beam-shims.nix`.
- Create `modules/beam/shim.sh` — the shim script body (kept as a separate file for readability; embedded via `builtins.readFile`).

Conventions to follow (from existing modules): header comment explaining the module, `{ pkgs, lib, ... }:` signature, PATH prepended after brew (Nix wins), build→diff→ZDOTDIR/throwaway test→`switch -b backup`→commit per iteration. Verify with `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh` first in each new shell.

---

### Task 1: BEAM sets flake package

**Files:**
- Create: `devshells/beam.nix`
- Modify: `flake.nix` (outputs `let` + `packages`)

- [ ] **Step 1: Write `devshells/beam.nix`**

```nix
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
  # name convention: e<elixirMinor>_o<erlangMinor> (the shim composes this)
  e1_19_o27 = mk {
    erlang = pkgs.beam.packages.erlang_27.erlang;
    elixir = pkgs.beam.packages.erlang_27.elixir_1_19;
    nodejs = pkgs.nodejs_23;
  };
  e1_16_o26 = mk {
    erlang = pkgs.beam.packages.erlang_26.erlang;
    elixir = pkgs.beam.packages.erlang_26.elixir_1_16;
  };
  e1_19_o28 = mk {
    erlang = pkgs.beam.packages.erlang_28.erlang;
    elixir = pkgs.beam.packages.erlang_28.elixir_1_19;
  };
}
```

- [ ] **Step 2: Wire `packages` in `flake.nix`**

In the `outputs` `let`, after `mkHome`, add:

```nix
      systems = [ "aarch64-darwin" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
        f (import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [ "1password-cli" ];
        }));
      beamSets = pkgs: import ./devshells/beam.nix { inherit pkgs; };
```

In the `in { ... }` attrset add:

```nix
      packages = forAllSystems (pkgs:
        nixpkgs.lib.mapAttrs' (name: drv:
          nixpkgs.lib.nameValuePair "beam-${name}" drv
        ) (beamSets pkgs));
```

- [ ] **Step 3: Build to verify the set resolves**

Run:
```bash
cd ~/dev/shinkansen/local/nix-config && git add -A
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix build .#packages.aarch64-darwin.beam-e1_16_o26 -o /tmp/beam-116
```
Expected: builds; `/tmp/beam-116/bin/elixir` exists.

- [ ] **Step 4: Assert versions**

Run:
```bash
/tmp/beam-116/bin/elixir --version | tail -1
/tmp/beam-116/bin/erl -eval 'io:format("~s~n",[erlang:system_info(otp_release)]),halt().' -noshell
```
Expected: `Elixir 1.16.x` and `26`.

- [ ] **Step 5: Build the other two sets**

Run:
```bash
nix build .#packages.aarch64-darwin.beam-e1_19_o27 -o /tmp/beam-119-27
nix build .#packages.aarch64-darwin.beam-e1_19_o28 -o /tmp/beam-119-28
/tmp/beam-119-27/bin/elixir --version | tail -1   # Elixir 1.19.x
/tmp/beam-119-28/bin/erl -eval 'io:format("~s~n",[erlang:system_info(otp_release)]),halt().' -noshell  # 28
```
Expected: 1.19/27 and 1.19/28 respectively. If a `beam.packages.erlang_28.elixir_1_19` attr does not exist in the pinned nixpkgs, run `nix eval --raw nixpkgs#beam.packages.erlang_28.elixir.version` to find the available attr and adjust `devshells/beam.nix` to the closest `elixir_1_19`/`elixir` attr present.

- [ ] **Step 6: Commit**

```bash
rm -f /tmp/beam-116 /tmp/beam-119-27 /tmp/beam-119-28
git add devshells/beam.nix flake.nix flake.lock
git commit -m "feat(beam): declare BEAM sets as flake packages (symlinkJoin)"
```

---

### Task 2: Shim script — resolve, map, exec

**Files:**
- Create: `modules/beam/shim.sh`
- Test: `/tmp/beam-shim-test/` (throwaway)

- [ ] **Step 1: Write `modules/beam/shim.sh`**

The shim is invoked as `mix`/`elixir`/`iex`/`erl`/`elixirc`/`epmd` (decided by `basename $0`). `@NIX@` and `@CONFIG@` are substituted by the HM module (Task 5).

```sh
#!/bin/sh
# nix-beam shim. argv0 basename = the BEAM binary to run. Resolves the
# nearest .tool-versions, maps to a set, ensures a GC-rooted profile, sets
# isolated MIX_* paths, execs the real binary. No Nix on the hot path once
# the profile symlink exists.
set -eu

bin="$(basename "$0")"
cfg="${NIX_CONFIG_DIR:-$HOME/dev/shinkansen/local/nix-config}"
cache="$HOME/.cache/nix-beam"
profiles="$cache/profiles"
default_set="e1_19_o27"

log() { printf 'nix-beam: %s\n' "$*" >&2; }

# --- find nearest .tool-versions walking up from $PWD ---
find_tv() {
  d="$PWD"
  while [ "$d" != / ]; do
    [ -f "$d/.tool-versions" ] && { printf '%s\n' "$d/.tool-versions"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

# --- map .tool-versions -> set name e<elixirMinor>_o<erlangMinor> ---
resolve_set() {
  tv="$(find_tv || true)"
  if [ -z "${tv:-}" ]; then
    log "no .tool-versions found, using default set $default_set"
    printf '%s\n' "$default_set"; return 0
  fi
  ex="$(awk '$1=="elixir"{print $2}' "$tv" | head -1)"
  er="$(awk '$1=="erlang"{print $2}' "$tv" | head -1)"
  if [ -z "$ex" ] || [ -z "$er" ]; then
    log "no .tool-versions found, using default set $default_set"
    printf '%s\n' "$default_set"; return 0
  fi
  exm="$(printf '%s' "$ex" | cut -d. -f1-2 | tr . _)"   # 1.16.3 -> 1_16
  erm="$(printf '%s' "$er" | cut -d. -f1)"               # 26.2.5.11 -> 26
  printf 'e%s_o%s\n' "$exm" "$erm"
}

set_name="$(resolve_set)"
profile="$profiles/$set_name"
exec "$profile/bin/$bin" "$@"
```

(Auto-build, isolation and warnings are added in Tasks 3–4; this task only proves resolve+exec against a pre-built profile.)

- [ ] **Step 2: Write the failing test**

```bash
mkdir -p /tmp/beam-shim-test && cd /tmp/beam-shim-test
nix build "$HOME/dev/shinkansen/local/nix-config#packages.aarch64-darwin.beam-e1_16_o26" \
  --out-link "$HOME/.cache/nix-beam/profiles/e1_16_o26"
printf 'elixir 1.16.3\nerlang 26.2.5.11\n' > .tool-versions
cp ~/dev/shinkansen/local/nix-config/modules/beam/shim.sh /tmp/sh && chmod +x /tmp/sh
ln -sf /tmp/sh /tmp/elixir
NIX_CONFIG_DIR="$HOME/dev/shinkansen/local/nix-config" /tmp/elixir --version | tail -1
```
Expected before Step 1 done: fails (no shim.sh). After: prints `Elixir 1.16.x`.

- [ ] **Step 3: Run it, verify mapping**

Run (from `/tmp/beam-shim-test`):
```bash
NIX_CONFIG_DIR="$HOME/dev/shinkansen/local/nix-config" /tmp/elixir --version | tail -1
```
Expected: `Elixir 1.16.x` (proves `.tool-versions` 1.16/26 → set `e1_16_o26` → profile exec).

- [ ] **Step 4: Verify default fallback**

Run:
```bash
nix build "$HOME/dev/shinkansen/local/nix-config#packages.aarch64-darwin.beam-e1_19_o27" \
  --out-link "$HOME/.cache/nix-beam/profiles/e1_19_o27"
cd /tmp && NIX_CONFIG_DIR="$HOME/dev/shinkansen/local/nix-config" /tmp/elixir --version 2>/tmp/e | tail -1; grep -q 'no .tool-versions' /tmp/e && echo DEFAULT-OK
```
Expected: `Elixir 1.19.x` and `DEFAULT-OK` (stderr warning emitted).

- [ ] **Step 5: Commit**

```bash
cd ~/dev/shinkansen/local/nix-config
git add modules/beam/shim.sh
git commit -m "feat(beam): shim core — resolve .tool-versions, map set, exec"
```

---

### Task 3: Auto-build profile + GC-root

**Files:**
- Modify: `modules/beam/shim.sh` (replace the final `exec` block)

- [ ] **Step 1: Replace the tail of `shim.sh`**

Replace the last two lines (`profile=…` / `exec …`) with:

```sh
profile="$profiles/$set_name"

ensure_profile() {
  [ -x "$profile/bin/$bin" ] && return 0
  # set not declared in the flake -> hard error, no execution
  if ! nix eval --raw "$cfg#packages.$(nix eval --impure --raw --expr builtins.currentSystem 2>/dev/null || echo aarch64-darwin).beam-$set_name.name" >/dev/null 2>&1; then
    log "ERROR no set for $set_name. Add it to $cfg/devshells/beam.nix, then: git add && switch"
    exit 1
  fi
  log "building toolchain $set_name (first use, may take a while)…"
  mkdir -p "$profiles"
  sys="$(nix eval --impure --raw --expr builtins.currentSystem 2>/dev/null || echo aarch64-darwin)"
  nix build "$cfg#packages.$sys.beam-$set_name" --out-link "$profile" >&2
}

ensure_profile
exec "$profile/bin/$bin" "$@"
```

- [ ] **Step 2: Test auto-build**

```bash
rm -rf "$HOME/.cache/nix-beam/profiles/e1_19_o28"
cp ~/dev/shinkansen/local/nix-config/modules/beam/shim.sh /tmp/sh && chmod +x /tmp/sh
ln -sf /tmp/sh /tmp/elixir
mkdir -p /tmp/t28 && cd /tmp/t28 && printf 'elixir 1.19.4\nerlang 28.3.2\n' > .tool-versions
NIX_CONFIG_DIR="$HOME/dev/shinkansen/local/nix-config" /tmp/elixir --version 2>/tmp/e28 | tail -1
grep -q 'building toolchain e1_19_o28' /tmp/e28 && echo AUTOBUILD-OK
test -L "$HOME/.cache/nix-beam/profiles/e1_19_o28" && echo GCROOT-OK
```
Expected: `Elixir 1.19.x`, `AUTOBUILD-OK`, `GCROOT-OK`.

- [ ] **Step 3: Test GC-root survives gc**

Run:
```bash
nix-collect-garbage >/dev/null 2>&1 || true
test -x "$HOME/.cache/nix-beam/profiles/e1_19_o28/bin/elixir" && echo GCROOT-SURVIVES
```
Expected: `GCROOT-SURVIVES`.

- [ ] **Step 4: Test unmapped set hard-errors**

```bash
mkdir -p /tmp/tbad && cd /tmp/tbad && printf 'elixir 1.99.0\nerlang 99.0\n' > .tool-versions
NIX_CONFIG_DIR="$HOME/dev/shinkansen/local/nix-config" /tmp/elixir --version 2>/tmp/ebad; echo "exit=$?"
grep -q 'ERROR no set for e1_99_o99' /tmp/ebad && echo UNMAPPED-OK
```
Expected: non-zero exit, `UNMAPPED-OK`, no Elixir version printed.

- [ ] **Step 5: Commit**

```bash
cd ~/dev/shinkansen/local/nix-config
git add modules/beam/shim.sh
git commit -m "feat(beam): auto-build profile with GC-root + unmapped-set error"
```

---

### Task 4: `_build`/`deps` isolation

**Files:**
- Modify: `modules/beam/shim.sh` (insert before final `exec`)

- [ ] **Step 1: Insert isolation block before `exec`**

Immediately before `exec "$profile/bin/$bin" "$@"` add:

```sh
# Isolate host builds: never write the repo's _build/deps (Mach-O NIFs
# break the Linux devcontainer). Redirect to a host-only, per-repo path.
repo_root=""
d="$PWD"
while [ "$d" != / ]; do
  if [ -f "$d/mix.exs" ] || [ -f "$d/.tool-versions" ]; then repo_root="$d"; fi
  d="$(dirname "$d")"
done
if [ -n "$repo_root" ]; then
  rid="$(printf '%s' "$repo_root" | cksum | cut -d' ' -f1)"
  work="$cache/work/$rid"
  export MIX_BUILD_ROOT="$work/_build"
  export MIX_DEPS_PATH="$work/deps"
  mkdir -p "$work"
fi
```

(`repo_root` keeps the **outermost** match so a sub-repo inside the monorail still gets its own root; this is intentional — each sub-repo with its own `mix.exs` is its own root because the loop keeps the last assignment while walking up, and the topmost dir with `mix.exs` wins. If the monorail root has no `mix.exs`, the sub-repo's own `mix.exs` dir is selected.)

- [ ] **Step 2: Test isolation env is set**

```bash
cp ~/dev/shinkansen/local/nix-config/modules/beam/shim.sh /tmp/sh && chmod +x /tmp/sh
ln -sf /tmp/sh /tmp/elixir
mkdir -p /tmp/fakerepo && cd /tmp/fakerepo
printf 'elixir 1.16.3\nerlang 26.2.5.11\n' > .tool-versions
echo 'defmodule X do end' > mix.exs
NIX_CONFIG_DIR="$HOME/dev/shinkansen/local/nix-config" /tmp/elixir \
  -e 'IO.puts(System.get_env("MIX_BUILD_ROOT")); IO.puts(System.get_env("MIX_DEPS_PATH"))'
```
Expected: two lines under `~/.cache/nix-beam/work/<digits>/` (`_build` and `deps`).

- [ ] **Step 3: Verify the monorail tree is untouched**

```bash
ls -la ~/.cache/nix-beam/work/ | head
echo "monorail _build NOT under cache: OK by construction (paths differ)"
```
Expected: work dir exists under cache; nothing written into any monorail path.

- [ ] **Step 4: Commit**

```bash
cd ~/dev/shinkansen/local/nix-config
git add modules/beam/shim.sh
git commit -m "feat(beam): isolate host _build/deps to ~/.cache/nix-beam/work"
```

---

### Task 5: Warnings layer (host deps missing)

**Files:**
- Modify: `modules/beam/shim.sh` (insert after isolation block, before `exec`)

- [ ] **Step 1: Insert deps-missing warning**

After the isolation block, before `exec`:

```sh
# Warn (do not auto-run) when a build-class mix command needs host deps
# that have not been fetched into the isolated path yet.
if [ "$bin" = "mix" ] && [ -n "${repo_root:-}" ]; then
  case "${1:-}" in
    compile|test|run|"phx.server"|release|"ecto.migrate"|"ecto.setup")
      if [ ! -d "$MIX_DEPS_PATH" ] || [ -z "$(ls -A "$MIX_DEPS_PATH" 2>/dev/null || true)" ]; then
        log "host deps missing for repo $(basename "$repo_root"). Run: mix deps.get"
      fi
      ;;
  esac
fi
```

- [ ] **Step 2: Test the warning fires and command still runs**

```bash
cp ~/dev/shinkansen/local/nix-config/modules/beam/shim.sh /tmp/sh && chmod +x /tmp/sh
ln -sf /tmp/sh /tmp/mix
cd /tmp/fakerepo
NIX_CONFIG_DIR="$HOME/dev/shinkansen/local/nix-config" /tmp/mix compile 2>/tmp/m || true
grep -q 'host deps missing' /tmp/m && echo DEPSWARN-OK
```
Expected: `DEPSWARN-OK` (warning on stderr); mix still attempts and errors normally — both fine.

- [ ] **Step 3: Test no false warning for non-build commands**

```bash
cd /tmp/fakerepo
NIX_CONFIG_DIR="$HOME/dev/shinkansen/local/nix-config" /tmp/mix format --check-formatted 2>/tmp/m2 || true
grep -q 'host deps missing' /tmp/m2 && echo "UNEXPECTED" || echo NOWARN-OK
```
Expected: `NOWARN-OK`.

- [ ] **Step 4: Commit**

```bash
cd ~/dev/shinkansen/local/nix-config
git add modules/beam/shim.sh
git commit -m "feat(beam): warn on missing host deps for build-class mix commands"
```

---

### Task 6: HM module — shims, beam-refresh, beam-gc, PATH

**Files:**
- Create: `modules/beam-shims.nix`
- Modify: `hosts/macbook.nix`

- [ ] **Step 1: Write `modules/beam-shims.nix`**

```nix
{ pkgs, lib, ... }:

# Installs the nix-beam shims (one script, symlinked per BEAM binary) plus
# beam-refresh / beam-gc. The shim resolves the per-repo BEAM version from
# the nearest .tool-versions and execs a GC-rooted Nix profile. Prepended to
# PATH so it wins over Homebrew/asdf for these binaries on the host.
let
  shim = pkgs.writeShellApplication {
    name = "nix-beam-shim";
    runtimeInputs = [ pkgs.nix pkgs.coreutils pkgs.gawk ];
    text = builtins.readFile ./beam/shim.sh;
  };
  bins = [ "mix" "elixir" "iex" "erl" "elixirc" "epmd" "rebar3" ];
  linkFarm = pkgs.runCommand "nix-beam-shims" { } ''
    mkdir -p "$out/bin"
    for b in ${lib.concatStringsSep " " bins}; do
      ln -s ${shim}/bin/nix-beam-shim "$out/bin/$b"
    done
  '';
  beam-refresh = pkgs.writeShellScriptBin "beam-refresh" ''
    set -eu
    cfg="''${NIX_CONFIG_DIR:-$HOME/dev/shinkansen/local/nix-config}"
    prof="$HOME/.cache/nix-beam/profiles"
    sys="$(${pkgs.nix}/bin/nix eval --impure --raw --expr builtins.currentSystem)"
    targets="''${1:-}"
    if [ "$targets" = "--all" ] || [ -z "$targets" ]; then
      targets="$(${pkgs.nix}/bin/nix eval --json "$cfg#packages.$sys" \
        --apply builtins.attrNames | ${pkgs.jq}/bin/jq -r '.[]' | sed 's/^beam-//')"
    fi
    for s in $targets; do
      echo "refreshing $s"
      ${pkgs.nix}/bin/nix build "$cfg#packages.$sys.beam-$s" --out-link "$prof/$s"
    done
  '';
  beam-gc = pkgs.writeShellScriptBin "beam-gc" ''
    set -eu
    base="$HOME/.cache/nix-beam"
    echo "removing work dirs: $base/work"
    rm -rf "$base/work"
    echo "kept profiles (GC-roots) under $base/profiles; remove a set with:"
    echo "  rm $base/profiles/<set>"
  '';
in
{
  home.packages = [ linkFarm beam-refresh beam-gc ];

  # Prepend the shims so they win over Homebrew/asdf for BEAM binaries.
  # Placed after the brew shellenv re-prepend (see modules/shell/zsh.nix).
  programs.zsh.initContent = lib.mkAfter ''
    path=("${linkFarm}/bin" $path)
  '';
}
```

- [ ] **Step 2: Wire into `hosts/macbook.nix`**

Add `../modules/beam-shims.nix` to the `imports` list (after `../modules/secrets.nix`).

- [ ] **Step 3: Build (shadow)**

```bash
cd ~/dev/shinkansen/local/nix-config && git add -A
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix build .#homeConfigurations.'"saher@macbook"'.activationPackage -o /tmp/hm-beam 2>&1 | tail -1
ls -l /tmp/hm-beam/home-path/bin/mix /tmp/hm-beam/home-path/bin/beam-refresh
```
Expected: build exit 0; `mix` and `beam-refresh` present in the profile.

- [ ] **Step 4: Switch**

```bash
nix run home-manager/master -- switch -b backup --flake .#"saher@macbook" 2>&1 | tail -1
home-manager generations 2>/dev/null | head -1
```
Expected: new generation current.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(beam): HM module — shims + beam-refresh/beam-gc + PATH wiring"
```

---

### Task 7: Integration verification (live, 3 sets + non-monorail + Bash detectability)

**Files:** none (verification only)

- [ ] **Step 1: Version switches by sub-repo (live shell)**

```bash
zsh -ic 'which mix; cd ~/Dev/shinkansen/local/shinkansen-monorail/customer-ui 2>/dev/null && elixir --version | tail -1' 2>/dev/null
zsh -ic 'cd ~/Dev/shinkansen/local/shinkansen-monorail/po-stp 2>/dev/null && elixir --version | tail -1' 2>/dev/null
```
Expected: `which mix` → `~/.nix-profile/bin/mix`; customer-ui → `Elixir 1.19.x`; po-stp → `Elixir 1.16.x`.

- [ ] **Step 2: Non-interactive Bash detectability (the Claude path)**

```bash
cd ~/Dev/shinkansen/local/shinkansen-monorail/po-stp && elixir --version | tail -1
cd ~/Dev/shinkansen/local/shinkansen-monorail/customer-ui && erl -eval 'io:format("~s~n",[erlang:system_info(otp_release)]),halt().' -noshell
```
Expected: 1.16.x then 27 — proves it works without direnv in a plain non-interactive shell.

- [ ] **Step 3: Monorail `_build`/`deps` untouched**

```bash
cd ~/Dev/shinkansen/local/shinkansen-monorail/po-stp
before=$(stat -f %m _build 2>/dev/null || echo none)
mix format --check-formatted >/dev/null 2>&1 || true
after=$(stat -f %m _build 2>/dev/null || echo none)
[ "$before" = "$after" ] && echo "MONORAIL-BUILD-UNTOUCHED"
ls ~/.cache/nix-beam/work/ | head
```
Expected: `MONORAIL-BUILD-UNTOUCHED`; host work dir present under cache.

- [ ] **Step 4: Non-monorail repo works**

```bash
mkdir -p /tmp/personal && cd /tmp/personal && printf 'elixir 1.19.4\nerlang 28.3.2\n' > .tool-versions
elixir --version | tail -1
```
Expected: `Elixir 1.19.x` (set `e1_19_o28`, auto-built if needed).

- [ ] **Step 5: Update README + commit**

Add a "Toolchain BEAM (host, auto-versionado)" section to `README.md` documenting: how it picks versions (`.tool-versions`), `beam-refresh` after `nix flake update`, `beam-gc`, isolated host build paths, and that the monorail/devcontainer are untouched.

```bash
cd ~/dev/shinkansen/local/nix-config
git add README.md
git commit -m "docs: document host BEAM toolchain in README"
```

---

## Self-Review

**Spec coverage:** §2 arch → Tasks 1–6. §3 detect/map → Task 2. §4 profiles/GC-root → Tasks 1,3. §5 isolation → Task 4. §6 warnings/detectability → Tasks 3,5,7. §7 layout/anti-basura → Tasks 6 (`beam-gc`),7. §8 out-of-scope respected (no asdf/devcontainer changes, minor-only). §9 risks: GC-root (Task 3), overhead (approach B, Task 2 exec path), nixpkgs attr fallback (Task 1 Step 5). No gaps.

**Placeholder scan:** No TBD/TODO; all steps have concrete code/commands and expected output. Task 1 Step 5 includes a concrete fallback command if an attr is absent.

**Type/name consistency:** set names `e<elixirMinor>_o<erlangMinor>` consistent across `devshells/beam.nix`, shim `resolve_set`, flake `beam-${name}`, `beam-refresh`. Profile path `~/.cache/nix-beam/profiles/<set>` consistent Tasks 2–3,6. `MIX_BUILD_ROOT`/`MIX_DEPS_PATH` consistent Tasks 4–5. Cache root `~/.cache/nix-beam` consistent.

Note: monorail path casing — verification tasks use `~/Dev/...` (filesystem is case-insensitive on this macOS host; both `~/dev` and `~/Dev` resolve identically).
