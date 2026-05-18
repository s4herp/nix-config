# nix-config

Migración de dotfiles a **Nix flake + Home Manager standalone**, multiplataforma
**macOS** (Apple Silicon) + **Bazzite** (Fedora atómico). Reemplaza el bare-repo
`~/.cfg`.

## Empezar aquí

1. **`CLAUDE.md`** — orientación autoritativa (qué está vigente vs. superado).
2. **`docs/2026-05-17-nix-implementation-dossier.md`** — plan de ejecución
   vigente y autocontenido. Arranca por su §5 (pista macOS).

## Estado

- **Secuencia: macOS-first.** Implementar primero en el Mac (dossier §5).
- **Bazzite: BLOQUEADO** por composefs (Fedora 42+). Causa raíz verificada
  contra source; workarounds con fuente en dossier §6.2 (transient root /
  imagen custom). No instalar Nix en Bazzite hasta aplicarlos.

## Estructura

```
CLAUDE.md                                   orientación para sesiones nuevas
README.md                                   este archivo
docs/2026-05-17-nix-implementation-dossier.md   PLAN VIGENTE (macOS-first)
docs/superpowers/specs/...-design.md        spec (decisiones D1–D7 vigentes;
                                            secuencia superada por el dossier)
docs/superpowers/plans/...-nix-bootstrap.md plan Fase 0 Bazzite-first
                                            (HISTÓRICO/DIFERIDO — no ejecutar
                                            en Bazzite: falla por composefs)
```
