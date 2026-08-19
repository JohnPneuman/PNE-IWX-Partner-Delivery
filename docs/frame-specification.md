# Frame Specification

## Purpose and boundary

PNE Frame Specification creates a printable production frame specification
from an existing Insight Works Product Configurator tree. The report starts
from the top-level BMP configuration, follows the selected `I_FRM` branch, and
uses configured Pneuman rules to derive frame-material lines. `I_FRT` is
header information only and never generates a material line.

The app is separate from PNE Product Configurator Enhancements. It has no
event subscribers, no writes to IWX records, and no changes to IWX Business
Rules. IWX remains the owner of configuration selection and configuration
history.

## Data ownership and database impact

Table 50151 `PNE Frame Spec. Rule` stores customer-maintained rule data:
frame configuration, triggering option, component, quantity, dimensions,
corrections, print sort order, and enabled state. It is the only persisted
business data owned by the app.

Table 50152 `PNE Frame Spec. Line` defines the structure of calculated lines.
The current report and preview use temporary instances only, so no calculated
line is persisted. Both tables are new database objects; no existing Business
Central or IWX table, field, ID, or type is changed.

Uninstalling the app removes the persisted rule data. Upgrades must preserve
the table and field IDs and types. Never use ForceSync.

## Report template

Report 50158 `PNE Frame Specification` is opened by the `Frame Specification`
action on Released Production Order. Its default layout is the Word file
`apps/PNE.FrameSpecification/Layouts/PNEFrameSpecification.docx`, registered
as `FrameSpecificationWord`. Business Central report-layout selection can
replace or customize the `.docx` without changing calculation code.

## Source resolution

The report first looks for a BMP configuration on the source sales order. If
none is available, it looks up the configured source item and then production
order lines. It fails clearly when no configuration containing `I_FRM` can be
found. Configuration records are copied into temporary buffers and recursive
configuration cycles stop with an error.
