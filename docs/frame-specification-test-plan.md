# Frame Specification test plan

Run these scenarios only in a Business Central Sandbox.

- **Rule maintenance:** create, edit, disable, and delete a `PNE Frame Spec.
  Rule`; verify Item and Production BOM component selection and description,
  quantity, and correction validation.
- **BMP source:** run Frame Specification from a Released Production Order
  whose source sales order has one BMP configuration with `I_FRM`; verify the
  correct configuration ID and configured item are printed.
- **Fallback source:** verify lookup from source item and from a production
  order line when no open source sales line is available.
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
