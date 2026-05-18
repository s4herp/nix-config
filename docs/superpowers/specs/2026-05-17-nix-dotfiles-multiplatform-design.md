# Spec — Migración de dotfiles a Nix/Home Manager multiplataforma

> **⚠ ESTADO:** Las **decisiones de diseño (§3, §12) siguen VIGENTES**. Pero la
> **secuencia descrita aquí (Bazzite-first) está SUPERADA**: el plan de
> ejecución vigente es macOS-first y vive en
> `docs/2026-05-17-nix-implementation-dossier.md`. Ver `CLAUDE.md` (raíz) antes
> de actuar. Este spec se conserva por sus decisiones y su razonamiento.

- **Fecha:** 2026-05-17
- **Autor:** Saher Pinero
- **Estado:** Aprobado (diseño) — pendiente de plan de implementación
- **Repo destino:** `~/dev/nix-config` (reemplaza el bare-repo `~/.cfg`)

---

## 1. Resumen

Reemplazar la gestión actual de dotfiles (bare-repo de git en `~/.cfg`) por una
configuración declarativa y reproducible basada en un **flake de Nix + Home
Manager standalone**, capaz de producir un entorno de usuario **idéntico** en dos
máquinas:

- **Bazzite** — Fedora Kinoite atómico, `x86_64-linux`, KDE Plasma/Wayland.
- **macOS** — Apple Silicon, `aarch64-darwin` (máquina de trabajo principal).

El alcance es máximo ("todo el provecho"): dotfiles reescritos a módulos nativos,
entornos de desarrollo por proyecto (`devShells`), binary cache (Cachix) y
gestión de secretos vía 1Password CLI. La gestión de sistema (nix-darwin) y la
app "Anillo" quedan **fuera** y serán specs separados.

## 2. Objetivos

1. Una sola fuente de verdad versionada (`flake.lock`) que produzca config
   bit-a-bit equivalente en Bazzite y macOS.
2. Reescritura **nativa completa** de la config de shell/tmux/git a módulos de
   Home Manager.
3. Neovim reproducible e idéntico entre máquinas sin port costoso (enfoque
   nativo-pragmático, ver §6.3).
4. Secretos resueltos desde 1Password **bajo demanda**, cacheados localmente
   fuera de VCS y fuera del `/nix/store`, sin penalizar el arranque del shell.
5. `devShells` por proyecto con `nix-direnv` que reemplacen a `asdf`.
6. Binary cache para que la segunda máquina no recompile.
7. Migración segura en paralelo: Bazzite como campo de pruebas; macOS intacto
   en su bare-repo hasta tener paridad probada; rollback atómico disponible.

## 3. No objetivos (fuera de alcance)

- **nix-darwin** y gestión declarativa de `defaults`/casks de macOS.
- Instalación de apps GUI (Karabiner, Raycast, Shortcat, DBeaver, Obsidian,
  Ghostty). *Nota:* sus archivos de config (p. ej. `karabiner.json`, config de
  Ghostty) **sí** pueden gestionarse como archivos por Home Manager aunque la
  app se instale manualmente como cask.
- La app unificada "Anillo del Poder" (spec independiente futuro).
- Cambios a la convención `asdf`/`.tool-versions` del monorail compartido del
  equipo. Los `devShells` de este spec son personales y conviven con `asdf`.

## 4. Restricciones y supuestos

- Bazzite es atómico (rpm-ostree): no se puede `dnf install` en el host. Nix se
  instala sin tocar la imagen base (instalador de Determinate Systems, que
  habilita flakes por defecto y maneja distros atómicas/SELinux).
- Home Manager gestiona archivos por symlink al `/nix/store` y **rehúsa
  sobrescribir** un archivo preexistente no gestionado por él (red de seguridad,
  no bug).
- El `/nix/store` es legible por todos los usuarios: **ningún secreto** puede
  declararse en módulos HM ni quedar en el store.
- macOS no expone `$XDG_RUNTIME_DIR`; las rutas dependientes de plataforma se
  resuelven en `hosts/*.nix`.
- En macOS hay commits firmados con GPG; la clave **privada** GPG no se inyecta
  como variable de entorno (se provisiona como Documento de 1Password, paso
  manual documentado).

## 5. Estado de partida (verificado 2026-05-17)

- **Bazzite:** sin Nix, sin `/nix`, sin Home Manager, sin repo de dotfiles, sin
  `op`. `$SHELL` actual = `/home/linuxbrew/.linuxbrew/bin/zsh` (linuxbrew como
  apaño parcial; será retirado en Fase 1). Shell de `passwd` = `/bin/bash`.
- **macOS:** config canónica completa en bare-repo `~/.cfg` + Homebrew + asdf.
  Documentada en `~/Downloads/2026-05-17-herramientas-de-desarrollo.md`
  (referencia de comportamiento objetivo para la verificación).
- Conclusión: **Bazzite es greenfield** y será el campo de pruebas; macOS
  permanece intacto hasta el corte (Fase 6).

## 6. Arquitectura

### 6.1 Enfoque

Flake único con `homeConfigurations` por host (enfoque A, aprobado). El
`flake.lock` clava `nixpkgs` y `home-manager` a commits exactos → ambos hosts
resuelven el mismo árbol de dependencias.

### 6.2 Estructura del repo

```
nix-config/
├── flake.nix                 # inputs: nixpkgs, home-manager; outputs:
│                             #   homeConfigurations."saher@bazzite"  (x86_64-linux)
│                             #   homeConfigurations."saher@macbook"  (aarch64-darwin)
│                             #   devShells.<system>.<name>
├── flake.lock                # ancla de reproducibilidad (versionado)
├── hosts/
│   ├── bazzite.nix           # x86_64-linux: retiro linuxbrew, precedencia PATH,
│   │                         #   $XDG_RUNTIME_DIR, paquetes linux-only
│   └── macbook.nix           # aarch64-darwin: rutas ~/Library, $TMPDIR,
│                             #   condicionales darwin (stdenv.isDarwin)
├── modules/
│   ├── default.nix           # importa todos; baseline compartido
│   ├── shell/zsh.nix         # programs.zsh nativo (ver §6.3)
│   ├── shell/tmux.nix        # programs.tmux nativo
│   ├── editor/neovim.nix     # neovim nativo-pragmático (ver §6.3)
│   ├── git.nix               # programs.git nativo (firma GPG, includes condicionales)
│   ├── cli.nix               # home.packages: set de CLIs del informe
│   ├── secrets.nix           # plantilla op + secrets-refresh + sourcing del cache
│   └── direnv.nix            # programs.direnv + nix-direnv
├── devshells/
│   └── elixir.nix            # Erlang/Elixir/Node/Postgres fijados (primer stack)
├── overlays/                 # pins/patches puntuales si hacen falta
├── secrets/
│   └── secrets.tpl           # SOLO referencias op:// (seguro versionar)
├── .gitignore                # excluye result/, cualquier cache materializado
└── README.md                 # bootstrap por host
```

### 6.3 Especificación de módulos

- **`shell/zsh.nix` (nativo completo):** `programs.zsh` con Powerlevel10k
  (instant prompt), equivalentes de los plugins antidote
  (zsh-completions, zsh-autosuggestions, fzf-tab, zsh-syntax-highlighting con el
  orden correcto: completado temprano, highlighting al final), opciones
  (`AUTO_CD`, `AUTO_PUSHD`, historial compartido sin dups, `EXTENDED_GLOB`),
  init de herramientas (atuin, fzf, direnv, zoxide), carga perezosa de
  `conda`/`nvm`, funciones fzf (`fcd`, `fgb`, `fv`, `fkill`, `ftm`), aliases
  (eza/nvim/tmux), retorno temprano en shells no interactivos. El `source` del
  cache de secretos se inyecta aquí (ver §7).
- **`shell/tmux.nix` (nativo completo):** prefix `C-Space`, `mouse on`,
  `base-index 1`, `mode-keys vi`, navegación `h/j/k/l`, plugins (tmux-yank,
  tmux-fzf, easymotion, extrakto, resurrect, catppuccin mocha, online-status,
  battery), `tmux-256color` + true color.
- **`git.nix` (nativo completo):** `programs.git` con firma GPG
  (`signing.signByDefault`), `includes`/`includeIf` para identidades
  condicionales por directorio (shinkansen / mudango), `init.defaultBranch`,
  `url.insteadOf` SSH, excludes globales.
- **`editor/neovim.nix` (nativo-pragmático, opción 2b aprobada):** Home Manager
  instala y **fija** Neovim; el árbol de config lua se entrega vía
  `xdg.configFile."nvim".source` desde *este repo* (sigue versionado y
  reproducible idéntico entre máquinas), con `lazy-lock.json` commiteado para
  fijar versiones de los ~50 plugins. *No* se reescribe a nixvim (coste de
  semanas sin valor proporcional; el objetivo real —nvim idéntico y
  reproducible— se cumple igual).
- **`cli.nix`:** `home.packages` con el set del informe: eza, bat, fd, zoxide,
  fzf, atuin, gh, lazygit, jq, ripgrep, fd, tree, ncdu, dive, httpie, direnv,
  pre-commit, etc.
- **`direnv.nix`:** `programs.direnv` + `nix-direnv`; convención `use flake`
  por proyecto.

### 6.4 Flujo de datos

`flake.nix` consume `nixpkgs`/`home-manager` fijados → expone
`homeConfigurations.<user@host>` y `devShells.<system>.<name>`. Cada
`hosts/*.nix` importa `modules/` y fija parámetros específicos de plataforma
(rutas, condicionales `pkgs.stdenv.isDarwin`/`isLinux`). Sin rutas hardcodeadas:
todo vía variables XDG + `homeDirectory`.

## 7. Diseño de secretos

```
secrets/secrets.tpl            (refs op://, EN VCS — seguro: son punteros)
        │
        ▼  secrets-refresh  (script gestionado por HM, ejecutado a voluntad)
   op inject  →  ( umask 077; ... )
        │
        ▼
$XDG_RUNTIME_DIR/ring/secrets   (Bazzite: tmpfs, 0600, se borra al cerrar sesión)
$TMPDIR/ring/secrets  o  ~/.cache/ring/secrets   (macOS)
        │
        ▼  snippet en .zshrc (gestionado por HM):  [ -r "$f" ] && source "$f"
```

- El cache materializado **nunca** se declara en HM, **nunca** entra al
  `/nix/store`, **nunca** se versiona (gitignored).
- `op` **no** se ejecuta en el arranque del shell (cero prompts por terminal,
  cero regresión de latencia). Solo en `secrets-refresh`, a voluntad.
- Snippet guardado (`[ -r ]`): si falta el cache, la shell no se rompe.
- `secrets-refresh` es idempotente y re-ejecutable.
- Ruta recomendada Bazzite: `$XDG_RUNTIME_DIR/ring/secrets` (tmpfs → texto plano
  nunca toca el SSD; un refresh por sesión de login).
- **GPG:** la clave privada se provisiona como Documento de 1Password (paso
  manual documentado en README), no por inyección de env var.
- Trade-off aceptado explícitamente: secreto en reposo en archivo local (misma
  postura que el `~/.zsh_secrets` actual, pero regenerable desde 1Password como
  fuente de verdad), mitigado por tmpfs + `0600` + on-demand.

## 8. Plan por fases

Cada fase es independientemente entregable y verificable.

| Fase | Contenido | Criterio de salida |
|---|---|---|
| **0 Bootstrap** | Nix (Determinate) en Bazzite; flakes on; repo `nix-config`; flake mínimo con `homeConfigurations."saher@bazzite"` vacío | `home-manager switch` instala un paquete trivial; `which eza` → `/nix/store/...` |
| **1 Shell core (Bazzite)** | `zsh`+`tmux`+`git`+`cli` nativos; retiro de linuxbrew; precedencia PATH | Shell interactiva Bazzite se comporta según informe (p10k instant prompt, fzf-tab con previews, atuin Ctrl-R, zoxide, aliases, tmux prefix/plugins); `zsh-bench` sin regresión de latencia |
| **2 Neovim** | `editor/neovim.nix` (2b) + lua tree + `lazy-lock.json` | `nvim` abre; `:checkhealth` limpio; ElixirLS/telescope/harpoon/treesitter OK |
| **3 Secretos** | `op` + `secrets.tpl` + `secrets-refresh` + sourcing | `secrets-refresh` materializa cache `0600` en tmpfs; sin `op` en arranque; firma GPG funciona |
| **4 devShells + direnv** | `devshells/elixir.nix` + `nix-direnv` | `cd` a un proyecto Elixir auto-carga toolchain fijado (Erlang/Elixir/Node/Postgres) |
| **5 Cachix** | binary cache push/pull | macOS jala closures del cache en vez de recompilar |
| **6 Corte macOS** | `homeConfigurations."saher@macbook"`; `build`+diff; `switch` con rollback listo | Paridad en ambas máquinas desde un flake; bare-repo `~/.cfg` archivado (no borrado) |

## 9. Manejo de errores y modos de fallo

- **HM rehúsa sobrescribir dotfile no-HM:** esperado en el primer `switch`; el
  procedimiento de bootstrap respalda/mueve los archivos existentes antes.
- **Config rota:** `home-manager switch` es atómico; rollback vía
  `home-manager generations` + activar generación previa.
- **Cache de secretos ausente/viejo:** snippet guardado (`[ -r ]`) nunca rompe
  la shell; `secrets-refresh` re-ejecutable.
- **Conflicto linuxbrew/Nix en PATH (Bazzite):** `hosts/bazzite.nix` controla
  precedencia; linuxbrew retirado en Fase 1 para evitar binarios duplicados.
- **Divergencia de rutas entre plataformas:** todo vía XDG + `homeDirectory`;
  diferencias aisladas en `hosts/*.nix`.
- **Apps GUI macOS:** fuera de alcance; sus dotfiles sí pueden gestionarse como
  archivos por HM.

## 10. Estrategia de verificación

- **Criterios de salida por fase** (tabla §8), objetivos y checklist-based,
  derivados del comportamiento documentado en el informe (secciones 4/6/9).
- **`home-manager build` + diff** del resultado generado vs dotfiles actuales
  **antes de cada `switch`** (shadow-validation; `$HOME` intacto hasta el
  `switch`).
- **Prueba en vivo sin colisión:** ejecutar la shell nueva bajo
  `ZDOTDIR=/tmp/hm-test zsh` mientras la shell diaria sigue en la config vieja.
- **`zsh-bench`** (ya en el toolkit) para confirmar que la latencia de arranque
  no regresa.
- **Reproducibilidad:** con el mismo `flake.lock`, `home-manager build` en
  ambos hosts → los store paths de los módulos compartidos coinciden.

## 11. Riesgos

| Riesgo | Mitigación |
|---|---|
| Reescritura nativa rompe paridad de comportamiento | Bazzite-first, build+diff, checklist del informe, rollback por generaciones |
| Secretos en reposo en disco | Ruta tmpfs (`$XDG_RUNTIME_DIR`) + `0600` + on-demand; trade-off aceptado |
| Provisión de clave GPG en máquina nueva | Documento de 1Password + paso manual documentado en README |
| linuxbrew interfiere en Bazzite | Retiro explícito + control de precedencia PATH en Fase 1 |
| Drift macOS↔Bazzite | Un solo `flake.lock`; verificación de hashes de store |

## 12. Decisiones cerradas

- Enfoque de repo: **A** (flake único + `homeConfigurations` por host).
- macOS: **Home Manager standalone** (sin nix-darwin).
- Migración: **reescritura nativa completa, Bazzite-first**, paralelo vía
  build+diff + generaciones (no dos sistemas sobre el mismo archivo).
- Neovim: **2b nativo-pragmático** (`xdg.configFile.source` + `lazy-lock.json`,
  no nixvim).
- Alcance: máximo (dotfiles + devShells + Cachix + secretos); nix-darwin y
  "Anillo" fuera, como specs futuros.

## 13. Referencias

- Informe de herramientas: `~/Downloads/2026-05-17-herramientas-de-desarrollo.md`
  (comportamiento objetivo de verificación).
- Documentación Nix: `/nixos/nix.dev` (vía context7).
- Instalador: Determinate Systems Nix installer.
