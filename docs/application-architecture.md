# Application architecture

## Current behavior flow

```text
IWX Additional Choices event
  -> PNE IWX Event Subscribers
  -> PNE IWX Add. Choices Mgt.
  -> PNE IWX Adapter
  -> permanent IWX Option Choice
  -> direct field copy to the active IWX Configurator BOM line

IWX Option Choice Unit Cost event
  -> PNE IWX Event Subscribers
  -> PNE Production BOM Cost Mgt.
  -> Production BOM Header and active Version
  -> Production BOM Lines
  -> recursive missing Non-Inventory cost
  -> add result to the Unit Cost already calculated by IWX
  -> PNE IWX Pricing Mgt.
  -> refresh Unit Price when configured as When Used

IWX Option Choice Unit Price event
  -> PNE IWX Event Subscribers
  -> PNE IWX Pricing Mgt.
  -> Blue Ace Item Profit Group
  -> calculate Unit Price from final Unit Cost and Profit %

IWX Choice Code validation or direct Additional Choice mapping
  -> PNE IWX Pricing Mgt.
  -> resolve Option Choice override or Item default
  -> copy effective profit group to the active configurator line

IWX Smart Item Number sequence-value event
  -> PNE IWX Event Subscribers
  -> PNE Smart Item No. Mgt.
  -> match the configured Option Code in the temporary configurator BOM buffer
  -> return the selected Option Text for the explicit Option Text type

Business Central sales extended-text insertion
  -> PNE IWX Event Subscribers
  -> PNE IWX Extended Text Mgt.
  -> retrieve the IWX configuration linked to the Sales Line
  -> recursively follow Choice Configuration ID
  -> build Dutch Item extended text with accumulated quantities

IWX configured-Item completion or explicit Item Card repair
  -> PNE IWX Routing Complete Mgt.
  -> read Item Category Choices Routing
  -> add only missing optional base-routing operations with zero time
  -> never run implicitly during production-order refresh
```

## Responsibility boundaries

- **PNE IWX Event Subscribers** keeps object ID 50101 and contains only
  subscriber entry points, eligibility checks, and delegation.
- **PNE IWX Add. Choices Mgt.** uses object ID 50102 and coordinates option
  lookup, filters, Production BOM List selection, and the selected result.
- **PNE IWX Adapter** uses object ID 50103 and owns direct creation/retrieval of
  IWX Option Choices and direct IWX field mapping, including the current-session
  workaround.
- **PNE Production BOM Cost Mgt.** uses object ID 50104 and owns active version
  selection, date filters, Non-Inventory costing, UOM conversion, scrap,
  recursion, and cycle detection.
- **PNE IWX Pricing Mgt.** uses object ID 50110 and owns profit-group
  resolution, rounding, Unit Price calculation, and per-session price updates.
- **PNE IWX Extended Text Mgt.** uses object ID 50115 and owns configured
  Sales Line text generation, nested traversal, quantity accumulation, and
  Dutch Item extended-text selection.
- **PNE IWX Item Template Mgt.** uses object ID 50116 and owns the opt-in
  Config. Template placeholder mapping from a selected IWX Choice Code to the
  Item's Item Disc. Group immediately before standard Config. Template
  validation.
- **PNE IWX Smart Item No. Type** uses object ID 50113 and adds only the
  explicit `Option Text` sequence component.
- **PNE Smart Item No. Mgt.** uses object ID 50114 and resolves that component
  from the temporary IWX configurator buffer without taking ownership of the
  surrounding IWX number-composition lifecycle.
- **PNE IWX Routing Complete Mgt.** uses object ID 50117 and owns the narrow
  missing-operation comparison and zero-time insertion after configured-Item
  creation/reconfiguration or the explicit authorized Item Card repair. It is
  not a production-order refresh subscriber.
- Table extensions 50105-50106 and page extensions 50107-50109 and 50111 add
  the persistent Option Choice default and configurable session override
  without writing back to Item. Permission set extension 50112 grants pricing
  codeunit execution through the existing IWX PC User role.

The extraction preserves the existing event signatures, IWX validation and
trigger behavior, direct current-session field assignments, inventory-cost
ownership, recursive costing, and the custom traversal's active-path cycle
guard. IWX performs its standard costing before the post-cost subscriber, so
circular Production BOM master data remains unsupported. Profit-group pricing
runs only when a group is selected; blank values preserve standard IWX pricing.
Rule Engine behavior remains a future dedicated module.

## Production Order Configuration Structure flow

```text
Simulated, Firm Planned, or Released Production Order
  -> BOM-stamstructuur action
  -> PNE PO Config. Structure Mgt.
       -> stored Prod. Order Line root Production BOM and version when present
       -> read-only nested Production BOM traversal and child-BOM headings
       -> certified date-effective child BOM versions (start, due, then WorkDate)
       -> circular/depth/20,000-row display guard
  -> temporary standard Production BOM Line rows
  -> read-only PNE PO Configuration Structure page
```

This is a display-only path. The management codeunit creates temporary rows
only for the page session, so it does not share persistent tables, transaction
boundaries, audit records or Apply behavior with the PIL flow. It uses no IWX
symbol, event or record and does not alter the existing IWX Configurator BOM
or Business Rules. The dedicated **PNE PO Struct View** permission
set grants only the page/codeunit and read access to the standard production
order and Production BOM source data; users still need their normal Business
Central access to open the host production-order page.

## Production Order Reconciliation flow

```text
Simulated, Firm Planned, or Released Production Order
  -> PNE PIL Import (headerless single-quoted AutoCAD rows)
  -> PNE PIL Header + raw rows + aggregated item lines
  -> PNE PIL Mgt.
       -> live linked production-order structure
       -> read-only, version-aware Production BOM fallback
       -> highest structural driver; otherwise direct CALC route
  -> PNE PIL Targets / optional manual allocation
       -> highest whole minimum for drivers on one carrier; explicit allocation only across independent carriers
  -> PNE PIL Change Lines (technical/commercial snapshot per carrier)
       -> read-only Change Proposal report
       -> optional grouped net morework/lesswork append to selected existing Sales Quote
  -> explicit Apply action
  -> standard Prod. Order Line and Component validations and triggers
  -> before/after Qty.-per-Top-Item-equivalent hour delta on one unambiguous end-item routing
```

Only `PNE PIL Group` and `PNE PIL Group Item` are maintained by an
administrator. A group links real AutoCAD Inventory-items to one existing
Non-Inventory CALC placeholder. There are no reconciliation profiles,
productiedoelen, position codes, fixed-assembly recipes, or Siemens-specific
rules.

The management codeunit owns structural analysis, coverage, ambiguity checks,
allocation, carrier scaling and the single-transaction apply. The import
codeunit owns only the four-field AutoCAD contract and raw/aggregate audit. A
carrier is every pointartikel (`.PN...`, `.EA...`, `.PH...`, `.TO...`, and
other `.` prefixes) plus a `G.` item only when it is an Inventory item with
replenishment system Prod. Order and a certified Production BOM. Pure G.
hours/material groups are not candidates; a pointcarrier has priority over an
eligible G. carrier in the same linked branch. A
structural driver is the highest imported item with a lower linked production
order or Production BOM structure; `7.*` is not a special case. Within the
same carrier, that driver wins even if a CALC component is also present. Its
imported descendants are marked covered and never added a second time. Only
loose grouped PIL-items without such a driver in their own carrier take the
CALC route, so independent direct-placeholder carriers remain replaceable. If
the same aggregated AutoCAD item could be both structural and loose on two
independent carriers, the management codeunit blocks Prepare because the PIL
does not provide enough parent context for a safe split.

The Production BOM fallback is read-only. At a root production-order line it
uses the stored Production BOM Version Code where present; other fallback
levels require the safe certified/date-valid selection. Routing links, scrap,
Calculation Formula and any UOM conversion or mismatch block the fallback
rather than being estimated. Each target records whether the analysis source
was the live production order or the read-only master-BOM fallback. The app
has no IWX dependency or adapter boundary because it does not access IWX.

The management codeunit also separates material placement from routing
ownership. A unique routed production-order source/end-item line owns the
live Routing Link calculation. Eligible Non-Inventory hour components are
totaled across all live lines in that order and that complete current total is
written once to the owner. A nested routed line is not selected just because
it received a point article. Zero-time optional operations stay disabled. This
Pneuman-owned live-order calculation neither invokes nor reimplements IWX
Business Rules and does not call or mutate Bluace Item Routing master data.

The proposal table is an app-owned technical/commercial audit snapshot, not a
sales-document editor. A user may select only an existing Open, unaccepted and
non-expired Sales Quote. The quote codeunit groups technical carrier changes
by Item, Variant and UOM and appends one standard Item line for each non-zero
original-to-final net delta; a negative quantity is lesswork and net zero
creates no Sales Line. It never changes an existing quote or configurator
line. Standard Sales Line validation calculates the price.

After inserting a net Item line, the same codeunit reads only standard
Business Central Extended Text when the Item has Automatic Ext. Texts enabled
and the text is enabled for Sales Quote and valid for
the quote document date and language. It creates attached blank Sales Lines,
prefixes each non-empty source text line with the net quantity or `Minderwerk`,
and word-wraps
without truncation. These attached lines are part of commercial report and
standard-reversal integrity. Technical Apply verifies the immutable Item-line
snapshot but deliberately does not depend on later mutable text master data.
The code does not invoke the IWX configured-text builder,
does not open a configuration and does not call an IWX formula or Business
Rule. The user must separately have normal
Business Central Sales Quote/Sales Line read-and-create rights: **PNE PIL
Reconcile** intentionally grants no Sales Header, Sales Line or sales-page
rights. Codeunit 50197 has indirect read permission only for Item and Extended
Text master data; it does not grant Sales Header/Line access. Before handoff, a manual **Naar deze carrier** change from *Gereed om
toe te passen* immediately returns the dossier to *Verdeling nodig*; **Stap 2
- Controleer verdeling** must rebuild the proposal first. Once a proposal has a quote
link, the technical allocation/reprepare path is locked. Apply-first and
handoff-second is the recommended workflow; pre-Apply handoff requires an
explicit warning confirmation. The report detects a
changed or deleted linked quote Item or attached text line live and asks for
commercial review instead of repairing it. If the user can no longer read the
linked Sales Line,
the technical report remains usable and reports that the quote link cannot be
verified with the current permissions; it is also commercial review, not a
report failure or a repair attempt.
