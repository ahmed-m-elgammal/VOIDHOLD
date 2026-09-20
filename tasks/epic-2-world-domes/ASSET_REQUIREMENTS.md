# VOIDHOLD — Epic 2 Reusable Asset Requirements

**Game:** VOIDHOLD: Moon Colony<br>
**Epic:** 2 — World + Domes<br>
**Purpose:** reusable production brief for Epic 2 and later Epic 3–9 content
**Status:** preparation brief; no final art is approved yet

Related canonical documents:

- [`README.md`](README.md) — Epic 2 implementation scope
- [`../epic-1-foundations/README.md`](../epic-1-foundations/README.md) — data and simulation contracts
- [`../epic-0-preproduction/T0.9-visual-identity-and-art-bible.md`](../epic-0-preproduction/T0.9-visual-identity-and-art-bible.md) — visual rules
- [`../epic-0-preproduction/T0.3-license-purge.md`](../epic-0-preproduction/T0.3-license-purge.md) — provenance and replacement rules
- [`../../mobile/data/buildings.json`](../../mobile/data/buildings.json) — the canonical 18-building list and footprints

## 1. Recommendation

Build one coherent, modular VOIDHOLD kit and reuse it everywhere. Do not commission 18 unrelated buildings or accept isolated AI-generated images as final game assets.

Epic 2 only needs the world, dome boundary, placement language, elevator flow, and a small set of greybox/hero buildings. The complete building prompts are included below so the art direction is locked before bulk production begins.

Recommended production order:

1. Master materials, trim sheets, decals, camera/readability test scene.
2. Ground, atmosphere, rocks/ice, dome fence, entrance, elevator, placement feedback.
3. Four premium slice buildings: oxygen, habitat, greenhouse, and wind power.
4. Remaining 14 buildings using the same modular kits.
5. Characters, VFX, UI, audio, and launch assets.

This gives the project reusable source files instead of a collection of assets that must be rebuilt later.

## 2. Current repository asset rule

The existing legacy art and audio are reference material or quarantine material until row-level commercial rights are proven. The audit currently marks the old sprite packs, tiles, music, and sound effects for replacement or proof. `maps/map.tmx` may provide logical map properties, but its referenced tile pixels must not be used in the commercial build.

Do not put any of the following in `art_final/` without provenance approval:

- old `images/` building icons as final art;
- `imagesoga/` or `ogaunused/` art;
- old `music/*.ogg` or `sounds/*` files;
- generated images without a human reviewer and source record;
- kitbashed assets whose commercial license does not cover modification and redistribution.

Use old assets only to preserve gameplay meaning, footprint, color semantics, or silhouette references. The final assets must be authored, commissioned, or obtained from a clearly commercial-safe source.

## 3. Shared art direction

Every prompt in this document inherits these rules.

### Style

Authored industrial survival on a frozen exomoon. Realistic-but-readable low-poly PBR, designed for a locked-angle orthographic 2.5D mobile colony builder. The world is quiet and mineral: snow, blue ice, dark rock, oxidized alloy, restrained safety markings, and warm habitation light. Shape language must remain clear at gameplay zoom before surface detail is added.

Palette anchors:

- snow / ice: `#E8EEF4`, pale blue-white;
- exposed rock: `#6B7280`, cool basalt gray;
- oxidized alloy: `#3A4750`, blue-gray metal;
- safety accent: `#FFB020`, warm amber;
- habitation light: `#FFC37A`, warm interior orange;
- healthy / valid: `#35D07F`;
- danger / blocked: `#FF4D4D`;
- controlled technology glow: cyan / ice blue, used sparingly.

Do not use random neon, excessive bloom, noisy texture soup, generic capsules, fantasy shapes, baked UI text, unreadable micro-decals, or copied pixel-art silhouettes.

### Technical standard

For every 3D asset, deliver:

- editable source file: `.blend` or equivalent;
- Godot-ready `.glb` with named meshes and materials;
- LOD0, LOD1, LOD2/impostor where appropriate;
- simple collision meshes and correct origin/pivot;
- Albedo/Base Color, OpenGL Normal, Roughness, Metallic, AO, and Emissive textures;
- 2048 textures for hero buildings, 1024 for units/props, 512 for small UI/support assets;
- texture names and material slots that remain stable after revisions;
- neutral preview renders at gameplay camera, close-up, and portrait crop;
- `provenance.md` with source, author, license, modification rights, and reviewer;
- a preview of the low tier with reduced material and geometry cost.

Performance targets come from the project plan: less than 180k visible triangles, less than 90 draw calls, less than 180 MB in view, one directional light, pooled particles, trim sheets before unique materials, LOD0 below 15 m, LOD1 to 60 m, and an impostor beyond that where useful.

### Shared negative prompt

```text
No generic sci-fi kit, no cyberpunk city, no random neon, no excessive bloom, no glowing everything, no floating parts, no impossible unsupported structures, no fantasy ornament, no copied game art, no pixel art, no baked words or logos, no UI panels in the render, no excessive tiny greebles, no noisy grunge, no texture repetition, no copyright-specific imitation, no transparent-background mistakes, no unlicensed source material.
```

For image-generation tools, use the result as a concept/reference sheet only. Rebuild the approved design as a clean, editable Blender/Substance asset before it enters the game.

## 4. Reusable foundation kits

These are the highest-value assets because every later building can reuse them.

### VH-MAT — master material library

**Prompt:**

```text
Create a cohesive material library for VOIDHOLD: Moon Colony, an authored industrial survival colony on a frozen exomoon. Design production-ready PBR materials for powder snow, compacted snow, blue ice, exposed basalt, oxidized alloy, painted safety metal, dark rubber, ceramic insulation, pressure glass, warm interior glass, brushed aluminum, hazard paint, and controlled cyan/amber emissive technology. Keep roughness and metallic response physically believable; use edge wear, snow accumulation, and contact dirt as restrained masks, not noisy grunge. The materials must share scale, color science, and wear direction so buildings from different categories still feel manufactured by the same colony. Show a clean material ball study, flat tile preview, 3/4 building application preview, and night emissive preview. Deliver editable Substance/Blender graphs, albedo, OpenGL normal, roughness, metallic, AO, emissive, and mask maps at the approved resolution, with mobile variants that remove unnecessary layers.
```

### VH-TRIM — three trim sheets

**Prompt:**

```text
Create three reusable trim sheets for VOIDHOLD: habitat, industrial, and sci-fi utility. Each sheet must contain clean, tileable strips for panel seams, pressure doors, ribs, vents, brackets, pipes, rails, cable channels, bolts, warning bands, insulated edges, and snow-catching ledges. The shapes must be useful across at least ten different buildings and must avoid recognizable one-off architecture. Include neutral sections, oxidized sections, painted safety sections, and a small controlled emissive strip. Keep texel scale consistent with 10.24 px/cm, readable under an orthographic camera, and suitable for low-draw-call atlasing. Deliver the editable source, packed texture sheet, material masks, trim placement guide, and a Godot test scene showing the same sheet on habitat, factory, and utility geometry.
```

### VH-DECAL — markings and surface language

**Prompt:**

```text
Create a commercial-safe VOIDHOLD decal atlas with non-linguistic visual markings: hazard stripes, arrows, docking chevrons, airlock symbols, power symbols, oxygen symbols, storage symbols, route markers, serial blocks made from abstract characters, maintenance marks, ownership bands, and subtle snow-obscured stencils. Keep all player-facing words out of the texture because English and Arabic localization are required. Use the VOIDHOLD palette, provide color-blind-safe shape alternatives, and make every decal readable from the gameplay camera. Deliver vector masters, transparent PNG atlas, roughness/metallic/emissive masks, and dark/light variants.
```

### VH-PROP — shared utility prop kit

**Prompt:**

```text
Create a modular prop kit for a frozen moon colony: pressure tanks, oxygen bottles, cargo crates, resource bins, pipe junctions, flexible hoses, cable reels, antenna masts, flood lamps, repair cases, snow-clearing blades, railings, ladders, vents, pallets, maintenance arms, and small sensor beacons. Use the same industrial manufacturing language as VOIDHOLD buildings: oxidized alloy, insulated panels, amber safety paint, and restrained cyan indicators. Make the props useful as dressing, silhouettes, and gameplay-readable resource cues. Produce small, medium, and large variants with shared materials, clean pivots, simple collision, LODs, and an atlas-friendly texture layout. Do not create a separate unique shader for every prop.
```

## 5. Epic 2 assets to prepare first

### E2-01 — planet ground material and logical mask atlas

**Prompt:**

```text
Create the hero ground presentation for a 210 x 210 frozen exomoon colony. The ground is one broad readable surface, not thousands of tile objects. Blend snow, dark basalt/rock, blue ice, and subtle exposed mineral zones with broad shapes that remain readable at orthographic zoom 24–90. Snow should collect naturally along height breaks and rock should appear through traffic and construction areas. Keep microdetail restrained and avoid checkerboard repetition. Provide a 2048 material set, a 2048 logical mask atlas aligned to the baked walkable/mineable/farmable/oreMineable/noFence/spawn data, a subtle macro variation map, and low/medium/high material variants. The logical masks must be generated from the data contract rather than hand-painted inconsistently. Show day, night, portrait, and low-device previews.
```

### E2-02 — sky, atmosphere, distant moon, and bounds

**Prompt:**

```text
Create a restrained frozen-moon atmosphere for VOIDHOLD: a deep blue-black sky, thin cold haze near the horizon, sparse stars, one distant moon or planetary body, and soft atmospheric depth that separates the playable ground from the void. The background must support a single directional light and a day/night lerp without competing with the colony. Include a neutral daylight state, cold twilight state, and warm night state where building windows and the dome fence become the visual focus. Deliver sky/background assets or procedural references, a distant moon texture/mesh if needed, fog color/value guide, and a Godot look-development scene. Avoid photographic clutter and avoid a giant distracting planet.
```

### E2-03 — dome laser-fence kit

**Prompt:**

```text
Create the modular boundary kit for an 80 x 80 VOIDHOLD dome: straight fence emitter post, corner post, gate/entrance post, small service beacon, and a lightweight ring or spline-ready boundary mesh. The fence should feel like engineered perimeter infrastructure, not a magical force field: dark alloy posts, thin cyan/ice-blue laser strands, small amber service indicators, and a controlled pulse that communicates the protected/habitable boundary. The kit must support any dome rectangle and multiple domes without unique manual meshes. Include active, low-power, blocked, damaged, and selected material states. Keep the glow thin and legible on a low-end phone; no full-screen bloom. Deliver modular meshes, trim/decals, emissive mask, collision/selection helpers, LODs, and a shader reference scene.
```

### E2-04 — dome entrance and interior transition

**Prompt:**

```text
Create a readable dome entrance for the VOIDHOLD 80 x 80 dome: a compact airlock threshold, two pressure doors, a small overhead beacon, snow-cleared approach, and a visible interior/exterior transition. It must align to the grid, stay walkable, and remain identifiable at gameplay zoom. Use rounded habitat engineering for the doors and hard industrial framing for the exterior. Provide open, closed, selected, damaged, and low-power states without changing the footprint. Deliver the entrance model, arrow/approach marker, collision, LODs, emissive indicators, and neutral/day/night previews.
```

### E2-05 — elevator and second-dome expansion pad

**Prompt:**

```text
Create the external elevator asset that starts a new dome in VOIDHOLD. It must read as an old-world underground access point upgraded by the colony: a compact landing platform, reinforced lift collar, service pylons, arrival beacon, safety rails, snow-cleared footprint, and a strong vertical light cue that can guide the camera during the new-dome flow. The silhouette must remain simple and recognizable from far away. Include inactive, selected, construction, active, damaged, and newly-created-dome states. Design the beacon so it can visually connect to the dome manager and camera jump without becoming a permanent giant beam. Deliver the model, footprint/collision, materials, LODs, construction shell, activation VFX anchor points, and a 3/4 orthographic presentation sheet.
```

### E2-06 — placement feedback asset pack

**Prompt:**

```text
Create the complete placement language for VOIDHOLD. Include a translucent building ghost material, green valid state, red blocked state, amber warning state, four rotation states, footprint grid overlay, entrance arrow, worker-radius ring, link/missing-link marker, no-resource marker, bad-tile marker, outside-dome marker, and elevator-special marker. The visuals must make the reason for failure obvious without relying on color alone: pair color with shape, icon, short localized UI text, and haptic/sound hooks. Keep overlays thin, calm, and readable over snow and dark rock in both landscape and portrait. Deliver shader/material variants, vector icon masters, transparent PNGs where required, ring/arrow meshes or procedural specifications, and a test sheet covering valid, no-resource, bad-tile, missing-link, and outside-dome states.
```

### E2-07 — Epic 2 greybox and slice building set

**Prompt:**

```text
Create a coherent first-pass building set for the planet and dome presentation: oxygen recycler, habitat, greenhouse, wind power unit, storage hub, and elevator. These are not disposable cubes; they are silhouette-approved greybox/hero prototypes that can be upgraded into final PBR assets without changing their footprint or visual identity. Give each building a strong category silhouette, a clear entrance/interaction side, a single readable function cue, shared modular materials, simple collision, and construction/damaged variants. Respect the canonical JSON width and height for every internal ID. Present the set together inside one dome under day and night lighting, at low, medium, and high gameplay zoom. Deliver editable blockout source, clean glTF test exports, material callouts, footprint diagrams, and a revision sheet.
```

### E2-08 — ground dressing and resource cues

**Prompt:**

```text
Create a small reusable environment dressing set for the frozen moon: low rocks, ice shards, compact snow drifts, exposed mineral seams, frost buildup, tire/boot/service tracks, shallow excavation marks, and a few safe-to-place cleared patches. The dressing must reinforce the logical map masks without hiding the placement grid or making the ground noisy. Use a small number of atlas materials and randomize scale/rotation through the engine. Include mineable, farmable, ore-mineable, no-fence, and spawn-area visual examples, but do not bake gameplay state into permanent textures. Deliver modular meshes, LODs, collision where needed, atlas textures, and density/readability guidance.
```

### E2-09 — world look-development and readability scene

**Prompt:**

```text
Create a reusable Godot look-development scene containing one 80 x 80 dome, the ground material, fence boundary, entrance, elevator beacon, oxygen/habitat/greenhouse/wind-power buildings, a placement ghost, one warning state, and one second-dome link. Provide day, twilight, night, low-tier, portrait, and sunlight-brightness captures. The scene must prove that the cold world, cyan perimeter, warm habitation light, amber construction cues, and red failure cues remain readable without excessive bloom. Include camera distances 24, 48, and 90, material/lighting notes, and a checklist for triangles, draw calls, texture memory, and silhouette recognition.
```

## 6. Full reusable building library — 18 prompts

The canonical data contains 18 buildings. Use these prompts after the Epic 2 look-development scene is approved. Each building should reuse the foundation materials, trim sheets, props, decals, construction shell, damage overlays, and LOD rules above.

### 1. `oxygen` — Oxygen Recycler

```text
Design a compact vertical oxygen-recycling tower for a frozen moon colony: stacked pressure cylinders, intake/exhaust fins, insulated pipe loops, a service hatch, and a restrained cyan oxygen-flow indicator. Give it a tall, unmistakable silhouette, a clear maintenance side, snow-catching ledges, and a warm amber emergency light. It must feel essential but not militarized, fit the canonical footprint, and remain readable at low zoom. Include construction, active, low-power, damaged, and LOD variants using shared VOIDHOLD materials.
```

### 2. `living` — Habitat

```text
Design a rounded modular habitat for VOIDHOLD Crew: pressure-safe capsule geometry, connected living modules, warm interior windows, a visible airlock, small privacy fins, and subtle ventilation. It should be the softest silhouette in the colony while still sharing oxidized alloy and snow-worn construction with the industrial buildings. Make the warm windows the night read, not a flood of neon. Include a scalable module seam so multiple habitats feel related without being clones, plus construction, occupied, low-power, damaged, and LOD variants.
```

### 3. `farmarea` — Greenhouse

```text
Design a compact greenhouse on a frozen moon: low transparent pressure panels, insulated structural ribs, visible planted rows, condensate channels, grow-light strips, and a snow-cleared service door. The interior should read as living biomass without becoming a bright glass box. Use warm green/amber interior accents, cool exterior ice reflections, simple readable geometry, and the canonical footprint. Include a transparent/opaque low-tier fallback, construction frame, damaged glass variant, collision, and LODs.
```

### 4. `solar` — Wind Power Unit

```text
Design the colony wind-power unit represented by the `solar` internal ID: a compact vertical-axis turbine or wind harvester with a sturdy base, protected generator housing, simple blades, cable conduit, and a small cyan/amber status indicator. It must read as an energy source from far away without looking like a modern Earth wind farm. Keep the silhouette low and clear so it does not obscure nearby buildings. Include still, operating, damaged, construction, and low-tier variants with shared materials.
```

### 5. `storage` — Storage Hub

```text
Design a low, broad storage hub with segmented cargo bays, resource bins, carrierbot access points, a loading apron, insulated roof panels, and a small inventory indicator. Use deliberate color bands for stone, alloy, biomass, ore, and stim only in replaceable decals or light states; do not bake localized text into the model. The silhouette must communicate logistics and remain readable in a crowded dome. Include open/closed loading states, construction, full-output warning, damage, collision, and LODs.
```

### 6. `elevator` — Surface Elevator

```text
Design the external elevator as a compact reinforced access platform with a central lift collar, service pylons, safety rails, amber arrival beacon, and a snow-cleared approach. It must feel older and more infrastructural than the new colony buildings, while still using the same material library. Create strong top-down readability, clear approach direction, construction/active/damaged states, and an activation anchor for the second-dome flow.
```

### 7. `farm` — Food Processing

```text
Design a food-processing building that receives greenhouse biomass and converts it into concentrated nutrition: enclosed processing drums, intake hopper, sealed conveyor, filtration vent, small loading hatch, and amber production indicator. Use a medium industrial silhouette with no open flame and no fantasy machinery. Show a readable connection direction toward greenhouse/storage, include construction, active, output-full, damaged, collision, and LOD variants.
```

### 8. `cantine` — Cantine

```text
Design a compact colony cantine that delivers food to hungry colonists: a warm service window, covered queue/approach, insulated dining module, visible food-service hatch, and soft interior glow. It must be distinct from the habitat and kitchen: more public and accessible, with a low, welcoming silhouette. Keep the exterior rugged and the interior warm but restrained. Include open/closed service, construction, starving-warning anchor, damage, and LOD variants.
```

### 9. `mine` — Stone Processing

```text
Design a stone-processing building with a protected crushing drum, dust filtration, input chute, output block conveyor, heavy foundation, and visible maintenance access. It should feel grounded and mechanically heavy, with dark rock dust and oxidized alloy but no uncontrolled particles in the base material. Make the resource flow readable from the gameplay camera. Include active, idle, output-full, construction, damaged, collision, and LOD variants.
```

### 10. `mineshaft` — Stone Collector

```text
Design a small ground-level stone collector that marks a mineable zone: anchored extraction head, reinforced frame, short conveyor or chute, sensor flag, and snow/rock cut into the ground. It must be visibly lighter and smaller than the stone processor and communicate that it is a source site rather than a factory. Include valid/occupied tile presentation, construction, depleted/idle cue, damage, simple collision, and LOD variants.
```

### 11. `oremine` — Ice Drilling

```text
Design an ice-drilling extractor for ore: vertical bore head, coolant pipes, stabilizing legs, ice chip guards, ore sensor, and a restrained blue/amber operating indicator. Its silhouette must be distinct from the stone collector and clearly penetrate the ice. Use cold translucent details only where they help readability. Include active drilling, idle, construction, damaged, no-ore cue, collision, and LOD variants.
```

### 12. `factory` — Metal Foundry

```text
Design a metal foundry that processes ore into alloy: enclosed furnace block, ore hopper, casting or output bay, heat shielding, crane/armature, vent stack, and controlled orange heat visible through protected slits. Make it the colony's heavy industrial hero without covering the world in fire or smoke. Use a hard wedge silhouette, deep oxidized metal, safety bands, and a warm internal glow. Include active, idle, output-full, construction, damaged, collision, and LOD variants.
```

### 13. `kitchen` — Cooking Area

```text
Design a cooking area that converts biomass into stim: sealed kitchen modules, ingredient intake, thermal exhaust, service hatch, insulated ducts, and a warm but clinical interior light. Distinguish it from the cantine by making the kitchen more industrial and back-of-house. Keep pipes and vents large enough to read from gameplay zoom. Include active, idle, no-input, construction, damaged, collision, and LOD variants.
```

### 14. `maintenance` — Repair Service

```text
Design a repair-service depot with repairbot docking bays, tool arms, spare-part racks, stone/alloy service bins, a visible maintenance apron, and a calm amber work light. It should communicate repair and support rather than production. Use a low utility silhouette, accessible service side, replaceable hazard decals, construction and damaged states, and anchor points for repair VFX and small repairbots.
```

### 15. `quarter` — Luxury Quarters

```text
Design refined luxury quarters for VOIDHOLD Officers: a taller, cleaner pressure habitat with controlled panoramic glass, layered warm lighting, privacy fins, a small observation niche, and more precise alloy finishing than Crew housing. It must feel aspirational without using gold, fantasy ornament, or a palace silhouette. Keep the same engineering language and footprint discipline. Include day/night windows, construction, damaged, low-power, collision, and LOD variants.
```

### 16. `bar` — High Culture

```text
Design a high-culture recreation building for Officers: a tall compact lounge with warm panoramic glass, sheltered entrance, subtle amber interior, controlled sound/light beacon, and a distinctive vertical silhouette. It should be recognizable as recreation from far away while remaining believable as a pressure-safe colony building. Avoid nightclub neon. Include closed/open service, construction, damaged, collision, and LOD variants.
```

### 17. `authority` — Defense Authority

```text
Design an authority defense building with a low armored command core, one visible mech bay, sensor mast, protected firing/observation ports, and a controlled cyan target-tracking light. It must read as defensive but not like a modern military base or a giant weapon tower. Use angular hard-surface geometry, clear sightline direction, and a small footprint that leaves nearby paths readable. Include idle, alert, active incident, damaged, construction, collision, muzzle/impact anchor points, and LOD variants.
```

### 18. `teleport` — Dome Teleport

```text
Design a dome teleport platform: circular reinforced pad, four stabilizer pylons, a central field aperture, service console, cable routing, and a restrained cyan/ice-blue beam anchor. It must communicate inter-dome logistics rather than magical travel. Keep the pad readable from overhead, make the beam optional and pooled for mobile performance, and provide inactive, charging, active, blocked/full, construction, damaged, collision, and LOD variants.
```

## 7. Characters and creatures

The source plan calls for five main rigs, with a repairbot as a recommended supporting prop/rig.

### Crew / internal `helot`

```text
Design a readable VOIDHOLD Crew colonist in a compact cold-weather pressure suit: rounded helmet, layered insulated torso, utility harness, boots, gloves, small color-coded role marker, and a silhouette that remains identifiable at gameplay zoom. Use the same oxidized alloy, fabric, amber safety, and cyan status language as the buildings. Avoid military armor and avoid a generic astronaut suit. Deliver an 8-direction mobile rig with idle, walk, carry, work, eat, relax, repair, worried, and die states, plus a clean portrait crop.
```

### Officers / internal `mighty`

```text
Design a VOIDHOLD Officer colonist from the same population but with a visibly different silhouette: cleaner tailored pressure coat, higher collar, refined utility details, controlled warm accent, and a more deliberate posture. The character must be readable as a different caste without relying only on color or text. Deliver the same 8-direction rig and state coverage as Crew, plus portrait, selected, hungry, happy, and injured variants.
```

### Carrierbot

```text
Design a small autonomous carrierbot for colony logistics: low center of gravity, two or four robust drive units, visible cargo tray, scanner eye, docking contacts, snow-resistant shell, and a compact amber/cyan status light. It must look dependable and utilitarian, not cute toy-like. Deliver idle, move, load, unload, blocked, damaged, and shutdown animations, with low-poly LODs and simple collision.
```

### Authority mech

```text
Design a compact defense mech operated from the Authority building: squat stable stance, protected sensor head, two controlled weapon mounts, insulated joints, visible power pack, and a silhouette distinct from both colonist castes and flying enemies. Keep it practical for a dome perimeter and avoid oversized military spectacle. Deliver idle, patrol, aim, fire, hit, damaged, and shutdown states, with a low-tier version and muzzle/impact sockets.
```

### Flying enemy

```text
Design the launch flying enemy for VOIDHOLD: a hostile, non-human aerial silhouette with asymmetric wing/rotor geometry, a bright but controlled sensor core, armored underside, and readable attack posture. It must contrast strongly against white snow and dark sky and remain identifiable in a small portrait or gameplay view. Do not make it resemble a real animal or a generic drone. Deliver idle flight, approach, attack, retreat, hit, damaged, and death animations, plus a low-tier silhouette and attack/VFX sockets.
```

### Optional repairbot

```text
Design a tiny maintenance repairbot that can dock at buildings and move short distances: articulated tool arm, compact body, visible spare-part compartment, amber work light, and a clear repair action. Keep it visually subordinate to colonists and carrierbots so it does not create a crowded scene. Deliver idle, travel, dock, repair, damaged, and shutdown states with a simple collision and low-poly LOD.
```

## 8. VFX packages

All VFX should be pooled, short, readable, and mobile-safe. Use one directional light and emissive materials instead of many dynamic point lights.

### Fence pulse

```text
Create a thin cyan/ice-blue dome-fence pulse VFX for a modular 80 x 80 boundary. The pulse must travel around the perimeter or breathe uniformly, show active/low-power/damaged states, and remain legible without full-screen bloom. Use a shader and small pooled particles only where necessary; provide intensity tiers for low, medium, and high quality.
```

### Construction assembly

```text
Create a restrained construction VFX language: grid scan, materializing frame, small welding sparks, snow displacement, dust puff, and final amber-to-cyan confirmation. It must work for all 18 building silhouettes without hiding the model and must have a low-motion/reduced-motion variant.
```

### Elevator activation and dome creation

```text
Create a cinematic but mobile-safe elevator activation VFX: ground dust, vertical lift light, beacon flash, expanding dome boundary trace, and a short camera-readable confirmation pulse. It must communicate the new dome being created without a permanent beam or excessive bloom. Provide fast and reduced-motion variants.
```

### Teleport beam

```text
Create a pooled inter-dome teleport beam using a narrow cyan core, soft ice-blue halo, four stabilizer arcs, and small particles that move toward the destination. It must sit cleanly on the teleport platform, scale between domes, and have charging, active, blocked/full, and shutdown states. Keep overdraw low and provide a low-tier beam.
```

### Damage and fire

```text
Create a shared damage VFX system: light smoke for damage above the first threshold, heavier smoke and intermittent sparks for severe damage, restrained fire at critical damage, and a clean extinguish state after repair. The VFX must attach to building sockets and never cover the silhouette or UI. Include low-tier versions using fewer particles.
```

### Energy and oxygen warnings

```text
Create small world-space warning VFX for no-energy and low-oxygen states: dimmed emissive windows, brief amber/red status pulse, subtle vent change, and a short warning marker. Pair every effect with a shape/icon and UI label; never communicate a critical state by color alone.
```

### Authority combat

```text
Create compact authority combat VFX: muzzle flash, short tracer, impact spark, target lock pulse, and enemy hit reaction. Use controlled amber/cyan/red accents, no giant explosions, no persistent lights, pooled particles, and clear directionality at the orthographic camera.
```

### Snow, wind, and dust

```text
Create a low-cost environmental VFX set: sparse drifting snow, occasional wind streaks, ground dust near construction/elevators, and small ice-chip bursts near mining. The effects must be subtle, pooled, and disabled or reduced on low tier so placement and building silhouettes remain primary.
```

## 9. UI and icon assets

UI text must be rendered from localized strings, not baked into images. Every state must use icon plus label plus color/shape.

### Logo, app icon, and dome badge

```text
Design the VOIDHOLD identity as an isometric dome mark with a strong geometric silhouette, readable at 48 dp, and usable in splash, adaptive app icon, top HUD dome badge, and shop header. Use an ice-blue/cyan outline with a restrained warm amber accent, plus light, dark, monochrome, and one-color versions. Deliver SVG/vector master, 1024 app icon, adaptive foreground/background layers, 512 UI badge, safe-area guides, and small-size legibility tests. Do not include tiny text in the mark.
```

### Resource icon pack

```text
Create five matching resource icons for stone, alloy, biomass, ore, and stim. Each icon must have a distinct silhouette, work in a 24–48 dp HUD slot, remain understandable in monochrome and color-blind conditions, and use the VOIDHOLD material language without tiny illustration detail. Deliver vector masters, 512 PNG exports, 64/48/32/24 dp exports, disabled/selected/warning states, and dark/light background tests.
```

### Building icon pack

```text
Create 18 building icons matching the canonical internal IDs: authority, bar, cantine, elevator, factory, farm, farmarea, kitchen, living, maintenance, mine, mineshaft, oremine, oxygen, quarter, solar, storage, and teleport. Use the approved building silhouettes, a consistent icon grid, category shape language, readable 24–48 dp forms, and no text. Include locked, available, selected, insufficient-resource, damaged, and unavailable states. Deliver vector masters and localized UI-ready exports.
```

### Warning and placement icon pack

```text
Create icons for no energy, low oxygen, output full, starving, under attack, bad tile, no resource, missing link, outside dome, rotate, entrance, worker radius, valid placement, invalid placement, and new dome. Each icon must remain meaningful without color, have a clear silhouette, and pair cleanly with English and Arabic labels. Deliver vector masters, dark/light states, disabled states, and 48 dp touch-target previews.
```

### UI surface and interaction kit

```text
Create a small reusable UI visual kit for VOIDHOLD: dark mineral panels, snow-bright cards, thin cyan focus lines, amber action states, red warnings, progress meters, tabs, bottom-sheet handles, selection rings, toast surfaces, and map labels. Use restrained translucency, strong contrast in sunlight, 48 dp minimum targets, RTL-safe geometry, reduced-motion alternatives, and no baked text. Deliver Figma/vector source plus Godot-ready 9-patch or SVG/PNG assets.
```

### Character portrait pack

```text
Create clean portrait assets for Crew, Officers, carrierbot, authority mech, and flying enemy. Use consistent head/upper-body framing, neutral background, readable expression/state, and the same cold/warm palette as the world. Deliver neutral, selected, hungry/low-fullness, damaged, happy, and warning variants at UI resolution, with enough empty space for localized labels.
```

## 10. Audio assets needed later

Audio is not an Epic 2 art blocker, but it should use the same authored identity and should replace the legacy files before release.

### SFX pack

```text
Create an original mobile sci-fi colony SFX pack for VOIDHOLD: tap/select, rotate, place, blocked placement, resource insufficient, sheet open/close, construction start/complete, repair, demolition confirmation, elevator activation, dome fence pulse, teleport charge/transfer, warning states, carrierbot movement/loading, mining, processing, wind power, cooking, combat, enemy hit/death, and save/resume. Use a tactile cold-industrial palette: ceramic clicks, insulated metal, low mechanical thumps, filtered air, and restrained electronic tones. Deliver clean one-shot WAV masters, normalized variations, loopable ambience where needed, metadata, and a mix guide targeting the project loudness plan.
```

### World ambience

```text
Create original seamless ambience for a frozen moon colony: distant wind, pressure systems, low habitat hum, occasional ice movement, industrial machinery, carrierbot movement, and quiet dome air. Provide exterior, interior, storm/pressure, night, and damaged-colony layers with loop points and mobile-friendly stems. Keep the soundscape sparse so alerts and gameplay feedback remain clear.
```

### Adaptive music

```text
Create six original adaptive VOIDHOLD music tracks for a cold industrial colony: landing/hope, productive colony, quiet night, rising pressure, attack/defense, and recovery/expansion. Use evolving low electronic, mineral percussion, restrained strings or pads, and warm harmonic movement when the colony succeeds. Supply loopable stems and intensity layers, seamless transitions, metadata, and a final mix near -14 LUFS. Do not reuse the legacy OGA tracks.
```

## 11. Launch and presentation assets

These are later Epic 6/9 assets, but the identity should be prepared once and reused.

### Store key art

```text
Create VOIDHOLD: Moon Colony store key art showing a readable frozen exomoon settlement inside a glowing dome, one hero habitat, wind power unit, warm windows, a distant moon, and restrained cyan/amber state lighting. The composition must work in portrait and landscape crops, leave safe space for store text overlays, and use the exact approved building language rather than generic sci-fi city shapes. Deliver layered source, portrait crop, landscape crop, square crop, and clean no-text versions.
```

### Screenshot capture direction

```text
Create a screenshot capture brief for VOIDHOLD showing: first dome landing, valid placement, blocked placement with reason, productive colony at night, under-attack warning, second-dome expansion, and portrait UI. Every capture must show real game assets and readable UI, with no misleading effects, no fake unavailable features, and enough composition space for store captions. Deliver a shot list, camera settings, UI-state checklist, and portrait/landscape crop guides.
```

## 12. Asset acceptance checklist

An asset is ready for `art_final/` only when all of these are true:

- visual lead approved the silhouette at low, medium, and high gameplay zoom;
- the asset follows the shared material and palette rules;
- source file is editable and organized;
- Godot `.glb`/texture export is tested on the Mobile renderer;
- collision, origin, scale, LOD, and visibility range are correct;
- low-tier version remains readable;
- no baked English-only text exists where localization is required;
- provenance, license, author, source URL, and modification rights are recorded;
- generated or kitbashed work has a human reviewer and a reproducible source package;
- the asset is listed in the project asset manifest with a stable ID;
- the asset does not introduce unapproved OGA pixels, music, sounds, fonts, or dependencies.

## 13. What to prepare now

For the immediate Epic 2 handoff, prepare these source packages first:

1. `VH-MAT` master materials.
2. `VH-TRIM` habitat/industrial/utility trim sheets.
3. `VH-DECAL` non-linguistic markings.
4. `VH-PROP` shared utility props.
5. `E2-01` ground and logical mask atlas.
6. `E2-02` atmosphere and distant moon.
7. `E2-03` dome fence kit.
8. `E2-04` dome entrance.
9. `E2-05` elevator and expansion beacon.
10. `E2-06` placement feedback pack.
11. `E2-07` oxygen, habitat, greenhouse, wind power, storage, and elevator greybox/hero set.
12. `E2-09` look-development/readability scene.

Do not spend production time on the remaining 14 buildings until the four-building premium slice passes visual identity, mobile readability, and minimum-device performance review. The remaining prompts are ready for production immediately after that gate.
