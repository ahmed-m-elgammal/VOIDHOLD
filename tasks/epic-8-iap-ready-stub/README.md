# EPIC 8 — IAP-Ready Stub (RevenueCat deferred, no SDK in v1)

Goal: ship the sim without store lock-in, while keeping entitlements, analytics, consent, and privacy replaceable. Parallel after the data/privacy contract; required before beta telemetry.
Team: Tech Lead + Producer (plan doc).

## T8.1 EntitlementManager stub
- Interface only: `has(entitlement)->bool, purchase_requested(id)->ComingSoon, grant_mock(id) debug-only`. All gameplay checks via manager. Save reserves `entitlements:{}`. Shop UI `ShopStub.tscn` Locked state, no price fetch, no .aar.
- Best: no store permissions added yet, no hard-coded prices, feature flags for boost/skin/moon/skip (all OFF).
- Accept: grep shows zero direct billing calls, save schema includes entitlements, shop opens Locked safely offline.

## T8.2 Analytics abstraction (vendor-neutral)
- Events: `ftue_step, warning_shown, placement_failed_reason, session_len, retention D1/D7 hooks, performance tier, save_error, migration_result, crash_context`.
- Define consent state, opt-out behavior, data minimization, retention, deletion, regional policy, offline queue limits, and whether beta metrics use a real provider or local export.
- No PII, no device fingerprinting, and no tracking behavior hidden behind a vendor-neutral interface.
- Accept: event list + payload specs approved, privacy/data map approved, consent denial tested, and the beta measurement method is operational before recruiting users.

## T8.4 Privacy + telemetry release contract
- Owner: Producer + engineer. Reviewer: legal/QA.
- [ ] App privacy details, Android Data Safety, iOS privacy manifest, privacy policy, support URL, consent copy, retention/deletion behavior, and third-party SDK manifests are consistent.
- [ ] ATT is included only if the final build tracks users or accesses advertising identifiers.
- [ ] Crash/ANR reporting, symbolication, save-loss diagnostics, and opt-out behavior are verified on both platforms.
- Accept: privacy review signed and beta dashboards can distinguish crash, ANR, save error, migration failure, and normal session data without collecting unnecessary personal data.

## T8.3 RevenueCat integration plan (doc only)
- Later steps documented: Play Billing v2 + StoreKit2 + RevenueCat REST validation, server entitlements, restore, sandbox matrix (pending/family/refund/renew/cancel), rewarded ads + UMP/ATT, paywall copy drafts (no prices locked).
- Accept: plan doc linked, explicitly marked DEFERRED, no implementation in v1.

## Epic exit
v1 builds with zero store dependencies, future IAP plugs into EntitlementManager without sim changes.
