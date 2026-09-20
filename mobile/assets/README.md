# VOIDHOLD — mobile/assets

Engine-facing asset library for VOIDHOLD: Moon Colony. Everything here was
generated procedurally for this project (see `PROVENANCE.md`); nothing is
copied from the quarantined legacy packs. Requirements source:
[`tasks/epic-2-world-domes/ASSET_REQUIREMENTS.md`](../../tasks/epic-2-world-domes/ASSET_REQUIREMENTS.md).

Status legend: **GREYBOX** = engine-ready placeholder, upgradeable in place.
**MEDIUM** = usable production quality for the Epic 2 handoff.
**CONCEPT** = reference only, never ship.

## Layout

```
assets/
  world/
    ground/          E2-01 ground material set (MEDIUM, tileable 1024)
      snow_albedo/_normal_gl/_roughness/_ao.png
      compacted_*    trodden snow / construction paths
      rock_*         exposed basalt
      ice_*          blue glacial ice
      macro_variation.png   R=tone, G=snow accumulation, B=mineral tint (512)
      _preview_*.png 4-up review sheets (albedo/normal/rough/AO)
    ground/dressing/ E2-08 modular dressing models (GREYBOX .glb)
    masks/           E2-01 logical mask atlas generated FROM data/grid.json
      logical_mask_a.png  210x210 RGBA: R=walkable G=mineable B=farmable A=oreMineable
      logical_mask_b.png  210x210 RGBA: R=noFence G=spawn B/A=reserved
      logical_mask_preview.png  human-readable color-coded preview (8x nearest)
    sky/             E2-02 atmosphere (MEDIUM)
      sky_day_panorama.png    2048x1024 equirect for PanoramaSkyMaterial
      sky_night_panorama.png  warm-focus night state
      distant_moon.png        1024 RGBA sprite, place on a far quad
      atmosphere_guide.md     fog/light values for WorldEnvironment
  domes/
    fence/           E2-03 laser fence FX (MEDIUM, emissive textures)
      fence_strand_gradient.png  thin cyan strand core + falloff
      fence_pulse_sheet.png      8-frame traveling pulse (2048x128)
      fence_post_glow.png        emitter tip glow sprite
    greybox/         E2-03/04/05/07 greybox model kit (GREYBOX .glb, 1 tile = 1 m)
      fence_post / fence_post_corner / fence_gate
      dome_entrance      E2-04 airlock + doors + beacon (4x4)
      elevator           E2-05 surface elevator (4x4)
      oxygen(5x5) living(5x5) farmarea(4x4) solar(3x3) storage(7x7) teleport(4x4)
      dome_shell         80x80 dome boundary placeholder (r=40 hemisphere)
      _preview_all.png   software-rendered review sheet
  ui/
    placement/       E2-06 placement feedback (MEDIUM, RGBA, no text)
      grid_overlay / ghost_valid / ghost_blocked / ghost_warning
      entrance_arrow / worker_radius_ring / selection_ring / link_marker
    icons/
      resources/     stone, alloy, biomass, ore, stim  (SVG + 512 + 48)
      buildings/     all 18 canonical IDs              (SVG + 512 + 48)
      placement/     valid, invalid, no-resource, bad-tile, missing-link,
                     outside-dome, rotate, entrance, worker-radius, new-dome,
                     no-energy, low-oxygen, output-full, starving, under-attack
  brand/
    voidhold_logo.svg/_512 + mono variant
    app_icon_1024/512/192 + adaptive_fg/bg_432 (Android adaptive layers)
  concepts/          AI-generated REFERENCE SHEETS ONLY (never ship, see PROVENANCE)
```

## Godot usage notes (4.7, Mobile renderer)

- **Ground**: 210x210 PlaneMesh (64 subdiv) + `StandardMaterial3D` per surface
  (snow/compacted/rock/ice), blend via `macro_variation.png` in a small shader.
  Textures are seamless-tileable by construction; set UV scale in whole tiles
  (e.g. 16) to keep texel density even. Import: VRAM compress ON (ETC2/ASTC).
- **Masks**: `logical_mask_a/b.png` import with filter OFF (nearest), mipmaps
  OFF, VRAM compress OFF (lossless). 1 pixel = 1 tile, x right / y down matches
  grid.json `[x, y]`. Ground shader samples these to tint mineable/farmable/
  oreMineable zones and to gate fence placement (noFence) and spawns.
- **Sky**: `PanoramaSkyMaterial` with `sky_day/night_panorama.png`; lerp
  energy/tint with the TimeManager day/night cycle. Values in
  `world/sky/atmosphere_guide.md` match the art-bible light rig.
- **Fence**: posts + gate are `.glb`; strands = thin quads/trails with
  `fence_strand_gradient.png` (additive blend, unshaded), pulse animates
  `fence_pulse_sheet.png` frames or a shader UV offset. Emissive stays legible
  without bloom on low tier.
- **Greybox buildings**: drop-in `MeshInstance3D` via `.glb` import; footprints
  match `data/buildings.json` (width x height tiles). Pivots at footprint
  center, y=0 ground. Material names are stable (`VH_*`); Godot creates
  matching materials automatically — or assign your own `StandardMaterial3D`.
  `dome_shell.glb` is a boundary placeholder (alpha blend, double-sided).
- **Icons**: `*_48.png` for HUD/build bar, `*_512.png` for store/sheets; SVG
  masters are the editable source of truth. No text is baked anywhere (EN+AR
  localization rule) — always pair icons with localized labels.
- **Ghost/feedback**: unshaded, alpha-blend, render above ground
  (`render_priority` / `no_depth_test` as needed).

## Regenerating

All assets are reproducible from `mobile/tools/asset_gen/` (see PROVENANCE):

```bash
python3 mobile/tools/asset_gen/gen_ground_textures.py --size 2048   # high tier
python3 mobile/tools/asset_gen/gen_mask_atlas.py                    # re-run after grid.json changes
python3 mobile/tools/asset_gen/gen_sky.py
python3 mobile/tools/asset_gen/gen_fence_fx.py
python3 mobile/tools/asset_gen/gen_icons.py
python3 mobile/tools/asset_gen/gen_greybox_models.py --seed 42
```

The ground materials were delivered at 1024 px (medium tier, mobile VRAM
budget); regenerate at `--size 2048` for the hero/high tier if wanted.
