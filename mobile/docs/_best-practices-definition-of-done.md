# Best Practices + Definition of Done — Epic 0 (applies to all epics)

## 1. Game-dev team principles
- Gameplay first: readability > realism. If PBR hurts placement clarity, clarity wins.
- Authored identity first: every major visual has a reference, purpose, silhouette, and reviewer. A technically complete asset that looks generic does not pass.
- Mobile constraints are features: 48dp targets, 3-min sessions, sunlight contrast, battery/thermal budgets.
- No invisible sim: every number affecting fun is surfaced or logged.
- Fail fairly: warn before starvation/destruction, never instant-lose on phone interruption.
- Content pipeline over hero assets: trim sheets, LODs, import presets before modeling spree.
- A premium vertical slice must prove the final quality bar before full content production.

## 2. Docs standards
- One owner + one reviewer per task. Decision logs with date + reason.
- Internal IDs immutable (`mine`, `oxygen`). Display text localizable.
- All art in `art_final/` needs license + source. `art_inbox/` quarantine otherwise.
- No unreviewed generated, placeholder, or provenance-free asset may enter `art_final/`.
- Wireframes frozen before build. Changes need change-control note with cost.
- Visual changes need an art-bible reference and a before/after review capture.

## 3. DB/data standards
- Versioned saves, atomic writes, quarantine corrupt files, GUID refs, clamped ranges.
- No hard-coded balance in code — data files only. Original values preserved + `mobile` override column.
- Legacy resource IDs map explicitly to canonical IDs; display labels never become save keys.
- Simulation fixtures define rounding, clamping, RNG, and edge-case behavior before porting.

## 4. UI/UX standards
- Both orientations from day 1. Safe-area, notch, gesture nav, edge-to-edge (API 36).
- Back hierarchy, confirm destructives, color-blind safe + labels, reduced motion, font scaling.
- TalkBack/VoiceOver semantics, RTL layout, localization expansion, and large-text behavior are part of acceptance.
- Haptics: light select, medium place, heavy error/warning. Sounds match.

## 5. Platform standards (API 36 + iOS)
- `targetSdk 36, minSdk 24`. NDK r28+ 16KB alignment. Minimal permissions.
- Renderer choice must be explicit: Mobile/Vulkan/Metal is not the same as Compatibility/OpenGL ES.
- Ortho gameplay camera. 1 dir light. Budgets: <180k tris, <90 calls, <180MB, with frame-time p95 recorded.
- Interrupt-proof: call/lock/airplane/storage-full matrix every milestone.

## 6. Definition of Done (Epic 0 task)
- [ ] Outputs linked (doc/figma/sheet/video/logs)
- [ ] Reviewer approved + date
- [ ] Accept checklist all ticked
- [ ] Handoffs to dependent tasks noted
- [ ] Zero production code/binaries committed (Epic 0 only; T0.4 throwaway spike excluded from release and quarantined)
- [ ] Risks + open questions logged or explicitly deferred with owner
- [ ] Visual quality review evidence attached where the task changes the look or interaction feel
- [ ] Parity changes, intentional bug fixes, and mobile tuning are labeled separately

Epic 0 exit review: producer checks all ten tasks T0.1–T0.10 Done (one authoritative file per ID + labeled artifacts), then opens Epic 1. Six-file gate retired. Epic 0 stays BLOCKED while any required check is unchecked.
