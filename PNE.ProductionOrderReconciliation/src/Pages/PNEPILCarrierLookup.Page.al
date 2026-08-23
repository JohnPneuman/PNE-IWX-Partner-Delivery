namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Inventory.Item;

page 50201 "PNE PIL Carrier Lookup"
{
    ApplicationArea = All;
    Caption = 'Kies passend puntartikel';
    Editable = false;
    PageType = List;
    SourceTable = Item;
    SourceTableTemporary = true;
    UsageCategory = None;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Caption = 'Puntartikel';
                    ToolTip = 'Geeft een puntartikel weer waarvan de gecertificeerde Production BOM dit AutoCAD-artikel bevat.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Omschrijving';
                    ToolTip = 'Geeft de omschrijving van het bestaande puntartikel weer.';
                }
                field("Production BOM No."; Rec."Production BOM No.")
                {
                    ApplicationArea = All;
                    Caption = 'Production BOM';
                    ToolTip = 'Geeft de Production BOM weer die samen met het puntartikel wordt toegevoegd.';
                }
                field(PNEProductionBOMLinkStatus; ProductionBOMLinkStatusTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Koppelstatus';
                    ToolTip = 'Geeft aan of de Production BOM-koppeling gereed is of na uw bevestiging door dezelfde actie wordt hersteld.';
                }
                field("Base Unit of Measure"; Rec."Base Unit of Measure")
                {
                    ApplicationArea = All;
                    Caption = 'Eenheid';
                    ToolTip = 'Geeft de eenheid van het puntartikel weer.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        PNEPILMgt: Codeunit "PNE PIL Mgt.";
    begin
        ProductionBOMLinkStatusTxt := PNEPILMgt.GetPointCarrierLinkStatus(
            CurrentPNEPILHeader,
            CurrentPILItemNo,
            Rec);
    end;

    procedure SetCandidates(PNEPILHeader: Record "PNE PIL Header"; PILItemNo: Code[20])
    var
        TempItem: Record Item temporary;
        PNEPILMgt: Codeunit "PNE PIL Mgt.";
    begin
        CurrentPNEPILHeader := PNEPILHeader;
        CurrentPILItemNo := PILItemNo;
        PNEPILMgt.GetMatchingPointCarrierItems(PNEPILHeader, PILItemNo, TempItem);
        if TempItem.IsEmpty() then
            Error(PNEPILMgt.GetPointCarrierLookupFailure(PNEPILHeader, PILItemNo));
        LoadCandidates(TempItem);
    end;

    local procedure LoadCandidates(var TempItem: Record Item temporary)
    begin
        Rec.DeleteAll();
        if TempItem.FindSet() then
            repeat
                Rec := TempItem;
                Rec.Insert();
            until TempItem.Next() = 0;
    end;

    var
        CurrentPNEPILHeader: Record "PNE PIL Header";
        CurrentPILItemNo: Code[20];
        ProductionBOMLinkStatusTxt: Text;

}
