namespace Pneuman.ProductionOrderReconciliation;

page 50180 "PNE PIL Groups"
{
    ApplicationArea = All;
    Caption = 'PIL-inrichting';
    PageType = List;
    SourceTable = "PNE PIL Group";
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                    Caption = 'Code';
                    ToolTip = 'Geeft de korte code van deze PIL-groep weer.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Omschrijving';
                    ToolTip = 'Geeft een herkenbare omschrijving van deze PIL-groep weer.';
                }
                field("CALC Item No."; Rec."CALC Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'CALC-placeholderartikel';
                    ToolTip = 'Geeft het CALC-placeholderartikel weer dat bij een losse PIL-regel door echte artikelen wordt vervangen.';
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    Caption = 'Ingeschakeld';
                    ToolTip = 'Geeft aan of deze groep bij nieuwe PIL-imports mag worden gebruikt.';
                }
                field("Active Item Count"; Rec."Active Item Count")
                {
                    ApplicationArea = All;
                    Caption = 'Aantal actieve artikelen';
                    ToolTip = 'Geeft het aantal actieve echte artikelen weer dat bij de laatste kostprijsberekening is gebruikt.';
                }
                field("Used Cost Sum"; Rec."Used Cost Sum")
                {
                    ApplicationArea = All;
                    Caption = 'Som kostprijzen';
                    ToolTip = 'Geeft de som van de kostprijzen weer die bij de laatste berekening is gebruikt.';
                }
                field("Average Unit Cost"; Rec."Average Unit Cost")
                {
                    ApplicationArea = All;
                    Caption = 'Gemiddelde kostprijs';
                    ToolTip = 'Geeft de gemiddelde kostprijs weer die in het CALC-placeholderartikel is gezet.';
                }
                field("Last Cost Recalculated At"; Rec."Last Cost Recalculated At")
                {
                    ApplicationArea = All;
                    Caption = 'Kostprijs herberekend op';
                    ToolTip = 'Geeft aan wanneer de CALC-kostprijs voor het laatst is herberekend.';
                }
            }
        }
    }

    actions
    {
        area(navigation)
        {
            action(PNEPILGroupItems)
            {
                ApplicationArea = All;
                Caption = 'PIL-artikelen';
                Image = Item;
                ToolTip = 'Opent de echte AutoCAD-artikelen die de CALC-placeholder van deze groep mogen vervangen. Artikelen die alleen via een bovenliggende assemblage worden herkend, hoeven hier niet in.';

                trigger OnAction()
                var
                    PNEPILGroupItem: Record "PNE PIL Group Item";
                    PNEPILGroupItems: Page "PNE PIL Group Items";
                begin
                    PNEPILGroupItem.SetRange("Group Code", Rec.Code);
                    PNEPILGroupItems.SetTableView(PNEPILGroupItem);
                    PNEPILGroupItems.Run();
                end;
            }
        }
        area(processing)
        {
            action(PNERecalculateCALCCost)
            {
                ApplicationArea = All;
                Caption = 'CALC-kostprijs herberekenen';
                Image = CalculateCost;
                ToolTip = 'Toont eerst het gemiddelde van de actieve echte artikelen. Pas na bevestiging wordt die kostprijs op de CALC-placeholder gezet.';

                trigger OnAction()
                var
                    PNEPILCostMgt: Codeunit "PNE PIL Cost Mgt.";
                    WarningText: Text;
                begin
                    if PNEPILCostMgt.RecalculateGroupCost(Rec, WarningText) then begin
                        if WarningText <> '' then
                            Message(CostCalculatedWithWarningsMsg, WarningText)
                        else
                            Message(CostCalculatedMsg);
                        CurrPage.Update(false);
                    end;
                end;
            }
        }
    }

    var
        CostCalculatedMsg: Label 'De kostprijs van de CALC-placeholder is herberekend.';
        CostCalculatedWithWarningsMsg: Label 'De kostprijs van de CALC-placeholder is herberekend. Controleer deze waarschuwingen:\%1', Comment = '%1 = one or more warnings';
}
