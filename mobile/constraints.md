# Mobile Constraints Baseline (Epic 0 decision)

## Touch + layout
- Targets >=48dp, sheets draggable, destructive 2-tap, back = sheet -> deselect -> pause.
- Both orientations day 1 + dynamic windows (fold/split/iPad multitasking) without losing selection/camera/sheet.
- Safe-area + notch + gesture nav + edge-to-edge (API 36 enforced). No HUD under bars.

## Interruption (must survive, no save loss)
Call, lock, airplane, low battery, storage full, kill-during-write (quarantine + recover), rotation mid-save, clock change, reinstall/restore, denied notifications, audio route change.

## Perf / battery
- 1 dir light only, ortho gameplay cam, pooled particles, LOD + HLOD, ASTC + fallback.
- Autosave 30s + focus-out, atomic tmp+rename, offline `last_seen_utc` capped 4h.
- Permissions minimal: INTERNET/VIBRATE/POST_NOTIFICATIONS only if justified. Inexact alarms. ATT only if tracking.

## Accessibility + localization
- TalkBack/VoiceOver semantics, font scaling, reduced motion/haptics, high contrast, color-blind labels+icons, RTL, pseudo-loc before hard-coded strings.

## Accept
- [ ] Constraints signed by engineer + UX + QA
- [ ] Handoff to T0.4 spike, T0.5 wireframes, T0.6 save schema noted
