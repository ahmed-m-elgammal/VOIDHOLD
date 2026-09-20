# EPIC 3 — Buildings Full Parity (Sim logic plan)

Goal: all 18 source buildings behave like the approved reference contract; intentional fixes and mobile tuning are measured separately. Blocks balancing, the premium slice, and UX.
Team: Tech Lead sim + Designer (tuning) + QA.

## T3.1 Building3D base
- Fields per T0.6: type, topleft, rotation, dome_guid, damage 0-1 + repairCooldown, update timer, hasEnergy, userMaxWorkers, outputStorage, storage{5}, attached buildings, workers/reservations/residents/mission refs, incidents, extra{import,export}. Cost deducts stone/alloy atomically. `isFunctional()` = damage<1 + energy + incident==null + output<max + input available. Serialize by GUID.
- Best: no display strings in sim, data-driven from buildings.json, all randomness seeded.
- Accept: create/demolish/serialize round-trip, functional matrix unit-tested on paper -> checklist.

## T3.2 All step* systems
- Port verbatim first: stepGather (productivity from mood/oxygen/damage), stepProduce (input->output with inOutFactor), stepEat (hungry-first), stepRelax (mood + drugs drain), stepRepair (stone->damage), stepIncident (0.2/tick), stepStorage/Teleport fetch assignment. Timers = updateDelta accumulators.
- Accept: 20-min soak curves for stone/biomass/alloy match the reference contract within the approved tolerance, canonical resource IDs are used, and popups/toasts fire on produce/consume.

## T3.3 Energy + Oxygen managers
- Energy: `solar*1.5*(1-damage)/need`, random shutdown order logged, `No energy` warning + FX. Oxygen: `oxygenBldgs/(bldgs*0.05+units*0.15)` affecting productivity 0.5-1.0.
- UX: HUD bars pulse red, inspector shows breakdown WHY.
- Accept: deficit repro produces shutdown + recovery, oxygen sweep table verified.

## T3.4 Ops: import/export, workers, demolish
- Worker slider 0..maxWorkers, `maxWorkers()` = min(user, perWorker-link count, type max). Import/export selects (biomass/stone/ore/alloy/stim). Demolish refunds partial, cancels workers/missions/incidents, frees walkability, sends residents home.
- Accept: slider/link interaction matrix, demolish with workers inside leaves no dangling refs.

## T3.5 Damage states + destruction
- Damage sources: constant + update + enemy. Repair consumes stone. Visual states: ok / smoke>0.2 / fire>0.9 / destroyed=1.0 removal + `destroyed` toast + save prune.
- Accept: damage->repair->destroy lifecycle demo on greybox, no orphan views.

## Simulation quality gate
- Every step system has a headless fixture covering normal, empty, full, damaged, no-energy, no-input, and destroyed states.
- Building state does not depend on scene nodes, animation timing, or frame rate.
- Worker reservations, attached worker buildings, mission workers, and incidents have explicit cancellation and save/load tests.

## Epic exit
Full 18-block soak passes, energy/oxygen sweeps logged, destruction safe, and simulation fixtures green. Ready for the premium slice and content expansion.
