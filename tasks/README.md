# Tasks Index — VOIDHOLD: Moon Colony (CANONICAL task tree)

> Canonical: `tasks/` is the single source of truth for all Epic specs. `mobile/docs/` is a generated verbatim mirror for device-side reference — never edit the mirror directly; edit here, then re-copy. Game is VOIDHOLD (`com.voidhold.colony`), not STARHOLD.
Engine: `Godot 4.7.2.stable.official.ed1daf0bf` | Android `targetSdk 36 / API 36` | iOS 15.0+

Task-set revision: 2026-09-20. These task files are the active production update. They correct the source inventory to 18 buildings, establish canonical resource IDs, and add the premium visual-quality and deterministic-simulation gates. The root plan should be synchronized with this task set before implementation begins.

## Epics — plan and production gates
- [ ] `epic-0-preproduction/` — identity, GDD, license/ownership audit, reference parity, art bible, wireframes, save schema, and premium vertical-slice gate. **Blocks all.**
- [ ] `epic-1-foundations/` — repo, canonical data, TMX bake, headless deterministic simulation, save harness, TimeManager, CI, and release integrity.
- [ ] `epic-2-world-domes/` — Planet3D greybox, dome AStar, placement validation, elevator flow.
- [ ] `epic-3-buildings/` — 18-block sim parity, energy/oxygen, ops, damage lifecycle.
- [ ] `epic-4-units-enemies/` — helot/mighty FSM, population, flying enemies + authority.
- [ ] `epic-5-3d-content/` — authored PBR models/LODs, rigs, VFX, audio replacement, provenance, and visual-quality review.
- [ ] `epic-6-mobile-ux/` — TopHud, BuildBar, sheets, toasts/FTUE/reports, portrait pass, accessibility, localization, and responsive windows.
- [ ] `epic-7-performance-platform/` — perf budgets, renderer/device certification, Android 36 + 16KB, edge-to-edge, iOS, privacy, and interrupt matrix.
- [ ] `epic-8-iap-ready-stub/` — EntitlementManager stub, analytics abstraction, RevenueCat plan DEFERRED.
- [ ] `epic-9-qa-launch/` — balance, automated/manual test plan, beta, update migration, store compliance, staged rollout, and rollback.

## Order
`0 -> 1 -> 2 -> 3+4 -> premium slice -> 5+6 parallel -> 7 -> 9`. Epic 8 runs after the data/privacy contract and before beta.

## Ways of working
1. One task = one owner + reviewer + demo evidence.
2. Epic 0-1 contracts and the premium slice gate come before full content production.
3. Internal IDs immutable, display via strings.csv. Versioned saves, atomic writes.
4. No final placeholder, unreviewed generated, or provenance-free asset enters `art_final/`.
5. Definition of Done in `epic-0-preproduction/_best-practices-definition-of-done.md`.
