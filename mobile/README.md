# mobile/ — VOIDHOLD Pre-production Gate (root)

Parent plan: `STARHOLD_PLAN.md` (to be renamed VOIDHOLD) + `tasks/` Epic 0 exit.
Game: `VOIDHOLD: Moon Colony` | Bundle: `com.voidhold.colony`
Engine: Godot 4.7.2 + targetSdk 36 / API 36 + iOS 15+.
Locales: v1 `en` + `ar` only. Later `es` + `de`. RTL required for `ar`.
Scope: docs only, no code. All phone/tablet constraints decided before sim/art/UI scale.

## Contents
- `device-matrix.md`
- `constraints.md`
- `orientation-touch-spec.md`
- `spike-exit-checklist.md`
- `evidence/` — Epic 0 capture manifests, audit rows, and parity fixtures

## Rules
- Canonical IDs: `stone/alloy/biomass/ore/stim` + legacy map.
- Budgets: `<180k tris, <90 calls, <180MB, placement <8ms, save <300ms`.
- Evidence links only (video, logs, Figma, sheets).
- Mirrors `tasks/epic-0-preproduction/` T0.4/T0.5/T0.6/T0.10 mobile requirements.
