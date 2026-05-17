# Nix Bootstrap (Phase 0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Nix on Bazzite and stand up a minimal, working flake-based Home Manager configuration that manages one trivial package, plus obtain the macOS dotfiles as the source-of-truth reference for later native-rewrite phases.

**Architecture:** Single flake (approach A) with `homeConfigurations."saher@bazzite"` for `x86_64-linux`. Determinate Systems installer (flakes enabled, atomic-OS safe). Home Manager standalone (no NixOS, no nix-darwin). This plan delivers Phase 0 only; it is independently valuable and testable (a working `home-manager switch` on Bazzite).

**Tech Stack:** Nix (Determinate installer), Nix flakes, Home Manager (nix-community), git.

---

## Plan series context

This is **Plan 1 of 7**, per the approved spec
(`docs/superpowers/specs/2026-05-17-nix-dotfiles-multiplatform-design.md`):

| Plan | Spec phase | Status | Blocking input |
|---|---|---|---|
| **1 — Bootstrap (this)** | Phase 0 | now | none |
| 2 — Core shell (Bazzite) | Phase 1 | later | macOS dotfile contents (Task 6 here) |
| 3 — Neovim 2b | Phase 2 | later | macOS nvim config + lazy-lock.json |
| 4 — Secrets via op | Phase 3 | later | Plan 2 done |
| 5 — devShells + direnv | Phase 4 | later | Plan 1 done |
| 6 — Cachix | Phase 5 | later | Plans 2-4 done |
| 7 — macOS cutover | Phase 6 | later | Plans 2-6 done |

**Adaptation note (TDD → Nix):** there is no pytest here. The TDD loop is
adapted faithfully: *define the verification command → run it to confirm the
current absent/failing state → implement the Nix code → run the verification to
confirm → commit.* "Test fails" means "the capability is absent / build errors";
"test passes" means "the verification command produces the expected output".

---

## File structure

| File | Responsibility |
|---|---|
| `~/dev/nix-config/flake.nix` | Flake inputs (nixpkgs, home-manager) + `homeConfigurations."saher@bazzite"` output |
| `~/dev/nix-config/flake.lock` | Generated lock — the reproducibility anchor |
| `~/dev/nix-config/.gitignore` | Already exists (excludes `result`, caches) — extend if needed |
| `~/dev/nix-config/reference/` | (Task 6) read-only copy of the macOS dotfiles, source of truth for Plans 2-3. Git-ignored. |

The repo `~/dev/nix-config` already exists with the spec committed (commit
`60259d6`). All work happens there.

---

## Task 1: Install Nix via the Determinate Systems installer

**Files:** none (system-level install).

- [ ] **Step 1: Verify Nix is currently absent (the "failing test")**

Run:
```bash
command -v nix || echo "NIX-ABSENT"
```
Expected: prints `NIX-ABSENT` (confirms clean starting state on Bazzite).

- [ ] **Step 2: Run the Determinate installer**

This command is **interactive and requires sudo**. In a Claude Code session the
user should run it with the `!` prefix so its output lands in the conversation;
a human executor runs it directly in a terminal.

Run:
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```
Expected: installer prints a plan, asks for confirmation, performs the install,
ends with `Nix was installed successfully!`. It creates `/nix`, a `nix-daemon`,
and enables `nix-command flakes` experimental features by default. It does **not**
modify the Bazzite rpm-ostree image.

- [ ] **Step 3: Open a fresh shell and verify Nix is on PATH (the "passing test")**

Run (in a new shell, or after `source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`):
```bash
nix --version && nix config show experimental-features
```
Expected: prints a `nix (Nix) X.Y.Z` version line, and the experimental-features
line includes `nix-command` and `flakes`.

- [ ] **Step 4: No commit** (system install, nothing in the repo changed).

---

## Task 2: Confirm the canonical home directory and username

**Files:** none (gathering values needed for `flake.nix`).

- [ ] **Step 1: Read the runtime values**

Run:
```bash
echo "HOME=$HOME"; echo "USER=$USER"; id -un
```
Expected: `USER` / `id -un` is `saherpinero`. `HOME` is most likely
`/var/home/saherpinero` (Bazzite atomic uses `/var/home`; `/home` is a symlink).

- [ ] **Step 2: Record the exact `$HOME` value**

Whatever `echo $HOME` printed verbatim is the value to use for
`home.homeDirectory` in Task 3. Home Manager **fails** if `home.homeDirectory`
does not match `$HOME` at activation. Do not guess — use the printed value.
For the rest of this plan it is written as `<HOME>` and `saherpinero` as
`<USER>`; substitute the verified values literally when editing files.

- [ ] **Step 3: No commit** (no file changes).

---

## Task 3: Create the minimal flake

**Files:**
- Create: `~/dev/nix-config/flake.nix`

- [ ] **Step 1: Verify the flake is absent (the "failing test")**

Run:
```bash
cd ~/dev/nix-config && nix flake show 2>&1 | head -1
```
Expected: an error mentioning no `flake.nix` found (confirms absent state).

- [ ] **Step 2: Determine the correct `home.stateVersion`**

Run:
```bash
nix run home-manager/master -- --version
```
Expected: prints a version like `25.05` or a git rev. `home.stateVersion` is a
**compatibility marker set once and never changed afterward**; set it to the
current Home Manager release series (the `XX.YY` shown, e.g. `25.05`). It is not
a version to "upgrade". Write it as `<STATE_VERSION>` below and substitute the
real value (e.g. `"25.05"`).

- [ ] **Step 3: Write `flake.nix`**

Create `~/dev/nix-config/flake.nix` with exactly this content, substituting
`<HOME>`, `<USER>`, `<STATE_VERSION>` with the values verified in Tasks 2-3:

```nix
{
  description = "Saher's cross-platform Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      mkHome =
        { system, username, homeDirectory }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            (
              { pkgs, ... }:
              {
                home.username = username;
                home.homeDirectory = homeDirectory;
                home.stateVersion = "<STATE_VERSION>";
                programs.home-manager.enable = true;

                # Phase 0 smoke test: exactly one trivial package.
                # Real package sets arrive in Plan 2 (Phase 1).
                home.packages = [ pkgs.hello ];
              }
            )
          ];
        };
    in
    {
      homeConfigurations."saher@bazzite" = mkHome {
        system = "x86_64-linux";
        username = "<USER>";
        homeDirectory = "<HOME>";
      };
    };
}
```

- [ ] **Step 4: Verify the flake evaluates (the "passing test")**

Run:
```bash
cd ~/dev/nix-config && git add flake.nix && nix flake show
```
Expected: shows the flake tree including
`homeConfigurations` → `saher@bazzite`. (`git add` is required because flakes
only see files tracked by git.) No evaluation errors.

- [ ] **Step 5: Commit**

```bash
cd ~/dev/nix-config
git add flake.nix flake.lock
git commit -m "Add minimal flake with bazzite home configuration"
```
Note: `nix flake show` generates `flake.lock`; if it is not yet present, run
`nix flake lock` before this commit so the lock (the reproducibility anchor) is
versioned.

---

## Task 4: Activate the Home Manager configuration

**Files:** none (activation; may create `~/.config` backups).

- [ ] **Step 1: Verify `hello` is not yet available (the "failing test")**

Run:
```bash
command -v hello || echo "HELLO-ABSENT"
```
Expected: prints `HELLO-ABSENT`.

- [ ] **Step 2: Build without activating (shadow validation)**

Run:
```bash
cd ~/dev/nix-config && nix build .#homeConfigurations.'"saher@bazzite"'.activationPackage
```
Expected: builds successfully, creates a `result` symlink. `$HOME` is **not**
modified by a build. If this fails, fix `flake.nix` before proceeding — never
run `switch` on a config that does not build.

- [ ] **Step 3: Activate with conflict backup enabled**

Run:
```bash
cd ~/dev/nix-config && nix run home-manager/master -- switch -b backup --flake .#"saher@bazzite"
```
Expected: ends with `Activating ...` and no errors. The `-b backup` flag means
any pre-existing file Home Manager would manage is renamed to `*.backup` instead
of causing a hard failure (the spec's documented safety procedure).

- [ ] **Step 4: Verify `hello` is now managed by Nix (the "passing test")**

Run:
```bash
hello && readlink -f "$(command -v hello)"
```
Expected: prints `Hello, world!`, and the resolved path is under
`/nix/store/...-hello-*/bin/hello`. This proves the flake-based Home Manager
round-trip works end to end on Bazzite.

- [ ] **Step 5: No commit** (activation produces no repo changes; `flake.lock`
was already committed in Task 3).

---

## Task 5: Verify reproducibility primitives and rollback

**Files:** none (verification only).

- [ ] **Step 1: Confirm generations and rollback exist (the "failing test" is
absence of a second generation)**

Run:
```bash
nix run home-manager/master -- generations
```
Expected: lists at least one generation with a date and store path. This
confirms the atomic-rollback mechanism the spec relies on (§9) is in place.

- [ ] **Step 2: Confirm `home-manager` is itself now on PATH**

Run:
```bash
command -v home-manager && home-manager --version
```
Expected: resolves to a `/nix/store` path (installed via
`programs.home-manager.enable = true`), prints a version. Subsequent phases can
use `home-manager switch --flake .#"saher@bazzite"` directly.

- [ ] **Step 3: Record the reproducibility anchor**

Run:
```bash
cd ~/dev/nix-config && nix flake metadata --json | nix run nixpkgs#jq -- -r '.locks.nodes.nixpkgs.locked.rev'
```
Expected: prints a 40-char commit hash — the exact `nixpkgs` revision both
machines will resolve. Note it in the commit message of Task 6 for traceability.

- [ ] **Step 4: No commit** (verification only).

---

## Task 6: Obtain the macOS dotfiles as the read-only reference

**Files:**
- Create: `~/dev/nix-config/reference/` (git-ignored copy of macOS dotfiles)
- Modify: `~/dev/nix-config/.gitignore`

This task unblocks Plans 2-3 (native rewrite of zsh/tmux/git/nvim). The dotfile
**contents** live in the macOS bare-repo `~/.cfg` and are not present on
Bazzite. Acquiring them requires a cross-machine action.

- [ ] **Step 1: Verify the reference is absent (the "failing test")**

Run:
```bash
ls ~/dev/nix-config/reference 2>/dev/null || echo "REFERENCE-ABSENT"
```
Expected: prints `REFERENCE-ABSENT`.

- [ ] **Step 2 (performed on the macOS machine): publish the bare-repo**

On macOS, push the dotfiles bare-repo to a private remote the Bazzite machine
can reach (e.g. a private GitHub repo). Exact commands on macOS:
```bash
git --git-dir="$HOME/.cfg/" --work-tree="$HOME" remote add origin git@github.com:<your-private>/dotfiles.git
git --git-dir="$HOME/.cfg/" --work-tree="$HOME" push -u origin HEAD
```
Alternative if no remote is desired: from Bazzite, `rsync` the rendered files:
```bash
rsync -av --files-from=<list> macos-host:~/ ~/dev/nix-config/reference/
```
Expected: the dotfile contents (`.zshrc`, `.tmux.conf`, `~/.config/nvim/`,
`~/.config/git/config`, etc.) become reachable from Bazzite.

- [ ] **Step 3: Ignore the reference directory (it is not the config, only input)**

Append to `~/dev/nix-config/.gitignore`:
```
/reference/
```

- [ ] **Step 4: Materialize the reference on Bazzite**

Run (using whichever transport from Step 2 applies), e.g. clone into a worktree:
```bash
mkdir -p ~/dev/nix-config/reference
git clone git@github.com:<your-private>/dotfiles.git ~/dev/nix-config/reference/dotfiles
```

- [ ] **Step 5: Verify the reference is present (the "passing test")**

Run:
```bash
test -s ~/dev/nix-config/reference/dotfiles/.zshrc \
  && test -s ~/dev/nix-config/reference/dotfiles/.tmux.conf \
  && echo "REFERENCE-OK"
```
Expected: prints `REFERENCE-OK`. (Adjust paths to match the bare-repo layout;
the requirement is that `.zshrc`, `.tmux.conf`, the nvim config tree, and the
git config are readable on Bazzite.)

- [ ] **Step 6: Commit the gitignore change**

```bash
cd ~/dev/nix-config
git add .gitignore
git commit -m "Ignore reference/ (macOS dotfiles input for native rewrite)

nixpkgs pinned at <REV from Task 5 Step 3>"
```

---

## Self-review

**1. Spec coverage (Phase 0 scope only — this plan is Plan 1 of 7):**
- Spec §8 Fase 0 "Nix (Determinate) en Bazzite" → Task 1. ✓
- Spec §8 Fase 0 "flake mínimo con homeConfigurations vacío" → Task 3. ✓
- Spec §8 Fase 0 exit "`home-manager switch` instala paquete trivial; `which
  eza`→/nix/store" → Task 4 (uses `hello` as the trivial package; functionally
  identical to the `eza` exit check — store-path resolution proven). ✓
- Spec §6.1/§12 "flake único enfoque A, flake.lock ancla" → Tasks 3, 5. ✓
- Spec §9 "rollback vía generaciones" reproducibility primitive → Task 5. ✓
- Spec §5 "config canónica en macOS, Bazzite greenfield" → Task 6 acquires the
  reference that Plans 2-3 require. ✓
- Phases 1-6 are explicitly out of scope for this plan (plan series table). ✓

**2. Placeholder scan:** `<HOME>`, `<USER>`, `<STATE_VERSION>`, `<REV>`,
`<your-private>` are **substitution markers with an explicit task step that
produces the real value** (Tasks 2, 3, 5), not TODOs — acceptable. No "TBD",
no "add error handling", no undefined references.

**3. Type/identifier consistency:** flake attribute `homeConfigurations."saher@
bazzite"` is used identically in Tasks 3, 4, 5. `mkHome` signature
(`{ system, username, homeDirectory }`) matches its single call site. The
trivial package is `pkgs.hello` consistently in Tasks 3-4.

No issues found.
