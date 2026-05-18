# nix-config

Migración de dotfiles a **Nix flake + Home Manager standalone**, multiplataforma
**macOS** (Apple Silicon) + **Bazzite** (Fedora atómico). Reemplaza el bare-repo
`~/.cfg`.

## Empezar aquí

1. **`CLAUDE.md`** — orientación autoritativa (qué está vigente vs. superado).
2. **`docs/2026-05-17-nix-implementation-dossier.md`** — plan de ejecución
   vigente y autocontenido. Arranca por su §5 (pista macOS).

## Operación diaria (manual)

El entorno macOS ya está migrado (M2 completo, generación 12). Los dotfiles
(`~/.zshrc`, `~/.zshenv`, `~/.config/nvim`, `~/.config/tmux/tmux.conf`,
`~/.config/git/config`, `~/.p10k.zsh`) son symlinks read-only al `/nix/store`.
No se editan a mano: se edita el repo y se reconstruye.

Repo de trabajo: `~/dev/shinkansen/local/nix-config`. Target del flake:
`.#"saher@macbook"`. Antes de cualquier comando `nix`/`home-manager` en una
shell nueva:

```
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Cambiar un dotfile o agregar una herramienta

1. Editar el módulo en `modules/` (zsh, tmux, git, cli, editor/neovim,
   direnv). Para agregar un CLI: añadir el paquete a `modules/cli.nix`.
2. Build en sombra (no toca `$HOME`):
   ```
   nix build .#homeConfigurations.'"saher@macbook"'.activationPackage
   ```
3. `git add -A` (los flakes solo ven archivos trackeados por git).
4. Aplicar:
   ```
   nix run home-manager/master -- switch -b backup --flake .#"saher@macbook"
   ```
   `-b backup` renombra cualquier archivo en conflicto a `*.backup` en vez de
   fallar. Crea una generación nueva.
5. `git commit` (inglés, sin co-author, sin emojis).

zsh: abrir shell nueva o `exec zsh`. tmux: `tmux kill-server && tmux` (la
config es server-wide; perdés las sesiones — guardá con `prefix Ctrl-s` antes
si usás resurrect). nvim: la primera vez lazy.nvim clona los plugins según
`nvim/lazy-lock.json`.

### Secretos (M3 — `op` / 1Password)

Modelo: los valores viven **solo en 1Password** (vault `Personal`). El repo
solo guarda **punteros** `op://` en `secrets/secrets.tpl` (sin valores,
seguro en VCS). `secrets-refresh` los materializa on-demand a
`~/.cache/ring/secrets` (modo `0600`, fuera del store y de VCS). `op` nunca
corre al abrir la shell (cero prompts, cero latencia); `zsh.nix` sourcea el
caché solo si existe.

**Agregar un secreto nuevo (automatizado):**

```
secret-add NOMBRE              # pide el valor oculto (no entra a argv/ps)
secret-add NOMBRE --generate   # 1Password genera el valor
```

`secret-add` hace en un paso: crea el item en op (`Personal`) **y** añade
`export NOMBRE="op://Personal/NOMBRE/password"` a `secrets/secrets.tpl`.
Luego (el ciclo Nix es inherente, el script lo imprime):

```
cd ~/dev/shinkansen/local/nix-config
git add secrets/secrets.tpl && git commit -m "secrets: add NOMBRE pointer"
nix run home-manager/master -- switch -b backup --flake .#"saher@macbook"
secrets-refresh                # regenera el caché; luego shell nueva
```

**Crear el item a mano en op** (equivalente al paso automatizado):

```
op item create --category password --title NOMBRE --vault Personal "password=VALOR"
# luego agregar a secrets/secrets.tpl:
#   export NOMBRE="op://Personal/NOMBRE/password"
```

**Listar:** `secret-ls` (nombres declarados, sin valores).

**Rotar / actualizar un valor:**

```
secret-set NOMBRE             # nuevo valor oculto
secret-set NOMBRE --generate  # 1Password genera uno nuevo
secrets-refresh               # luego shell nueva
```

El puntero no cambia → **no hace falta `switch`**, solo `secrets-refresh`.
(También sirve cambiarlo en la app de 1Password + `secrets-refresh`.)

**Borrar:**

```
secret-rm NOMBRE              # pide confirmación; borra item op + puntero
```

Como cambia `secrets.tpl`, sí requiere el ciclo Nix (el script imprime los
pasos: git commit, switch, borrar caché, secrets-refresh).

**Convenciones:** `NOMBRE` solo `[A-Za-z0-9_]` (seguro como env var). Vault
`Personal`, categoría `password`, campo `password`. Nunca poner valores en
`secrets.tpl` ni en ningún `.nix` (el store es world-readable).

`NIX_CONFIG_DIR` override del path del repo si no es el default
(`~/dev/shinkansen/local/nix-config`).

### Rollback

```
home-manager generations            # lista todas las generaciones
/nix/store/<gen-previa>/activate    # activa la anterior (atómico)
```

Red final: el bare-repo `~/.cfg` sigue intacto y los `*.backup`
(`~/.zshrc.backup`, `~/.tmux.conf.backup`, `~/.gitconfig.backup`,
`~/.p10k.zsh.backup`, `~/.config/nvim.backup`) conservan los originales.

### Actualizar versiones (nixpkgs / home-manager)

```
nix flake update          # bump de flake.lock
nix build .#homeConfigurations.'"saher@macbook"'.activationPackage
nix run home-manager/master -- switch -b backup --flake .#"saher@macbook"
git commit -m "chore: bump flake.lock"
```

Sin `flake update` las versiones quedan ancladas por `flake.lock` (misma
entrada = mismo entorno bit a bit en cualquier máquina).

### Actualizar plugins de Neovim

`:Lazy update` en nvim (escribe `~/.local/share/...`), luego copiar el lock
nuevo al repo y reconstruir:

```
cp ~/.config/nvim/lazy-lock.json nvim/lazy-lock.json   # ojo: nvim es symlink ro;
# en la práctica: tras :Lazy update, lazy escribe el lock en su estado mutable;
# copiar ese lazy-lock.json a repo/nvim/, git add, switch, commit.
```

### Notas operativas

- **Precedencia PATH:** `zsh.nix` re-prepende `~/.nix-profile/bin` tras
  `brew shellenv`, así las herramientas Nix ganan a Homebrew. Si una versión
  vieja de Homebrew "gana", revisar ese bloque.
- **Secretos:** M3 hecho — ver sección "Secretos" arriba. `~/.zsh_secrets`
  legacy retirado (borrar el archivo huérfano si sigue en disco).
- **`git`:** identidad global = personal; dentro de `~/dev/shinkansen/` aplica
  la identidad de trabajo vía `includeIf`.
- **Módulos draft (M3+):** secretos, devShells, Cachix no están aún. Ver
  dossier §5.4–5.7.

## Estado

- **Secuencia: macOS-first.** Implementar primero en el Mac (dossier §5).
- **Bazzite: BLOQUEADO** por composefs (Fedora 42+). Causa raíz verificada
  contra source; workarounds con fuente en dossier §6.2 (transient root /
  imagen custom). No instalar Nix en Bazzite hasta aplicarlos.

## Estructura

```
flake.nix / flake.lock                      raíz + ancla de reproducibilidad
hosts/{macbook,bazzite}.nix                 config por host (importa módulos)
modules/shell/{zsh,tmux}.nix                shell + multiplexor
modules/editor/neovim.nix                   neovim (árbol lua en nvim/)
modules/{git,cli,direnv}.nix                git, CLIs, direnv
nvim/                                        árbol lua vendorizado + lazy-lock
p10k.zsh                                     config Powerlevel10k vendorizada
CLAUDE.md                                   orientación para sesiones nuevas
README.md                                   este archivo
docs/2026-05-17-nix-implementation-dossier.md   PLAN VIGENTE (macOS-first)
docs/superpowers/specs/...-design.md        spec (decisiones D1–D7 vigentes;
                                            secuencia superada por el dossier)
docs/superpowers/plans/...-nix-bootstrap.md plan Fase 0 Bazzite-first
                                            (HISTÓRICO/DIFERIDO — no ejecutar
                                            en Bazzite: falla por composefs)
```
