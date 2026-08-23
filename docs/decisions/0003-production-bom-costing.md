# ADR 0003: Add only missing Production BOM cost

- Status: Accepted
- Date: 2026-07-23

## Context

IWX calculates normal Production BOM inventory cost, but standalone Production
BOM Option Choices omit Non-Inventory Item cost.

## Decision

Preserve the Unit Cost calculated by IWX and add only recursively calculated
Non-Inventory component cost after IWX updates the choice. Use active certified
versions, valid dates, Business Central line Quantity, UOM conversion, Scrap %,
nested BOM traversal, and an active-path cycle guard within the custom
calculation.

## Consequences

Inventory cost is not double-counted, while Non-Inventory-only and mixed BOMs
receive complete cost. The calculation applies to manually created and
Additional Choices Production BOM options. Changes require focused cost
regression tests and must not alter Unit Price.

IWX performs its standard Production BOM costing before this post-cost
calculation. Circular Production BOM master data is therefore unsupported:
IWX may recurse before the custom guard is reached.
