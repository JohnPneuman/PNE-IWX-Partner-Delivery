# PNE Frame Specification

This standalone app creates production frame-specification lines from an Insight Works Product Configurator tree. It reads only the selected `I_FRM` branch; `I_FRT` is header information and does not produce frame-material lines.

Rules are keyed by frame configuration and configuration option, such as `PD10.150SI` plus `H_PLT_ALU`. The rule stores the AccountView `ART_BM` corrections and printed quantity. The calculation follows `I_FRM`, reads `I_WDTH` and `I_HGHT` from that child configuration and produces lines only for enabled rules whose options occur in the frame configuration.

Tables 50151 and 50152 are new extension tables. They contain only new rule master data and future production-order snapshots; no existing BC or IWX record is modified. Never deploy this app using ForceSync.

## Production document

The `Frame Specification` action on the Released Production Order opens report 50158. The report finds the top-level BMP configuration from the configured source item (`OBJAV...`) on the production order or its lines. It then builds the calculated frame lines, sorted by description.

Header values come from the BMP options (`I_OBJ`, `I_FRM`, `I_FRT`, `I_FRMC`, `I_WDTH`, `I_HGHT`, and `I_DPTH`). When an open sales line still exists for the configuration, the report also reads the customer, project and responsible user from that sales document. The configured item number remains the object fallback, so the report can still be printed when no sales line is found.

The Word layout is stored in `Layouts/PNEFrameSpecification.docx` and can be replaced or customized through Business Central report layouts without changing the calculation code.

## Insight Works Business Rules compatibility

This app has no event subscribers. It reads `IWX Configurator BOM v3` records
into temporary buffers and produces temporary report lines. It does not create,
modify, or delete Product Configurator configurations, Option Choices, or
Insight Works Business Rule records. Its own configurable frame rules are
stored only in new table `PNE Frame Spec. Rule`; they are not IWX Business
Rules.

## Report template

Report 50158 `PNE Frame Specification` uses the Word layout file
`Layouts/PNEFrameSpecification.docx`, registered in AL as
`FrameSpecificationWord`. Business Central report-layout selection can replace
or customize this `.docx` without changing the AL calculation code.
