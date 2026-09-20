# EPIC 1 — Project Foundations (Docs + setup plan, no sim code yet)

Goal: production Godot 4.7.2 project with canonical data, a testable deterministic simulation core, safe saves, and reproducible builds. Exit blocks Epic 2 and the premium vertical slice.
Team: Tech Lead + QA/build. Designer reviews data dictionaries.

## T1.1 Repo + project setup
- Owner: Tech Lead. Output: `project/` with the renderer selected by T0.4, 1280x720 reference size, all supported window modes, Git+LFS (`*.glb *.png *.ogg *.wav`), import presets with ASTC/ETC2 and fallback behavior, Low/Med/High tiers, autoload skeleton (GameManager, SaveSystem, AudioManager, TimeManager, EntitlementManager-stub).
- Best practices: `project.godot` version pinned 4.7.2, no Forward+ shipping, folder conventions from plan §4, atomic commits, CI validation from T1.7.
- Accept: fresh clone imports clean on Win, Android and iOS export prerequisites are documented, the chosen renderer is recorded, and tiers switchable in settings stub.

## T1.2 Data port (paper -> JSON skeleton)
- Owner: Designer + Tech Lead. Inputs: `Building.TYPES`, `PRECONDITIONS/TABS`, timers/costs.
- Outputs: `buildings.json` (18 source entries plus any separately approved new entry, with `mobile_override` and `intentional_fix` columns), `tech_tree.json`, `moons.json` (3 diffs), `balance.json` (starting 60/20/30/10, spawn 40s, enemy 20s).
- Resource keys: canonical `stone/alloy/biomass/ore/stim`, with an explicit legacy import map from `money/nutrition/drugs`.
- DB hook: internal IDs immutable, display via `strings.csv`. Validation rules documented (cost>=0, workers<=max, damage 0-1).
- Accept: JSON schema validates 18/18 source entries, canonical resource mapping, and any new entry separately; balance sheet CSV signed.

## T1.3 TMX bake tool plan
- Owner: Tech Lead. Input: `maps/map.tmx` 210x210 + 4 layers + tile properties.
- Output spec: `tools/tmx_to_json.py` -> `walkable/mineable/farmable/oreMineable/noFence/spawns` arrays + debug heatmap view. Visuals decoupled (ground shader in Epic 2).
- Accept: baked grid matches original walkability spot-check 50 tiles + spawn count >0.

## T1.4 SaveSystem v1 (design + harness plan)
- Owner: Tech Lead. Input: T0.6 schema. Outputs: versioned `user://slot%d.json v1` + thumbnail spec, atomic tmp+rename, autosave 30s + focus-out, quarantine corrupt, 3 slots + autoslot.
- Accept: round-trip checklist (save -> load -> diff zero) + corruption recovery demo plan.

## T1.5 TimeManager (design)
- Owner: Tech Lead. 1x/2x/3x + pause + offline `last_seen_utc` capped 4h (calc only, no grants). Background/foreground hooks for API 36.
- Accept: 10-min background catch-up math verified on paper + interrupt matrix ref.

## T1.6 Headless simulation + deterministic replay
- Owner: Tech Lead. Inputs: T0.8 parity fixtures and T0.6 schema.
- Build the simulation as data-only services independent of `Node3D`, `CharacterBody3D`, UI, and animation.
- Use a fixed 20 Hz simulation step with render interpolation. Define accumulator behavior, max catch-up, pause, 1x/2x/3x, and 4-hour offline fast-forward.
- Persist or deterministically derive RNG state. Add seeded replay fixtures for building updates, unit FSM, enemy FSM, energy shutdown, and teleport trade.
- Add reference-vs-Godot golden tests for normal and edge-case scenarios. Intentional fixes and mobile tuning must be labeled, not hidden in parity results.
- Accept: headless simulation runs without a scene tree, save/load produces identical state for a fixture, replay is deterministic, and offline fast-forward completes within the agreed budget.

## T1.7 CI + release integrity
- Owner: Tech Lead + build engineer. Reviewer: QA.
- Add headless import, data/schema validation, deterministic tests, asset provenance/license scan, project settings check, export smoke tests, package-size report, and performance-budget report to CI.
- Define versioning, export-template pinning, Android keystore/provisioning handling, iOS signing handling, symbol/archive retention, and secret management. Never commit signing credentials.
- Verify release and debug builds use the same content manifest and that quarantined or unreviewed assets cannot be exported.
- Accept: a clean checkout can validate and export builds reproducibly; CI blocks broken data, unapproved assets, missing notices, and failed smoke tests.

## Epic exit
All JSON skeletons validated, deterministic sim/replay harness ready, save harness checklist ready, bake spec approved, and CI export checks green. The premium vertical slice may begin only after this exit review.
