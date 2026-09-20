# EPIC 9 — QA + Launch (Beta to staged rollout)

Goal: balanced, visually complete, tested, store-ready staged release. Depends on the Epic 7 platform/privacy gate and the premium visual-quality gate.
Team: Producer + QA + Designer (balance) + Engineer (hotfix).

## T9.1 Mobile balance pass
- Timers -25-30% vs reference only where approved, starting pack 60 stone / 20 alloy / 30 biomass / 10 stim, spawn 40s, enemy 20s with explicit cap, solar/oxygen curves from Epic 3 sweeps, tutorial boosts, 2x/3x + 4h offline cap validated. Difficulty multipliers per moon.
- Best: data-only changes, no code, A/B notes for post-launch.
- Accept: FTUE <5min to fun, 20-min colony survives with active play, expert moon fails if idle (by design).

## T9.2 Automated + device test plan
- Placement matrix, energy/oxygen, save corruption/quarantine, app-update migration, siege/defense, teleport trade, orientation/window switch mid-game, back-button, interrupt matrix, a11y/localization, perf regression, renderer fallback, audio interruption, and low-memory recovery.
- Add property-based placement/save tests, deterministic replay tests, golden simulation tests, and long-session soak tests; a fixed case count is not a quality metric by itself.
- Accept: 95% pass for beta, 100% blockers fixed for launch, zero known save-loss paths, and regressions tracked with owners.

## T9.3 Beta (Play Closed + TestFlight 100)
- 100 users, D1/D7, session len, FTUE completion, crash-free and ANR-free rates, save-error rate, migration success, performance tier, and feedback triage (crash/save-loss > balance > UX).
- Accept: beta report + operational telemetry verified + top-10 fixes landed or deferred with owners. A stub that cannot collect evidence does not count as telemetry.

## T9.4 Store assets + compliance
- Rebranded screenshots landscape+portrait, preview video, ASO keywords, privacy/data safety forms, age rating, support URL, credits/attribution, open-source licenses if any.
- API 36 data safety + iOS privacy manifest accurate (no excess permissions).
- Full-quality screenshots must use the final art direction; no graybox, placeholder, or unreviewed generated asset appears in store media.
- Accept: store listings in draft, compliance checklist signed, privacy/support links live, credits complete, and content-rights evidence attached.

## T9.5 Staged rollout + backlog
- 10%->50%->100% with halt criteria (crash spike, save-loss, ANR). Hotfix branch ready. Post-launch backlog: ground beetles, weather events, Moon 4 DLC, season content.
- Accept: rollout plan + rollback steps + backlog prioritized.

## T9.6 Update, migration + incident operations
- Define versioned save migrations, rollback limits, hotfix branch policy, crash/ANR/save-loss halt thresholds, customer-support escalation, and emergency communication.
- Test update from every supported prior save version, reinstall/restore behavior, partial download, low storage, and interrupted patching.
- Accept: release owner can identify a bad build, halt rollout, preserve player saves, ship a signed hotfix, and explain the recovery path.

## Epic exit
100% staged or halted with reason. No launch while the full art/content bar, save safety, platform gate, privacy gate, or operational rollback plan is incomplete. Launch retro scheduled.
