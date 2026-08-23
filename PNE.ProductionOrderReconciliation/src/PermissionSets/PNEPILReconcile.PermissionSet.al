namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Foundation.Company;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;

permissionset 50187 "PNE PIL Reconcile"
{
    Assignable = true;
    Caption = 'PNE PIL verwerken';
    Permissions = tabledata "PNE PIL Header" = R,
                  tabledata "PNE PIL Line" = R,
                  tabledata "PNE PIL Target" = R,
                  tabledata "PNE PIL Raw Line" = R,
                  tabledata "PNE PIL Change Line" = R,
                  tabledata "PNE PIL Quote Reversal" = R,
                  tabledata "Company Information" = R,
                  tabledata "Production Order" = R,
                  tabledata "Prod. Order Line" = R,
                  tabledata "Prod. Order Component" = R,
                  tabledata "Production BOM Header" = R,
                  tabledata "Production BOM Line" = R,
                  tabledata "Production BOM Version" = R,
                  tabledata "Reservation Entry" = R,
                  tabledata Item = R,
                  tabledata "Item Unit of Measure" = R,
                  tabledata "Stockkeeping Unit" = R,
                  codeunit "PNE PIL Import" = X,
                  codeunit "PNE PIL Mgt." = X,
                  codeunit "PNE PIL Sales Quote Mgt." = X,
                  codeunit "PNE PO Config. Structure Mgt." = X,
                  page "PNE PIL Reconciliations" = X,
                  page "PNE PIL Reconciliation" = X,
                  page "PNE PIL Reason Dialog" = X,
                  page "PNE PIL Destination Lookup" = X,
                  page "PNE PIL Carrier Lookup" = X,
                  page "PNE PIL Lines Part" = X,
                  page "PNE PIL Targets Part" = X,
                  page "PNE PIL Raw Lines Part" = X,
                  page "PNE PIL Change Lines Part" = X,
                  page "PNE PO Configuration Structure" = X,
                  report "PNE PIL Change Proposal" = X;
}
