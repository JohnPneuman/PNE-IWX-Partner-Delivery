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

## Configured Item Template defaults

When IWX creates an Item from a configurator category whose Data Template has
an Item Disc. Group Config. Template Line with a Default Value in the exact
form `{<Option Code>}`, the app replaces that placeholder with the selected
Choice Code from the top-level configuration. For example, `{I_FA}` assigns
the selected `I_FA` Choice Code. A missing or blank choice explicitly clears
the new Item's Item Disc. Group. Other template fields and values are left to
standard IWX and Business Central template processing.

The mapping starts through IWX's public pre-creation event and substitutes the
value through Business Central's standard Config. Template validation event.
It does not change the Config. Template, IWX configuration, or IWX Business
Rules. It validates the active template `FieldRef` without retrieving the
not-yet-inserted Item. No `Commit()` is used, so an invalid Choice Code fails
and rolls back the surrounding Item-creation transaction.

## Optional configured-Item routing operations

After IWX creates or genuinely reconfigures an Item, the app compares the
Item Category Choices Routing with the Item's base routing. A missing optional
operation is copied with zero Setup Time and zero Run Time so a Production BOM
Routing Link such as `COD` can always resolve. Existing operations, selected
times and routing versions are not overwritten. If either the target Item
routing or the Item Category Choices Routing contains a version, automatic
repair stops before writing because changing only the base routing would not
prove which version is effective.

Normal Business Central production-order refresh does not perform this repair
and never changes shared Item-routing master data. For one older configured
Item, a routing-authorized user can run **Optionele routing herstellen** on the
Item Card. The action reads the Item's single IWX configuration and category
choices, previews the result and inserts only the missing zero-time operations.
An ambiguous configuration, missing base routing, target/Choices routing version or operation
number conflict blocks without a partial repair. Refreshing an existing
production order afterward remains a separate planner decision and is safe
only before consumption, picks or output.

## Production Order Reconciliation

Op Simulated, Firm Planned en Released Production Order staat onder
**Functions** ook **BOM-stamstructuur**. Dit opent een alleen-lezen boom
met het hoofdartikel, de bestaande onderliggende Production BOM's als koppen en
hun ingesprongen artikelen. Bovenaan staat ook **Hoofd-BOM / versie** van de
eerste productieorderregel; bij meerdere hoofd-BOM's maakt de tekst dat
duidelijk en staan alle takken in de boom. De root komt uit de op de **Prod.
Order Line** vastgelegde Production BOM en gebruikt de vastgelegde versie waar
die gevuld is; anders gebruiken root en onderliggende BOM's alleen een
gecertificeerde, datumgeldige versie op achtereenvolgens startdatum, uiterste
datum of werkdatum. Een artikel met een eigen Production BOM krijgt eveneens
een duidelijke kind-BOM-kop met de gebruikte versie. Een Routing Link Code
wordt uitsluitend getoond wanneer die op de bestaande BOM-regel staat.

De boom gebruikt tijdelijke standaard **Production BOM Line**-records. Er
ontstaat geen nieuwe PNE-tabel, PIL-dossier of auditrecord en er wijzigt geen
Productieorder, Item, Production BOM, IWX-record of Business Rule. Een cirkel,
diepte van meer dan 50 niveaus of meer dan 20.000 weer te geven regels wordt
als melding getoond en niet verder uitgeklapt. Naast de PIL-rollen kan de
alleen-lezen rol **PNE productiestructuur bekijken** (permission set 50198,
object `PNE PO Struct View`) uitsluitend deze pagina en de benodigde
standaard brondata openen.

On Simulated, Firm Planned and Released production orders, **Import AutoCAD
PIL** accepts the actual headerless four-field AutoCAD format:

```text
'Artikelnummer','Tek. KompNr','KlemNr','Art. Aantal'
```

A blank `Art. Aantal` means one. Every source row is retained and item totals
are aggregated for review. The only maintained mapping is a PIL group to an
existing Non-Inventory CALC placeholder, plus its eligible Inventory-items.
There are no profiles, productiedoelen, positions or fixed-assembly recipes.

Prepare first traverses the live linked production-order structure. Every
puntartikel (`.PN...`, `.EA...`, `.PH...`, `.TO...`, enzovoort) is eligible as
a carrier. A `G.`-item is eligible only when it is an Inventory-item with
replenishment system Prod. Order and a certified Production BOM; pure G.
uren-/materiaalgroepen and Purchase/Non-Inventory helper items are excluded.
When both occur in one linked branch, the puntcarrier remains leading. When
the live chain does not yield a structural driver for an eligible carrier, the
app reads, but never changes, the Production BOM as a fallback; an unlinked
carrier component can be recognized this way as well. On a root production-
order line it uses the stored Production BOM Version Code where present; other
fallback levels require a certified, date-valid version. Routing links, scrap,
Calculation Formula and UOM conversion or mismatch block this fallback. It
selects the highest imported item that has a lower structural level as the
structural driver; `7.*` has no special meaning. Imported descendants of that
driver are covered for audit and are not applied a second time. Within the same
carrier that structural driver is leading even where a configured CALC component
exists; only loose grouped items without such a driver take the direct CALC
route. Because the file has no parent context and aggregated item totals cannot
be split safely, Prepare blocks an item that is both structurally represented
and independently available through a loose CALC carrier; it never silently
consumes the loose quantity as structural coverage.

When one article number occurs both as a physical Item line and as a nested
Production BOM heading, the Item line is the single quantity-bearing PIL
driver. The identically numbered BOM heading remains available for lower
structure and hours but is never counted as a second physical item. A legacy
BOM with only the nested heading remains recognizable through the controlled
master-BOM fallback. An existing linked point-carrier line uses its stored BOM
and version for that check, so a repeated already-applied PIL can resolve as a
no-change audit instead of becoming an open item again.

The target audit states whether each carrier was found through the live
production-order snapshot or the read-only current master-BOM fallback. That
provenance explains the analysis but never authorizes a master-BOM change.
Drivers that reach the same carrier are treated as minimum requirements rather
than separate orders. The highest rounded-up whole-carrier requirement wins;
the requirements are never summed. Only a genuinely shared imported quantity
across different independent carriers remains a manual allocation decision.

Prepare also creates one read-only proposal line per carrier, with the old and
proposed quantity, the delta, PIL details and a current production cost
indication. **Print Change Proposal** only reports this information. A user may
hand grouped non-zero original-to-final net deltas to a selected existing
Sales Quote only when it is Open, not accepted and not expired. Positive net
deltas become morework Item lines, negative net deltas become lesswork Item
lines and net zero creates no line. The app never edits existing quote or
configurator lines. Standard Business Central Sales Line validation supplies
the quote price, not IWX formulas.

For every created Item line with **Automatic Ext. Texts** enabled, applicable
standard Business Central Extended Text for Sales Quote, quote document date
and quote language is inserted as
attached text. Every non-empty source text line shows the net quantity;
lesswork is explicitly labelled and uses the absolute quantity. Long text is
word-wrapped without
truncation. The PIL app does not invoke the IWX configured-text generator or
configuration tree. Existing, missing, added or changed attached text is part
of commercial report and reversal integrity; text-only drift does not block the
technical production-order Apply. The linked Item line itself must still match
its immutable snapshot. The user needs separate normal Business
Central Sales Quote/Sales Line read-and-create rights; **PNE PIL Reconcile**
intentionally grants no Sales Header, Sales Line or sales-page rights. When a
user changes **Naar deze carrier** on a *Gereed om toe te passen* dossier before handoff,
the status immediately becomes *Verdeling nodig*: **Stap 2 - Controleer verdeling**
must rebuild the proposal before handoff or Apply can continue. After quote
linking, the technical proposal cannot be re-prepared or reallocated. The
recommended order is technical Apply first and quote handoff second; handoff
before Apply requires a warning confirmation. The report live-checks whether
linked quote lines and their attached text still
exist and still match item, variant, UOM, quantity and expected standard text.
If the user has lost Sales Line read access,
the technical report remains usable and states that the quote link cannot be
verified with the current permissions; that is commercial review, not a report
failure or automatic repair.

The target list allocates a PIL item automatically when exactly one carrier is
valid; more than one carrier requires an exact manual split. Apply is available
only after the allocation check reports Gereed om toe te passen. It validates and raises
the structural or CALC carrier with standard Business Central triggers, then
replaces an exact live CALC source with the allocated actual Inventory-item
components. It blocks stale, consumed, reserved, picked, finished, ambiguous
and inexact structures. No `Commit()` is used, so a failure rolls the complete
Apply back.

Routing-hour comparison is separate from the component destination. Where the
order has one unambiguous routed end-item line, the app snapshots all eligible
Non-Inventory components with a Routing Link Code across every live production
order line before and after Apply. Each component contributes `Quantity per ×
owning production-line quantity ÷ routed end-item quantity`, the live equivalent
of BOM Buffer **Qty. per Top Item**. Only that proven difference is added to or
subtracted from the existing active end-item operation. Hidden hours that were
already represented in the routing but are not expanded as live components are
therefore retained. Nested work-area routes are not chosen merely because
material was added there, and an optional live routing operation with Run Time
zero remains zero. Standard Business Central then reschedules the affected live
routing lines; no IWX or Bluace master routing is invoked or modified.

The same calculation is available without a PIL dossier through **Routinguren
opnieuw berekenen** on Simulated, Firm Planned and Released Production Orders.
It is intended for manual production-component changes and requires an explicit
confirmation before active linked route times are replaced.
It blocks when a component with an hour-bearing Production BOM is not expanded,
unless its active certified Production BOM can be read safely. Such a component
is expanded read-only in memory and contributes its nested Routing Link hours at
the actual component quantity per routed top item. No production-order line or
master BOM is created or modified. Scrap and Fixed Quantity in this fallback
remain blocked rather than guessed.

Production BOM Header/Line master data, the original configured Item and all
IWX data remain unchanged. A Toegepast audit dossier is not prepared or applied
again. See `production-order-reconciliation.md` for the complete rules and
`production-order-reconciliation-test-plan.md` for the required Sandbox tests.
