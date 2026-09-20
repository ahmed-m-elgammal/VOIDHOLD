# Localization Plan — VOIDHOLD v1 en+ar, later es+de (docs only)

## Scope lock
- v1: `en` (LTR default) + `ar` (RTL). All critical paths playable in both.
- Deferred: `es`, `de`. Files stubbed as `strings_es.csv` / `strings_de.csv` empty, no hard-coded English anywhere.
- Internal IDs immutable (`stone/alloy/biomass/ore/stim`, building IDs incl. `cantine/oppulence` legacy spellings). Display only via locale tables.

## Deliverables (Epic 0 paper, Epic 6 build)
- [ ] `strings_en.csv` + `strings_ar.csv` key lists from T0.5 (HUD, BuildBar, sheets, warnings, tutorial, settings, shop stub, legal).
- [ ] Font fallback: Latin + Arabic glyphs, large-text scaling, no clipped sheets at 200% text.
- [ ] RTL: layout mirroring, number formatting per locale, icon + meter direction, TalkBack/VoiceOver focus order both locales.
- [ ] Pseudo-loc + expansion test before translation (German later expands ~30% — reserve space now).
- [ ] QA: language switch mid-game + mid-sheet + mid-placement without losing selection/camera/save. Arabic full FTUE run.

## Best practices
- Never use display strings as save keys or logic branches.
- Plural rules + units per locale (CLDR). Dates/numbers via locale formatters, not concatenation.
- Store listings + screenshots in en + ar for v1 launch.

## Accept
- [ ] Key list frozen, en/ar translators assigned, es/de explicitly deferred with stubs
- [ ] RTL + font + a11y evidence attached in Epic 6 for both orientations
