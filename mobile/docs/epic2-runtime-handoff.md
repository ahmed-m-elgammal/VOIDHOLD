# Epic 2 Runtime Handoff — World + Domes (Greybox)

Status: **Epic 2 implemented on greybox** — playable planet grid, dome logic,
placement validation, elevator-to-new-dome flow, day/night. All runtime code
is wired to the asset kit in `mobile/assets/` (commit 46c253c) and the frozen
data contracts in `mobile/data/`.

## What is running (T2.1–T2.4)

### T2.1 Planet3D ground + environment
- `scenes/world/Planet3D.tscn` — ground is one `PlaneMesh` **210×210 m
  (64×64 subdiv)**, `shaders/ground_blend.gdshader` blends snow / compacted /
  rock / ice from the E2-01 material set. Logical masks
  (`logical_mask_a/b.png`) are sampled **1 texel = 1 tile** with UVs quantized
  to texel centers and `textureLod(..., 0)` — exact grid read regardless of
  import filter/mipmap settings. `debug_view` uniform (1/2) renders the raw
  masks for grid spot-checks. Macro variation, spawn-pad marking, and a void
  rim darkening provide broad reads at zoom 24–90.
- `scripts/world/day_night.gd` — single `DirectionalLight3D` + hemisphere
  ambient + `PanoramaSkyMaterial` crossfade (day/night panoramas), fog lerp
  per `assets/world/sky/atmosphere_guide.md`. Drives `solar_mult` into every
  `DomeSim.tune`, which scales solar output in `energy_saturation()` and
  `step_energy()` — visible in the HUD debug overlay (`daylight`,
  `solar_mult`, per-dome solar saturation). Cycle values live in
  `data/balance.json → day_night`.
- Distant moon sprite at ~750 m, unshaded, behind fog.

### T2.2 Dome node + AStarGrid2D
- `scripts/world/dome_pathing.gd` — **80×80 `AStarGrid2D` per dome**,
  `DIAGONAL_MODE_NEVER` (cardinal default per Epic 2; diagonals would be an
  explicit mobile-design change with new tests), Manhattan heuristic.
  `place_walkable/remove_walkable` mirror `dome.js`; **entrance cells can
  never be blocked**; `resync()` re-derives solids from `DomeSim` walk state.
- `scripts/world/dome_world.gd` — per-dome visuals: laser-fence ring built
  from straight quad segments (entrance gap), `shaders/fence_ring.gdshader`
  (unshaded additive strands + traveling pulse, night boost), fence posts
  every 10 tiles, gate + airlock at the entrance, alpha-blended dome shell
  placeholder.
- `scripts/world/dome_manager.gd` — multi-dome manager: index parity with
  `PlanetSim.domes`, `closest_world()` query, overlap checks, and the
  T2.4 candidate-rect search (bounds, overlap+1 spacing, ≥35% walkable,
  walkable entrance strip).
- Dome record per T0.6: `DomeSim` now carries `topleft`, `dome_size` (80),
  `entrance_side`, saved/restored additively in `PlanetSim.snapshot()` /
  `load_state()`. **Guid ranges are disjoint per dome** (dome N owns
  `N*1,000,000+1…`); dome 1 keeps the Epic 1 range.

### T2.3 Placement system
- `scripts/world/placement_system.gd` — ghost with `ghost_valid/blocked/
  warning` tints, entrance arrow (rot 0/90/180/270, `R` key + Rotate button),
  `perWorker` radius ring + link marker to the closest super building,
  footprint overlay, tap-to-move / tap-again-to-confirm, hover for desktop.
  **Pinch/pan stay live during placement** (camera rig consumes drags,
  placement consumes only quick taps).
- Validation matrix, in toast-contract order: `outside-dome`,
  `elevator-outside`, `no-space`, `bad-tile` (footprint or `planetProperty`),
  `missing-link` (closest super building + slot capacity), `prerequisite`
  (tech tree), `no-resource`. Reason keys are localized (EN/AR).
- Placement query perf: **avg 0.015 ms, worst 0.044 ms** desktop headless
  (budget: 8 ms on low device target; 1000-query sample in regression).

### T2.4 Elevator + new dome flow
- Placing an elevator **outside all dome rects** validates a candidate
  80×80 rect first (no overlap exploit: candidates need +1 spacing from
  every dome, must fit in the 210×210 bounds, ≥35% walkable, walkable
  entrance strip facing the elevator).
- Confirm: pays stone/alloy from the source dome, creates the new `DomeSim`,
  seeds the placed elevator as the new dome's spawn/store (start resources),
  adds `DomeWorld`, camera jump + zoom-out to the new dome, autosaves
  immediately. Dome 2 is fully playable and save-carried.

## Validation (Godot 4.7.2, headless)

```
godot --headless --path mobile --import
godot --headless --path mobile -s tools/epic1_regression.gd     # PASS (parity)
godot --headless --path mobile -s tools/epic2_regression.gd     # 68/68
godot --headless --path mobile -s tools/save_regression.gd      # PASS
godot --headless --path mobile -s tools/offline_regression.gd   # PASS
godot --headless --path mobile -s tools/perf_regression.gd      # p95 3.37 ms
python3 tools/run_parity_tests.py                               # 28 PASS / 3 SKIP
python3 tools/ci_check.py                                       # 8/8
python3 tools/validate_data.py .                                # 10/10
```

Epic 2 regression covers: solar multiplier day/night, dome world-state save
round-trip, AStarGrid2D detour + cardinal-only + entrance protection,
the full placement validation matrix, elevator flow (2 domes, no overlap,
save carried), mask↔grid spot check (900 cells), and placement perf.

## Handoff to the premium slice (what greybox defers)

1. **Ground** — shader currently blends albedos + 2 normals + analytic
   roughness. The generated roughness/AO maps and full 2048 set are ready in
   `assets/world/ground/`; slice should add height-blended transitions
   (SDF-smoothed mask edges), triplanar cliff faces at the void rim, and
   VRAM-compress imports (ETC2/ASTC) once the editor pipeline runs.
2. **Fence** — strand quads are one additive shader; slice should add
   depth-soft particles at gate events, per-dome hue variation, and the
   8-frame pulse sheet as a flipbook instead of UV scroll.
3. **Buildings** — 8 kinds use greybox `.glb` (no collision/LOD/prod UVs,
   per `assets/PROVENANCE.md`); 10 kinds use footprint-correct procedural
   boxes with amber roof stripe + warm window strip. Replace with the VH-MAT
   / VH-TRIM / VH-DECAL / VH-PROP kits (ASSET_REQUIREMENTS §4) — the
   `BuildingView` kind→model mapping is the single swap point.
4. **Missing reusable packages** — master material library, trim sheets,
   decal atlas, prop kit, look-dev scene (E2-00 level) are still open; see
   `tasks/epic-2-world-domes/ASSET_REQUIREMENTS.md` §4.
5. **Units/enemies have no world visuals yet** (Epic 4); pathing is in place.
6. **Camera** — pinch zoom + drag pan + focus tween are in `camera_rig.gd`;
   edge-of-screen pan and rotation gestures remain Epic 6 work.
