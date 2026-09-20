# T0.4 Mobile Spike Exit Checklist (Godot 4.7.2)

Spike: 1 dome ring + 1 greybox habitat + 1 drone waypoint + drag/pinch/rotate. Throwaway allowed.

Evidence packet: `mobile/evidence/README.md` and `mobile/evidence/t0.4-device-capture-log.md`.

## Must prove
- [ ] AAB `targetSdk 36` installs on API 36 emulator + physical, 16KB alignment pass log
- [ ] iOS stub installs on min + high (simulator/TestFlight), renderer decision recorded
- [ ] Video landscape + portrait + fps/p95/tris/calls/RAM per device in `device-matrix.md`
- [ ] Edge-to-edge + cutout + gesture + predictive back hierarchy verified
- [ ] Interrupt matrix: call/lock/airplane/storage-full/kill-during-write — no save loss (save stub path `user://`)
- [ ] Low-tier still readable + touch targets >=48dp on 6-inch phone
- [ ] Go/no-go for realistic PBR at full parity, or written scope warning

## Handoff
Promote only config + camera learnings to Epic 1. Keep spike separate if messy.
Gate for T0.10 slice: min-device frame/thermal budget + save reliability + readability.
