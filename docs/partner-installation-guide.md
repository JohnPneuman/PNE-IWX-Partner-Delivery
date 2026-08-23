# Partner installation and upgrade guide — PNE extension suite

## Purpose and scope

This guide is for Blu Ace when assessing, packaging, installing, upgrading and
accepting the three private Pneuman per-tenant extensions. Together they cover:

1. selection of Production BOMs as IWX Additional Choices;
2. addition of missing Non-Inventory cost to an IWX Production BOM choice;
3. price calculation from the Blue Ace Item Profit Group;
4. Smart Item Number Option Text and configured Sales Line extended text;
5. Item Disc. Group defaults sourced from a selected configurator Choice Code;
6. complete optional zero-time Item routing operations;
7. read-only Frame Specification on Simulated, Firm Planned and Released
   Production Orders; and
8. independent AutoCAD PIL reconciliation, production-order routing-hour
   reconciliation and auditable net morework/lesswork transfer to an existing
   Sales Quote.

It is not a replacement for IWX configuration, Production BOM maintenance,
Blue Ace price-group maintenance, or Business Central extended-text setup.

## Package identity and dependencies

| App | App ID | Version | Direct dependencies |
|---|---|---:|---|
| PNE Product Configurator Enhancements | `b4514682-8029-4a3d-ad9d-e887cdf51b0f` | `1.0.0.8` | IWX Product Configurator 4.1.9649.1; Bluace Pneuman 1.0.202606.5 |
| PNE Frame Specification | `f84b335b-771e-429f-a30b-4161c3f670a1` | `1.0.0.8` | IWX Product Configurator 4.1.9649.1 |
| PNE Production Order Reconciliation | `3dc4b8fc-77a4-4e2e-9ff2-59f99d444c68` | `2.7.0.10` | none |

All three apps target Business Central application 28.0 and runtime 17.0. The
IWX app ID is `f558b611-3753-4d0b-98ca-6b658a4ed24a`; the Bluace app ID is
`0aeaa135-2753-4f1b-8fc8-2f69b4cd58a8`.

Production packages allow debugging for authorised support but do not allow
source download or embed source in symbol packages. The reviewed source is
transferred through the separate partner-delivery repository instead.

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
3. Compile all packages against the **exact symbols from the target Sandbox**.
   The repository's local validation is necessary but is not a substitute for
   compiling against the currently installed Business Central/IWX/Bluace build.
4. Import the packages whose IDs and versions match the table above. Install or
   upgrade Product Configurator Enhancements first, Frame Specification second
   and Production Order Reconciliation last. The last app is independent, but
   this order makes the configurator and reporting prerequisites easy to prove.
5. Install or upgrade the extensions using the normal Business Central extension
   administration process. No ForceSync, data deletion, or manual database
   alteration is required or supported.
6. Assign roles by duty, not to every user:
   - normal IWX users retain `IWX PC User`; the enhancement extends only the
     required PNE executable surface;
   - normal Frame users receive `PNE Frame Spec. View`;
   - Frame rule maintainers additionally receive `PNE Frame Spec.`;
   - daily PIL processors receive `PNE PIL verwerken`;
   - PIL setup maintainers additionally receive `PNE PIL-inrichting`;
   - read-only structure viewers can receive `PNE productiestructuur bekijken`;
   - Sales Quote handoff still requires the organisation's normal Sales Quote
     permissions; the PIL role deliberately does not grant commercial access.
7. Complete and retain the acceptance evidence before any production release.

Product Configurator Enhancements introduces two customer-content fields with ID 50105, both named
`Item Profit Group Code PNE`: one on the permanent IWX Option Choice and one on
the IWX Configurator BOM line. These are additive table-extension fields;
installation does not alter existing field IDs, types, or application data.

Production Order Reconciliation introduces its own audit/setup tables in the
50170..50201 object range. Frame Specification retains its existing rule table.
Upgrading the versions above is additive. A normal uninstall preserves
extension data, but the app and its event handling are inactive until reinstall.
Selecting **Delete Extension Data** or a Clean schema synchronization deletes
the app-owned data and is irreversible; never use either as a rollback.

## Release evidence, upgrade and rollback

Before production, retain one release folder outside Git containing the three
signed/approved `.app` packages, SHA-256 hashes, the exact target BC/IWX/Bluace
versions, the clean compiler/analyzer output and the completed Sandbox test
records. Never use an older package with the same version number.

For an upgrade, export or otherwise protect the company data according to the
normal Business Central operational procedure, publish the higher version and
run data upgrade. If acceptance fails **before** production use, restore or
recreate the Sandbox from the approved baseline. A temporary normal uninstall
preserves data but must only be done during downtime because app events do not
run while it is absent. If a production upgrade fails after data upgrade, stop
processing and use the agreed tenant recovery procedure; do not ForceSync and
do not publish a lower version over the installed app. A code rollback must be
a new higher app version containing the reverted code and must be retested.

The repository does not yet contain automated AL test codeunits. Therefore the
dated manual Sandbox evidence in the three test plans is a mandatory release
gate, not optional documentation.

Microsoft lifecycle references:

- [Install and uninstall apps](https://learn.microsoft.com/en-gb/dynamics365/business-central/ui-extensions-install-uninstall)
- [Lifecycle of apps and extensions](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-app-life-cycle)
- [Unpublishing, uninstalling and Clean synchronization](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-unpublish-and-uninstall-extension-v2)

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

### Optional zero-time routing operations

Maintain every operation that can receive a component `Routing Link Code` in
the IWX Item Category **Choices Routing**. When IWX creates or reconfigures an
Item, missing operations are copied to the Item's base routing with zero times;
selected operations and their calculated times are preserved. The explicit
Item Card recovery action is for an authorised routing maintainer only.

The repair deliberately refuses a target or Choices Routing that has routing
versions. Otherwise only the base routing would change while another version
could remain effective. Resolve that master-data choice manually; do not bypass
the guard and do not use production-order Refresh as a routing-master repair.

### Frame Specification

Maintain `PNE Frame Spec. Rule` records for the supported frame choice and IWX
option codes. The report is read-only and available on Simulated, Firm Planned
and Released Production Orders. If more than one different frame configuration
matches the actual top production-order items, the app stops instead of printing
an arbitrary Sales Line/configuration. Correct the source link before retrying.

### AutoCAD PIL reconciliation

Open **PIL-inrichting** and maintain only the required PIL groups, CALC
placeholder and real Item mappings. Daily users import from the production
order, follow the four numbered steps, resolve only visible exceptions, review
the proposal and then choose **Veilig doorvoeren**. Quote handoff is optional,
normally follows safe Apply, and
uses the existing authorised Sales Quote. The reconciliation app changes only
the selected live production order and its audit; it has no IWX dependency and
does not write Production BOM master data.

For automatic net more-/lesswork article text, enable **Automatic Ext. Texts**
on the Item and maintain a standard Extended Text Header valid for **Sales
Quote**, the quote language and document date. The app has indirect read access
only to Item and Extended Text master data; users still need the organisation's
normal Sales Quote permissions. A handoff attempted before Apply shows a warning
because editing its new Item line or price, deleting the quote, or converting it
first removes or changes the snapshot that Apply must verify.

Location/variant-specific Stockkeeping Units are part of acceptance: when an
SKU specifies another Production BOM, lookup, structural analysis and routing-
hour reconstruction must use that BOM rather than the Item-card fallback.

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
  Group Default Value, and an invalid Choice Code that rolls back creation;
- optional operations present/absent, the explicit repair action, and safe
  blocking for both target-routing and Choices-Routing versions;
- Frame Specification from all three production-order statuses, including two
  different matching frame configurations that must block as ambiguous; and
- the complete PIL test matrix, including SKU-specific BOM, repeated zero-delta
  import, point-carrier lookup, safe Apply, routing totals, quote net difference,
  reversal, permissions and representative performance timings.

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

When source is transferred, create the archive from reviewed committed files
with the `git archive` procedure in
[development-setup.md](development-setup.md). Do not zip a working directory
that may contain ignored proprietary symbols, generated packages, local launch
settings, or credentials.

For an issue, capture the package version, dependency versions, affected IWX
option/configuration, selected BOM or Item, work date, expected and actual
Unit Cost/Unit Price, and a reproducible Sandbox scenario. Consult
[functional-specification.md](functional-specification.md) for the intended
business outcome and [current-behavior.md](current-behavior.md) for technical
edge cases.

For source onboarding, Workspace Trust, exact symbol acquisition, formatting,
the standard warnings-as-errors build, analyzer evidence, and troubleshooting,
follow [development-setup.md](development-setup.md). Before upgrading a build
that introduces namespaces, complete the external-consumer and Sandbox checks
in [namespace-compatibility-audit.md](namespace-compatibility-audit.md).
