namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Manufacturing.Document;

page 50200 "PNE PIL Destination Lookup"
{
    ApplicationArea = All;
    Caption = 'Kies werkgebied in de productieorder';
    Editable = false;
    PageType = List;
    SourceTable = "Prod. Order Line";
    SourceTableTemporary = true;
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    Caption = 'Regelnummer';
                    ToolTip = 'Geeft het regelnummer binnen de productieorder weer.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Productieartikel';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Werkgebied / positie in productieorder';
                    ToolTip = 'Toont onder welk bestaand productieartikel deze productieregel valt. Kies bijvoorbeeld de bedrading-, paneel- of kastsubconfiguratie waar het nieuwe materiaal of puntartikel werkelijk bij hoort.';
                }
                field(PointCarrierAlreadyHere; PointCarrierAlreadyHere)
                {
                    ApplicationArea = All;
                    Caption = 'Gekozen puntartikel staat hier al';
                    ToolTip = 'Geeft aan dat het gekozen puntartikel al als component onder deze werkregel staat. Kies bij meerdere voorkomens de regel die bij het juiste werkgebied of de juiste subconfiguratie hoort.';
                    Visible = PointCarrierContextActive;
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    Caption = 'Aantal';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    Caption = 'Eenheid';
                }
                field("Starting Date"; Rec."Starting Date")
                {
                    ApplicationArea = All;
                    Caption = 'Geplande start';
                    ToolTip = 'Het nieuwe puntartikel wordt vóór deze startdatum benodigd en wordt vanaf deze gekozen productieregel teruggepland.';
                }
                field("Due Date"; Rec."Due Date")
                {
                    ApplicationArea = All;
                    Caption = 'Uiterste datum werkgebied';
                    ToolTip = 'Geeft de uiterste datum van het gekozen werkgebied weer.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        PointCarrierAlreadyHere := false;
        if not PointCarrierContextActive then
            exit;

        ProdOrderComponent.SetRange(Status, Rec.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", Rec."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", Rec."Line No.");
        ProdOrderComponent.SetRange("Item No.", PointCarrierItemNo);
        PointCarrierAlreadyHere := not ProdOrderComponent.IsEmpty();
    end;

    procedure SetProductionOrder(PNEPILHeader: Record "PNE PIL Header")
    var
        TempProdOrderLine: Record "Prod. Order Line" temporary;
        PNEPILMgt: Codeunit "PNE PIL Mgt.";
    begin
        PNEPILMgt.GetDirectComponentDestinationLines(PNEPILHeader, TempProdOrderLine);
        if TempProdOrderLine.FindSet() then
            repeat
                Rec := TempProdOrderLine;
                Rec.Insert();
            until TempProdOrderLine.Next() = 0;
    end;

    procedure SetPointCarrierContext(NewPointCarrierItemNo: Code[20])
    begin
        PointCarrierItemNo := NewPointCarrierItemNo;
        PointCarrierContextActive := PointCarrierItemNo <> '';
    end;

    var
        PointCarrierItemNo: Code[20];
        PointCarrierAlreadyHere: Boolean;
        PointCarrierContextActive: Boolean;
}
