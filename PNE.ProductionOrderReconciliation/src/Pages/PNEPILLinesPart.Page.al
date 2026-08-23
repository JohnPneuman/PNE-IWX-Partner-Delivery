namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;

page 50184 "PNE PIL Lines Part"
{
    ApplicationArea = All;
    Caption = 'Geïmporteerde AutoCAD-PIL — kies verwerking per regel';
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    PageType = ListPart;
    SourceTable = "PNE PIL Line";

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'AutoCAD-artikel';
                    ToolTip = 'Geeft het artikelnummer uit AutoCAD weer.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Artikelomschrijving';
                    ToolTip = 'Geeft de artikelomschrijving uit Business Central weer wanneer het artikel bestaat.';
                }
                field("Group Code"; Rec."Group Code")
                {
                    ApplicationArea = All;
                    Caption = 'PIL-groep';
                    ToolTip = 'Geeft de PIL-groep weer die dit artikel aan een CALC-placeholder koppelt.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    Caption = 'PIL-totaal';
                    ToolTip = 'Geeft het totale aantal uit de geïmporteerde PIL weer.';
                }
                field("Covered Quantity"; Rec."Covered Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Gedekt aantal';
                    ToolTip = 'Geeft het deel weer dat al door een hoger structureel artikel wordt vertegenwoordigd.';
                }
                field("Covered By Item No."; Rec."Covered By Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Gedekt door artikel';
                    ToolTip = 'Geeft het hogere structurele AutoCAD-artikel weer dat deze regel al vertegenwoordigt.';
                }
                field(Resolution; Rec.Resolution)
                {
                    ApplicationArea = All;
                    Caption = 'Beslissing';
                    ToolTip = 'Geeft duidelijk weer hoe deze AutoCAD-regel in de afstemming wordt gebruikt.';
                }
                field("Ignore for Reconciliation"; Rec."Ignore for Reconciliation")
                {
                    ApplicationArea = All;
                    Caption = 'Bewust negeren';
                    ToolTip = 'Geeft aan dat een ongekoppeld positief AutoCAD-artikel bewust niet op deze productieorder wordt verwerkt.';
                }
                field("Ignore Reason"; Rec."Ignore Reason")
                {
                    ApplicationArea = All;
                    Caption = 'Reden van negeren';
                    ToolTip = 'Geeft de vastgelegde reden weer waarom dit AutoCAD-artikel bewust is genegeerd.';
                }
                field("Ignored By"; Rec."Ignored By")
                {
                    ApplicationArea = All;
                    Caption = 'Genegeerd door';
                    ToolTip = 'Geeft aan wie deze bewuste uitzondering heeft vastgelegd.';
                }
                field("Ignored At"; Rec."Ignored At")
                {
                    ApplicationArea = All;
                    Caption = 'Genegeerd op';
                    ToolTip = 'Geeft aan wanneer deze bewuste uitzondering is vastgelegd.';
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(PNEAddDirectComponent)
            {
                ApplicationArea = All;
                Caption = 'Als echt los materiaal toevoegen';
                Enabled = CanAddDirectComponent;
                Image = Add;
                ToolTip = 'Gebruik dit alleen voor materiaal dat niet onder een bestaand puntartikel hoort. Bij meerdere geselecteerde regels kiest u één keer de productieregel en worden alle geselecteerde artikelen daar afzonderlijk als los materiaal voorgesteld; uren en andere BOM-regels worden hierdoor niet aangemaakt.';

                trigger OnAction()
                var
                    PNEPILHeader: Record "PNE PIL Header";
                    SelectedPNEPILLine: Record "PNE PIL Line";
                    ProdOrderLine: Record "Prod. Order Line";
                    PNEPILMgt: Codeunit "PNE PIL Mgt.";
                    PNEPILDestinationLookup: Page "PNE PIL Destination Lookup";
                begin
                    CurrPage.SetSelectionFilter(SelectedPNEPILLine);
                    if SelectedPNEPILLine.IsEmpty() then
                        exit;
                    PNEPILHeader.Get(Rec."Header Entry No.");
                    PNEPILDestinationLookup.SetProductionOrder(PNEPILHeader);
                    PNEPILDestinationLookup.LookupMode(true);
                    if PNEPILDestinationLookup.RunModal() <> Action::LookupOK then
                        exit;
                    PNEPILDestinationLookup.GetRecord(ProdOrderLine);
                    PNEPILMgt.AddSelectedPILLinesAsDirectComponents(SelectedPNEPILLine, ProdOrderLine);
                    CurrPage.Update(false);
                end;
            }
            action(PNEAddComponentUnderCarrier)
            {
                ApplicationArea = All;
                Caption = 'Puntartikel verhogen';
                Enabled = CanAddPointCarrier;
                Image = Hierarchy;
                ToolTip = 'Kies het puntartikel waaronder dit AutoCAD-artikel thuis hoort. Bestaat dat puntartikel al precies één keer, dan gebruikt de app automatisch die bestaande positie; alleen voor een nieuw of meervoudig puntartikel kiest u een productieregel. De BOM neemt de bijbehorende draden, uren en overige onderdelen mee.';

                trigger OnAction()
                var
                    PointCarrierItem: Record Item;
                    PNEPILHeader: Record "PNE PIL Header";
                    DestinationProdOrderLine: Record "Prod. Order Line";
                    PNEPILMgt: Codeunit "PNE PIL Mgt.";
                    PNEPILCarrierLookup: Page "PNE PIL Carrier Lookup";
                    PNEPILDestinationLookup: Page "PNE PIL Destination Lookup";
                begin
                    PNEPILHeader.Get(Rec."Header Entry No.");
                    PNEPILCarrierLookup.SetCandidates(PNEPILHeader, Rec."Item No.");
                    PNEPILCarrierLookup.LookupMode(true);
                    if PNEPILCarrierLookup.RunModal() <> Action::LookupOK then
                        exit;
                    PNEPILCarrierLookup.GetRecord(PointCarrierItem);
                    if PNEPILMgt.PointCarrierNeedsDestination(PNEPILHeader, PointCarrierItem) then begin
                        PNEPILDestinationLookup.SetProductionOrder(PNEPILHeader);
                        PNEPILDestinationLookup.SetPointCarrierContext(PointCarrierItem."No.");
                        PNEPILDestinationLookup.LookupMode(true);
                        if PNEPILDestinationLookup.RunModal() <> Action::LookupOK then
                            exit;
                        PNEPILDestinationLookup.GetRecord(DestinationProdOrderLine);
                    end;
                    if not PNEPILMgt.EnsurePointCarrierProductionBOMLink(
                         PNEPILHeader,
                         Rec."Item No.",
                         PointCarrierItem)
                    then
                        exit;
                    PNEPILMgt.AssignPILLineToPointCarrier(Rec, PointCarrierItem, DestinationProdOrderLine);
                    CurrPage.Update(false);
                end;
            }
            action(PNEIgnorePILLine)
            {
                ApplicationArea = All;
                Caption = 'Bewust negeren';
                Enabled = CanIgnore;
                Image = Stop;
                ToolTip = 'Gebruik dit alleen wanneer dit positieve, ongekoppelde AutoCAD-artikel echt niet bij deze productieorder hoort. U moet een reden vastleggen.';

                trigger OnAction()
                var
                    PNEPILMgt: Codeunit "PNE PIL Mgt.";
                    PNEPILReasonDialog: Page "PNE PIL Reason Dialog";
                begin
                    PNEPILReasonDialog.SetContext(IgnoreHeadingTxt, IgnoreInstructionsTxt);
                    if PNEPILReasonDialog.RunModal() <> Action::OK then
                        exit;
                    PNEPILMgt.SetPILLineIgnore(Rec, PNEPILReasonDialog.GetReason());
                    CurrPage.Update(false);
                end;
            }
            action(PNERestorePILLine)
            {
                ApplicationArea = All;
                Caption = 'Negeren herstellen';
                Enabled = CanRestoreIgnore;
                Image = Undo;
                ToolTip = 'Maakt een eerder bewust genegeerde AutoCAD-regel weer actief, zodat u hem kunt koppelen of verdelen.';

                trigger OnAction()
                var
                    PNEPILMgt: Codeunit "PNE PIL Mgt.";
                begin
                    PNEPILMgt.RestorePILLine(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    var
        PNEPILHeader: Record "PNE PIL Header";
    begin
        CanIgnore := false;
        CanRestoreIgnore := false;
        CanAddDirectComponent := false;
        CanAddPointCarrier := false;
        if not PNEPILHeader.Get(Rec."Header Entry No.") then
            exit;
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            exit;

        CanIgnore :=
            (Rec.Quantity > 0) and
            (Rec."Group Code" = '') and
            (Rec."Covered Quantity" = 0) and
            not Rec."Ignore for Reconciliation";
        CanAddPointCarrier :=
            (Rec.Quantity - Rec."Covered Quantity" > 0.00001) and
            (Rec."Group Code" = '') and
            not Rec."Ignore for Reconciliation";
        CanAddDirectComponent := CanAddPointCarrier;
        CanRestoreIgnore := Rec."Ignore for Reconciliation";
    end;

    trigger OnOpenPage()
    begin
        Rec.SetFilter(Quantity, '>%1', 0);
        Rec.SetFilter(Resolution, '%1|%2|%3|%4', '', NotUsedTxt, IgnoredByUserTxt, PartiallyCoveredTxt);
    end;

    var
        CanIgnore: Boolean;
        CanAddDirectComponent: Boolean;
        CanAddPointCarrier: Boolean;
        CanRestoreIgnore: Boolean;
        IgnoreHeadingTxt: Label 'AutoCAD-artikel bewust negeren';
        IgnoreInstructionsTxt: Label 'Gebruik dit uitsluitend wanneer dit positieve AutoCAD-artikel echt niet bij deze productieorder hoort. De reden wordt als audit vastgelegd; de app mag de regel daarna niet stilzwijgend alsnog verwerken.';
        IgnoredByUserTxt: Label 'Bewust genegeerd met reden';
        NotUsedTxt: Label 'Niet gebruikt op deze productieorder';
        PartiallyCoveredTxt: Label 'Gedeeltelijk gedekt; rest nog verwerken';
}
