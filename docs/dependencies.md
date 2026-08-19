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

Fields and methods used include Item Category Code, Configuration Option,
Additional Choices Type, Additional Choices Filter, Code, Type, No.,
Description, Variant Code, Unit Price, Unit Cost, Unit of Measure Code,
Ext. Text Template, Image Set Code, Default Quantity, Choice fields,
Quantity per Unit, Smart Item Number Type, Option Code, Option Text,
`UpdateUnitCost`, and `GetRoutingLinkCode`.

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
