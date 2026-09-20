# EPIC 6 — VOIDHOLD Adaptive Mobile UX (Build plan from T0.5 wireframes)

Goal: shippable touch UI in `en` + `ar` (RTL) across portrait, landscape, tablets, foldables, split-screen. `es`/`de` stubbed. Blocks beta.
Team: UI/UX + Client engineer + Audio/haptics.

## T6.1 TopHud
- Resources Stone|Alloy|Biomass|Ore|Stim + Pop/Happy/Food/O2/Energy bars, red pulse + warning icons, safe-area + notch, sunlight contrast pass, portrait compact vs landscape full.
- Accept: all warnings visible <1s after trigger, 48dp targets, screenshot both orientations.

## T6.2 BuildBar (3 tabs)
- Service/Industry/Colonists tabs, cards with cost + lock by tech tree + disabled reasons, horizontal scroll landscape / drawer portrait, ghost preview handoff to Epic 2.
- Accept: lock matrix matches tech_tree.json, locked tap shows requirement.

## T6.3 BuildingSheet + UnitCard
- Bottom-sheet: title, status (energy/damage/efficiency/storage bars with WHY breakdown), stored goods, workers slider, import/export selects, demolish 2-tap confirm. UnitCard: portrait, mood bars, job + carrying, follow button.
- Accept: every sim field from T0.6 viewable, destructive guarded, sheet drag + back-button closes.

## T6.4 Toasts + FTUE + Reports
- Toasts replace spawnPopup (produced/used/starving/attack/teleport), queue max 3, color-blind safe. FTUE 7 steps with skippable + repair/defend coaching. Reports graphs (storage/production/pop/damage) port from Raphael to Godot Controls.
- Accept: FTUE funnel 80% complete in test, toasts never cover placement area.

## T6.5 Pause + Settings + Notifications
- Pause Save&Exit + Continue, quality Low/Med/High, music/sound/haptics/language, legal links, notification permission post-FTUE (inexact only for API 36).
- Accept: settings persist, pause autosaves, permission denied degrades gracefully.

## T6.6 Portrait pass + accessibility
- Drawer behavior, full-screen sheets, font scaling, reduced motion, color-blind labels + icons, 6-inch phone QA.
- Accept: no h-scroll, no clipped sheets, a11y checklist signed.

## Localization + accessibility gate (v1 en+ar, es/de later)
- Locale files `strings_en.csv` + `strings_ar.csv` live; `es`/`de` stubbed empty per `mobile/localization-en-ar.md`.
- Define locale files, plural rules, number formatting, text expansion, font fallback, RTL mirroring, and pseudo-localization before strings are hard-coded.
- Test TalkBack and VoiceOver semantics for HUD, build cards, sheets, warnings, graphs, placement errors, and destructive actions.
- Test large text, reduced motion, reduced haptics, high contrast, color-blind labels/icons, screen-reader focus order, and touch targets.
- Test Android window resizing, fold/unfold, split-screen, safe-area changes, and iPad multitasking without losing selection, camera, or sheet state.
- Accept: accessibility and localization evidence is attached for both orientations and the smallest supported window; no clipped or untranslated critical action remains.

## Epic exit
Figma intent is reproduced in-engine across supported windows, FTUE + warnings + reports demoed, accessibility/localization pass logged, and slice-quality visual review passed.
