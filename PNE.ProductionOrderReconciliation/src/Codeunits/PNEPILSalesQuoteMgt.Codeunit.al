namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Foundation.ExtendedText;
using Microsoft.Inventory.Item;
using Microsoft.Sales.Document;

codeunit 50197 "PNE PIL Sales Quote Mgt."
{
    Permissions = tabledata "Extended Text Header" = r,
                  tabledata "Extended Text Line" = r,
                  tabledata Item = r,
                  tabledata "PNE PIL Change Line" = rimd,
                  tabledata "PNE PIL Quote Resolution" = rimd,
                  tabledata "PNE PIL Quote Reversal" = rimd;

    procedure AddNetChangesToSelectedSalesQuote(var PNEPILHeader: Record "PNE PIL Header"; var SalesQuoteNo: Code[20]): Boolean
    var
        SalesHeader: Record "Sales Header";
        MoreworkLineCount: Integer;
        LessworkLineCount: Integer;
        TotalMoreworkQuantity: Decimal;
        TotalLessworkQuantity: Decimal;
        TotalEstimatedCostDifference: Decimal;
    begin
        CheckHeaderIsReadyForSalesQuote(PNEPILHeader);
        EnsureFreshTechnicalProposalForQuote(PNEPILHeader);
        CheckNoExistingSalesQuoteLinks(PNEPILHeader);
        if PNEPILHeader.Status = PNEPILHeader.Status::Prepared then
            if not Confirm(PreparedQuoteHandoffQst, false) then
                exit(false);
        GetNetChangeSummary(
            PNEPILHeader,
            MoreworkLineCount,
            LessworkLineCount,
            TotalMoreworkQuantity,
            TotalLessworkQuantity,
            TotalEstimatedCostDifference);
        if (MoreworkLineCount + LessworkLineCount) = 0 then
            Error(NoNetChangesErr, PNEPILHeader."Entry No.");

        if not SelectOpenSalesQuote(SalesHeader) then
            exit(false);

        if not Confirm(
            AddNetToQuoteQst,
            false,
            SalesHeader."No.",
            MoreworkLineCount,
            Format(TotalMoreworkQuantity),
            LessworkLineCount,
            Format(TotalLessworkQuantity),
            Format(TotalEstimatedCostDifference))
        then
            exit(false);

        AddNetChangesToSalesQuote(PNEPILHeader, SalesHeader);
        SalesQuoteNo := SalesHeader."No.";
        exit(true);
    end;

    procedure ReverseActiveQuoteHandoff(var PNEPILHeader: Record "PNE PIL Header"; ReversalReason: Text[250]): Boolean
    var
        SalesQuoteNo: Code[20];
        ActiveChangeCount: Integer;
    begin
        CheckReversalReason(ReversalReason);
        CheckHeaderCanReverseSalesQuote(PNEPILHeader);
        if not GetActiveQuoteHandoffSummary(PNEPILHeader, SalesQuoteNo, ActiveChangeCount) then
            exit(false);

        EnsureActiveQuoteLinksCurrent(PNEPILHeader);
        if not Confirm(ReverseQuoteQst, false, ActiveChangeCount, SalesQuoteNo) then
            exit(false);

        ReverseActiveQuoteHandoffOnOpenSalesQuote(PNEPILHeader, SalesQuoteNo, ReversalReason);
        exit(true);
    end;

    procedure HasActiveQuoteHandoff(PNEPILHeader: Record "PNE PIL Header"): Boolean
    var
        SalesQuoteNo: Code[20];
        ActiveChangeCount: Integer;
    begin
        exit(GetActiveQuoteHandoffSummary(PNEPILHeader, SalesQuoteNo, ActiveChangeCount));
    end;

    procedure HasCommerciallyLockedHandoff(PNEPILHeader: Record "PNE PIL Header"): Boolean
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
    begin
        SetCommerciallyLockedQuoteLinkFilter(PNEPILChangeLine, PNEPILHeader);
        exit(not PNEPILChangeLine.IsEmpty());
    end;

    procedure HasReleasedQuoteHandoff(PNEPILHeader: Record "PNE PIL Header"): Boolean
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
    begin
        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILChangeLine.SetRange("Quote Reversed", false);
        PNEPILChangeLine.SetRange("Quote Link Released", true);
        PNEPILChangeLine.SetFilter("Sales Quote No.", '<>%1', '');
        exit(not PNEPILChangeLine.IsEmpty());
    end;

    procedure GetQuoteHandoffState(PNEPILHeader: Record "PNE PIL Header"; var ActiveQuoteHandoffFound: Boolean; var CommerciallyLockedHandoffFound: Boolean; var ReleasedQuoteHandoffFound: Boolean)
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
    begin
        Clear(ActiveQuoteHandoffFound);
        Clear(CommerciallyLockedHandoffFound);
        Clear(ReleasedQuoteHandoffFound);

        SetCommerciallyLockedQuoteLinkFilter(PNEPILChangeLine, PNEPILHeader);
        PNEPILChangeLine.SetLoadFields("Quote Link Released");
        if PNEPILChangeLine.FindSet(false) then
            repeat
                CommerciallyLockedHandoffFound := true;
                if PNEPILChangeLine."Quote Link Released" then
                    ReleasedQuoteHandoffFound := true
                else
                    ActiveQuoteHandoffFound := true;
                if ActiveQuoteHandoffFound and ReleasedQuoteHandoffFound then
                    exit;
            until PNEPILChangeLine.Next() = 0;
    end;

    procedure ReleaseActiveQuoteHandoff(var PNEPILHeader: Record "PNE PIL Header"; ResolutionReason: Text[250]): Boolean
    var
        SalesQuoteNo: Code[20];
        ActiveChangeCount: Integer;
    begin
        CheckResolutionReason(ResolutionReason);
        CheckHeaderCanReleaseSalesQuote(PNEPILHeader);
        if not GetActiveQuoteHandoffSummary(PNEPILHeader, SalesQuoteNo, ActiveChangeCount) then
            exit(false);
        if not Confirm(ReleaseQuoteLinkQst, false, ActiveChangeCount, SalesQuoteNo) then
            exit(false);

        ReleaseActiveQuoteHandoffWithAudit(PNEPILHeader, ResolutionReason);
        exit(true);
    end;

    procedure GetQuotableNetChangeCount(PNEPILHeader: Record "PNE PIL Header"): Integer
    var
        MoreworkLineCount: Integer;
        LessworkLineCount: Integer;
        TotalMoreworkQuantity: Decimal;
        TotalLessworkQuantity: Decimal;
        TotalEstimatedCostDifference: Decimal;
    begin
        GetNetChangeSummary(
            PNEPILHeader,
            MoreworkLineCount,
            LessworkLineCount,
            TotalMoreworkQuantity,
            TotalLessworkQuantity,
            TotalEstimatedCostDifference);
        exit(MoreworkLineCount + LessworkLineCount);
    end;

    procedure GetCommercialGroupNetQuantity(PNEPILChangeLine: Record "PNE PIL Change Line"): Decimal
    var
        GroupPNEPILChangeLine: Record "PNE PIL Change Line";
        NetQuantity: Decimal;
    begin
        GroupPNEPILChangeLine.SetRange("Header Entry No.", PNEPILChangeLine."Header Entry No.");
        GroupPNEPILChangeLine.SetRange("Carrier Item No.", PNEPILChangeLine."Carrier Item No.");
        GroupPNEPILChangeLine.SetRange("Carrier Variant Code", PNEPILChangeLine."Carrier Variant Code");
        GroupPNEPILChangeLine.SetRange("Unit of Measure Code", PNEPILChangeLine."Unit of Measure Code");
        if GroupPNEPILChangeLine.FindSet() then
            repeat
                if not IsDirectComponentChangeLine(GroupPNEPILChangeLine) then
                    NetQuantity += GroupPNEPILChangeLine."Quantity Difference";
            until GroupPNEPILChangeLine.Next() = 0;
        exit(NetQuantity);
    end;

    procedure EnsureActiveQuoteLinksCurrent(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        ProcessedQuoteLines: Dictionary of [Text, Boolean];
        QuoteLineKey: Text;
        QuoteItemLineIsCurrent: Boolean;
        QuoteLineIsCurrent: Boolean;
    begin
        SetActiveQuoteLinkFilter(PNEPILChangeLine, PNEPILHeader);
        if PNEPILChangeLine.FindSet() then
            repeat
                QuoteLineKey := GetQuoteLineKey(PNEPILChangeLine);
                if not ProcessedQuoteLines.ContainsKey(QuoteLineKey) then begin
                    if not TryGetActiveQuoteLinkStatus(PNEPILChangeLine, QuoteItemLineIsCurrent, QuoteLineIsCurrent) then
                        Error(QuoteLinkCannotBeVerifiedErr, PNEPILChangeLine."Sales Quote No.", PNEPILChangeLine."Sales Quote Line No.");
                    if not QuoteItemLineIsCurrent then
                        Error(QuotedLineChangedErr, PNEPILChangeLine."Sales Quote No.", PNEPILChangeLine."Sales Quote Line No.");
                    if not QuoteLineIsCurrent then
                        Error(QuotedTextChangedErr, PNEPILChangeLine."Sales Quote No.", PNEPILChangeLine."Sales Quote Line No.");
                    ProcessedQuoteLines.Add(QuoteLineKey, true);
                end;
            until PNEPILChangeLine.Next() = 0;
    end;

    procedure EnsureActiveQuoteItemLinksCurrent(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        ProcessedQuoteLines: Dictionary of [Text, Boolean];
        QuoteLineKey: Text;
        QuoteLineIsCurrent: Boolean;
    begin
        SetActiveQuoteLinkFilter(PNEPILChangeLine, PNEPILHeader);
        if PNEPILChangeLine.FindSet() then
            repeat
                QuoteLineKey := GetQuoteLineKey(PNEPILChangeLine);
                if not ProcessedQuoteLines.ContainsKey(QuoteLineKey) then begin
                    if not TryIsActiveQuoteItemLinkCurrent(PNEPILChangeLine, QuoteLineIsCurrent) then
                        Error(QuoteLinkCannotBeVerifiedErr, PNEPILChangeLine."Sales Quote No.", PNEPILChangeLine."Sales Quote Line No.");
                    if not QuoteLineIsCurrent then
                        Error(QuotedLineChangedErr, PNEPILChangeLine."Sales Quote No.", PNEPILChangeLine."Sales Quote Line No.");
                    ProcessedQuoteLines.Add(QuoteLineKey, true);
                end;
            until PNEPILChangeLine.Next() = 0;
    end;

    procedure IsActiveQuoteLinkCurrent(PNEPILChangeLine: Record "PNE PIL Change Line"): Boolean
    var
        QuoteItemLineIsCurrent: Boolean;
        QuoteTextIsCurrent: Boolean;
    begin
        GetActiveQuoteLinkStatus(PNEPILChangeLine, QuoteItemLineIsCurrent, QuoteTextIsCurrent);
        exit(QuoteItemLineIsCurrent and QuoteTextIsCurrent);
    end;

    local procedure GetActiveQuoteLinkStatus(PNEPILChangeLine: Record "PNE PIL Change Line"; var QuoteItemLineIsCurrent: Boolean; var QuoteTextIsCurrent: Boolean)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        Clear(QuoteItemLineIsCurrent);
        Clear(QuoteTextIsCurrent);
        if PNEPILChangeLine."Quote Reversed" or
           PNEPILChangeLine."Quote Link Released" or
           (PNEPILChangeLine."Sales Quote No." = '') or
           (PNEPILChangeLine."Sales Quote Line No." = 0)
        then
            exit;
        if not SalesHeader.Get(SalesHeader."Document Type"::Quote, PNEPILChangeLine."Sales Quote No.") then
            exit;
        if not SalesLine.Get(
            SalesLine."Document Type"::Quote,
            PNEPILChangeLine."Sales Quote No.",
            PNEPILChangeLine."Sales Quote Line No.")
        then
            exit;
        QuoteItemLineIsCurrent := IsMatchingSalesQuoteItemLine(PNEPILChangeLine, SalesHeader, SalesLine);
        if QuoteItemLineIsCurrent then
            QuoteTextIsCurrent := HasExpectedSalesQuoteExtendedText(SalesHeader, SalesLine);
    end;

    local procedure IsActiveQuoteItemLinkCurrent(PNEPILChangeLine: Record "PNE PIL Change Line"): Boolean
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        if PNEPILChangeLine."Quote Reversed" or
           PNEPILChangeLine."Quote Link Released" or
           (PNEPILChangeLine."Sales Quote No." = '') or
           (PNEPILChangeLine."Sales Quote Line No." = 0)
        then
            exit(false);
        if not SalesHeader.Get(SalesHeader."Document Type"::Quote, PNEPILChangeLine."Sales Quote No.") then
            exit(false);
        if not SalesLine.Get(
            SalesLine."Document Type"::Quote,
            PNEPILChangeLine."Sales Quote No.",
            PNEPILChangeLine."Sales Quote Line No.")
        then
            exit(false);
        exit(IsMatchingSalesQuoteItemLine(PNEPILChangeLine, SalesHeader, SalesLine));
    end;

    procedure OpenSalesQuote(SalesQuoteNo: Code[20])
    begin
        if not TryOpenSalesQuote(SalesQuoteNo) then
            Error(OpenSalesQuoteErr, SalesQuoteNo);
    end;

    local procedure SelectOpenSalesQuote(var SelectedSalesHeader: Record "Sales Header"): Boolean
    var
        SalesQuotes: Page "Sales Quotes";
    begin
        SelectedSalesHeader.Reset();
        SelectedSalesHeader.SetRange("Document Type", SelectedSalesHeader."Document Type"::Quote);
        SelectedSalesHeader.SetRange(Status, SelectedSalesHeader.Status::Open);
        SelectedSalesHeader.SetRange("Quote Accepted", false);
        SelectedSalesHeader.SetFilter("Quote Valid Until Date", '%1|>=%2', 0D, WorkDate());
        SalesQuotes.SetTableView(SelectedSalesHeader);
        SalesQuotes.LookupMode(true);
        if SalesQuotes.RunModal() <> Action::LookupOK then
            exit(false);
        SalesQuotes.GetRecord(SelectedSalesHeader);
        CheckOpenSalesQuote(SelectedSalesHeader);
        exit(true);
    end;

    local procedure AddNetChangesToSalesQuote(var PNEPILHeader: Record "PNE PIL Header"; SelectedSalesHeader: Record "Sales Header")
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        TempPNEPILChangeLine: Record "PNE PIL Change Line" temporary;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        PNEPILMgt: Codeunit "PNE PIL Mgt.";
    begin
        PNEPILHeader.LockTable();
        PNEPILChangeLine.LockTable();
        SalesHeader.LockTable();
        SalesLine.LockTable();

        PNEPILHeader.Get(PNEPILHeader."Entry No.");
        CheckHeaderIsReadyForSalesQuote(PNEPILHeader);
        if PNEPILHeader.Status = PNEPILHeader.Status::Prepared then
            PNEPILMgt.EnsureProposalCurrentForCommercialHandoff(PNEPILHeader);
        CheckNoExistingSalesQuoteLinks(PNEPILHeader);

        SalesHeader.Get(SalesHeader."Document Type"::Quote, SelectedSalesHeader."No.");
        CheckOpenSalesQuote(SalesHeader);

        BuildCommercialAggregates(PNEPILHeader, TempPNEPILChangeLine);
        if TempPNEPILChangeLine.FindSet() then
            repeat
                if Abs(TempPNEPILChangeLine."Quantity Difference") > QuantityTolerance() then
                    AddNetSalesQuoteItemLine(
                        SalesHeader,
                        TempPNEPILChangeLine);
            until TempPNEPILChangeLine.Next() = 0;
    end;

    local procedure AddNetSalesQuoteItemLine(SalesHeader: Record "Sales Header"; TempPNEPILChangeLine: Record "PNE PIL Change Line" temporary)
    var
        NewSalesLine: Record "Sales Line";
        TempExpectedExtendedTextSalesLine: Record "Sales Line" temporary;
    begin
        NewSalesLine.Init();
        NewSalesLine."Document Type" := SalesHeader."Document Type";
        NewSalesLine."Document No." := SalesHeader."No.";
        NewSalesLine."Line No." := GetNextSalesLineNo(SalesHeader);
        NewSalesLine.SetSalesHeader(SalesHeader);
        NewSalesLine.Validate(Type, NewSalesLine.Type::Item);
        NewSalesLine.Validate("No.", TempPNEPILChangeLine."Carrier Item No.");
        if TempPNEPILChangeLine."Carrier Variant Code" <> '' then
            NewSalesLine.Validate("Variant Code", TempPNEPILChangeLine."Carrier Variant Code");
        if TempPNEPILChangeLine."Unit of Measure Code" <> '' then
            NewSalesLine.Validate("Unit of Measure Code", TempPNEPILChangeLine."Unit of Measure Code");
        NewSalesLine.Validate(Quantity, TempPNEPILChangeLine."Quantity Difference");
        NewSalesLine.Insert(true);
        InsertQuantitySalesQuoteExtendedText(SalesHeader, NewSalesLine, TempExpectedExtendedTextSalesLine);
        if not SalesQuoteExtendedTextMatchesExpected(NewSalesLine, TempExpectedExtendedTextSalesLine) then
            Error(QuoteExtendedTextInsertErr, NewSalesLine."No.");

        LinkCommercialSourceLines(
            TempPNEPILChangeLine,
            SalesHeader,
            NewSalesLine);
    end;

    local procedure LinkCommercialSourceLines(TempPNEPILChangeLine: Record "PNE PIL Change Line" temporary; SalesHeader: Record "Sales Header"; NewSalesLine: Record "Sales Line")
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
    begin
        PNEPILChangeLine.SetRange("Header Entry No.", TempPNEPILChangeLine."Header Entry No.");
        PNEPILChangeLine.SetRange("Carrier Item No.", TempPNEPILChangeLine."Carrier Item No.");
        PNEPILChangeLine.SetRange("Carrier Variant Code", TempPNEPILChangeLine."Carrier Variant Code");
        PNEPILChangeLine.SetRange("Unit of Measure Code", TempPNEPILChangeLine."Unit of Measure Code");
        if PNEPILChangeLine.FindSet(true) then
            repeat
                if (Abs(PNEPILChangeLine."Quantity Difference") > QuantityTolerance()) and
                   not IsDirectComponentChangeLine(PNEPILChangeLine)
                then begin
                    PNEPILChangeLine."Sales Quote No." := SalesHeader."No.";
                    PNEPILChangeLine."Sales Quote Line No." := NewSalesLine."Line No.";
                    PNEPILChangeLine."Sales Quote Line SystemId" := NewSalesLine.SystemId;
                    PNEPILChangeLine."Sales Quote Line Modified At" := NewSalesLine.SystemModifiedAt;
                    PNEPILChangeLine."Quote Unit Price" := NewSalesLine."Unit Price";
                    PNEPILChangeLine."Quote Line Amount" := NewSalesLine."Line Amount";
                    PNEPILChangeLine."Quote Currency Code" := SalesHeader."Currency Code";
                    PNEPILChangeLine."Quote Added At" := CurrentDateTime();
                    PNEPILChangeLine."Quote Added By" := CopyStr(UserId(), 1, MaxStrLen(PNEPILChangeLine."Quote Added By"));
                    PNEPILChangeLine."Quote Line Description" := NewSalesLine.Description;
                    PNEPILChangeLine."Quote Reversed" := false;
                    PNEPILChangeLine."Quote Reversal Entry No." := 0;
                    PNEPILChangeLine."Quote Link Released" := false;
                    PNEPILChangeLine."Quote Resolution Entry No." := 0;
                    PNEPILChangeLine.Modify(true);
                end;
            until PNEPILChangeLine.Next() = 0;
    end;

    local procedure ReverseActiveQuoteHandoffOnOpenSalesQuote(var PNEPILHeader: Record "PNE PIL Header"; SalesQuoteNo: Code[20]; ReversalReason: Text[250])
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        PNEPILQuoteReversal: Record "PNE PIL Quote Reversal";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ProcessedSalesQuoteLineNos: Dictionary of [Integer, Boolean];
        QuoteLineIsCurrent: Boolean;
    begin
        PNEPILHeader.LockTable();
        PNEPILChangeLine.LockTable();
        PNEPILQuoteReversal.LockTable();
        SalesHeader.LockTable();
        SalesLine.LockTable();

        PNEPILHeader.Get(PNEPILHeader."Entry No.");
        CheckHeaderCanReverseSalesQuote(PNEPILHeader);
        SalesHeader.Get(SalesHeader."Document Type"::Quote, SalesQuoteNo);
        CheckOpenSalesQuote(SalesHeader);

        SetActiveQuoteLinkFilter(PNEPILChangeLine, PNEPILHeader);
        PNEPILChangeLine.SetRange("Sales Quote No.", SalesQuoteNo);
        if PNEPILChangeLine.IsEmpty() then
            Error(NoActiveQuoteHandoffErr, PNEPILHeader."Entry No.");
        if PNEPILChangeLine.FindSet(true) then
            repeat
                if not ProcessedSalesQuoteLineNos.ContainsKey(PNEPILChangeLine."Sales Quote Line No.") then begin
                    if not SalesLine.Get(
                        SalesLine."Document Type"::Quote,
                        PNEPILChangeLine."Sales Quote No.",
                        PNEPILChangeLine."Sales Quote Line No.")
                    then
                        Error(QuotedLineMissingErr, PNEPILChangeLine."Sales Quote No.", PNEPILChangeLine."Sales Quote Line No.");
                    if not IsMatchingSalesQuoteItemLine(PNEPILChangeLine, SalesHeader, SalesLine) then
                        Error(QuotedLineChangedErr, PNEPILChangeLine."Sales Quote No.", PNEPILChangeLine."Sales Quote Line No.");
                    if not TryHasExpectedSalesQuoteExtendedText(SalesHeader, SalesLine, QuoteLineIsCurrent) then
                        Error(QuoteLinkCannotBeVerifiedErr, PNEPILChangeLine."Sales Quote No.", PNEPILChangeLine."Sales Quote Line No.");
                    if not QuoteLineIsCurrent then
                        Error(QuotedTextChangedErr, PNEPILChangeLine."Sales Quote No.", PNEPILChangeLine."Sales Quote Line No.");
                    SalesLine.Delete(true);
                    ProcessedSalesQuoteLineNos.Add(PNEPILChangeLine."Sales Quote Line No.", true);
                end;

                CreateQuoteReversalAudit(PNEPILQuoteReversal, PNEPILChangeLine, ReversalReason);
                PNEPILChangeLine."Quote Reversed" := true;
                PNEPILChangeLine."Quote Reversal Entry No." := PNEPILQuoteReversal."Entry No.";
                PNEPILChangeLine.Modify(true);
            until PNEPILChangeLine.Next() = 0;
    end;

    local procedure CreateQuoteReversalAudit(var PNEPILQuoteReversal: Record "PNE PIL Quote Reversal"; PNEPILChangeLine: Record "PNE PIL Change Line"; ReversalReason: Text[250])
    begin
        PNEPILQuoteReversal.Init();
        PNEPILQuoteReversal."Header Entry No." := PNEPILChangeLine."Header Entry No.";
        PNEPILQuoteReversal."Change Line No." := PNEPILChangeLine."Line No.";
        PNEPILQuoteReversal."Sales Quote No." := PNEPILChangeLine."Sales Quote No.";
        PNEPILQuoteReversal."Sales Quote Line No." := PNEPILChangeLine."Sales Quote Line No.";
        PNEPILQuoteReversal."Sales Quote Line SystemId" := PNEPILChangeLine."Sales Quote Line SystemId";
        PNEPILQuoteReversal."Sales Quote Line Modified At" := PNEPILChangeLine."Sales Quote Line Modified At";
        PNEPILQuoteReversal."Carrier Item No." := PNEPILChangeLine."Carrier Item No.";
        PNEPILQuoteReversal."Carrier Variant Code" := PNEPILChangeLine."Carrier Variant Code";
        PNEPILQuoteReversal."Unit of Measure Code" := PNEPILChangeLine."Unit of Measure Code";
        PNEPILQuoteReversal.Quantity := PNEPILChangeLine."Quantity Difference";
        PNEPILQuoteReversal."Quote Line Description" := PNEPILChangeLine."Quote Line Description";
        PNEPILQuoteReversal."Quote Unit Price" := PNEPILChangeLine."Quote Unit Price";
        PNEPILQuoteReversal."Quote Line Amount" := PNEPILChangeLine."Quote Line Amount";
        PNEPILQuoteReversal."Quote Currency Code" := PNEPILChangeLine."Quote Currency Code";
        PNEPILQuoteReversal."Reversal Reason" := ReversalReason;
        PNEPILQuoteReversal."Reversed At" := CurrentDateTime();
        PNEPILQuoteReversal."Reversed By" := CopyStr(UserId(), 1, MaxStrLen(PNEPILQuoteReversal."Reversed By"));
        PNEPILQuoteReversal.Insert(true);
    end;

    local procedure ReleaseActiveQuoteHandoffWithAudit(var PNEPILHeader: Record "PNE PIL Header"; ResolutionReason: Text[250])
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        PNEPILQuoteResolution: Record "PNE PIL Quote Resolution";
        ResolvedAt: DateTime;
        ResolvedBy: Text[50];
    begin
        PNEPILHeader.LockTable();
        PNEPILChangeLine.LockTable();
        PNEPILQuoteResolution.LockTable();

        PNEPILHeader.Get(PNEPILHeader."Entry No.");
        CheckHeaderCanReleaseSalesQuote(PNEPILHeader);
        SetActiveQuoteLinkFilter(PNEPILChangeLine, PNEPILHeader);
        if PNEPILChangeLine.IsEmpty() then
            Error(NoActiveQuoteHandoffErr, PNEPILHeader."Entry No.");
        ResolvedAt := CurrentDateTime();
        ResolvedBy := CopyStr(UserId(), 1, MaxStrLen(ResolvedBy));
        if PNEPILChangeLine.FindSet(true) then
            repeat
                CreateQuoteResolutionAudit(
                    PNEPILQuoteResolution,
                    PNEPILChangeLine,
                    ResolutionReason,
                    ResolvedAt,
                    ResolvedBy);
                PNEPILChangeLine."Quote Link Released" := true;
                PNEPILChangeLine."Quote Resolution Entry No." := PNEPILQuoteResolution."Entry No.";
                PNEPILChangeLine.Modify(true);
            until PNEPILChangeLine.Next() = 0;
    end;

    local procedure CreateQuoteResolutionAudit(var PNEPILQuoteResolution: Record "PNE PIL Quote Resolution"; PNEPILChangeLine: Record "PNE PIL Change Line"; ResolutionReason: Text[250]; ResolvedAt: DateTime; ResolvedBy: Text[50])
    begin
        PNEPILQuoteResolution.Init();
        PNEPILQuoteResolution."Header Entry No." := PNEPILChangeLine."Header Entry No.";
        PNEPILQuoteResolution."Change Line No." := PNEPILChangeLine."Line No.";
        PNEPILQuoteResolution."Sales Quote No." := PNEPILChangeLine."Sales Quote No.";
        PNEPILQuoteResolution."Sales Quote Line No." := PNEPILChangeLine."Sales Quote Line No.";
        PNEPILQuoteResolution."Sales Quote Line SystemId" := PNEPILChangeLine."Sales Quote Line SystemId";
        PNEPILQuoteResolution."Sales Quote Line Modified At" := PNEPILChangeLine."Sales Quote Line Modified At";
        PNEPILQuoteResolution."Carrier Item No." := PNEPILChangeLine."Carrier Item No.";
        PNEPILQuoteResolution."Carrier Variant Code" := PNEPILChangeLine."Carrier Variant Code";
        PNEPILQuoteResolution."Unit of Measure Code" := PNEPILChangeLine."Unit of Measure Code";
        PNEPILQuoteResolution.Quantity := PNEPILChangeLine."Quantity Difference";
        PNEPILQuoteResolution."Quote Line Description" := PNEPILChangeLine."Quote Line Description";
        PNEPILQuoteResolution."Quote Unit Price" := PNEPILChangeLine."Quote Unit Price";
        PNEPILQuoteResolution."Quote Line Amount" := PNEPILChangeLine."Quote Line Amount";
        PNEPILQuoteResolution."Quote Currency Code" := PNEPILChangeLine."Quote Currency Code";
        PNEPILQuoteResolution."Observed Link State" := GetObservedQuoteLinkState(PNEPILChangeLine);
        PNEPILQuoteResolution."Resolution Reason" := ResolutionReason;
        PNEPILQuoteResolution."Resolved At" := ResolvedAt;
        PNEPILQuoteResolution."Resolved By" := ResolvedBy;
        PNEPILQuoteResolution.Insert(true);
    end;

    local procedure GetObservedQuoteLinkState(PNEPILChangeLine: Record "PNE PIL Change Line"): Enum "PNE PIL Quote Link State"
    var
        QuoteLinkState: Enum "PNE PIL Quote Link State";
    begin
        if not TryDetermineQuoteLinkState(PNEPILChangeLine, QuoteLinkState) then
            exit(QuoteLinkState::"Cannot Verify");
        exit(QuoteLinkState);
    end;

    local procedure DetermineQuoteLinkState(PNEPILChangeLine: Record "PNE PIL Change Line"): Enum "PNE PIL Quote Link State"
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        if not SalesHeader.Get(SalesHeader."Document Type"::Quote, PNEPILChangeLine."Sales Quote No.") then
            exit("PNE PIL Quote Link State"::"Quote Missing");
        if not SalesLine.Get(
            SalesLine."Document Type"::Quote,
            PNEPILChangeLine."Sales Quote No.",
            PNEPILChangeLine."Sales Quote Line No.")
        then
            exit("PNE PIL Quote Link State"::"Quote Line Missing");
        if not IsMatchingSalesQuoteItemLine(PNEPILChangeLine, SalesHeader, SalesLine) then
            exit("PNE PIL Quote Link State"::"Item Line Changed");
        if not HasExpectedSalesQuoteExtendedText(SalesHeader, SalesLine) then
            exit("PNE PIL Quote Link State"::"Text Changed");
        exit("PNE PIL Quote Link State"::Current);
    end;

    local procedure CheckHeaderIsReadyForSalesQuote(PNEPILHeader: Record "PNE PIL Header")
    begin
        if not (PNEPILHeader.Status in [PNEPILHeader.Status::Prepared, PNEPILHeader.Status::Applied]) then
            Error(ProposalNotReadyErr, PNEPILHeader."Entry No.");
    end;

    local procedure CheckHeaderCanReverseSalesQuote(PNEPILHeader: Record "PNE PIL Header")
    begin
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AppliedProposalCannotReverseErr, PNEPILHeader."Entry No.");
        if PNEPILHeader.Status <> PNEPILHeader.Status::Prepared then
            Error(ProposalNotReadyForReversalErr, PNEPILHeader."Entry No.");
    end;

    local procedure CheckHeaderCanReleaseSalesQuote(PNEPILHeader: Record "PNE PIL Header")
    begin
        if not (PNEPILHeader.Status in [PNEPILHeader.Status::Prepared, PNEPILHeader.Status::Applied]) then
            Error(ProposalNotReadyForReleaseErr, PNEPILHeader."Entry No.");
    end;

    local procedure EnsureFreshTechnicalProposalForQuote(var PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILMgt: Codeunit "PNE PIL Mgt.";
    begin
        if PNEPILHeader.Status = PNEPILHeader.Status::Prepared then
            PNEPILMgt.EnsureProposalCurrentForCommercialHandoff(PNEPILHeader);
    end;

    local procedure CheckNoExistingSalesQuoteLinks(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
    begin
        SetCommerciallyLockedQuoteLinkFilter(PNEPILChangeLine, PNEPILHeader);
        if not PNEPILChangeLine.IsEmpty() then
            Error(AlreadyAddedToQuoteErr, PNEPILHeader."Entry No.");
    end;

    local procedure CheckOpenSalesQuote(SalesHeader: Record "Sales Header")
    begin
        SalesHeader.TestField("Document Type", SalesHeader."Document Type"::Quote);
        SalesHeader.TestField(Status, SalesHeader.Status::Open);
        SalesHeader.TestField("Quote Accepted", false);
        if (SalesHeader."Quote Valid Until Date" <> 0D) and (SalesHeader."Quote Valid Until Date" < WorkDate()) then
            Error(QuoteExpiredErr, SalesHeader."No.", SalesHeader."Quote Valid Until Date");
    end;

    local procedure CheckReversalReason(ReversalReason: Text[250])
    begin
        if DelChr(ReversalReason, '=', ' ') = '' then
            Error(ReversalReasonRequiredErr);
    end;

    local procedure CheckResolutionReason(ResolutionReason: Text[250])
    begin
        if DelChr(ResolutionReason, '=', ' ') = '' then
            Error(ResolutionReasonRequiredErr);
    end;

    local procedure GetActiveQuoteHandoffSummary(PNEPILHeader: Record "PNE PIL Header"; var SalesQuoteNo: Code[20]; var ActiveChangeCount: Integer): Boolean
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        ActiveSalesQuoteLineNos: Dictionary of [Integer, Boolean];
    begin
        Clear(SalesQuoteNo);
        Clear(ActiveChangeCount);
        SetActiveQuoteLinkFilter(PNEPILChangeLine, PNEPILHeader);
        if not PNEPILChangeLine.FindSet() then
            exit(false);
        repeat
            if SalesQuoteNo = '' then
                SalesQuoteNo := PNEPILChangeLine."Sales Quote No."
            else
                if SalesQuoteNo <> PNEPILChangeLine."Sales Quote No." then
                    Error(MultipleActiveSalesQuotesErr, PNEPILHeader."Entry No.");
            if not ActiveSalesQuoteLineNos.ContainsKey(PNEPILChangeLine."Sales Quote Line No.") then begin
                ActiveSalesQuoteLineNos.Add(PNEPILChangeLine."Sales Quote Line No.", true);
                ActiveChangeCount += 1;
            end;
        until PNEPILChangeLine.Next() = 0;
        exit(true);
    end;

    local procedure GetNextSalesLineNo(SalesHeader: Record "Sales Header"): Integer
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindLast() then
            exit(SalesLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure InsertQuantitySalesQuoteExtendedText(SalesHeader: Record "Sales Header"; SalesLine: Record "Sales Line"; var TempExpectedExtendedTextSalesLine: Record "Sales Line" temporary)
    var
        NewExtendedTextSalesLine: Record "Sales Line";
    begin
        BuildExpectedSalesQuoteExtendedText(SalesHeader, SalesLine, TempExpectedExtendedTextSalesLine);
        if TempExpectedExtendedTextSalesLine.FindSet() then
            repeat
                NewExtendedTextSalesLine := TempExpectedExtendedTextSalesLine;
                NewExtendedTextSalesLine.Insert();
            until TempExpectedExtendedTextSalesLine.Next() = 0;
    end;

    local procedure HasExpectedSalesQuoteExtendedText(SalesHeader: Record "Sales Header"; SalesLine: Record "Sales Line"): Boolean
    var
        TempExpectedExtendedTextSalesLine: Record "Sales Line" temporary;
    begin
        BuildExpectedSalesQuoteExtendedText(SalesHeader, SalesLine, TempExpectedExtendedTextSalesLine);
        exit(SalesQuoteExtendedTextMatchesExpected(SalesLine, TempExpectedExtendedTextSalesLine));
    end;

    local procedure SalesQuoteExtendedTextMatchesExpected(SalesLine: Record "Sales Line"; var TempExpectedExtendedTextSalesLine: Record "Sales Line" temporary): Boolean
    var
        ActualExtendedTextSalesLine: Record "Sales Line";
        ActualLineFound: Boolean;
        ExpectedLineFound: Boolean;
    begin
        ActualExtendedTextSalesLine.SetRange("Document Type", SalesLine."Document Type");
        ActualExtendedTextSalesLine.SetRange("Document No.", SalesLine."Document No.");
        ActualExtendedTextSalesLine.SetRange("Attached to Line No.", SalesLine."Line No.");
        ActualLineFound := ActualExtendedTextSalesLine.FindSet();
        ExpectedLineFound := TempExpectedExtendedTextSalesLine.FindSet();
        while ActualLineFound and ExpectedLineFound do begin
            if (ActualExtendedTextSalesLine."Line No." <> TempExpectedExtendedTextSalesLine."Line No.") or
               (ActualExtendedTextSalesLine.Type <> SalesLine.Type::" ") or
               (ActualExtendedTextSalesLine."No." <> '') or
               (ActualExtendedTextSalesLine.Quantity <> 0) or
               (ActualExtendedTextSalesLine.Description <> TempExpectedExtendedTextSalesLine.Description)
            then
                exit(false);
            ActualLineFound := ActualExtendedTextSalesLine.Next() <> 0;
            ExpectedLineFound := TempExpectedExtendedTextSalesLine.Next() <> 0;
        end;
        exit(not ActualLineFound and not ExpectedLineFound);
    end;

    local procedure BuildExpectedSalesQuoteExtendedText(SalesHeader: Record "Sales Header"; SalesLine: Record "Sales Line"; var TempExpectedExtendedTextSalesLine: Record "Sales Line" temporary)
    var
        ExtendedTextHeader: Record "Extended Text Header";
        Item: Record Item;
        TempExtendedTextLine: Record "Extended Text Line" temporary;
        TransferExtendedText: Codeunit "Transfer Extended Text";
        NextLineNo: Integer;
    begin
        TempExpectedExtendedTextSalesLine.Reset();
        TempExpectedExtendedTextSalesLine.DeleteAll();
        if (SalesLine.Type <> SalesLine.Type::Item) or (SalesLine."No." = '') then
            exit;
        if not Item.Get(SalesLine."No.") or not Item."Automatic Ext. Texts" then
            exit;

        ExtendedTextHeader.SetRange("Table Name", ExtendedTextHeader."Table Name"::Item);
        ExtendedTextHeader.SetRange("No.", SalesLine."No.");
        ExtendedTextHeader.SetRange("Sales Quote", true);
        if not TransferExtendedText.ReadExtTextLines(
            ExtendedTextHeader,
            SalesHeader."Document Date",
            SalesHeader."Language Code")
        then
            exit;

        TransferExtendedText.GetTempExtTextLine(TempExtendedTextLine);
        NextLineNo := SalesLine."Line No." + ExtendedTextLineSpacing();
        if TempExtendedTextLine.FindSet() then
            repeat
                if TempExtendedTextLine.Text = '' then
                    AppendBlankSalesTextLine(TempExpectedExtendedTextSalesLine, SalesLine, NextLineNo)
                else
                    AppendQuantitySalesTextLines(
                        TempExpectedExtendedTextSalesLine,
                        SalesLine,
                        TempExtendedTextLine.Text,
                        NextLineNo);
            until TempExtendedTextLine.Next() = 0;
    end;

    local procedure AppendBlankSalesTextLine(var TempExpectedExtendedTextSalesLine: Record "Sales Line" temporary; SalesLine: Record "Sales Line"; var NextLineNo: Integer)
    begin
        TempExpectedExtendedTextSalesLine.Init();
        TempExpectedExtendedTextSalesLine."Document Type" := SalesLine."Document Type";
        TempExpectedExtendedTextSalesLine."Document No." := SalesLine."Document No.";
        TempExpectedExtendedTextSalesLine."Line No." := NextLineNo;
        TempExpectedExtendedTextSalesLine.Description := '';
        TempExpectedExtendedTextSalesLine."Attached to Line No." := SalesLine."Line No.";
        TempExpectedExtendedTextSalesLine.Insert();
        NextLineNo += ExtendedTextLineSpacing();
    end;

    local procedure AppendQuantitySalesTextLines(var TempExpectedExtendedTextSalesLine: Record "Sales Line" temporary; SalesLine: Record "Sales Line"; ExtendedText: Text; var NextLineNo: Integer)
    var
        OutputText: Text;
        QuantityPrefix: Text;
        TextPart: Text;
        AvailableTextLength: Integer;
    begin
        OutputText := ExtendedText;
        QuantityPrefix := GetSalesTextQuantityPrefix(SalesLine.Quantity);
        AvailableTextLength := MaxStrLen(TempExpectedExtendedTextSalesLine.Description) - StrLen(QuantityPrefix);
        if AvailableTextLength < 1 then
            AvailableTextLength := 1;
        while OutputText <> '' do begin
            TextPart := GetWordWrappedTextPart(OutputText, AvailableTextLength);
            OutputText := RemoveWrappedTextPart(OutputText, TextPart);

            TempExpectedExtendedTextSalesLine.Init();
            TempExpectedExtendedTextSalesLine."Document Type" := SalesLine."Document Type";
            TempExpectedExtendedTextSalesLine."Document No." := SalesLine."Document No.";
            TempExpectedExtendedTextSalesLine."Line No." := NextLineNo;
            TempExpectedExtendedTextSalesLine.Description := CopyStr(
                QuantityPrefix + TextPart,
                1,
                MaxStrLen(TempExpectedExtendedTextSalesLine.Description));
            TempExpectedExtendedTextSalesLine."Attached to Line No." := SalesLine."Line No.";
            TempExpectedExtendedTextSalesLine.Insert();

            NextLineNo += ExtendedTextLineSpacing();
            Clear(QuantityPrefix);
            AvailableTextLength := MaxStrLen(TempExpectedExtendedTextSalesLine.Description);
        end;
    end;

    local procedure GetSalesTextQuantityPrefix(Quantity: Decimal): Text
    begin
        if Quantity < 0 then
            exit(StrSubstNo(LessworkQuantityPrefixLbl, Format(Abs(Quantity), 0, 9)));
        exit(StrSubstNo(QuantityPrefixLbl, Format(Quantity, 0, 9)));
    end;

    local procedure GetWordWrappedTextPart(OutputText: Text; AvailableTextLength: Integer): Text
    var
        BreakPosition: Integer;
    begin
        if StrLen(OutputText) <= AvailableTextLength then
            exit(OutputText);

        BreakPosition := AvailableTextLength;
        while (BreakPosition > 1) and (CopyStr(OutputText, BreakPosition, 1) <> ' ') do
            BreakPosition -= 1;
        if BreakPosition = 1 then
            exit(CopyStr(OutputText, 1, AvailableTextLength));
        exit(CopyStr(OutputText, 1, BreakPosition - 1));
    end;

    local procedure RemoveWrappedTextPart(OutputText: Text; TextPart: Text): Text
    var
        NextPosition: Integer;
    begin
        NextPosition := StrLen(TextPart) + 1;
        while (NextPosition <= StrLen(OutputText)) and (CopyStr(OutputText, NextPosition, 1) = ' ') do
            NextPosition += 1;
        exit(CopyStr(OutputText, NextPosition));
    end;

    local procedure ExtendedTextLineSpacing(): Integer
    begin
        exit(10);
    end;

    local procedure GetNetChangeSummary(PNEPILHeader: Record "PNE PIL Header"; var MoreworkLineCount: Integer; var LessworkLineCount: Integer; var TotalMoreworkQuantity: Decimal; var TotalLessworkQuantity: Decimal; var TotalEstimatedCostDifference: Decimal)
    var
        TempPNEPILChangeLine: Record "PNE PIL Change Line" temporary;
    begin
        Clear(MoreworkLineCount);
        Clear(LessworkLineCount);
        Clear(TotalMoreworkQuantity);
        Clear(TotalLessworkQuantity);
        Clear(TotalEstimatedCostDifference);
        BuildCommercialAggregates(PNEPILHeader, TempPNEPILChangeLine);
        if TempPNEPILChangeLine.FindSet() then
            repeat
                if TempPNEPILChangeLine."Quantity Difference" > QuantityTolerance() then begin
                    MoreworkLineCount += 1;
                    TotalMoreworkQuantity += TempPNEPILChangeLine."Quantity Difference";
                    TotalEstimatedCostDifference += TempPNEPILChangeLine."Estimated Cost Difference";
                end else
                    if TempPNEPILChangeLine."Quantity Difference" < -QuantityTolerance() then begin
                        LessworkLineCount += 1;
                        TotalLessworkQuantity += Abs(TempPNEPILChangeLine."Quantity Difference");
                        TotalEstimatedCostDifference += TempPNEPILChangeLine."Estimated Cost Difference";
                    end;
            until TempPNEPILChangeLine.Next() = 0;
    end;

    local procedure BuildCommercialAggregates(PNEPILHeader: Record "PNE PIL Header"; var TempPNEPILChangeLine: Record "PNE PIL Change Line" temporary)
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        CommercialGroupLineNos: Dictionary of [Text, Integer];
        CommercialGroupKey: Text;
        CommercialGroupLineNo: Integer;
        NextCommercialGroupLineNo: Integer;
    begin
        TempPNEPILChangeLine.Reset();
        TempPNEPILChangeLine.DeleteAll();
        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILChangeLine.FindSet() then
            repeat
                if not IsDirectComponentChangeLine(PNEPILChangeLine) then begin
                    CommercialGroupKey := GetCommercialGroupKey(PNEPILChangeLine);
                    if not CommercialGroupLineNos.Get(CommercialGroupKey, CommercialGroupLineNo) then begin
                        NextCommercialGroupLineNo += 1;
                        CommercialGroupLineNo := NextCommercialGroupLineNo;
                        CommercialGroupLineNos.Add(CommercialGroupKey, CommercialGroupLineNo);
                        TempPNEPILChangeLine.Init();
                        TempPNEPILChangeLine."Header Entry No." := PNEPILHeader."Entry No.";
                        TempPNEPILChangeLine."Line No." := CommercialGroupLineNo;
                        TempPNEPILChangeLine."Carrier Item No." := PNEPILChangeLine."Carrier Item No.";
                        TempPNEPILChangeLine."Carrier Variant Code" := PNEPILChangeLine."Carrier Variant Code";
                        TempPNEPILChangeLine."Carrier Description" := PNEPILChangeLine."Carrier Description";
                        TempPNEPILChangeLine."Unit of Measure Code" := PNEPILChangeLine."Unit of Measure Code";
                        TempPNEPILChangeLine.Insert();
                    end;
                    TempPNEPILChangeLine.Get(PNEPILHeader."Entry No.", CommercialGroupLineNo);
                    TempPNEPILChangeLine."Original Quantity" += PNEPILChangeLine."Original Quantity";
                    TempPNEPILChangeLine."Proposed Quantity" += PNEPILChangeLine."Proposed Quantity";
                    TempPNEPILChangeLine."Quantity Difference" :=
                        TempPNEPILChangeLine."Proposed Quantity" -
                        TempPNEPILChangeLine."Original Quantity";
                    TempPNEPILChangeLine."Estimated Cost Difference" +=
                        PNEPILChangeLine."Estimated Cost Difference";
                    TempPNEPILChangeLine.Modify();
                end;
            until PNEPILChangeLine.Next() = 0;
    end;

    local procedure GetCommercialGroupKey(PNEPILChangeLine: Record "PNE PIL Change Line"): Text
    begin
        exit(
            PadStr(PNEPILChangeLine."Carrier Item No.", MaxStrLen(PNEPILChangeLine."Carrier Item No.")) +
            PadStr(PNEPILChangeLine."Carrier Variant Code", MaxStrLen(PNEPILChangeLine."Carrier Variant Code")) +
            PadStr(PNEPILChangeLine."Unit of Measure Code", MaxStrLen(PNEPILChangeLine."Unit of Measure Code")));
    end;

    procedure IsDirectComponentChangeLine(PNEPILChangeLine: Record "PNE PIL Change Line"): Boolean
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILChangeLine."Header Entry No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Direct component addition");
        PNEPILTarget.SetRange("Carrier Status", PNEPILChangeLine."Carrier Status");
        PNEPILTarget.SetRange("Carrier Production Order No.", PNEPILChangeLine."Carrier Production Order No.");
        PNEPILTarget.SetRange("Carrier Order Line No.", PNEPILChangeLine."Carrier Order Line No.");
        PNEPILTarget.SetRange("PIL Item No.", PNEPILChangeLine."Carrier Item No.");
        exit(not PNEPILTarget.IsEmpty());
    end;

    local procedure IsMatchingSalesQuoteItemLine(PNEPILChangeLine: Record "PNE PIL Change Line"; SalesHeader: Record "Sales Header"; SalesLine: Record "Sales Line"): Boolean
    var
        ExpectedQuoteQuantity: Decimal;
    begin
        ExpectedQuoteQuantity := GetLinkedQuoteNetQuantity(PNEPILChangeLine);
        if (SalesLine.Type <> SalesLine.Type::Item) or
           (SalesLine.SystemId <> PNEPILChangeLine."Sales Quote Line SystemId") or
           (SalesLine.SystemModifiedAt <> PNEPILChangeLine."Sales Quote Line Modified At") or
           (SalesLine."No." <> PNEPILChangeLine."Carrier Item No.") or
           (SalesLine."Variant Code" <> PNEPILChangeLine."Carrier Variant Code") or
           (SalesLine."Unit of Measure Code" <> PNEPILChangeLine."Unit of Measure Code") or
           (SalesLine.Description <> PNEPILChangeLine."Quote Line Description") or
           (SalesHeader."Currency Code" <> PNEPILChangeLine."Quote Currency Code") or
           (Abs(SalesLine.Quantity - ExpectedQuoteQuantity) > QuantityTolerance()) or
           (Abs(SalesLine."Unit Price" - PNEPILChangeLine."Quote Unit Price") > QuantityTolerance()) or
           (Abs(SalesLine."Line Amount" - PNEPILChangeLine."Quote Line Amount") > QuantityTolerance())
        then
            exit(false);
        exit(true);
    end;

    local procedure GetLinkedQuoteNetQuantity(PNEPILChangeLine: Record "PNE PIL Change Line"): Decimal
    var
        LinkedPNEPILChangeLine: Record "PNE PIL Change Line";
        NetQuantity: Decimal;
    begin
        LinkedPNEPILChangeLine.SetRange("Header Entry No.", PNEPILChangeLine."Header Entry No.");
        LinkedPNEPILChangeLine.SetRange("Sales Quote No.", PNEPILChangeLine."Sales Quote No.");
        LinkedPNEPILChangeLine.SetRange("Sales Quote Line No.", PNEPILChangeLine."Sales Quote Line No.");
        LinkedPNEPILChangeLine.SetRange("Quote Reversed", false);
        if LinkedPNEPILChangeLine.FindSet() then
            repeat
                NetQuantity += LinkedPNEPILChangeLine."Quantity Difference";
            until LinkedPNEPILChangeLine.Next() = 0;
        exit(NetQuantity);
    end;

    local procedure SetActiveQuoteLinkFilter(var PNEPILChangeLine: Record "PNE PIL Change Line"; PNEPILHeader: Record "PNE PIL Header")
    begin
        PNEPILChangeLine.Reset();
        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILChangeLine.SetRange("Quote Reversed", false);
        PNEPILChangeLine.SetRange("Quote Link Released", false);
        PNEPILChangeLine.SetFilter("Sales Quote No.", '<>%1', '');
    end;

    local procedure SetCommerciallyLockedQuoteLinkFilter(var PNEPILChangeLine: Record "PNE PIL Change Line"; PNEPILHeader: Record "PNE PIL Header")
    begin
        PNEPILChangeLine.Reset();
        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILChangeLine.SetRange("Quote Reversed", false);
        PNEPILChangeLine.SetFilter("Sales Quote No.", '<>%1', '');
    end;

    local procedure GetQuoteLineKey(PNEPILChangeLine: Record "PNE PIL Change Line"): Text
    begin
        exit(PNEPILChangeLine."Sales Quote No." + '|' + Format(PNEPILChangeLine."Sales Quote Line No."));
    end;

    [TryFunction]
    local procedure TryGetActiveQuoteLinkStatus(PNEPILChangeLine: Record "PNE PIL Change Line"; var QuoteItemLineIsCurrent: Boolean; var QuoteTextIsCurrent: Boolean)
    begin
        GetActiveQuoteLinkStatus(PNEPILChangeLine, QuoteItemLineIsCurrent, QuoteTextIsCurrent);
    end;

    [TryFunction]
    local procedure TryIsActiveQuoteItemLinkCurrent(PNEPILChangeLine: Record "PNE PIL Change Line"; var QuoteLineIsCurrent: Boolean)
    begin
        QuoteLineIsCurrent := IsActiveQuoteItemLinkCurrent(PNEPILChangeLine);
    end;

    [TryFunction]
    local procedure TryHasExpectedSalesQuoteExtendedText(SalesHeader: Record "Sales Header"; SalesLine: Record "Sales Line"; var QuoteTextIsCurrent: Boolean)
    begin
        QuoteTextIsCurrent := HasExpectedSalesQuoteExtendedText(SalesHeader, SalesLine);
    end;

    [TryFunction]
    local procedure TryDetermineQuoteLinkState(PNEPILChangeLine: Record "PNE PIL Change Line"; var QuoteLinkState: Enum "PNE PIL Quote Link State")
    begin
        QuoteLinkState := DetermineQuoteLinkState(PNEPILChangeLine);
    end;

    [TryFunction]
    local procedure TryOpenSalesQuote(SalesQuoteNo: Code[20])
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.Get(SalesHeader."Document Type"::Quote, SalesQuoteNo);
        Page.Run(Page::"Sales Quote", SalesHeader);
    end;

    local procedure QuantityTolerance(): Decimal
    begin
        exit(0.00001);
    end;

    var
        AddNetToQuoteQst: Label 'Voeg het netto verschil toe aan offerte %1?\Meerwerk: %2 samengevoegde regel(s), totaal +%3.\Minderwerk: %4 samengevoegde regel(s), totaal -%5.\De netto technische kostenindicatie is %6. De app groepeert op artikel, variant en eenheid, maakt alleen nieuwe gewone artikelregels en wijzigt geen bestaande offerte- of configuratorregel. Geldige automatische artikelteksten voor Sales Quote worden met het netto aantal onder de nieuwe regel gezet.', Comment = '%1 = sales quote number, %2 = morework line count, %3 = total morework quantity, %4 = lesswork line count, %5 = total lesswork quantity, %6 = net technical cost indication';
        AlreadyAddedToQuoteErr: Label 'PIL-import %1 is al commercieel overgedragen of handmatig vrijgegeven. Controleer het auditdossier; dezelfde wijziging wordt niet nogmaals aan een offerte toegevoegd.', Comment = '%1 = import entry number';
        AppliedProposalCannotReverseErr: Label 'PIL-import %1 is al toegepast op de productieorder. De offerte-overdracht kan niet meer automatisch worden teruggedraaid; beoordeel de offerte handmatig.', Comment = '%1 = import entry number';
        MultipleActiveSalesQuotesErr: Label 'PIL-import %1 heeft actieve koppelingen met meer dan één offerte en kan niet automatisch worden teruggedraaid.', Comment = '%1 = import entry number';
        NoActiveQuoteHandoffErr: Label 'PIL-import %1 heeft geen actieve offerte-overdracht om terug te draaien.', Comment = '%1 = import entry number';
        NoNetChangesErr: Label 'PIL-import %1 heeft na groepering geen netto carrierwijzigingen om aan een offerte toe te voegen.', Comment = '%1 = import entry number';
        OpenSalesQuoteErr: Label 'Offerte %1 kan met de huidige rechten niet worden geopend. Open de offerte via uw normale offertetoegang.', Comment = '%1 = sales quote number';
        PreparedQuoteHandoffQst: Label 'Deze PIL is technisch gecontroleerd, maar nog niet op de productieorder toegepast. De veiligste volgorde is eerst ''Pas veilig toe'' en daarna de offerte-overdracht. Tot Apply mag de aangemaakte offertregel niet worden gewijzigd, ook niet de prijs, en de offerte mag niet worden verwijderd of naar een order worden omgezet. Anders kan de koppeling niet meer automatisch worden gecontroleerd. Toch nu naar de offerte overdragen?';
        ProposalNotReadyErr: Label 'PIL-import %1 moet eerst klaar zijn voor toepassen voordat deze aan een offerte kan worden toegevoegd.', Comment = '%1 = import entry number';
        ProposalNotReadyForReleaseErr: Label 'PIL-import %1 moet gereed om toe te passen of al toegepast zijn voordat de commerciële koppeling kan worden vrijgegeven.', Comment = '%1 = import entry number';
        ProposalNotReadyForReversalErr: Label 'PIL-import %1 moet klaar zijn voor toepassen en nog niet zijn toegepast voordat de offerte-overdracht kan worden teruggedraaid.', Comment = '%1 = import entry number';
        QuantityPrefixLbl: Label '%1x ', Comment = '%1 = positive net item quantity';
        LessworkQuantityPrefixLbl: Label 'Minderwerk: %1x ', Comment = '%1 = absolute negative net item quantity';
        QuoteExtendedTextInsertErr: Label 'De artikeltekst van %1 kon niet volledig en controleerbaar aan de offerte worden toegevoegd. Er is niets overgedragen.', Comment = '%1 = item number';
        QuoteExpiredErr: Label 'Offerte %1 is verlopen op %2 en kan niet automatisch PIL-regels ontvangen of terugdraaien.', Comment = '%1 = sales quote number, %2 = valid-until date';
        QuoteLinkCannotBeVerifiedErr: Label 'Offerte %1, regel %2 kan met de huidige rechten niet worden gecontroleerd. Geef de beoordelaar normale leesrechten op offertregels of voer eerst een handmatige commerciële controle uit.', Comment = '%1 = sales quote number, %2 = sales quote line number';
        QuotedLineChangedErr: Label 'Offerte %1, regel %2 wijkt af van het PIL-voorstel. De app verandert of verwijdert deze regel niet automatisch; beoordeel hem handmatig.', Comment = '%1 = sales quote number, %2 = sales quote line number';
        QuotedTextChangedErr: Label 'De gekoppelde artikeltekst onder offerte %1, regel %2 is gewijzigd of volgt inmiddels een andere tekstinrichting. Technische Apply blijft mogelijk zolang de artikelregel zelf ongewijzigd is. Automatisch terugdraaien is geblokkeerd; beoordeel en corrigeer de offerte handmatig.', Comment = '%1 = sales quote number, %2 = sales quote line number';
        QuotedLineMissingErr: Label 'Offerte %1, regel %2 die aan dit PIL-voorstel is gekoppeld, bestaat niet meer.', Comment = '%1 = sales quote number, %2 = sales quote line number';
        ReversalReasonRequiredErr: Label 'Vul een reden in voordat u de offerte-overdracht terugdraait.';
        ReleaseQuoteLinkQst: Label 'Geef de commerciële koppeling van %1 technische regel(s) met offerte %2 vrij? De app wijzigt of verwijdert niets in verkoop. De reden en aangetroffen toestand worden blijvend vastgelegd. Deze PIL kan daarna niet nogmaals automatisch naar een offerte worden gestuurd.', Comment = '%1 = active PIL change line count, %2 = sales quote number';
        ResolutionReasonRequiredErr: Label 'Vul een reden in voordat u de commerciële koppeling vrijgeeft.';
        ReverseQuoteQst: Label 'Draai %1 door dit PIL-dossier aangemaakte artikelregel(s) op offerte %2 terug? Alleen ongewijzigde regels die deze app zelf heeft toegevoegd, worden verwijderd. De opgegeven reden blijft in de audit bewaard.', Comment = '%1 = active PIL change line count, %2 = sales quote number';
}
