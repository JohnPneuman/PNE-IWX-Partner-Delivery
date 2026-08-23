namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Manufacturing.Document;

pageextension 50188 "PNE Simulated Prod. Order PIL" extends "Simulated Production Order"
{
    actions
    {
        addlast("F&unctions")
        {
            action(PNEViewConfigurationStructure)
            {
                AccessByPermission = Page "PNE PO Configuration Structure" = X;
                ApplicationArea = All;
                Caption = 'BOM-stamstructuur';
                Image = Components;
                ToolTip = 'Toont alleen-lezen de stam-BOM en aantallen per bovenliggend BOM-onderdeel. Dit is geen actuele productiebehoefte of zaaglijst.';

                trigger OnAction()
                begin
                    OpenConfigurationStructure();
                end;
            }
            action(PNERecalculateRoutingHours)
            {
                AccessByPermission = codeunit "PNE PIL Mgt." = X;
                ApplicationArea = All;
                Caption = 'Routinguren opnieuw berekenen';
                Image = Calculate;
                ToolTip = 'Bouwt de actieve routinguren van het hoofdartikel opnieuw op uit alle actuele U.-componenten met een Routing Link Code in deze productieorder.';

                trigger OnAction()
                begin
                    RecalculateRoutingHours();
                end;
            }
            action(PNEImportAutoCADPIL)
            {
                AccessByPermission = codeunit "PNE PIL Import" = X;
                ApplicationArea = All;
                Caption = 'AutoCAD-PIL importeren';
                Image = Import;
                ToolTip = 'Importeert een headerloze AutoCAD-PIL en opent direct het afstemdossier voor deze gesimuleerde productieorder.';

                trigger OnAction()
                begin
                    OpenNewPILReconciliation();
                end;
            }
            action(PNEOpenPILReconciliations)
            {
                AccessByPermission = page "PNE PIL Reconciliations" = X;
                ApplicationArea = All;
                Caption = 'PIL-afstemmingen';
                Image = List;
                ToolTip = 'Toont alle AutoCAD-PIL-imports voor deze gesimuleerde productieorder.';

                trigger OnAction()
                begin
                    OpenPILReconciliations();
                end;
            }
        }
    }

    local procedure OpenNewPILReconciliation()
    var
        PNEPILHeader: Record "PNE PIL Header";
        PNEPILImport: Codeunit "PNE PIL Import";
        PNEPILReconciliation: Page "PNE PIL Reconciliation";
    begin
        PNEPILImport.ImportForProductionOrder(Rec, PNEPILHeader);
        if PNEPILHeader."Entry No." = 0 then
            exit;
        PNEPILReconciliation.SetRecord(PNEPILHeader);
        PNEPILReconciliation.Run();
    end;

    local procedure OpenConfigurationStructure()
    var
        PNEPOConfigStructureMgtCodeunit: Codeunit "PNE PO Config. Structure Mgt.";
    begin
        PNEPOConfigStructureMgtCodeunit.OpenForProductionOrder(Rec);
    end;

    local procedure OpenPILReconciliations()
    var
        PNEPILHeader: Record "PNE PIL Header";
        PNEPILReconciliations: Page "PNE PIL Reconciliations";
    begin
        PNEPILHeader.SetRange("Production Order Status", Rec.Status);
        PNEPILHeader.SetRange("Production Order No.", Rec."No.");
        PNEPILReconciliations.SetTableView(PNEPILHeader);
        PNEPILReconciliations.Run();
    end;

    local procedure RecalculateRoutingHours()
    var
        PNEPILMgt: Codeunit "PNE PIL Mgt.";
    begin
        PNEPILMgt.RecalculateOrderRoutingHours(Rec);
        CurrPage.Update(false);
    end;
}
