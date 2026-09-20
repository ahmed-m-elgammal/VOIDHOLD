# EPIC 2 — World + Domes (Plan, no final art)

Asset preparation brief: [`ASSET_REQUIREMENTS.md`](ASSET_REQUIREMENTS.md)

Goal: playable planet grid + dome logic + placement validation on greybox, with a clean handoff to the premium slice. Blocks Epic 3/4.
Team: Tech Lead sim + Tech Artist (ground/fence shaders).

## T2.1 Planet3D ground + environment
- Greybox PlaneMesh 210x210 (64 subdiv) + shader blending snow/rock/ice from T1.3 masks. WorldEnvironment hemisphere + DirectionalLight rig + day/night lerp affecting solar multiplier. Fog + bounds.
- Best: 1 dir light only, no per-tile nodes, mask texture 2048, anisotropy 4.
- Accept: mask matches logical grid spot-check, day/night changes light + solar value in debug overlay.

## T2.2 Dome node + AStarGrid2D
- 80x80 `AStarGrid2D` per dome, cardinal movement by default to match the source reference; any diagonal mode is an explicit mobile-design change with new placement/path tests. `placeWalkable/removeWalkable` mirrors `dome.js`, entrance kept walkable, multi-dome manager + closest-dome query.
- Laser fence shader ring (emissive + pulse), width/height from data.
- DB: dome `guid,topleft,width,buildings[],units[]` per T0.6.
- Accept: path finds around placed greybox, unplace restores walkability, 2 domes coexist.

## T2.3 Placement system
- Ghost green/red + entrance arrow + rotation 0/90/180/270 + radius viz for `perWorkerBuildingMaxRadius` + link check via `getClosestSuperBuilding` + resource check (stone/alloy) + `planetProperty` tile check + inside-dome check. Elevator outside-dome special.
- UX both orientations: rotate button, pinch stays active during placement, error toasts with reason (no-resource vs bad-tile vs missing-link).
- Accept: matrix of all invalid cases blocked with correct message, valid cases place.

## T2.4 Elevator + new dome flow
- Place elevator outside -> create 80x80 dome, push to manager, camera jump + zoom-out, spawn point set, save updated.
- Accept: dome 2 functional, camera + save carry new dome, no overlap exploit.

## Epic exit
Greybox planet + 2 domes + validated placement, no orphaned links after demolition, and a documented handoff for slice-quality ground/fence presentation. Perf: placement query <8ms on low device target.
