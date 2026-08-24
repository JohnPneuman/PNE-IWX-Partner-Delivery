namespace Pneuman.ProductionOrderReconciliation;

enum 50199 "PNE PIL Quote Link State"
{
    Caption = 'PIL-offertekoppelingstoestand';
    Extensible = false;

    value(0; Unknown)
    {
        Caption = 'Onbekend';
    }
    value(1; Current)
    {
        Caption = 'Actueel';
    }
    value(2; "Quote Missing")
    {
        Caption = 'Offerte ontbreekt';
    }
    value(3; "Quote Line Missing")
    {
        Caption = 'Offertregel ontbreekt';
    }
    value(4; "Item Line Changed")
    {
        Caption = 'Artikelregel gewijzigd';
    }
    value(5; "Text Changed")
    {
        Caption = 'Artikeltekst gewijzigd';
    }
    value(6; "Cannot Verify")
    {
        Caption = 'Niet controleerbaar';
    }
}
