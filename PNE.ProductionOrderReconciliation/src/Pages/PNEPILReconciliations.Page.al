namespace Pneuman.ProductionOrderReconciliation;

page 50182 "PNE PIL Reconciliations"
{
    ApplicationArea = All;
    Caption = 'Productieorder-PIL-afstemmingen';
    CardPageId = "PNE PIL Reconciliation";
    DeleteAllowed = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = "PNE PIL Header";
    UsageCategory = History;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Geeft het unieke nummer van deze PIL-import weer.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Geeft aan in welke stap deze PIL-afstemming zich bevindt.';
                }
                field("Production Order Status"; Rec."Production Order Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Geeft de status van de gekoppelde productieorder weer.';
                }
                field("Production Order No."; Rec."Production Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Geeft de productieorder weer waarvoor deze AutoCAD-PIL is geïmporteerd.';
                }
                field("Source File Name"; Rec."Source File Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Geeft de naam van het geïmporteerde AutoCAD-PIL-bestand weer.';
                }
                field("Created At"; Rec."Created At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Geeft aan wanneer de PIL is geïmporteerd.';
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Geeft aan wie de PIL heeft geïmporteerd.';
                }
                field("Applied At"; Rec."Applied At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Geeft aan wanneer de PIL op de productieorder is toegepast.';
                }
                field("Applied By"; Rec."Applied By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Geeft aan wie de PIL heeft toegepast.';
                }
            }
        }
    }
}
