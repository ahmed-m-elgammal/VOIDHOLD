# EPIC 4 — Units + Enemies (AI FSM plan)

Goal: helot/mighty lifecycles + flying enemies + authority defense loop closed. Blocks content + UX.
Team: Tech Lead AI + Designer + Audio (barks/FX hooks).

## T4.1 UnitFSM (helot + mighty)
- States: Work/Eat/Relax (+Oppulence bar for mighty)/Idle/GoUnderground + job states Fetch/Store/Repair/Incident/GoHome variants. Route via dome AStar, `routeFinished` -> `workerEnter`, timeout -> `workerExit` -> next. `fullness -=0.002/s` while moving. Idle fallback max 3 tries.
- Caste tables: helot `work90s [farm,mine,storage,oremine,teleport,maintenance] -> eat30s [cantine] -> relax30s [living]`; mighty `work60s [factory,kitchen,authority] -> eat -> oppulence[bar]` (legacy internal ID two p's, display Oppulence) `-> relax[quarter]`. Idle spots `[farmarea,mineshaft,oxygen,solar,teleport]`.
- Accept: 10-min follow-cam shows full cycles, no stuck units, job cancel safe.

## T4.2 Needs + population
- Happiness/fullness 0-1 clamps, mood affects productivity, hunger icons, eat-shortening when full>=0.99, spawn if `avg>0.8 + free bed` every 40s from elevator, death if fullness<=0, elevator-down exit with toast. Beds = living/quarter residents[] capacity.
- DB: unit GUID + caste + mood + state refs per T0.6. Name via `names` list + localization.
- Accept: spawn/death/bed-full matrix, starvation warning 60s before death.

## T4.3 EnemyFSM flying
- States `random15s -> attack60s -> gohome`, route = hover lerp (no AStar), attack reserves via `incidentReserve->Enter`, damages 0.01/s, `Building under attack!` toast + sound throttle 2s. Authority mech counter is 0.2 per approved simulation update when in 80px. Death -> `incidentCancel` + `Enemy died` + view cleanup. Spawn every 20s with an explicit cap and 50% chance from spawn tiles; cap behavior must be intentional rather than inherited from the source boundary quirk.
- Beetle ground: stub only, no pathing in v1.
- Accept: siege -> defend -> gohome loop, 3-enemy cap held, incident refs never leak.

## T4.4 Population manager + subscribers
- Dome `units[]`, averages, `hasRepairNeed/hasIncidentNeed/hasStorageTodo` counts driving job assignment priority (repair by damage-dist, fetch by fullness-dist). Emit on spawn/death for views + saves.
- Accept: need-counters match manual count, job assignment prioritizes correctly in repro.

## Simulation quality gate
- Unit and enemy FSMs run in the headless simulation without scene nodes or animation callbacks.
- Save/load during movement, reservation, attack, repair, starvation warning, and elevator exit leaves no dangling references.
- A deterministic replay reproduces a complete 20-minute colony cycle and a siege.

## Epic exit
Colony lives 20 min unattended without deadlocks, siege defended, saves include units/enemies cleanly, and the core loop is ready for the premium slice.

## Premium vertical-slice gate
- After Epic 4, integrate the first finished art subset from Epic 5 and the first finished HUD/sheet subset from Epic 6.
- Demonstrate one complete dome loop in portrait and landscape on the minimum device: build, assign, produce, defend, save, interrupt, resume, and fast-forward.
- Do not start bulk production of the remaining buildings until the visual lead, game designer, Tech Lead, and QA sign the slice.
- Accept: slice checklist from T0.10 passes, no critical visual/readability defect remains, deterministic replay and save recovery pass, and the minimum-device frame-time/thermal budget passes.
