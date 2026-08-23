# Dependencies

## Insight Works Product Configurator

Required version: **4.1.9649.1**

| Symbol | Use | Compatibility concern |
|---|---|---|
| Codeunit `IWX Additional Choices Mgmt.` | Publishes filter and selection integration events | Event names and signatures |
| Table `IWX Configurator Option v3` | Additional Choices Type and Filter | Key and field changes |
| Table `IWX Cfg Option Choice v3` | Permanent choices, standard validation, cost event | Type/No. validation and field semantics |
| Table `IWX Configurator BOM v3` | Active configurator line | Direct mapping and session lookup behavior |
| Table `IWX Configurator BOM Buffer` | IWX text and configuration transfer fields | Quantity, text mode, and child configuration fields |
| Codeunit `IWX PC Sales Line Mgt.` | Retrieves the configuration linked to a Sales Line | Public method and temporary record behavior |
| Codeunit `IWX Cfg. Smart Item No. Mgmt.` | Publishes the custom Smart Item Number sequence-value event | Event signature, handling order, and `IsHandled` semantics |
| Table `IWX Cfg. Smart Item No. Config` | Supplies the Smart Item Number type and Option Code | Field names, types, and component lifecycle |
| Enum `IWX Cfg. Additional Choices Type` | Extended by object 50100 | Extensibility and value compatibility |
| Enum `IWX Cfg. Option Choice Type` | Uses `Production BOM` | Enum value semantics |
| Enum `IWX Cfg. Smart Item No. Type` | Extended by object 50113 | Extensibility and value compatibility |

Used events and subscriber signatures:

- `OnSetCustomAdditionalChoicesFilterObjectIDWithConfiguratorOption`:
  `var Integer`, `Record "IWX Configurator Option v3"`.
- `OnSelectCustomAdditionalChoicesWithConfiguratorBOM`:
  `var Record "IWX Configurator BOM v3"`.
- Table event `OnAfterUpdateUnitCost`:
  `var Record "IWX Cfg Option Choice v3"`,
  `Record "IWX Cfg Option Choice v3"` representing the previous record.
- Table event `OnBeforeUpdateUnitPrice`:
  `var Record "IWX Cfg Option Choice v3"`, `var Boolean`.
- Table event `OnAfterValidateChoiceCode`:
  `var Record "IWX Configurator BOM v3"`,
  `Record "IWX Configurator BOM v3"` representing the previous record.
- Page event `OnBeforeOpenPage`:
  `var temporary Record "IWX Configurator BOM v3"`, `var Code[20]`.
- Codeunit `IWX Cfg. Smart Item No. Mgmt.` event
  `OnGetSequenceValueTypeElse`: `var Text`,
  `Record "IWX Cfg. Smart Item No. Config"`,
  `var temporary Record "IWX Configurator BOM Buffer"`, `var Boolean`.
- Codeunit `Transfer Extended Text` event
  `OnInsertSalesExtTextRetLastOnBeforeFindTempExtTextLine`:
  `var temporary Record "Extended Text Line"`, `Record "Sales Line"`.
- Codeunit `Transfer Extended Text` event `OnBeforeSalesCheckIfAnyExtText`:
  `var Record "Sales Line"`, `Record "Sales Header"`, `Boolean`,
  `var Boolean`, `var Boolean`, `var Boolean`, `var Boolean`.
- Codeunit `IWX Configurator Mgmt.` event
  `OnBeforeCreateItemWithConfiguratorBOM`: `Record Item`,
  `var Record "IWX Configurator BOM v3"`, `var Boolean`.
- Codeunit `Config. Template Management` event
  `OnInsertTemplateBeforeValidateFieldValue`: `var RecordRef`, `FieldRef`,
  `Text[2048]`, `Integer`, `var Boolean`, `Record "Config. Template Line"`.

Fields and methods used include Item Category Code, Configuration Option,
Additional Choices Type, Additional Choices Filter, Code, Type, No.,
Description, Variant Code, Unit Price, Unit Cost, Unit of Measure Code,
Ext. Text Template, Image Set Code, Default Quantity, Choice fields,
Quantity per Unit, Smart Item Number Type, Option Code, Option Text,
`UpdateUnitCost`, and `GetRoutingLinkCode`.

The optional Item Disc. Group mapping also reads IWX Configurator Item Category
field `Data Template` and standard `Config. Template Line` fields `Data
Template Code`, `Table ID`, `Field ID`, and `Default Value`. It validates the
resolved Choice Code through the standard Item field validation event.

After an IWX upgrade, inspect the actual symbols before compiling: confirm all
used events and `var`/temporary semantics, keys, enum values, Type/No.
validation side effects, `UpdateUnitCost`, Smart Item Number handling order,
mapping fields, and the current-session lookup behavior. Never infer renamed
fields or events and never copy proprietary IWX source into this repository.

## Microsoft Business Central

| Symbol | Use |
|---|---|
| Production BOM Header | Filter table, selected BOM, certification status |
| Production BOM Line | Version/date-filtered components and calculated quantity |
| Production BOM List | Standard lookup UI |
| Production BOM Version | Active certified version data through version management |
| Item | Type and Unit Cost for Non-Inventory components |
| Codeunit VersionManagement | `GetBOMVersion` at `WorkDate()` |

The current implementation uses
`Production BOM Line.GetQtyPerUnitOfMeasure()` for Item UOM conversion. It does
not directly call Unit of Measure Management.

Configured Sales Line text reads standard `Extended Text Header` and
`Extended Text Line` records. The current scope selects Item headers enabled
for Sales Quote with language `NLD` (or All Language Codes) and dates valid at
WorkDate. It does not modify extended-text master data.

## Blue Ace Pneuman

Required version: **1.0.202606.5**

App ID: `0aeaa135-2753-4f1b-8fc8-2f69b4cd58a8`

| Symbol | Use | Compatibility concern |
|---|---|---|
| Tableextension 90000 `Item PTE` | Reads Item field 90000 `Item Profit Group Code PTE` as the inherited default | Field name, number, type, and owning app |
| Table 90000 `Item Profit Group PTE` | Validates group codes and reads field 20 `Profit %` | Key, percentage semantics, and field accessibility |

The Blue Ace internal Item helper and update codeunits are not called. They are
internal and manage Item validation; this app reads only the public table and
field symbols. After a Blue Ace upgrade, verify the app identity, Item field,
group table key, Profit % field, and standard `Price=Cost+Profit` semantics
before compiling or publishing.

## PNE Production Order Reconciliation

This third app has no Insight Works or Blue Ace dependency. It compiles only
against Microsoft Business Central application 28.x symbols.

| Microsoft symbol | Use | Compatibility concern |
|---|---|---|
| Production Order | Identifies Simulated, Firm Planned and Released orders for PIL and the configuration view | Status and primary key semantics |
| Prod. Order Line | Finds and validates a point-carrier or eligible produceerbare `G.`-carrier production order line; supplies the stored root BOM/version to the configuration view | Quantity validation, stored BOM/version and linked-line semantics |
| Prod. Order Component | Finds/scales a point-carrier or eligible produceerbare `G.`-carrier component, locates a live CALC source, and creates actual components | Field validation, warehouse/reservation and quantity formula behavior |
| Prod. Order Routing Line, Capacity Unit of Measure and Calculate Prod. Order | Selects one unambiguous routed end-item owner, writes the complete order-wide Routing Link hour total and reschedules affected live order lines | Source/end-item identity, Routing Reference/No. filters, Run Time and Lot Size semantics, capacity-UOM conversion and `CalculateRoutingFromActual` behavior; zero-time optional operations must remain disabled |
| Reservation Entry | Follows existing linked production-order demand and detects reservations | Source filter, paired entry and ordertracking semantics |
| Production BOM Header/Line/Version and VersionManagement | Read-only structural fallback and temporary configuration tree: stored root Production BOM Version Code where present, otherwise certified/date-valid child selection | Certification, start/due/work-date filtering, existing routing-link display and recursive/cycle/display-limit semantics; conversion/mismatch must block the PIL fallback rather than be estimated |
| Item | Constrains group setup, resolves imported descriptions and recalculates the CALC Unit Cost; resolves a child BOM beneath an Item in the temporary configuration tree; after a separate user confirmation repairs only a same-number point Item's missing/incorrect Production BOM No. through standard validation | Inventory/Non-Inventory type, Production BOM No. and Unit Cost validation; existing Item subscribers must run and no general direct Item-modify permission is granted |
| Sales Header, Sales Line and standard Extended Text | Validates a selected existing eligible Sales Quote, appends grouped original-to-final net morework or lesswork as new Item lines and inserts applicable automatic attached article text | Open/Quote Accepted/valid-until state, standard Sales Line price calculation, positive/negative quantity validation, line numbering, currency, item/variant/UOM validation, `Automatic Ext. Texts`, Sales Quote/date/language text applicability and shared Item/text-link integrity; codeunit 50197 carries only indirect read permission for Item and Extended Text master data, while the user still needs normal separate Sales Header/Line read/create rights |
| Sales Quotes and Sales Quote pages | Presents the user-selected existing Sales Quote and opens it after successful handoff | Public lookup/page-action anchors; the application code creates no quote and never edits an existing quote line; PNE PIL Reconcile deliberately grants no sales-table or sales-page rights |
| Simulated/Firm Planned/Released Production Order pages | Host Import, PIL-history and read-only BOM-stamstructuur actions | Public page/action anchors and standard page access |
| InStream and UploadIntoStream | Read the headerless, single-quoted four-field AutoCAD file | Encoding, line read and quote/decimal semantics |

After a Microsoft application upgrade, inspect these exact public symbols and
rerun the headerless-import, structural-driver, CALC-replacement, Production
BOM fallback and warehouse safeguard scenarios. Confirm specifically that a
highest structural driver wins only in its own carrier, while loose items in a
different direct-CALC carrier remain replaceable. `7.*` is not a dependency or
a hardcoded application rule. Also rerun the Sales Quote grouped positive,
negative and net-zero scenarios, expired/accepted quote, shared quote-line
integrity, reversal and standard-price scenarios. Do
not add IWX symbols merely because other apps in the monorepo use them. Also
rerun the configuration-tree scenario with the stored root BOM/version, a
date-effective certified child version and circular/deep nested BOMs. The
separate **PNE PO Struct View** role must stay limited to the
read-only page/codeunit and standard source data; it must not add a PIL, IWX or
production-order write permission.
