# Test plan

## Manual regression scenarios

For every BOM-cost scenario, verify the permanent IWX Option Choice, active
configurator line, Extended Details behavior, Unit Cost, and unchanged Unit
Price when no profit group is selected.

- **Inventory-only BOM:** IWX inventory cost remains unchanged; custom cost is
  zero and is not double-counted.
- **Non-Inventory-only BOM:** Unit Cost equals the missing Non-Inventory cost.
- **Mixed BOM:** IWX inventory cost plus exactly one Non-Inventory addition.
- **Nested BOM:** nested Non-Inventory cost is multiplied by parent quantities.
- **Active BOM version:** the certified version effective on WorkDate is used.
- **Date-filtered lines:** future and expired lines are excluded.
- **Scrap:** Scrap % is included except for Fixed Quantity.
- **Alternate UOM:** Item cost uses the BOM UOM-to-base conversion.
- **Circular BOM constraint:** Do not create circular Production BOM master
  data. IWX standard costing runs before the custom post-cost subscriber and
  may recurse before the custom cycle guard is reached.
- **Existing choice:** type/number are checked, cost refreshes, no duplicate is
  inserted.
- **New Additional Choice:** a permanent Production BOM choice is inserted by
  standard Type/No. validation.
- **Manual Production BOM choice:** the Unit Cost event adds the same missing
  Non-Inventory cost.
- **Filtering:** Additional Choices Filter limits Production BOM List.
- **Reopen configurator:** the permanent choice remains selectable.
- **Extended Details:** Production BOM is not interpreted as an Item.
- **No accidental Item creation:** selection creates only the intended IWX
  Option Choice.
- **Immediate display:** Unit Cost is visible without reopening the session.
- **Current-session mapping:** no `Choice Code ... is not valid` error occurs.

## Profit-group pricing scenarios

- **Item default:** an Item choice with no Option Choice override shows the
  Blue Ace Item profit group in the Designer and retains standard IWX pricing.
- **Item session override:** changing the Designer profit group changes only
  the active line and Unit Price, not Item or the permanent Option Choice.
- **Item permanent override:** a nonblank Option Choice group overrides the
  Item default and uses the custom calculation.
- **Production BOM blank:** no group preserves the current Unit Price behavior.
- **Production BOM group:** the permanent group calculates Unit Price from the
  final Unit Cost and the group's Profit %.
- **Manual update:** after group validation, a later manual Unit Price remains
  unchanged while `Update Unit Price` is `Manually`.
- **When-used update:** Unit Price refreshes after the final Unit Cost when the
  setting is `When Used`.
- **Final cost order:** mixed and nested BOM prices include the custom
  Non-Inventory cost exactly once.
- **Clear override:** clearing a session group restores the permanent Option
  Choice Unit Price.
- **Invalid percentage:** Profit % of 100 or higher stops with a clear error.
- **Reopen configurator:** the session override and calculated price survive
  the supported IWX close/reopen lifecycle.
- **Read-only Designer state:** the custom field must not permit a change when
  IWX has disabled editing for the configurator line.
- **Permissions:** a normal configurator user can read the group relation and
  calculate price without receiving broader Blue Ace modification rights.

## Smart Item Number Option Text scenarios

- **Explicit Option Text type:** a configured component of type `Option Text`
  returns the selected buffer line's Option Text for its Option Code.
- **Existing component types:** every standard IWX Smart Item Number type keeps
  its existing value and composition behavior.
- **Blank Option Code:** the new component returns blank without an error and
  without taking a value from another Option.
- **Missing selected Option:** an Option Code with no matching selected buffer
  line returns blank.
- **Blank Option Text:** a matching selected line with blank Option Text returns
  a blank component.
- **Changed selection:** recalculation uses the current temporary buffer and
  returns the newly selected Option Text rather than a stale value.
- **Multiple components:** Option Text and standard IWX components are combined
  in the configured IWX sequence order.
- **Repeated Option Code:** when the supplied buffer contains more than one
  matching line, the first line in IWX buffer ordering supplies the value;
  verify that intended production configurations do not make this ambiguous.
- **Length and characters:** long or special Option Text is passed to IWX and
  follows the same final number length, normalization, and validation rules as
  other IWX sequence values.
- **Collision and failure:** duplicate or invalid final Item numbers follow IWX
  handling and do not create a partially initialized Item.
- **Reopen and regenerate:** the resulting number is stable across the
  supported IWX close/reopen and Item-creation lifecycle when selections have
  not changed.

## Optional configured-Item routing scenarios

- **New Item, option off:** the completed Item base routing contains the
  category operation with its Routing Link Code and zero Setup/Run Time.
- **New Item, option on:** the selected operation and its calculated time are
  preserved and are never reset to zero.
- **Existing complete Item:** explicit repair reports that nothing is missing
  and writes no routing line.
- **Older incomplete Item:** a routing-authorized user runs **Optionele routing
  herstellen** and only the missing zero-time operation is inserted.
- **Refresh boundary:** normal production-order refresh does not modify the
  Item base routing. Transfer of a repaired routing to an existing order is a
  separate planner action on a clean, unconsumed order.
- **Ambiguity and target version:** multiple IWX configurations, any version on
  the configured Item's target routing, or an operation-number conflict blocks
  without a partial change.
- **Choices-routing version:** add a version to the Item Category Choices
  Routing while the target has none. New-Item completion and explicit repair
  must block before changing the target base routing.
- **Least privilege:** a user without Routing Line insert permission cannot see
  the explicit repair action; normal configured-Item creation remains usable
  through the app's indirect permission.
- **IWX regression:** configuration result and Business Rules are identical
  before and after the routing-completion feature.

## Configured Sales Line extended-text scenarios

- **Manual insertion:** Insert Ext. Text adds every selected NLD Item text.
- **Automatic insertion:** automatic insertion produces the same output.
- **Complete Item fallback:** after converting a Quoting Item to a Complete
  Item, whose Sales Line has no IWX Configuration ID, Insert Ext. Text finds
  the one matching nonblank IWX Configuration ID through `IWX Configurator BOM
  v3`.`Configured Item No.` and produces the same output as before conversion.
- **Complete Item availability:** a converted Complete Item with no standard
  Item Extended Text Header still enables the standard Insert Ext. Text flow
  when its IWX configuration contains an `Include Item Extended Text` choice.
- **Ambiguous Complete Item:** when a Complete Item number matches snapshot
  lines with more than one IWX Configuration ID, the custom fallback does not
  choose a configuration and standard extended-text handling remains intact.
- **Top-level quantity:** Item quantity 5 produces `5x <text>`.
- **Nested quantity:** parent quantity 2 and child quantity 3 produce
  `6x <text>`.
- **Multiple levels/sub-configurations:** every active selected Item is
  included once with its accumulated quantity.
- **Display order:** Item text and child-configuration groups follow the
  matching `IWX Configurator Option v3`.`Display Order` value instead of code
  order, including when the BOM copy has a different or empty display value.
- **Display-order regression:** options `H_PRT_LED` through `H_PWR_DCDC` with
  display values 8010 through 8080 appear in numeric display order, not
  alphabetical option-code order.
- **Snapshot category mismatch:** the Configurator Option display value is
  resolved by option code when the Quoting Item snapshot has an empty or
  different Item Category Code.
- **Template formula context:** per-Option IWX template generation can resolve
  variables from other configuration Options, including `I_WDTH` and
  `I_HGHT`.
- **Language and validity:** NLD and All Language Codes are included; other
  languages, invalid dates, and Sales Quote-disabled headers are excluded.
- **Long text:** prefixed lines wrap at a word boundary without truncation;
  continuation text starts at the beginning of the next line.
- **Quantity width:** quantities such as `1x`, `12x`, and `1000x` are followed
  by one normal space without artificial spacing.
- **No recursive duplicates:** configurations with sub-configurations contain
  every included item extended-text line exactly once.
- **IWX quantity merge:** an item line already produced by IWX with a quantity
  prefix is replaced by, and not retained beside, the custom quantity line.
- **Long word:** a single word exceeding the available width is split without
  losing characters.
- **Zero quantity:** zero accumulated quantity produces no text.
- **Mixed modes:** `Include Item Extended Text` produces quantity-prefixed Item
  text while active `Yes` choices retain their IWX template output without
  duplicating the unprefixed Item text.
- **Mixed-mode order:** IWX template and quantity-prefixed Item text are
  interleaved according to Configurator Option `Display Order`.
- **Nested IWX templates:** `Yes` template lines from one-level and multi-level
  child configurations are included for quoting Items.
- **Configuration separators:** main and child configuration text is emitted
  in tree order with one empty comment line after each nonempty configuration;
  the separator contains one space so standard transfer retains it. No
  separator is added within a configuration or for an empty configuration.
- **Missing Item text:** an `Include Item Extended Text` choice with no valid
  NLD text or an empty text line produces no `1x` blank document line.
- **Include with template value:** an empty IWX buffer remnant from an Include
  choice with Ext. Text Template populated produces no document line.
- **Circular child configuration:** traversal stops with a clear error.
- **Traversal limits:** 51 nested child configurations and more than 20,000
  snapshot rows stop with a clear performance-protection error.
- **No master-data mutation:** Extended Text Header and Line remain unchanged.

## Configured Item Template default scenarios

Evidence status: the repository contains no retained, dated Sandbox result for
the previously reported `{I_FA}` conversion test. Rerun the scenarios below
and retain the environment, app/dependency versions, executor, date, expected
result, actual result, and release decision.

- **Choice Code mapping:** an Item category with a Data Template whose Item
  Disc. Group Default Value is `{I_FA}` replaces the placeholder before
  standard validation and creates an Item with the selected `I_FA` Choice Code
  as Item Disc. Group.
- **Blank choice:** a blank or missing `I_FA` selection creates the Item with a
  blank Item Disc. Group rather than retaining the literal placeholder.
- **No placeholder:** a literal Item Disc. Group Default Value retains standard
  IWX and Business Central Config. Template behavior.
- **Other fields:** placeholders on fields other than Item Disc. Group remain
  untouched by this feature.
- **Invalid choice:** a selected Choice Code invalid for Item Disc. Group stops
  Item creation without a partially updated Item.
- **No IWX mutation:** Config. Template records, IWX Configurator BOM records,
  and IWX Business Rules remain unchanged after Item creation.

## Future automated AL tests

The first test app should cover Non-Inventory-only cost, mixed cost, nested BOM,
UOM conversion, scrap, active version selection, date-filtered lines, circular
references, prevention of inventory double-counting, profit-group resolution,
manual/when-used pricing, rounding, invalid percentages, Smart Item Number
Option Text resolution, unchanged standard Smart Item Number types, configured
text ordering, nested quantity accumulation, wrapping, language/date filters,
duplicate prevention, and circular child-configuration handling.

Create it only when Business Central test dependencies are available, the
sandbox or container can execute tests, and its object ID allocation is agreed.
The test app should use fixtures with explicit WorkDate and certified versions,
invoke one authoritative costing entry point, and assert both returned cost and
the preserved IWX component. A direct unit test should verify the custom
calculation's active-path cycle guard without invoking IWX standard costing.
Until then, these remain concrete manual cases; an empty non-runnable test
project provides no protection.

## Production Order Reconciliation scenarios

The full acceptance matrix is maintained in
`production-order-reconciliation-test-plan.md`. At minimum, release requires:

- real headerless, single-quoted four-field AutoCAD PIL import and raw audit,
  including both `1,00` and `1.00`;
- only PIL-group and PIL-group-article setup, including Business Central Item
  type lookups;
- all pointartikel prefixes as carrier candidates and eligible produceerbare
  `G.` carriers, while G. hour/material/helper groups remain excluded;
- direct CALC route only for loose items without a structural driver in that
  same carrier: raise the selected carrier before replacing its live CALC source
  with actual items;
- generic highest structural driver, including a non-`7.*` fixture and
  coverage of imported descendants without double counting or aggregate
  overlap/scaling;
- read-only Production BOM fallback for an unlinked carrier component, including
  the stored root BOM-version where present, visible target analysis source,
  and safe blocking for routing, scrap, formula and UOM conversion/mismatch;
- automatic allocation for one valid carrier, zero allocation blocking, and
  exact manual allocation for multiple candidates;
- a manual **Naar deze carrier** edit after *Gereed om toe te passen* immediately
  returning the dossier to *Verdeling nodig*, with **Stap 2 - Controleer verdeling**
  required to rebuild the proposal before commercial handoff or Apply;
- clear, read-only carrier change proposal and report, including technical
  cost indication versus commercial sales price;
- selected existing Sales Quote handoff: append positive deltas only as new
  Item lines to an Open, unaccepted, non-expired quote; never alter existing
  quote or configurator lines; use standard Business Central quote pricing,
  not IWX formulas; normal Sales Quote/Sales Line read-and-create rights are
  required separately from **PNE PIL Reconcile**;
- manual commercial review for negative/zero deltas, a locked technical
  snapshot after quote linking, and live report detection of a changed or
  deleted quote line; after Sales Line read access is removed, the technical
  report must remain usable and show permission-based commercial review;
- no Production BOM master-data mutation;
- apply rollback on invalid quantity, formula, Item or later target;
- consumption, reservation and pick blocking;
- stale-carrier, stale structural driver, finished-output, ambiguity and
  applied-audit blocking;
- permission and applied-audit immutability checks;
- availability of PIL and Frame Specification actions on Simulated, Firm
  Planned and Released production orders; and
- unchanged representative IWX Business Rules, Quoting Item conversion and
  Product Configurator behavior before and after app installation.
