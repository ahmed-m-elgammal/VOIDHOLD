# PROVENANCE — mobile/assets

Per `tasks/epic-0-preproduction/T0.3-license-purge.md` and
`tasks/epic-2-world-domes/ASSET_REQUIREMENTS.md` section 12, every asset
family records source, author, license, modification rights, reviewer, and a
reproducible source package.

**No asset in this folder derives from the quarantined legacy packs
(`images/`, `imagesoga/`, `ogaunused/`, old `music/`, `sounds/`, `map.tmx`
tile pixels).**

## 1. Procedural assets (original work)

| Family | Paths | Source package | License |
|---|---|---|---|
| Ground PBR set | `world/ground/*` | `mobile/tools/asset_gen/gen_ground_textures.py` + `vh_common.py` | Repo license |
| Logical mask atlas | `world/masks/*` | `mobile/tools/asset_gen/gen_mask_atlas.py` (input: `mobile/data/grid.json`) | Repo license |
| Sky / atmosphere | `world/sky/*` | `mobile/tools/asset_gen/gen_sky.py` | Repo license |
| Fence FX textures | `domes/fence/*` | `mobile/tools/asset_gen/gen_fence_fx.py` | Repo license |
| Placement feedback | `ui/placement/*` | `mobile/tools/asset_gen/gen_fence_fx.py` | Repo license |
| Icon packs + brand | `ui/icons/*`, `brand/*` | `mobile/tools/asset_gen/gen_icons.py` (SVG masters emitted by code) | Repo license |
| Greybox model kit | `domes/greybox/*.glb`, `world/ground/dressing/*.glb` | `mobile/tools/asset_gen/gltf_writer.py` + `gen_greybox_models.py` | Repo license |

- **Author**: generated programmatically for VOIDHOLD (agent-assisted
  production pipeline), seeds pinned in the scripts; every file is
  reproducible byte-for-byte from the recorded source package.
- **Third-party content**: none. All geometry, textures, and vectors are
  synthesized from mathematical noise / geometric primitives at generation
  time. No scraped images, no external fonts, no sampled data.
- **Modification rights**: unrestricted — the source scripts are the editable
  masters; regenerate with new seeds/sizes as needed.
- **Human reviewer**: `__________` (visual lead — sign off before any of these
  are promoted to `art_final/` per ASSET_REQUIREMENTS section 12).
- **Review artifacts**: `_preview_*.png` sheets (ground, greybox montage)
  accompany each family for the review pass.

## 2. AI-generated concept sheets (REFERENCE ONLY — DO NOT SHIP)

| File | Used for |
|---|---|
| `concepts/E2-03_dome_fence_kit_concept.png` | fence kit shape language |
| `concepts/E2-04_dome_entrance_concept.png` | entrance/airlock design |
| `concepts/E2-05_elevator_concept.png` | elevator + expansion pad design |
| `concepts/E2-07_slice_building_set_concept.png` | six-building slice composition |
| `concepts/E2-09_world_lookdev_keyart.png` | world mood / look-dev target |

- **Generator**: GLM image generation (z-ai-web-dev-sdk), 2026-09-21.
- **Prompts**: recorded verbatim in `mobile/tools/asset_gen/gen_concepts.sh`
  (style block + shared negative prompt from ASSET_REQUIREMENTS section 3).
- **Rule**: per ASSET_REQUIREMENTS section 3, image-model output is a
  concept/reference sheet only. Any design carried forward must be rebuilt as
  a clean, editable asset (Blender/Substance or the procedural scripts) with a
  human reviewer before it enters the game or `art_final/`.
- **Known limitations**: AI sheets may contain text-like artifacts and must
  not be cropped into UI or store assets as-is.

## 3. Promotion checklist (to `art_final/`)

- [ ] visual lead approved silhouette at low/medium/high gameplay zoom
- [ ] palette + material rules match the art bible
- [ ] Godot Mobile renderer import tested (ETC2/ASTC)
- [ ] collision, origin, scale, LOD, visibility range set
- [ ] low-tier readability confirmed
- [ ] no baked English-only text where localization is required
- [ ] reviewer signature recorded above with date
