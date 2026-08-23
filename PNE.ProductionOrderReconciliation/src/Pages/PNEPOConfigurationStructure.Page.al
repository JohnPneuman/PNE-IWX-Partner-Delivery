namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Manufacturing.ProductionBOM;

page 50198 "PNE PO Configuration Structure"
{
    ApplicationArea = All;
    Caption = 'BOM-stamstructuur (geen actuele behoefte)';
    DeleteAllowed = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = "Production BOM Line";
    SourceTableTemporary = true;
    SourceTableView = sorting("Production BOM No.", "Version Code", "Line No.");
    UsageCategory = None;

    layout
    {
        area(content)
        {
            group(Overview)
            {
                Caption = 'Overzicht';

                field(ProductionOrder; ProductionOrderTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Productieorder';
                    Editable = false;
                    ToolTip = 'Geeft de productieorder weer waarvoor deze bestaande configuratiestructuur wordt getoond.';
                }
                field(MainBOMSource; MainBOMSourceTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Hoofd-BOM / versie';
                    Editable = false;
                    ToolTip = 'Geeft de op de productieorderregel vastgelegde hoofd-BOM en versie weer. Bij meerdere hoofdregels staat de eerste hier; de volledige structuur staat hieronder.';
                }
                field(StructureSource; StructureSourceTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Bron';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Legt uit welke bestaande Production BOM-gegevens voor dit alleen-lezen overzicht worden gebruikt.';
                }
            }
            repeater(Structure)
            {
                ShowCaption = false;

                field(NodeType; NodeTypeTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Soort';
                    Editable = false;
                    ToolTip = 'Geeft aan of de regel het hoofdartikel, een onderliggende BOM, een artikel of een melding is.';
                }
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Caption = 'Artikel-/BOM-nr.';
                    ToolTip = 'Geeft het bestaande artikelnummer of Production BOM-nummer weer.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Structuur';
                    StyleExpr = LineStyleTxt;
                    ToolTip = 'Toont het onderdeel met inspringing, zodat zichtbaar is welke artikelen onder welke bestaande BOM horen.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    Caption = 'BOM-aantal per bovenliggend onderdeel';
                    ToolTip = 'Geeft het aantal uit de stam-BOM per bovenliggend BOM-onderdeel weer. Dit is geen actuele productiebehoefte, zaaglengte of ordertotaal.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    Caption = 'Eenheid';
                    ToolTip = 'Geeft de bestaande eenheid van het onderdeel weer.';
                }
                field("Routing Link Code"; Rec."Routing Link Code")
                {
                    ApplicationArea = All;
                    Caption = 'Routing-link';
                    ToolTip = 'Geeft de bestaande Routing Link Code weer. Een lege waarde betekent dat deze BOM-regel zelf geen directe routingskoppeling heeft.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        SetLinePresentation();
    end;

    procedure SetStructure(var TempProductionBOMLine: Record "Production BOM Line" temporary; NewProductionOrderTxt: Text[250]; NewMainBOMSourceTxt: Text[250]; NewStructureSourceTxt: Text[250])
    begin
        Rec.Copy(TempProductionBOMLine, true);
        ProductionOrderTxt := NewProductionOrderTxt;
        MainBOMSourceTxt := NewMainBOMSourceTxt;
        StructureSourceTxt := NewStructureSourceTxt;
    end;

    local procedure SetLinePresentation()
    begin
        NodeTypeTxt := ItemRoleTxt;
        LineStyleTxt := '';

        case Rec.Position of
            RootRoleTok:
                begin
                    NodeTypeTxt := RootRoleTxt;
                    LineStyleTxt := StrongStyleTok;
                end;
            BOMRoleTok:
                begin
                    NodeTypeTxt := BOMRoleTxt;
                    LineStyleTxt := StrongStyleTok;
                end;
            InformationRoleTok:
                begin
                    NodeTypeTxt := InformationRoleTxt;
                    LineStyleTxt := AttentionStyleTok;
                end;
        end;
    end;

    var
        AttentionStyleTok: Label 'Attention', Locked = true;
        BOMRoleTok: Label 'BOM', Locked = true;
        BOMRoleTxt: Label 'Onderdeel-BOM';
        InformationRoleTok: Label 'INFO', Locked = true;
        InformationRoleTxt: Label 'Melding';
        ItemRoleTxt: Label 'Artikel';
        LineStyleTxt: Text[30];
        MainBOMSourceTxt: Text[250];
        NodeTypeTxt: Text[30];
        ProductionOrderTxt: Text[250];
        RootRoleTok: Label 'ROOT', Locked = true;
        RootRoleTxt: Label 'Hoofdartikel';
        StrongStyleTok: Label 'Strong', Locked = true;
        StructureSourceTxt: Text[250];
}
