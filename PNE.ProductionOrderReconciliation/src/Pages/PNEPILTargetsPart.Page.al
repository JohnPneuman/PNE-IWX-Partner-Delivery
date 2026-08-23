namespace Pneuman.ProductionOrderReconciliation;

page 50185 "PNE PIL Targets Part"
{
    ApplicationArea = All;
    Caption = 'Verdeling van AutoCAD-artikelen';
    Permissions = tabledata "PNE PIL Header" = m,
                  tabledata "PNE PIL Target" = m;
    InsertAllowed = false;
    DeleteAllowed = false;
    PageType = ListPart;
    SourceTable = "PNE PIL Target";

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("PIL Item No."; Rec."PIL Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'AutoCAD-artikel';
                    Editable = false;
                    ToolTip = 'Geeft het AutoCAD-artikel weer dat aan deze productiecarrier is gekoppeld.';
                }
                field("PIL Item Description"; Rec."PIL Item Description")
                {
                    ApplicationArea = All;
                    Caption = 'Artikelomschrijving';
                    Editable = false;
                    ToolTip = 'Geeft de omschrijving van het AutoCAD-artikel weer.';
                }
                field(Kind; Rec.Kind)
                {
                    ApplicationArea = All;
                    Caption = 'Route';
                    Editable = false;
                    ToolTip = 'Geeft aan of dit artikel een structurele carrier stuurt of een CALC-placeholder vervangt.';
                }
                field("Carrier Type"; Rec."Carrier Type")
                {
                    ApplicationArea = All;
                    Caption = 'Carriertype';
                    Editable = false;
                    ToolTip = 'Geeft aan of de carrier een aparte productieorderregel of een component op de huidige order is.';
                }
                field("Analysis Source"; Rec."Analysis Source")
                {
                    ApplicationArea = All;
                    Caption = 'Analysebron';
                    Editable = false;
                    ToolTip = 'Geeft aan of de carrier in de actuele productieorder is gevonden of alleen via een veilige, alleen-lezen master-BOM-analyse.';
                }
                field("Carrier Item No."; Rec."Carrier Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Carrier-artikel';
                    Editable = false;
                    ToolTip = 'Geeft de samengestelde carrier weer waarvan het aantal wordt aangepast.';
                }
                field("Carrier Description"; Rec."Carrier Description")
                {
                    ApplicationArea = All;
                    Caption = 'Carrieromschrijving';
                    Editable = false;
                    ToolTip = 'Geeft de omschrijving van de productiecarrier weer.';
                }
                field("New Point Carrier Item No."; Rec."New Point Carrier Item No.")
                {
                    ApplicationArea = All;
                    Caption = 'Toe te voegen puntartikel';
                    Editable = false;
                    ToolTip = 'Geeft het puntartikel weer dat als nieuwe onderliggende productieregel wordt toegevoegd.';
                }
                field("Carrier Component Line No."; Rec."Carrier Component Line No.")
                {
                    ApplicationArea = All;
                    Caption = 'Carrier-componentregel';
                    Editable = false;
                    ToolTip = 'Geeft het componentregelnnummer weer wanneer twee gelijke carriers onder dezelfde orderregel kunnen voorkomen.';
                }
                field("PIL Group Code"; Rec."PIL Group Code")
                {
                    ApplicationArea = All;
                    Caption = 'PIL-groep';
                    Editable = false;
                    ToolTip = 'Geeft de PIL-groep voor een eventuele CALC-vervanging weer.';
                }
                field("PIL Quantity"; Rec."PIL Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'PIL-totaal';
                    Editable = false;
                    ToolTip = 'Geeft het totale AutoCAD-aantal voor dit artikel weer.';
                }
                field("Allocated PIL Quantity"; Rec."Allocated PIL Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Naar deze carrier';
                    ToolTip = 'Geeft het aantal voor deze carrier weer. Bij één geldige carrier vult de app dit zelf; alleen bij meerdere carriers verdeelt u hier handmatig.';
                }
                field("Unallocated PIL Quantity"; Rec."Unallocated PIL Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Nog te verdelen';
                    Editable = false;
                    ToolTip = 'Geeft aan welk aantal van dit AutoCAD-artikel nog niet is verdeeld.';
                }
                field("Quantity per Carrier"; Rec."Quantity per Carrier")
                {
                    ApplicationArea = All;
                    Caption = 'Aantal per carrier';
                    Editable = false;
                    ToolTip = 'Geeft het huidige aantal van dit artikel of deze CALC-placeholder per carrier weer.';
                }
                field("Observed Live Qty. per Carrier"; Rec."Observed Live Qty. per Carrier")
                {
                    ApplicationArea = All;
                    Caption = 'Live gevonden per carrier';
                    Editable = false;
                    ToolTip = 'Geeft weer hoeveel de actuele productieorder fysiek per carrier bevat. Als dit door een oude en een nieuwe BOM-route dubbel wordt geteld, blijft het geldige BOM-recept leidend.';
                }
                field("Factor Reconciliation Note"; Rec."Factor Reconciliation Note")
                {
                    ApplicationArea = All;
                    Caption = 'Uitleg factor';
                    Editable = false;
                    ToolTip = 'Legt uit waarom de analyse eventueel het geldige BOM-recept gebruikt in plaats van een hoger, dubbel geteld live aantal.';
                }
                field("Original Carrier Quantity"; Rec."Original Carrier Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Huidig carrieraantal';
                    Editable = false;
                    ToolTip = 'Geeft het carrier-aantal vóór toepassing weer.';
                }
                field("New Carrier Quantity"; Rec."New Carrier Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Nieuw carrieraantal';
                    Editable = false;
                    ToolTip = 'Geeft het nieuwe carrier-aantal weer dat uit de PIL-verdeling is berekend.';
                }
                field("Driver Suggested Quantity"; Rec."Driver Suggested Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Driver vraagt';
                    Editable = false;
                    ToolTip = 'Geeft het carrieraantal weer dat deze afzonderlijke AutoCAD-driver berekent.';
                }
                field("Carrier Quantity Conflict"; Rec."Carrier Quantity Conflict")
                {
                    ApplicationArea = All;
                    Caption = 'Drivers verschillen';
                    Editable = false;
                    ToolTip = 'Geeft aan dat onafhankelijke drivers voor dezelfde carrier verschillende aantallen berekenen.';
                }
                field("Chosen Carrier Quantity"; Rec."Chosen Carrier Quantity")
                {
                    ApplicationArea = All;
                    Caption = 'Bewust gekozen aantal';
                    Editable = false;
                    ToolTip = 'Geeft het carrieraantal weer dat een gebruiker bewust heeft gekozen om een driverconflict op te lossen.';
                }
                field("Carrier Qty. Choice Reason"; Rec."Carrier Qty. Choice Reason")
                {
                    ApplicationArea = All;
                    Caption = 'Reden van keuze';
                    Editable = false;
                    ToolTip = 'Geeft de verplichte auditreden voor het bewust gekozen carrieraantal weer.';
                }
                field(Resolution; Rec.Resolution)
                {
                    ApplicationArea = All;
                    Caption = 'Verdeling';
                    Editable = false;
                    ToolTip = 'Geeft aan of de verdeling automatisch is bepaald of nog handmatige invoer nodig heeft.';
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(ChooseCarrierQuantity)
            {
                ApplicationArea = All;
                Caption = 'Kies carrieraantal';
                Enabled = Rec."Carrier Quantity Conflict";
                Visible = Rec."Carrier Quantity Conflict";
                Image = SelectLineToApply;
                ToolTip = 'Kies het definitieve carrieraantal wanneer onafhankelijke AutoCAD-drivers verschillende aantallen vragen. De keuze en reden worden vastgelegd.';

                trigger OnAction()
                var
                    PNEPILMgt: Codeunit "PNE PIL Mgt.";
                    PNEPILReasonDialog: Page "PNE PIL Reason Dialog";
                begin
                    PNEPILReasonDialog.SetQuantityContext(
                        StrSubstNo(ChooseCarrierQuantityHeadingTxt, Rec."Carrier Item No."),
                        StrSubstNo(
                            ChooseCarrierQuantityInstructionsTxt,
                            Rec."PIL Item No.",
                            Rec."Driver Suggested Quantity"),
                        Rec."Driver Suggested Quantity");
                    if PNEPILReasonDialog.RunModal() <> Action::OK then
                        exit;
                    PNEPILMgt.ChooseCarrierQuantity(
                        Rec,
                        PNEPILReasonDialog.GetQuantity(),
                        PNEPILReasonDialog.GetReason());
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        ChooseCarrierQuantityHeadingTxt: Label 'Kies definitief aantal voor carrier %1', Comment = '%1 = carrier item number';
        ChooseCarrierQuantityInstructionsTxt: Label 'De drivers voor deze carrier spreken elkaar tegen. De geselecteerde AutoCAD-driver %1 vraagt %2 carrier(s). Bevestig dit aantal of vul het juiste aantal in en leg kort uit waarom deze keuze leidend is.', Comment = '%1 = selected AutoCAD driver item number, %2 = suggested carrier quantity';
}
