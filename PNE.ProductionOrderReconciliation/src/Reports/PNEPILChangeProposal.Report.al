namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Foundation.Company;
using Microsoft.Manufacturing.Document;

report 50196 "PNE PIL Change Proposal"
{
    ApplicationArea = All;
    Caption = 'PIL-wijzigingsvoorstel';
    DefaultRenderingLayout = PILChangeProposalWord;
    UsageCategory = None;

    dataset
    {
        dataitem(PNEPILHeader; "PNE PIL Header")
        {
            DataItemTableView = sorting("Entry No.");
            RequestFilterFields = "Entry No.", "Production Order Status", "Production Order No.", Status;

            column(CompanyName; CompanyName) { }
            column(DocumentTitle; DocumentTitleLbl) { }
            column(ReportDate; ReportDateText) { }
            column(ReportTime; ReportTimeText) { }
            column(HeaderEntryNo; "Entry No.") { }
            column(ProductionOrderStatus; "Production Order Status") { }
            column(ProductionOrderNo; "Production Order No.") { }
            column(ReconciliationStatus; Status) { }
            column(SourceFileName; "Source File Name") { }
            column(CreatedAt; "Created At") { }
            column(CreatedBy; "Created By") { }
            column(PreparedAt; "Prepared At") { }
            column(AppliedAt; "Applied At") { }
            column(AppliedBy; "Applied By") { }
            column(TechnicalReviewStatus; TechnicalReviewStatusText) { }
            column(CommercialReviewStatus; CommercialReviewStatusText) { }
            column(TotalPILItemCount; TotalPILItemCount) { }
            column(TotalPILQuantity; TotalPILQuantity) { }
            column(CoveredPILItemCount; CoveredPILItemCount) { }
            column(CoveredPILQuantity; CoveredPILQuantity) { }
            column(ChangeLineCount; ChangeLineCount) { }
            column(PositiveChangeLineCount; PositiveChangeLineCount) { }
            column(UnquotedPositiveChangeLineCount; UnquotedPositiveChangeLineCount) { }
            column(CommercialChangeLineCount; CommercialChangeLineCount) { }
            column(UnquotedCommercialChangeLineCount; UnquotedCommercialChangeLineCount) { }
            column(ReversedQuoteLineCount; ReversedQuoteLineCount) { }
            column(TotalEstimatedCostDifference; TotalEstimatedCostDifference) { }
            column(QuoteSummary; QuoteSummaryText) { }

            dataitem(PNEPILChangeLine; "PNE PIL Change Line")
            {
                DataItemLink = "Header Entry No." = field("Entry No.");
                DataItemTableView = sorting("Header Entry No.", "Line No.");

                column(ChangeLineNo; "Line No.") { }
                column(ChangeCarrierType; "Carrier Type") { }
                column(ChangeCarrierStatus; "Carrier Status") { }
                column(ChangeCarrierProductionOrderNo; "Carrier Production Order No.") { }
                column(ChangeCarrierOrderLineNo; "Carrier Order Line No.") { }
                column(ChangeCarrierComponentLineNo; "Carrier Component Line No.") { }
                column(ChangeCarrierItemNo; "Carrier Item No.") { }
                column(ChangeCarrierVariantCode; "Carrier Variant Code") { }
                column(ChangeCarrierIdentity; ChangeCarrierIdentityText) { }
                column(ChangeCarrierDescription; "Carrier Description") { }
                column(ChangeUnitOfMeasureCode; "Unit of Measure Code") { }
                column(ChangeOriginalQuantity; "Original Quantity") { }
                column(ChangeProposedQuantity; "Proposed Quantity") { }
                column(ChangeQuantityDifference; "Quantity Difference") { }
                column(ChangeCarrierUnitCost; "Carrier Unit Cost") { }
                column(ChangeEstimatedCostDifference; "Estimated Cost Difference") { }
                column(ChangePILDetails; "PIL Details") { }
                column(ChangeSalesQuoteNo; "Sales Quote No.") { }
                column(ChangeSalesQuoteLineNo; "Sales Quote Line No.") { }
                column(ChangeSalesQuoteLineSystemId; "Sales Quote Line SystemId") { }
                column(ChangeSalesQuoteLineModifiedAt; "Sales Quote Line Modified At") { }
                column(ChangeQuoteUnitPrice; "Quote Unit Price") { }
                column(ChangeQuoteLineAmount; "Quote Line Amount") { }
                column(ChangeQuoteCurrencyCode; "Quote Currency Code") { }
                column(ChangeQuoteAddedAt; "Quote Added At") { }
                column(ChangeQuoteAddedBy; "Quote Added By") { }
                column(ChangeQuoteLineDescription; "Quote Line Description") { }
                column(ChangeQuoteReversed; "Quote Reversed") { }
                column(ChangeQuoteReversalEntryNo; "Quote Reversal Entry No.") { }
                column(ChangeCommercialStatus; ChangeCommercialStatusText) { }

                trigger OnAfterGetRecord()
                begin
                    ChangeCommercialStatusText := GetChangeCommercialStatus(PNEPILChangeLine);
                    ChangeCarrierIdentityText := GetCarrierIdentity(
                        PNEPILChangeLine."Carrier Status",
                        PNEPILChangeLine."Carrier Production Order No.",
                        PNEPILChangeLine."Carrier Order Line No.",
                        PNEPILChangeLine."Carrier Component Line No.",
                        PNEPILChangeLine."Carrier Variant Code",
                        PNEPILChangeLine."Unit of Measure Code");
                end;
            }
            dataitem(PNEPILTarget; "PNE PIL Target")
            {
                DataItemLink = "Header Entry No." = field("Entry No.");
                DataItemTableView = sorting("Header Entry No.", "Line No.");

                column(TargetLineNo; "Line No.") { }
                column(TargetPILItemNo; "PIL Item No.") { }
                column(TargetPILItemDescription; "PIL Item Description") { }
                column(TargetPILGroupCode; "PIL Group Code") { }
                column(TargetPILQuantity; "PIL Quantity") { }
                column(TargetAllocatedPILQuantity; "Allocated PIL Quantity") { }
                column(TargetUnallocatedPILQuantity; "Unallocated PIL Quantity") { }
                column(TargetKind; Kind) { }
                column(TargetCarrierType; "Carrier Type") { }
                column(TargetCarrierStatus; "Carrier Status") { }
                column(TargetCarrierProductionOrderNo; "Carrier Production Order No.") { }
                column(TargetCarrierOrderLineNo; "Carrier Order Line No.") { }
                column(TargetCarrierComponentLineNo; "Carrier Component Line No.") { }
                column(TargetCarrierItemNo; "Carrier Item No.") { }
                column(TargetCarrierVariantCode; "Carrier Variant Code") { }
                column(TargetCarrierUnitOfMeasureCode; "Carrier Unit of Measure Code") { }
                column(TargetCarrierIdentity; TargetCarrierIdentityText) { }
                column(TargetCarrierDescription; "Carrier Description") { }
                column(TargetAnalysisSource; "Analysis Source") { }
                column(TargetOriginalCarrierQuantity; "Original Carrier Quantity") { }
                column(TargetNewCarrierQuantity; "New Carrier Quantity") { }
                column(TargetDriverSuggestedQuantity; "Driver Suggested Quantity") { }
                column(TargetCarrierQuantityConflict; "Carrier Quantity Conflict") { }
                column(TargetCarrierQuantityChoiceActive; "Carrier Qty. Choice Active") { }
                column(TargetChosenCarrierQuantity; "Chosen Carrier Quantity") { }
                column(TargetCarrierQuantityChoiceReason; "Carrier Qty. Choice Reason") { }
                column(TargetCarrierQuantityChosenBy; "Carrier Qty. Chosen By") { }
                column(TargetCarrierQuantityChosenAt; "Carrier Qty. Chosen At") { }
                column(TargetCarrierQuantityDecision; TargetCarrierQuantityDecisionText) { }
                column(TargetAllocationResolution; Resolution) { }

                trigger OnAfterGetRecord()
                begin
                    TargetCarrierIdentityText := GetCarrierIdentity(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.",
                        PNEPILTarget."Carrier Component Line No.",
                        PNEPILTarget."Carrier Variant Code",
                        PNEPILTarget."Carrier Unit of Measure Code");
                    TargetCarrierQuantityDecisionText := GetCarrierQuantityDecision(PNEPILTarget);
                end;
            }
            dataitem(PNEPILIgnoredLine; "PNE PIL Line")
            {
                DataItemLink = "Header Entry No." = field("Entry No.");
                DataItemTableView = sorting("Header Entry No.", "Line No.") where("Ignore for Reconciliation" = const(true));

                column(IgnoredPILItemNo; "Item No.") { }
                column(IgnoredPILDescription; Description) { }
                column(IgnoredPILGroupCode; "Group Code") { }
                column(IgnoredPILQuantity; Quantity) { }
                column(IgnoredForReconciliation; "Ignore for Reconciliation") { }
                column(IgnoredReason; "Ignore Reason") { }
                column(IgnoredBy; "Ignored By") { }
                column(IgnoredAt; "Ignored At") { }
            }
            dataitem(PNEPILQuoteReversal; "PNE PIL Quote Reversal")
            {
                DataItemLink = "Header Entry No." = field("Entry No.");
                DataItemTableView = sorting("Entry No.");

                column(ReversalEntryNo; "Entry No.") { }
                column(ReversalChangeLineNo; "Change Line No.") { }
                column(ReversalSalesQuoteNo; "Sales Quote No.") { }
                column(ReversalSalesQuoteLineNo; "Sales Quote Line No.") { }
                column(ReversalSalesQuoteLineSystemId; "Sales Quote Line SystemId") { }
                column(ReversalSalesQuoteLineModifiedAt; "Sales Quote Line Modified At") { }
                column(ReversalCarrierItemNo; "Carrier Item No.") { }
                column(ReversalCarrierVariantCode; "Carrier Variant Code") { }
                column(ReversalUnitOfMeasureCode; "Unit of Measure Code") { }
                column(ReversalQuantity; Quantity) { }
                column(ReversalQuoteLineDescription; "Quote Line Description") { }
                column(ReversalQuoteUnitPrice; "Quote Unit Price") { }
                column(ReversalQuoteLineAmount; "Quote Line Amount") { }
                column(ReversalQuoteCurrencyCode; "Quote Currency Code") { }
                column(ReversalReason; "Reversal Reason") { }
                column(ReversedAt; "Reversed At") { }
                column(ReversedBy; "Reversed By") { }
            }

            trigger OnAfterGetRecord()
            begin
                CalculateHeaderSummary(PNEPILHeader);
            end;
        }
    }

    rendering
    {
        layout(PILChangeProposalWord)
        {
            Type = Word;
            LayoutFile = 'Layouts/PNEPILChangeProposal.docx';
            Caption = 'PIL-wijzigingsvoorstel';
            Summary = 'Duidelijk productie- en commercieel wijzigingsvoorstel uit een AutoCAD-PIL, inclusief carrierhoeveelheden, kostenindicatie en offerte-overdracht.';
        }
    }

    trigger OnPreReport()
    var
        CurrentDateTimeValue: DateTime;
    begin
        if CompanyInformation.Get() then
            CompanyName := CompanyInformation.Name;

        CurrentDateTimeValue := CurrentDateTime();
        ReportDateText := Format(DT2Date(CurrentDateTimeValue), 0, '<Day,2>-<Month,2>-<Year4>');
        ReportTimeText := Format(DT2Time(CurrentDateTimeValue), 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>');
    end;

    local procedure CalculateHeaderSummary(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        PNEPILLine: Record "PNE PIL Line";
        PNEPILSalesQuoteMgt: Codeunit "PNE PIL Sales Quote Mgt.";
        CurrentQuoteLineKeys: Dictionary of [Text, Boolean];
        ReversedQuoteLineKeys: Dictionary of [Text, Boolean];
        QuoteLineKey: Text;
        QuoteLineIsCurrent: Boolean;
        QuoteCount: Integer;
    begin
        Clear(TotalPILItemCount);
        Clear(TotalPILQuantity);
        Clear(CoveredPILItemCount);
        Clear(CoveredPILQuantity);
        Clear(ChangeLineCount);
        Clear(PositiveChangeLineCount);
        Clear(UnquotedPositiveChangeLineCount);
        Clear(CommercialChangeLineCount);
        Clear(UnquotedCommercialChangeLineCount);
        Clear(ReversedQuoteLineCount);
        Clear(TotalEstimatedCostDifference);
        Clear(QuoteSummaryText);
        Clear(QuoteLinkCurrentCache);
        Clear(QuoteLinkVerificationCache);

        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet() then
            repeat
                TotalPILItemCount += 1;
                TotalPILQuantity += PNEPILLine.Quantity;
                if PNEPILLine."Covered Quantity" > 0 then begin
                    CoveredPILItemCount += 1;
                    CoveredPILQuantity += PNEPILLine."Covered Quantity";
                end;
            until PNEPILLine.Next() = 0;

        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILChangeLine.FindSet() then
            repeat
                ChangeLineCount += 1;
                TotalEstimatedCostDifference += PNEPILChangeLine."Estimated Cost Difference";
                if (PNEPILChangeLine."Quantity Difference" > 0) and
                   not PNEPILSalesQuoteMgt.IsDirectComponentChangeLine(PNEPILChangeLine)
                then
                    PositiveChangeLineCount += 1;
                if (Abs(PNEPILChangeLine."Quantity Difference") > QuantityTolerance()) and
                   not PNEPILSalesQuoteMgt.IsDirectComponentChangeLine(PNEPILChangeLine)
                then
                    if PNEPILChangeLine."Quote Reversed" then begin
                        QuoteLineKey := GetQuoteLineKey(PNEPILChangeLine);
                        if not ReversedQuoteLineKeys.ContainsKey(QuoteLineKey) then
                            ReversedQuoteLineKeys.Add(QuoteLineKey, true);
                        if PNEPILChangeLine."Quantity Difference" > 0 then
                            UnquotedPositiveChangeLineCount += 1;
                    end else
                        if GetCachedQuoteLineStatus(PNEPILSalesQuoteMgt, PNEPILChangeLine, QuoteLineIsCurrent) then begin
                            if QuoteLineIsCurrent then begin
                                QuoteLineKey := GetQuoteLineKey(PNEPILChangeLine);
                                if not CurrentQuoteLineKeys.ContainsKey(QuoteLineKey) then begin
                                    CurrentQuoteLineKeys.Add(QuoteLineKey, true);
                                    QuoteCount += 1;
                                end;
                            end else
                                if PNEPILChangeLine."Quantity Difference" > 0 then
                                    UnquotedPositiveChangeLineCount += 1;
                        end else
                            if PNEPILChangeLine."Quantity Difference" > 0 then
                                UnquotedPositiveChangeLineCount += 1;
            until PNEPILChangeLine.Next() = 0;

        CommercialChangeLineCount := PNEPILSalesQuoteMgt.GetQuotableNetChangeCount(PNEPILHeader);
        UnquotedCommercialChangeLineCount := CommercialChangeLineCount - CurrentQuoteLineKeys.Count();
        if UnquotedCommercialChangeLineCount < 0 then
            UnquotedCommercialChangeLineCount := 0;
        ReversedQuoteLineCount := ReversedQuoteLineKeys.Count();
        TechnicalReviewStatusText := GetTechnicalReviewStatus(PNEPILHeader);
        CommercialReviewStatusText := GetCommercialReviewStatus(CommercialChangeLineCount, UnquotedCommercialChangeLineCount, ReversedQuoteLineCount);
        QuoteSummaryText := GetQuoteSummary(QuoteCount, CommercialChangeLineCount, UnquotedCommercialChangeLineCount, ReversedQuoteLineCount);
    end;

    local procedure GetTechnicalReviewStatus(PNEPILHeader: Record "PNE PIL Header"): Text[100]
    begin
        case PNEPILHeader.Status of
            PNEPILHeader.Status::Imported:
                exit(ImportNotPreparedTxt);
            PNEPILHeader.Status::"Allocation Required":
                exit(AllocationRequiredTxt);
            PNEPILHeader.Status::Prepared:
                exit(PreparedForApplyTxt);
            PNEPILHeader.Status::Applied:
                exit(AppliedTxt);
        end;
    end;

    local procedure GetCommercialReviewStatus(CommercialLineCount: Integer; UnquotedCommercialLineCount: Integer; ReversedLineCount: Integer): Text[100]
    begin
        if CommercialLineCount = 0 then
            exit(NoCommercialChangeTxt);
        if ReversedLineCount > 0 then
            exit(ReversedQuoteReviewTxt);
        if UnquotedCommercialLineCount = 0 then
            exit(AllCommercialChangesQuotedTxt);
        if UnquotedCommercialLineCount = CommercialLineCount then
            exit(NoCommercialChangesQuotedTxt);
        exit(SomeCommercialChangesUnquotedTxt);
    end;

    local procedure GetQuoteSummary(QuoteCount: Integer; CommercialLineCount: Integer; UnquotedCommercialLineCount: Integer; ReversedLineCount: Integer): Text[100]
    begin
        if CommercialLineCount = 0 then
            exit(NoQuoteRequiredTxt);
        if ReversedLineCount > 0 then
            exit(CopyStr(StrSubstNo(ReversedQuoteLinesTxt, ReversedLineCount, UnquotedCommercialLineCount), 1, 100));
        if QuoteCount = 0 then
            exit(NoQuoteLinesTxt);
        if UnquotedCommercialLineCount = 0 then
            exit(AllQuoteLinesTxt);
        exit(CopyStr(StrSubstNo(QuotedAndUnquotedLinesTxt, QuoteCount, UnquotedCommercialLineCount), 1, 100));
    end;

    local procedure GetChangeCommercialStatus(PNEPILChangeLine: Record "PNE PIL Change Line"): Text[100]
    var
        PNEPILSalesQuoteMgt: Codeunit "PNE PIL Sales Quote Mgt.";
        QuoteLineIsCurrent: Boolean;
    begin
        if PNEPILSalesQuoteMgt.IsDirectComponentChangeLine(PNEPILChangeLine) then
            exit(CopyStr(DirectComponentCommercialReviewTxt, 1, 100));
        if Abs(PNEPILChangeLine."Quantity Difference") <= QuantityTolerance() then
            exit(NoCommercialDifferenceTxt);
        if Abs(PNEPILSalesQuoteMgt.GetCommercialGroupNetQuantity(PNEPILChangeLine)) <= QuantityTolerance() then
            exit(NetCommercialGroupZeroTxt);
        if PNEPILChangeLine."Quote Reversed" then
            exit(QuoteReversedTxt);
        if PNEPILChangeLine."Sales Quote No." = '' then
            exit(NotAddedToQuoteTxt);
        if not GetCachedQuoteLineStatus(PNEPILSalesQuoteMgt, PNEPILChangeLine, QuoteLineIsCurrent) then
            exit(QuoteLinkCannotBeVerifiedTxt);
        if not QuoteLineIsCurrent then
            exit(QuoteLinkNeedsReviewTxt);
        exit(StrSubstNo(AddedToQuoteTxt, PNEPILChangeLine."Sales Quote No.", PNEPILChangeLine."Sales Quote Line No."));
    end;

    local procedure GetQuoteLineKey(PNEPILChangeLine: Record "PNE PIL Change Line"): Text
    begin
        exit(PNEPILChangeLine."Sales Quote No." + '|' + Format(PNEPILChangeLine."Sales Quote Line No."));
    end;

    local procedure GetCachedQuoteLineStatus(PNEPILSalesQuoteMgt: Codeunit "PNE PIL Sales Quote Mgt."; PNEPILChangeLine: Record "PNE PIL Change Line"; var QuoteLineIsCurrent: Boolean): Boolean
    var
        QuoteLineKey: Text;
        QuoteLineCanBeVerified: Boolean;
    begin
        QuoteLineKey := GetQuoteLineKey(PNEPILChangeLine);
        if QuoteLinkVerificationCache.Get(QuoteLineKey, QuoteLineCanBeVerified) then begin
            QuoteLinkCurrentCache.Get(QuoteLineKey, QuoteLineIsCurrent);
            exit(QuoteLineCanBeVerified);
        end;

        Clear(QuoteLineIsCurrent);
        QuoteLineCanBeVerified := TryIsCurrentQuoteLine(PNEPILSalesQuoteMgt, PNEPILChangeLine, QuoteLineIsCurrent);
        QuoteLinkVerificationCache.Add(QuoteLineKey, QuoteLineCanBeVerified);
        QuoteLinkCurrentCache.Add(QuoteLineKey, QuoteLineIsCurrent);
        exit(QuoteLineCanBeVerified);
    end;

    local procedure QuantityTolerance(): Decimal
    begin
        exit(0.00001);
    end;

    local procedure GetCarrierIdentity(CarrierStatus: Enum "Production Order Status"; CarrierProductionOrderNo: Code[20]; CarrierOrderLineNo: Integer; CarrierComponentLineNo: Integer; CarrierVariantCode: Code[10]; CarrierUnitOfMeasureCode: Code[10]): Text[250]
    var
        CarrierIdentity: Text[250];
    begin
        CarrierIdentity := StrSubstNo(CarrierIdentityStartLbl, Format(CarrierStatus), CarrierProductionOrderNo, CarrierOrderLineNo);
        if CarrierComponentLineNo <> 0 then
            CarrierIdentity += StrSubstNo(CarrierIdentityComponentLbl, CarrierComponentLineNo);
        if CarrierVariantCode <> '' then
            CarrierIdentity += StrSubstNo(CarrierIdentityVariantLbl, CarrierVariantCode);
        if CarrierUnitOfMeasureCode <> '' then
            CarrierIdentity += StrSubstNo(CarrierIdentityUnitOfMeasureLbl, CarrierUnitOfMeasureCode);
        exit(CarrierIdentity);
    end;

    local procedure GetCarrierQuantityDecision(PNEPILTarget: Record "PNE PIL Target"): Text[250]
    begin
        if PNEPILTarget."Carrier Qty. Choice Active" then
            exit(CopyStr(
                StrSubstNo(
                    CarrierQuantityChosenTxt,
                    PNEPILTarget."Chosen Carrier Quantity",
                    PNEPILTarget."Carrier Qty. Chosen By",
                    PNEPILTarget."Carrier Qty. Chosen At",
                    PNEPILTarget."Carrier Qty. Choice Reason"),
                1,
                MaxStrLen(TargetCarrierQuantityDecisionText)));

        if PNEPILTarget."Carrier Quantity Conflict" then
            exit(CopyStr(
                StrSubstNo(CarrierQuantityConflictTxt, PNEPILTarget."Driver Suggested Quantity"),
                1,
                MaxStrLen(TargetCarrierQuantityDecisionText)));

        if PNEPILTarget."Driver Suggested Quantity" > 0 then
            exit(CopyStr(
                StrSubstNo(CarrierQuantitySuggestedTxt, PNEPILTarget."Driver Suggested Quantity"),
                1,
                MaxStrLen(TargetCarrierQuantityDecisionText)));
    end;

    [TryFunction]
    local procedure TryIsCurrentQuoteLine(PNEPILSalesQuoteMgt: Codeunit "PNE PIL Sales Quote Mgt."; PNEPILChangeLine: Record "PNE PIL Change Line"; var QuoteLineIsCurrent: Boolean)
    begin
        QuoteLineIsCurrent := PNEPILSalesQuoteMgt.IsActiveQuoteLinkCurrent(PNEPILChangeLine);
    end;

    var
        CompanyInformation: Record "Company Information";
        QuoteLinkCurrentCache: Dictionary of [Text, Boolean];
        QuoteLinkVerificationCache: Dictionary of [Text, Boolean];
        CompanyName: Text[100];
        ChangeCommercialStatusText: Text[100];
        ChangeCarrierIdentityText: Text[250];
        CommercialReviewStatusText: Text[100];
        QuoteSummaryText: Text[100];
        ReportDateText: Text[30];
        ReportTimeText: Text[30];
        TechnicalReviewStatusText: Text[100];
        TargetCarrierIdentityText: Text[250];
        TargetCarrierQuantityDecisionText: Text[250];
        TotalPILQuantity: Decimal;
        CoveredPILQuantity: Decimal;
        TotalEstimatedCostDifference: Decimal;
        ChangeLineCount: Integer;
        CommercialChangeLineCount: Integer;
        CoveredPILItemCount: Integer;
        PositiveChangeLineCount: Integer;
        ReversedQuoteLineCount: Integer;
        TotalPILItemCount: Integer;
        UnquotedCommercialChangeLineCount: Integer;
        UnquotedPositiveChangeLineCount: Integer;
        AddedToQuoteTxt: Label 'Toegevoegd aan offerte %1, regel %2.', Comment = '%1 = sales quote number, %2 = sales quote line number';
        AllCommercialChangesQuotedTxt: Label 'Alle netto meer- en minderwerkregels zijn gekoppeld aan een actuele offertregel.';
        AllocationRequiredTxt: Label 'Het technische voorstel is nog niet compleet: verdeel eerst alle AutoCAD-artikelen.';
        AllQuoteLinesTxt: Label 'Alle netto meer- en minderwerkregels hebben een actuele offertregel.';
        AppliedTxt: Label 'De technische PIL-wijziging is toegepast op de productieorder.';
        CarrierIdentityComponentLbl: Label ', component %1', Comment = '%1 = production order component line number';
        CarrierIdentityStartLbl: Label '%1, PO %2, regel %3', Comment = '%1 = production order status, %2 = production order number, %3 = production order line number';
        CarrierIdentityUnitOfMeasureLbl: Label ', eenheid %1', Comment = '%1 = unit of measure code';
        CarrierIdentityVariantLbl: Label ', variant %1', Comment = '%1 = variant code';
        CarrierQuantityChosenTxt: Label 'Bewuste keuze: %1 door %2 op %3. Reden: %4', Comment = '%1 = chosen carrier quantity, %2 = user ID, %3 = date-time, %4 = reason';
        CarrierQuantityConflictTxt: Label 'Conflict: deze driver vraagt %1; een bewuste carrierkeuze is nodig.', Comment = '%1 = driver suggested quantity';
        CarrierQuantitySuggestedTxt: Label 'Driver vraagt carrieraantal %1.', Comment = '%1 = driver suggested quantity';
        ImportNotPreparedTxt: Label 'Het technische voorstel is nog niet voorbereid.';
        NoCommercialChangesQuotedTxt: Label 'Geen netto meer- of minderwerkregel is gekoppeld aan een passende actuele offertregel.';
        NoCommercialChangeTxt: Label 'Er is geen netto carrierwijziging voor automatische offerte-overdracht.';
        NoCommercialDifferenceTxt: Label 'Geen netto commercieel verschil.';
        NetCommercialGroupZeroTxt: Label 'Valt weg tegen andere technische regels van hetzelfde artikel; commercieel netto nul.';
        NoQuoteLinesTxt: Label 'Er is geen passende actuele offertregel gevonden.';
        NoQuoteRequiredTxt: Label 'Geen netto meer- of minderwerkregel heeft een offerte-overdracht nodig.';
        NotAddedToQuoteTxt: Label 'Nog niet aan een offerte toegevoegd.';
        PreparedForApplyTxt: Label 'Technisch gecontroleerd en klaar om toe te passen.';
        QuoteLinkNeedsReviewTxt: Label 'Offertekoppeling controleren: artikelregel of gekoppelde artikeltekst wijkt af van dit voorstel.';
        QuoteLinkCannotBeVerifiedTxt: Label 'Offertekoppeling kan met de huidige rechten niet worden gecontroleerd.';
        QuoteReversedTxt: Label 'Offerte-overdracht is teruggedraaid; kies zo nodig opnieuw een offerte.';
        ReversedQuoteLinesTxt: Label '%1 offertregel(s) teruggedraaid; %2 technische regel(s) vragen commerciële beoordeling.', Comment = '%1 = reversed quote line count, %2 = technical change line count requiring commercial review';
        ReversedQuoteReviewTxt: Label 'Minstens één offerte-overdracht is teruggedraaid; kies opnieuw een offerte of beoordeel commercieel.';
        QuotedAndUnquotedLinesTxt: Label '%1 nettoregel(s) gekoppeld; %2 technische regel(s) vragen commerciële beoordeling.', Comment = '%1 = net quote line count linked to a current sales quote, %2 = technical change line count needing commercial review';
        SomeCommercialChangesUnquotedTxt: Label 'Een deel van het netto meer- en minderwerk vraagt commerciële beoordeling vóór offerte-overdracht.';
        DocumentTitleLbl: Label 'PIL-wijzigingsvoorstel';
        DirectComponentCommercialReviewTxt: Label 'Los toegevoegd productiecomponent: handmatige commerciële beoordeling; niet automatisch naar offerte.';
}
