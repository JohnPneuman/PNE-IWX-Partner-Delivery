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
- **No master-data mutation:** Extended Text Header and Line remain unchanged.

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
