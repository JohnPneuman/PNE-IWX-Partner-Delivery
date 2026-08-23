namespace Pneuman.ProductionOrderReconciliation;

enum 50179 "PNE PIL Carrier Type"
{
    Caption = 'PIL-carriertype';
    Extensible = false;

    value(0; "Production Order Line")
    {
        Caption = 'Productieorderregel';
    }
    value(1; "Production Order Component")
    {
        Caption = 'Productieordercomponent';
    }
}
