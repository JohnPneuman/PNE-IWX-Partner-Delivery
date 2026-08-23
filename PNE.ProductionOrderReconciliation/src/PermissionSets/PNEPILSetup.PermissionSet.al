namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Inventory.Item;

permissionset 50199 "PNE PIL Setup"
{
    Assignable = true;
    Caption = 'PNE PIL-inrichting';
    Permissions = tabledata "PNE PIL Group" = RIMD,
                  tabledata "PNE PIL Group Item" = RIMD,
                  tabledata Item = R,
                  codeunit "PNE PIL Cost Mgt." = X,
                  page "PNE PIL Groups" = X,
                  page "PNE PIL Group Items" = X;
}
