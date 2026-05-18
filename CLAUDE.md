# CLAUDE.md — Orientación autoritativa de este repo

> Si abres una sesión nueva en este repo (p. ej. continuando desde otra
> máquina): **lee esto primero**. Evita confundir el orden de los documentos.

## Qué es este repo

Migración de los dotfiles de Saher (bare-repo `~/.cfg`) a **Nix flake + Home
Manager standalone**, mismo entorno reproducible en **macOS** (Apple Silicon)
y **Bazzite** (Fedora atómico). Reemplazará a `~/.cfg`.

## DOCUMENTO AUTORITATIVO (leer siempre primero)

**`docs/2026-05-17-nix-implementation-dossier.md`** es el plan vigente y
autocontenido. Cualquier ejecución arranca ahí.

## Estado actual (2026-05-17)

- **Secuencia = macOS-FIRST.** Se implementa primero en el Mac (§5 del
  dossier). El Mac no depende de Bazzite.
- **Bazzite está BLOQUEADO** por composefs (Fedora 42+): el instalador no
  puede crear `/nix` en el root read-only. Causa raíz **verificada contra
  source**; workarounds con fuente (transient root / imagen custom) en
  **§6.2 del dossier**. NO intentar instalar Nix en Bazzite hasta aplicar A o C.

## Qué está vigente vs. superado — IMPORTANTE

| Documento | Estado |
|---|---|
| `docs/2026-05-17-nix-implementation-dossier.md` | **VIGENTE.** Plan de ejecución real |
| `docs/superpowers/specs/2026-05-17-...-design.md` | Decisiones de diseño **D1–D7 VIGENTES**; su narrativa de secuencia (Bazzite-first) **SUPERADA** por el dossier |
| `docs/superpowers/plans/2026-05-17-nix-bootstrap.md` | **HISTÓRICO/DIFERIDO.** Es el plan Fase 0 *Bazzite-first*. **NO ejecutarlo en Bazzite** (fallará por composefs). Útil solo como referencia de pasos |

No re-litigar las decisiones cerradas (spec §3/§12, dossier §3: enfoque A,
HM standalone sin nix-darwin, reescritura nativa, nvim 2b, secretos vía `op`).
Ya están decididas; el spec explica el porqué.

## Por dónde empezar (en el Mac)

1. Leer dossier §1 (resumen/secuencia) y §3 (decisiones).
2. Ejecutar **dossier §5** paso a paso (M0 instalar Nix → M6 estabilizar).
3. §5.0 son salvaguardas **obligatorias** (se itera sobre la máquina de
   trabajo): build+diff, prueba en `ZDOTDIR` aislado, `switch -b backup`, no
   borrar `~/.cfg`, rollback por generaciones.

## Convenciones

- Comunicación con el usuario: **español**.
- Commits: en **inglés**, **sin** `Co-Authored-By`, sin emojis.
- Dotfiles fuente: `github.com/s4herp/dotfiles` (privado, rama `main`) —
  contiene zsh/tmux/ghostty + nvim en `.config/nvim/`. **No** trae git config
  (se escribe a mano desde spec §6.3).
- Verificar contra fuente antes de afirmar (no de memoria).
