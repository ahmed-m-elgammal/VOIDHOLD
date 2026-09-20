# EPIC 7 — Performance + Platform API 36 + iOS (Ship-blocker gate)

Goal: 30fps low / 60fps high where promised, clean AAB + IPA, interrupt-proof, privacy-ready, and visually faithful to the approved slice. Blocks beta/launch.
Team: Tech Lead + QA/build. Artist supports LOD/cuts.

## T7.1 Perf budget enforcement
- Profiler on Galaxy A14 variants, Pixel 8 + API 36/16KB emulator, iPhone 11, iPhone 15/iPad, and at least one representative low-end GPU family. Logs: frame-time p50/p95/p99, tris, calls, RAM/VRAM where available, thermal 20min, battery drain, startup, package size, and save duration. LOD/shadow tiers, particle halves on Low, texture fallback audit, MultiMesh for farmarea/mineshaft, HLOD + VisibilityRange.
- Budgets: <180k tris, <90 calls, <180MB in view, placement query <8ms, save <300ms, and no sustained thermal throttle beyond the agreed allowance.
- Accept: perf sheet per device + video, no sustained throttling crash.

## T7.2 Android targetSdk 36
- `minSdk 24, targetSdk current Play requirement or higher (36 at this plan date), Gradle/JDK/SDK versions pinned by the export spike, NDK r28+`, arm64 plus any deliberately supported legacy ABI, AAB + asset-delivery decision, adaptive icons, splash <12s, permissions INTERNET/VIBRATE/POST_NOTIFICATIONS only if justified.
- 16KB compatibility check on AAB plus every native `.so` and transitive prebuilt library, not only `.aar` files. Edge-to-edge + gesture + cutout in both orientations, large-screen resizing, split-screen, and foldables. Predictive back hierarchy. Play Internal track.
- Accept: `aab` installs on API 36 emulator + physical, alignment pass log, back/interrupt matrix green.

## T7.3 iOS
- Xcode/SDK version accepted at submission time, iOS 15.0 min only if the selected renderer and plugins support it, Metal/MoltenVK decision recorded, Team/BundleID, launch storyboard, safe-area, TestFlight build, background audio off, restore button placeholder, and privacy-manifest review.
- ATT is conditional on actual tracking/advertising-ID use; it is not a default prompt for an offline, non-tracking build.
- Accept: TestFlight installs on min + high device, ATT flow logged.

## T7.4 Interrupt + storage matrix
- Call, lock, airplane, low battery, storage full, rotation mid-save, kill during save (quarantine recovery), locale + font-scale sweep.
- App update migration, reinstall/OS restore, clock changes, memory pressure, denied notifications, audio interruption/Bluetooth route, TalkBack/VoiceOver, split-screen, and fold/unfold.
- Accept: zero save loss, zero corrupt promotion, matrix signed by QA.

## Epic exit
Signed perf + platform/privacy gate. No known crashers, ANRs, save-loss paths, or renderer-specific blockers; budgets met; both stores have test builds.
