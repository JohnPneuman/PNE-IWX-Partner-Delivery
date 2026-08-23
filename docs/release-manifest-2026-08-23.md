# Release candidate manifest — 2026-08-23

Status: **source-complete and locally validated; not yet production-approved**.

| App | Version | Local package | SHA-256 |
|---|---:|---|---|
| PNE Frame Specification | 1.0.0.8 | `PNE.FrameSpecification/.build/PNE-Frame-Specification-1.0.0.8.app` | `B7AD9FA8A4F4696C21CD92D7B1805D3AC38B2FA126AF13525C6FEC8FA33CA852` |
| PNE Product Configurator Enhancements | 1.0.0.8 | `PNE.ProductConfiguratorEnhancements/.build/PNE-Product-Configurator-Enhancements-1.0.0.8.app` | `1CF165D314AB0FBBBF72C76F9FB1A3C1ABBF5034CC82F83B533BFA8B758765A9` |
| PNE Production Order Reconciliation | 2.7.0.9 | `PNE.ProductionOrderReconciliation/.build/PNE-Production-Order-Reconciliation-2.7.0.9.app` | `A3F9957AC8F6D405871672FADB5D56CD1E0E59F1549644876EB141C2362432F7` |

The packages are intentionally ignored by Git and are not included in this
source delivery. The hashes above identify the packages produced during the
partner-delivery validation. Rebuild all three apps from this reviewed source
against the exact target-Sandbox symbols and record new hashes before
installation.

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
target Sandbox symbols, rebuild all three packages and repeat the clean
validation before production. Recompute and replace the hashes if the package
bytes change.

Execute and retain the dated Sandbox evidence in:

- `docs/test-plan.md`;
- `docs/frame-specification-test-plan.md`; and
- `docs/production-order-reconciliation-test-plan.md`.

The acceptance run must include the real AutoCAD PIL, repeated zero-delta
import, point-carrier lookup, SKU-specific BOM, routing-hour before/after proof,
net morework/lesswork quote handoff and reversal, role separation, Word report
output and representative performance timings. No automated AL test codeunits
exist yet, so these manual results are a mandatory gate.
