# PNE Product Configurator Enhancements

This is the installable Business Central AL app in this repository. It extends
Insight Works Product Configurator in five specific areas: Production BOM
Additional Choices, missing Non-Inventory BOM cost, Blue Ace profit-group
pricing, configuration-derived Item Disc. Group defaults, and sales text.

For an installation and configuration handover, use the repository-level
[partner installation guide](../../docs/partner-installation-guide.md) and
[functional specification](../../docs/functional-specification.md). This file
is the concise technical behavior reference for the app folder.

## Behavior

For configurator options whose Additional Choices Type is `Production BOMs`,
the app uses `Production BOM Header` as the filter table, applies the configured
Additional Choices Filter, and opens the standard Production BOM List.

The selected BOM is created or retrieved as a permanent
`IWX Cfg Option Choice v3` record. Its type remains `Production BOM`, and the
standard IWX validations for Type and No. populate IWX-managed fields.

For an already-open configurator session, the Option Choice fields are copied
directly to `IWX Configurator BOM v3`. The app intentionally does not validate
`Choice Code` immediately because the session lookup was built before the
dynamically inserted choice existed.

IWX continues to calculate normal inventory cost. After IWX updates a
Production BOM Option Choice, this app adds only missing Non-Inventory component
cost. The calculation supports certified active versions, valid line dates,
Business Central-calculated line quantities, unit-of-measure conversion, scrap,
nested Production BOMs, and an active-path cycle guard in the custom traversal.

Circular Production BOM master data is unsupported. IWX calculates its standard
Production BOM cost before this app's post-cost event runs, so IWX can recurse
first when two BOMs reference each other. Do not create circular Production BOM
structures.

An optional Item Profit Group Code can be assigned to a permanent IWX Option
Choice and overridden on the active configurator line. Item choices inherit the
existing Blue Ace Item profit group when no explicit Option Choice override is
set. Production BOM choices can be assigned a group directly.

When a group is selected, Unit Price is calculated from the final Unit Cost and
the group's Profit %. The existing IWX `Update Unit Price` setting remains
authoritative: `Manually` preserves later manual changes, while `When Used`
refreshes the calculated price after Unit Cost is updated. A blank group keeps
the existing IWX Unit Price behavior.

## Smart Item Number using Option Text

The app extends the IWX Smart Item Number component type with `Option Text`.
When that type is used with an Option Code, the component value is read from
the matching selected `IWX Configurator BOM Buffer` line. The value is blank
when the Option Code is blank, no selected buffer line matches, or the matched
Option Text is blank.

Only the explicit `Option Text` type is handled by this app. Existing IWX Smart
Item Number component types and the surrounding IWX number composition,
normalization, length, and uniqueness behavior remain under IWX control.

## Configured Item Template default

For an IWX Item Category with a Data Template, an Item Disc. Group Config.
Template Line can use an exact placeholder such as `{I_FA}` as its Default
Value. When IWX creates the Item, the app replaces it with the selected `I_FA`
Choice Code before standard Config. Template validation. A blank or missing
choice clears Item Disc. Group. Literal default values and all fields other
than Item Disc. Group retain standard IWX and Business Central template
behavior.

## Configured Sales Line extended text

When Business Central inserts extended text for a Sales Line linked to an IWX
configuration, the app rebuilds the temporary output if at least one selected
choice in the configuration tree uses `Include Item Extended Text`. A converted
Complete Item without an IWX Configuration ID on its Sales Line resolves its
one matching configuration snapshot by configured Item No., so Insert Ext.
Text remains available after conversion.

Standard IWX template text and custom Item extended text are emitted per Option
in configured display order. Child configurations follow the same ordering and
their quantities are multiplied through the configuration tree. Valid Item
text is limited to headers enabled for Sales Quote, language `NLD` or All
Language Codes, and dates valid at WorkDate. Each Item line is prefixed as
`<quantity>x ` and wrapped without truncation to the Sales Line text width.

The implementation suppresses duplicate recursive insertion, ignores empty
text, inserts a retained separator between nonempty configuration groups, and
stops on circular child-configuration references. Stored configuration and
extended-text master data are not modified. See `../../docs/current-behavior.md`
for the exact output ordering and scope.

## IWX Business Rules compatibility

The app does not read, create, modify, delete, or bypass Insight Works Business
Rule definitions or their evaluation lifecycle. It uses public Product
Configurator events and preserves IWX validation for Option Choice Type and
No. The documented direct copy to the active configurator buffer is a
current-session lookup workaround after IWX has validated the permanent
Option Choice; it does not write Business Rule data or initiate a Rule Engine
evaluation. See `../../docs/iwx-business-rules-compatibility.md`.

## Dependency

Required dependencies:

- Insight Works Product Configurator 4.1.9649.1;
- Blue Ace Pneuman 1.0.202606.5.

The app identity is `b4514682-8029-4a3d-ad9d-e887cdf51b0f`, version `1.0.0.4`;
the required Business Central application is 28.0 and runtime is 17.0. Verify
the exact dependency app IDs and public symbol assumptions in
`../../docs/dependencies.md` before compiling against an upgraded dependency.

## Manual verification

Run the scenarios in `../../docs/test-plan.md`, especially existing and new
choices, filtering, immediate Unit Cost display, mixed and nested BOM costs,
profit-group defaults and overrides, manual/when-used pricing, Smart Item
Number Option Text, configured text ordering and nesting, and reopening the
configurator. Treat circular BOMs as invalid test data and verify that circular
child configurations stop with the documented error.
