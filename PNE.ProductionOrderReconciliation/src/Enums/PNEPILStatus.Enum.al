namespace Pneuman.ProductionOrderReconciliation;

enum 50175 "PNE PIL Status"
{
    Extensible = false;

    value(0; Imported) { Caption = 'Geïmporteerd'; }
    value(1; "Allocation Required") { Caption = 'Verdeling nodig'; }
    value(2; Prepared) { Caption = 'Gereed om toe te passen'; }
    value(3; Applied) { Caption = 'Toegepast'; }
}
