# PTE release manifest — 2026-08-24

Status: **exact-target compiled and analyzer-clean; ready for Sandbox PTE
installation, not yet production-accepted**.

| App to install | Version | Package | SHA-256 |
|---|---:|---|---|
| PNE Product Configurator Enhancements | 1.0.0.10 | `PNE-Product-Configurator-Enhancements-1.0.0.10.app` | `440DB85C18D50646EDBAF3B7DFB1D8093D0C6031577EB1037CAD549B4FB9CC2E` |
| PNE Frame Specification | 1.0.0.9 | `PNE-Frame-Specification-1.0.0.9.app` | `21CADC76AA2B0C5077F05414361C1DA8D8C742BE9000F62D37F794F76809AC65` |
| PNE Production Order Reconciliation | 2.8.0.1 | `PNE-Production-Order-Reconciliation-2.8.0.1.app` | `E82DD762077A230F2600559FA44D660DC39FE940DBD99A99276F9834AD79D728` |

These are deliberately higher than the latest development versions, so the
PTE installation is a normal upgrade of the same app IDs and preserves the
app-owned data. Never rebuild or replace one of these packages without raising
its version and updating this manifest.

## Exact validation environment

- target tenant: Pneuman Sandbox;
- Microsoft Application: 28.4.53241.53312;
- Microsoft Base Application: 28.4.53241.53758;
- Microsoft System Application and Business Foundation: 28.4.53241.53312;
- Microsoft System: 28.0.53445.0;
- Insight Works Product Configurator: 4.1.9649.1;
- BluAce Pneuman: 1.0.202608.1;
- BluAce Technical Management propagated dependency: 1.0.202607.11;
- AL Language extension: 17.0.2273547;
- AL compiler: 17.0.34.45391;
- CodeCop, UICop and PerTenantExtensionCop with warnings as errors.

The environment setup check completed with 0 failures and 0 warnings. The
three apps compiled from a clean generated-output folder with 0 errors,
0 warnings and 0 informational diagnostics. Evidence is retained in each
app's ignored `.build/validation-diagnostics.json` and copied into the
controlled release folder.

## Installation order and remaining gate

Install or upgrade in this order:

1. PNE Product Configurator Enhancements 1.0.0.10;
2. PNE Frame Specification 1.0.0.9;
3. PNE Production Order Reconciliation 2.8.0.1.

Use the Business Central administration PTE upload/upgrade route. Do not use
VS Code Publish, ForceSync, Delete Extension Data or a lower version. First
install these exact packages in the Sandbox and retain the dated acceptance
evidence from:

- `docs/test-plan.md`;
- `docs/frame-specification-test-plan.md`; and
- `docs/production-order-reconciliation-test-plan.md`.

The acceptance run must include the real AutoCAD PIL, repeated zero-delta
import, point-carrier lookup, SKU-specific BOM, routing-hour before/after proof,
net morework/lesswork quote handoff and reversal, durable commercial-link
resolution, role separation, both Word reports and representative performance
timings. The repository has no automated AL test codeunits, so production
approval remains blocked until this manual Sandbox evidence is complete.
