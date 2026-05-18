# Diseño — Toolchain Elixir/Erlang host auto-versionado por Nix

- **Fecha:** 2026-05-18
- **Repo:** `~/dev/shinkansen/local/nix-config` (personal, no toca el monorail)
- **Estado:** diseño aprobado (brainstorming), pendiente plan de implementación

## 1. Problema y objetivo

Hoy el desarrollo Elixir sufre: malabar de versiones entre sub-repos del
monorail (3 sets distintos) y dualidad devcontainer/host. asdf fija versiones
pero compila contra libs del sistema (no reproducible). El devcontainer
aísla pero es pesado y los builds de host contaminan el `_build` compartido
con NIFs Mach-O que rompen dentro del container Linux.

**Objetivo:** un toolchain Nix en el **host**, paralelo al devcontainer, que
entregue el Elixir/Erlang correcto por sub-repo automáticamente, detectable
en cualquier contexto (shell interactivo, scripts, Bash no-interactivo de
Claude), **sin modificar el monorail** y **sin contaminar** su `_build`/`deps`.

### Restricciones duras (verificadas)

- El monorail ya tiene `.envrc` propios (root + sub-repos, trackeados) → no se
  pueden agregar/modificar. direnv no se carga en Bash no-interactivo.
- AGENTS.md del monorail: asdf + `.tool-versions` + devcontainer = flujo
  oficial. No se reemplaza.
- `feedback_host_vs_container_build`: `mix` en host contamina el `_build`
  compartido con NIFs Mach-O que rompen en el container. Landmine central.
- Sets reales hoy: `1.19/erlang 27` (customer-ui, saibankan), `1.16/erlang 26`
  (mayoría po-*, kabuki, naikan-ui, simulated-bank), `1.19/erlang 28`
  (adp-scotiabank-cl). `customer-ui-mcp` es python/uv (fuera de alcance).

### Decisiones cerradas

| # | Decisión |
|---|---|
| D1 | Toolchain host paralelo al devcontainer; build pesado sigue en container |
| D2 | Activación vía **shims en PATH** (estilo asdf, backend Nix), funciona en Bash no-interactivo |
| D3 | Host compila en **rutas aisladas propias** (`MIX_BUILD_ROOT`/`MIX_DEPS_PATH` host-only); el `_build`/`deps` del repo queda intacto |
| D4 | **Minor-exacto**, patch el que ancle `flake.lock` (cubre `~> 1.x` de los mix.exs) |
| D5 | Auto-build del perfil del set en 1ra uso (cacheado, GC-root); deps faltantes = aviso claro, no auto-corre; set no mapeado = error claro |
| D6 | Resolución vía **perfil GC-rooted + exec directo** (enfoque B): sin Nix en el path caliente |

## 2. Arquitectura

```
.tool-versions (sub-repo del monorail, solo-lectura)
        │  lee (shell puro, sin Nix)
        ▼
[shim]  mix · elixir · iex · erl · elixirc · mix · epmd …
        │  resuelve (elixir_minor, erlang_minor) -> nombre de set
        ▼
[resolver]  set -> perfil GC-rooted en ~/.cache/nix-beam/profiles/<set>
        │  si falta: nix build automático (1ra vez), --out-link GC-root
        ▼
[exec]  PATH=<perfil>/bin:$PATH ; MIX_* aislados ; exec binario real "$@"
```

Tres componentes, una responsabilidad cada uno:

- **flake (`devshells/beam.nix` + output `packages.<system>.beam-<set>`)**:
  declara los sets BEAM como `buildEnv`/`symlinkJoin` (path con `bin/` listo
  para exec, NO `devShell`). Fuente única de versiones.
- **shim** (un script, multi-symlink por binario): único en el PATH caliente.
  Sin Nix en la ruta rápida. Lee `.tool-versions`, mapea, asegura perfil,
  fija aislamiento, `exec`.
- **resolver/builder** (función del shim): dado un set, devuelve el path del
  perfil; si no existe, `nix build … --out-link ~/.cache/nix-beam/profiles/<set>`.

Distinción clave: `buildEnv` (directorio con `bin/` en el store, ejecutable
por path) vs `devShell` (solo existe dentro de `nix develop`). El `exec`
directo sobre el `buildEnv` es lo que da overhead casi-cero por llamada.

## 3. Detección y mapeo de versiones

**Detección** (shim, sin Nix): desde el cwd, subir buscando el
`.tool-versions` más cercano (algoritmo asdf). Parsear `elixir X.Y.Z` y
`erlang A.B.C…`; quedarse con el **minor** (`1.16`, `26`). Sin
`.tool-versions` → set default (`e1_19_o27`, el más nuevo).

**Mapeo** `(elixir_minor, erlang_minor)` → nombre de set por convención
`e<elixirMinor>_o<erlangMinor>` (`.`→`_`):

| `.tool-versions` | Set | Sub-repos hoy |
|---|---|---|
| elixir 1.19 / erlang 27 | `e1_19_o27` | customer-ui, saibankan |
| elixir 1.16 / erlang 26 | `e1_16_o26` | po-*, kabuki, naikan-ui, simulated-bank |
| elixir 1.19 / erlang 28 | `e1_19_o28` | adp-scotiabank-cl |

El flake declara los sets en un attrset (`devshells/beam.nix`); el shim
compone el nombre y pide ese attr (sin tabla duplicada). Set no mapeado →
error claro (§6). nodejs: si el `.tool-versions` declara `nodejs X`, el set
incluye ese Node minor; si no, sin Node.

## 4. Build de perfiles, GC-root, auto-build

- Por set, un perfil = clausura con `erlang`, `elixir`, `rebar3`, `hex`
  (+ `nodejs` si aplica), expuesto como `packages.<system>.beam-<set>`
  (`symlinkJoin`).
- Materializado en `~/.cache/nix-beam/profiles/<set>` = symlink al
  `/nix/store/...`, registrado como **GC-root** vía `nix build --out-link`
  (sobrevive `nix-collect-garbage`).
- 1ra invocación de un set sin perfil: el shim corre
  `nix build ${NIX_CONFIG_DIR:-~/dev/shinkansen/local/nix-config}#beam-<set>
  --out-link ~/.cache/nix-beam/profiles/<set>` (lenta 1ra vez; instantánea si
  Cachix M5 ya lo tiene). Siguientes: symlink existe → cero Nix en path caliente.
- **Invalidación:** tras `nix flake update` los sets cambian de hash. Comando
  explícito `beam-refresh [set|--all]` reconstruye y reapunta GC-roots
  (borra los viejos). El shim no detecta drift de lock por llamada (sería caro).

## 5. Ejecución del shim + aislamiento `_build`/`deps`

Camino caliente (cada `mix`/`elixir`/`iex`/…), shell puro:

1. Resolver `.tool-versions` más cercano → set.
2. Asegurar perfil (symlink existe; si no, auto-build §4).
3. `export PATH="<perfil>/bin:$PATH"`.
4. Fijar aislamiento (abajo).
5. `exec <perfil>/bin/<binario-real> "$@"`.

**Aislamiento (el punto que rompió antes):** el host nunca escribe en el
`_build`/`deps` dentro del sub-repo.

- `export MIX_BUILD_ROOT="$HOME/.cache/nix-beam/work/<repo-id>/_build"`
- `export MIX_DEPS_PATH="$HOME/.cache/nix-beam/work/<repo-id>/deps"`
- `<repo-id>` = hash corto del path absoluto de la raíz del repo (la que
  tiene `mix.exs`), estable por repo.

Resultado: `deps.get`/`compile`/`test` en host escriben solo bajo
`~/.cache/nix-beam/work/<repo-id>/`. El `_build`/`deps` versionado del
monorail queda intacto → devcontainer y CI sin contaminar. Árboles de build
host y container independientes (deps duplicadas en host, costo aceptado).

Caveats: host necesita su propio `mix deps.get` (avisos §6); comandos
no-build (`mix format`, `elixir`, `iex`) van por el shim → versión correcta
sin tocar nada; repos sin `mix.exs` (ej `customer-ui-mcp`) no se ven afectados.

## 6. Avisos + detectabilidad por Bash

Todo a **stderr**, prefijo `nix-beam:`, formato estable:

| Situación | Comportamiento |
|---|---|
| Perfil no construido | Auto-build. `nix-beam: building toolchain e1_16_o26 (first use, may take a while)…` |
| Set no mapeado | **Aborta** (exit≠0). `nix-beam: ERROR no set for elixir 1.20/erlang 30. Add it to <nix-config>/devshells/beam.nix, then git add && switch`. No corre nada. |
| Host deps faltantes (comando los necesita) | No auto-corre. `nix-beam: host deps missing for <repo-id>. Run: mix deps.get`. Ejecuta el comando igual (mix dará su error). |
| `.tool-versions` ausente | `nix-beam: no .tool-versions found, using default set e1_19_o27`, sigue. |

Detectabilidad por Claude/Bash: non-interactive, mensajes a stderr con
prefijo y verbos claros (`ERROR`, `building`, `Run: …`) → al correr
`cd <subrepo> && mix test` se ve exactamente qué falta y el comando exacto,
sin hook de direnv, sin estado oculto, determinístico.

## 7. Layout, integración, anti-basura

```
devshells/beam.nix       sets BEAM (attrset: e1_19_o27, e1_16_o26, e1_19_o28, default)
modules/beam-shims.nix    módulo HM: shims + beam-refresh + beam-gc; wirea PATH
flake.nix                 expone packages.<system>.beam-<set> (symlinkJoin por set)
```

- `modules/beam-shims.nix` wireado en `hosts/macbook.nix` (ciclo
  build→switch→commit). Shims antepuestos al PATH después del fix brew (Nix
  gana, igual que el resto de módulos).
- Estado runtime **solo** bajo `~/.cache/nix-beam/` (perfiles GC-rooted +
  work dirs). `beam-gc` borra perfiles/work no usados. `beam-refresh`
  reapunta tras `nix flake update`.
- Nada se escribe en el monorail. Rollback de generación retira los shims
  atómico. No toca asdf (devcontainer sigue igual), ni módulos M1–M3.
  `cli.nix` no duplica elixir/erlang.
- Uso fuera del monorail: idéntico (cualquier repo con `.tool-versions` o
  `mix.exs` default). Proyectos personales: cero config.

## 8. Fuera de alcance

- Reemplazar el devcontainer o asdf en el monorail.
- Patch idéntico a asdf (elixir-overlay) — sólo si un patch concreto rompe
  (decisión futura puntual).
- Python/uv (`customer-ui-mcp`) y otros runtimes no-BEAM.
- Detección de drift de `flake.lock` automática (es `beam-refresh` explícito).

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| 1ra build lenta sin Cachix | M5 Cachix (prerequisito de provecho real); aviso claro mientras |
| Patch nixpkgs ≠ asdf rompe algo | Minor cubre `~> 1.x`; overlay puntual si concreto (§8) |
| Deps host desincronizadas del repo | Aislamiento intencional; aviso `mix deps.get`; host es para dev liviano, build pesado en container |
| Overhead por llamada | Enfoque B (perfil pre-resuelto + exec, sin Nix en path caliente) |
| GC borra toolchain en uso | `nix build --out-link` GC-root |
