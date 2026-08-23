# Transfer audit — IWX Business Rules and extension safety

Audit date: 2026-08-23
Scope: all three delivered apps

## Result

The static source audit found no code that creates, changes, deletes,
suppresses, or reimplements Insight Works Product Configurator Business Rules.
The documented IWX compatibility boundary is followed by all three apps.

This is a source and symbol audit, not a replacement for Blu Ace's Sandbox
acceptance. The required regression scenarios remain in `test-plan.md` and
`frame-specification-test-plan.md`.

## Business Rules boundary

- No subscriber targets an IWX Business Rule, Rule Engine, Rule Builder, rule
  definition, or rule-action event.
- No code reads, inserts, modifies, or deletes an IWX Business Rule record.
- All IWX integration events in Product Configurator Enhancements were checked
  against dependency symbols. The Item Disc. Group placeholder starts from the
  public IWX pre-Item-creation event and handles only the standard Business
  Central Config. Template field-validation event.
- Frame Specification has no event subscribers. It reads Configurator BOM data
  into temporary calculation buffers and does not write IWX configuration data.
- Production Order Reconciliation has no IWX or Bluace dependency and does not
  read or write Product Configurator data.

## IWX data writes and `IsHandled` review

| Area | Operation | Boundary conclusion |
|---|---|---|
| Production BOM Additional Choices | Inserts or reuses an IWX Option Choice and copies it to the active temporary BOM buffer | Deliberate public-extension integration; preserves IWX Type/No. validation and is not a Business Rule write. |
| Profit-group pricing | Handles IWX Unit Price update only when a custom profit group is selected | Scoped pricing extension point; blank group leaves standard IWX pricing. |
| Smart Item Number Option Text | Handles only the custom `Option Text` component type | Existing IWX component types and number composition remain under IWX control. |
| Configured Sales Line text | Handles standard Business Central extended-text availability only when configured text exists | Not an IWX Business Rule event; IWX template behavior remains intact. |
| Configured Item Template default | Handles standard Config. Template field validation only for Item Disc. Group placeholders | No IWX or Config. Template record is changed; the selected Choice Code is validated before the new Item is inserted. |
| Frame Specification | Temporary calculated records only | No IWX write and no Business Rule interaction. |

## Transaction and data safety

- No new `Commit()` was introduced.
- The Item Disc. Group placeholder uses the surrounding Item-creation
  transaction. An invalid Choice Code fails validation and rolls back the
  creation; a blank/missing choice validates as blank.
- No table, table-extension, field ID, field type, app ID, or object ID was
  changed for the Item Template correction.
- Generated packages, symbols, launch settings, credentials, and internal
  use-case material are excluded from the partner delivery.

## Build and acceptance status

- All three apps completed the standard repository validation against exact local
  Business Central 28.3 and dependency symbols using AL compiler
  17.0.34.45391.
- CodeCop, UICop, and PerTenantExtensionCop ran with warnings as errors and
  reported 0 errors, 0 warnings, and 0 informational diagnostics for all three
  apps.
- Every object now has its approved Pneuman namespace. The public-symbol and
  Sandbox-upgrade risks are documented in `namespace-compatibility-audit.md`.
- A previous handover note reported the `{I_FA}` Item Disc. Group conversion
  scenario as confirmed in Sandbox, but the repository contains no dated test
  record, environment reference, executor, or result artifact. Treat this
  scenario as unverified until it is rerun and evidence is retained.
- Before a release decision, Blu Ace must execute and retain all applicable
  scenarios in the three test plans, including existing IWX Business Rules,
  frame-report and production-reconciliation regression behavior.
