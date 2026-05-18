# Informe de implementación — Nix + Home Manager multiplataforma

> **Documento de handoff autocontenido.** Reúne diseño, decisiones,
> inventario de las dos máquinas, plan de ejecución macOS-first y el bloqueo
> verificado de Bazzite. Pensado para que **Saher lo ejecute por su cuenta**.
> Complementa (no reemplaza) el spec
> `docs/superpowers/specs/2026-05-17-nix-dotfiles-multiplatform-design.md` y el
> `docs/superpowers/plans/2026-05-17-nix-bootstrap.md`.

- **Fecha:** 2026-05-17
- **Autor:** Saher Pinero
- **Repo de trabajo:** `~/dev/nix-config` (reemplazará al bare-repo `~/.cfg`)

---

## 0. Cómo usar este documento

1. Lee §1 (resumen y secuenciación) y §3 (decisiones cerradas) para el marco.
2. Ejecuta la **Pista macOS** (§5) paso a paso en el Mac.
3. Cuando quieras llevarlo a Bazzite, ve a la **Pista Bazzite** (§6): está
   **bloqueada** por un problema verificado de composefs; ahí está la
   evidencia y los caminos a investigar (no un fix inventado).
4. §7 (secretos), §8 (verificación), §9 (riesgos) aplican a ambas.
5. Apéndice A: salidas de diagnóstico exactas capturadas el 2026-05-17.

Convención: comandos que necesitan tu intervención interactiva (sudo, login)
van marcados **[MANUAL]**.

---

## 1. Resumen ejecutivo y secuenciación

**Objetivo:** un único flake de Nix + **Home Manager standalone** que produzca
un entorno de usuario reproducible e idéntico en macOS (Apple Silicon, máquina
de trabajo principal) y Bazzite (Fedora Atómico, `x86_64-linux`), reemplazando
el bare-repo `~/.cfg` + Homebrew + asdf.

**Cambio de secuencia (2026-05-17):** la estrategia original era *Bazzite-first*
(no arriesgar la máquina de trabajo). Tras verificar que **Bazzite está
bloqueado** por composefs (§6), y por decisión explícita del usuario, se pasa a
**macOS-first**:

| | Antes | Ahora |
|---|---|---|
| Primera máquina | Bazzite (greenfield) | **macOS** (máquina de trabajo) |
| Riesgo | bajo (Bazzite desechable) | **alto: se itera sobre la máquina de trabajo** |
| Salvaguardas | recomendadas | **OBLIGATORIAS** (§5.0) |
| Bazzite | campo de pruebas | diferido hasta resolver composefs (§6) |

El diseño es portable: el mismo flake sirve a ambas máquinas vía
`homeConfigurations."saher@<host>"`; macOS no depende de Bazzite.

---

## 2. Inventario de máquinas

### 2.1 macOS — máquina de trabajo principal

Fuente: informe `~/Downloads/2026-05-17-herramientas-de-desarrollo.md`.

- **SO:** macOS, Darwin 25.4.0, Apple Silicon (`aarch64-darwin`). Shell por
  defecto `/bin/zsh`.
- **Gestión actual:** Homebrew (CLIs + casks) + **asdf** (`~/.tool-versions`:
  Erlang 27.3.4.6, Ruby 3.1.4, Node 23.10.0, Python 3.10.14, Java Temurin
  21.0.9, Maven 3.9.6) + bare-repo git `~/.cfg` para dotfiles.
- **Stack real:** Elixir/Phoenix LiveView (monorail Shinkansen).
- **Dotfiles versionados** (`~/.cfg`): `.zshrc` (15 secciones, p10k instant
  prompt, antidote, fzf-tab, atuin, zoxide, direnv, lazy-load conda/nvm),
  `.zshenv`, `.zprofile`, `.zsh_plugins.txt`, `.tmux.conf` (prefix C-Space,
  Catppuccin mocha, TPM, resurrect, easymotion, extrakto), `~/.config/nvim`
  (kickstart-style, lazy.nvim ~50 plugins, ElixirLS, Telescope, Harpoon),
  `~/.config/ghostty/config`, `~/.config/git/config` (firma GPG
  `BF390DAAE816840D`, identidades condicionales shinkansen/mudango).
- **Secretos hoy:** `~/.zsh_secrets`, `~/.zshrc.local` (cargados si existen),
  token de Raycast.
- **Apps GUI (fuera de alcance Nix):** Karabiner-Elements (Caps→Hyper), Raycast
  (lanzador + tiling), Shortcat, DBeaver, Obsidian, Ghostty (terminal activo).

### 2.2 Bazzite — máquina secundaria (verificado en vivo 2026-05-17)

**Hardware** (de memoria de usuario):
- CPU AMD Ryzen 7 5800X (8c/16t), 46 GB RAM, GPU NVIDIA RTX 3090 Ti (24 GB,
  nvidia-open), NVMe 930 GB, swap 15 GB.

**Sistema operativo (medido):**
- Imagen: `ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-nvidia:stable`
- Versión: **44.20260515** (2026-05-15), digest
  `sha256:bf99b0d893795baca379579756872cf4d04d7df003c68ddc48f6dc20da94a3f5`
- Kernel: `6.19.14-ogc5.1.fc44.x86_64`
- **Root filesystem: `composefs overlay ro`** ← causa del bloqueo (§6)
- `LayeredPackages`: `1password ghostty grim tesseract tesseract-langpack-spa
  wtype xclip xterm`
- Desktop: KDE Plasma / Wayland.

**Estado actual del usuario en Bazzite (medido):**
- `USER=saherpinero`; `$HOME=/home/saherpinero` (symlink) — el canónico es
  `/var/home/saherpinero` (el instalador escribió `/var/home/nix`). **Verificar
  `echo $HOME` al implementar**; HM exige que `home.homeDirectory` coincida.
- Shell de `passwd`: `/bin/bash`. Shell interactivo actual:
  `/home/linuxbrew/.linuxbrew/bin/zsh` → **linuxbrew instalado como apaño
  parcial**; se retira en la fase de shell.
- **Nix: ausente.** Sin `/nix`, sin `/var/home/nix`, sin units residuales (el
  instalador revirtió limpio). Sin Home Manager. Sin `op`.
- Repo `~/dev/nix-config` ya existe con spec + plan + este informe commiteados.

---

## 3. Decisiones cerradas (autoritativas)

| # | Decisión | Detalle |
|---|---|---|
| D1 | Enfoque de repo | **A**: flake único + `homeConfigurations` por host; `flake.lock` = ancla de reproducibilidad |
| D2 | macOS | **Home Manager standalone**, SIN nix-darwin (sin `defaults`/casks declarativos) |
| D3 | Migración | **Reescritura nativa completa** de zsh/tmux/git a módulos HM |
| D4 | Neovim | **Opción 2b**: HM fija Neovim; árbol lua vendorizado vía `xdg.configFile."nvim".source`; `lazy-lock.json` commiteado. NO nixvim |
| D5 | Secretos | `op` (1Password CLI) bajo demanda → caché local fuera de VCS/store, NO en arranque del shell (§7) |
| D6 | Alcance | Máximo: dotfiles + devShells + Cachix + secretos. FUERA: nix-darwin, app "Anillo", apps GUI |
| D7 | Secuencia | **macOS-first** (este informe), Bazzite diferido por composefs |

---

## 4. Fuentes de verdad: dotfiles y secretos

- **Un solo repo de dotfiles:** `github.com/s4herp/dotfiles` — **PRIVADO**,
  rama `main`, layout normal (archivos en raíz espejan `$HOME`; NO bare).
  Contiene zsh/tmux/ghostty **y toda la config de nvim en `.config/nvim/`**
  (el repo aparte kickstart.nvim quedó descartado por el usuario; todo vive
  aquí). En macOS ya es accesible (es el origen del bare-repo); desde Bazzite,
  vía `gh` autenticado como `s4herp`.
- **Vacío deliberado:** el repo **NO contiene `~/.config/git/config`** ni
  `.gitconfig-shinkansen`/`.gitconfig-mudango` ni la clave GPG (excluidos por
  secretos). → El módulo `git.nix` se **escribe a mano** desde los valores
  documentados en el spec §6.3 (firma GPG `BF390DAAE816840D`, includes
  condicionales por directorio, `url.insteadOf` SSH), no se deriva del repo.
- **`lazy-lock.json`:** puede estar git-ignored por `.config/nvim/.gitignore`.
  Verificar al implementar Neovim; si falta, obtener el pin de plugins aparte.
- **Secretos:** nunca al `/nix/store` (legible por todos) ni a VCS. Se resuelven
  con `op` (§7).

---

## 5. Pista macOS (ejecutar primero)

### 5.0 Postura de riesgo — OBLIGATORIO

macOS es ahora la máquina de trabajo *y* la primera. Reglas no negociables:

1. **Nunca `home-manager switch` sin `nix build` + diff previo.** Un build no
   toca `$HOME`.
2. **Probar en vivo sin colisión** antes del switch: `ZDOTDIR=/tmp/hm-test zsh`
   con la config generada, mientras tu shell diaria sigue intacta.
3. **`switch -b backup`** siempre: HM renombra a `*.backup` en vez de fallar.
4. **NO borrar `~/.cfg`** (bare-repo) hasta tener paridad probada y días de uso.
   Es tu plan de retorno.
5. **Rollback listo:** `home-manager generations` + activar la previa.
6. Hacerlo **fuera de horario de trabajo** (jornada 09–17h documentada).

`★ Insight ─────────────────────────────────────`
- HM se **niega a sobrescribir** un dotfile que no creó él. Eso es la red de
  seguridad: tu `.zshrc` actual no puede romperse por accidente; `-b backup`
  convierte ese error en un respaldo automático.
- El bare-repo y HM **no pueden gestionar el mismo archivo a la vez** en la
  misma máquina. El "paralelo" seguro es: build+diff + ZDOTDIR de prueba +
  generaciones, no dos sistemas peleando por `~/.zshrc`.
`─────────────────────────────────────────────────`

### 5.1 Fase M0 — Instalar Nix en macOS **[MANUAL]**

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

- En macOS el planner crea un **volumen APFS dedicado** montado en `/nix`
  (mecanismo distinto a Bazzite; no sufre el problema composefs).
- Habilita `nix-command flakes` por defecto.
- **Verificar al ejecutar** (no asumir de memoria): lee el "install plan" que
  imprime y confirma; al terminar:
  ```bash
  nix --version && nix config show experimental-features
  ```
  Debe listar `nix-command` y `flakes`.

### 5.2 Fase M1 — Flake mínimo + smoke test

1. Confirmar valores: `echo "$HOME"; id -un` (en macOS `$HOME=/Users/<user>`).
2. `home.stateVersion`: ejecutar `nix run home-manager/master -- --version`,
   usar la serie `XX.YY` impresa (marcador fijo, **se pone una vez y no se
   cambia**).
3. Crear `~/dev/nix-config/flake.nix` (sustituir `<HOME>`, `<USER>`,
   `<STATE_VERSION>`, `<SYSTEM>`=`aarch64-darwin`):

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
      mkHome = { system, username, homeDirectory }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            ({ pkgs, ... }: {
              home.username = username;
              home.homeDirectory = homeDirectory;
              home.stateVersion = "<STATE_VERSION>";
              programs.home-manager.enable = true;
              home.packages = [ pkgs.hello ];   # smoke test
            })
          ];
        };
    in {
      homeConfigurations."saher@macbook" = mkHome {
        system = "aarch64-darwin";
        username = "<USER>";
        homeDirectory = "<HOME>";
      };
      # Pre-cableado para el futuro (no se activa en macOS):
      homeConfigurations."saher@bazzite" = mkHome {
        system = "x86_64-linux";
        username = "saherpinero";
        homeDirectory = "/var/home/saherpinero";  # verificar en Bazzite
      };
    };
}
```

4. `cd ~/dev/nix-config && git add flake.nix && nix flake show` (los flakes
   solo ven archivos trackeados por git). Sin errores → `nix flake lock`,
   commit de `flake.nix` + `flake.lock`.
5. Build (shadow): `nix build .#homeConfigurations.'"saher@macbook"'.activationPackage`
6. Activar: `nix run home-manager/master -- switch -b backup --flake .#"saher@macbook"`
7. Verificar: `hello && readlink -f "$(command -v hello)"` → ruta `/nix/store/...`.

### 5.3 Fase M2 — Estructura de repo y módulos nativos

Crear la estructura del spec §6.2:

```
hosts/{macbook.nix,bazzite.nix}      modules/{shell/zsh.nix,shell/tmux.nix,
editor/neovim.nix,git.nix,cli.nix,secrets.nix,direnv.nix}
devshells/elixir.nix   secrets/secrets.tpl   overlays/
```

Reescritura nativa (D3/D4), tomando como referencia el clon de
`s4herp/dotfiles` (en macOS ya tienes los archivos en `$HOME`; opcional
`git clone` a `reference/` git-ignored para diff):

- `shell/zsh.nix`: `programs.zsh` — p10k instant prompt, plugins equivalentes a
  antidote (`zsh-completions`, `zsh-autosuggestions`, `fzf-tab`,
  `zsh-syntax-highlighting` en orden correcto), opciones (`AUTO_CD`,
  `AUTO_PUSHD`, historial compartido sin dups, `EXTENDED_GLOB`), init de
  atuin/fzf/direnv/zoxide, lazy-load conda/nvm, funciones fzf
  (`fcd/fgb/fv/fkill/ftm`), aliases eza/nvim/tmux, retorno temprano no
  interactivo, y el `source` del caché de secretos (§7).
- `shell/tmux.nix`: `programs.tmux` — prefix `C-Space`, `mode-keys vi`,
  navegación `h/j/k/l`, plugins (tmux-yank, tmux-fzf, easymotion, extrakto,
  resurrect, catppuccin mocha, online-status, battery), true color.
- `git.nix`: `programs.git` — firma GPG `signByDefault`, `includes`/`includeIf`
  shinkansen/mudango, `init.defaultBranch=main`, `url.insteadOf` SSH, excludes.
  **Escrito a mano** (no está en el repo de dotfiles).
- `editor/neovim.nix` (2b): HM instala/fija Neovim; vendoriza el árbol lua y lo
  entrega con `xdg.configFile."nvim".source`; `lazy-lock.json` commiteado
  (verificar si está git-ignored).
- `cli.nix`: `home.packages` con el set del informe (eza, bat, fd, zoxide, fzf,
  atuin, gh, lazygit, jq, ripgrep, tree, ncdu, dive, httpie, direnv,
  pre-commit, …).
- `direnv.nix`: `programs.direnv` + `nix-direnv`.

Cada módulo: editar → `nix build` → diff vs dotfile actual → probar en
`ZDOTDIR=/tmp/hm-test` → `switch -b backup` → commit. Un módulo por iteración.

### 5.4 Fase M3 — Secretos (ver §7)

### 5.5 Fase M4 — devShells + direnv

`devshells/elixir.nix` (Erlang/Elixir/Node/Postgres fijados) + `nix-direnv`
`use flake` por proyecto. Convive con asdf del monorail (no lo reemplaza en el
repo compartido).

### 5.6 Fase M5 — Cachix

Binary cache (push desde macOS) para que Bazzite, cuando se desbloquee, **no
recompile** el toolchain.

### 5.7 Fase M6 — Estabilización

Días de uso real. Cuando haya confianza: archivar `~/.cfg` (NO borrar; mover a
`~/.cfg.archived-YYYYMMDD`). `zsh-bench` para confirmar que la latencia de
arranque no regresó (objetivo documentado: <100ms p10k).

---

## 6. Pista Bazzite (BLOQUEADA — composefs)

### 6.1 El bloqueo, con evidencia

El instalador Determinate (planner `ostree`) falló el 2026-05-17:

```
ERROR Error saving receipt: RecordingReceipt("/nix", Os { code: 30,
      kind: ReadOnlyFilesystem, message: "Read-only file system" })
Action `start_systemd_unit` errored — systemctl start nix.mount
A dependency job for nix.mount failed.
```

Diagnóstico verificado (Apéndice A): root =
`composefs overlay ro`. Bazzite 44 sella el root con **composefs** (overlay
read-only con integridad), más estricto que el ostree clásico. El planner
intenta crear `/nix` como punto de montaje y montar `/var/home/nix` ahí vía
`nix-directory.service` + `nix.mount`; con composefs el mountpoint `/nix` no
puede crearse en el root sellado → la dependencia de `nix.mount` falla → el
receipt a `/nix` pega contra solo-lectura. El revert dejó el sistema **limpio**.

`★ Insight ─────────────────────────────────────`
- composefs no es "ostree con otro nombre": es un root **verificado e
  inmutable a nivel de imagen** (overlay `ro` + objetos en `/sysroot/ostree`).
  Técnicas que funcionaban en Silverblue clásico (crear `/nix` con un servicio
  systemd al boot) pueden no aplicar igual aquí.
- Por eso macOS-first no es solo preferencia: es el camino **sin bloqueo
  conocido** hoy, mientras se resuelve esto sin presión.
`─────────────────────────────────────────────────`

### 6.2 Caminos a investigar (NO un fix verificado)

El servidor de documentación (context7) se desconectó durante esta sesión, así
que **no afirmo una solución de memoria** (criterio del usuario: verificar
contra fuente). Opciones a evaluar **con fuentes** antes de tocar el sistema:

1. **Determinate Nix en sistemas composefs/uBlue**: revisar la doc oficial
   actual de Determinate Systems y los issues de `DeterminateSystems/nix-installer`
   filtrando `composefs`/`bazzite`/`ublue`/`ostree`. Confirmar si hay un
   planner/flag soportado para root composefs.
2. **Guía uBlue/Bazzite oficial para Nix**: uBlue documenta métodos para
   software fuera de la imagen. Verificar si recomiendan un método concreto
   (montaje `/var/lib/nix` + bind, o `/nix` vía `systemd` con `RequiresMountsFor`).
3. **Backing store en `/var` + `nix.mount` propio**: `/var` SÍ es escribible en
   ostree/composefs. El patrón es montar un dir bajo `/var` en `/nix`; el
   problema es crear el *mountpoint* `/nix` en el root sellado. Investigar si
   `systemd` puede materializar el target con `ConditionPathExists`/tmpfiles
   en composefs (es justo lo que falló — entender por qué).
4. **Alternativas si `/nix` resulta inviable**: Distrobox/toolbox con Nix
   dentro (aislado, pierde integración con el host), o `nix` con store
   relocalizado (`--store`), evaluando el coste de no usar `/nix` canónico.

Criterio de salida Bazzite: `nix --version` responde, `flakes` activos,
`home-manager switch --flake .#"saher@bazzite"` aplica, y `hello` resuelve a
`/nix/store`. Recién entonces clonar `s4herp/dotfiles` como reference y aplicar
los mismos módulos (ya escritos en la pista macOS — sin reescritura).

### 6.3 Diferencias de host Bazzite (`hosts/bazzite.nix`)

- `homeDirectory` canónico: `/var/home/saherpinero` (verificar `echo $HOME`;
  `/home` es symlink).
- Retirar **linuxbrew** y controlar precedencia de PATH (hoy `$SHELL` es
  linuxbrew zsh).
- Secretos: caché en `$XDG_RUNTIME_DIR/ring/secrets` (tmpfs, 0600).
- Paquetes solo-Linux y condicionales `pkgs.stdenv.isLinux`.

---

## 7. Diseño de secretos (ambas máquinas)

```
secrets/secrets.tpl   (refs op://, EN VCS — punteros, seguros)
   │  secrets-refresh  (script HM, ejecutado A VOLUNTAD)
   ▼  op inject  →  ( umask 077; … )
$XDG_RUNTIME_DIR/ring/secrets   (Bazzite: tmpfs 0600, se borra al logout)
$TMPDIR/ring/secrets | ~/.cache/ring/secrets   (macOS: no hay XDG_RUNTIME_DIR)
   │  snippet en .zshrc (HM):  [ -r "$f" ] && source "$f"
```

- El caché materializado **nunca** se declara en HM, **nunca** entra al store,
  **nunca** se versiona (gitignored). `op` **no** corre en el arranque del
  shell (cero prompts por terminal, cero regresión de latencia).
- Snippet guardado: si falta el caché, la shell no se rompe. `secrets-refresh`
  idempotente y re-ejecutable.
- **GPG:** la clave privada se provisiona como **Documento de 1Password**
  (paso manual documentado), NO se inyecta como env var.
- Trade-off aceptado: secreto en reposo en archivo local (misma postura que el
  `~/.zsh_secrets` actual, pero regenerable desde 1Password), mitigado por
  tmpfs (Linux) + `0600` + on-demand. Para CLIs concretos (`gh`, `gcloud`,
  `awscli`) evaluar en paralelo los **Shell Plugins** de 1Password.

---

## 8. Verificación

- **Por módulo:** `nix build` → diff generado vs dotfile actual → prueba en
  `ZDOTDIR`/sesión aislada → `switch -b backup` → commit.
- **Comportamiento:** checklist contra el informe de herramientas (p10k instant
  prompt, fzf-tab con previews, atuin Ctrl-R, zoxide, aliases, tmux
  prefix/plugins, nvim `:checkhealth`/ElixirLS/Telescope/Harpoon).
- **Latencia:** `zsh-bench` sin regresión (<100ms objetivo).
- **Reproducibilidad:** mismo `flake.lock` → `nix build` en ambos hosts → los
  store paths de los módulos compartidos coinciden.
- **Rollback:** `home-manager generations` + activar la previa (atómico).

---

## 9. Riesgos y temas abiertos

| Tema | Estado / mitigación |
|---|---|
| Bazzite composefs | **ABIERTO** — investigar §6.2 con fuentes antes de tocar el sistema |
| Iterar sobre la máquina de trabajo | macOS-first: salvaguardas §5.0 obligatorias; `~/.cfg` intacto como retorno |
| `git.nix` sin fuente en repo | Escrito a mano desde spec §6.3 (firma GPG, includes) |
| `lazy-lock.json` git-ignored | Verificar; si falta, obtener pin de plugins aparte |
| Determinate en macOS | Mecanismo APFS, distinto a composefs; **verificar install plan al ejecutar**, no asumir |
| Apps GUI macOS | Fuera de alcance (Karabiner/Raycast/Shortcat/DBeaver/Obsidian); sus *archivos* de config sí pueden ir en HM |
| Secreto en reposo | Trade-off aceptado; tmpfs+0600+on-demand |

---

## Apéndice A — Diagnóstico Bazzite capturado (2026-05-17)

```
rpm-ostree: ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-nvidia:stable
Version: 44.20260515 (2026-05-15T07:00:40Z)
Digest: sha256:bf99b0d893795baca379579756872cf4d04d7df003c68ddc48f6dc20da94a3f5
Kernel: 6.19.14-ogc5.1.fc44.x86_64
findmnt / : composefs overlay ro,relatime,seclabel,
  lowerdir+=/run/ostree/.private/cfsroot-lower,
  datadir+=/sysroot/ostree/repo/objects,redirect_dir=on,metacopy=on
/nix : No such file or directory  (sin montaje)
/var/home/nix : No such file or directory  (revert limpio)
/etc/systemd/system/nix.mount : No such file or directory  (revert limpio)
USER=saherpinero  HOME=/home/saherpinero (symlink → /var/home/saherpinero)
passwd shell: /bin/bash   shell interactivo: linuxbrew zsh
LayeredPackages: 1password ghostty grim tesseract tesseract-langpack-spa
  wtype xclip xterm
```

Error del instalador (resumen):
```
RecordingReceipt("/nix", Os { code: 30, kind: ReadOnlyFilesystem })
systemctl start nix.mount → "A dependency job for nix.mount failed"
→ revert automático: "Partial Nix install was uninstalled successfully!"
```

## Apéndice B — Referencias

- Spec: `docs/superpowers/specs/2026-05-17-nix-dotfiles-multiplatform-design.md`
- Plan Fase 0 (Bazzite-first, ahora diferido):
  `docs/superpowers/plans/2026-05-17-nix-bootstrap.md`
- Informe de herramientas (comportamiento objetivo):
  `~/Downloads/2026-05-17-herramientas-de-desarrollo.md`
- Dotfiles: `github.com/s4herp/dotfiles` (privado, rama `main`)
- A verificar con fuente: doc oficial Determinate Systems + issues
  `DeterminateSystems/nix-installer` (composefs/ublue/bazzite); guía Nix de uBlue.
