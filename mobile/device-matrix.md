# Mobile Device Matrix (Epic 0 decision)

## Coverage (exact, reproducible)
- Low Android (required physical): Galaxy A14 SM-A145F/M (Mali-G52 MC2, 4GB, 720p) — Low tier. Record exact variant + chipset + GPU + OS build tested. No `class` substitution.
- Mid Android: Pixel 8 (Tensor G3) physical + API 36 emulator (16KB check) — Med tier.
- Min iOS (required physical): iPhone 11 / iOS 15 — Low tier.
- High: iPhone 15 / iPad + flagship Android — High tier.
- Extra: 1 named foldable (model + OS recorded) + 1 tablet split-screen check.

## Numerical pass/fail budgets (slice gate T0.10 + Epic 7)
- Frame-time p95: Low <=33.3ms (>=30fps floor), Mid/High p95 <=20ms (>=50fps floor, 60fps target). No sustained p99 >60ms for 60s.
- RAM in view: <=180MB growth over boot on Low, <=260MB Mid/High. VRAM where available logged, no OOM kill.
- Thermal: 20min soak, skin-temp rise <=8°C over ambient, no sustained throttle below target fps after 10min.
- Battery: 20min drain <=8% Low, <=10% Mid/High (screen 50% brightness reference).
- Startup: cold start to menu <=6s Low, <=4s Mid/High.
- Save: full-dome save <300ms, load <2s Low / <1s Mid/High, zero loss.
- Offline fast-forward 4h worst case: completes <5s Low / <2s Mid/High, no ANR, identical result to live replay fixture.

## Rules
- T0.4 spike must log fps + frame p95 + tris/calls/RAM/thermal per device + video.
- Epic 7 repeats full matrix with thermal 20min + battery + startup + save duration.
- No device removed without producer sign + DoD update.
- Emulator alone never counts as physical evidence for perf gate.

## Accept
- [ ] Matrix + OS versions + owners recorded
- [ ] 16KB alignment pass on API 36 AAB + all .so
- [x] Numerical perf budgets defined (p95/RAM/thermal/battery/startup/save/fast-forward) — device runs still pending for T0.10 gate
