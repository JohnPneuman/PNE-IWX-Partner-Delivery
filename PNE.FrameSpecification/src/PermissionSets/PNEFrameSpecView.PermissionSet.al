namespace Pneuman.FrameSpecification;

using Microsoft.Foundation.Company;
using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Sales.Document;

permissionset 50165 "PNE Frame Spec. View"
{
    Assignable = true;
    Caption = 'PNE Frame Specification bekijken';
    Permissions = tabledata "PNE Frame Spec. Rule" = R,
                  tabledata "PNE Frame Spec. Line" = R,
                  tabledata "Company Information" = R,
                  tabledata Item = R,
                  tabledata "Production Order" = R,
                  tabledata "Prod. Order Line" = R,
                  tabledata "Production BOM Line" = R,
                  tabledata "Sales Header" = R,
                  tabledata "Sales Line" = R,
                  tabledata "IWX Configurator BOM v3" = R,
                  codeunit "PNE Frame Spec. Action Mgt." = X,
                  codeunit "PNE Frame Spec. Mgt." = X,
                  page "PNE Frame Spec. Preview" = X,
                  report "PNE Frame Specification" = X;
}
