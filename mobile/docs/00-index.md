# VOIDHOLD mobile/docs — Epic 0 Execution Specs (root)

Game: `VOIDHOLD: Moon Colony` (`com.voidhold.colony`). Engine 4.7.2 + API 36 + iOS 15+. Locales v1 `en+ar`.

## Specs in this folder (mirror — canonical source is tasks/epic-0-preproduction/)
- `00-index.md` (this file) — execution order + gates
- `T0.1-output-decision-draft.md` + `T0.1-rebrand-identity.md` — identity lock
- `T0.2-output-parity-starter.md` + `T0.2-gdd-lock.md` + `T0.8-output-fixture-starter.md` + `T0.8-reference-simulation-and-parity.md` — GDD + parity
- `T0.3-output-audit-starter.md` + `T0.3-license-purge.md` + `T0.7-output-inventory-template.md` + `T0.7-ownership-and-supply-chain-audit.md` — licenses
- `T0.4-runbook.md` + `T0.4-engine-spike-472.md` — spike (throwaway greybox + export proof; only code allowed in Epic 0)
- `T0.5-wireframes-adaptive-ui.md` + `T0.9-output-art-bible-starter.md` + `T0.9-visual-identity-and-art-bible.md` — UI + art + RTL
- `T0.6-data-db-save-schema-design.md` — save v1 + dictionaries + recovery
- `T0.10-output-slice-scope.md` + `T0.10-premium-vertical-slice.md` — one-dome gate, pause bulk on fail
- `device-matrix.md` — numerical perf budgets

## Order
`01 + 04(spike) + 03-audit parallel -> 02 -> 05 + 06 -> 10 -> EXIT`
Epic 0 DoD holds except T0.4 throwaway code explicitly allowed. No production sim/art/UI code until Epic 1/slice.
IAP skipped (Epic 8 stub only).
