namespace Pneuman.ProductionOrderReconciliation;

page 50181 "PNE PIL Group Items"
{
    ApplicationArea = All;
    Caption = 'PIL-groepsartikelen';
    PageType = List;
    SourceTable = "PNE PIL Group Item";
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Group Code"; Rec."Group Code")
                {
                    ApplicationArea = All;
                    Caption = 'PIL-groep';
                    ToolTip = 'Geeft de PIL-groep weer waartoe dit AutoCAD-artikel behoort.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Artikelnummer';
                    ToolTip = 'Geeft het echte voorraadartikel weer dat een losse AutoCAD-regel voor deze groep mag vervangen. Artikelen die alleen via een bovenliggende assemblage worden herkend, hoeven hier niet in.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Omschrijving';
                    ToolTip = 'Geeft de omschrijving uit de artikelkaart weer.';
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    Caption = 'Ingeschakeld';
                    ToolTip = 'Geeft aan of dit artikel bij nieuwe PIL-imports mag worden gebruikt.';
                }
            }
        }
    }
}
