# Partner installation guide — PNE Product Configurator Enhancements

## Purpose and scope

This guide is for Blu Ace when assessing, packaging, installing, and accepting
the extension in the Pneuman master. The app is a private per-tenant extension
that augments Insight Works Product Configurator in five narrowly scoped areas:

1. selection of Production BOMs as IWX Additional Choices;
2. addition of missing Non-Inventory cost to an IWX Production BOM choice;
3. price calculation from the Blue Ace Item Profit Group; and
4. Smart Item Number Option Text and configured Sales Line extended text; and
5. Item Disc. Group defaults sourced from a selected configurator Choice Code.

It is not a replacement for IWX configuration, Production BOM maintenance,
Blue Ace price-group maintenance, or Business Central extended-text setup.

## Package identity and dependencies

| Item | Required value |
|---|---|
| App | PNE Product Configurator Enhancements |
| Publisher | Pneuman |
| App ID | `b4514682-8029-4a3d-ad9d-e887cdf51b0f` |
| App version | `1.0.0.4` |
| Business Central application | 28.0 |
| Runtime | 17.0 |
| Insight Works Product Configurator | 4.1.9649.1 |
| Insight Works app ID | `f558b611-3753-4d0b-98ca-6b658a4ed24a` |
| Blue Ace Pneuman | 1.0.202606.5 |
| Blue Ace app ID | `0aeaa135-2753-4f1b-8fc8-2f69b4cd58a8` |

The listed dependency versions are compile-time and runtime prerequisites. Do
not substitute a newer dependency solely because it installs: first compare the
public symbols and event signatures described in
[dependencies.md](dependencies.md), then compile and complete Sandbox
regression tests.

## Installation order and safety

1. Use a Business Central Sandbox that represents the intended master
   configuration. Do not use production for first installation or acceptance.
2. Confirm that Product Configurator 4.1.9649.1 and Blue Ace Pneuman
   1.0.202606.5 are already installed and operational.
3. Import the package whose ID and version match the table above.
4. Install or upgrade the extension using the normal Business Central extension
   administration process. No ForceSync, data deletion, or manual database
   alteration is required or supported by this app.
5. Assign the normal IWX Product Configurator user role. The extension adds
   execute access to its pricing codeunit to the existing `IWX PC User`
   permission set; it deliberately does not grant wider Blue Ace modification
   permissions.
6. Complete the acceptance tests below before any production release decision.

The extension introduces two customer-content fields with ID 50105, both named
`Item Profit Group Code PNE`: one on the permanent IWX Option Choice and one on
the IWX Configurator BOM line. These are additive table-extension fields;
installation does not alter existing field IDs, types, or application data.

## Configuration required after installation

### Production BOM Additional Choices

For each IWX Configurator Option that must allow a Production BOM selection:

1. set **Additional Choices Type** to **Production BOMs**;
2. optionally fill **Additional Choices Filter** with a valid `Production BOM
   Header` table view; and
3. ensure that selectable Production BOMs and their active versions are
   maintained and certified as appropriate.

The option opens the standard **Production BOM List**. A selected BOM becomes
an IWX Option Choice of type `Production BOM`; existing matching choices are
reused rather than duplicated.

### Profit-group price calculation

The `Item Profit Group Code` field is available on the IWX Option Choice card,
the IWX Option Choices list, the Configurator BOM Designer, and the Configurator
Option subform. It is enabled only for Item and Production BOM choices.

- For an Item choice with a blank permanent override, the effective group is
  read from Blue Ace Item field `Item Profit Group Code PTE`.
- For a Production BOM choice, set the group on the permanent Option Choice if
  custom calculation is required.
- A group entered in the Designer is a configuration-session override only; it
  does not update the Item or permanent Option Choice.
- A blank group preserves standard IWX Unit Price behavior.

Maintain the referenced Blue Ace Item Profit Groups before using them. A group
with Profit % of 100 or higher is rejected because it cannot produce a valid
cost-plus-profit price.

### Smart Item Number Option Text

In IWX Smart Item Number configuration, select the new component type
**Option Text** and enter the IWX Option Code whose selected text must be used.
No action is required for existing component types. If the code is blank or
does not resolve to a selected buffer line, this component contributes blank
text rather than borrowing a value from another option.

### Configured Sales Line extended text

For an Item option whose Item extended text must be printed from a configuration
tree, set the IWX Option Choice **Add Extended Text** mode to **Include Item
Extended Text**. The Item's Extended Text Header must:

- apply to **Item**;
- have **Sales Quote** enabled;
- use language `NLD` or **All Language Codes**; and
- be valid on the current work date.

This feature runs during the standard Business Central extended-text insertion
for a Sales Line linked to an IWX configuration. It does not change Item
extended-text master data.

### Configured Item Template default

For an IWX Item Category with a standard Business Central Data Template, set
the Item Disc. Group template line's **Default Value** to an exact placeholder
such as `{I_FA}`. During Item creation, the app replaces it with the selected
Choice Code for configurator option `I_FA` before standard template validation.
Any top-level configurator Option Code can be used in the same way, for example
`{I_DISC}`. A blank or missing selection leaves Item Disc. Group blank.

This placeholder applies only to Item Disc. Group. A literal Default Value and
all other template fields retain standard Business Central and IWX behavior.

## Acceptance criteria

At minimum, test the following in Sandbox:

- filtered and unfiltered Production BOM selection; both new and existing IWX
  Option Choices; and close/reopen of the configurator;
- an inventory-only, Non-Inventory-only, mixed, nested, dated, and alternate
  UOM BOM; verify that inventory cost is not added twice;
- Item default, permanent override, temporary Designer override, blank group,
  `Manually`, and `When Used` pricing behavior;
- Option Text Smart Item Number output, blank/missing options, and unchanged
  standard IWX component types; and
- manual and automatic extended-text insertion, nested quantities, display
  ordering, NLD/date filters, mixed IWX/custom text, and circular child
  configuration handling; and
- an Item created with `{I_FA}`, a blank/missing choice, a literal Item Disc.
  Group Default Value, and an invalid Choice Code that rolls back creation.

The full expected results are in [test-plan.md](test-plan.md). Retain the
executed evidence with the release decision.

## Important operating limits

- Do not create circular Production BOM structures. IWX standard costing runs
  before this extension's custom cost check and may recurse first.
- Do not change the selected Production BOM mapping to validate `Choice Code`
  inside an already open configurator session. The direct mapping is intentional
  because IWX constructed its lookup before the newly created choice existed.
- The custom cost routine adds only Non-Inventory Item cost. IWX remains owner
  of normal inventory cost.
- The custom price formula applies only when a profit group is selected:
  `Unit Price = Round(Unit Cost / (1 - Profit % / 100))`, using General Ledger
  Setup unit-amount rounding precision.
- Dutch Item extended text is restricted to Sales Quote headers as described
  above. It does not add a generic multilingual document-text feature.

## Support handover

For an issue, capture the package version, dependency versions, affected IWX
option/configuration, selected BOM or Item, work date, expected and actual
Unit Cost/Unit Price, and a reproducible Sandbox scenario. Consult
[functional-specification.md](functional-specification.md) for the intended
business outcome and [current-behavior.md](current-behavior.md) for technical
edge cases.
