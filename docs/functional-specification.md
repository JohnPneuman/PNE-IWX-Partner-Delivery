# Functional specification — PNE Product Configurator Enhancements

## Why this extension exists

Insight Works Product Configurator supports configurable choices and standard
Production BOM cost calculation, but Pneuman needs four additions in its
configuration process: choose a BOM through Additional Choices, include the
Non-Inventory part of that BOM's cost, price the resulting choice from a Blue
Ace margin group, and produce meaningful identifiers and quotation text from
selected configuration values.

The extension keeps each responsibility with its existing owner wherever
possible: IWX owns its configuration lifecycle and inventory costing, Business
Central owns BOM quantities and extended-text records, and Blue Ace owns Item
Profit Groups. This limits the impact of the customization and makes upgrades
reviewable.

## Functional overview

| Feature | User-visible result | Reason for the customization |
|---|---|---|
| Production BOM Additional Choices | The user selects a Production BOM from the standard list for a configured option. | IWX Additional Choices needs a dedicated BOM selection path. |
| Missing Non-Inventory cost | The IWX choice cost includes Non-Inventory BOM components, including nested components. | Standard IWX cost remains the source for inventory components; only the missing cost is added. |
| Item Profit Group pricing | Option choices and current configuration lines can derive Unit Price from a Blue Ace Profit %. | Pricing follows Pneuman's margin-group policy without editing the Item master. |
| Smart Item Number Option Text | A configured number segment can consist of the text selected for an option. | Selected descriptive values can become part of the generated identifier. |
| Configured Sales Line extended text | Quotation Sales Lines show ordered, quantity-prefixed Dutch Item text across a nested configuration. | The quotation must describe the actual selected structure, not merely separate unqualified Item texts. |

## 1. Production BOM as an Additional Choice

When **Production BOMs** is selected as the IWX Additional Choices Type, the
extension tells IWX to use `Production BOM Header` as the filter source and
opens the standard Production BOM List. The regular IWX Additional Choices
Filter is honoured unchanged, so implementation consultants can restrict the
selection with the familiar IWX configuration.

After selection, the app finds the IWX Option Choice for the item category,
configuration option, and BOM number. It reuses a matching Production BOM
choice and refreshes its cost; otherwise it creates a permanent choice by
validating the normal IWX Type and No. fields. Therefore IWX continues to fill
and validate its own code, description, and base cost fields.

The selection is immediately copied to the active configurator line. This is a
deliberate current-session workaround: validating Choice Code at that point can
fail because IWX built the lookup before the dynamic choice was inserted. The
choice remains permanent and is selectable again when the configuration is
reopened.

## 2. Production BOM cost

After IWX has calculated the Unit Cost of a Production BOM Option Choice, the
extension adds the cost of Item components that are explicitly typed
Non-Inventory. It never recalculates or adds the standard inventory component
cost, which prevents double counting.

The added cost uses the certified BOM version effective on `WorkDate`; where no
active version exists, it uses only a certified header. It honours line start
and end dates, Business Central's calculated line quantity, unit-of-measure
conversion, and scrap (except for Fixed Quantity, where Business Central does
not apply scrap). Nested Production BOMs are traversed recursively and their
quantities are multiplied into the parent quantity.

A custom active-path check stops a circular nested BOM reference with an error.
Circular BOM master data remains prohibited: standard IWX costing happens
earlier and can encounter the circular reference before this check executes.

## 3. Profit-group price calculation

The extension adds `Item Profit Group Code PNE` to two IWX records:

- **IWX Option Choice**: the permanent default or override; and
- **IWX Configurator BOM**: an override for the current configuration session.

For Item choices without a permanent override, the effective group comes from
the Blue Ace Item's `Item Profit Group Code PTE`. For Production BOM choices,
the permanent IWX Option Choice is the place to set the group. Editing the
current session's group only changes that active configuration line; it never
writes back to the Item or permanent choice.

If a nonblank group is effective, Unit Price is calculated as:

`Round(Unit Cost / (1 - Profit % / 100))`

The rounding precision is read from General Ledger Setup. A group at or above
100% causes a clear error. If no group is selected, the app defers entirely to
standard IWX pricing. The IWX **Update Unit Price** policy stays authoritative:
`When Used` refreshes after final Unit Cost is known; `Manually` preserves a
subsequent manual Unit Price change.

## 4. Smart Item Number Option Text

The extension adds one explicit Smart Item Number type: **Option Text**. IWX
passes the temporary configuration buffer to the extension; it returns the
Option Text of the first matching selected Option Code. A blank Option Code,
missing selected line, or blank text returns a blank component.

All other IWX Smart Item Number types are untouched. IWX remains responsible
for segment order, final number formatting, length, permitted characters,
uniqueness, and Item creation.

## 5. Configured Sales Line extended text

During standard Business Central extended-text insertion, the extension checks
whether the linked IWX configuration tree contains an Item choice marked
**Include Item Extended Text**. If it does, output is rebuilt in configuration
display order.

For each such Item, valid Dutch Extended Text lines are emitted with an
accumulated quantity prefix, for example `6x Kabelset`. Child configuration
quantities are multiplied by parent quantities. Standard IWX template text for
other modes is retained and interleaved at the same display position, so the
existing IWX formula context remains available.

Only Item Extended Text Headers that are valid on the work date, enabled for
Sales Quote, and marked `NLD` or All Language Codes are included. Empty text
is skipped, long text is wrapped without truncation, stored IWX configuration
and Extended Text master data are not changed, and repeated/circular child
configuration references result in controlled behavior rather than duplicate
text.

## 6. Configured Item Template default

An IWX Item Category can refer to a standard Business Central Data Template.
When the Item Disc. Group line in that template has a Default Value in the
exact form `{<Option Code>}`, the app resolves the selected Choice Code from
the top-level configuration before standard Config. Template validation. For
example, `{I_FA}` sets Item Disc. Group to the selected `I_FA` Choice Code.

A blank or missing choice explicitly clears Item Disc. Group. Literal values
and all other Config. Template fields remain under standard IWX and Business
Central processing. The app neither changes the template nor handles an IWX
Business Rule event; it validates Item Disc. Group through the standard Config.
Template extension point and relies on the surrounding transaction to roll back
an invalid code.

## Boundaries and upgrade impact

The app contains event subscribers, table/page extensions, enum extensions,
and management codeunits in its own ID range 50100–50116. It adds no new
tables, changes no existing IDs or types, calls no Blue Ace internal helper,
and does not take ownership of IWX's core lifecycle.

An IWX or Blue Ace upgrade must be assessed against the public dependencies in
[dependencies.md](dependencies.md), then compiled and accepted in Sandbox. In
particular, validate IWX events and temporary/`var` semantics, Type/No.
validation behavior, cost events, and the Blue Ace Item Profit Group symbols.
