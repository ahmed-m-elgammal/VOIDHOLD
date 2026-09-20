# Orientation + Touch Spec (Epic 0 contract for T0.5)

## Layouts
- Landscape: top full HUD, bottom BuildBar 3 tabs, right inspector.
- Portrait: top compact HUD, bottom drawer BuildBar collapsible, full-screen sheets.
- Dynamic: fold/unfold, split-screen, iPad multitasking keep state. No h-scroll, no clipped critical action.

## Gestures
Tap select, long-press info, drag pan with inertia, pinch zoom ortho 24-90, rotate-button 90° snap (replaces R), double-tap focus. Pinch stays live during placement.

## Placement UX
Ghost green/red + reason toast (no-resource vs bad-tile vs missing-link), entrance arrow, radius ring, rotate preserves center. Error haptic heavy, select light, place medium.

## FTUE + warnings
7 steps <5min, skippable, teaches failure (energy/output/starving/attack). Toasts max 3, never cover placement. Every sim warning has HUD + sound + haptic + color-blind icon.

## Accept
- [ ] 12 screens x2 orientations + window-size variants in Figma
- [ ] Gesture + haptic map approved by engineer
- [ ] Strings + warning events list handed to T0.6
