# Insight Works Business Rules compatibility

## Purpose

This document records the compatibility boundary between Pneuman's extensions
and Insight Works Product Configurator Business Rules. The extensions must not
alter, delete, suppress, or reimplement the IWX Business Rule lifecycle.

## PNE Product Configurator Enhancements

The app uses public Product Configurator events and documented public tables.
It does not read, create, modify, or delete IWX Business Rule records.

The app preserves IWX ownership of Option Choice validation, inventory cost,
standard Smart Item Number composition, and standard pricing when no custom
profit group is selected. Its event subscribers do not handle or bypass any
Business Rule event.

The adapter writes validated Option Choice values to the active temporary IWX
Configurator BOM buffer only to make a newly created Additional Choice visible
in the already-open session. This documented current-session workaround does
not write a Business Rule record and does not cause a new Rule Engine
evaluation. It must remain limited to that session-mapping scenario.

Custom Smart Item Number, pricing, and extended-text handling use their
specific public IWX extension points. Their `IsHandled` behavior is scoped to
those extension points; it does not suppress IWX Business Rules.

The optional Item Disc. Group placeholder mapping starts only from the public
IWX pre-Item-creation event. It reads the existing IWX Data Template reference
and uses the standard Config. Template validation event to validate the
resolved value, but never changes the IWX or Config. Template records. Its
`IsHandled` assignment is limited to that standard template-field validation
event; it does not handle a Business Rule event.

The optional-routing completion subscribes only to public IWX events after an
Item has been newly configured or genuinely reconfigured. It reads the
category Choices Routing and adds only missing standard Routing Lines to the
configured Item base routing with zero time. Existing operations and times are
not changed. Normal production-order calculation or refresh does not invoke
this shared-master-data repair. An authorized Item user can run the explicit
**Optionele routing herstellen** action for one older Item; that action reads
its single stored IWX configuration read-only. No IWX record, Business Rule,
temporary Configurator BOM or `IsHandled` value is written by this feature,
and no Business Rule evaluation is initiated or bypassed.

## PNE Frame Specification

The app has no event subscribers. It reads `IWX Configurator BOM v3` records
to find a configuration and copies them only into temporary records for
calculation. It does not write to Product Configurator records or to IWX
Business Rule definitions.

Table 50151 `PNE Frame Spec. Rule` contains Pneuman-owned configuration for
the frame-specification report. These are report-calculation rules, not Insight
Works Business Rules. Table 50152 `PNE Frame Spec. Line` is used as the type
for temporary calculated report and preview lines; the current report flow does
not persist those lines.

## PNE Production Order Reconciliation

This app has no Insight Works dependency. It does not read or write an IWX
table, subscribe to an IWX event, set an IWX `IsHandled`, invoke the IWX Rule
Engine, or create/modify/delete an IWX Business Rule. It has no IWX event
subscriber and does not need an IWX adapter boundary; it only uses standard
production-order, Production BOM, Item and Sales Quote APIs for the PIL
workflow. Its positive-change quote lines obtain their price through standard
Business Central Sales Line validation, never through an IWX formula or Rule
Engine call.

The separate **BOM-stamstructuur** view follows the same boundary. It
reads only the existing standard Production Order, Prod. Order Line, Item and
Production BOM records, creates temporary Production BOM Line rows for its
page session, and uses no IWX symbol or record. Permission set 50198 **PNE
productiestructuur bekijken** (`PNE PO Struct View`) grants no IWX, PIL or
production-order write permission.

Sandbox acceptance must still run representative existing IWX Business Rules
and Quoting Item conversion before and after installation. The expected result
is identical IWX data and behavior; the new app should only add its production
order actions, app-owned audit data, and controlled CALC reconciliation.

## Upgrade and review checks

Before an IWX upgrade or a new feature, confirm that public event signatures
and IWX table semantics remain compatible. Review every new write to an IWX
record and every new `IsHandled := true` assignment to ensure it is not tied to
a Business Rule lifecycle event. Do not add a dependency on internal IWX Rule
Engine objects without written Insight Works approval.

## Engineering enforcement

The repository instructions in `AGENTS.md` make this boundary mandatory for
all development work. They require an explicit impact assessment before an IWX
write, event subscriber, or `IsHandled` assignment is added, and require work
to stop for clarification if its effect on Business Rule evaluation is unclear.
