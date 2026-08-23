# Frame Specification test plan

Run these scenarios only in a Business Central Sandbox.

- **Rule maintenance:** create, edit, disable, and delete a `PNE Frame Spec.
  Rule`; verify Item and Production BOM component selection and description,
  quantity, and correction validation.
- **BMP source:** run Frame Specification from a Simulated order sourced from a
  Sales Quote and Firm Planned/Released orders sourced from a Sales Order, each
  with one BMP configuration containing `I_FRM`; verify the correct
  configuration ID and configured Item are printed in every status.
- **Fallback source:** verify lookup from source item and from a production
  order line when no open source sales line is available.
- **Multiple Sales Lines:** use one source Sales Order with two different frame
  configurations, but only one configured Item on the top production-order
  line. Verify that the matching Item configuration is printed. Put both
  different configured Items on top production-order lines and verify that the
  report blocks with an ambiguity message instead of printing the first line.
- **Configured Item history:** store two different IWX configuration IDs for
  the same configured Item number. Verify that Item fallback blocks and names
  both IDs; identical repeated snapshot rows must not create false ambiguity.
- **Frame branch:** verify only options under the selected `I_FRM` child
  configuration create material lines; `I_FRT` contributes header data only.
- **Dimensions:** verify `I_WDTH` and `I_HGHT`, width/height flags, and positive
  and negative corrections produce the expected millimetre values.
- **Rule selection:** verify disabled rules and absent configuration options
  produce no line; enabled matching rules follow configured sort order.
- **Report layout:** verify report 50158 uses
  `Layouts/PNEFrameSpecification.docx`, prints all header fields and lines, and
  can be replaced through standard report-layout selection.
- **No mutation:** before and after preview/report execution, verify IWX
  Configurator BOM, Production Order, Sales Line, and IWX Business Rules are
  unchanged.
- **Error handling:** verify clear errors for a missing BMP configuration,
  missing `I_FRM`, no matching rules, and circular child configurations.
- **Traversal limits:** a synthetic 51-level child configuration and a tree
  exceeding 20,000 snapshot rows must stop clearly without partial output or a
  long-running session.
- **Least privilege:** a user with only `PNE Frame Spec. View` plus the normal right
  to open the production order can preview and print, but cannot change IWX,
  Sales, Item, Production BOM or Production Order records through this role.
  A separate rule maintainer with `PNE Frame Spec.` can maintain only the PNE
  rule setup and its lookups.
