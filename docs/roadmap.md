# Roadmap

## Option Choice Item Profit Groups

Status: implemented, pending complete Sandbox regression and release
validation. The app adds an optional permanent Option Choice override and an
effective configurator-line override while leaving Item data unchanged.
Remaining validation covers session persistence, permissions, actual group
percentages, and upgrade compatibility.

## Per-choice Unit Price

Status: implemented, pending complete Sandbox regression and release
validation. The calculation uses Blue Ace Profit % with Business Central's
`Price=Cost+Profit` formula and unit-amount rounding and honors IWX `Manually`
and `When Used` update behavior. Future work may still need explicit currency,
discount, and sales-price-list rules beyond this cost-plus-profit calculation.

## Smart Item Number using Option Text

Status: implemented on the current feature branch, pending complete Sandbox
regression and release validation.

The app adds the explicit `Option Text` component type and resolves its value
from the selected temporary configurator buffer line matching the configured
Option Code. Existing component types remain with IWX. IWX also retains
ownership of sequence composition, normalization, length, uniqueness, and Item
creation. The exact current behavior and dependency event are documented in
`current-behavior.md` and `dependencies.md`.

Remaining work is to execute and record every Smart Item Number case in
`test-plan.md`, especially changed selections, repeated Option Codes, final
length/character validation, collision handling, close/reopen stability, and
compatibility with the supported IWX version.

## Extended Text from Nested Configurations

Status: implemented on the current feature branch for configured Sales Line
extended-text insertion, pending complete Sandbox regression and release
validation.

The implementation combines standard IWX template output and quantity-prefixed
Dutch Item extended text in Option display order, traverses nested
configurations, accumulates quantities, prevents recursive duplicates, wraps
text, retains separators between nonempty groups, and rejects circular child
references. Its exact Sales Quote, language, WorkDate, and empty-text scope is
documented in `current-behavior.md`; `test-plan.md` is the release checklist.

Possible later enhancements are other sales document applicability flags,
language selection from document context, configurable quantity formatting,
explicit user opt-out, and separately proven unit-of-measure presentation.
These are not part of the current behavior.

## IWX Rule Engine integration

Determine the actual public IWX events, rule tables, formula context, and
supported configurator field access. Do not invent event or object names.

Open questions include rule ownership by Item/BOM/choice, nested BOM membership,
execution order, deduplication, recalculation, removed choices, error handling,
and rule lifecycle when the active configuration changes.

Tests must cover selected and unselected links, nested use, duplicate paths,
choice removal/replacement, recalculation order, and formulas reading current
input and calculated fields.

## Conditional Item and BOM rules

Rules should run only when the linked Item or Production BOM is actually present
in the active configuration. The design must define identity, nested traversal,
and execution context before implementation.

## Shared adapter considerations

Keep app-local adapters until at least two real apps require the same compiled
IWX integration. A shared app introduces dependency and release coupling and is
not justified by a hypothetical future consumer.

## Automated AL tests

Start with deterministic Production BOM costing tests once test dependencies,
test execution, and object ID allocation are available. See `test-plan.md`.

## CI/CD

Future pull-request automation should compile with CodeCop, UICop, and
PerTenantExtensionCop, compare diagnostics with the baseline, and run AL tests.
No workflow will be added until compiler and dependency acquisition are
portable and verified.
