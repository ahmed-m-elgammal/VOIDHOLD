# EPIC 0 — Pre-production + Rebrand (Docs only, no production code)
> Source of truth: ONE authoritative file per ID below. Files named `*-output-*.md` / `T0.X-runbook.md` are supporting ARTIFACTS, never authoritative.

| ID | Authoritative spec | Supporting artifacts |
|---|---|---|
| T0.1 | `T0.1-rebrand-identity.md` | `T0.1-output-decision-draft.md` |
| T0.2 | `T0.2-gdd-lock.md` | `T0.2-output-parity-starter.md` |
| T0.3 | `T0.3-license-purge.md` | `T0.3-output-audit-starter.md` |
| T0.4 | `T0.4-engine-spike-472.md` | `T0.4-runbook.md` |
| T0.5 | `T0.5-wireframes-adaptive-ui.md` | (none) |
| T0.6 | `T0.6-data-db-save-schema-design.md` | (none) |
| T0.7 | `T0.7-ownership-and-supply-chain-audit.md` | `T0.7-output-inventory-template.md` |
| T0.8 | `T0.8-reference-simulation-and-parity.md` | `T0.8-output-fixture-starter.md` |
| T0.9 | `T0.9-visual-identity-and-art-bible.md` | `T0.9-output-art-bible-starter.md` |
| T0.10 | `T0.10-premium-vertical-slice.md` | `T0.10-output-slice-scope.md` |

Goal: establish the creative, legal, behavioral, technical, and visual contracts before full production.
Exit gate: all T0.1–T0.10 marked Done + stakeholder sign-off. Blocks Epic 1 and full asset production.

## Scope
- Rebrand + bundle IDs + store names
- GDD v1 lock (loop, win/lose, 3 moons, controls both orientations)
- License purge (zero OGA in commercial build)
- Engine spike on Godot 4.7.2 + targetSdk 36 validation
- Adaptive UI wireframes landscape + portrait
- Data/DB/save schema design on paper
- Original-code and software-supply-chain ownership audit
- Reference simulation and parity contract
- Visual identity and art bible
- Premium vertical-slice plan and gate

## Team (ideal)
- Producer/owner: decisions, sign-offs
- Game designer: T0.2, balance sheet
- Producer + legal: T0.1, T0.3, T0.7
- Client engineer: T0.4, T0.6 review
- UI/UX designer: T0.5, T0.9 review
- Art Director / visual lead: T0.9, T0.10 review
- QA/build: test matrix, DoD enforcement

## Timeline
The old 5–8 day estimate is no longer valid. Allow 2–4 weeks with an ideal team, longer if legal ownership, art direction, or device access is unresolved.

## Dependencies
```
T0.1 ─┐
T0.3 ─┼─> T0.2 ─> T0.5 ─> T0.6 ─┐
T0.7 ─┘         └─> T0.8 ────────┼─> T0.10 ─> EXIT
T0.4 ───────────────> T0.9 ───────┘
```
- T0.1, T0.4, T0.7, and T0.9 can begin in parallel.
- T0.2 needs T0.1 name decisions and T0.3/T0.7 constraints.
- T0.5 and T0.6 need T0.2.
- T0.8 needs T0.2 and source inspection.
- T0.10 needs T0.4, T0.5, T0.6, T0.8, and T0.9.

## Exit criteria
1. Name + bundleIDs reserved, logo v1 approved.
2. GDD v1 signed, no open TBDs blocking Epic 1.
3. License sheet shows 0 ship-blockers, replacement list costed.
4. Spike video + renderer decision + fps logs on Android and iOS device.
5. 12 wireframes approved landscape + portrait with accessibility/localization notes.
6. Save/DB schema v1 + data dictionaries approved.
7. Source/dependency rights audit approved.
8. Reference parity fixtures approved.
9. Art bible approved.
10. Premium vertical-slice scope and gate approved.

## Risks
- Name collision -> check Play + App Store + trademark early (T0.1).
- OGA copyleft contamination -> purge before public beta (T0.3).
- Realistic PBR over-budget on low Android -> spike must test Low tier (T0.4).
- Both-orientations doubling work -> freeze layouts in T0.5, no changes in Epic 6 without change-control.
- Original-code or dependency rights unclear -> no public build until T0.7 is approved.
- Generic or unreadable visual result -> stop bulk content production and return to T0.9/T0.10.
- Offline fast-forward diverges from live simulation -> T0.8/T1.6 golden tests block the slice.
