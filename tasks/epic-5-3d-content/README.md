# EPIC 5 — Realistic 3D Content PBR (Art production plan, no code logic)

Goal: all 18 source buildings plus any separately approved addition, 5 rigs, VFX, and audio replace OGA at mobile budgets while meeting the approved art bible. Blocks final UX polish + perf pass.
Team: 3D Artist + Tech Artist + Audio. Engineer supports import/LOD.

## T5.1 Buildings (18 source types) PBR
- Authored low-poly + PBR sets (Albedo/Normal/Rough/Metal/AO/Emissive), hero 2048 / standard 1024, trim sheets (habitat/industrial/props), LOD0<15m/LOD1-60m/impostor, collision boxes for placement, damage variants via shader (smoke/fire attach points), texel 10.24px/cm, ASTC import with tested fallback.
- Order: oxygen/storage/living/solar first (tutorial blockers), then food/mine, then advanced, then teleport/elevator.
- Accept: turntable + in-engine day/night shots, tris/calls/memory per building logged, silhouette readable at zoom-out, asset provenance attached, and visual lead approves the asset against the art bible.

## Slice-first art gate
- Produce the first four tutorial buildings, one character, one enemy, one ground kit, one VFX language, and the first HUD as a coherent set before bulk production.
- Reject assets that are generic, over-detailed at gameplay scale, texture-noisy, over-bloomed, visually repetitive, or disconnected from the approved shape language.
- The slice set must run on the minimum device before the remaining buildings are commissioned.

## T5.2 Units rigs (5)
- Helot Crew, Officer Mighty, Carrierbot, Mech (authority), Flyer enemy. Chibi-proportioned for readability, 8-dir blend walk/idle/die, status icon sockets (hunger/happy), portrait renders for UnitCard, mech muzzle socket + light.
- Accept: walk/idle/die in-engine, icon readability at 2 zoom levels, portraits approved.

## T5.3 VFX + lighting
- Teleport beam, construction poof, muzzle flash + pooled light (max 2), damage smoke/fire, snow drift, selection outline, laser fence pulse. 1 dir light + hemisphere only.
- Best: pooled particles, max 30s lifetime, Low tier halves emission rate.
- Accept: VFX list with perf cost each, no per-building realtime lights.

## T5.4 Audio replacement
- New SFX (place/error/select/warning/repair/combat/teleport/pickup/drop) + ambient wind + 6 adaptive music tracks, -14 LUFS, .ogg. Positional via AudioStreamPlayer3D, pools to avoid clipping.
- Accept: loudness report + no OGA audio remains + mute/music toggles work.

## Epic exit
Zero unapproved assets in `art_final/`, manifest complete, visual bible review complete, and all assets under budget (<180k tris/<90 calls/<180MB in view) with frame-time evidence on the minimum device.
