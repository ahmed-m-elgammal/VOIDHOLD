#!/bin/bash
# VOIDHOLD AI concept/reference sheets (Epic 2).
# Per ASSET_REQUIREMENTS.md section 3: AI-generated images are CONCEPT/REFERENCE
# ONLY — approved designs must be rebuilt as clean editable assets before use.
set -e
OUT=/home/z/my-project/VOIDHOLD/mobile/assets/concepts
mkdir -p "$OUT"

STYLE="Authored industrial survival colony on a frozen exomoon, realistic-but-readable low-poly PBR game art, designed for orthographic 2.5D mobile colony builder, quiet and mineral mood: powder snow #E8EEF4, blue ice, dark basalt rock #6B7280, oxidized blue-gray alloy #3A4750, restrained warm amber safety markings #FFB020, warm habitation light #FFC37A, sparing cyan/ice-blue technology glow, clean shape language readable at gameplay zoom, neutral concept-sheet presentation"
NEG="no generic sci-fi kit, no cyberpunk city, no random neon, no excessive bloom, no glowing everything, no floating parts, no fantasy ornament, no copied game art, no pixel art, no baked words or logos, no UI panels, no excessive tiny greebles, no noisy grunge, no texture repetition"

gen () {
  local file="$1"; local prompt="$2"; local size="${3:-1344x768}"
  echo "--- $file"
  z-ai image -p "$prompt. $STYLE. $NEG" -o "$OUT/$file" -s "$size" && echo "ok: $file" || echo "FAILED: $file"
}

gen "E2-03_dome_fence_kit_concept.png" "Concept sheet of a modular dome perimeter fence kit for a moon colony: straight emitter posts, corner post, gate post, small service beacon, dark alloy posts with thin cyan ice-blue laser strands between them, small amber service indicators, engineered perimeter infrastructure not magic force field, white grid presentation layout with multiple angles, orthographic views"

gen "E2-04_dome_entrance_concept.png" "Concept sheet of a readable dome entrance airlock for a moon colony game: compact airlock threshold, two pressure doors, small overhead beacon, snow-cleared approach path, rounded habitat engineering doors with hard industrial exterior framing, orthographic three-quarter view, white grid presentation layout with front and side views"

gen "E2-05_elevator_concept.png" "Concept sheet of an old-world underground access elevator upgraded by a moon colony: compact landing platform, reinforced central lift collar, four service pylons, amber arrival beacon, safety rails, snow-cleared footprint, strong vertical light cue, simple recognizable silhouette from far away, orthographic three-quarter view, white grid presentation layout"

gen "E2-07_slice_building_set_concept.png" "Concept sheet of six colony buildings together inside one translucent dome on a frozen moon: compact vertical oxygen recycler tower with stacked pressure cylinders, rounded habitat capsules with warm windows, low greenhouse vault with planted rows visible, small vertical-axis wind power turbine, low broad storage hub with cargo bays, circular teleport pad, day lighting, readable distinct silhouettes, orthographic 3-4 view"

gen "E2-09_world_lookdev_keyart.png" "Wide game key art of a frozen exomoon colony seen from above at three-quarter orthographic angle: glowing translucent dome protecting a small settlement, one hero habitat with warm windows, wind turbine, greenhouse, cyan laser fence perimeter, thin cold haze horizon, deep blue-black sky with sparse stars and one distant icy moon, day and warm night mood, clean readable composition"

echo "ALL DONE"
