# Current behavior

## Production BOM Additional Choices

Enum extension 50100 adds `Production BOMs` to
`IWX Cfg. Additional Choices Type`. For such a configurator option, codeunit
50101 sets `Production BOM Header` as the filter object, reads the option's
Additional Choices Filter, applies it with `SetView`, and opens the standard
Production BOM List in lookup mode.

On selection, the app retrieves an existing IWX Option Choice by Item Category,
Configuration Option, and Production BOM number, or inserts a permanent choice.
An existing choice must have type `Production BOM` and a matching No. A new
choice validates Type and No. so IWX fills its own Code, Description, and cost
fields.

## Active configurator session

The selected Option Choice is copied directly into the active
`IWX Configurator BOM v3` record: Choice Code, Description, Choice Type, Choice
No., Variant, Unit Price fields, Unit Cost, UOM, extended text template, image
set, routing link, and nonzero default quantity.

This direct copy is intentional. Validating `Choice Code` immediately after
inserting the Option Choice can fail because the already-open IWX session built
its selectable lookup before the record existed. Do not restore that validation
unless the session lookup is also refreshed correctly.

## Production BOM cost

After IWX updates Unit Cost for every Option Choice of type `Production BOM`,
the app calculates only missing Non-Inventory component cost and adds it to the
existing IWX Unit Cost. Normal inventory cost is never recalculated by this
custom routine.

The recursive calculation:

- selects the active certified BOM version at `WorkDate()`;
- otherwise requires a certified header;
- filters lines by Version Code, Starting Date, and Ending Date;
- uses Business Central's calculated `Production BOM Line.Quantity`;
- converts Item quantities through `GetQtyPerUnitOfMeasure`;
- applies Scrap % except for Fixed Quantity;
- includes only Items of type Non-Inventory;
- traverses nested Production BOM lines; and
- stops with an error when a BOM number repeats in the custom traversal's active
  path.

Circular Production BOM master data is unsupported. IWX performs its standard
Production BOM cost calculation before raising the post-cost event used by this
app. A circular structure can therefore recurse inside IWX before the custom
active-path check is reached. Production BOMs must not reference each other in
a cycle.

The permanent choice and active configurator line show Unit Cost immediately.

## Option Choice profit-group pricing

An Option Choice can store an optional `Item Profit Group Code PNE`. When this
field is blank for an Item choice, the effective group used in the configurator
comes from Blue Ace field 90000 on Item. The Item record is never changed. A
Production BOM has no Item default and can therefore be assigned a group on the
permanent Option Choice.

The active `IWX Configurator BOM v3` line stores an effective group that can be
overridden for the current configuration. Changing this value recalculates the
line Unit Price without writing back to Item or the permanent Option Choice.
Clearing it restores the permanent Option Choice Unit Price.

The permanent field is shown on the IWX Option Choice card and list. The
effective session field is shown in the Configurator BOM Designer and
Configurator Option subform. These controls are enabled only for Item and
Production BOM choices. The existing IWX PC User permission set is extended
with execute permission for the pricing management codeunit; it does not grant
broader Blue Ace modification rights.

For a nonblank permanent Option Choice group, the app handles IWX
`OnBeforeUpdateUnitPrice` and calculates:

`Unit Price = Round(Unit Cost / (1 - Profit % / 100))`

The rounding precision is the General Ledger Setup Unit-Amount Rounding
Precision. A Profit % of 100 or higher is rejected. A blank group leaves IWX
pricing unchanged. With `Update Unit Price = When Used`, pricing runs again
after the final Unit Cost, including the custom Non-Inventory addition, is
known. With `Manually`, later manual Unit Price changes remain untouched until
the group itself is changed.

## Smart Item Number using Option Text

Enum extension 50113 adds `Option Text` to `IWX Cfg. Smart Item No. Type`.
When IWX requests a value for that explicit type, codeunit 50114 marks the
request handled, clears the result, and looks up the configured Option Code in
the supplied temporary `IWX Configurator BOM Buffer`. The first matching
selected line supplies its `Option Text` as the sequence value.

A blank Option Code, no matching selected line, or blank Option Text produces a
blank component. Other Smart Item Number types are not handled by this app and
continue through standard IWX behavior. IWX remains responsible for combining
the sequence, allowed characters, length, normalization, numbering, collision
handling, and Item creation. Existing configurations change only when the new
type is explicitly selected.

## Configured Sales Line extended text

During standard Sales Line extended-text insertion, the app detects the linked
IWX configuration. When an Item Sales Line has no IWX Configuration ID, such
as after conversion from a Quoting Item to a Complete Item, the app looks up
the configuration snapshot by the Sales Line Item No. in `Configured Item No.`
instead of using the Sales Line lookup. The fallback is used only when every
matching snapshot line has the same nonblank Configuration ID; otherwise it
leaves standard extended-text handling unchanged. When the selected tree uses
`Include Item Extended Text`, the temporary document text is rebuilt from all
selected Item choices using that mode.

When the linked configuration has included Item text, the app also reports
that extended text is available during the standard Sales Line availability
check. This lets **Insert Ext. Text** run for a Complete Item even when that
Complete Item has no standard Extended Text Header of its own.

The traversal follows every Choice Configuration ID and multiplies each Item
quantity by its parent quantities. Valid Dutch Item extended-text lines start
with the formatted quantity and `x `. Text wraps at word boundaries within the
Sales Line description length. Continuation lines use the full line width
because proportional Business Central fonts cannot provide reliable
space-based column alignment. A single word that exceeds the available width
is split as an unavoidable fallback. Headers must be enabled for Sales Quote,
use `NLD` or All Language Codes, and be valid at WorkDate.

Recursive IWX extended-text calls made while a sub-configuration is built are
ignored by the subscriber so included item text is not inserted twice.

Circular child references stop with an error. Item and configured-Item master
text is not changed. Choices using IWX `Yes` retain their standard IWX
template output. IWX template text and quantity-prefixed Item text are generated
per Option in one ordered pass, preventing duplicate standard and custom Item
text. No automatic empty comment lines are inserted within a configuration.
Within every configuration, selected choices and child-configuration references
follow the `Display Order` from their matching `IWX Configurator Option v3`
record. A temporary working copy is used, so the stored configuration BOM is
not modified. Each next line is selected explicitly by its lowest display
value; option code is used only when display values are equal. If the
configuration snapshot does not contain the matching Item Category, the Option
is resolved by its code so its configured display value is still used.

Standard IWX template text is generated per displayed Option while sharing the
complete temporary configuration as formula context. Formula references to
other configuration variables therefore remain available.
Output is grouped in tree order: main configuration, one empty comment line,
then each child configuration and its separator before the next child or deeper
level. A configuration with no output gets no separator. The separator contains
one space because Business Central can skip a truly empty temporary text line.
Empty temporary IWX lines, including empty remnants
from an Include choice that still has an Ext. Text Template value, are ignored.

An `Include Item Extended Text` choice with no valid Dutch text, or with an
empty Extended Text Line, contributes no document line. This allows the mode
to be enabled broadly for hardware choices without producing `1x` blank text.
