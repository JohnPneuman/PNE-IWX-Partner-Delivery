namespace Pneuman.ProductionOrderReconciliation;

page 50195 "PNE PIL Change Lines Part"
{
    ApplicationArea = All;
    Caption = 'Voorgestelde productie- en commerciële wijzigingen';
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    PageType = ListPart;
    SourceTable = "PNE PIL Change Line";

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Carrier Item No."; Rec."Carrier Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Carrier-artikel';
                    ToolTip = 'Geeft aan welk samengesteld productieartikel door de PIL wijzigt.';
                }
                field("Carrier Component Line No."; Rec."Carrier Component Line No.")
                {
                    ApplicationArea = All;
                    Caption = 'Carrier-componentregel';
                    ToolTip = 'Geeft alleen onderscheid wanneer hetzelfde carrier-artikel meer dan één keer onder dezelfde productieorderregel voorkomt.';
                }
                field("Carrier Variant Code"; Rec."Carrier Variant Code")
                {
                    ApplicationArea = All;
                    Caption = 'Carrier-variantcode';
                    ToolTip = 'Geeft de variantcode van het carrier-artikel aan, als die van toepassing is.';
                }
                field("Carrier Description"; Rec."Carrier Description")
                {
                    ApplicationArea = All;
                    Caption = 'Carrier-omschrijving';
                    ToolTip = 'Geeft de omschrijving van het productieartikel dat wordt verhoogd of verlaagd.';
                }
                field("PIL Details"; Rec."PIL Details")
                {
                    ApplicationArea = All;
                    Caption = 'AutoCAD-artikelen';
                    ToolTip = 'Geeft per AutoCAD-artikel de controleberekening weer: verdeeld PIL-aantal / aantal per carrier = gevraagd carrieraantal.';
                }
                field("Original Quantity"; Rec."Original Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Huidig aantal';
                    ToolTip = 'Geeft het aantal op de productieorder vóór toepassing van de PIL weer.';
                }
                field("Proposed Quantity"; Rec."Proposed Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Voorgesteld aantal';
                    ToolTip = 'Geeft het nieuwe aantal weer dat de app uit de gecontroleerde PIL voorstelt.';
                }
                field("Quantity Difference"; Rec."Quantity Difference")
                {
                    ApplicationArea = All;
                    Caption = 'Verschil';
                    ToolTip = 'Geeft de verhoging of verlaging per technische carrierregel weer. Bij offerteoverdracht groepeert de app gelijke artikelen en gebruikt zij alleen het netto verschil tussen de totale oorspronkelijke en definitieve hoeveelheid.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    Caption = 'Eenheid';
                    ToolTip = 'Geeft de eenheid van het carrier-artikel weer.';
                }
                field("Carrier Unit Cost"; Rec."Carrier Unit Cost")
                {
                    ApplicationArea = All;
                    Caption = 'Kostprijs per eenheid';
                    ToolTip = 'Geeft de huidige kostprijs op de productieorder weer. Dit is een technische kostenindicatie, geen verkoopprijs.';
                }
                field("Estimated Cost Difference"; Rec."Estimated Cost Difference")
                {
                    ApplicationArea = All;
                    Caption = 'Geschat kostenverschil';
                    ToolTip = 'Geeft de technische kostenindicatie van het verschil weer. Dit is geen verkoopprijs en verandert geen offerteprijs.';
                }
                field("Sales Quote No."; Rec."Sales Quote No.")
                {
                    ApplicationArea = All;
                    DrillDown = true;
                    Caption = 'Offertenr.';
                    ToolTip = 'Geeft de offerte weer waaraan deze technische wijziging als onderdeel van een netto meer- of minderwerkregel is gekoppeld. Meerdere regels kunnen bewust naar dezelfde samengevoegde offertregel wijzen.';

                    trigger OnDrillDown()
                    var
                        PNEPILSalesQuoteMgt: Codeunit "PNE PIL Sales Quote Mgt.";
                    begin
                        if Rec."Quote Reversed" then
                            Message(QuoteReversedMsg)
                        else
                            if Rec."Sales Quote No." <> '' then
                            PNEPILSalesQuoteMgt.OpenSalesQuote(Rec."Sales Quote No.");
                    end;
                }
                field("Sales Quote Line No."; Rec."Sales Quote Line No.")
                {
                    ApplicationArea = All;
                    Caption = 'Offertregelnr.';
                    ToolTip = 'Geeft het regelnummer van de door deze PIL aangemaakte offertregel weer.';
                }
                field("Quote Line Description"; Rec."Quote Line Description")
                {
                    ApplicationArea = All;
                    Caption = 'Offerte-regelomschrijving';
                    ToolTip = 'Geeft de omschrijving weer zoals die op de aangemaakte offertregel stond. Deze wordt gecontroleerd voordat de app een overdracht terugdraait.';
                }
                field("Quote Unit Price"; Rec."Quote Unit Price")
                {
                    ApplicationArea = All;
                    Caption = 'Offerteprijs per eenheid';
                    ToolTip = 'Geeft de standaard Business Central-verkoopprijs weer die op de aangemaakte offertregel is vastgelegd.';
                }
                field("Quote Line Amount"; Rec."Quote Line Amount")
                {
                    ApplicationArea = All;
                    Caption = 'Offerte-regelbedrag';
                    ToolTip = 'Geeft het bedrag weer dat op de aangemaakte offertregel is vastgelegd.';
                }
                field("Quote Reversed"; Rec."Quote Reversed")
                {
                    ApplicationArea = All;
                    Caption = 'Offerte-overdracht teruggedraaid';
                    ToolTip = 'Geeft aan dat de door dit PIL-dossier aangemaakte offertregel gecontroleerd is verwijderd. De reden staat in de audit van het wijzigingsvoorstel.';
                }
                field("Quote Reversal Entry No."; Rec."Quote Reversal Entry No.")
                {
                    ApplicationArea = All;
                    Caption = 'Terugdraai-auditnr.';
                    ToolTip = 'Geeft het onveranderbare auditnummer van de teruggedraaide offerte-overdracht weer.';
                }
            }
        }
    }

    var
        QuoteReversedMsg: Label 'Deze offerte-overdracht is teruggedraaid. Kies opnieuw een offerte via de actie op het PIL-dossier als deze wijziging alsnog commercieel moet worden verwerkt.';
}
