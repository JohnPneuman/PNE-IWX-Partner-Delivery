# Release candidate manifest — 2026-08-23

Status: **source-complete and locally validated; not yet production-approved**.

| App to deploy | Version | Local package | SHA-256 |
|---|---:|---|---|
| PNE Production Order Reconciliation | 2.7.0.10 | `PNE.ProductionOrderReconciliation/.build/PNE-Production-Order-Reconciliation-2.7.0.10.app` | `ED297D19DCB8A802EE54D18904BD4D0703F6FB3D3715FAD1AAA8327D556C9979` |

PNE Frame Specification 1.0.0.8 and PNE Product Configurator Enhancements
1.0.0.8 were recompiled only as validation dependencies and contain no source
change in this release. **Do not redeploy their newly generated local binaries
under the unchanged version number.** Keep the already approved/installed
1.0.0.8 packages. The package above is intentionally ignored by Git; copy only
that exact Reconciliation package to the controlled release folder.

## Local validation evidence

- AL Language extension 17.0.2273547;
- AL compiler 17.0.34.45391;
- Business Central application symbols 28.3.52162.52579;
- CodeCop, UICop and PerTenantExtensionCop with warnings as errors;
- Frame Specification: 16 AL files, 0 errors, 0 warnings, 0 info;
- Product Configurator Enhancements: 19 AL files, 0/0/0;
- Production Order Reconciliation: 36 AL files, 0/0/0;
- environment setup check: 0 failures, 0 warnings.

## Remaining release gates

The reported target environment is Business Central 28.4.53241.53504, while
the retained local Base Application symbols are 28.3. Re-download the exact
target Sandbox symbols, rebuild all three apps for validation and repeat the
clean checks before production. Recompute the Reconciliation hash if its package
bytes change; do not ship rebuilt unchanged-version dependency packages.

Execute and retain the dated Sandbox evidence in:

- `docs/test-plan.md`;
- `docs/frame-specification-test-plan.md`; and
- `docs/production-order-reconciliation-test-plan.md`.

The acceptance run must include the real AutoCAD PIL, repeated zero-delta
import, point-carrier lookup, SKU-specific BOM, routing-hour before/after proof,
net morework/lesswork quote handoff and reversal, role separation, Word report
output and representative performance timings. No automated AL test codeunits
exist yet, so these manual results are a mandatory gate.
