namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Sales.Document;

page 50183 "PNE PIL Reconciliation"
{
    ApplicationArea = All;
    Caption = 'Productieorder-PIL-afstemming';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = Document;
    SourceTable = "PNE PIL Header";
    UsageCategory = Tasks;

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'PIL-import';
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    Caption = 'Dossiernr.';
                    Editable = false;
                    ToolTip = 'Geeft het unieke nummer van deze PIL-import weer.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Caption = 'Stap';
                    Editable = false;
                    ToolTip = 'Geeft aan in welke stap deze PIL-afstemming zich bevindt.';
                }
                field("Production Order Status"; Rec."Production Order Status")
                {
                    ApplicationArea = All;
                    Caption = 'Productieorderstatus';
                    Editable = false;
                    ToolTip = 'Geeft de status van de gekoppelde productieorder weer.';
                }
                field("Production Order No."; Rec."Production Order No.")
                {
                    ApplicationArea = All;
                    Caption = 'Productieordernr.';
                    Editable = false;
                    ToolTip = 'Geeft de productieorder weer waarop deze PIL wordt toegepast.';
                }
                field("Source File Name"; Rec."Source File Name")
                {
                    ApplicationArea = All;
                    Caption = 'Bronbestand';
                    Editable = false;
                    ToolTip = 'Geeft het geïmporteerde AutoCAD-PIL-bestand weer.';
                }
                field("Created At"; Rec."Created At")
                {
                    ApplicationArea = All;
                    Caption = 'Geïmporteerd op';
                    Editable = false;
                    ToolTip = 'Geeft aan wanneer de PIL is geïmporteerd.';
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    Caption = 'Geïmporteerd door';
                    Editable = false;
                    ToolTip = 'Geeft aan wie de PIL heeft geïmporteerd.';
                }
                field("Applied At"; Rec."Applied At")
                {
                    ApplicationArea = All;
                    Caption = 'Toegepast op';
                    Editable = false;
                    ToolTip = 'Geeft aan wanneer de PIL op de productieorder is toegepast.';
                }
                field("Applied By"; Rec."Applied By")
                {
                    ApplicationArea = All;
                    Caption = 'Toegepast door';
                    Editable = false;
                    ToolTip = 'Geeft aan wie de PIL heeft toegepast.';
                }
            }
            group(NextStep)
            {
                Caption = 'Volgende stap';

                field(NextStepText; NextStepText)
                {
                    ApplicationArea = All;
                    Editable = false;
                    MultiLine = true;
                    ShowCaption = false;
                    Style = Strong;
                    ToolTip = 'Legt uit wat u nu moet doen om deze PIL-afstemming af te ronden.';
                }
                field(SafetyNoticeText; SafetyNoticeText)
                {
                    ApplicationArea = All;
                    Editable = false;
                    MultiLine = true;
                    ShowCaption = false;
                    Style = Attention;
                    ToolTip = 'Geeft een aandachtspunt weer dat eerst moet worden opgelost.';
                }
            }
            part(PNEPILLines; "PNE PIL Lines Part")
            {
                ApplicationArea = All;
                Caption = '1. Geïmporteerde AutoCAD-PIL';
                SubPageLink = "Header Entry No." = field("Entry No.");
            }
            part(PNEPILTargets; "PNE PIL Targets Part")
            {
                ApplicationArea = All;
                Caption = '2. Verdeling over productiecarriers';
                SubPageLink = "Header Entry No." = field("Entry No.");
            }
            part(PNEPILChangeLines; "PNE PIL Change Lines Part")
            {
                ApplicationArea = All;
                Caption = '3. Voorgestelde productie- en commerciële wijzigingen';
                SubPageLink = "Header Entry No." = field("Entry No.");
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(PNEPreparePIL)
            {
                ApplicationArea = All;
                Caption = 'Stap 1 - Analyseer PIL';
                Enabled = CanPrepare;
                Visible = CanPrepare;
                Image = Calculate;
                ToolTip = 'Zoekt automatisch naar de juiste productiecarrier, herkent bovenliggende assemblages en maakt een veilig wijzigingsvoorstel.';

                trigger OnAction()
                var
                    PNEPILMgt: Codeunit "PNE PIL Mgt.";
                begin
                    PNEPILMgt.Prepare(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(PNERepreparePIL)
            {
                ApplicationArea = All;
                Caption = 'Analyseer opnieuw';
                Enabled = CanReprepare;
                Visible = CanReprepare;
                Image = Refresh;
                ToolTip = 'Maakt het voorstel opnieuw op basis van de huidige productieorder. Handmatige verdelingen worden opnieuw opgebouwd.';

                trigger OnAction()
                var
                    PNEPILMgt: Codeunit "PNE PIL Mgt.";
                begin
                    if not Confirm(ReprepareQst, false) then
                        exit;
                    PNEPILMgt.Prepare(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(PNECheckAllocation)
            {
                ApplicationArea = All;
                Caption = 'Stap 2 - Controleer verdeling';
                Enabled = CanCheckAllocation;
                Visible = CanCheckAllocation;
                Image = CheckList;
                ToolTip = 'Controleert of alle AutoCAD-aantallen volledig en veilig zijn verdeeld en werkt het voorstel bij.';

                trigger OnAction()
                var
                    PNEPILMgt: Codeunit "PNE PIL Mgt.";
                    AllocationStatusMessage: Text;
                begin
                    PNEPILMgt.CheckAllocations(Rec);
                    if Rec.Status = Rec.Status::"Allocation Required" then begin
                        AllocationStatusMessage := PNEPILMgt.GetAllocationStatusMessage(Rec);
                        Message(AllocationStatusMessage);
                    end else
                        Message(AllocationReadyMsg);
                    CurrPage.Update(false);
                end;
            }
            action(PNEPrintChangeProposal)
            {
                ApplicationArea = All;
                Caption = 'Stap 3 - Bekijk wijzigingsvoorstel';
                Image = PrintReport;
                Visible = CanPrintProposal;
                ToolTip = 'Toont of drukt het complete technische en commerciële voorstel af. Deze actie verandert niets.';

                trigger OnAction()
                var
                    PNEPILChangeProposal: Report "PNE PIL Change Proposal";
                begin
                    Rec.SetRecFilter();
                    PNEPILChangeProposal.SetTableView(Rec);
                    PNEPILChangeProposal.RunModal();
                end;
            }
            action(PNEAddNetChangesToSalesQuote)
            {
                AccessByPermission = tabledata "Sales Line" = I;
                ApplicationArea = All;
                Caption = 'Meer- en minderwerk naar bestaande offerte';
                Enabled = CanAddToSalesQuote;
                Visible = CanAddToSalesQuote;
                Image = Quote;
                ToolTip = 'Groepeert de oorspronkelijke en definitieve carrieraantallen per artikel, variant en eenheid en voegt alleen het netto meer- of minderwerk als nieuwe regels toe aan een open bestaande offerte. Toepasselijke standaard artikeltekst komt mee wanneer Automatische uitgebreide teksten op het artikel aanstaat. Bestaande offertregels worden nooit gewijzigd.';

                trigger OnAction()
                var
                    PNEPILSalesQuoteMgt: Codeunit "PNE PIL Sales Quote Mgt.";
                    SalesQuoteNo: Code[20];
                begin
                    if PNEPILSalesQuoteMgt.AddNetChangesToSelectedSalesQuote(Rec, SalesQuoteNo) then begin
                        if Rec.Status = Rec.Status::Prepared then
                            Message(AddedToQuoteBeforeApplyMsg, SalesQuoteNo)
                        else
                            Message(AddedToQuoteMsg, SalesQuoteNo);
                        CurrPage.Update(false);
                        if Confirm(OpenSalesQuoteQst, false, SalesQuoteNo) then
                            PNEPILSalesQuoteMgt.OpenSalesQuote(SalesQuoteNo);
                    end;
                end;
            }
            action(PNEReverseSalesQuoteHandoff)
            {
                AccessByPermission = tabledata "Sales Line" = D;
                ApplicationArea = All;
                Caption = 'Offerteoverdracht terugdraaien';
                Enabled = CanReverseSalesQuoteHandoff;
                Visible = CanReverseSalesQuoteHandoff;
                Image = Undo;
                ToolTip = 'Verwijdert alleen de nog ongewijzigde offertregels en gekoppelde tekstregels die deze PIL zelf heeft toegevoegd. Geef altijd een reden op.';

                trigger OnAction()
                var
                    PNEPILSalesQuoteMgt: Codeunit "PNE PIL Sales Quote Mgt.";
                    PNEPILReasonDialog: Page "PNE PIL Reason Dialog";
                begin
                    PNEPILReasonDialog.SetContext(ReverseQuoteHeadingTxt, ReverseQuoteInstructionsTxt);
                    if PNEPILReasonDialog.RunModal() <> Action::OK then
                        exit;
                    if PNEPILSalesQuoteMgt.ReverseActiveQuoteHandoff(Rec, PNEPILReasonDialog.GetReason()) then
                        Message(QuoteHandoffReversedMsg);
                    CurrPage.Update(false);
                end;
            }
            action(PNEReleaseSalesQuoteHandoff)
            {
                ApplicationArea = All;
                Caption = 'Commerciële koppeling vrijgeven';
                Enabled = CanReleaseSalesQuoteHandoff;
                Visible = CanReleaseSalesQuoteHandoff;
                Image = UnLinkAccount;
                ToolTip = 'Legt met verplichte reden vast dat de gekoppelde offerte handmatig commercieel is beoordeeld. De app wijzigt niets in verkoop, maar een technisch nog actueel voorstel kan daarna worden toegepast. Dezelfde wijziging kan niet nogmaals automatisch naar een offerte.';

                trigger OnAction()
                var
                    PNEPILSalesQuoteMgt: Codeunit "PNE PIL Sales Quote Mgt.";
                    PNEPILReasonDialog: Page "PNE PIL Reason Dialog";
                begin
                    PNEPILReasonDialog.SetContext(ReleaseQuoteHeadingTxt, ReleaseQuoteInstructionsTxt);
                    if PNEPILReasonDialog.RunModal() <> Action::OK then
                        exit;
                    if PNEPILSalesQuoteMgt.ReleaseActiveQuoteHandoff(Rec, PNEPILReasonDialog.GetReason()) then
                        Message(QuoteHandoffReleasedMsg);
                    CurrPage.Update(false);
                end;
            }
            action(PNEApplyPIL)
            {
                ApplicationArea = All;
                Caption = 'Stap 4 - Pas veilig toe';
                Enabled = CanApply;
                Visible = CanApply;
                Image = Apply;
                ToolTip = 'Past het gecontroleerde voorstel toe: verhoogt de productiecarrier en vervangt daarna de juiste CALC-regels door echte artikelen.';

                trigger OnAction()
                var
                    PNEPILMgt: Codeunit "PNE PIL Mgt.";
                    ImpactSummary: Text;
                    RoutingImpactSummary: Text;
                    NoProductionChanges: Boolean;
                begin
                    ImpactSummary := PNEPILMgt.GetApplyImpactSummary(Rec);
                    NoProductionChanges := PNEPILMgt.HasNoProductionChanges(Rec);
                    if NoProductionChanges then begin
                        if not Confirm(ApplyNoChangesQst, false) then
                            exit;
                    end else
                        if Rec."Production Order Status" = Rec."Production Order Status"::Released then begin
                        if not Confirm(ApplyReleasedQst, false, Rec."Production Order No.", ImpactSummary) then
                            exit;
                        end else
                        if not Confirm(ApplyQst, false, Rec."Production Order No.", ImpactSummary) then
                            exit;
                    PNEPILMgt.Apply(Rec, RoutingImpactSummary);
                    if NoProductionChanges then
                        Message(ApplyNoChangesSucceededMsg, Rec."Production Order No.")
                    else
                        Message(ApplySucceededMsg, Rec."Production Order No.", RoutingImpactSummary);
                    CurrPage.Close();
                end;
            }
        }
        area(navigation)
        {
            action(PNEPILSetup)
            {
                AccessByPermission = tabledata "PNE PIL Group" = M;
                ApplicationArea = All;
                Caption = 'PIL-inrichting';
                Image = Setup;
                RunObject = page "PNE PIL Groups";
                ToolTip = 'Opent de inrichting met PIL-groepen, CALC-placeholders en echte AutoCAD-artikelen.';
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        SetWorkflowState();
    end;

    local procedure SetWorkflowState()
    var
        PNEPILMgt: Codeunit "PNE PIL Mgt.";
        PNEPILSalesQuoteMgt: Codeunit "PNE PIL Sales Quote Mgt.";
        HasActiveQuoteHandoff: Boolean;
        HasCommerciallyLockedHandoff: Boolean;
        HasReleasedQuoteHandoff: Boolean;
        NoProductionChanges: Boolean;
    begin
        PNEPILSalesQuoteMgt.GetQuoteHandoffState(
            Rec,
            HasActiveQuoteHandoff,
            HasCommerciallyLockedHandoff,
            HasReleasedQuoteHandoff);
        NoProductionChanges := PNEPILMgt.HasNoProductionChanges(Rec);
        CanPrepare := Rec.Status = Rec.Status::Imported;
        CanReprepare :=
            (Rec.Status in [Rec.Status::"Allocation Required", Rec.Status::Prepared]) and
            not HasCommerciallyLockedHandoff;
        CanCheckAllocation := Rec.Status = Rec.Status::"Allocation Required";
        CanPrintProposal := Rec.Status in [Rec.Status::Prepared, Rec.Status::Applied];
        CanAddToSalesQuote := false;
        if (Rec.Status in [Rec.Status::Prepared, Rec.Status::Applied]) and
           not NoProductionChanges and
           not HasCommerciallyLockedHandoff
        then
            CanAddToSalesQuote := PNEPILSalesQuoteMgt.GetQuotableNetChangeCount(Rec) > 0;
        CanApply := Rec.Status = Rec.Status::Prepared;
        CanReverseSalesQuoteHandoff :=
            (Rec.Status = Rec.Status::Prepared) and HasActiveQuoteHandoff;
        CanReleaseSalesQuoteHandoff :=
            (Rec.Status in [Rec.Status::Prepared, Rec.Status::Applied]) and HasActiveQuoteHandoff;
        Clear(SafetyNoticeText);

        if HasReleasedQuoteHandoff then
            SafetyNoticeText := ReleasedQuoteSafetyNoticeTxt;

        case Rec.Status of
            Rec.Status::Imported:
                NextStepText := ImportedNextStepTxt;
            Rec.Status::"Allocation Required":
                NextStepText := GetAllocationNextStepText(Rec);
            Rec.Status::Prepared:
                if NoProductionChanges then
                    NextStepText := PreparedNoChangesNextStepTxt
                else
                    NextStepText := PreparedNextStepTxt;
            Rec.Status::Applied:
                NextStepText := AppliedNextStepTxt;
        end;
    end;

    local procedure GetAllocationNextStepText(PNEPILHeader: Record "PNE PIL Header"): Text[500]
    var
        PNEPILMgt: Codeunit "PNE PIL Mgt.";
    begin
        if PNEPILMgt.HasBlockingPositivePILLines(PNEPILHeader) then
            exit(UnmappedNextStepTxt);
        exit(AllocationNextStepTxt);
    end;

    var
        CanAddToSalesQuote: Boolean;
        CanApply: Boolean;
        CanCheckAllocation: Boolean;
        CanPrepare: Boolean;
        CanPrintProposal: Boolean;
        CanReprepare: Boolean;
        CanReleaseSalesQuoteHandoff: Boolean;
        CanReverseSalesQuoteHandoff: Boolean;
        NextStepText: Text[500];
        SafetyNoticeText: Text[500];
        AddedToQuoteBeforeApplyMsg: Label 'Het netto meer- en minderwerk is toegevoegd aan offerte %1. Kies nu eerst ''Pas veilig toe''. Wijzig de aangemaakte offertregel, prijs en offerte tot dat moment niet. Controleer daarna de verkoopprijzen, bedragen en tekst.', Comment = '%1 = sales quote number';
        AddedToQuoteMsg: Label 'Het netto meer- en minderwerk is als nieuwe regels toegevoegd aan offerte %1. Toepasselijke standaard artikelteksten staan met het netto aantal onder de nieuwe regels. Controleer de verkoopprijzen, bedragen en tekst.', Comment = '%1 = offerte number';
        AllocationNextStepTxt: Label 'Stap 2 van 4: controleer de voorgestelde verdeling. Vul alleen waar nodig ''Naar deze carrier'' in en kies daarna ''Controleer verdeling''.';
        AllocationReadyMsg: Label 'Alle aantallen zijn verdeeld. Bekijk het voorstel en kies daarna eerst ''Pas veilig toe''. Zet vervolgens het netto meer- en minderwerk op de bestaande offerte.';
        AppliedNextStepTxt: Label 'Afgerond: deze PIL is veilig toegepast. Open het wijzigingsvoorstel als auditdossier of zet het netto meer- en minderwerk op een bestaande offerte.';
        ApplyNoChangesQst: Label 'Deze PIL is al volledig in de huidige productieorder verwerkt of bevat alleen bewust genegeerde regels. De productieorder wordt niet opnieuw gewijzigd; het dossier wordt alleen als compleet vastgelegd. Doorgaan?';
        ApplyNoChangesSucceededMsg: Label 'De PIL voor productieorder %1 is zonder nieuwe productieorderwijzigingen als compleet vastgelegd. Het dossier blijft beschikbaar via PIL-afstemmingen.', Comment = '%1 = production order number';
        ApplyQst: Label 'Het voorstel wordt nu toegepast op productieorder %1.\%2\De app controleert vlak vóór de wijziging opnieuw op verbruik, reserveringen en andere risico''s. Doorgaan?', Comment = '%1 = productieorder number, %2 = impact summary';
        ApplyReleasedQst: Label 'Productieorder %1 is vrijgegeven.\%2\Het gecontroleerde voorstel wordt alleen toegepast als er geen verbruik, reserveringen, journaalwerk of routing-risico is. Doorgaan?', Comment = '%1 = productieorder number, %2 = impact summary';
        ApplySucceededMsg: Label 'De PIL is veilig toegepast op productieorder %1.\Routingcontrole per geproduceerd hoofdartikel:\%2\U keert nu terug naar de bijgewerkte productieorder. Het toegepaste dossier blijft beschikbaar via PIL-afstemmingen.', Comment = '%1 = production order number, %2 = routing impact summary';
        ImportedNextStepTxt: Label 'Stap 1 van 4: kies ''Analyseer PIL''. De app zoekt daarna automatisch de hoogste passende productiecarrier en maakt een voorstel.';
        OpenSalesQuoteQst: Label 'Offerte %1 nu openen?', Comment = '%1 = offerte number';
        PreparedNextStepTxt: Label 'Stap 3 van 4: bekijk het wijzigingsvoorstel en kies eerst ''Pas veilig toe''. Zet daarna het netto meer- en minderwerk op een bestaande offerte. Wilt u toch eerst offreren, dan waarschuwt de app voor de juiste volgorde.';
        PreparedNoChangesNextStepTxt: Label 'Deze PIL is al volledig in de productieorder verwerkt of bevat alleen bewust genegeerde regels. Kies ''Pas veilig toe'' om het dossier zonder dubbele wijzigingen als compleet vast te leggen.';
        QuoteHandoffReversedMsg: Label 'De offerteoverdracht is teruggedraaid. Alleen de nog ongewijzigde artikel- en gekoppelde tekstregels die door deze PIL zijn toegevoegd, zijn verwijderd. U kunt nu de juiste offerte kiezen.';
        QuoteHandoffReleasedMsg: Label 'De commerciële koppeling is met reden vrijgegeven. Er is niets in verkoop gewijzigd. Een technisch nog actueel voorstel kan nu veilig worden toegepast; dezelfde wijziging wordt niet nogmaals automatisch naar een offerte gestuurd.';
        ReleaseQuoteHeadingTxt: Label 'Commerciële koppeling vrijgeven';
        ReleaseQuoteInstructionsTxt: Label 'Gebruik dit alleen nadat de offerte of vervolgorder handmatig commercieel is gecontroleerd. De app verwijdert of wijzigt niets in verkoop. De reden, gebruiker, tijd en aangetroffen koppelingstoestand blijven in het auditdossier staan.';
        ReleasedQuoteSafetyNoticeTxt: Label 'De oorspronkelijke offerte-koppeling is handmatig commercieel vrijgegeven. Controleer de vastgelegde reden in het wijzigingsvoorstel. Er wordt niets meer automatisch naar een offerte gestuurd.';
        ReprepareQst: Label 'De analyse wordt opnieuw opgebouwd op basis van de huidige productieorder. Bestaande handmatige verdelingen worden vervangen. Doorgaan?';
        ReverseQuoteHeadingTxt: Label 'Offerteoverdracht terugdraaien';
        ReverseQuoteInstructionsTxt: Label 'Deze actie verwijdert uitsluitend de nog ongewijzigde artikel- en gekoppelde tekstregels die deze PIL zelf heeft toegevoegd. Geef een duidelijke reden op; deze wordt in het auditdossier bewaard.';
        UnmappedNextStepTxt: Label 'Stap 2 van 4: selecteer in ''Geïmporteerde AutoCAD-PIL'' eerst iedere regel met beslissing ''Niet gebruikt''. Kies ''Als los component toevoegen'', ''Onder puntartikel toevoegen'', maak zo nodig een PIL-koppeling, of negeer alleen een artikel dat echt niet bij deze order hoort. Kies daarna ''Controleer verdeling''.';
}
