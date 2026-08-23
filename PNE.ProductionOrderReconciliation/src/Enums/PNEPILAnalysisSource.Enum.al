namespace Pneuman.ProductionOrderReconciliation;

enum 50193 "PNE PIL Analysis Source"
{
    Caption = 'PIL-analysebron';
    Extensible = false;

    value(0; "Live Production Order")
    {
        Caption = 'Actuele productieorder';
    }
    value(1; "Current Master BOM")
    {
        Caption = 'Huidige master-BOM';
    }
}
