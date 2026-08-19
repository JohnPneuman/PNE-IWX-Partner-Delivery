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

## Upgrade and review checks

Before an IWX upgrade or a new feature, confirm that public event signatures
and IWX table semantics remain compatible. Review every new write to an IWX
record and every new `IsHandled := true` assignment to ensure it is not tied to
a Business Rule lifecycle event. Do not add a dependency on internal IWX Rule
Engine objects without written Insight Works approval.
