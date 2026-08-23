namespace Pneuman.ProductionOrderReconciliation;

enum 50176 "PNE PIL Target Kind"
{
    Extensible = false;

    value(0; "CALC replacement") { Caption = 'CALC-vervanging'; }
    value(1; "Structural driver") { Caption = 'Structurele driver'; }
    value(2; "Direct component addition") { Caption = 'Los component toevoegen'; }
    value(3; "Point carrier addition") { Caption = 'Puntartikel toevoegen'; }
}
