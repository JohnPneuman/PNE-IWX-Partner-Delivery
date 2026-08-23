namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;

permissionset 50198 "PNE PO Struct View"
{
    Assignable = true;
    Caption = 'PNE productiestructuur bekijken';
    Permissions = tabledata "Production Order" = R,
                  tabledata "Prod. Order Line" = R,
                  tabledata "Production BOM Header" = R,
                  tabledata "Production BOM Line" = R,
                  tabledata "Production BOM Version" = R,
                  tabledata Item = R,
                  codeunit "PNE PO Config. Structure Mgt." = X,
                  page "PNE PO Configuration Structure" = X;
}
