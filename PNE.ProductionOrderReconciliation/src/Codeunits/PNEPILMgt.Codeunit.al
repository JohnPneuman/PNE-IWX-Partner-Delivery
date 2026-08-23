namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Setup;

codeunit 50178 "PNE PIL Mgt."
{
    Permissions = tabledata "PNE PIL Group" = r,
                  tabledata "PNE PIL Group Item" = r,
                  tabledata "PNE PIL Header" = rim,
                  tabledata "PNE PIL Line" = rim,
                  tabledata "PNE PIL Target" = rimd,
                  tabledata "PNE PIL Change Line" = rimd,
                  tabledata "Production Order" = r,
                  tabledata "Prod. Order Line" = rim,
                  tabledata "Prod. Order Component" = rimd,
                  tabledata "Prod. Order Routing Line" = rm,
                  tabledata "Capacity Ledger Entry" = r,
                  tabledata "Capacity Unit of Measure" = r,
                  tabledata "Manufacturing Setup" = r,
                  tabledata "Production BOM Header" = r,
                  tabledata "Production BOM Line" = r,
                  tabledata "Production BOM Version" = r,
                  tabledata "Reservation Entry" = r,
                  tabledata "Item Journal Line" = r,
                  tabledata Item = rm,
                  tabledata "Item Unit of Measure" = r,
                  tabledata "Stockkeeping Unit" = r;

    procedure Prepare(var PNEPILHeader: Record "PNE PIL Header")
    begin
        CheckHeader(PNEPILHeader);
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AlreadyAppliedErr, PNEPILHeader."Entry No.");
        AssertProposalNotTransferred(PNEPILHeader);
        ClearReview(PNEPILHeader);
        BuildStructuralTargets(PNEPILHeader);
        RecalculateTargetQuantities(PNEPILHeader);
        RefreshPILCoverage(PNEPILHeader);
        BuildUniqueExistingPointCarrierTargets(PNEPILHeader);
        RecalculateTargetQuantities(PNEPILHeader);
        RefreshPILCoverage(PNEPILHeader);
        EnsureNoAmbiguousStructuralCALCRoutes(PNEPILHeader);
        BuildCALCTargets(PNEPILHeader);
        EnsureNoExistingActualPILComponentsForCALCTargets(PNEPILHeader);
        UpdateLineResolutions(PNEPILHeader);
        EnsureNoBlockingPositivePILLines(PNEPILHeader);
        RefreshAllocations(PNEPILHeader);
        BuildChangeLines(PNEPILHeader);
    end;

    procedure CheckAllocations(var PNEPILHeader: Record "PNE PIL Header")
    begin
        CheckHeader(PNEPILHeader);
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AlreadyAppliedErr, PNEPILHeader."Entry No.");
        AssertProposalNotTransferred(PNEPILHeader);
        RefreshPILCoverage(PNEPILHeader);
        RecalculateTargetQuantities(PNEPILHeader);
        RefreshPILCoverage(PNEPILHeader);
        UpdateLineResolutions(PNEPILHeader);
        EnsureNoBlockingPositivePILLines(PNEPILHeader);
        RefreshAllocations(PNEPILHeader);
        EnsureNoExistingActualPILComponentsForCALCTargets(PNEPILHeader);
        BuildChangeLines(PNEPILHeader);
    end;

    procedure GetAllocationStatusMessage(PNEPILHeader: Record "PNE PIL Header"): Text
    var
        PNEPILLine: Record "PNE PIL Line";
        PNEPILTarget: Record "PNE PIL Target";
        AllocatedQuantity: Decimal;
        RequiredQuantity: Decimal;
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet() then
            repeat
                if IsBlockingPositivePILLine(PNEPILLine) then
                    exit(
                        StrSubstNo(
                            BlockingPILLineStatusTxt,
                            PNEPILLine."Item No.",
                            PNEPILLine.Resolution));
            until PNEPILLine.Next() = 0;

        PNEPILLine.Reset();
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet() then
            repeat
                RequiredQuantity := GetRequiredAllocation(PNEPILHeader, PNEPILLine);
                AllocatedQuantity := GetAllocatedQuantity(PNEPILHeader, PNEPILLine);
                if Abs(RequiredQuantity - AllocatedQuantity) > QuantityTolerance() then
                    exit(
                        StrSubstNo(
                            IncompleteAllocationStatusTxt,
                            PNEPILLine."Item No.",
                            RequiredQuantity,
                            AllocatedQuantity,
                            RequiredQuantity - AllocatedQuantity));
            until PNEPILLine.Next() = 0;

        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("Carrier Quantity Conflict", true);
        PNEPILTarget.SetRange("Carrier Qty. Choice Active", false);
        if PNEPILTarget.FindFirst() then
            exit(
                StrSubstNo(
                    CarrierConflictStatusTxt,
                    PNEPILTarget."Carrier Item No.",
                    GetCarrierPILDetails(PNEPILTarget)));

        exit(AllocationRequiredStatusTxt);
    end;

    procedure ChooseCarrierQuantity(var PNEPILTarget: Record "PNE PIL Target"; ChosenCarrierQuantity: Decimal; ChoiceReason: Text)
    var
        CarrierPNEPILTarget: Record "PNE PIL Target";
        PNEPILHeader: Record "PNE PIL Header";
    begin
        PNEPILTarget.Get(PNEPILTarget."Header Entry No.", PNEPILTarget."Line No.");
        PNEPILHeader.Get(PNEPILTarget."Header Entry No.");
        CheckHeader(PNEPILHeader);
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AlreadyAppliedErr, PNEPILHeader."Entry No.");
        AssertProposalNotTransferred(PNEPILHeader);
        if not PNEPILTarget."Carrier Quantity Conflict" then
            Error(NoCarrierQuantityConflictErr, PNEPILTarget."Carrier Item No.");
        if ChosenCarrierQuantity < 0 then
            Error(NegativeCarrierQuantityChoiceErr);
        if Abs(ChosenCarrierQuantity - Round(ChosenCarrierQuantity, 1, '=')) > QuantityTolerance() then
            Error(CarrierQuantityChoiceNotWholeErr);
        if DelChr(ChoiceReason, '<>', ' ') = '' then
            Error(CarrierQuantityChoiceReasonErr);

        SetCarrierTargetFilter(CarrierPNEPILTarget, PNEPILTarget);
        CarrierPNEPILTarget.SetFilter(
            Kind,
            '%1|%2',
            CarrierPNEPILTarget.Kind::"Structural driver",
            CarrierPNEPILTarget.Kind::"CALC replacement");
        if CarrierPNEPILTarget.FindSet(true) then
            repeat
                CarrierPNEPILTarget."Carrier Qty. Choice Active" := true;
                CarrierPNEPILTarget."Chosen Carrier Quantity" := ChosenCarrierQuantity;
                CarrierPNEPILTarget."Carrier Qty. Choice Reason" :=
                    CopyStr(ChoiceReason, 1, MaxStrLen(CarrierPNEPILTarget."Carrier Qty. Choice Reason"));
                CarrierPNEPILTarget."Carrier Qty. Chosen By" :=
                    CopyStr(UserId(), 1, MaxStrLen(CarrierPNEPILTarget."Carrier Qty. Chosen By"));
                CarrierPNEPILTarget."Carrier Qty. Chosen At" := CurrentDateTime();
                CarrierPNEPILTarget.Modify(true);
            until CarrierPNEPILTarget.Next() = 0;

        if PNEPILHeader.Status <> PNEPILHeader.Status::"Allocation Required" then begin
            PNEPILHeader.Status := PNEPILHeader.Status::"Allocation Required";
            Clear(PNEPILHeader."Prepared At");
            PNEPILHeader.Modify(true);
        end;
        RefreshAllocations(PNEPILHeader);
        BuildChangeLines(PNEPILHeader);
        PNEPILTarget.Get(PNEPILTarget."Header Entry No.", PNEPILTarget."Line No.");
    end;

    procedure RecalculateOrderRoutingHours(var ProductionOrder: Record "Production Order")
    var
        ManufacturingSetup: Record "Manufacturing Setup";
        ProdOrderComponent: Record "Prod. Order Component";
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
        RoutingOwnerProdOrderLine: Record "Prod. Order Line";
        CurrentRoutingLinks: Dictionary of [Text, Decimal];
        CurrentRoutingHours: Dictionary of [Text, Decimal];
        RoutingLinksToRecalculate: Dictionary of [Text, Decimal];
        RoutingHours: Dictionary of [Text, Decimal];
        CapacityUnitOfMeasureCode: Code[10];
        RoutingPreview: Text[2048];
        RoutingImpactSummary: Text;
    begin
        if not (ProductionOrder.Status in [
            ProductionOrder.Status::Simulated,
            ProductionOrder.Status::"Firm Planned",
            ProductionOrder.Status::Released])
        then
            Error(UnsupportedOrderStatusErr, ProductionOrder."No.");
        if not FindOrderLevelRoutingOwnerForOrder(
             ProductionOrder.Status,
             ProductionOrder."No.",
             RoutingOwnerProdOrderLine)
        then
            Error(AmbiguousOrderRoutingOwnerErr, ProductionOrder."No.");
        CheckOrderRoutingRecalculationSafety(ProductionOrder);
        ManufacturingSetup.Get();
        ManufacturingSetup.TestField("Show Capacity In");
        CapacityUnitOfMeasureCode := ManufacturingSetup."Show Capacity In";
        GetCapacityTimeFactor(CapacityUnitOfMeasureCode);
        CollectRoutingHoursPerOutput(
            RoutingOwnerProdOrderLine,
            CapacityUnitOfMeasureCode,
            RoutingHours);
        CollectActiveRoutingLinksForOwner(
            RoutingOwnerProdOrderLine,
            CapacityUnitOfMeasureCode,
            RoutingLinksToRecalculate);
        if (RoutingHours.Count() = 0) and (RoutingLinksToRecalculate.Count() = 0) then begin
            Message(NoOrderRoutingHoursFoundMsg, ProductionOrder."No.");
            exit;
        end;
        RoutingPreview := BuildOrderRoutingHoursPreview(
            RoutingOwnerProdOrderLine,
            RoutingLinksToRecalculate,
            RoutingHours,
            CapacityUnitOfMeasureCode);
        if not HasActiveRoutingHourDifference(RoutingLinksToRecalculate, RoutingHours) then begin
            Message(NoRoutingHourAdjustmentTxt);
            exit;
        end;
        if not Confirm(
             RecalculateOrderRoutingHoursQst,
             false,
             ProductionOrder."No.",
             RoutingPreview)
        then
            exit;

        ProdOrderLine.LockTable();
        ProdOrderComponent.LockTable();
        ProdOrderRoutingLine.LockTable();
        ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.");
        if not FindOrderLevelRoutingOwnerForOrder(
             ProductionOrder.Status,
             ProductionOrder."No.",
             RoutingOwnerProdOrderLine)
        then
            Error(AmbiguousOrderRoutingOwnerErr, ProductionOrder."No.");
        CheckOrderRoutingRecalculationSafety(ProductionOrder);
        CollectRoutingHoursPerOutput(
            RoutingOwnerProdOrderLine,
            CapacityUnitOfMeasureCode,
            CurrentRoutingHours);
        CollectActiveRoutingLinksForOwner(
            RoutingOwnerProdOrderLine,
            CapacityUnitOfMeasureCode,
            CurrentRoutingLinks);
        if not DecimalDictionariesEqual(RoutingHours, CurrentRoutingHours) or
           not DecimalDictionariesEqual(RoutingLinksToRecalculate, CurrentRoutingLinks)
        then
            Error(RoutingChangedAfterPreviewErr, ProductionOrder."No.");

        ApplyRoutingHourChangesForOwner(
            RoutingOwnerProdOrderLine,
            CurrentRoutingLinks,
            CurrentRoutingHours,
            CapacityUnitOfMeasureCode,
            true,
            RoutingImpactSummary);
        if RoutingImpactSummary = '' then
            RoutingImpactSummary := NoRoutingHourAdjustmentTxt;
        RecalculateProductionOrderRouting(RoutingOwnerProdOrderLine);
        Message(
            OrderRoutingHoursRecalculatedMsg,
            RoutingOwnerProdOrderLine."Item No.",
            ProductionOrder."No.",
            RoutingImpactSummary);
    end;

    local procedure BuildOrderRoutingHoursPreview(RoutingOwnerProdOrderLine: Record "Prod. Order Line"; RoutingLinksToRecalculate: Dictionary of [Text, Decimal]; RoutingHours: Dictionary of [Text, Decimal]; CapacityUnitOfMeasureCode: Code[10]): Text[2048]
    var
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
        RoutingHourKey: Text;
        RoutingHourKeys: List of [Text];
        PreviewRoutingLinks: Dictionary of [Text, Decimal];
        RoutingOwnerPrefix: Text;
        RoutingLinkCode: Code[10];
        LotSize: Decimal;
        CurrentQuantityPerOutput: Decimal;
        NewQuantityPerOutput: Decimal;
        DisplayedLinkCount: Integer;
        PreviewText: Text[2048];
    begin
        RoutingOwnerPrefix := GetRoutingHourOwnerPrefix(RoutingOwnerProdOrderLine);
        AddRoutingHourKeysForOwner(
            RoutingLinksToRecalculate,
            RoutingOwnerPrefix,
            PreviewRoutingLinks);
        AddRoutingHourKeysForOwner(
            RoutingHours,
            RoutingOwnerPrefix,
            PreviewRoutingLinks);
        RoutingHourKeys := PreviewRoutingLinks.Keys();
        foreach RoutingHourKey in RoutingHourKeys do begin
            RoutingLinkCode := CopyStr(
                RoutingHourKey,
                StrLen(RoutingOwnerPrefix) + 1,
                MaxStrLen(RoutingLinkCode));
            GetUniqueProductionOrderRoutingLine(
                RoutingOwnerProdOrderLine,
                RoutingLinkCode,
                ProdOrderRoutingLine);

            LotSize := ProdOrderRoutingLine."Lot Size";
            if LotSize = 0 then
                LotSize := 1;
            CurrentQuantityPerOutput := ConvertCapacityQuantity(
                ProdOrderRoutingLine."Run Time" / LotSize,
                ProdOrderRoutingLine."Run Time Unit of Meas. Code",
                CapacityUnitOfMeasureCode);
            NewQuantityPerOutput := GetDecimalDictionaryValue(RoutingHours, RoutingHourKey);
            DisplayedLinkCount += 1;
            if ProdOrderRoutingLine."Run Time" <= QuantityTolerance() then
                AppendInactiveRoutingPreviewLine(
                    PreviewText,
                    RoutingLinkCode,
                    NewQuantityPerOutput,
                    CapacityUnitOfMeasureCode,
                    DisplayedLinkCount)
            else
                AppendRoutingPreviewLine(
                    PreviewText,
                    RoutingLinkCode,
                    CurrentQuantityPerOutput,
                    NewQuantityPerOutput,
                    CapacityUnitOfMeasureCode,
                    DisplayedLinkCount);
        end;
        exit(PreviewText);
    end;

    local procedure AddRoutingHourKeysForOwner(SourceRoutingHours: Dictionary of [Text, Decimal]; RoutingOwnerPrefix: Text; var TargetRoutingLinks: Dictionary of [Text, Decimal])
    var
        RoutingHourKey: Text;
        RoutingHourKeys: List of [Text];
    begin
        RoutingHourKeys := SourceRoutingHours.Keys();
        foreach RoutingHourKey in RoutingHourKeys do
            if (CopyStr(RoutingHourKey, 1, StrLen(RoutingOwnerPrefix)) = RoutingOwnerPrefix) and
               not TargetRoutingLinks.ContainsKey(RoutingHourKey)
            then
                TargetRoutingLinks.Add(RoutingHourKey, 0);
    end;

    local procedure HasActiveRoutingHourDifference(CurrentRoutingHours: Dictionary of [Text, Decimal]; ProposedRoutingHours: Dictionary of [Text, Decimal]): Boolean
    var
        RoutingHourKey: Text;
        RoutingHourKeys: List of [Text];
    begin
        RoutingHourKeys := CurrentRoutingHours.Keys();
        foreach RoutingHourKey in RoutingHourKeys do
            if Abs(
                 GetDecimalDictionaryValue(CurrentRoutingHours, RoutingHourKey) -
                 GetDecimalDictionaryValue(ProposedRoutingHours, RoutingHourKey)) > QuantityTolerance()
            then
                exit(true);
        exit(false);
    end;

    local procedure AppendRoutingPreviewLine(var PreviewText: Text[2048]; RoutingLinkCode: Code[10]; CurrentQuantityPerOutput: Decimal; NewQuantityPerOutput: Decimal; CapacityUnitOfMeasureCode: Code[10]; DisplayedLinkCount: Integer)
    var
        NewPreviewLine: Text;
    begin
        if DisplayedLinkCount > MaximumRoutingPreviewLines() then begin
            if DisplayedLinkCount = MaximumRoutingPreviewLines() + 1 then
                AppendRoutingPreviewText(PreviewText, RoutingPreviewTruncatedTxt);
            exit;
        end;
        NewPreviewLine := StrSubstNo(
            RoutingPreviewLineTxt,
            RoutingLinkCode,
            CurrentQuantityPerOutput,
            NewQuantityPerOutput,
            NewQuantityPerOutput - CurrentQuantityPerOutput,
            CapacityUnitOfMeasureCode);
        AppendRoutingPreviewText(PreviewText, NewPreviewLine);
    end;

    local procedure AppendInactiveRoutingPreviewLine(var PreviewText: Text[2048]; RoutingLinkCode: Code[10]; CalculatedQuantityPerOutput: Decimal; CapacityUnitOfMeasureCode: Code[10]; DisplayedLinkCount: Integer)
    var
        NewPreviewLine: Text;
    begin
        if DisplayedLinkCount > MaximumRoutingPreviewLines() then begin
            if DisplayedLinkCount = MaximumRoutingPreviewLines() + 1 then
                AppendRoutingPreviewText(PreviewText, RoutingPreviewTruncatedTxt);
            exit;
        end;
        NewPreviewLine := StrSubstNo(
            InactiveRoutingPreviewLineTxt,
            RoutingLinkCode,
            CalculatedQuantityPerOutput,
            CapacityUnitOfMeasureCode);
        AppendRoutingPreviewText(PreviewText, NewPreviewLine);
    end;

    local procedure AppendRoutingPreviewText(var PreviewText: Text[2048]; NewPreviewLine: Text)
    var
        LineFeed: Char;
        RequiredLength: Integer;
    begin
        LineFeed := 10;
        RequiredLength := StrLen(NewPreviewLine);
        if PreviewText <> '' then
            RequiredLength += 1;
        if StrLen(PreviewText) + RequiredLength > MaxStrLen(PreviewText) then
            exit;
        if PreviewText <> '' then
            PreviewText += LineFeed;
        PreviewText += NewPreviewLine;
    end;

    local procedure MaximumRoutingPreviewLines(): Integer
    begin
        exit(15);
    end;

    local procedure MaximumRoutingImpactSummaryLength(): Integer
    begin
        exit(2048);
    end;

    procedure Apply(var PNEPILHeader: Record "PNE PIL Header"; var RoutingImpactSummary: Text)
    var
        ItemJournalLine: Record "Item Journal Line";
        ProdOrderComponent: Record "Prod. Order Component";
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
        PNEPILTarget: Record "PNE PIL Target";
        TempRoutingOwnerProdOrderLine: Record "Prod. Order Line" temporary;
        RoutingHoursBefore: Dictionary of [Text, Decimal];
        CapacityUnitOfMeasureCode: Code[10];
    begin
        Clear(RoutingImpactSummary);
        CheckHeader(PNEPILHeader);
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AlreadyAppliedErr, PNEPILHeader."Entry No.");

        PNEPILHeader.LockTable();
        ProdOrderLine.LockTable();
        ProdOrderComponent.LockTable();
        ProdOrderRoutingLine.LockTable();
        ItemJournalLine.LockTable();
        PNEPILTarget.LockTable();

        PNEPILHeader.Get(PNEPILHeader."Entry No.");
        if PNEPILHeader.Status <> PNEPILHeader.Status::Prepared then
            Error(ProposalMustBeCheckedErr, PNEPILHeader."Entry No.");
        RefreshAllocations(PNEPILHeader);
        EnsureProposalCurrentForCommercialHandoff(PNEPILHeader);
        if not HasNoProductionChanges(PNEPILHeader) then begin
            CaptureRoutingHourSnapshot(
                PNEPILHeader,
                TempRoutingOwnerProdOrderLine,
                RoutingHoursBefore,
                CapacityUnitOfMeasureCode);
            UpdateCarrierQuantities(PNEPILHeader);
            ReplaceCALCComponents(PNEPILHeader);
            AddDirectPILComponents(PNEPILHeader);
            AddPointCarrierPILComponents(PNEPILHeader);
            ApplyRoutingHourChanges(
                TempRoutingOwnerProdOrderLine,
                RoutingHoursBefore,
                CapacityUnitOfMeasureCode,
                RoutingImpactSummary);
            RecalculateAffectedProductionOrderRouting(PNEPILHeader);
            OnAfterPILLiveChangesApplied(PNEPILHeader);
        end;

        PNEPILHeader.Status := PNEPILHeader.Status::Applied;
        PNEPILHeader."Applied At" := CurrentDateTime();
        PNEPILHeader."Applied By" := CopyStr(UserId(), 1, MaxStrLen(PNEPILHeader."Applied By"));
        PNEPILHeader.Modify(true);
    end;

    procedure EnsureProposalCurrentForCommercialHandoff(var PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILSalesQuoteMgt: Codeunit "PNE PIL Sales Quote Mgt.";
    begin
        CheckHeader(PNEPILHeader);
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AlreadyAppliedErr, PNEPILHeader."Entry No.");
        if PNEPILHeader.Status <> PNEPILHeader.Status::Prepared then
            Error(AllocationRequiredErr, PNEPILHeader."Entry No.");

        EnsureNoBlockingPositivePILLines(PNEPILHeader);
        if not AllAllocationsComplete(PNEPILHeader) then
            Error(AllocationRequiredErr, PNEPILHeader."Entry No.");
        CheckCarrierQuantityConsistency(PNEPILHeader);
        CheckApplySafety(PNEPILHeader);
        CheckQuotedProposalStillMatchesTargets(PNEPILHeader);
        if PNEPILSalesQuoteMgt.HasActiveQuoteHandoff(PNEPILHeader) then
            PNEPILSalesQuoteMgt.EnsureActiveQuoteLinksCurrent(PNEPILHeader);
    end;

    procedure SetPILLineIgnore(var PNEPILLine: Record "PNE PIL Line"; IgnoreReason: Text)
    var
        PNEPILHeader: Record "PNE PIL Header";
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILLine.Get(PNEPILLine."Header Entry No.", PNEPILLine."Line No.");
        PNEPILHeader.Get(PNEPILLine."Header Entry No.");
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AlreadyAppliedErr, PNEPILHeader."Entry No.");
        if PNEPILLine.Quantity <= QuantityTolerance() then
            Error(ZeroQuantityCannotBeIgnoredErr, PNEPILLine."Item No.");
        if PNEPILLine."Group Code" <> '' then
            Error(MappedPILLineCannotBeIgnoredErr, PNEPILLine."Item No.");
        if (PNEPILLine."Covered Quantity" > QuantityTolerance()) or
           (PNEPILLine.Resolution = CoveredByDriverTxt)
        then
            Error(CoveredPILLineCannotBeIgnoredErr, PNEPILLine."Item No.", PNEPILLine."Covered By Item No.");
        PNEPILTarget.SetRange("Header Entry No.", PNEPILLine."Header Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", PNEPILLine."Line No.");
        if not PNEPILTarget.IsEmpty() then
            Error(ResolvedPILLineCannotBeIgnoredErr, PNEPILLine."Item No.");
        if DelChr(IgnoreReason, '<>', ' ') = '' then
            Error(IgnoreReasonRequiredErr, PNEPILLine."Item No.");

        PNEPILLine."Ignore for Reconciliation" := true;
        PNEPILLine."Ignore Reason" := CopyStr(IgnoreReason, 1, MaxStrLen(PNEPILLine."Ignore Reason"));
        PNEPILLine."Ignored By" := CopyStr(UserId(), 1, MaxStrLen(PNEPILLine."Ignored By"));
        PNEPILLine."Ignored At" := CurrentDateTime();
        PNEPILLine.Resolution := IgnoredByUserTxt;
        PNEPILLine.Modify(true);

        if PNEPILHeader.Status = PNEPILHeader.Status::Prepared then begin
            PNEPILHeader.Status := PNEPILHeader.Status::"Allocation Required";
            Clear(PNEPILHeader."Prepared At");
            PNEPILHeader.Modify(true);
        end;
    end;

    procedure RestorePILLine(var PNEPILLine: Record "PNE PIL Line")
    var
        PNEPILHeader: Record "PNE PIL Header";
    begin
        PNEPILLine.Get(PNEPILLine."Header Entry No.", PNEPILLine."Line No.");
        PNEPILHeader.Get(PNEPILLine."Header Entry No.");
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AlreadyAppliedErr, PNEPILHeader."Entry No.");
        if not PNEPILLine."Ignore for Reconciliation" then
            exit;

        PNEPILLine."Ignore for Reconciliation" := false;
        Clear(PNEPILLine."Ignore Reason");
        Clear(PNEPILLine."Ignored By");
        Clear(PNEPILLine."Ignored At");
        Clear(PNEPILLine.Resolution);
        PNEPILLine.Modify(true);

        if PNEPILHeader.Status = PNEPILHeader.Status::Prepared then begin
            PNEPILHeader.Status := PNEPILHeader.Status::"Allocation Required";
            Clear(PNEPILHeader."Prepared At");
            PNEPILHeader.Modify(true);
        end;
    end;

    procedure AddPILLineAsDirectComponent(var PNEPILLine: Record "PNE PIL Line"; DestinationProdOrderLine: Record "Prod. Order Line")
    var
        PNEPILHeader: Record "PNE PIL Header";
    begin
        PNEPILHeader.Get(PNEPILLine."Header Entry No.");
        AddPILLineAsDirectComponentInternal(PNEPILLine, DestinationProdOrderLine, PNEPILHeader);
        FinalizeDirectComponentAssignments(PNEPILHeader);
    end;

    procedure AddSelectedPILLinesAsDirectComponents(var SelectedPNEPILLine: Record "PNE PIL Line"; DestinationProdOrderLine: Record "Prod. Order Line")
    var
        PNEPILHeader: Record "PNE PIL Header";
        HeaderEntryNo: Integer;
    begin
        if not SelectedPNEPILLine.FindSet() then
            exit;

        HeaderEntryNo := SelectedPNEPILLine."Header Entry No.";
        PNEPILHeader.Get(HeaderEntryNo);
        repeat
            if SelectedPNEPILLine."Header Entry No." <> HeaderEntryNo then
                Error(SelectedPILLinesDifferentHeadersErr);
            AddPILLineAsDirectComponentInternal(SelectedPNEPILLine, DestinationProdOrderLine, PNEPILHeader);
        until SelectedPNEPILLine.Next() = 0;
        FinalizeDirectComponentAssignments(PNEPILHeader);
    end;

    local procedure AddPILLineAsDirectComponentInternal(var PNEPILLine: Record "PNE PIL Line"; DestinationProdOrderLine: Record "Prod. Order Line"; PNEPILHeader: Record "PNE PIL Header")
    var
        ExistingProdOrderComponent: Record "Prod. Order Component";
        Item: Record Item;
        PNEPILTarget: Record "PNE PIL Target";
        RemainingPILQuantity: Decimal;
    begin
        PNEPILLine.Get(PNEPILLine."Header Entry No.", PNEPILLine."Line No.");
        if PNEPILLine."Header Entry No." <> PNEPILHeader."Entry No." then
            Error(SelectedPILLinesDifferentHeadersErr);
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AlreadyAppliedErr, PNEPILHeader."Entry No.");
        AssertProposalNotTransferred(PNEPILHeader);
        RemainingPILQuantity := PNEPILLine.Quantity - PNEPILLine."Covered Quantity";
        if (PNEPILLine.Quantity <= QuantityTolerance()) or
           (PNEPILLine."Group Code" <> '') or
           (RemainingPILQuantity <= QuantityTolerance()) or
           PNEPILLine."Ignore for Reconciliation"
        then
            Error(DirectComponentNotEligibleErr, PNEPILLine."Item No.");
        if not Item.Get(PNEPILLine."Item No.") then
            Error(PILItemNoLongerExistsErr, PNEPILLine."Item No.");
        if (Item."Base Unit of Measure" <> PiecesUnitOfMeasureLbl) or
           (Item."Production BOM No." <> '')
        then
            Error(DirectComponentItemNotSupportedErr, PNEPILLine."Item No.");
        if (DestinationProdOrderLine.Status <> PNEPILHeader."Production Order Status") or
           (DestinationProdOrderLine."Prod. Order No." <> PNEPILHeader."Production Order No.") then
            Error(DirectComponentWrongOrderErr);
        CheckProductionOrderLineUnitOfMeasure(DestinationProdOrderLine);

        ExistingProdOrderComponent.SetRange(Status, DestinationProdOrderLine.Status);
        ExistingProdOrderComponent.SetRange("Prod. Order No.", DestinationProdOrderLine."Prod. Order No.");
        ExistingProdOrderComponent.SetRange("Prod. Order Line No.", DestinationProdOrderLine."Line No.");
        ExistingProdOrderComponent.SetRange("Item No.", PNEPILLine."Item No.");
        if ExistingProdOrderComponent.Count() > 1 then
            Error(
                DirectComponentOccursMultipleTimesErr,
                PNEPILLine."Item No.",
                DestinationProdOrderLine."Item No.",
                ExistingProdOrderComponent.Count());

        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", PNEPILLine."Line No.");
        if not PNEPILTarget.IsEmpty() then
            Error(ResolvedPILLineCannotBeIgnoredErr, PNEPILLine."Item No.");

        PNEPILTarget.Init();
        PNEPILTarget."Header Entry No." := PNEPILHeader."Entry No.";
        PNEPILTarget."Line No." := GetNextTargetLineNo(PNEPILHeader);
        PNEPILTarget."PIL Line No." := PNEPILLine."Line No.";
        PNEPILTarget."PIL Item No." := PNEPILLine."Item No.";
        PNEPILTarget."PIL Item Description" := PNEPILLine.Description;
        PNEPILTarget."PIL Quantity" := PNEPILLine.Quantity;
        PNEPILTarget."Allocated PIL Quantity" := RemainingPILQuantity;
        PNEPILTarget.Kind := PNEPILTarget.Kind::"Direct component addition";
        PNEPILTarget."Carrier Type" := PNEPILTarget."Carrier Type"::"Production Order Line";
        PNEPILTarget."Carrier Status" := DestinationProdOrderLine.Status;
        PNEPILTarget."Carrier Production Order No." := DestinationProdOrderLine."Prod. Order No.";
        PNEPILTarget."Carrier Order Line No." := DestinationProdOrderLine."Line No.";
        PNEPILTarget."Carrier Item No." := DestinationProdOrderLine."Item No.";
        PNEPILTarget."Carrier Description" := DestinationProdOrderLine.Description;
        PNEPILTarget."Carrier SystemId" := DestinationProdOrderLine.SystemId;
        PNEPILTarget."Carrier Variant Code" := DestinationProdOrderLine."Variant Code";
        PNEPILTarget."Carrier Unit of Measure Code" := DestinationProdOrderLine."Unit of Measure Code";
        PNEPILTarget."Quantity per Carrier" := 1;
        PNEPILTarget."Original Carrier Quantity" := DestinationProdOrderLine.Quantity;
        PNEPILTarget."New Carrier Quantity" := DestinationProdOrderLine.Quantity;
        PNEPILTarget."Analysis Source" := PNEPILTarget."Analysis Source"::"Live Production Order";
        if ExistingProdOrderComponent.FindFirst() then begin
            CheckProductionOrderComponentUnitOfMeasure(ExistingProdOrderComponent);
            PNEPILTarget."Existing Actual PIL Quantity" := ExistingProdOrderComponent."Expected Quantity";
            PNEPILTarget."Existing Direct Comp. SystemId" := ExistingProdOrderComponent.SystemId;
            PNEPILTarget."Existing Direct Comp. Line No." := ExistingProdOrderComponent."Line No.";
        end;
        PNEPILTarget.Resolution := DirectComponentAdditionTxt;
        PNEPILTarget.Insert(true);
    end;

    local procedure FinalizeDirectComponentAssignments(var PNEPILHeader: Record "PNE PIL Header")
    begin
        UpdateLineResolutions(PNEPILHeader);
        RefreshAllocations(PNEPILHeader);
        BuildChangeLines(PNEPILHeader);
    end;

    procedure GetMatchingPointCarrierComponents(PNEPILHeader: Record "PNE PIL Header"; PILItemNo: Code[20]; var TempProdOrderComponent: Record "Prod. Order Component" temporary)
    var
        ContainingProductionBOMNos: Dictionary of [Code[20], Boolean];
    begin
        TempProdOrderComponent.DeleteAll();
        BuildContainingProductionBOMNosForOrder(
            PNEPILHeader,
            PILItemNo,
            ContainingProductionBOMNos);
        CollectMatchingPointCarrierComponents(
            PNEPILHeader,
            PILItemNo,
            ContainingProductionBOMNos,
            TempProdOrderComponent);
    end;

    local procedure CollectMatchingPointCarrierComponents(PNEPILHeader: Record "PNE PIL Header"; PILItemNo: Code[20]; ContainingProductionBOMNos: Dictionary of [Code[20], Boolean]; var TempProdOrderComponent: Record "Prod. Order Component" temporary)
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        ProdOrderComponent.SetRange(Status, PNEPILHeader."Production Order Status");
        ProdOrderComponent.SetRange("Prod. Order No.", PNEPILHeader."Production Order No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if IsPointCarrierItemNo(ProdOrderComponent."Item No.") and
                   (ProdOrderComponent."Unit of Measure Code" = PiecesUnitOfMeasureLbl) and
                   (Abs(ProdOrderComponent."Qty. per Unit of Measure" - 1) <= QuantityTolerance())
                then
                    if PointCarrierComponentContainsPILItem(
                         ProdOrderComponent,
                         PILItemNo,
                         ContainingProductionBOMNos)
                    then begin
                        TempProdOrderComponent := ProdOrderComponent;
                        TempProdOrderComponent.Insert();
                    end;
            until ProdOrderComponent.Next() = 0;
    end;

    procedure HasMatchingPointCarrier(PNEPILHeader: Record "PNE PIL Header"; PILItemNo: Code[20]): Boolean
    var
        TempItem: Record Item temporary;
    begin
        GetMatchingPointCarrierItems(PNEPILHeader, PILItemNo, TempItem);
        exit(not TempItem.IsEmpty());
    end;

    procedure GetMatchingPointCarrierItems(PNEPILHeader: Record "PNE PIL Header"; PILItemNo: Code[20]; var TempItem: Record Item temporary)
    var
        CandidateItem: Record Item;
        TempPointCarrierProdOrderComponent: Record "Prod. Order Component" temporary;
        ContainingProductionBOMNos: Dictionary of [Code[20], Boolean];
    begin
        TempItem.DeleteAll();
        BuildContainingProductionBOMNosForOrder(
            PNEPILHeader,
            PILItemNo,
            ContainingProductionBOMNos);

        CollectMatchingPointCarrierComponents(
            PNEPILHeader,
            PILItemNo,
            ContainingProductionBOMNos,
            TempPointCarrierProdOrderComponent);
        if TempPointCarrierProdOrderComponent.FindSet() then
            repeat
                if not TempItem.Get(TempPointCarrierProdOrderComponent."Item No.") then begin
                    CandidateItem.Get(TempPointCarrierProdOrderComponent."Item No.");
                    TempItem := CandidateItem;
                    TempItem.Insert();
                end;
            until TempPointCarrierProdOrderComponent.Next() = 0;

        CandidateItem.SetLoadFields(
            "No.",
            Description,
            Type,
            "Replenishment System",
            "Base Unit of Measure",
            "Production BOM No.");
        CandidateItem.SetRange(Type, CandidateItem.Type::Inventory);
        CandidateItem.SetRange("Replenishment System", CandidateItem."Replenishment System"::"Prod. Order");
        CandidateItem.SetRange("Base Unit of Measure", PiecesUnitOfMeasureLbl);
        CandidateItem.SetFilter("Production BOM No.", '<>%1', '');
        if CandidateItem.FindSet() then
            repeat
                if IsPointCarrierItemNo(CandidateItem."No.") then
                    if ContainingProductionBOMNos.ContainsKey(CandidateItem."Production BOM No.") then
                        if not TempItem.Get(CandidateItem."No.") then begin
                            TempItem := CandidateItem;
                            TempItem.Insert();
                        end;
            until CandidateItem.Next() = 0;
        AddDirectParentPointCarrierItems(
            PNEPILHeader,
            PILItemNo,
            TempItem);
        if TempItem.IsEmpty() then
            AddPointCarrierItemsByAuthoritativeBOMScan(
                PNEPILHeader,
                PILItemNo,
                TempItem);
    end;

    local procedure AddDirectParentPointCarrierItems(PNEPILHeader: Record "PNE PIL Header"; PILItemNo: Code[20]; var TempItem: Record Item temporary)
    var
        CandidateItem: Record Item;
        ProductionBOMLine: Record "Production BOM Line";
        CalculationDates: Dictionary of [Date, Boolean];
        ProductionBOMContainsItemCache: Dictionary of [Code[20], Boolean];
        ContainsPILItem: Boolean;
    begin
        GetProductionOrderCalculationDates(PNEPILHeader, CalculationDates);
        ProductionBOMLine.SetFilter(
            Type,
            '%1|%2',
            ProductionBOMLine.Type::Item,
            ProductionBOMLine.Type::"Production BOM");
        ProductionBOMLine.SetRange("No.", PILItemNo);
        if ProductionBOMLine.FindSet() then
            repeat
                AddRepairablePointCarrierItem(
                    ProductionBOMLine."Production BOM No.",
                    PILItemNo,
                    CalculationDates,
                    ProductionBOMContainsItemCache,
                    TempItem);
                CandidateItem.Reset();
                CandidateItem.SetLoadFields(
                    "No.",
                    Description,
                    Type,
                    "Replenishment System",
                    "Base Unit of Measure",
                    "Production BOM No.");
                CandidateItem.SetRange(Type, CandidateItem.Type::Inventory);
                CandidateItem.SetRange(
                    "Replenishment System",
                    CandidateItem."Replenishment System"::"Prod. Order");
                CandidateItem.SetRange("Base Unit of Measure", PiecesUnitOfMeasureLbl);
                CandidateItem.SetRange("Production BOM No.", ProductionBOMLine."Production BOM No.");
                if CandidateItem.FindSet() then
                    repeat
                        if IsPointCarrierItemNo(CandidateItem."No.") then begin
                            if not ProductionBOMContainsItemCache.Get(
                                 CandidateItem."Production BOM No.",
                                 ContainsPILItem)
                            then begin
                                ContainsPILItem := ProductionBOMContainsItemOnAnyOrderDate(
                                    CandidateItem."Production BOM No.",
                                    PILItemNo,
                                    CalculationDates);
                                ProductionBOMContainsItemCache.Add(
                                    CandidateItem."Production BOM No.",
                                    ContainsPILItem);
                            end;
                            if ContainsPILItem then
                                if not TempItem.Get(CandidateItem."No.") then begin
                                    TempItem := CandidateItem;
                                    TempItem.Insert();
                                end;
                        end;
                    until CandidateItem.Next() = 0;
            until ProductionBOMLine.Next() = 0;
    end;

    local procedure AddRepairablePointCarrierItem(ProductionBOMNo: Code[20]; PILItemNo: Code[20]; CalculationDates: Dictionary of [Date, Boolean]; var ProductionBOMContainsItemCache: Dictionary of [Code[20], Boolean]; var TempItem: Record Item temporary)
    var
        CandidateItem: Record Item;
        ContainsPILItem: Boolean;
    begin
        if not CandidateItem.Get(ProductionBOMNo) then
            exit;
        if not IsPointCarrierItemNo(CandidateItem."No.") or
           (CandidateItem.Type <> CandidateItem.Type::Inventory) or
           (CandidateItem."Replenishment System" <> CandidateItem."Replenishment System"::"Prod. Order") or
           (CandidateItem."Base Unit of Measure" <> PiecesUnitOfMeasureLbl)
        then
            exit;

        if not ProductionBOMContainsItemCache.Get(ProductionBOMNo, ContainsPILItem) then begin
            ContainsPILItem := ProductionBOMContainsItemOnAnyOrderDate(
                ProductionBOMNo,
                PILItemNo,
                CalculationDates);
            ProductionBOMContainsItemCache.Add(ProductionBOMNo, ContainsPILItem);
        end;
        if not ContainsPILItem or TempItem.Get(CandidateItem."No.") then
            exit;

        TempItem := CandidateItem;
        TempItem.Insert();
    end;

    procedure GetPointCarrierLinkStatus(PNEPILHeader: Record "PNE PIL Header"; PILItemNo: Code[20]; PointCarrierItem: Record Item): Text
    var
        CalculationDates: Dictionary of [Date, Boolean];
    begin
        GetProductionOrderCalculationDates(PNEPILHeader, CalculationDates);
        if (PointCarrierItem."Production BOM No." <> '') and
           ProductionBOMContainsItemOnAnyOrderDate(
                PointCarrierItem."Production BOM No.",
                PILItemNo,
                CalculationDates)
        then
            exit(PointCarrierLinkReadyTxt);

        if ProductionBOMContainsItemOnAnyOrderDate(
             PointCarrierItem."No.",
             PILItemNo,
             CalculationDates)
        then
            exit(StrSubstNo(PointCarrierLinkWillBeRepairedTxt, PointCarrierItem."No."));

        exit(PointCarrierLinkNeedsReviewTxt);
    end;

    procedure EnsurePointCarrierProductionBOMLink(PNEPILHeader: Record "PNE PIL Header"; PILItemNo: Code[20]; var PointCarrierItem: Record Item): Boolean
    var
        CalculationDates: Dictionary of [Date, Boolean];
        CurrentProductionBOMNoTxt: Text;
        OriginalProductionBOMNo: Code[20];
        ProposedProductionBOMNo: Code[20];
    begin
        PNEPILHeader.Get(PNEPILHeader."Entry No.");
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AlreadyAppliedErr, PNEPILHeader."Entry No.");
        AssertProposalNotTransferred(PNEPILHeader);

        PointCarrierItem.Get(PointCarrierItem."No.");
        GetProductionOrderCalculationDates(PNEPILHeader, CalculationDates);
        if (PointCarrierItem."Production BOM No." <> '') and
           ProductionBOMContainsItemOnAnyOrderDate(
                PointCarrierItem."Production BOM No.",
                PILItemNo,
                CalculationDates)
        then
            exit(true);

        ProposedProductionBOMNo := PointCarrierItem."No.";
        if not IsPointCarrierItemNo(PointCarrierItem."No.") or
           (PointCarrierItem.Type <> PointCarrierItem.Type::Inventory) or
           (PointCarrierItem."Replenishment System" <> PointCarrierItem."Replenishment System"::"Prod. Order") or
           (PointCarrierItem."Base Unit of Measure" <> PiecesUnitOfMeasureLbl) or
           not ProductionBOMContainsItemOnAnyOrderDate(
                ProposedProductionBOMNo,
                PILItemNo,
                CalculationDates)
        then
            Error(PointCarrierItemNotSupportedErr, PointCarrierItem."No.");

        OriginalProductionBOMNo := PointCarrierItem."Production BOM No.";
        CurrentProductionBOMNoTxt := OriginalProductionBOMNo;
        if CurrentProductionBOMNoTxt = '' then
            CurrentProductionBOMNoTxt := EmptyValueTxt;
        if not Confirm(
             RepairPointCarrierProductionBOMQst,
             false,
             PointCarrierItem."No.",
             CurrentProductionBOMNoTxt,
             ProposedProductionBOMNo,
             PILItemNo)
        then
            exit(false);

        PointCarrierItem.LockTable();
        PointCarrierItem.Get(PointCarrierItem."No.");
        if (PointCarrierItem."Production BOM No." <> '') and
           ProductionBOMContainsItemOnAnyOrderDate(
                PointCarrierItem."Production BOM No.",
                PILItemNo,
                CalculationDates)
        then
            exit(true);
        if PointCarrierItem."Production BOM No." <> OriginalProductionBOMNo then
            Error(PointCarrierLinkChangedDuringConfirmationErr, PointCarrierItem."No.");

        PointCarrierItem.Validate("Production BOM No.", ProposedProductionBOMNo);
        PointCarrierItem.Modify(true);
        PointCarrierItem.Get(PointCarrierItem."No.");
        exit(true);
    end;

    procedure GetPointCarrierLookupFailure(PNEPILHeader: Record "PNE PIL Header"; PILItemNo: Code[20]): Text
    var
        CandidateItem: Record Item;
        ProductionBOMLine: Record "Production BOM Line";
        CalculationDates: Dictionary of [Date, Boolean];
        CalculationDateList: List of [Date];
        CalculationDate: Date;
        ActualProductionBOMNo: Text;
    begin
        ProductionBOMLine.SetFilter(
            Type,
            '%1|%2',
            ProductionBOMLine.Type::Item,
            ProductionBOMLine.Type::"Production BOM");
        ProductionBOMLine.SetRange("No.", PILItemNo);
        if not ProductionBOMLine.FindFirst() then
            exit(StrSubstNo(NoPointCarrierRelationErr, PILItemNo));

        if not FindPointCarrierItemForProductionBOM(
             ProductionBOMLine."Production BOM No.",
             CandidateItem)
        then begin
            CandidateItem.Reset();
            if CandidateItem.Get(ProductionBOMLine."Production BOM No.") and
               IsPointCarrierItemNo(CandidateItem."No.")
            then begin
                ActualProductionBOMNo := CandidateItem."Production BOM No.";
                if ActualProductionBOMNo = '' then
                    ActualProductionBOMNo := EmptyValueTxt;
                exit(
                    StrSubstNo(
                        PointCarrierBOMFieldMismatchErr,
                        CandidateItem."No.",
                        ProductionBOMLine."Production BOM No.",
                        ActualProductionBOMNo));
            end;
            exit(
                StrSubstNo(
                    NoPointCarrierItemForBOMErr,
                    PILItemNo,
                    ProductionBOMLine."Production BOM No."));
        end;
        if CandidateItem.Type <> CandidateItem.Type::Inventory then
            exit(StrSubstNo(PointCarrierWrongTypeErr, CandidateItem."No."));
        if CandidateItem."Replenishment System" <>
           CandidateItem."Replenishment System"::"Prod. Order"
        then
            exit(StrSubstNo(PointCarrierWrongReplenishmentErr, CandidateItem."No."));
        if CandidateItem."Base Unit of Measure" <> PiecesUnitOfMeasureLbl then
            exit(
                StrSubstNo(
                    PointCarrierWrongUnitErr,
                    CandidateItem."No.",
                    CandidateItem."Base Unit of Measure"));

        GetProductionOrderCalculationDates(PNEPILHeader, CalculationDates);
        CalculationDateList := CalculationDates.Keys();
        foreach CalculationDate in CalculationDateList do
            if HasCertifiedProductionBOM(
                 CandidateItem."Production BOM No.",
                 CalculationDate,
                 '',
                 false)
            then
                exit(StrSubstNo(PointCarrierInactiveBOMLinesErr, CandidateItem."No.", PILItemNo));
        exit(
            StrSubstNo(
                PointCarrierBOMNotCertifiedForOrderErr,
                CandidateItem."No.",
                CandidateItem."Production BOM No."));
    end;

    local procedure FindPointCarrierItemForProductionBOM(ProductionBOMNo: Code[20]; var CandidateItem: Record Item): Boolean
    begin
        CandidateItem.Reset();
        CandidateItem.SetRange("Production BOM No.", ProductionBOMNo);
        if CandidateItem.FindSet() then
            repeat
                if IsPointCarrierItemNo(CandidateItem."No.") then
                    exit(true);
            until CandidateItem.Next() = 0;
        exit(false);
    end;

    local procedure PointCarrierComponentContainsPILItem(PointCarrierProdOrderComponent: Record "Prod. Order Component"; PILItemNo: Code[20]; ContainingProductionBOMNos: Dictionary of [Code[20], Boolean]): Boolean
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        if FindChildProdOrderLine(PointCarrierProdOrderComponent, ChildProdOrderLine) then begin
            if HasStructuralItemInLine(PILItemNo, ChildProdOrderLine, TempVisitedProdOrderLine) then
                exit(true);
            exit(ProductionOrderLineBOMContainsItem(ChildProdOrderLine, PILItemNo));
        end;

        exit(
            ContainingProductionBOMNos.ContainsKey(
                GetProductionBOMNoForComponent(PointCarrierProdOrderComponent)));
    end;

    local procedure BuildContainingProductionBOMNosForOrder(PNEPILHeader: Record "PNE PIL Header"; ItemNo: Code[20]; var ContainingProductionBOMNos: Dictionary of [Code[20], Boolean])
    var
        TempBridgeProductionBOMLine: Record "Production BOM Line" temporary;
        CalculationDates: Dictionary of [Date, Boolean];
        ContainingProductionBOMNosAtDate: Dictionary of [Code[20], Boolean];
        CalculationDate: Date;
        CalculationDateList: List of [Date];
        ProductionBOMNo: Code[20];
        ProductionBOMNosAtDate: List of [Code[20]];
    begin
        Clear(ContainingProductionBOMNos);
        GetProductionOrderCalculationDates(PNEPILHeader, CalculationDates);
        BuildItemProductionBOMBridgeIndex(TempBridgeProductionBOMLine);
        CalculationDateList := CalculationDates.Keys();
        foreach CalculationDate in CalculationDateList do begin
            Clear(ContainingProductionBOMNosAtDate);
            BuildContainingProductionBOMNos(
                ItemNo,
                CalculationDate,
                TempBridgeProductionBOMLine,
                ContainingProductionBOMNosAtDate);
            ProductionBOMNosAtDate := ContainingProductionBOMNosAtDate.Keys();
            foreach ProductionBOMNo in ProductionBOMNosAtDate do
                if not ContainingProductionBOMNos.ContainsKey(ProductionBOMNo) then
                    ContainingProductionBOMNos.Add(ProductionBOMNo, true);
        end;
    end;

    local procedure GetProductionOrderCalculationDates(PNEPILHeader: Record "PNE PIL Header"; var CalculationDates: Dictionary of [Date, Boolean])
    var
        ProdOrderLine: Record "Prod. Order Line";
        CalculationDate: Date;
    begin
        Clear(CalculationDates);
        ProdOrderLine.SetRange(Status, PNEPILHeader."Production Order Status");
        ProdOrderLine.SetRange("Prod. Order No.", PNEPILHeader."Production Order No.");
        if ProdOrderLine.FindSet() then
            repeat
                CalculationDate := GetCarrierCalculationDate(ProdOrderLine);
                if not CalculationDates.ContainsKey(CalculationDate) then
                    CalculationDates.Add(CalculationDate, true);
            until ProdOrderLine.Next() = 0;
        if CalculationDates.Count() = 0 then
            CalculationDates.Add(WorkDate(), true);
    end;

    local procedure BuildContainingProductionBOMNos(ItemNo: Code[20]; CalculationDate: Date; var TempBridgeProductionBOMLine: Record "Production BOM Line" temporary; var ContainingProductionBOMNos: Dictionary of [Code[20], Boolean])
    var
        Item: Record Item;
        ParentProductionBOMLine: Record "Production BOM Line";
        ProductionBOMLine: Record "Production BOM Line";
        ActiveVersionCodeCache: Dictionary of [Code[20], Code[20]];
        CertifiedProductionBOMCache: Dictionary of [Code[20], Boolean];
        ProductionBOMQueue: List of [Code[20]];
        ActiveVersionCode: Code[20];
        CurrentProductionBOMNo: Code[20];
        QueueIndex: Integer;
    begin
        Clear(ContainingProductionBOMNos);

        if GetCachedActiveCertifiedProductionBOMVersion(
             ItemNo,
             CalculationDate,
             CertifiedProductionBOMCache,
             ActiveVersionCodeCache,
             ActiveVersionCode)
        then
            AddProductionBOMToSearchQueue(
                ItemNo,
                ContainingProductionBOMNos,
                ProductionBOMQueue);

        if Item.Get(ItemNo) then
            if Item."Production BOM No." <> '' then
                if GetCachedActiveCertifiedProductionBOMVersion(
                     Item."Production BOM No.",
                     CalculationDate,
                     CertifiedProductionBOMCache,
                     ActiveVersionCodeCache,
                     ActiveVersionCode)
                then
                    AddProductionBOMToSearchQueue(
                        Item."Production BOM No.",
                        ContainingProductionBOMNos,
                        ProductionBOMQueue);

        ProductionBOMLine.SetFilter(
            Type,
            '%1|%2',
            ProductionBOMLine.Type::Item,
            ProductionBOMLine.Type::"Production BOM");
        ProductionBOMLine.SetRange("No.", ItemNo);
        if ProductionBOMLine.FindSet() then
            repeat
                if IsActiveCertifiedProductionBOMLine(
                     ProductionBOMLine,
                     CalculationDate,
                     CertifiedProductionBOMCache,
                     ActiveVersionCodeCache)
                then
                    AddProductionBOMToSearchQueue(
                        ProductionBOMLine."Production BOM No.",
                        ContainingProductionBOMNos,
                        ProductionBOMQueue);
            until ProductionBOMLine.Next() = 0;

        QueueIndex := 1;
        while QueueIndex <= ProductionBOMQueue.Count() do begin
            CurrentProductionBOMNo := ProductionBOMQueue.Get(QueueIndex);

            ParentProductionBOMLine.Reset();
            ParentProductionBOMLine.SetRange(Type, ParentProductionBOMLine.Type::"Production BOM");
            ParentProductionBOMLine.SetRange("No.", CurrentProductionBOMNo);
            if ParentProductionBOMLine.FindSet() then
                repeat
                    if IsActiveCertifiedProductionBOMLine(
                         ParentProductionBOMLine,
                         CalculationDate,
                         CertifiedProductionBOMCache,
                         ActiveVersionCodeCache)
                    then
                        AddProductionBOMToSearchQueue(
                            ParentProductionBOMLine."Production BOM No.",
                            ContainingProductionBOMNos,
                            ProductionBOMQueue);
                until ParentProductionBOMLine.Next() = 0;

            TempBridgeProductionBOMLine.Reset();
            TempBridgeProductionBOMLine.SetRange("Production BOM No.", CurrentProductionBOMNo);
            if TempBridgeProductionBOMLine.FindSet() then
                repeat
                    ParentProductionBOMLine.Reset();
                    ParentProductionBOMLine.SetRange(Type, ParentProductionBOMLine.Type::Item);
                    ParentProductionBOMLine.SetRange("No.", TempBridgeProductionBOMLine."No.");
                    if ParentProductionBOMLine.FindSet() then
                        repeat
                            if IsActiveCertifiedProductionBOMLine(
                                 ParentProductionBOMLine,
                                 CalculationDate,
                                 CertifiedProductionBOMCache,
                                 ActiveVersionCodeCache)
                            then
                                AddProductionBOMToSearchQueue(
                                    ParentProductionBOMLine."Production BOM No.",
                                    ContainingProductionBOMNos,
                                    ProductionBOMQueue);
                        until ParentProductionBOMLine.Next() = 0;
                until TempBridgeProductionBOMLine.Next() = 0;

            QueueIndex += 1;
        end;
    end;

    local procedure AddPointCarrierItemsByAuthoritativeBOMScan(PNEPILHeader: Record "PNE PIL Header"; PILItemNo: Code[20]; var TempItem: Record Item temporary)
    var
        CandidateItem: Record Item;
        CalculationDates: Dictionary of [Date, Boolean];
        ProductionBOMContainsItemCache: Dictionary of [Code[20], Boolean];
        ContainsPILItem: Boolean;
    begin
        GetProductionOrderCalculationDates(PNEPILHeader, CalculationDates);
        CandidateItem.SetLoadFields(
            "No.",
            Description,
            Type,
            "Replenishment System",
            "Base Unit of Measure",
            "Production BOM No.");
        CandidateItem.SetRange(Type, CandidateItem.Type::Inventory);
        CandidateItem.SetRange("Replenishment System", CandidateItem."Replenishment System"::"Prod. Order");
        CandidateItem.SetRange("Base Unit of Measure", PiecesUnitOfMeasureLbl);
        CandidateItem.SetFilter("Production BOM No.", '<>%1', '');
        if CandidateItem.FindSet() then
            repeat
                if IsPointCarrierItemNo(CandidateItem."No.") then begin
                    if not ProductionBOMContainsItemCache.Get(
                         CandidateItem."Production BOM No.",
                         ContainsPILItem)
                    then begin
                        ContainsPILItem := ProductionBOMContainsItemOnAnyOrderDate(
                            CandidateItem."Production BOM No.",
                            PILItemNo,
                            CalculationDates);
                        ProductionBOMContainsItemCache.Add(
                            CandidateItem."Production BOM No.",
                            ContainsPILItem);
                    end;
                    if ContainsPILItem then
                        if not TempItem.Get(CandidateItem."No.") then begin
                            TempItem := CandidateItem;
                            TempItem.Insert();
                        end;
                end;
            until CandidateItem.Next() = 0;
    end;

    local procedure ProductionBOMContainsItemOnAnyOrderDate(ProductionBOMNo: Code[20]; PILItemNo: Code[20]; CalculationDates: Dictionary of [Date, Boolean]): Boolean
    var
        BOMPath: List of [Code[20]];
        CalculationDateList: List of [Date];
        CalculationDate: Date;
    begin
        CalculationDateList := CalculationDates.Keys();
        foreach CalculationDate in CalculationDateList do begin
            Clear(BOMPath);
            if HasCertifiedProductionBOM(ProductionBOMNo, CalculationDate, '', false) then
                if ProductionBOMContainsItem(
                     ProductionBOMNo,
                     CalculationDate,
                     '',
                     false,
                     PILItemNo,
                     BOMPath)
                then
                    exit(true);
        end;
        exit(false);
    end;

    local procedure BuildItemProductionBOMBridgeIndex(var TempBridgeProductionBOMLine: Record "Production BOM Line" temporary)
    var
        BridgeItem: Record Item;
        NextLineNo: Integer;
    begin
        TempBridgeProductionBOMLine.Reset();
        TempBridgeProductionBOMLine.DeleteAll();
        BridgeItem.SetLoadFields("No.", "Production BOM No.");
        BridgeItem.SetFilter("Production BOM No.", '<>%1', '');
        if BridgeItem.FindSet() then
            repeat
                NextLineNo += 1;
                TempBridgeProductionBOMLine.Init();
                TempBridgeProductionBOMLine."Production BOM No." := BridgeItem."Production BOM No.";
                TempBridgeProductionBOMLine."Line No." := NextLineNo;
                TempBridgeProductionBOMLine.Type := TempBridgeProductionBOMLine.Type::Item;
                TempBridgeProductionBOMLine."No." := BridgeItem."No.";
                TempBridgeProductionBOMLine.Insert();
            until BridgeItem.Next() = 0;
    end;

    local procedure AddProductionBOMToSearchQueue(ProductionBOMNo: Code[20]; var ContainingProductionBOMNos: Dictionary of [Code[20], Boolean]; var ProductionBOMQueue: List of [Code[20]])
    begin
        if (ProductionBOMNo = '') or ContainingProductionBOMNos.ContainsKey(ProductionBOMNo) then
            exit;
        ContainingProductionBOMNos.Add(ProductionBOMNo, true);
        ProductionBOMQueue.Add(ProductionBOMNo);
    end;

    local procedure IsActiveCertifiedProductionBOMLine(ProductionBOMLine: Record "Production BOM Line"; CalculationDate: Date; var CertifiedProductionBOMCache: Dictionary of [Code[20], Boolean]; var ActiveVersionCodeCache: Dictionary of [Code[20], Code[20]]): Boolean
    var
        ActiveVersionCode: Code[20];
    begin
        if not GetCachedActiveCertifiedProductionBOMVersion(
             ProductionBOMLine."Production BOM No.",
             CalculationDate,
             CertifiedProductionBOMCache,
             ActiveVersionCodeCache,
             ActiveVersionCode)
        then
            exit(false);
        if ProductionBOMLine."Version Code" <> ActiveVersionCode then
            exit(false);
        if (ProductionBOMLine."Starting Date" <> 0D) and
           (ProductionBOMLine."Starting Date" > CalculationDate)
        then
            exit(false);
        if (ProductionBOMLine."Ending Date" <> 0D) and
           (ProductionBOMLine."Ending Date" < CalculationDate)
        then
            exit(false);
        exit(true);
    end;

    local procedure GetCachedActiveCertifiedProductionBOMVersion(ProductionBOMNo: Code[20]; CalculationDate: Date; var CertifiedProductionBOMCache: Dictionary of [Code[20], Boolean]; var ActiveVersionCodeCache: Dictionary of [Code[20], Code[20]]; var ActiveVersionCode: Code[20]): Boolean
    var
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMVersion: Record "Production BOM Version";
        VersionManagement: Codeunit VersionManagement;
        IsCertified: Boolean;
    begin
        Clear(ActiveVersionCode);
        if CertifiedProductionBOMCache.Get(ProductionBOMNo, IsCertified) then begin
            ActiveVersionCodeCache.Get(ProductionBOMNo, ActiveVersionCode);
            exit(IsCertified);
        end;

        IsCertified := ProductionBOMHeader.Get(ProductionBOMNo);
        if IsCertified then begin
            ActiveVersionCode := VersionManagement.GetBOMVersion(ProductionBOMNo, CalculationDate, true);
            if ActiveVersionCode = '' then
                IsCertified := ProductionBOMHeader.Status = ProductionBOMHeader.Status::Certified
            else
                IsCertified :=
                    ProductionBOMVersion.Get(ProductionBOMNo, ActiveVersionCode) and
                    (ProductionBOMVersion.Status = ProductionBOMVersion.Status::Certified);
        end;

        CertifiedProductionBOMCache.Add(ProductionBOMNo, IsCertified);
        ActiveVersionCodeCache.Add(ProductionBOMNo, ActiveVersionCode);
        exit(IsCertified);
    end;

    procedure PointCarrierNeedsDestination(PNEPILHeader: Record "PNE PIL Header"; PointCarrierItem: Record Item): Boolean
    var
        PointCarrierProdOrderComponent: Record "Prod. Order Component";
        MatchingComponentCount: Integer;
    begin
        PointCarrierProdOrderComponent.SetRange(Status, PNEPILHeader."Production Order Status");
        PointCarrierProdOrderComponent.SetRange("Prod. Order No.", PNEPILHeader."Production Order No.");
        PointCarrierProdOrderComponent.SetRange("Item No.", PointCarrierItem."No.");
        MatchingComponentCount := PointCarrierProdOrderComponent.Count();
        exit(MatchingComponentCount <> 1);
    end;

    procedure AssignPILLineToPointCarrier(var PNEPILLine: Record "PNE PIL Line"; PointCarrierItem: Record Item; DestinationProdOrderLine: Record "Prod. Order Line")
    var
        PNEPILHeader: Record "PNE PIL Header";
        AdditionalLinkedLineCount: Integer;
    begin
        PNEPILHeader.Get(PNEPILLine."Header Entry No.");
        AssignPILLineToPointCarrierInternal(PNEPILLine, PointCarrierItem, DestinationProdOrderLine, PNEPILHeader);
        AdditionalLinkedLineCount := AssignOtherMatchingPILLinesToPointCarrier(
            PNEPILHeader,
            PNEPILLine."Line No.",
            PointCarrierItem);
        FinalizePointCarrierAssignments(PNEPILHeader);
        if AdditionalLinkedLineCount > 0 then
            Message(AdditionalPILLinesLinkedMsg, AdditionalLinkedLineCount, PointCarrierItem."No.");
    end;

    local procedure AssignOtherMatchingPILLinesToPointCarrier(PNEPILHeader: Record "PNE PIL Header"; SourcePILLineNo: Integer; PointCarrierItem: Record Item): Integer
    var
        CandidatePNEPILLine: Record "PNE PIL Line";
        DestinationProdOrderLine: Record "Prod. Order Line";
        MatchingPNEPILLine: Record "PNE PIL Line";
        SourcePNEPILTarget: Record "PNE PIL Target";
        EligiblePILItemNos: Dictionary of [Code[20], Boolean];
        QuantityPerPILItem: Dictionary of [Code[20], Decimal];
        BOMPath: List of [Code[20]];
        ProductionBOMNo: Code[20];
        RequestedVersionCode: Code[20];
        AdditionalLinkedLineCount: Integer;
        CalculationDate: Date;
        CandidateQuantityPerCarrier: Decimal;
        SourceTargetFound: Boolean;
        UseRequestedVersion: Boolean;
    begin
        SourcePNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if SourcePNEPILTarget.FindSet() then
            repeat
                SourceTargetFound :=
                    (SourcePNEPILTarget."PIL Line No." = SourcePILLineNo) and
                    (SourcePNEPILTarget.Kind in [
                        SourcePNEPILTarget.Kind::"Structural driver",
                        SourcePNEPILTarget.Kind::"Point carrier addition"]);
            until SourceTargetFound or (SourcePNEPILTarget.Next() = 0);
        if not SourceTargetFound then
            exit;
        if SourcePNEPILTarget."Quantity per Carrier" <= QuantityTolerance() then
            exit;
        DestinationProdOrderLine.Get(
            SourcePNEPILTarget."Carrier Status",
            SourcePNEPILTarget."Carrier Production Order No.",
            SourcePNEPILTarget."Carrier Order Line No.");
        CalculationDate := GetPointCarrierTargetCalculationDate(SourcePNEPILTarget);
        if SourcePNEPILTarget.Kind = SourcePNEPILTarget.Kind::"Point carrier addition" then
            ProductionBOMNo := PointCarrierItem."Production BOM No."
        else begin
            ProductionBOMNo := GetProductionBOMNoForLine(DestinationProdOrderLine);
            RequestedVersionCode := DestinationProdOrderLine."Production BOM Version Code";
            UseRequestedVersion := RequestedVersionCode <> '';
        end;

        CandidatePNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CandidatePNEPILLine.SetFilter(Quantity, '>%1', QuantityTolerance());
        if CandidatePNEPILLine.FindSet() then
            repeat
                if (CandidatePNEPILLine."Line No." <> SourcePILLineNo) and
                   IsUnresolvedPILLineEligibleForPointCarrier(PNEPILHeader, CandidatePNEPILLine) and
                   not EligiblePILItemNos.ContainsKey(CandidatePNEPILLine."Item No.")
                then
                    EligiblePILItemNos.Add(CandidatePNEPILLine."Item No.", true);
            until CandidatePNEPILLine.Next() = 0;
        if EligiblePILItemNos.Count() > 0 then begin
            Clear(BOMPath);
            BuildMasterStructuralQuantityMap(
                ProductionBOMNo,
                CalculationDate,
                1,
                RequestedVersionCode,
                UseRequestedVersion,
                EligiblePILItemNos,
                QuantityPerPILItem,
                BOMPath);
        end;

        if CandidatePNEPILLine.FindSet() then
            repeat
                if (CandidatePNEPILLine."Line No." <> SourcePILLineNo) and
                   IsUnresolvedPILLineEligibleForPointCarrier(PNEPILHeader, CandidatePNEPILLine)
                then begin
                    Clear(CandidateQuantityPerCarrier);
                    if QuantityPerPILItem.Get(CandidatePNEPILLine."Item No.", CandidateQuantityPerCarrier) and
                       (CandidateQuantityPerCarrier > QuantityTolerance())
                    then begin
                        MatchingPNEPILLine := CandidatePNEPILLine;
                        AssignPILLineToPointCarrierInternal(
                            MatchingPNEPILLine,
                            PointCarrierItem,
                            DestinationProdOrderLine,
                            PNEPILHeader);
                        AdditionalLinkedLineCount += 1;
                    end;
                end;
            until CandidatePNEPILLine.Next() = 0;
        exit(AdditionalLinkedLineCount);
    end;

    local procedure IsUnresolvedPILLineEligibleForPointCarrier(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"): Boolean
    begin
        if (PNEPILLine."Group Code" <> '') or
           (PNEPILLine."Covered Quantity" >= PNEPILLine.Quantity - QuantityTolerance()) or
           PNEPILLine."Ignore for Reconciliation" or
           not (PNEPILLine.Resolution in ['', NotUsedTxt, PartiallyCoveredTxt])
        then
            exit(false);
        exit(
            not HasStructuralTarget(PNEPILHeader, PNEPILLine."Line No.") and
            not HasDirectComponentTarget(PNEPILHeader, PNEPILLine."Line No.") and
            not HasPointCarrierAdditionTarget(PNEPILHeader, PNEPILLine."Line No."));
    end;

    local procedure GetPointCarrierTargetCalculationDate(PNEPILTarget: Record "PNE PIL Target"): Date
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        ProdOrderLine.Get(
            PNEPILTarget."Carrier Status",
            PNEPILTarget."Carrier Production Order No.",
            PNEPILTarget."Carrier Order Line No.");
        exit(GetCarrierCalculationDate(ProdOrderLine));
    end;

    local procedure AssignPILLineToPointCarrierInternal(var PNEPILLine: Record "PNE PIL Line"; PointCarrierItem: Record Item; DestinationProdOrderLine: Record "Prod. Order Line"; PNEPILHeader: Record "PNE PIL Header")
    var
        PointCarrierProdOrderComponent: Record "Prod. Order Component";
        MatchingComponentCount: Integer;
    begin
        if PNEPILLine."Header Entry No." <> PNEPILHeader."Entry No." then
            Error(SelectedPILLinesDifferentHeadersErr);
        PointCarrierItem.Get(PointCarrierItem."No.");

        PointCarrierProdOrderComponent.SetRange(Status, PNEPILHeader."Production Order Status");
        PointCarrierProdOrderComponent.SetRange("Prod. Order No.", PNEPILHeader."Production Order No.");
        PointCarrierProdOrderComponent.SetRange("Item No.", PointCarrierItem."No.");
        if DestinationProdOrderLine."Line No." <> 0 then
            PointCarrierProdOrderComponent.SetRange("Prod. Order Line No.", DestinationProdOrderLine."Line No.");
        MatchingComponentCount := PointCarrierProdOrderComponent.Count();
        if MatchingComponentCount = 1 then begin
            PointCarrierProdOrderComponent.FindFirst();
            AddPILLineUnderPointCarrier(PNEPILLine, PointCarrierProdOrderComponent);
            exit;
        end;
        if MatchingComponentCount > 1 then
            Error(PointCarrierOccursMultipleTimesUnderLineErr, PointCarrierItem."No.", DestinationProdOrderLine."Item No.");

        if (DestinationProdOrderLine.Status <> PNEPILHeader."Production Order Status") or
           (DestinationProdOrderLine."Prod. Order No." <> PNEPILHeader."Production Order No.") or
           (DestinationProdOrderLine."Line No." = 0)
        then
            Error(PointCarrierDestinationRequiredErr, PointCarrierItem."No.");
        CheckProductionOrderLineUnitOfMeasure(DestinationProdOrderLine);
        AddPILLineAsNewPointCarrier(PNEPILLine, PointCarrierItem, DestinationProdOrderLine);
    end;

    local procedure FinalizePointCarrierAssignments(var PNEPILHeader: Record "PNE PIL Header")
    begin
        RecalculateTargetQuantities(PNEPILHeader);
        RefreshPILCoverage(PNEPILHeader);
        UpdateLineResolutions(PNEPILHeader);
        RefreshAllocations(PNEPILHeader);
        BuildChangeLines(PNEPILHeader);
    end;

    local procedure AddPILLineAsNewPointCarrier(var PNEPILLine: Record "PNE PIL Line"; PointCarrierItem: Record Item; DestinationProdOrderLine: Record "Prod. Order Line")
    var
        ExistingPNEPILTarget: Record "PNE PIL Target";
        PNEPILHeader: Record "PNE PIL Header";
        PNEPILTarget: Record "PNE PIL Target";
        BOMPath: List of [Code[20]];
        DesiredCarrierQuantity: Decimal;
        RemainingPILQuantity: Decimal;
        QuantityPerCarrier: Decimal;
    begin
        PNEPILLine.Get(PNEPILLine."Header Entry No.", PNEPILLine."Line No.");
        PNEPILHeader.Get(PNEPILLine."Header Entry No.");
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AlreadyAppliedErr, PNEPILHeader."Entry No.");
        AssertProposalNotTransferred(PNEPILHeader);
        RemainingPILQuantity := PNEPILLine.Quantity - PNEPILLine."Covered Quantity";
        if (PNEPILLine.Quantity <= QuantityTolerance()) or
           (PNEPILLine."Group Code" <> '') or
           (RemainingPILQuantity <= QuantityTolerance()) or
           PNEPILLine."Ignore for Reconciliation"
        then
            Error(DirectComponentNotEligibleErr, PNEPILLine."Item No.");

        ExistingPNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        ExistingPNEPILTarget.SetRange("PIL Line No.", PNEPILLine."Line No.");
        if not ExistingPNEPILTarget.IsEmpty() then
            Error(ResolvedPILLineCannotBeIgnoredErr, PNEPILLine."Item No.");

        CheckNewPointCarrierItem(PointCarrierItem, DestinationProdOrderLine, PNEPILLine."Item No.");
        SumMasterStructuralQuantityPerCarrier(
            PointCarrierItem."Production BOM No.",
            GetCarrierCalculationDate(DestinationProdOrderLine),
            PNEPILLine."Item No.",
            1,
            '',
            false,
            QuantityPerCarrier,
            BOMPath);
        if QuantityPerCarrier <= QuantityTolerance() then
            Error(PointCarrierDoesNotContainItemErr, PointCarrierItem."No.", PNEPILLine."Item No.");
        DesiredCarrierQuantity := Round(RemainingPILQuantity / QuantityPerCarrier, 1, '>');

        PNEPILTarget.Init();
        PNEPILTarget."Header Entry No." := PNEPILHeader."Entry No.";
        PNEPILTarget."Line No." := GetNextTargetLineNo(PNEPILHeader);
        PNEPILTarget."PIL Line No." := PNEPILLine."Line No.";
        PNEPILTarget."PIL Item No." := PNEPILLine."Item No.";
        PNEPILTarget."PIL Item Description" := PNEPILLine.Description;
        PNEPILTarget."PIL Quantity" := PNEPILLine.Quantity;
        PNEPILTarget."Allocated PIL Quantity" := RemainingPILQuantity;
        PNEPILTarget.Kind := PNEPILTarget.Kind::"Point carrier addition";
        PNEPILTarget."Carrier Type" := PNEPILTarget."Carrier Type"::"Production Order Line";
        PNEPILTarget."Carrier Status" := DestinationProdOrderLine.Status;
        PNEPILTarget."Carrier Production Order No." := DestinationProdOrderLine."Prod. Order No.";
        PNEPILTarget."Carrier Order Line No." := DestinationProdOrderLine."Line No.";
        PNEPILTarget."Carrier Item No." := DestinationProdOrderLine."Item No.";
        PNEPILTarget."Carrier Description" := DestinationProdOrderLine.Description;
        PNEPILTarget."Carrier SystemId" := DestinationProdOrderLine.SystemId;
        PNEPILTarget."Carrier Variant Code" := DestinationProdOrderLine."Variant Code";
        PNEPILTarget."Carrier Unit of Measure Code" := DestinationProdOrderLine."Unit of Measure Code";
        PNEPILTarget."Quantity per Carrier" := QuantityPerCarrier;
        PNEPILTarget."Original Carrier Quantity" := 0;
        PNEPILTarget."New Carrier Quantity" := DesiredCarrierQuantity;
        PNEPILTarget."Analysis Source" := PNEPILTarget."Analysis Source"::"Current Master BOM";
        PNEPILTarget."New Point Carrier Item No." := PointCarrierItem."No.";
        PNEPILTarget."New Point Carrier Description" := PointCarrierItem.Description;
        PNEPILTarget."New Point Carrier SystemId" := PointCarrierItem.SystemId;
        PNEPILTarget."New Point Carrier BOM No." := PointCarrierItem."Production BOM No.";
        PNEPILTarget."Destination Original Quantity" := DestinationProdOrderLine.Quantity;
        PNEPILTarget.Resolution := PointCarrierAdditionTxt;
        PNEPILTarget.Insert(true);

    end;

    local procedure CheckNewPointCarrierItem(PointCarrierItem: Record Item; DestinationProdOrderLine: Record "Prod. Order Line"; PILItemNo: Code[20])
    var
        BOMPath: List of [Code[20]];
    begin
        if not IsPointCarrierItemNo(PointCarrierItem."No.") or
           (PointCarrierItem.Type <> PointCarrierItem.Type::Inventory) or
           (PointCarrierItem."Replenishment System" <> PointCarrierItem."Replenishment System"::"Prod. Order") or
           (PointCarrierItem."Base Unit of Measure" <> PiecesUnitOfMeasureLbl) or
           (PointCarrierItem."Production BOM No." = '')
        then
            Error(PointCarrierItemNotSupportedErr, PointCarrierItem."No.");
        if not HasCertifiedProductionBOM(
            PointCarrierItem."Production BOM No.",
            GetCarrierCalculationDate(DestinationProdOrderLine),
            '',
            false)
        then
            Error(PointCarrierItemNotSupportedErr, PointCarrierItem."No.");
        if not ProductionBOMContainsItem(
            PointCarrierItem."Production BOM No.",
            GetCarrierCalculationDate(DestinationProdOrderLine),
            '',
            false,
            PILItemNo,
            BOMPath)
        then
            Error(PointCarrierDoesNotContainItemErr, PointCarrierItem."No.", PILItemNo);
    end;

    procedure GetDirectComponentDestinationLines(PNEPILHeader: Record "PNE PIL Header"; var TempProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ProdOrderLine: Record "Prod. Order Line";
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        TempProdOrderLine.DeleteAll();
        ProdOrderLine.SetRange(Status, PNEPILHeader."Production Order Status");
        ProdOrderLine.SetRange("Prod. Order No.", PNEPILHeader."Production Order No.");
        if ProdOrderLine.FindSet() then
            repeat
                if (ProdOrderLine."Unit of Measure Code" = PiecesUnitOfMeasureLbl) and
                   (Abs(ProdOrderLine."Qty. per Unit of Measure" - 1) <= QuantityTolerance())
                then begin
                    TempVisitedProdOrderLine.DeleteAll();
                    TempProdOrderLine := ProdOrderLine;
                    TempProdOrderLine.Description := CopyStr(
                        GetProductionOrderLinePath(ProdOrderLine, TempVisitedProdOrderLine),
                        1,
                        MaxStrLen(TempProdOrderLine.Description));
                    TempProdOrderLine.Insert();
                end;
            until ProdOrderLine.Next() = 0;
    end;

    local procedure GetProductionOrderLinePath(ProdOrderLine: Record "Prod. Order Line"; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary): Text
    var
        ParentProdOrderComponent: Record "Prod. Order Component";
        ParentProdOrderLine: Record "Prod. Order Line";
        CurrentLineText: Text;
    begin
        if WasVisited(ProdOrderLine, TempVisitedProdOrderLine) then
            exit(ProdOrderLine."Item No.");

        CurrentLineText := ProdOrderLine."Item No." + ' — ' + ProdOrderLine.Description;
        ParentProdOrderComponent.SetRange(Status, ProdOrderLine.Status);
        ParentProdOrderComponent.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        ParentProdOrderComponent.SetRange("Supplied-by Line No.", ProdOrderLine."Line No.");
        if ParentProdOrderComponent.FindFirst() then begin
            ParentProdOrderLine.Get(
                ParentProdOrderComponent.Status,
                ParentProdOrderComponent."Prod. Order No.",
                ParentProdOrderComponent."Prod. Order Line No.");
            exit(GetProductionOrderLinePath(ParentProdOrderLine, TempVisitedProdOrderLine) + ' > ' + CurrentLineText);
        end;
        exit(CurrentLineText);
    end;

    local procedure AddPILLineUnderPointCarrier(var PNEPILLine: Record "PNE PIL Line"; CarrierProdOrderComponent: Record "Prod. Order Component")
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ExistingPNEPILTarget: Record "PNE PIL Target";
        OwningProdOrderLine: Record "Prod. Order Line";
        PNEPILHeader: Record "PNE PIL Header";
        TempCarrierPNEPILTarget: Record "PNE PIL Target" temporary;
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
        BOMPath: List of [Code[20]];
        QuantityPerCarrier: Decimal;
        RemainingPILQuantity: Decimal;
    begin
        PNEPILLine.Get(PNEPILLine."Header Entry No.", PNEPILLine."Line No.");
        PNEPILHeader.Get(PNEPILLine."Header Entry No.");
        if PNEPILHeader.Status = PNEPILHeader.Status::Applied then
            Error(AlreadyAppliedErr, PNEPILHeader."Entry No.");
        AssertProposalNotTransferred(PNEPILHeader);
        RemainingPILQuantity := PNEPILLine.Quantity - PNEPILLine."Covered Quantity";
        if (PNEPILLine.Quantity <= QuantityTolerance()) or
           (PNEPILLine."Group Code" <> '') or
           (RemainingPILQuantity <= QuantityTolerance()) or
           PNEPILLine."Ignore for Reconciliation"
        then
            Error(DirectComponentNotEligibleErr, PNEPILLine."Item No.");
        if (CarrierProdOrderComponent.Status <> PNEPILHeader."Production Order Status") or
           (CarrierProdOrderComponent."Prod. Order No." <> PNEPILHeader."Production Order No.") or
           not IsPointCarrierItemNo(CarrierProdOrderComponent."Item No.")
        then
            Error(DirectComponentWrongOrderErr);
        OwningProdOrderLine.Get(
            CarrierProdOrderComponent.Status,
            CarrierProdOrderComponent."Prod. Order No.",
            CarrierProdOrderComponent."Prod. Order Line No.");

        ExistingPNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        ExistingPNEPILTarget.SetRange("PIL Line No.", PNEPILLine."Line No.");
        if not ExistingPNEPILTarget.IsEmpty() then
            Error(ResolvedPILLineCannotBeIgnoredErr, PNEPILLine."Item No.");

        if FindChildProdOrderLine(CarrierProdOrderComponent, ChildProdOrderLine) then begin
            CheckLinkedProductionOrderUnitOfMeasure(CarrierProdOrderComponent, ChildProdOrderLine);
            if ChildProdOrderLine.Quantity <= QuantityTolerance() then
                Error(ZeroCarrierQuantityErr, ChildProdOrderLine."Item No.");
            SumLiveStructuralQuantityPerCarrier(
                ChildProdOrderLine,
                ChildProdOrderLine,
                PNEPILLine."Item No.",
                QuantityPerCarrier,
                TempVisitedProdOrderLine);
            if QuantityPerCarrier > QuantityTolerance() then begin
                InsertTarget(
                    PNEPILHeader,
                    PNEPILLine,
                    ChildProdOrderLine,
                    ExistingPNEPILTarget.Kind::"Structural driver",
                    QuantityPerCarrier,
                    RemainingPILQuantity,
                    '',
                    '',
                    0);
                NormalizeLiveStructuralTargetFactors(PNEPILHeader, ChildProdOrderLine);
                exit;
            end;

            if ProductionOrderLineBOMContainsItem(ChildProdOrderLine, PNEPILLine."Item No.") then begin
                Clear(BOMPath);
                Clear(QuantityPerCarrier);
                CheckRootBOMUnitOfMeasure(
                    GetProductionBOMNoForLine(ChildProdOrderLine),
                    ChildProdOrderLine."Production BOM Version Code",
                    true,
                    GetCarrierCalculationDate(ChildProdOrderLine),
                    ChildProdOrderLine."Unit of Measure Code");
                SumMasterStructuralQuantityPerCarrier(
                    GetProductionBOMNoForLine(ChildProdOrderLine),
                    GetCarrierCalculationDate(ChildProdOrderLine),
                    PNEPILLine."Item No.",
                    1,
                    ChildProdOrderLine."Production BOM Version Code",
                    true,
                    QuantityPerCarrier,
                    BOMPath);
                if QuantityPerCarrier > QuantityTolerance() then begin
                    InitializeLineCarrierTemplate(TempCarrierPNEPILTarget, ChildProdOrderLine);
                    InsertTargetFromCarrierTemplate(
                        PNEPILHeader,
                        PNEPILLine,
                        TempCarrierPNEPILTarget,
                        ExistingPNEPILTarget.Kind::"Structural driver",
                        QuantityPerCarrier,
                        RemainingPILQuantity,
                        '',
                        '');
                    exit;
                end;
            end;
            Error(PointCarrierDoesNotContainItemErr, CarrierProdOrderComponent."Item No.", PNEPILLine."Item No.");
        end;

        CheckProductionOrderComponentUnitOfMeasure(CarrierProdOrderComponent);
        CheckRootBOMUnitOfMeasure(
            GetProductionBOMNoForComponent(CarrierProdOrderComponent),
            '',
            false,
            GetCarrierCalculationDate(OwningProdOrderLine),
            CarrierProdOrderComponent."Unit of Measure Code");
        SumMasterStructuralQuantityPerCarrier(
            GetProductionBOMNoForComponent(CarrierProdOrderComponent),
            GetCarrierCalculationDate(OwningProdOrderLine),
            PNEPILLine."Item No.",
            1,
            '',
            false,
            QuantityPerCarrier,
            BOMPath);
        if QuantityPerCarrier <= QuantityTolerance() then
            Error(PointCarrierDoesNotContainItemErr, CarrierProdOrderComponent."Item No.", PNEPILLine."Item No.");
        InitializeComponentCarrierTemplate(TempCarrierPNEPILTarget, CarrierProdOrderComponent);
        InsertTargetFromCarrierTemplate(
            PNEPILHeader,
            PNEPILLine,
            TempCarrierPNEPILTarget,
            ExistingPNEPILTarget.Kind::"Structural driver",
            QuantityPerCarrier,
            RemainingPILQuantity,
            '',
            '');
    end;

    local procedure ProductionBOMContainsItem(ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; ItemNo: Code[20]; var BOMPath: List of [Code[20]]): Boolean
    var
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
    begin
        if ProductionBOMNo = '' then
            exit(false);
        if BOMPath.Contains(ProductionBOMNo) or (BOMPath.Count() >= MaximumProductionBOMDepth()) then
            exit(false);
        BOMPath.Add(ProductionBOMNo);

        SetActiveProductionBOMLineFilters(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion, ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                if ProductionBOMLine."No." = ItemNo then begin
                    BOMPath.Remove(ProductionBOMNo);
                    exit(true);
                end;
                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if (ChildProductionBOMNo <> '') and
                   ProductionBOMContainsItem(ChildProductionBOMNo, CalculationDate, '', false, ItemNo, BOMPath)
                then begin
                    BOMPath.Remove(ProductionBOMNo);
                    exit(true);
                end;
            until ProductionBOMLine.Next() = 0;

        BOMPath.Remove(ProductionBOMNo);
        exit(false);
    end;

    local procedure ProductionOrderLineBOMContainsItem(ProdOrderLine: Record "Prod. Order Line"; ItemNo: Code[20]): Boolean
    var
        BOMPath: List of [Code[20]];
        ProductionBOMNo: Code[20];
    begin
        ProductionBOMNo := GetProductionBOMNoForLine(ProdOrderLine);
        if (ProductionBOMNo = '') or
           not HasCertifiedProductionBOM(
               ProductionBOMNo,
               GetCarrierCalculationDate(ProdOrderLine),
               ProdOrderLine."Production BOM Version Code",
               true)
        then
            exit(false);
        exit(
            ProductionBOMContainsItem(
                ProductionBOMNo,
                GetCarrierCalculationDate(ProdOrderLine),
                ProdOrderLine."Production BOM Version Code",
                true,
                ItemNo,
                BOMPath));
    end;

    procedure HasBlockingPositivePILLines(PNEPILHeader: Record "PNE PIL Header"): Boolean
    var
        PNEPILLine: Record "PNE PIL Line";
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet() then
            repeat
                if IsBlockingPositivePILLine(PNEPILLine) then
                    exit(true);
            until PNEPILLine.Next() = 0;
        exit(false);
    end;

    procedure HasNoProductionChanges(PNEPILHeader: Record "PNE PIL Header"): Boolean
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILTarget.FindSet() then
            repeat
                if TargetChangesProductionOrder(PNEPILTarget) then
                    exit(false);
            until PNEPILTarget.Next() = 0;
        exit(true);
    end;

    procedure GetWorkflowGuidance(PNEPILHeader: Record "PNE PIL Header"): Text
    begin
        case PNEPILHeader.Status of
            PNEPILHeader.Status::Imported:
                exit(ImportedWorkflowGuidanceTxt);
            PNEPILHeader.Status::"Allocation Required":
                exit(AllocationWorkflowGuidanceTxt);
            PNEPILHeader.Status::Prepared:
                if HasNoProductionChanges(PNEPILHeader) then
                    exit(PreparedNoChangesWorkflowGuidanceTxt)
                else
                    exit(PreparedWorkflowGuidanceTxt);
            PNEPILHeader.Status::Applied:
                exit(AppliedWorkflowGuidanceTxt);
        end;
    end;

    procedure GetApplyImpactSummary(PNEPILHeader: Record "PNE PIL Header"): Text
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        PNEPILTarget: Record "PNE PIL Target";
        PositiveChangeCount: Integer;
        ChangeCount: Integer;
        CALCReplacementCount: Integer;
    begin
        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILChangeLine.FindSet() then
            repeat
                ChangeCount += 1;
                if PNEPILChangeLine."Quantity Difference" > QuantityTolerance() then
                    PositiveChangeCount += 1;
            until PNEPILChangeLine.Next() = 0;

        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"CALC replacement");
        if PNEPILTarget.FindSet() then
            repeat
                if not HasEarlierCALCTargetForCarrierAndGroup(PNEPILTarget) then
                    CALCReplacementCount += 1;
            until PNEPILTarget.Next() = 0;
        exit(StrSubstNo(ApplyImpactSummaryTxt, ChangeCount, PositiveChangeCount, CALCReplacementCount));
    end;

    local procedure CheckHeader(PNEPILHeader: Record "PNE PIL Header")
    var
        ProductionOrder: Record "Production Order";
    begin
        ProductionOrder.Get(PNEPILHeader."Production Order Status", PNEPILHeader."Production Order No.");
        if not (ProductionOrder.Status in [ProductionOrder.Status::Simulated, ProductionOrder.Status::"Firm Planned", ProductionOrder.Status::Released]) then
            Error(UnsupportedOrderStatusErr, ProductionOrder."No.");
    end;

    local procedure ClearReview(var PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        PNEPILLine: Record "PNE PIL Line";
        PNEPILTarget: Record "PNE PIL Target";
    begin
        if PNEPILHeader."Prepared At" <> 0DT then begin
            Clear(PNEPILHeader."Prepared At");
            PNEPILHeader.Modify(true);
        end;

        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILChangeLine.DeleteAll(true);

        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.DeleteAll(true);

        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet(true) then
            repeat
                PNEPILLine."Covered By Item No." := '';
                PNEPILLine."Covered Quantity" := 0;
                PNEPILLine.Resolution := '';
                PNEPILLine.Modify(true);
            until PNEPILLine.Next() = 0;
    end;

    local procedure BuildStructuralTargets(PNEPILHeader: Record "PNE PIL Header")
    var
        CarrierProdOrderLine: Record "Prod. Order Line";
        CarrierProdOrderComponent: Record "Prod. Order Component";
        TempUnlinkedCarrierProdOrderComponent: Record "Prod. Order Component" temporary;
        TempOuterCarrierProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        GetOuterCarrierLines(PNEPILHeader, TempOuterCarrierProdOrderLine);
        if TempOuterCarrierProdOrderLine.FindSet() then
            repeat
                CarrierProdOrderLine := TempOuterCarrierProdOrderLine;
                FindStructuralDriversInCarrier(PNEPILHeader, CarrierProdOrderLine);
            until TempOuterCarrierProdOrderLine.Next() = 0;

        GetUnlinkedOuterCarrierComponents(PNEPILHeader, TempUnlinkedCarrierProdOrderComponent);
        if TempUnlinkedCarrierProdOrderComponent.FindSet() then
            repeat
                CarrierProdOrderComponent := TempUnlinkedCarrierProdOrderComponent;
                FindStructuralDriversInUnlinkedComponent(PNEPILHeader, CarrierProdOrderComponent);
            until TempUnlinkedCarrierProdOrderComponent.Next() = 0;
        ConfigureStructuralTargetAllocations(PNEPILHeader);
    end;

    local procedure BuildUniqueExistingPointCarrierTargets(PNEPILHeader: Record "PNE PIL Header")
    var
        MatchingPointCarrierProdOrderComponent: Record "Prod. Order Component";
        PNEPILLine: Record "PNE PIL Line";
        MatchingCarrierSystemIds: Dictionary of [Code[20], Guid];
        MatchingCarrierCounts: Dictionary of [Code[20], Integer];
        MatchingCarrierSystemId: Guid;
        MatchingCarrierCount: Integer;
    begin
        BuildExistingPointCarrierMatchIndex(
            PNEPILHeader,
            MatchingCarrierSystemIds,
            MatchingCarrierCounts);

        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILLine.SetFilter(Quantity, '>%1', QuantityTolerance());
        if PNEPILLine.FindSet() then
            repeat
                Clear(MatchingCarrierCount);
                Clear(MatchingCarrierSystemId);
                if IsUnresolvedPILLineEligibleForPointCarrier(PNEPILHeader, PNEPILLine) and
                   MatchingCarrierCounts.Get(PNEPILLine."Item No.", MatchingCarrierCount) and
                   (MatchingCarrierCount = 1) and
                   MatchingCarrierSystemIds.Get(PNEPILLine."Item No.", MatchingCarrierSystemId)
                then begin
                    MatchingPointCarrierProdOrderComponent.GetBySystemId(MatchingCarrierSystemId);
                    AddPILLineUnderPointCarrier(PNEPILLine, MatchingPointCarrierProdOrderComponent);
                    RecalculateTargetQuantities(PNEPILHeader);
                    ApplyStructuralCoverageForPILLine(PNEPILHeader, PNEPILLine."Line No.");
                end;
            until PNEPILLine.Next() = 0;
    end;

    local procedure BuildExistingPointCarrierMatchIndex(PNEPILHeader: Record "PNE PIL Header"; var MatchingCarrierSystemIds: Dictionary of [Code[20], Guid]; var MatchingCarrierCounts: Dictionary of [Code[20], Integer])
    var
        CandidateProdOrderComponent: Record "Prod. Order Component";
        ChildProdOrderLine: Record "Prod. Order Line";
        OwningProdOrderLine: Record "Prod. Order Line";
        PNEPILLine: Record "PNE PIL Line";
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
        EligiblePILItemNos: Dictionary of [Code[20], Boolean];
        MatchingPILItemNos: Dictionary of [Code[20], Boolean];
        MatchingPILItemNoList: List of [Code[20]];
        BOMPath: List of [Code[20]];
        MatchingPILItemNo: Code[20];
        ProductionBOMNo: Code[20];
    begin
        Clear(MatchingCarrierSystemIds);
        Clear(MatchingCarrierCounts);

        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILLine.SetFilter(Quantity, '>%1', QuantityTolerance());
        if PNEPILLine.FindSet() then
            repeat
                if IsUnresolvedPILLineEligibleForPointCarrier(PNEPILHeader, PNEPILLine) and
                   not EligiblePILItemNos.ContainsKey(PNEPILLine."Item No.")
                then
                    EligiblePILItemNos.Add(PNEPILLine."Item No.", true);
            until PNEPILLine.Next() = 0;
        if EligiblePILItemNos.Count() = 0 then
            exit;

        CandidateProdOrderComponent.SetRange(Status, PNEPILHeader."Production Order Status");
        CandidateProdOrderComponent.SetRange("Prod. Order No.", PNEPILHeader."Production Order No.");
        CandidateProdOrderComponent.SetFilter("Item No.", '.%1', '*');
        if CandidateProdOrderComponent.FindSet() then
            repeat
                if IsPointCarrierItemNo(CandidateProdOrderComponent."Item No.") and
                   (CandidateProdOrderComponent."Unit of Measure Code" = PiecesUnitOfMeasureLbl) and
                   (Abs(CandidateProdOrderComponent."Qty. per Unit of Measure" - 1) <= QuantityTolerance())
                then begin
                    Clear(MatchingPILItemNos);
                    TempVisitedProdOrderLine.DeleteAll();
                    if FindChildProdOrderLine(CandidateProdOrderComponent, ChildProdOrderLine) then begin
                        CollectMatchingPILItemsInLine(
                            ChildProdOrderLine,
                            EligiblePILItemNos,
                            MatchingPILItemNos,
                            TempVisitedProdOrderLine);
                        if MatchingPILItemNos.Count() < EligiblePILItemNos.Count() then
                            CollectMatchingPILItemsInProductionOrderLineBOM(
                                ChildProdOrderLine,
                                EligiblePILItemNos,
                                MatchingPILItemNos);
                    end else begin
                        OwningProdOrderLine.Get(
                            CandidateProdOrderComponent.Status,
                            CandidateProdOrderComponent."Prod. Order No.",
                            CandidateProdOrderComponent."Prod. Order Line No.");
                        ProductionBOMNo := GetProductionBOMNoForComponent(CandidateProdOrderComponent);
                        if HasCertifiedProductionBOM(
                             ProductionBOMNo,
                             GetCarrierCalculationDate(OwningProdOrderLine),
                             '',
                             false)
                        then begin
                            Clear(BOMPath);
                            CollectMatchingPILItemsInProductionBOM(
                                ProductionBOMNo,
                                GetCarrierCalculationDate(OwningProdOrderLine),
                                '',
                                false,
                                EligiblePILItemNos,
                                MatchingPILItemNos,
                                BOMPath);
                        end;
                    end;

                    MatchingPILItemNoList := MatchingPILItemNos.Keys();
                    foreach MatchingPILItemNo in MatchingPILItemNoList do
                        RegisterPointCarrierMatch(
                            MatchingPILItemNo,
                            CandidateProdOrderComponent.SystemId,
                            MatchingCarrierSystemIds,
                            MatchingCarrierCounts);
                end;
            until CandidateProdOrderComponent.Next() = 0;
    end;

    local procedure CollectMatchingPILItemsInLine(CurrentProdOrderLine: Record "Prod. Order Line"; EligiblePILItemNos: Dictionary of [Code[20], Boolean]; var MatchingPILItemNos: Dictionary of [Code[20], Boolean]; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if EligiblePILItemNos.ContainsKey(ProdOrderComponent."Item No.") and
                   not MatchingPILItemNos.ContainsKey(ProdOrderComponent."Item No.")
                then
                    MatchingPILItemNos.Add(ProdOrderComponent."Item No.", true);
                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                    CollectMatchingPILItemsInLine(
                        ChildProdOrderLine,
                        EligiblePILItemNos,
                        MatchingPILItemNos,
                        TempVisitedProdOrderLine);
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure CollectMatchingPILItemsInProductionOrderLineBOM(ProdOrderLine: Record "Prod. Order Line"; EligiblePILItemNos: Dictionary of [Code[20], Boolean]; var MatchingPILItemNos: Dictionary of [Code[20], Boolean])
    var
        BOMPath: List of [Code[20]];
        ProductionBOMNo: Code[20];
    begin
        ProductionBOMNo := GetProductionBOMNoForLine(ProdOrderLine);
        if (ProductionBOMNo = '') or
           not HasCertifiedProductionBOM(
               ProductionBOMNo,
               GetCarrierCalculationDate(ProdOrderLine),
               ProdOrderLine."Production BOM Version Code",
               true)
        then
            exit;

        CollectMatchingPILItemsInProductionBOM(
            ProductionBOMNo,
            GetCarrierCalculationDate(ProdOrderLine),
            ProdOrderLine."Production BOM Version Code",
            true,
            EligiblePILItemNos,
            MatchingPILItemNos,
            BOMPath);
    end;

    local procedure CollectMatchingPILItemsInProductionBOM(ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; EligiblePILItemNos: Dictionary of [Code[20], Boolean]; var MatchingPILItemNos: Dictionary of [Code[20], Boolean]; var BOMPath: List of [Code[20]])
    var
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
    begin
        if (ProductionBOMNo = '') or BOMPath.Contains(ProductionBOMNo) or
           (BOMPath.Count() >= MaximumProductionBOMDepth())
        then
            exit;
        BOMPath.Add(ProductionBOMNo);

        SetActiveProductionBOMLineFilters(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                if EligiblePILItemNos.ContainsKey(ProductionBOMLine."No.") and
                   not MatchingPILItemNos.ContainsKey(ProductionBOMLine."No.")
                then
                    MatchingPILItemNos.Add(ProductionBOMLine."No.", true);
                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if ChildProductionBOMNo <> '' then
                    CollectMatchingPILItemsInProductionBOM(
                        ChildProductionBOMNo,
                        CalculationDate,
                        '',
                        false,
                        EligiblePILItemNos,
                        MatchingPILItemNos,
                        BOMPath);
            until ProductionBOMLine.Next() = 0;

        BOMPath.Remove(ProductionBOMNo);
    end;

    local procedure RegisterPointCarrierMatch(PILItemNo: Code[20]; CarrierSystemId: Guid; var MatchingCarrierSystemIds: Dictionary of [Code[20], Guid]; var MatchingCarrierCounts: Dictionary of [Code[20], Integer])
    var
        MatchCount: Integer;
    begin
        if not MatchingCarrierCounts.Get(PILItemNo, MatchCount) then begin
            MatchingCarrierCounts.Add(PILItemNo, 1);
            MatchingCarrierSystemIds.Add(PILItemNo, CarrierSystemId);
            exit;
        end;
        MatchingCarrierCounts.Set(PILItemNo, MatchCount + 1);
    end;

    local procedure ApplyStructuralCoverageForPILLine(PNEPILHeader: Record "PNE PIL Header"; PILLineNo: Integer)
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", PILLineNo);
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Structural driver");
        if PNEPILTarget.FindSet() then
            repeat
                AddStructuralCoverageForTarget(PNEPILHeader, PNEPILTarget);
            until PNEPILTarget.Next() = 0;
    end;

    local procedure FindStructuralDriversInCarrier(PNEPILHeader: Record "PNE PIL Header"; CarrierProdOrderLine: Record "Prod. Order Line")
    var
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
        HigherDriverBOMItemIndex: Dictionary of [Text, Boolean];
        IndexedHigherDriverBOMs: Dictionary of [Text, Boolean];
        PositiveDriverLineCache: Dictionary of [Text, Boolean];
        TargetCountBefore: Integer;
    begin
        TargetCountBefore := GetStructuralTargetCountForCarrierLine(PNEPILHeader, CarrierProdOrderLine);
        FindStructuralDriversInLine(
            PNEPILHeader,
            CarrierProdOrderLine,
            CarrierProdOrderLine,
            TempVisitedProdOrderLine,
            PositiveDriverLineCache,
            HigherDriverBOMItemIndex,
            IndexedHigherDriverBOMs);
        NormalizeLiveStructuralTargetFactors(PNEPILHeader, CarrierProdOrderLine);
        if GetStructuralTargetCountForCarrierLine(PNEPILHeader, CarrierProdOrderLine) = TargetCountBefore then
            FindStructuralDriversInCarrierBOM(PNEPILHeader, CarrierProdOrderLine);
    end;

    local procedure NormalizeLiveStructuralTargetFactors(PNEPILHeader: Record "PNE PIL Header"; CarrierProdOrderLine: Record "Prod. Order Line")
    var
        PNEPILTarget: Record "PNE PIL Target";
        MasterQuantityPerCarrier: Decimal;
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Structural driver");
        PNEPILTarget.SetRange("Carrier Type", PNEPILTarget."Carrier Type"::"Production Order Line");
        PNEPILTarget.SetRange("Carrier Status", CarrierProdOrderLine.Status);
        PNEPILTarget.SetRange("Carrier Production Order No.", CarrierProdOrderLine."Prod. Order No.");
        PNEPILTarget.SetRange("Carrier Order Line No.", CarrierProdOrderLine."Line No.");
        PNEPILTarget.SetRange("Carrier Component Line No.", 0);
        PNEPILTarget.SetRange("Analysis Source", PNEPILTarget."Analysis Source"::"Live Production Order");
        if PNEPILTarget.FindSet(true) then
            repeat
                PNEPILTarget."Observed Live Qty. per Carrier" := PNEPILTarget."Quantity per Carrier";
                Clear(MasterQuantityPerCarrier);
                if TryGetOrderBOMStructuralQuantityPerCarrier(
                     CarrierProdOrderLine,
                     PNEPILTarget."PIL Item No.",
                     MasterQuantityPerCarrier) and
                   (MasterQuantityPerCarrier > QuantityTolerance()) and
                   (PNEPILTarget."Quantity per Carrier" > MasterQuantityPerCarrier + QuantityTolerance())
                then begin
                    PNEPILTarget."Quantity per Carrier" := MasterQuantityPerCarrier;
                    PNEPILTarget."Analysis Source" := PNEPILTarget."Analysis Source"::"Current Master BOM";
                    PNEPILTarget."Factor Reconciliation Note" := CopyStr(
                        StrSubstNo(
                            DuplicateLiveFactorNormalizedTxt,
                            PNEPILTarget."Observed Live Qty. per Carrier",
                            MasterQuantityPerCarrier),
                        1,
                        MaxStrLen(PNEPILTarget."Factor Reconciliation Note"));
                end;
                PNEPILTarget.Modify(true);
            until PNEPILTarget.Next() = 0;
    end;

    [TryFunction]
    local procedure TryGetOrderBOMStructuralQuantityPerCarrier(CarrierProdOrderLine: Record "Prod. Order Line"; PILItemNo: Code[20]; var QuantityPerCarrier: Decimal)
    var
        BOMPath: List of [Code[20]];
        ProductionBOMNo: Code[20];
        UseRequestedVersion: Boolean;
    begin
        Clear(QuantityPerCarrier);
        ProductionBOMNo := GetProductionBOMNoForLine(CarrierProdOrderLine);
        if ProductionBOMNo = '' then
            Error(ProductionBOMMissingErr, ProductionBOMNo);
        UseRequestedVersion := CarrierProdOrderLine."Production BOM Version Code" <> '';
        if not HasCertifiedProductionBOM(
             ProductionBOMNo,
             GetCarrierCalculationDate(CarrierProdOrderLine),
             CarrierProdOrderLine."Production BOM Version Code",
             UseRequestedVersion)
        then
            Error(ProductionBOMNotCertifiedErr, ProductionBOMNo);
        CheckRootBOMUnitOfMeasure(
            ProductionBOMNo,
            CarrierProdOrderLine."Production BOM Version Code",
            UseRequestedVersion,
            GetCarrierCalculationDate(CarrierProdOrderLine),
            CarrierProdOrderLine."Unit of Measure Code");
        SumMasterStructuralQuantityPerCarrier(
            ProductionBOMNo,
            GetCarrierCalculationDate(CarrierProdOrderLine),
            PILItemNo,
            1,
            CarrierProdOrderLine."Production BOM Version Code",
            UseRequestedVersion,
            QuantityPerCarrier,
            BOMPath);
    end;

    local procedure FindStructuralDriversInLine(PNEPILHeader: Record "PNE PIL Header"; CarrierProdOrderLine: Record "Prod. Order Line"; CurrentProdOrderLine: Record "Prod. Order Line"; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary; var PositiveDriverLineCache: Dictionary of [Text, Boolean]; var HigherDriverBOMItemIndex: Dictionary of [Text, Boolean]; var IndexedHigherDriverBOMs: Dictionary of [Text, Boolean])
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        PNEPILLine: Record "PNE PIL Line";
        ProdOrderComponent: Record "Prod. Order Component";
        TempRelevantChildProdOrderLine: Record "Prod. Order Line" temporary;
        HasChildProductionOrderLine: Boolean;
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                HasChildProductionOrderLine := FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine);
                if GetPILLine(PNEPILHeader, ProdOrderComponent."Item No.", PNEPILLine) and
                   (PNEPILLine.Quantity > QuantityTolerance()) and
                   not ShouldResolvePILLineThroughCALC(PNEPILLine, CarrierProdOrderLine)
                then begin
                    if not HasHigherImportedStructuralDriverOnLine(
                         PNEPILHeader,
                         CurrentProdOrderLine,
                         ProdOrderComponent,
                         HigherDriverBOMItemIndex,
                         IndexedHigherDriverBOMs)
                    then begin
                        if HasChildProductionOrderLine then
                            CheckLinkedProductionOrderUnitOfMeasure(ProdOrderComponent, ChildProdOrderLine);
                        AddStructuralTarget(PNEPILHeader, PNEPILLine, CarrierProdOrderLine, ProdOrderComponent);
                    end;
                end else
                    if HasChildProductionOrderLine then begin
                        TempRelevantChildProdOrderLine.DeleteAll();
                        if HasPositiveStructuralPILDriverInLineCached(
                            PNEPILHeader,
                            ChildProdOrderLine,
                            TempRelevantChildProdOrderLine,
                            PositiveDriverLineCache)
                        then begin
                            CheckLinkedProductionOrderUnitOfMeasure(ProdOrderComponent, ChildProdOrderLine);
                            FindStructuralDriversInLine(
                                PNEPILHeader,
                                CarrierProdOrderLine,
                                ChildProdOrderLine,
                                TempVisitedProdOrderLine,
                                PositiveDriverLineCache,
                                HigherDriverBOMItemIndex,
                                IndexedHigherDriverBOMs);
                        end else
                            if IsIndependentCarrierChild(CurrentProdOrderLine, ProdOrderComponent, ChildProdOrderLine) and
                               HasPositiveStructuralPILDriverInProductionOrderLineBOM(PNEPILHeader, ChildProdOrderLine)
                            then
                                FindStructuralDriversInCarrierBOM(PNEPILHeader, ChildProdOrderLine);
                    end;
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure ShouldResolvePILLineThroughCALC(PNEPILLine: Record "PNE PIL Line"; CarrierProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        PNEPILGroup: Record "PNE PIL Group";
    begin
        if PNEPILLine."Group Code" = '' then
            exit(false);
        if not PNEPILGroup.Get(PNEPILLine."Group Code") then
            exit(false);
        if not PNEPILGroup.Enabled or (PNEPILGroup."CALC Item No." = '') then
            exit(false);
        exit(
            GetQuantityPerCarrierForItem(
                CarrierProdOrderLine,
                PNEPILGroup."CALC Item No.") > QuantityTolerance());
    end;

    local procedure HasHigherImportedStructuralDriverOnLine(PNEPILHeader: Record "PNE PIL Header"; CurrentProdOrderLine: Record "Prod. Order Line"; CandidateProdOrderComponent: Record "Prod. Order Component"; var HigherDriverBOMItemIndex: Dictionary of [Text, Boolean]; var IndexedHigherDriverBOMs: Dictionary of [Text, Boolean]): Boolean
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        HigherDriverPNEPILLine: Record "PNE PIL Line";
        PotentialHigherDriverProdOrderComponent: Record "Prod. Order Component";
        BOMIndexKey: Text;
        CalculationDate: Date;
        ProductionBOMNo: Code[20];
        RequestedVersionCode: Code[20];
        UseRequestedVersion: Boolean;
    begin
        CalculationDate := GetCarrierCalculationDate(CurrentProdOrderLine);
        PotentialHigherDriverProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        PotentialHigherDriverProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        PotentialHigherDriverProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        PotentialHigherDriverProdOrderComponent.SetFilter("Line No.", '<>%1', CandidateProdOrderComponent."Line No.");
        if PotentialHigherDriverProdOrderComponent.FindSet() then
            repeat
                if GetPILLine(PNEPILHeader, PotentialHigherDriverProdOrderComponent."Item No.", HigherDriverPNEPILLine) and
                   (HigherDriverPNEPILLine.Quantity > QuantityTolerance())
                then begin
                    Clear(ProductionBOMNo);
                    Clear(RequestedVersionCode);
                    UseRequestedVersion := false;
                    if FindChildProdOrderLine(PotentialHigherDriverProdOrderComponent, ChildProdOrderLine) then begin
                        ProductionBOMNo := GetProductionBOMNoForLine(ChildProdOrderLine);
                        RequestedVersionCode := ChildProdOrderLine."Production BOM Version Code";
                        UseRequestedVersion := true;
                    end else
                        ProductionBOMNo := GetProductionBOMNoForComponent(PotentialHigherDriverProdOrderComponent);

                    if (ProductionBOMNo <> '') and
                       HasCertifiedProductionBOM(
                         ProductionBOMNo,
                         CalculationDate,
                         RequestedVersionCode,
                         UseRequestedVersion)
                    then begin
                        EnsureProductionBOMItemIndex(
                            ProductionBOMNo,
                            CalculationDate,
                            RequestedVersionCode,
                            UseRequestedVersion,
                            HigherDriverBOMItemIndex,
                            IndexedHigherDriverBOMs,
                            BOMIndexKey);
                        if HigherDriverBOMItemIndex.ContainsKey(
                             BOMIndexKey + '|' + CandidateProdOrderComponent."Item No.")
                        then
                            exit(true);
                    end;
                end;
            until PotentialHigherDriverProdOrderComponent.Next() = 0;
        exit(false);
    end;

    local procedure EnsureProductionBOMItemIndex(ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var ProductionBOMItemIndex: Dictionary of [Text, Boolean]; var IndexedProductionBOMs: Dictionary of [Text, Boolean]; var BOMIndexKey: Text)
    var
        BOMPath: List of [Code[20]];
    begin
        BOMIndexKey := GetProductionBOMIndexKey(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion);
        if IndexedProductionBOMs.ContainsKey(BOMIndexKey) then
            exit;

        IndexProductionBOMItems(
            BOMIndexKey,
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            ProductionBOMItemIndex,
            BOMPath);
        IndexedProductionBOMs.Add(BOMIndexKey, true);
    end;

    local procedure IndexProductionBOMItems(RootBOMIndexKey: Text; ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var ProductionBOMItemIndex: Dictionary of [Text, Boolean]; var BOMPath: List of [Code[20]])
    var
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
        ItemIndexKey: Text;
    begin
        if (ProductionBOMNo = '') or BOMPath.Contains(ProductionBOMNo) or
           (BOMPath.Count() >= MaximumProductionBOMDepth())
        then
            exit;
        BOMPath.Add(ProductionBOMNo);

        SetActiveProductionBOMLineFilters(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                ItemIndexKey := RootBOMIndexKey + '|' + ProductionBOMLine."No.";
                if not ProductionBOMItemIndex.ContainsKey(ItemIndexKey) then
                    ProductionBOMItemIndex.Add(ItemIndexKey, true);
                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if ChildProductionBOMNo <> '' then
                    IndexProductionBOMItems(
                        RootBOMIndexKey,
                        ChildProductionBOMNo,
                        CalculationDate,
                        '',
                        false,
                        ProductionBOMItemIndex,
                        BOMPath);
            until ProductionBOMLine.Next() = 0;

        BOMPath.Remove(ProductionBOMNo);
    end;

    local procedure GetProductionBOMIndexKey(ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean): Text
    begin
        exit(
            ProductionBOMNo + '|' +
            RequestedVersionCode + '|' +
            Format(UseRequestedVersion) + '|' +
            Format(CalculationDate, 0, 9));
    end;

    local procedure GetProductionOrderLineIndexKey(ProdOrderLine: Record "Prod. Order Line"): Text
    begin
        exit(
            Format(ProdOrderLine.Status.AsInteger()) + '|' +
            ProdOrderLine."Prod. Order No." + '|' +
            Format(ProdOrderLine."Line No."));
    end;

    local procedure HasPositiveStructuralPILDriverInLine(PNEPILHeader: Record "PNE PIL Header"; CurrentProdOrderLine: Record "Prod. Order Line"; var TempActiveProdOrderLine: Record "Prod. Order Line" temporary): Boolean
    var
        PositiveDriverLineCache: Dictionary of [Text, Boolean];
    begin
        exit(
            HasPositiveStructuralPILDriverInLineCached(
                PNEPILHeader,
                CurrentProdOrderLine,
                TempActiveProdOrderLine,
                PositiveDriverLineCache));
    end;

    local procedure HasPositiveStructuralPILDriverInLineCached(PNEPILHeader: Record "PNE PIL Header"; CurrentProdOrderLine: Record "Prod. Order Line"; var TempActiveProdOrderLine: Record "Prod. Order Line" temporary; var PositiveDriverLineCache: Dictionary of [Text, Boolean]): Boolean
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        PNEPILLine: Record "PNE PIL Line";
        ProdOrderComponent: Record "Prod. Order Component";
        LineIndexKey: Text;
        HasPositiveDriver: Boolean;
    begin
        LineIndexKey := GetProductionOrderLineIndexKey(CurrentProdOrderLine);
        if PositiveDriverLineCache.Get(LineIndexKey, HasPositiveDriver) then
            exit(HasPositiveDriver);
        if TempActiveProdOrderLine.Get(
             CurrentProdOrderLine.Status,
             CurrentProdOrderLine."Prod. Order No.",
             CurrentProdOrderLine."Line No.")
        then
            exit(false);
        TempActiveProdOrderLine := CurrentProdOrderLine;
        TempActiveProdOrderLine.Insert();

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if GetPILLine(PNEPILHeader, ProdOrderComponent."Item No.", PNEPILLine) and
                   (PNEPILLine.Quantity > QuantityTolerance())
                then
                    HasPositiveDriver := true;
                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                    if HasPositiveStructuralPILDriverInLineCached(
                         PNEPILHeader,
                         ChildProdOrderLine,
                         TempActiveProdOrderLine,
                         PositiveDriverLineCache)
                    then
                        HasPositiveDriver := true;
            until (ProdOrderComponent.Next() = 0) or HasPositiveDriver;

        TempActiveProdOrderLine.Get(
            CurrentProdOrderLine.Status,
            CurrentProdOrderLine."Prod. Order No.",
            CurrentProdOrderLine."Line No.");
        TempActiveProdOrderLine.Delete();
        PositiveDriverLineCache.Add(LineIndexKey, HasPositiveDriver);
        exit(HasPositiveDriver);
    end;

    local procedure HasPositiveStructuralPILDriverInProductionOrderLineBOM(PNEPILHeader: Record "PNE PIL Header"; ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        BOMPath: List of [Code[20]];
        ProductionBOMNo: Code[20];
    begin
        ProductionBOMNo := GetProductionBOMNoForLine(ProdOrderLine);
        if (ProductionBOMNo = '') or
           not HasCertifiedProductionBOM(
               ProductionBOMNo,
               GetCarrierCalculationDate(ProdOrderLine),
               ProdOrderLine."Production BOM Version Code",
               true)
        then
            exit(false);
        exit(
            HasPositiveStructuralPILDriverInBOM(
                PNEPILHeader,
                ProductionBOMNo,
                GetCarrierCalculationDate(ProdOrderLine),
                ProdOrderLine."Production BOM Version Code",
                true,
                BOMPath));
    end;

    local procedure IsIndependentCarrierChild(ParentProdOrderLine: Record "Prod. Order Line"; ChildProdOrderComponent: Record "Prod. Order Component"; ChildProdOrderLine: Record "Prod. Order Line"): Boolean
    begin
        if not IsCarrier(ChildProdOrderLine) then
            exit(false);
        exit(not ProductionOrderLineBOMContainsItem(ParentProdOrderLine, ChildProdOrderComponent."Item No."));
    end;

    local procedure AddStructuralTarget(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"; CarrierProdOrderLine: Record "Prod. Order Line"; DriverProdOrderComponent: Record "Prod. Order Component")
    var
        PNEPILTarget: Record "PNE PIL Target";
        QuantityPerCarrier: Decimal;
    begin
        CheckPILItemUnitOfMeasure(PNEPILLine);
        CheckProductionOrderLineUnitOfMeasure(CarrierProdOrderLine);
        CheckProductionOrderComponentUnitOfMeasure(DriverProdOrderComponent);
        if CarrierProdOrderLine.Quantity <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, CarrierProdOrderLine."Item No.");
        QuantityPerCarrier := DriverProdOrderComponent."Expected Quantity" / CarrierProdOrderLine.Quantity;
        if QuantityPerCarrier <= QuantityTolerance() then
            Error(ZeroQuantityPerErr, PNEPILLine."Item No.", CarrierProdOrderLine."Item No.");

        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", PNEPILLine."Line No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Structural driver");
        PNEPILTarget.SetRange("Carrier Type", PNEPILTarget."Carrier Type"::"Production Order Line");
        PNEPILTarget.SetRange("Carrier Status", CarrierProdOrderLine.Status);
        PNEPILTarget.SetRange("Carrier Production Order No.", CarrierProdOrderLine."Prod. Order No.");
        PNEPILTarget.SetRange("Carrier Order Line No.", CarrierProdOrderLine."Line No.");
        PNEPILTarget.SetRange("Carrier Component Line No.", 0);
        if PNEPILTarget.FindFirst() then begin
            PNEPILTarget."Quantity per Carrier" += QuantityPerCarrier;
            PNEPILTarget.Modify(true);
            exit;
        end;

        InsertTarget(
            PNEPILHeader,
            PNEPILLine,
            CarrierProdOrderLine,
            PNEPILTarget.Kind::"Structural driver",
            QuantityPerCarrier,
            0,
            '',
            '',
            0);
    end;

    local procedure FindStructuralDriversInCarrierBOM(PNEPILHeader: Record "PNE PIL Header"; CarrierProdOrderLine: Record "Prod. Order Line")
    var
        TempCarrierPNEPILTarget: Record "PNE PIL Target" temporary;
        ProductionBOMNo: Code[20];
        BOMPath: List of [Code[20]];
    begin
        ProductionBOMNo := GetProductionBOMNoForLine(CarrierProdOrderLine);
        if ProductionBOMNo = '' then
            exit;
        if not HasPositiveStructuralPILDriverInBOM(
            PNEPILHeader,
            ProductionBOMNo,
            GetCarrierCalculationDate(CarrierProdOrderLine),
            CarrierProdOrderLine."Production BOM Version Code",
            true,
            BOMPath)
        then
            exit;

        CheckProductionOrderLineUnitOfMeasure(CarrierProdOrderLine);
        CheckRootBOMUnitOfMeasure(
            ProductionBOMNo,
            CarrierProdOrderLine."Production BOM Version Code",
            true,
            GetCarrierCalculationDate(CarrierProdOrderLine),
            CarrierProdOrderLine."Unit of Measure Code");
        InitializeLineCarrierTemplate(TempCarrierPNEPILTarget, CarrierProdOrderLine);
        FindStructuralDriversInBOM(
            PNEPILHeader,
            TempCarrierPNEPILTarget,
            ProductionBOMNo,
            GetCarrierCalculationDate(CarrierProdOrderLine),
            1,
            CarrierProdOrderLine."Production BOM Version Code",
            true,
            BOMPath);
    end;

    local procedure FindStructuralDriversInUnlinkedComponent(PNEPILHeader: Record "PNE PIL Header"; CarrierProdOrderComponent: Record "Prod. Order Component")
    var
        CarrierProdOrderLine: Record "Prod. Order Line";
        TempCarrierPNEPILTarget: Record "PNE PIL Target" temporary;
        ProductionBOMNo: Code[20];
        BOMPath: List of [Code[20]];
    begin
        CarrierProdOrderLine.Get(
            CarrierProdOrderComponent.Status,
            CarrierProdOrderComponent."Prod. Order No.",
            CarrierProdOrderComponent."Prod. Order Line No.");
        ProductionBOMNo := GetProductionBOMNoForComponent(CarrierProdOrderComponent);
        if ProductionBOMNo = '' then
            exit;
        if not HasPositiveStructuralPILDriverInBOM(
            PNEPILHeader,
            ProductionBOMNo,
            GetCarrierCalculationDate(CarrierProdOrderLine),
            '',
            false,
            BOMPath)
        then
            exit;

        CheckProductionOrderComponentUnitOfMeasure(CarrierProdOrderComponent);
        CheckRootBOMUnitOfMeasure(
            ProductionBOMNo,
            '',
            false,
            GetCarrierCalculationDate(CarrierProdOrderLine),
            CarrierProdOrderComponent."Unit of Measure Code");
        InitializeComponentCarrierTemplate(TempCarrierPNEPILTarget, CarrierProdOrderComponent);
        FindStructuralDriversInBOM(
            PNEPILHeader,
            TempCarrierPNEPILTarget,
            ProductionBOMNo,
            GetCarrierCalculationDate(CarrierProdOrderLine),
            1,
            '',
            false,
            BOMPath);
    end;

    local procedure FindStructuralDriversInBOM(PNEPILHeader: Record "PNE PIL Header"; TempCarrierPNEPILTarget: Record "PNE PIL Target" temporary; ProductionBOMNo: Code[20]; CalculationDate: Date; QuantityPerCarrier: Decimal; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var BOMPath: List of [Code[20]])
    var
        PhysicalItemNos: Dictionary of [Code[20], Boolean];
        PhysicalItemBOMPath: List of [Code[20]];
        SuppressedPhysicalItemNos: List of [Code[20]];
        VisitedProductionBOMNos: Dictionary of [Code[20], Boolean];
    begin
        CollectPhysicalItemNosInBOM(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            PhysicalItemNos,
            VisitedProductionBOMNos,
            PhysicalItemBOMPath);
        FindStructuralDriversInBOMInternal(
            PNEPILHeader,
            TempCarrierPNEPILTarget,
            ProductionBOMNo,
            CalculationDate,
            QuantityPerCarrier,
            RequestedVersionCode,
            UseRequestedVersion,
            PhysicalItemNos,
            SuppressedPhysicalItemNos,
            BOMPath);
    end;

    local procedure FindStructuralDriversInBOMInternal(PNEPILHeader: Record "PNE PIL Header"; TempCarrierPNEPILTarget: Record "PNE PIL Target" temporary; ProductionBOMNo: Code[20]; CalculationDate: Date; QuantityPerCarrier: Decimal; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; PhysicalItemNos: Dictionary of [Code[20], Boolean]; var SuppressedPhysicalItemNos: List of [Code[20]]; var BOMPath: List of [Code[20]])
    var
        PNEPILLine: Record "PNE PIL Line";
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
        DirectPhysicalItemNos: Dictionary of [Code[20], Boolean];
        ProductionBOMHeadingNos: Dictionary of [Code[20], Boolean];
        RelevantBOMPath: List of [Code[20]];
        AddedPhysicalItemSuppression: Boolean;
    begin
        if BOMPath.Contains(ProductionBOMNo) then
            Error(CircularProductionBOMErr, ProductionBOMNo);
        if BOMPath.Count() >= MaximumProductionBOMDepth() then
            Error(ProductionBOMTooDeepErr, ProductionBOMNo);
        BOMPath.Add(ProductionBOMNo);

        CollectDirectProductionBOMHeadingNos(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            ProductionBOMHeadingNos);
        CollectDirectPhysicalItemNos(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            DirectPhysicalItemNos);
        SetActiveProductionBOMLineFilters(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion, ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if GetPILLine(PNEPILHeader, ProductionBOMLine."No.", PNEPILLine) and
                   (PNEPILLine.Quantity > QuantityTolerance()) and
                   IsPreferredStructuralBOMLine(ProductionBOMLine, PhysicalItemNos) and
                   not IsSuppressedPhysicalItem(ProductionBOMLine, SuppressedPhysicalItemNos)
                then begin
                    if ChildProductionBOMNo <> '' then
                        CheckChildBOMUnitOfMeasure(ProductionBOMLine, ChildProductionBOMNo, CalculationDate);
                    AddStructuralTargetFromTemplate(
                        PNEPILHeader,
                        PNEPILLine,
                        TempCarrierPNEPILTarget,
                        QuantityPerCarrier * GetBOMLineQuantity(ProductionBOMLine));
                end else
                    if (ChildProductionBOMNo <> '') and
                       not IsRedundantItemBOMExpansion(ProductionBOMLine, ProductionBOMHeadingNos)
                    then begin
                        Clear(RelevantBOMPath);
                        if HasPositiveStructuralPILDriverInBOM(
                            PNEPILHeader,
                            ChildProductionBOMNo,
                            CalculationDate,
                            '',
                            false,
                            RelevantBOMPath)
                        then begin
                            CheckChildBOMUnitOfMeasure(ProductionBOMLine, ChildProductionBOMNo, CalculationDate);
                            AddedPhysicalItemSuppression := false;
                            if (ProductionBOMLine.Type = ProductionBOMLine.Type::"Production BOM") and
                               DirectPhysicalItemNos.ContainsKey(ProductionBOMLine."No.") and
                               not SuppressedPhysicalItemNos.Contains(ProductionBOMLine."No.")
                            then begin
                                SuppressedPhysicalItemNos.Add(ProductionBOMLine."No.");
                                AddedPhysicalItemSuppression := true;
                            end;
                            FindStructuralDriversInBOMInternal(
                                PNEPILHeader,
                                TempCarrierPNEPILTarget,
                                ChildProductionBOMNo,
                                CalculationDate,
                                QuantityPerCarrier * GetBOMLineQuantity(ProductionBOMLine),
                                '',
                                false,
                                PhysicalItemNos,
                                SuppressedPhysicalItemNos,
                                BOMPath);
                            if AddedPhysicalItemSuppression then
                                SuppressedPhysicalItemNos.Remove(ProductionBOMLine."No.");
                        end;
                    end;
            until ProductionBOMLine.Next() = 0;

        BOMPath.Remove(ProductionBOMNo);
    end;

    local procedure HasPositiveStructuralPILDriverInBOM(PNEPILHeader: Record "PNE PIL Header"; ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var BOMPath: List of [Code[20]]): Boolean
    var
        PNEPILLine: Record "PNE PIL Line";
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
        HasDriver: Boolean;
    begin
        if BOMPath.Contains(ProductionBOMNo) then
            Error(CircularProductionBOMErr, ProductionBOMNo);
        if BOMPath.Count() >= MaximumProductionBOMDepth() then
            Error(ProductionBOMTooDeepErr, ProductionBOMNo);
        BOMPath.Add(ProductionBOMNo);

        SetActiveProductionBOMLineFilters(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion, ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if GetPILLine(PNEPILHeader, ProductionBOMLine."No.", PNEPILLine) and
                   (PNEPILLine.Quantity > QuantityTolerance())
                then
                    HasDriver := true
                else
                    if ChildProductionBOMNo <> '' then
                        HasDriver := HasPositiveStructuralPILDriverInBOM(
                            PNEPILHeader,
                            ChildProductionBOMNo,
                            CalculationDate,
                            '',
                            false,
                            BOMPath);
            until (ProductionBOMLine.Next() = 0) or HasDriver;

        BOMPath.Remove(ProductionBOMNo);
        exit(HasDriver);
    end;

    local procedure AddStructuralTargetFromTemplate(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"; TempCarrierPNEPILTarget: Record "PNE PIL Target" temporary; QuantityPerCarrier: Decimal)
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        CheckPILItemUnitOfMeasure(PNEPILLine);
        CheckCarrierTemplateUnitOfMeasure(TempCarrierPNEPILTarget);
        if TempCarrierPNEPILTarget."Original Carrier Quantity" <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, TempCarrierPNEPILTarget."Carrier Item No.");
        if QuantityPerCarrier <= QuantityTolerance() then
            Error(ZeroQuantityPerErr, PNEPILLine."Item No.", TempCarrierPNEPILTarget."Carrier Item No.");

        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        SetTargetCarrierFilter(PNEPILTarget, TempCarrierPNEPILTarget);
        PNEPILTarget.SetRange("PIL Line No.", PNEPILLine."Line No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Structural driver");
        if PNEPILTarget.FindFirst() then begin
            PNEPILTarget."Quantity per Carrier" += QuantityPerCarrier;
            PNEPILTarget.Modify(true);
            exit;
        end;

        InsertTargetFromCarrierTemplate(
            PNEPILHeader,
            PNEPILLine,
            TempCarrierPNEPILTarget,
            PNEPILTarget.Kind::"Structural driver",
            QuantityPerCarrier,
            0,
            '',
            '');
    end;

    local procedure InsertTargetFromCarrierTemplate(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"; TempCarrierPNEPILTarget: Record "PNE PIL Target" temporary; TargetKind: Enum "PNE PIL Target Kind"; QuantityPerCarrier: Decimal; AllocatedPILQuantity: Decimal; CALCItemNo: Code[20]; GroupCode: Code[20])
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.Init();
        PNEPILTarget."Header Entry No." := PNEPILHeader."Entry No.";
        PNEPILTarget."Line No." := GetNextTargetLineNo(PNEPILHeader);
        PNEPILTarget."PIL Line No." := PNEPILLine."Line No.";
        PNEPILTarget."PIL Item No." := PNEPILLine."Item No.";
        PNEPILTarget."PIL Item Description" := PNEPILLine.Description;
        PNEPILTarget."PIL Quantity" := PNEPILLine.Quantity;
        PNEPILTarget."Allocated PIL Quantity" := AllocatedPILQuantity;
        PNEPILTarget."Analysis Source" := PNEPILTarget."Analysis Source"::"Current Master BOM";
        PNEPILTarget."Carrier Type" := TempCarrierPNEPILTarget."Carrier Type";
        PNEPILTarget."Carrier Status" := TempCarrierPNEPILTarget."Carrier Status";
        PNEPILTarget."Carrier Production Order No." := TempCarrierPNEPILTarget."Carrier Production Order No.";
        PNEPILTarget."Carrier Order Line No." := TempCarrierPNEPILTarget."Carrier Order Line No.";
        PNEPILTarget."Carrier Component Line No." := TempCarrierPNEPILTarget."Carrier Component Line No.";
        PNEPILTarget."Carrier Item No." := TempCarrierPNEPILTarget."Carrier Item No.";
        PNEPILTarget."Carrier Description" := TempCarrierPNEPILTarget."Carrier Description";
        PNEPILTarget."Carrier SystemId" := TempCarrierPNEPILTarget."Carrier SystemId";
        PNEPILTarget."Carrier Variant Code" := TempCarrierPNEPILTarget."Carrier Variant Code";
        PNEPILTarget."Carrier Unit of Measure Code" := TempCarrierPNEPILTarget."Carrier Unit of Measure Code";
        PNEPILTarget.Kind := TargetKind;
        PNEPILTarget."Quantity per Carrier" := QuantityPerCarrier;
        PNEPILTarget."Original Carrier Quantity" := TempCarrierPNEPILTarget."Original Carrier Quantity";
        PNEPILTarget."CALC Item No." := CALCItemNo;
        PNEPILTarget."PIL Group Code" := GroupCode;
        PNEPILTarget.Resolution := ManualAllocationTxt;
        PNEPILTarget.Insert(true);
    end;

    local procedure InitializeLineCarrierTemplate(var TempCarrierPNEPILTarget: Record "PNE PIL Target" temporary; CarrierProdOrderLine: Record "Prod. Order Line")
    begin
        TempCarrierPNEPILTarget.Init();
        TempCarrierPNEPILTarget."Carrier Type" := TempCarrierPNEPILTarget."Carrier Type"::"Production Order Line";
        TempCarrierPNEPILTarget."Carrier Status" := CarrierProdOrderLine.Status;
        TempCarrierPNEPILTarget."Carrier Production Order No." := CarrierProdOrderLine."Prod. Order No.";
        TempCarrierPNEPILTarget."Carrier Order Line No." := CarrierProdOrderLine."Line No.";
        TempCarrierPNEPILTarget."Carrier Component Line No." := 0;
        TempCarrierPNEPILTarget."Carrier Item No." := CarrierProdOrderLine."Item No.";
        TempCarrierPNEPILTarget."Carrier Description" := CarrierProdOrderLine.Description;
        TempCarrierPNEPILTarget."Carrier SystemId" := CarrierProdOrderLine.SystemId;
        TempCarrierPNEPILTarget."Carrier Variant Code" := CarrierProdOrderLine."Variant Code";
        TempCarrierPNEPILTarget."Carrier Unit of Measure Code" := CarrierProdOrderLine."Unit of Measure Code";
        TempCarrierPNEPILTarget."Original Carrier Quantity" := CarrierProdOrderLine.Quantity;
    end;

    local procedure InitializeComponentCarrierTemplate(var TempCarrierPNEPILTarget: Record "PNE PIL Target" temporary; CarrierProdOrderComponent: Record "Prod. Order Component")
    begin
        TempCarrierPNEPILTarget.Init();
        TempCarrierPNEPILTarget."Carrier Type" := TempCarrierPNEPILTarget."Carrier Type"::"Production Order Component";
        TempCarrierPNEPILTarget."Carrier Status" := CarrierProdOrderComponent.Status;
        TempCarrierPNEPILTarget."Carrier Production Order No." := CarrierProdOrderComponent."Prod. Order No.";
        TempCarrierPNEPILTarget."Carrier Order Line No." := CarrierProdOrderComponent."Prod. Order Line No.";
        TempCarrierPNEPILTarget."Carrier Component Line No." := CarrierProdOrderComponent."Line No.";
        TempCarrierPNEPILTarget."Carrier Item No." := CarrierProdOrderComponent."Item No.";
        TempCarrierPNEPILTarget."Carrier Description" := CarrierProdOrderComponent.Description;
        TempCarrierPNEPILTarget."Carrier SystemId" := CarrierProdOrderComponent.SystemId;
        TempCarrierPNEPILTarget."Carrier Variant Code" := CarrierProdOrderComponent."Variant Code";
        TempCarrierPNEPILTarget."Carrier Unit of Measure Code" := CarrierProdOrderComponent."Unit of Measure Code";
        TempCarrierPNEPILTarget."Original Carrier Quantity" := CarrierProdOrderComponent."Expected Quantity";
    end;

    local procedure CheckPILItemUnitOfMeasure(PNEPILLine: Record "PNE PIL Line")
    var
        Item: Record Item;
    begin
        if not Item.Get(PNEPILLine."Item No.") then
            Error(PILItemNoLongerExistsErr, PNEPILLine."Item No.");
        if Item."Base Unit of Measure" <> PiecesUnitOfMeasureLbl then
            Error(UnsupportedPILItemUnitOfMeasureErr, PNEPILLine."Item No.", Item."Base Unit of Measure");
    end;

    local procedure CheckProductionOrderLineUnitOfMeasure(ProdOrderLine: Record "Prod. Order Line")
    var
        Item: Record Item;
    begin
        if not Item.Get(ProdOrderLine."Item No.") then
            Error(PILItemNoLongerExistsErr, ProdOrderLine."Item No.");
        if (ProdOrderLine."Unit of Measure Code" <> PiecesUnitOfMeasureLbl) or
           (Item."Base Unit of Measure" <> PiecesUnitOfMeasureLbl) or
           (Abs(ProdOrderLine."Qty. per Unit of Measure" - 1) > QuantityTolerance())
        then
            Error(UnsupportedCarrierUnitOfMeasureErr, ProdOrderLine."Item No.", ProdOrderLine."Unit of Measure Code");
    end;

    local procedure CheckProductionOrderComponentUnitOfMeasure(ProdOrderComponent: Record "Prod. Order Component")
    var
        Item: Record Item;
    begin
        if not Item.Get(ProdOrderComponent."Item No.") then
            Error(PILItemNoLongerExistsErr, ProdOrderComponent."Item No.");
        if (ProdOrderComponent."Unit of Measure Code" <> PiecesUnitOfMeasureLbl) or
           (Item."Base Unit of Measure" <> PiecesUnitOfMeasureLbl) or
           (Abs(ProdOrderComponent."Qty. per Unit of Measure" - 1) > QuantityTolerance())
        then
            Error(UnsupportedComponentUnitOfMeasureErr, ProdOrderComponent."Item No.", ProdOrderComponent."Unit of Measure Code");
    end;

    local procedure CheckLinkedProductionOrderUnitOfMeasure(ProdOrderComponent: Record "Prod. Order Component"; ChildProdOrderLine: Record "Prod. Order Line")
    begin
        CheckProductionOrderComponentUnitOfMeasure(ProdOrderComponent);
        CheckProductionOrderLineUnitOfMeasure(ChildProdOrderLine);
        if ProdOrderComponent."Unit of Measure Code" <> ChildProdOrderLine."Unit of Measure Code" then
            Error(LinkedOrderUnitOfMeasureErr, ProdOrderComponent."Item No.", ProdOrderComponent."Unit of Measure Code", ChildProdOrderLine."Unit of Measure Code");
    end;

    local procedure CheckCarrierTemplateUnitOfMeasure(TempCarrierPNEPILTarget: Record "PNE PIL Target" temporary)
    var
        CarrierProdOrderComponent: Record "Prod. Order Component";
        CarrierProdOrderLine: Record "Prod. Order Line";
    begin
        case TempCarrierPNEPILTarget."Carrier Type" of
            TempCarrierPNEPILTarget."Carrier Type"::"Production Order Line":
                begin
                    CarrierProdOrderLine.Get(
                        TempCarrierPNEPILTarget."Carrier Status",
                        TempCarrierPNEPILTarget."Carrier Production Order No.",
                        TempCarrierPNEPILTarget."Carrier Order Line No.");
                    CheckProductionOrderLineUnitOfMeasure(CarrierProdOrderLine);
                end;
            TempCarrierPNEPILTarget."Carrier Type"::"Production Order Component":
                begin
                    CarrierProdOrderComponent.Get(
                        TempCarrierPNEPILTarget."Carrier Status",
                        TempCarrierPNEPILTarget."Carrier Production Order No.",
                        TempCarrierPNEPILTarget."Carrier Order Line No.",
                        TempCarrierPNEPILTarget."Carrier Component Line No.");
                    CheckProductionOrderComponentUnitOfMeasure(CarrierProdOrderComponent);
                end;
        end;
    end;

    local procedure SnapshotCALCSource(var PNEPILTarget: Record "PNE PIL Target"; CarrierProdOrderLine: Record "Prod. Order Line"; CALCItemNo: Code[20])
    var
        SourceCALCProdOrderComponent: Record "Prod. Order Component";
        FoundCount: Integer;
    begin
        FindComponentInCarrierTree(CarrierProdOrderLine, CALCItemNo, SourceCALCProdOrderComponent, FoundCount);
        if FoundCount <> 1 then
            Error(CALCSourceAmbiguousErr, CALCItemNo, CarrierProdOrderLine."Item No.", FoundCount);
        CheckProductionOrderComponentUnitOfMeasure(SourceCALCProdOrderComponent);

        PNEPILTarget."Source CALC SystemId" := SourceCALCProdOrderComponent.SystemId;
        PNEPILTarget."Source CALC Status" := SourceCALCProdOrderComponent.Status;
        PNEPILTarget."CALC Source Prod. Order No." := SourceCALCProdOrderComponent."Prod. Order No.";
        PNEPILTarget."Source CALC Order Line No." := SourceCALCProdOrderComponent."Prod. Order Line No.";
        PNEPILTarget."Source CALC Component Line No." := SourceCALCProdOrderComponent."Line No.";
        PNEPILTarget."Source CALC Item No." := SourceCALCProdOrderComponent."Item No.";
        PNEPILTarget."Source CALC Variant Code" := SourceCALCProdOrderComponent."Variant Code";
        PNEPILTarget."CALC Source UOM Code" := SourceCALCProdOrderComponent."Unit of Measure Code";
        PNEPILTarget."Source CALC Expected Quantity" := SourceCALCProdOrderComponent."Expected Quantity";
        PNEPILTarget."Source CALC Quantity per" := SourceCALCProdOrderComponent."Quantity per";
        PNEPILTarget."Source CALC Qty. per UOM" := SourceCALCProdOrderComponent."Qty. per Unit of Measure";
    end;

    local procedure GetProductionBOMNoForLine(CarrierProdOrderLine: Record "Prod. Order Line"): Code[20]
    begin
        if CarrierProdOrderLine."Production BOM No." <> '' then
            exit(CarrierProdOrderLine."Production BOM No.");
        exit(
            GetProductionBOMNoForItem(
                CarrierProdOrderLine."Item No.",
                CarrierProdOrderLine."Location Code",
                CarrierProdOrderLine."Variant Code"));
    end;

    local procedure GetProductionBOMNoForItem(ItemNo: Code[20]; LocationCode: Code[10]; VariantCode: Code[10]): Code[20]
    var
        Item: Record Item;
        StockkeepingUnit: Record "Stockkeeping Unit";
    begin
        if StockkeepingUnit.Get(LocationCode, ItemNo, VariantCode) and
           (StockkeepingUnit."Production BOM No." <> '')
        then
            exit(StockkeepingUnit."Production BOM No.");
        if Item.Get(ItemNo) then
            exit(Item."Production BOM No.");
        exit('');
    end;

    local procedure GetProductionBOMNoForComponent(ProdOrderComponent: Record "Prod. Order Component"): Code[20]
    begin
        exit(
            GetProductionBOMNoForItem(
                ProdOrderComponent."Item No.",
                ProdOrderComponent."Location Code",
                ProdOrderComponent."Variant Code"));
    end;

    local procedure GetCarrierCalculationDate(CarrierProdOrderLine: Record "Prod. Order Line"): Date
    begin
        if CarrierProdOrderLine."Starting Date" <> 0D then
            exit(CarrierProdOrderLine."Starting Date");
        exit(CarrierProdOrderLine."Due Date");
    end;

    local procedure SetActiveProductionBOMLineFilters(ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var ProductionBOMLine: Record "Production BOM Line")
    var
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMVersion: Record "Production BOM Version";
        VersionManagement: Codeunit VersionManagement;
        VersionCode: Code[20];
    begin
        if not ProductionBOMHeader.Get(ProductionBOMNo) then
            Error(ProductionBOMMissingErr, ProductionBOMNo);

        if UseRequestedVersion and (RequestedVersionCode <> '') then
            VersionCode := RequestedVersionCode
        else
            VersionCode := VersionManagement.GetBOMVersion(ProductionBOMNo, CalculationDate, true);
        if VersionCode <> '' then begin
            ProductionBOMVersion.Get(ProductionBOMNo, VersionCode);
            if ProductionBOMVersion.Status <> ProductionBOMVersion.Status::Certified then
                Error(ProductionBOMNotCertifiedErr, ProductionBOMNo);
        end else
            if ProductionBOMHeader.Status <> ProductionBOMHeader.Status::Certified then
                Error(ProductionBOMNotCertifiedErr, ProductionBOMNo);

        ProductionBOMLine.Reset();
        ProductionBOMLine.SetRange("Production BOM No.", ProductionBOMNo);
        ProductionBOMLine.SetRange("Version Code", VersionCode);
        ProductionBOMLine.SetFilter("Starting Date", '%1|..%2', 0D, CalculationDate);
        ProductionBOMLine.SetFilter("Ending Date", '%1|%2..', 0D, CalculationDate);
    end;

    local procedure CheckRootBOMUnitOfMeasure(ProductionBOMNo: Code[20]; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; CalculationDate: Date; CarrierUnitOfMeasureCode: Code[10])
    var
        BOMUnitOfMeasureCode: Code[10];
    begin
        if CarrierUnitOfMeasureCode <> PiecesUnitOfMeasureLbl then
            Error(UnsupportedCarrierUnitOfMeasureErr, ProductionBOMNo, CarrierUnitOfMeasureCode);
        BOMUnitOfMeasureCode := GetProductionBOMUnitOfMeasure(ProductionBOMNo, RequestedVersionCode, UseRequestedVersion, CalculationDate);
        if BOMUnitOfMeasureCode <> PiecesUnitOfMeasureLbl then
            Error(UnsupportedBOMPiecesUnitOfMeasureErr, ProductionBOMNo, BOMUnitOfMeasureCode);
        if BOMUnitOfMeasureCode <> CarrierUnitOfMeasureCode then
            Error(UnsupportedBOMUnitOfMeasureErr, ProductionBOMNo, CarrierUnitOfMeasureCode, BOMUnitOfMeasureCode);
    end;

    local procedure CheckChildBOMUnitOfMeasure(ProductionBOMLine: Record "Production BOM Line"; ChildProductionBOMNo: Code[20]; CalculationDate: Date)
    var
        BOMUnitOfMeasureCode: Code[10];
    begin
        if ProductionBOMLine."Unit of Measure Code" <> PiecesUnitOfMeasureLbl then
            Error(UnsupportedBOMLineUnitOfMeasureErr, ProductionBOMLine."No.", ProductionBOMLine."Unit of Measure Code");
        BOMUnitOfMeasureCode := GetProductionBOMUnitOfMeasure(ChildProductionBOMNo, '', false, CalculationDate);
        if BOMUnitOfMeasureCode <> PiecesUnitOfMeasureLbl then
            Error(UnsupportedBOMPiecesUnitOfMeasureErr, ChildProductionBOMNo, BOMUnitOfMeasureCode);
        if ProductionBOMLine."Unit of Measure Code" <> BOMUnitOfMeasureCode then
            Error(UnsupportedBOMUnitOfMeasureErr, ChildProductionBOMNo, ProductionBOMLine."Unit of Measure Code", BOMUnitOfMeasureCode);
    end;

    local procedure GetProductionBOMUnitOfMeasure(ProductionBOMNo: Code[20]; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; CalculationDate: Date): Code[10]
    var
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMVersion: Record "Production BOM Version";
        VersionManagement: Codeunit VersionManagement;
        VersionCode: Code[20];
    begin
        if not ProductionBOMHeader.Get(ProductionBOMNo) then
            Error(ProductionBOMMissingErr, ProductionBOMNo);

        if UseRequestedVersion and (RequestedVersionCode <> '') then
            VersionCode := RequestedVersionCode
        else
            VersionCode := VersionManagement.GetBOMVersion(ProductionBOMNo, CalculationDate, true);
        if VersionCode = '' then
            exit(ProductionBOMHeader."Unit of Measure Code");

        ProductionBOMVersion.Get(ProductionBOMNo, VersionCode);
        exit(ProductionBOMVersion."Unit of Measure Code");
    end;

    local procedure GetChildProductionBOMNo(ProductionBOMLine: Record "Production BOM Line"): Code[20]
    var
        Item: Record Item;
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMNo: Code[20];
    begin
        case ProductionBOMLine.Type of
            ProductionBOMLine.Type::Item:
                if Item.Get(ProductionBOMLine."No.") then
                    ProductionBOMNo := Item."Production BOM No.";
            ProductionBOMLine.Type::"Production BOM":
                ProductionBOMNo := ProductionBOMLine."No.";
        end;

        if (ProductionBOMNo <> '') and ProductionBOMHeader.Get(ProductionBOMNo) then
            exit(ProductionBOMNo);
        exit('');
    end;

    local procedure GetBOMLineQuantity(ProductionBOMLine: Record "Production BOM Line"): Decimal
    var
        QuantityPerParent: Decimal;
    begin
        if ProductionBOMLine."Unit of Measure Code" <> PiecesUnitOfMeasureLbl then
            Error(UnsupportedBOMLineUnitOfMeasureErr, ProductionBOMLine."No.", ProductionBOMLine."Unit of Measure Code");
        if (ProductionBOMLine."Routing Link Code" <> '') or
           (ProductionBOMLine."Scrap %" <> 0) or
           (ProductionBOMLine."Calculation Formula" <> ProductionBOMLine."Calculation Formula"::" ")
        then
            Error(UnsupportedBOMLineErr, ProductionBOMLine."No.");

        QuantityPerParent := ProductionBOMLine.Quantity;
        if ProductionBOMLine.Type = ProductionBOMLine.Type::Item then begin
            if Abs(ProductionBOMLine.GetQtyPerUnitOfMeasure() - 1) > QuantityTolerance() then
                Error(UnsupportedBOMLineErr, ProductionBOMLine."No.");
            QuantityPerParent *= ProductionBOMLine.GetQtyPerUnitOfMeasure();
        end;
        exit(QuantityPerParent);
    end;

    local procedure ConfigureStructuralTargetAllocations(PNEPILHeader: Record "PNE PIL Header")
    var
        CurrentPNEPILTarget: Record "PNE PIL Target";
        CandidatePNEPILTarget: Record "PNE PIL Target";
    begin
        CurrentPNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CurrentPNEPILTarget.SetRange(Kind, CurrentPNEPILTarget.Kind::"Structural driver");
        if CurrentPNEPILTarget.FindSet() then
            repeat
                if not HasEarlierTargetForPILLineAndKind(CurrentPNEPILTarget) then begin
                    CandidatePNEPILTarget.Copy(CurrentPNEPILTarget);
                    CandidatePNEPILTarget.SetRange("Header Entry No.", CurrentPNEPILTarget."Header Entry No.");
                    CandidatePNEPILTarget.SetRange("PIL Line No.", CurrentPNEPILTarget."PIL Line No.");
                    CandidatePNEPILTarget.SetRange(Kind, CurrentPNEPILTarget.Kind);
                    if CandidatePNEPILTarget.Count() = 1 then begin
                        CandidatePNEPILTarget.FindFirst();
                        CandidatePNEPILTarget."Allocated PIL Quantity" := CandidatePNEPILTarget."PIL Quantity";
                        CandidatePNEPILTarget.Resolution := AutomaticResolutionTxt;
                        CandidatePNEPILTarget.Modify(true);
                    end else
                        if CandidatePNEPILTarget.FindSet(true) then
                            repeat
                                CandidatePNEPILTarget."Allocated PIL Quantity" := 0;
                                CandidatePNEPILTarget.Resolution := ManualAllocationTxt;
                                CandidatePNEPILTarget.Modify(true);
                            until CandidatePNEPILTarget.Next() = 0;
                end;
            until CurrentPNEPILTarget.Next() = 0;

        CurrentPNEPILTarget.Reset();
        CurrentPNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CurrentPNEPILTarget.SetRange(Kind, CurrentPNEPILTarget.Kind::"Structural driver");
        if CurrentPNEPILTarget.FindSet() then
            repeat
                if not HasEarlierTargetForPILLineAndKind(CurrentPNEPILTarget) then begin
                    CandidatePNEPILTarget.Copy(CurrentPNEPILTarget);
                    CandidatePNEPILTarget.SetRange("Header Entry No.", CurrentPNEPILTarget."Header Entry No.");
                    CandidatePNEPILTarget.SetRange("PIL Line No.", CurrentPNEPILTarget."PIL Line No.");
                    CandidatePNEPILTarget.SetRange(Kind, CurrentPNEPILTarget.Kind);
                    if CandidatePNEPILTarget.Count() > 1 then
                        DistributeSharedStructuralPILLine(PNEPILHeader, CurrentPNEPILTarget);
                end;
            until CurrentPNEPILTarget.Next() = 0;
    end;

    local procedure DistributeSharedStructuralPILLine(PNEPILHeader: Record "PNE PIL Header"; SourcePNEPILTarget: Record "PNE PIL Target")
    var
        CandidatePNEPILTarget: Record "PNE PIL Target";
        DesiredCarrierQuantity: Decimal;
        KnownRequiredQuantity: Decimal;
        RemainingQuantity: Decimal;
        UnknownCandidateCount: Integer;
    begin
        CandidatePNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CandidatePNEPILTarget.SetRange("PIL Line No.", SourcePNEPILTarget."PIL Line No.");
        CandidatePNEPILTarget.SetRange(Kind, SourcePNEPILTarget.Kind);
        if CandidatePNEPILTarget.FindSet(true) then
            repeat
                if TryGetCarrierQuantityFromUniqueStructuralTargets(
                    PNEPILHeader,
                    CandidatePNEPILTarget,
                    DesiredCarrierQuantity)
                then begin
                    CandidatePNEPILTarget."Allocated PIL Quantity" :=
                        DesiredCarrierQuantity * CandidatePNEPILTarget."Quantity per Carrier";
                    KnownRequiredQuantity += CandidatePNEPILTarget."Allocated PIL Quantity";
                end else
                    UnknownCandidateCount += 1;
                CandidatePNEPILTarget.Resolution := ManualAllocationTxt;
                CandidatePNEPILTarget.Modify(true);
            until CandidatePNEPILTarget.Next() = 0;

        if KnownRequiredQuantity > SourcePNEPILTarget."PIL Quantity" + QuantityTolerance() then begin
            CapSharedStructuralAllocationsToPILQuantity(
                PNEPILHeader,
                SourcePNEPILTarget);
            exit;
        end;

        RemainingQuantity := SourcePNEPILTarget."PIL Quantity" - KnownRequiredQuantity;
        if Abs(RemainingQuantity) <= QuantityTolerance() then
            RemainingQuantity := 0;

        if UnknownCandidateCount = 1 then begin
            CandidatePNEPILTarget.Reset();
            CandidatePNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
            CandidatePNEPILTarget.SetRange("PIL Line No.", SourcePNEPILTarget."PIL Line No.");
            CandidatePNEPILTarget.SetRange(Kind, SourcePNEPILTarget.Kind);
            if CandidatePNEPILTarget.FindSet(true) then
                repeat
                    if not TryGetCarrierQuantityFromUniqueStructuralTargets(
                        PNEPILHeader,
                        CandidatePNEPILTarget,
                        DesiredCarrierQuantity)
                    then begin
                        CandidatePNEPILTarget."Allocated PIL Quantity" := RemainingQuantity;
                        CandidatePNEPILTarget.Modify(true);
                    end;
                until CandidatePNEPILTarget.Next() = 0;
        end;
    end;

    local procedure CapSharedStructuralAllocationsToPILQuantity(PNEPILHeader: Record "PNE PIL Header"; SourcePNEPILTarget: Record "PNE PIL Target")
    var
        CandidatePNEPILTarget: Record "PNE PIL Target";
        RemainingQuantity: Decimal;
    begin
        RemainingQuantity := SourcePNEPILTarget."PIL Quantity";
        CandidatePNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CandidatePNEPILTarget.SetRange("PIL Line No.", SourcePNEPILTarget."PIL Line No.");
        CandidatePNEPILTarget.SetRange(Kind, SourcePNEPILTarget.Kind);
        if CandidatePNEPILTarget.FindSet(true) then
            repeat
                CandidatePNEPILTarget."Allocated PIL Quantity" := MinDecimal(
                    CandidatePNEPILTarget."Allocated PIL Quantity",
                    MaxDecimal(0, RemainingQuantity));
                RemainingQuantity -= CandidatePNEPILTarget."Allocated PIL Quantity";
                CandidatePNEPILTarget.Resolution := AutomaticResolutionTxt;
                CandidatePNEPILTarget.Modify(true);
            until CandidatePNEPILTarget.Next() = 0;
    end;

    local procedure TryGetCarrierQuantityFromUniqueStructuralTargets(PNEPILHeader: Record "PNE PIL Header"; SourcePNEPILTarget: Record "PNE PIL Target"; var DesiredCarrierQuantity: Decimal): Boolean
    var
        CarrierPNEPILTarget: Record "PNE PIL Target";
        CandidateCarrierQuantity: Decimal;
        HasEvidence: Boolean;
    begin
        Clear(DesiredCarrierQuantity);
        SetCarrierTargetFilter(CarrierPNEPILTarget, SourcePNEPILTarget);
        CarrierPNEPILTarget.SetRange(Kind, CarrierPNEPILTarget.Kind::"Structural driver");
        if CarrierPNEPILTarget.FindSet() then
            repeat
                if not HasMultipleStructuralTargetsForPILLine(PNEPILHeader, CarrierPNEPILTarget) then begin
                    if CarrierPNEPILTarget."Quantity per Carrier" <= QuantityTolerance() then
                        Error(ZeroQuantityPerErr, CarrierPNEPILTarget."PIL Item No.", CarrierPNEPILTarget."Carrier Item No.");
                    CandidateCarrierQuantity :=
                        Round(
                            CarrierPNEPILTarget."PIL Quantity" /
                            CarrierPNEPILTarget."Quantity per Carrier",
                            1,
                            '>');
                    CandidateCarrierQuantity := MaxDecimal(
                        CarrierPNEPILTarget."Original Carrier Quantity",
                        CandidateCarrierQuantity);
                    if HasEvidence and
                       (Abs(CandidateCarrierQuantity - DesiredCarrierQuantity) > QuantityTolerance())
                    then
                        exit(false);
                    DesiredCarrierQuantity := CandidateCarrierQuantity;
                    HasEvidence := true;
                end;
            until CarrierPNEPILTarget.Next() = 0;
        exit(HasEvidence);
    end;

    local procedure HasMultipleStructuralTargetsForPILLine(PNEPILHeader: Record "PNE PIL Header"; SourcePNEPILTarget: Record "PNE PIL Target"): Boolean
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", SourcePNEPILTarget."PIL Line No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Structural driver");
        exit(PNEPILTarget.Count() > 1);
    end;

    local procedure ApplyStructuralCoverage(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILLine: Record "PNE PIL Line";
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet(true) then
            repeat
                Clear(PNEPILLine."Covered By Item No.");
                Clear(PNEPILLine."Covered Quantity");
                PNEPILLine.Modify(true);
            until PNEPILLine.Next() = 0;

        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Structural driver");
        if PNEPILTarget.FindSet() then
            repeat
                AddStructuralCoverageForTarget(PNEPILHeader, PNEPILTarget);
            until PNEPILTarget.Next() = 0;
    end;

    local procedure RefreshPILCoverage(PNEPILHeader: Record "PNE PIL Header")
    begin
        ApplyStructuralCoverage(PNEPILHeader);
        MarkExistingNonPiecesPILLines(PNEPILHeader);
        MarkInformationalGroupHeaderPILLines(PNEPILHeader);
    end;

    local procedure MarkExistingNonPiecesPILLines(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILLine: Record "PNE PIL Line";
        ExistingPiecesQuantity: Decimal;
        NewCoveredQuantity: Decimal;
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet(true) then
            repeat
                if not PNEPILLine."Ignore for Reconciliation" and
                   (PNEPILLine.Quantity > QuantityTolerance())
                then
                    if IsNonPiecesPILItemAlreadyOnProductionOrder(
                         PNEPILHeader,
                         PNEPILLine."Item No.")
                    then begin
                        PNEPILLine."Covered Quantity" := PNEPILLine.Quantity;
                        PNEPILLine."Covered By Item No." := PNEPILLine."Item No.";
                        PNEPILLine.Modify(true);
                    end else
                        if not HasStructuralTarget(PNEPILHeader, PNEPILLine."Line No.") then begin
                            ExistingPiecesQuantity := GetExistingPiecesPILQuantityOnProductionOrder(
                                PNEPILHeader,
                                PNEPILLine."Item No.");
                            NewCoveredQuantity := MinDecimal(
                                PNEPILLine.Quantity,
                                MaxDecimal(PNEPILLine."Covered Quantity", ExistingPiecesQuantity));
                            if NewCoveredQuantity > PNEPILLine."Covered Quantity" + QuantityTolerance() then begin
                                PNEPILLine."Covered Quantity" := NewCoveredQuantity;
                                if PNEPILLine."Covered By Item No." = '' then
                                    PNEPILLine."Covered By Item No." := PNEPILLine."Item No.";
                                PNEPILLine.Modify(true);
                            end;
                        end;
            until PNEPILLine.Next() = 0;
    end;

    local procedure IsNonPiecesPILItemAlreadyOnProductionOrder(PNEPILHeader: Record "PNE PIL Header"; ItemNo: Code[20]): Boolean
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        ProdOrderComponent.SetRange(Status, PNEPILHeader."Production Order Status");
        ProdOrderComponent.SetRange("Prod. Order No.", PNEPILHeader."Production Order No.");
        ProdOrderComponent.SetRange("Item No.", ItemNo);
        if ProdOrderComponent.FindSet() then
            repeat
                if (ProdOrderComponent."Unit of Measure Code" <> PiecesUnitOfMeasureLbl) or
                   (Abs(ProdOrderComponent."Qty. per Unit of Measure" - 1) > QuantityTolerance())
                then
                    exit(true);
            until ProdOrderComponent.Next() = 0;
        exit(false);
    end;

    local procedure GetExistingPiecesPILQuantityOnProductionOrder(PNEPILHeader: Record "PNE PIL Header"; ItemNo: Code[20]): Decimal
    var
        ProdOrderComponent: Record "Prod. Order Component";
        ExistingQuantity: Decimal;
    begin
        ProdOrderComponent.SetRange(Status, PNEPILHeader."Production Order Status");
        ProdOrderComponent.SetRange("Prod. Order No.", PNEPILHeader."Production Order No.");
        ProdOrderComponent.SetRange("Item No.", ItemNo);
        if ProdOrderComponent.FindSet() then
            repeat
                if (ProdOrderComponent."Unit of Measure Code" = PiecesUnitOfMeasureLbl) and
                   (Abs(ProdOrderComponent."Qty. per Unit of Measure" - 1) <= QuantityTolerance())
                then
                    ExistingQuantity += ProdOrderComponent."Expected Quantity";
            until ProdOrderComponent.Next() = 0;
        exit(ExistingQuantity);
    end;

    local procedure MarkInformationalGroupHeaderPILLines(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILLine: Record "PNE PIL Line";
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet(true) then
            repeat
                if not PNEPILLine."Ignore for Reconciliation" and
                   (PNEPILLine.Quantity > QuantityTolerance()) and
                   IsInformationalGroupHeaderPILItem(PNEPILLine."Item No.")
                then begin
                    PNEPILLine."Covered Quantity" := PNEPILLine.Quantity;
                    PNEPILLine."Covered By Item No." := PNEPILLine."Item No.";
                    PNEPILLine.Modify(true);
                end;
            until PNEPILLine.Next() = 0;
    end;

    local procedure IsInformationalGroupHeaderPILItem(ItemNo: Code[20]): Boolean
    var
        Item: Record Item;
    begin
        if not Item.Get(ItemNo) then
            exit(false);
        exit(
            (CopyStr(ItemNo, 1, 2) = 'G.') and
            (Item.Type = Item.Type::"Non-Inventory") and
            (Item."Replenishment System" = Item."Replenishment System"::Purchase) and
            (Item."Production BOM No." = ''));
    end;

    local procedure EnsureNoAmbiguousStructuralCALCRoutes(PNEPILHeader: Record "PNE PIL Header")
    var
        LooseCarrierProdOrderLine: Record "Prod. Order Line";
        PNEPILGroup: Record "PNE PIL Group";
        PNEPILLine: Record "PNE PIL Line";
        StructuralDriverItemNo: Code[20];
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet() then
            repeat
                if not PNEPILLine."Ignore for Reconciliation" and
                   IsStructurallyResolvedPILLine(PNEPILHeader, PNEPILLine)
                then
                    if PNEPILGroup.Get(PNEPILLine."Group Code") then
                        if PNEPILGroup.Enabled and (PNEPILGroup."CALC Item No." <> '') then
                            if FindLooseCALCCarrier(
                                PNEPILHeader,
                                PNEPILLine,
                                PNEPILGroup."CALC Item No.",
                                LooseCarrierProdOrderLine)
                            then begin
                                StructuralDriverItemNo := PNEPILLine."Covered By Item No.";
                                if StructuralDriverItemNo = '' then
                                    StructuralDriverItemNo := PNEPILLine."Item No.";
                                Error(
                                    AmbiguousStructuralCALCRouteErr,
                                    PNEPILLine."Item No.",
                                    StructuralDriverItemNo,
                                    LooseCarrierProdOrderLine."Item No.",
                                    PNEPILGroup."CALC Item No.");
                            end;
            until PNEPILLine.Next() = 0;
    end;

    local procedure IsStructurallyResolvedPILLine(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"): Boolean
    begin
        exit(
            HasStructuralTarget(PNEPILHeader, PNEPILLine."Line No.") or
            (PNEPILLine."Covered Quantity" > QuantityTolerance()));
    end;

    local procedure FindLooseCALCCarrier(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"; CALCItemNo: Code[20]; var LooseCarrierProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        CarrierProdOrderLine: Record "Prod. Order Line";
        TempOuterCarrierProdOrderLine: Record "Prod. Order Line" temporary;
        QuantityPerCarrier: Decimal;
    begin
        Clear(LooseCarrierProdOrderLine);
        GetOuterCarrierLines(PNEPILHeader, TempOuterCarrierProdOrderLine);
        if TempOuterCarrierProdOrderLine.FindSet() then
            repeat
                CarrierProdOrderLine := TempOuterCarrierProdOrderLine;
                QuantityPerCarrier := GetQuantityPerCarrierForItem(CarrierProdOrderLine, CALCItemNo);
                if QuantityPerCarrier > QuantityTolerance() then begin
                    CheckProductionOrderLineUnitOfMeasure(CarrierProdOrderLine);
                    if not IsPILLineStructurallyRepresentedByCarrier(PNEPILHeader, PNEPILLine, CarrierProdOrderLine) then begin
                        LooseCarrierProdOrderLine := CarrierProdOrderLine;
                        exit(true);
                    end;
                end;
            until TempOuterCarrierProdOrderLine.Next() = 0;
        exit(false);
    end;

    local procedure IsPILLineStructurallyRepresentedByCarrier(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"; CarrierProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        CoveringPNEPILTarget: Record "PNE PIL Target";
        PNEPILTarget: Record "PNE PIL Target";
        MatchingTargetCount: Integer;
    begin
        PNEPILTarget.SetCurrentKey(
            "Header Entry No.",
            "Carrier Type",
            "Carrier Status",
            "Carrier Production Order No.",
            "Carrier Order Line No.",
            "Carrier Component Line No.");
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("Carrier Type", PNEPILTarget."Carrier Type"::"Production Order Line");
        PNEPILTarget.SetRange("Carrier Status", CarrierProdOrderLine.Status);
        PNEPILTarget.SetRange("Carrier Production Order No.", CarrierProdOrderLine."Prod. Order No.");
        PNEPILTarget.SetRange("Carrier Order Line No.", CarrierProdOrderLine."Line No.");
        PNEPILTarget.SetRange("Carrier Component Line No.", 0);
        if PNEPILTarget.FindSet() then
            repeat
                if (PNEPILTarget.Kind = PNEPILTarget.Kind::"Structural driver") and
                   (PNEPILTarget."PIL Line No." = PNEPILLine."Line No.")
                then
                    exit(true);
            until PNEPILTarget.Next() = 0;

        if PNEPILLine."Covered By Item No." = '' then
            exit(false);

        PNEPILTarget.Reset();
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILTarget.FindSet() then
            repeat
                if (PNEPILTarget.Kind = PNEPILTarget.Kind::"Structural driver") and
                   (PNEPILTarget."PIL Item No." = PNEPILLine."Covered By Item No.")
                then begin
                    MatchingTargetCount += 1;
                    CoveringPNEPILTarget := PNEPILTarget;
                end;
            until PNEPILTarget.Next() = 0;
        if MatchingTargetCount <> 1 then
            exit(false);
        exit(
            (CoveringPNEPILTarget."Carrier Type" = CoveringPNEPILTarget."Carrier Type"::"Production Order Line") and
            (CoveringPNEPILTarget."Carrier Status" = CarrierProdOrderLine.Status) and
            (CoveringPNEPILTarget."Carrier Production Order No." = CarrierProdOrderLine."Prod. Order No.") and
            (CoveringPNEPILTarget."Carrier Order Line No." = CarrierProdOrderLine."Line No.") and
            (CoveringPNEPILTarget."Carrier Component Line No." = 0));
    end;

    local procedure AddStructuralCoverageForTarget(PNEPILHeader: Record "PNE PIL Header"; PNEPILTarget: Record "PNE PIL Target")
    var
        CarrierProdOrderComponent: Record "Prod. Order Component";
        CarrierProdOrderLine: Record "Prod. Order Line";
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        case PNEPILTarget."Carrier Type" of
            PNEPILTarget."Carrier Type"::"Production Order Line":
                begin
                    CarrierProdOrderLine.Get(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.");
                    case PNEPILTarget."Analysis Source" of
                        PNEPILTarget."Analysis Source"::"Live Production Order":
                            MarkStructuralCoverageInLine(PNEPILHeader, PNEPILTarget, CarrierProdOrderLine, TempVisitedProdOrderLine);
                        PNEPILTarget."Analysis Source"::"Current Master BOM":
                            MarkStructuralCoverageInLineBOM(PNEPILHeader, PNEPILTarget, CarrierProdOrderLine);
                    end;
                end;
            PNEPILTarget."Carrier Type"::"Production Order Component":
                begin
                    CarrierProdOrderComponent.Get(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.",
                        PNEPILTarget."Carrier Component Line No.");
                    MarkStructuralCoverageInComponentBOM(PNEPILHeader, PNEPILTarget, CarrierProdOrderComponent);
                end;
        end;
    end;

    local procedure MarkStructuralCoverageInLine(PNEPILHeader: Record "PNE PIL Header"; PNEPILTarget: Record "PNE PIL Target"; CurrentProdOrderLine: Record "Prod. Order Line"; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
        TempCoveredVisitedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if ProdOrderComponent."Item No." = PNEPILTarget."PIL Item No." then begin
                    if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                        MarkImportedDescendants(
                            PNEPILHeader,
                            PNEPILTarget,
                            ChildProdOrderLine,
                            GetStructuralDriverCoverageQuantity(PNEPILTarget),
                            TempCoveredVisitedProdOrderLine)
                    else
                        MarkImportedDescendantsInDriverBOM(
                            PNEPILHeader,
                            PNEPILTarget,
                            ProdOrderComponent,
                            CurrentProdOrderLine);
                end else
                    if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                        MarkStructuralCoverageInLine(
                            PNEPILHeader,
                            PNEPILTarget,
                            ChildProdOrderLine,
                            TempVisitedProdOrderLine);
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure MarkImportedDescendantsInDriverBOM(PNEPILHeader: Record "PNE PIL Header"; PNEPILTarget: Record "PNE PIL Target"; DriverProdOrderComponent: Record "Prod. Order Component"; CurrentProdOrderLine: Record "Prod. Order Line")
    var
        BOMPath: List of [Code[20]];
        CalculationDate: Date;
        ProductionBOMNo: Code[20];
    begin
        ProductionBOMNo := GetProductionBOMNoForComponent(DriverProdOrderComponent);
        CalculationDate := GetCarrierCalculationDate(CurrentProdOrderLine);
        if (ProductionBOMNo = '') or
           not HasCertifiedProductionBOM(ProductionBOMNo, CalculationDate, '', false)
        then
            exit;

        MarkImportedBOMDescendants(
            PNEPILHeader,
            PNEPILTarget,
            ProductionBOMNo,
            CalculationDate,
            '',
            false,
            GetStructuralDriverCoverageQuantity(PNEPILTarget),
            BOMPath);
    end;

    local procedure MarkImportedDescendants(PNEPILHeader: Record "PNE PIL Header"; PNEPILTarget: Record "PNE PIL Target"; CurrentProdOrderLine: Record "Prod. Order Line"; DesiredParentQuantity: Decimal; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        PNEPILLine: Record "PNE PIL Line";
        ProdOrderComponent: Record "Prod. Order Component";
        TempRelevantChildProdOrderLine: Record "Prod. Order Line" temporary;
        DesiredComponentQuantity: Decimal;
        HasChildProdOrderLine: Boolean;
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;
        if CurrentProdOrderLine.Quantity <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, CurrentProdOrderLine."Item No.");

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                HasChildProdOrderLine := FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine);
                if (ProdOrderComponent."Item No." <> PNEPILTarget."PIL Item No.") and
                   GetPILLine(PNEPILHeader, ProdOrderComponent."Item No.", PNEPILLine)
                then begin
                    CheckProductionOrderComponentUnitOfMeasure(ProdOrderComponent);
                    DesiredComponentQuantity :=
                        DesiredParentQuantity * ProdOrderComponent."Expected Quantity" /
                        CurrentProdOrderLine.Quantity;
                    AddImportedStructuralCoverage(PNEPILLine, PNEPILTarget, DesiredComponentQuantity);
                end;
                if HasChildProdOrderLine then begin
                    TempRelevantChildProdOrderLine.DeleteAll();
                    if HasPositiveStructuralPILDriverInLine(
                         PNEPILHeader,
                         ChildProdOrderLine,
                         TempRelevantChildProdOrderLine)
                    then begin
                        CheckLinkedProductionOrderUnitOfMeasure(ProdOrderComponent, ChildProdOrderLine);
                        DesiredComponentQuantity :=
                            DesiredParentQuantity * ProdOrderComponent."Expected Quantity" /
                            CurrentProdOrderLine.Quantity;
                        MarkImportedDescendants(
                            PNEPILHeader,
                            PNEPILTarget,
                            ChildProdOrderLine,
                            DesiredComponentQuantity,
                            TempVisitedProdOrderLine);
                    end;
                end;
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure MarkStructuralCoverageInLineBOM(PNEPILHeader: Record "PNE PIL Header"; PNEPILTarget: Record "PNE PIL Target"; CarrierProdOrderLine: Record "Prod. Order Line")
    var
        BOMPath: List of [Code[20]];
        ProductionBOMNo: Code[20];
    begin
        ProductionBOMNo := GetProductionBOMNoForLine(CarrierProdOrderLine);
        if ProductionBOMNo <> '' then
            MarkStructuralCoverageInBOM(
                PNEPILHeader,
                PNEPILTarget,
                ProductionBOMNo,
                GetCarrierCalculationDate(CarrierProdOrderLine),
                CarrierProdOrderLine."Production BOM Version Code",
                true,
                BOMPath);
    end;

    local procedure MarkStructuralCoverageInComponentBOM(PNEPILHeader: Record "PNE PIL Header"; PNEPILTarget: Record "PNE PIL Target"; CarrierProdOrderComponent: Record "Prod. Order Component")
    var
        CarrierProdOrderLine: Record "Prod. Order Line";
        ProductionBOMNo: Code[20];
        BOMPath: List of [Code[20]];
    begin
        CarrierProdOrderLine.Get(
            CarrierProdOrderComponent.Status,
            CarrierProdOrderComponent."Prod. Order No.",
            CarrierProdOrderComponent."Prod. Order Line No.");
        ProductionBOMNo := GetProductionBOMNoForComponent(CarrierProdOrderComponent);
        if ProductionBOMNo <> '' then
            MarkStructuralCoverageInBOM(
                PNEPILHeader,
                PNEPILTarget,
                ProductionBOMNo,
                GetCarrierCalculationDate(CarrierProdOrderLine),
                '',
                false,
                BOMPath);
    end;

    local procedure MarkStructuralCoverageInBOM(PNEPILHeader: Record "PNE PIL Header"; PNEPILTarget: Record "PNE PIL Target"; ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var BOMPath: List of [Code[20]])
    var
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
        RelevantBOMPath: List of [Code[20]];
    begin
        if BOMPath.Contains(ProductionBOMNo) then
            Error(CircularProductionBOMErr, ProductionBOMNo);
        if BOMPath.Count() >= MaximumProductionBOMDepth() then
            Error(ProductionBOMTooDeepErr, ProductionBOMNo);
        BOMPath.Add(ProductionBOMNo);

        SetActiveProductionBOMLineFilters(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion, ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if (ProductionBOMLine."No." = PNEPILTarget."PIL Item No.") and
                    (ChildProductionBOMNo <> '')
                then begin
                    CheckChildBOMUnitOfMeasure(ProductionBOMLine, ChildProductionBOMNo, CalculationDate);
                    MarkImportedBOMDescendants(
                        PNEPILHeader,
                        PNEPILTarget,
                        ChildProductionBOMNo,
                        CalculationDate,
                        '',
                        false,
                        GetStructuralDriverCoverageQuantity(PNEPILTarget),
                        BOMPath);
                end else
                    if ChildProductionBOMNo <> '' then begin
                        Clear(RelevantBOMPath);
                        if HasStructuralItemInBOM(
                            PNEPILTarget."PIL Item No.",
                            ChildProductionBOMNo,
                            CalculationDate,
                            '',
                            false,
                            RelevantBOMPath)
                        then begin
                            CheckChildBOMUnitOfMeasure(ProductionBOMLine, ChildProductionBOMNo, CalculationDate);
                            MarkStructuralCoverageInBOM(
                                PNEPILHeader,
                                PNEPILTarget,
                                ChildProductionBOMNo,
                                CalculationDate,
                                '',
                                false,
                                BOMPath);
                        end;
                    end;
            until ProductionBOMLine.Next() = 0;

        BOMPath.Remove(ProductionBOMNo);
    end;

    local procedure MarkImportedBOMDescendants(PNEPILHeader: Record "PNE PIL Header"; PNEPILTarget: Record "PNE PIL Target"; ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; DesiredParentQuantity: Decimal; var BOMPath: List of [Code[20]])
    var
        PNEPILLine: Record "PNE PIL Line";
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
        RelevantBOMPath: List of [Code[20]];
        DesiredComponentQuantity: Decimal;
    begin
        if BOMPath.Contains(ProductionBOMNo) then
            Error(CircularProductionBOMErr, ProductionBOMNo);
        if BOMPath.Count() >= MaximumProductionBOMDepth() then
            Error(ProductionBOMTooDeepErr, ProductionBOMNo);
        BOMPath.Add(ProductionBOMNo);

        SetActiveProductionBOMLineFilters(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion, ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                DesiredComponentQuantity := 0;
                if (ProductionBOMLine."No." <> PNEPILTarget."PIL Item No.") and
                   GetPILLine(PNEPILHeader, ProductionBOMLine."No.", PNEPILLine)
                then begin
                    DesiredComponentQuantity := DesiredParentQuantity * GetBOMLineQuantity(ProductionBOMLine);
                    AddImportedStructuralCoverage(PNEPILLine, PNEPILTarget, DesiredComponentQuantity);
                end;
                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if ChildProductionBOMNo <> '' then begin
                    Clear(RelevantBOMPath);
                    if HasPositiveStructuralPILDriverInBOM(
                         PNEPILHeader,
                         ChildProductionBOMNo,
                         CalculationDate,
                         '',
                         false,
                         RelevantBOMPath)
                    then begin
                        CheckChildBOMUnitOfMeasure(ProductionBOMLine, ChildProductionBOMNo, CalculationDate);
                        if DesiredComponentQuantity = 0 then
                            DesiredComponentQuantity := DesiredParentQuantity * GetBOMLineQuantity(ProductionBOMLine);
                        MarkImportedBOMDescendants(
                            PNEPILHeader,
                            PNEPILTarget,
                            ChildProductionBOMNo,
                            CalculationDate,
                            '',
                            false,
                            DesiredComponentQuantity,
                            BOMPath);
                    end;
                end;
            until ProductionBOMLine.Next() = 0;

        BOMPath.Remove(ProductionBOMNo);
    end;

    local procedure AddImportedStructuralCoverage(var PNEPILLine: Record "PNE PIL Line"; PNEPILTarget: Record "PNE PIL Target"; DesiredComponentQuantity: Decimal)
    var
        RemainingQuantity: Decimal;
    begin
        if DesiredComponentQuantity <= QuantityTolerance() then
            exit;
        RemainingQuantity := PNEPILLine.Quantity - PNEPILLine."Covered Quantity";
        if RemainingQuantity <= QuantityTolerance() then
            exit;
        PNEPILLine."Covered Quantity" += MinDecimal(RemainingQuantity, DesiredComponentQuantity);
        if PNEPILLine."Covered By Item No." = '' then
            PNEPILLine."Covered By Item No." := PNEPILTarget."PIL Item No.";
        PNEPILLine.Modify(true);
    end;

    local procedure GetStructuralDriverCoverageQuantity(PNEPILTarget: Record "PNE PIL Target"): Decimal
    begin
        if PNEPILTarget."Driver Suggested Quantity" > QuantityTolerance() then
            exit(
                PNEPILTarget."Driver Suggested Quantity" *
                PNEPILTarget."Quantity per Carrier");
        exit(PNEPILTarget."Allocated PIL Quantity");
    end;

    local procedure BuildCALCTargets(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILLine: Record "PNE PIL Line";
        QuantityToAllocate: Decimal;
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet() then
            repeat
                if not PNEPILLine."Ignore for Reconciliation" and
                   (PNEPILLine."Group Code" <> '') and
                   not HasStructuralTarget(PNEPILHeader, PNEPILLine."Line No.")
                then begin
                    QuantityToAllocate := PNEPILLine.Quantity - PNEPILLine."Covered Quantity";
                    if QuantityToAllocate > QuantityTolerance() then
                        AddCALCTargetsForLine(PNEPILHeader, PNEPILLine, QuantityToAllocate);
                end;
            until PNEPILLine.Next() = 0;
    end;

    local procedure AddCALCTargetsForLine(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"; QuantityToAllocate: Decimal)
    var
        CarrierProdOrderLine: Record "Prod. Order Line";
        PNEPILGroup: Record "PNE PIL Group";
        TempOuterCarrierProdOrderLine: Record "Prod. Order Line" temporary;
        CandidateCount: Integer;
        ExistingActualQuantity: Decimal;
        QuantityPerCarrier: Decimal;
    begin
        PNEPILGroup.Get(PNEPILLine."Group Code");
        PNEPILGroup.TestField(Enabled, true);
        PNEPILGroup.TestField("CALC Item No.");
        CheckPILItemUnitOfMeasure(PNEPILLine);

        GetOuterCarrierLines(PNEPILHeader, TempOuterCarrierProdOrderLine);
        if TempOuterCarrierProdOrderLine.FindSet() then
            repeat
                CarrierProdOrderLine := TempOuterCarrierProdOrderLine;
                QuantityPerCarrier := GetPILGroupCapacityPerCarrier(
                    CarrierProdOrderLine,
                    PNEPILGroup);
                if QuantityPerCarrier > QuantityTolerance() then begin
                    CheckProductionOrderLineUnitOfMeasure(CarrierProdOrderLine);
                    ExistingActualQuantity :=
                        GetQuantityPerCarrierForItem(
                            CarrierProdOrderLine,
                            PNEPILLine."Item No.") *
                        CarrierProdOrderLine.Quantity;
                    CandidateCount += 1;
                    InsertTarget(
                        PNEPILHeader,
                        PNEPILLine,
                        CarrierProdOrderLine,
                        Enum::"PNE PIL Target Kind"::"CALC replacement",
                        QuantityPerCarrier,
                        0,
                        PNEPILGroup."CALC Item No.",
                        PNEPILGroup.Code,
                        ExistingActualQuantity);
                    AddExistingCALCGroupCompanionTargets(
                        PNEPILHeader,
                        PNEPILGroup,
                        CarrierProdOrderLine,
                        QuantityPerCarrier);
                end;
            until TempOuterCarrierProdOrderLine.Next() = 0;

        if CandidateCount = 0 then
            Error(CALCCarrierMissingErr, PNEPILLine."Item No.", PNEPILGroup."CALC Item No.");
        if CandidateCount = 1 then
            SetAutomaticAllocation(PNEPILHeader, PNEPILLine."Line No.", QuantityToAllocate)
        else
            SetManualAllocationRequired(PNEPILHeader, PNEPILLine."Line No.");
    end;

    local procedure AddExistingCALCGroupCompanionTargets(PNEPILHeader: Record "PNE PIL Header"; PNEPILGroup: Record "PNE PIL Group"; CarrierProdOrderLine: Record "Prod. Order Line"; GroupQuantityPerCarrier: Decimal)
    var
        CompanionPNEPILLine: Record "PNE PIL Line";
        ExistingPNEPILTarget: Record "PNE PIL Target";
        ExistingActualQuantity: Decimal;
    begin
        CompanionPNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CompanionPNEPILLine.SetRange("Group Code", PNEPILGroup.Code);
        CompanionPNEPILLine.SetFilter(Quantity, '>%1', QuantityTolerance());
        CompanionPNEPILLine.SetRange("Ignore for Reconciliation", false);
        if CompanionPNEPILLine.FindSet() then
            repeat
                ExistingActualQuantity :=
                    GetQuantityPerCarrierForItem(
                        CarrierProdOrderLine,
                        CompanionPNEPILLine."Item No.") *
                    CarrierProdOrderLine.Quantity;
                if (ExistingActualQuantity > QuantityTolerance()) and
                   not HasStructuralTarget(
                     PNEPILHeader,
                     CompanionPNEPILLine."Line No.")
                then begin
                    ExistingPNEPILTarget.Reset();
                    ExistingPNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
                    ExistingPNEPILTarget.SetRange("PIL Line No.", CompanionPNEPILLine."Line No.");
                    ExistingPNEPILTarget.SetRange(Kind, ExistingPNEPILTarget.Kind::"CALC replacement");
                    ExistingPNEPILTarget.SetRange("Carrier Type", ExistingPNEPILTarget."Carrier Type"::"Production Order Line");
                    ExistingPNEPILTarget.SetRange("Carrier Status", CarrierProdOrderLine.Status);
                    ExistingPNEPILTarget.SetRange("Carrier Production Order No.", CarrierProdOrderLine."Prod. Order No.");
                    ExistingPNEPILTarget.SetRange("Carrier Order Line No.", CarrierProdOrderLine."Line No.");
                    ExistingPNEPILTarget.SetRange("Carrier Component Line No.", 0);
                    if ExistingPNEPILTarget.IsEmpty() then
                        InsertTarget(
                            PNEPILHeader,
                            CompanionPNEPILLine,
                            CarrierProdOrderLine,
                            Enum::"PNE PIL Target Kind"::"CALC replacement",
                            GroupQuantityPerCarrier,
                            0,
                            PNEPILGroup."CALC Item No.",
                            PNEPILGroup.Code,
                            ExistingActualQuantity);
                end;
            until CompanionPNEPILLine.Next() = 0;
    end;

    local procedure GetPILGroupCapacityPerCarrier(CarrierProdOrderLine: Record "Prod. Order Line"; PNEPILGroup: Record "PNE PIL Group"): Decimal
    var
        PNEPILGroupItem: Record "PNE PIL Group Item";
        GroupCapacityPerCarrier: Decimal;
    begin
        GroupCapacityPerCarrier := GetQuantityPerCarrierForItem(
            CarrierProdOrderLine,
            PNEPILGroup."CALC Item No.");
        PNEPILGroupItem.SetRange("Group Code", PNEPILGroup.Code);
        PNEPILGroupItem.SetRange(Enabled, true);
        if PNEPILGroupItem.FindSet() then
            repeat
                GroupCapacityPerCarrier += GetQuantityPerCarrierForItem(
                    CarrierProdOrderLine,
                    PNEPILGroupItem."Item No.");
            until PNEPILGroupItem.Next() = 0;
        exit(GroupCapacityPerCarrier);
    end;

    local procedure InsertTarget(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"; CarrierProdOrderLine: Record "Prod. Order Line"; TargetKind: Enum "PNE PIL Target Kind"; QuantityPerCarrier: Decimal; AllocatedPILQuantity: Decimal; CALCItemNo: Code[20]; GroupCode: Code[20]; ExistingActualPILQuantity: Decimal)
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.Init();
        PNEPILTarget."Header Entry No." := PNEPILHeader."Entry No.";
        PNEPILTarget."Line No." := GetNextTargetLineNo(PNEPILHeader);
        PNEPILTarget."PIL Line No." := PNEPILLine."Line No.";
        PNEPILTarget."PIL Item No." := PNEPILLine."Item No.";
        PNEPILTarget."PIL Item Description" := PNEPILLine.Description;
        PNEPILTarget."PIL Quantity" := PNEPILLine.Quantity;
        PNEPILTarget."Allocated PIL Quantity" := AllocatedPILQuantity;
        PNEPILTarget."Analysis Source" := PNEPILTarget."Analysis Source"::"Live Production Order";
        PNEPILTarget."Carrier Type" := PNEPILTarget."Carrier Type"::"Production Order Line";
        PNEPILTarget."Carrier Status" := CarrierProdOrderLine.Status;
        PNEPILTarget."Carrier Production Order No." := CarrierProdOrderLine."Prod. Order No.";
        PNEPILTarget."Carrier Order Line No." := CarrierProdOrderLine."Line No.";
        PNEPILTarget."Carrier Component Line No." := 0;
        PNEPILTarget."Carrier Item No." := CarrierProdOrderLine."Item No.";
        PNEPILTarget."Carrier Description" := CarrierProdOrderLine.Description;
        PNEPILTarget."Carrier SystemId" := CarrierProdOrderLine.SystemId;
        PNEPILTarget."Carrier Variant Code" := CarrierProdOrderLine."Variant Code";
        PNEPILTarget."Carrier Unit of Measure Code" := CarrierProdOrderLine."Unit of Measure Code";
        PNEPILTarget.Kind := TargetKind;
        PNEPILTarget."Quantity per Carrier" := QuantityPerCarrier;
        PNEPILTarget."Original Carrier Quantity" := CarrierProdOrderLine.Quantity;
        PNEPILTarget."CALC Item No." := CALCItemNo;
        PNEPILTarget."PIL Group Code" := GroupCode;
        PNEPILTarget."Existing Actual PIL Quantity" := ExistingActualPILQuantity;
        PNEPILTarget.Resolution := ManualAllocationTxt;
        if TargetKind = PNEPILTarget.Kind::"CALC replacement" then begin
            SnapshotCALCSource(PNEPILTarget, CarrierProdOrderLine, CALCItemNo);
            EnsureCALCSourceNotUsedByAnotherGroup(PNEPILTarget);
        end;
        PNEPILTarget.Insert(true);
    end;

    local procedure EnsureCALCSourceNotUsedByAnotherGroup(PNEPILTarget: Record "PNE PIL Target")
    var
        ExistingPNEPILTarget: Record "PNE PIL Target";
    begin
        ExistingPNEPILTarget.SetRange("Header Entry No.", PNEPILTarget."Header Entry No.");
        ExistingPNEPILTarget.SetRange(Kind, ExistingPNEPILTarget.Kind::"CALC replacement");
        SetTargetCarrierFilter(ExistingPNEPILTarget, PNEPILTarget);
        ExistingPNEPILTarget.SetRange("Source CALC SystemId", PNEPILTarget."Source CALC SystemId");
        ExistingPNEPILTarget.SetFilter("PIL Group Code", '<>%1', PNEPILTarget."PIL Group Code");
        if not ExistingPNEPILTarget.IsEmpty() then
            Error(CALCSourceUsedByMultipleGroupsErr, PNEPILTarget."CALC Item No.", PNEPILTarget."Carrier Item No.");
    end;

    local procedure SetAutomaticAllocation(PNEPILHeader: Record "PNE PIL Header"; PILLineNo: Integer; QuantityToAllocate: Decimal)
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", PILLineNo);
        if PNEPILTarget.FindFirst() then begin
            PNEPILTarget."Allocated PIL Quantity" := QuantityToAllocate;
            PNEPILTarget.Resolution := AutomaticResolutionTxt;
            PNEPILTarget.Modify(true);
        end;
    end;

    local procedure SetManualAllocationRequired(PNEPILHeader: Record "PNE PIL Header"; PILLineNo: Integer)
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", PILLineNo);
        if PNEPILTarget.FindSet(true) then
            repeat
                PNEPILTarget."Allocated PIL Quantity" := 0;
                PNEPILTarget.Resolution := ManualAllocationTxt;
                PNEPILTarget.Modify(true);
            until PNEPILTarget.Next() = 0;
    end;

    local procedure RefreshAllocations(var PNEPILHeader: Record "PNE PIL Header")
    var
        HeaderChanged: Boolean;
        IsPrepared: Boolean;
    begin
        RecalculateTargetQuantities(PNEPILHeader);
        UpdateTargetAllocationStatus(PNEPILHeader);
        UpdateCarrierConflictResolutions(PNEPILHeader);
        IsPrepared :=
            AllAllocationsComplete(PNEPILHeader) and
            not HasUnresolvedCarrierQuantityConflict(PNEPILHeader);
        if IsPrepared then begin
            if PNEPILHeader.Status <> PNEPILHeader.Status::Prepared then begin
                PNEPILHeader.Status := PNEPILHeader.Status::Prepared;
                HeaderChanged := true;
            end;
            if PNEPILHeader."Prepared At" = 0DT then begin
                PNEPILHeader."Prepared At" := CurrentDateTime();
                HeaderChanged := true;
            end;
        end else begin
            if PNEPILHeader.Status <> PNEPILHeader.Status::"Allocation Required" then begin
                PNEPILHeader.Status := PNEPILHeader.Status::"Allocation Required";
                HeaderChanged := true;
            end;
            if PNEPILHeader."Prepared At" <> 0DT then begin
                Clear(PNEPILHeader."Prepared At");
                HeaderChanged := true;
            end;
        end;
        if HeaderChanged then
            PNEPILHeader.Modify(true);
    end;

    local procedure RecalculateTargetQuantities(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        NormalizeResidualStructuralTargetAllocations(PNEPILHeader);
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Structural driver");
        if PNEPILTarget.FindSet(true) then
            repeat
                if PNEPILTarget."Quantity per Carrier" <= QuantityTolerance() then
                    Error(ZeroQuantityPerErr, PNEPILTarget."PIL Item No.", PNEPILTarget."Carrier Item No.");
                PNEPILTarget."Driver Suggested Quantity" :=
                    CalculateStructuralDriverSuggestedQuantity(PNEPILTarget);
                PNEPILTarget."New Carrier Quantity" := PNEPILTarget."Driver Suggested Quantity";
                PNEPILTarget.Modify(true);
            until PNEPILTarget.Next() = 0;

        RecalculateCALCTargetQuantities(PNEPILHeader);
        RecalculatePointCarrierAdditionQuantities(PNEPILHeader);
        UpdateCarrierQuantityConflictState(PNEPILHeader);
    end;

    local procedure NormalizeResidualStructuralTargetAllocations(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILLine: Record "PNE PIL Line";
        PNEPILTarget: Record "PNE PIL Target";
        RemainingQuantity: Decimal;
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILLine.SetFilter("Covered Quantity", '>%1', QuantityTolerance());
        if PNEPILLine.FindSet() then
            repeat
                RemainingQuantity := PNEPILLine.Quantity - PNEPILLine."Covered Quantity";
                if RemainingQuantity < QuantityTolerance() then
                    RemainingQuantity := 0;
                PNEPILTarget.Reset();
                PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
                PNEPILTarget.SetRange("PIL Line No.", PNEPILLine."Line No.");
                PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Structural driver");
                if PNEPILTarget.Count() = 1 then begin
                    PNEPILTarget.FindFirst();
                    if Abs(PNEPILTarget."Allocated PIL Quantity" - RemainingQuantity) > QuantityTolerance() then begin
                        PNEPILTarget."Allocated PIL Quantity" := RemainingQuantity;
                        PNEPILTarget.Resolution := AutomaticResidualResolutionTxt;
                        PNEPILTarget.Modify(true);
                    end;
                end;
            until PNEPILLine.Next() = 0;
    end;

    local procedure CalculateStructuralDriverSuggestedQuantity(var PNEPILTarget: Record "PNE PIL Target"): Decimal
    var
        PNEPILLine: Record "PNE PIL Line";
        AdditionalCarrierQuantity: Decimal;
        BaseCarrierQuantity: Decimal;
        RequiredCarrierQuantity: Decimal;
    begin
        PNEPILLine.Get(PNEPILTarget."Header Entry No.", PNEPILTarget."PIL Line No.");
        if PNEPILLine."Covered Quantity" <= QuantityTolerance() then begin
            RequiredCarrierQuantity := Round(
                PNEPILTarget."Allocated PIL Quantity" / PNEPILTarget."Quantity per Carrier",
                1,
                '>');
            exit(MaxDecimal(PNEPILTarget."Original Carrier Quantity", RequiredCarrierQuantity));
        end;

        AdditionalCarrierQuantity := Round(
            PNEPILTarget."Allocated PIL Quantity" / PNEPILTarget."Quantity per Carrier",
            1,
            '>');
        if not TryGetBaseCarrierQuantityForResidual(PNEPILTarget, BaseCarrierQuantity) then
            BaseCarrierQuantity := 0;
        PNEPILTarget."Factor Reconciliation Note" := CopyStr(
            StrSubstNo(
                ResidualCarrierSuggestionTxt,
                PNEPILLine."Covered Quantity",
                PNEPILLine.Quantity,
                PNEPILTarget."Allocated PIL Quantity",
                PNEPILTarget."Quantity per Carrier",
                AdditionalCarrierQuantity,
                BaseCarrierQuantity + AdditionalCarrierQuantity),
            1,
            MaxStrLen(PNEPILTarget."Factor Reconciliation Note"));
        exit(BaseCarrierQuantity + AdditionalCarrierQuantity);
    end;

    local procedure TryGetBaseCarrierQuantityForResidual(SourcePNEPILTarget: Record "PNE PIL Target"; var BaseCarrierQuantity: Decimal): Boolean
    var
        CandidatePNEPILLine: Record "PNE PIL Line";
        CandidatePNEPILTarget: Record "PNE PIL Target";
        CandidateCarrierQuantity: Decimal;
        HasBaseQuantity: Boolean;
    begin
        BaseCarrierQuantity := SourcePNEPILTarget."Original Carrier Quantity";
        HasBaseQuantity := BaseCarrierQuantity > QuantityTolerance();
        SetCarrierTargetFilter(CandidatePNEPILTarget, SourcePNEPILTarget);
        CandidatePNEPILTarget.SetRange(Kind, CandidatePNEPILTarget.Kind::"Structural driver");
        if CandidatePNEPILTarget.FindSet() then
            repeat
                if (CandidatePNEPILTarget."Line No." <> SourcePNEPILTarget."Line No.") and
                   CandidatePNEPILLine.Get(
                       CandidatePNEPILTarget."Header Entry No.",
                       CandidatePNEPILTarget."PIL Line No.") and
                   (CandidatePNEPILLine."Covered Quantity" <= QuantityTolerance()) and
                   (CandidatePNEPILTarget."Quantity per Carrier" > QuantityTolerance())
                then begin
                    CandidateCarrierQuantity :=
                        Round(
                            CandidatePNEPILTarget."Allocated PIL Quantity" /
                            CandidatePNEPILTarget."Quantity per Carrier",
                            1,
                            '>');
                    CandidateCarrierQuantity := MaxDecimal(
                        CandidatePNEPILTarget."Original Carrier Quantity",
                        CandidateCarrierQuantity);
                    if not HasBaseQuantity or (CandidateCarrierQuantity > BaseCarrierQuantity) then
                        BaseCarrierQuantity := CandidateCarrierQuantity;
                    HasBaseQuantity := true;
                end;
            until CandidatePNEPILTarget.Next() = 0;
        exit(HasBaseQuantity);
    end;

    local procedure RecalculateCALCTargetQuantities(PNEPILHeader: Record "PNE PIL Header")
    var
        CurrentPNEPILTarget: Record "PNE PIL Target";
        GroupPNEPILTarget: Record "PNE PIL Target";
        ExistingActualQuantity: Decimal;
        TotalAllocatedQuantity: Decimal;
        TotalDesiredQuantity: Decimal;
        NewCarrierQuantity: Decimal;
    begin
        CurrentPNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CurrentPNEPILTarget.SetRange(Kind, CurrentPNEPILTarget.Kind::"CALC replacement");
        if CurrentPNEPILTarget.FindSet() then
            repeat
                if not HasEarlierCALCTargetForCarrierAndGroup(CurrentPNEPILTarget) then begin
                    GroupPNEPILTarget.Copy(CurrentPNEPILTarget);
                    SetCALCTargetGroupFilter(GroupPNEPILTarget, CurrentPNEPILTarget);
                    GroupPNEPILTarget.CalcSums("Allocated PIL Quantity");
                    TotalAllocatedQuantity := GroupPNEPILTarget."Allocated PIL Quantity";
                    Clear(ExistingActualQuantity);
                    if GroupPNEPILTarget.FindSet() then
                        repeat
                            ExistingActualQuantity += GroupPNEPILTarget."Existing Actual PIL Quantity";
                        until GroupPNEPILTarget.Next() = 0;
                    TotalDesiredQuantity := TotalAllocatedQuantity + ExistingActualQuantity;
                    if CurrentPNEPILTarget."Quantity per Carrier" <= QuantityTolerance() then
                        Error(ZeroQuantityPerErr, CurrentPNEPILTarget."CALC Item No.", CurrentPNEPILTarget."Carrier Item No.");
                    NewCarrierQuantity := Round(
                        TotalDesiredQuantity / CurrentPNEPILTarget."Quantity per Carrier",
                        1,
                        '>');
                    NewCarrierQuantity := MaxDecimal(
                        CurrentPNEPILTarget."Original Carrier Quantity",
                        NewCarrierQuantity);
                    if GroupPNEPILTarget.FindSet(true) then
                        repeat
                            GroupPNEPILTarget."Driver Suggested Quantity" := NewCarrierQuantity;
                            GroupPNEPILTarget."New Carrier Quantity" := NewCarrierQuantity;
                            GroupPNEPILTarget.Modify(true);
                        until GroupPNEPILTarget.Next() = 0;
                end;
            until CurrentPNEPILTarget.Next() = 0;
    end;

    local procedure RecalculatePointCarrierAdditionQuantities(PNEPILHeader: Record "PNE PIL Header")
    var
        CurrentPNEPILTarget: Record "PNE PIL Target";
        GroupPNEPILTarget: Record "PNE PIL Target";
        RequiredCarrierQuantity: Decimal;
        TargetCarrierQuantity: Decimal;
    begin
        CurrentPNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CurrentPNEPILTarget.SetRange(Kind, CurrentPNEPILTarget.Kind::"Point carrier addition");
        if CurrentPNEPILTarget.FindSet() then
            repeat
                if not HasEarlierTargetForCarrier(CurrentPNEPILTarget) then begin
                    Clear(RequiredCarrierQuantity);
                    SetPointCarrierAdditionFilter(GroupPNEPILTarget, CurrentPNEPILTarget);
                    if GroupPNEPILTarget.FindSet() then
                        repeat
                            if GroupPNEPILTarget."Quantity per Carrier" <= QuantityTolerance() then
                                Error(
                                    ZeroQuantityPerErr,
                                    GroupPNEPILTarget."PIL Item No.",
                                    GroupPNEPILTarget."New Point Carrier Item No.");
                            TargetCarrierQuantity := Round(
                                GroupPNEPILTarget."Allocated PIL Quantity" /
                                GroupPNEPILTarget."Quantity per Carrier",
                                1,
                                '>');
                            if TargetCarrierQuantity > RequiredCarrierQuantity then
                                RequiredCarrierQuantity := TargetCarrierQuantity;
                        until GroupPNEPILTarget.Next() = 0;

                    SetPointCarrierAdditionFilter(GroupPNEPILTarget, CurrentPNEPILTarget);
                    if GroupPNEPILTarget.FindSet(true) then
                        repeat
                            GroupPNEPILTarget."Driver Suggested Quantity" := RequiredCarrierQuantity;
                            GroupPNEPILTarget."New Carrier Quantity" := RequiredCarrierQuantity;
                            GroupPNEPILTarget.Modify(true);
                        until GroupPNEPILTarget.Next() = 0;
                end;
            until CurrentPNEPILTarget.Next() = 0;
    end;

    local procedure UpdateCarrierQuantityConflictState(PNEPILHeader: Record "PNE PIL Header")
    var
        CarrierPNEPILTarget: Record "PNE PIL Target";
        CurrentPNEPILTarget: Record "PNE PIL Target";
        ChosenCarrierQuantity: Decimal;
        RequiredCarrierQuantity: Decimal;
        HasCarrierQuantityChoice: Boolean;
    begin
        CurrentPNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CurrentPNEPILTarget.SetFilter(
            Kind,
            '%1|%2',
            CurrentPNEPILTarget.Kind::"Structural driver",
            CurrentPNEPILTarget.Kind::"CALC replacement");
        if CurrentPNEPILTarget.FindSet() then
            repeat
                if not HasEarlierQuantityTargetForCarrier(CurrentPNEPILTarget) then begin
                    Clear(ChosenCarrierQuantity);
                    Clear(RequiredCarrierQuantity);
                    HasCarrierQuantityChoice := false;

                    SetCarrierTargetFilter(CarrierPNEPILTarget, CurrentPNEPILTarget);
                    CarrierPNEPILTarget.SetFilter(
                        Kind,
                        '%1|%2',
                        CarrierPNEPILTarget.Kind::"Structural driver",
                        CarrierPNEPILTarget.Kind::"CALC replacement");
                    if CarrierPNEPILTarget.FindSet() then
                        repeat
                            RequiredCarrierQuantity := MaxDecimal(
                                RequiredCarrierQuantity,
                                MaxDecimal(
                                    CarrierPNEPILTarget."Original Carrier Quantity",
                                    CarrierPNEPILTarget."Driver Suggested Quantity"));

                            if CarrierPNEPILTarget."Carrier Qty. Choice Active" then
                                if HasCarrierQuantityChoice then begin
                                    if Abs(
                                         CarrierPNEPILTarget."Chosen Carrier Quantity" -
                                         ChosenCarrierQuantity) > QuantityTolerance()
                                    then
                                        Error(
                                            InconsistentCarrierQuantityChoiceErr,
                                            CarrierPNEPILTarget."Carrier Item No.");
                                end else begin
                                    ChosenCarrierQuantity := CarrierPNEPILTarget."Chosen Carrier Quantity";
                                    HasCarrierQuantityChoice := true;
                                end;
                        until CarrierPNEPILTarget.Next() = 0;

                    if HasCarrierQuantityChoice and
                       (ChosenCarrierQuantity + QuantityTolerance() < RequiredCarrierQuantity)
                    then
                        Error(
                            CarrierQuantityChoiceBelowMinimumErr,
                            CurrentPNEPILTarget."Carrier Item No.",
                            ChosenCarrierQuantity,
                            RequiredCarrierQuantity);

                    SetCarrierTargetFilter(CarrierPNEPILTarget, CurrentPNEPILTarget);
                    CarrierPNEPILTarget.SetFilter(
                        Kind,
                        '%1|%2',
                        CarrierPNEPILTarget.Kind::"Structural driver",
                        CarrierPNEPILTarget.Kind::"CALC replacement");
                    if CarrierPNEPILTarget.FindSet(true) then
                        repeat
                            CarrierPNEPILTarget."Carrier Quantity Conflict" := false;
                            if HasCarrierQuantityChoice then
                                CarrierPNEPILTarget."New Carrier Quantity" := ChosenCarrierQuantity
                            else begin
                                CarrierPNEPILTarget."New Carrier Quantity" := RequiredCarrierQuantity;
                                ClearCarrierQuantityChoiceFields(CarrierPNEPILTarget);
                            end;
                            CarrierPNEPILTarget.Modify(true);
                        until CarrierPNEPILTarget.Next() = 0;
                end;
            until CurrentPNEPILTarget.Next() = 0;
    end;

    local procedure ClearCarrierQuantityChoiceFields(var PNEPILTarget: Record "PNE PIL Target")
    begin
        Clear(PNEPILTarget."Carrier Qty. Choice Active");
        Clear(PNEPILTarget."Chosen Carrier Quantity");
        Clear(PNEPILTarget."Carrier Qty. Choice Reason");
        Clear(PNEPILTarget."Carrier Qty. Chosen By");
        Clear(PNEPILTarget."Carrier Qty. Chosen At");
    end;

    local procedure HasEarlierQuantityTargetForCarrier(PNEPILTarget: Record "PNE PIL Target"): Boolean
    var
        EarlierPNEPILTarget: Record "PNE PIL Target";
    begin
        SetCarrierTargetFilter(EarlierPNEPILTarget, PNEPILTarget);
        EarlierPNEPILTarget.SetFilter(
            Kind,
            '%1|%2',
            EarlierPNEPILTarget.Kind::"Structural driver",
            EarlierPNEPILTarget.Kind::"CALC replacement");
        EarlierPNEPILTarget.SetFilter("Line No.", '<%1', PNEPILTarget."Line No.");
        exit(not EarlierPNEPILTarget.IsEmpty());
    end;

    local procedure HasUnresolvedCarrierQuantityConflict(PNEPILHeader: Record "PNE PIL Header"): Boolean
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("Carrier Quantity Conflict", true);
        PNEPILTarget.SetRange("Carrier Qty. Choice Active", false);
        exit(not PNEPILTarget.IsEmpty());
    end;

    local procedure UpdateCarrierConflictResolutions(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("Carrier Quantity Conflict", true);
        if PNEPILTarget.FindSet(true) then
            repeat
                if PNEPILTarget."Carrier Qty. Choice Active" then
                    PNEPILTarget.Resolution := CopyStr(
                        StrSubstNo(
                            CarrierQuantityChoiceAppliedTxt,
                            PNEPILTarget."Chosen Carrier Quantity"),
                        1,
                        MaxStrLen(PNEPILTarget.Resolution))
                else
                    PNEPILTarget.Resolution := CarrierQuantityChoiceRequiredTxt;
                PNEPILTarget.Modify(true);
            until PNEPILTarget.Next() = 0;
    end;

    local procedure UpdateTargetAllocationStatus(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILLine: Record "PNE PIL Line";
        PNEPILTarget: Record "PNE PIL Target";
        AllocatedQuantity: Decimal;
        RequiredQuantity: Decimal;
        UnallocatedQuantity: Decimal;
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet() then
            repeat
                RequiredQuantity := GetRequiredAllocation(PNEPILHeader, PNEPILLine);
                AllocatedQuantity := GetAllocatedQuantity(PNEPILHeader, PNEPILLine);
                UnallocatedQuantity := RequiredQuantity - AllocatedQuantity;
                if Abs(UnallocatedQuantity) <= QuantityTolerance() then
                    UnallocatedQuantity := 0;
                PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
                PNEPILTarget.SetRange("PIL Line No.", PNEPILLine."Line No.");
                if PNEPILTarget.FindSet(true) then
                    repeat
                        PNEPILTarget."Unallocated PIL Quantity" := UnallocatedQuantity;
                        if Abs(UnallocatedQuantity) <= QuantityTolerance() then
                            if HasMultipleTargetsForPILLine(PNEPILHeader, PNEPILLine) then
                                PNEPILTarget.Resolution := ManualAllocationTxt
                            else
                                PNEPILTarget.Resolution := AutomaticResolutionTxt
                        else
                            PNEPILTarget.Resolution := ManualAllocationTxt;
                        PNEPILTarget.Modify(true);
                    until PNEPILTarget.Next() = 0;
            until PNEPILLine.Next() = 0;
    end;

    local procedure AllAllocationsComplete(PNEPILHeader: Record "PNE PIL Header"): Boolean
    var
        PNEPILLine: Record "PNE PIL Line";
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet() then
            repeat
                if Abs(GetRequiredAllocation(PNEPILHeader, PNEPILLine) - GetAllocatedQuantity(PNEPILHeader, PNEPILLine)) > QuantityTolerance() then
                    exit(false);
            until PNEPILLine.Next() = 0;
        exit(true);
    end;

    local procedure GetRequiredAllocation(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"): Decimal
    var
        RemainingQuantity: Decimal;
    begin
        if PNEPILLine."Ignore for Reconciliation" then
            exit(0);
        RemainingQuantity := PNEPILLine.Quantity - PNEPILLine."Covered Quantity";
        if RemainingQuantity < QuantityTolerance() then
            RemainingQuantity := 0;
        if HasStructuralTarget(PNEPILHeader, PNEPILLine."Line No.") or
           HasDirectComponentTarget(PNEPILHeader, PNEPILLine."Line No.") or
           HasPointCarrierAdditionTarget(PNEPILHeader, PNEPILLine."Line No.")
        then
            exit(RemainingQuantity);
        if PNEPILLine.Resolution in [
            ExistingOrderQuantityRetainedTxt,
            InformationalGroupHeaderTxt,
            CoveredByDriverTxt]
        then
            exit(0);
        if PNEPILLine."Group Code" <> '' then
            exit(RemainingQuantity);
        exit(PNEPILLine.Quantity);
    end;

    local procedure GetAllocatedQuantity(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"): Decimal
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", PNEPILLine."Line No.");
        if HasStructuralTarget(PNEPILHeader, PNEPILLine."Line No.") then
            PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Structural driver")
        else
            if HasDirectComponentTarget(PNEPILHeader, PNEPILLine."Line No.") then
                PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Direct component addition")
            else
                if HasPointCarrierAdditionTarget(PNEPILHeader, PNEPILLine."Line No.") then
                    PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Point carrier addition")
        else
            PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"CALC replacement");
        PNEPILTarget.CalcSums("Allocated PIL Quantity");
        exit(PNEPILTarget."Allocated PIL Quantity");
    end;

    local procedure CheckCarrierQuantityConsistency(PNEPILHeader: Record "PNE PIL Header")
    var
        CurrentPNEPILTarget: Record "PNE PIL Target";
        CarrierPNEPILTarget: Record "PNE PIL Target";
        ExpectedCarrierQuantity: Decimal;
    begin
        CurrentPNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CurrentPNEPILTarget.SetRange("Carrier Quantity Conflict", true);
        CurrentPNEPILTarget.SetRange("Carrier Qty. Choice Active", false);
        if CurrentPNEPILTarget.FindFirst() then
            Error(UnresolvedCarrierQuantityConflictErr, CurrentPNEPILTarget."Carrier Item No.");

        CurrentPNEPILTarget.Reset();
        CurrentPNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CurrentPNEPILTarget.SetFilter(Kind, '%1|%2', CurrentPNEPILTarget.Kind::"Structural driver", CurrentPNEPILTarget.Kind::"CALC replacement");
        if CurrentPNEPILTarget.FindSet() then
            repeat
                if not HasEarlierQuantityTargetForCarrier(CurrentPNEPILTarget) then begin
                    CarrierPNEPILTarget.Copy(CurrentPNEPILTarget);
                    SetCarrierTargetFilter(CarrierPNEPILTarget, CurrentPNEPILTarget);
                    if CarrierPNEPILTarget.FindSet() then begin
                        ExpectedCarrierQuantity := CarrierPNEPILTarget."New Carrier Quantity";
                        repeat
                            if Abs(CarrierPNEPILTarget."New Carrier Quantity" - ExpectedCarrierQuantity) > QuantityTolerance() then
                                Error(ConflictingDriversErr, CurrentPNEPILTarget."Carrier Item No.");
                        until CarrierPNEPILTarget.Next() = 0;
                    end;
                end;
            until CurrentPNEPILTarget.Next() = 0;
        CheckPointCarrierAdditionConsistency(PNEPILHeader);
    end;

    local procedure CheckPointCarrierAdditionConsistency(PNEPILHeader: Record "PNE PIL Header")
    var
        CurrentPNEPILTarget: Record "PNE PIL Target";
        PointCarrierPNEPILTarget: Record "PNE PIL Target";
        ExpectedCarrierQuantity: Decimal;
    begin
        CurrentPNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        CurrentPNEPILTarget.SetRange(Kind, CurrentPNEPILTarget.Kind::"Point carrier addition");
        if CurrentPNEPILTarget.FindSet() then
            repeat
                if not HasEarlierTargetForCarrier(CurrentPNEPILTarget) then begin
                    SetPointCarrierAdditionFilter(PointCarrierPNEPILTarget, CurrentPNEPILTarget);
                    if PointCarrierPNEPILTarget.FindSet() then begin
                        ExpectedCarrierQuantity := PointCarrierPNEPILTarget."New Carrier Quantity";
                        repeat
                            if Abs(PointCarrierPNEPILTarget."New Carrier Quantity" - ExpectedCarrierQuantity) > QuantityTolerance() then
                                Error(ConflictingDriversErr, CurrentPNEPILTarget."New Point Carrier Item No.");
                        until PointCarrierPNEPILTarget.Next() = 0;
                    end;
                end;
            until CurrentPNEPILTarget.Next() = 0;
    end;

    local procedure UpdateLineResolutions(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILLine: Record "PNE PIL Line";
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet(true) then
            repeat
                if PNEPILLine."Ignore for Reconciliation" then
                    PNEPILLine.Resolution := IgnoredByUserTxt
                else
                    if PNEPILLine.Quantity <= QuantityTolerance() then
                        PNEPILLine.Resolution := ZeroQuantityTxt
                    else
                        if HasDirectComponentTarget(PNEPILHeader, PNEPILLine."Line No.") then
                            PNEPILLine.Resolution := DirectComponentAdditionTxt
                        else
                            if HasPointCarrierAdditionTarget(PNEPILHeader, PNEPILLine."Line No.") then
                                PNEPILLine.Resolution := PointCarrierAdditionTxt
                            else
                                if HasStructuralTarget(PNEPILHeader, PNEPILLine."Line No.") then
                                    PNEPILLine.Resolution := StructuralDriverTxt
                                else
                                    if IsInformationalGroupHeaderPILItem(PNEPILLine."Item No.") then
                                        PNEPILLine.Resolution := InformationalGroupHeaderTxt
                                    else
                                        if PNEPILLine."Covered Quantity" >= PNEPILLine.Quantity - QuantityTolerance() then
                                            PNEPILLine.Resolution := CoveredByDriverTxt
                                        else
                                            if PNEPILLine."Covered Quantity" > QuantityTolerance() then
                                                PNEPILLine.Resolution := PartiallyCoveredTxt
                                            else
                                                if IsNonPiecesPILItemAlreadyOnProductionOrder(
                                                     PNEPILHeader,
                                                     PNEPILLine."Item No.")
                                                then
                                                    PNEPILLine.Resolution := ExistingOrderQuantityRetainedTxt
                                                else
                                                    if PNEPILLine."Group Code" <> '' then
                                                        PNEPILLine.Resolution := CALCReplacementTxt
                                                    else
                                                        PNEPILLine.Resolution := NotUsedTxt;
                PNEPILLine.Modify(true);
            until PNEPILLine.Next() = 0;
    end;

    local procedure EnsureNoBlockingPositivePILLines(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILLine: Record "PNE PIL Line";
    begin
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILLine.FindSet() then
            repeat
                if PNEPILLine."Ignore for Reconciliation" and
                   ((DelChr(PNEPILLine."Ignore Reason", '<>', ' ') = '') or
                    (PNEPILLine."Ignored By" = '') or
                    (PNEPILLine."Ignored At" = 0DT))
                then
                    Error(IncompleteIgnoreAuditErr, PNEPILLine."Item No.");
            until PNEPILLine.Next() = 0;
    end;

    local procedure IsBlockingPositivePILLine(PNEPILLine: Record "PNE PIL Line"): Boolean
    begin
        if PNEPILLine.Quantity <= QuantityTolerance() then
            exit(false);
        if PNEPILLine."Ignore for Reconciliation" then
            exit(
                (DelChr(PNEPILLine."Ignore Reason", '<>', ' ') = '') or
                (PNEPILLine."Ignored By" = '') or
                (PNEPILLine."Ignored At" = 0DT));
        exit(not (PNEPILLine.Resolution in [
            StructuralDriverTxt,
            CoveredByDriverTxt,
            CALCReplacementTxt,
            ExistingOrderQuantityRetainedTxt,
            InformationalGroupHeaderTxt,
            DirectComponentAdditionTxt,
            PointCarrierAdditionTxt]));
    end;

    local procedure BuildChangeLines(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILChangeLine.DeleteAll(true);

        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILTarget.FindSet() then
            repeat
                if ShouldCreateChangeLine(PNEPILTarget) then begin
                    PNEPILChangeLine.Init();
                    PNEPILChangeLine."Header Entry No." := PNEPILHeader."Entry No.";
                    PNEPILChangeLine."Line No." := GetNextChangeLineNo(PNEPILHeader);
                    PopulateChangeLine(PNEPILChangeLine, PNEPILTarget);
                    PNEPILChangeLine.Insert(true);
                end;
            until PNEPILTarget.Next() = 0;
    end;

    local procedure ShouldCreateChangeLine(PNEPILTarget: Record "PNE PIL Target"): Boolean
    var
        CarrierPNEPILTarget: Record "PNE PIL Target";
    begin
        if PNEPILTarget.Kind = PNEPILTarget.Kind::"Direct component addition" then
            exit(TargetChangesProductionOrder(PNEPILTarget));
        if PNEPILTarget.Kind = PNEPILTarget.Kind::"Point carrier addition" then begin
            if HasEarlierTargetForCarrier(PNEPILTarget) then
                exit(false);
            exit(TargetChangesProductionOrder(PNEPILTarget));
        end;
        if HasEarlierQuantityTargetForCarrier(PNEPILTarget) then
            exit(false);

        SetCarrierTargetFilter(CarrierPNEPILTarget, PNEPILTarget);
        CarrierPNEPILTarget.SetFilter(
            Kind,
            '%1|%2',
            CarrierPNEPILTarget.Kind::"Structural driver",
            CarrierPNEPILTarget.Kind::"CALC replacement");
        if CarrierPNEPILTarget.FindSet() then
            repeat
                if TargetChangesProductionOrder(CarrierPNEPILTarget) then
                    exit(true);
            until CarrierPNEPILTarget.Next() = 0;
        exit(false);
    end;

    local procedure PopulateChangeLine(var PNEPILChangeLine: Record "PNE PIL Change Line"; PNEPILTarget: Record "PNE PIL Target")
    var
        CarrierProdOrderComponent: Record "Prod. Order Component";
        CarrierProdOrderLine: Record "Prod. Order Line";
        PointCarrierItem: Record Item;
    begin
        PNEPILChangeLine."Carrier Type" := PNEPILTarget."Carrier Type";
        PNEPILChangeLine."Carrier Status" := PNEPILTarget."Carrier Status";
        PNEPILChangeLine."Carrier Production Order No." := PNEPILTarget."Carrier Production Order No.";
        PNEPILChangeLine."Carrier Order Line No." := PNEPILTarget."Carrier Order Line No.";
        PNEPILChangeLine."Carrier Component Line No." := PNEPILTarget."Carrier Component Line No.";
        PNEPILChangeLine."Target Line No." := PNEPILTarget."Line No.";

        case PNEPILTarget.Kind of
            PNEPILTarget.Kind::"Direct component addition":
                begin
                    PointCarrierItem.Get(PNEPILTarget."PIL Item No.");
                    PNEPILChangeLine."Carrier Item No." := PointCarrierItem."No.";
                    PNEPILChangeLine."Carrier Description" := PointCarrierItem.Description;
                    PNEPILChangeLine."Unit of Measure Code" := PointCarrierItem."Base Unit of Measure";
                    PNEPILChangeLine."Carrier Unit Cost" := PointCarrierItem."Unit Cost";
                end;
            PNEPILTarget.Kind::"Point carrier addition":
                begin
                    PointCarrierItem.Get(PNEPILTarget."New Point Carrier Item No.");
                    PNEPILChangeLine."Carrier Item No." := PointCarrierItem."No.";
                    PNEPILChangeLine."Carrier Description" := PointCarrierItem.Description;
                    PNEPILChangeLine."Unit of Measure Code" := PointCarrierItem."Base Unit of Measure";
                    PNEPILChangeLine."Carrier Unit Cost" := PointCarrierItem."Unit Cost";
                end;
            else
                case PNEPILTarget."Carrier Type" of
            PNEPILTarget."Carrier Type"::"Production Order Line":
                begin
                    CarrierProdOrderLine.Get(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.");
                    PNEPILChangeLine."Carrier Item No." := CarrierProdOrderLine."Item No.";
                    PNEPILChangeLine."Carrier Variant Code" := CarrierProdOrderLine."Variant Code";
                    PNEPILChangeLine."Carrier Description" := CarrierProdOrderLine.Description;
                    PNEPILChangeLine."Unit of Measure Code" := CarrierProdOrderLine."Unit of Measure Code";
                    PNEPILChangeLine."Carrier Unit Cost" := CarrierProdOrderLine."Unit Cost";
                end;
            PNEPILTarget."Carrier Type"::"Production Order Component":
                begin
                    CarrierProdOrderComponent.Get(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.",
                        PNEPILTarget."Carrier Component Line No.");
                    PNEPILChangeLine."Carrier Item No." := CarrierProdOrderComponent."Item No.";
                    PNEPILChangeLine."Carrier Variant Code" := CarrierProdOrderComponent."Variant Code";
                    PNEPILChangeLine."Carrier Description" := CarrierProdOrderComponent.Description;
                    PNEPILChangeLine."Unit of Measure Code" := CarrierProdOrderComponent."Unit of Measure Code";
                    PNEPILChangeLine."Carrier Unit Cost" := CarrierProdOrderComponent."Unit Cost";
                end;
                end;
        end;

        if PNEPILTarget.Kind = PNEPILTarget.Kind::"Direct component addition" then begin
            PNEPILChangeLine."Original Quantity" := PNEPILTarget."Existing Actual PIL Quantity";
            PNEPILChangeLine."Proposed Quantity" :=
                PNEPILTarget."Existing Actual PIL Quantity" +
                PNEPILTarget."Allocated PIL Quantity";
        end else begin
            PNEPILChangeLine."Original Quantity" := PNEPILTarget."Original Carrier Quantity";
            PNEPILChangeLine."Proposed Quantity" := PNEPILTarget."New Carrier Quantity";
        end;
        PNEPILChangeLine."Quantity Difference" := PNEPILChangeLine."Proposed Quantity" - PNEPILChangeLine."Original Quantity";
        PNEPILChangeLine."Estimated Cost Difference" := PNEPILChangeLine."Quantity Difference" * PNEPILChangeLine."Carrier Unit Cost";
        PNEPILChangeLine."PIL Details" := GetCarrierPILDetails(PNEPILTarget);
    end;

    local procedure GetCarrierPILDetails(PNEPILTarget: Record "PNE PIL Target"): Text[250]
    var
        CarrierPNEPILTarget: Record "PNE PIL Target";
        PILDetails: Text[250];
    begin
        if PNEPILTarget.Kind = PNEPILTarget.Kind::"Direct component addition" then begin
            AppendPILDetail(PILDetails, PNEPILTarget."PIL Item No.");
            exit(PILDetails);
        end;
        if PNEPILTarget.Kind = PNEPILTarget.Kind::"Point carrier addition" then begin
            SetPointCarrierAdditionFilter(CarrierPNEPILTarget, PNEPILTarget);
            if CarrierPNEPILTarget.FindSet() then
                repeat
                    AppendPILDetail(PILDetails, CarrierPNEPILTarget."PIL Item No.");
                until CarrierPNEPILTarget.Next() = 0;
            exit(PILDetails);
        end;
        SetCarrierTargetFilter(CarrierPNEPILTarget, PNEPILTarget);
        if CarrierPNEPILTarget.FindSet() then
            repeat
                AppendPILCalculationDetail(PILDetails, CarrierPNEPILTarget);
            until CarrierPNEPILTarget.Next() = 0;
        exit(PILDetails);
    end;

    local procedure AppendPILCalculationDetail(var PILDetails: Text[250]; PNEPILTarget: Record "PNE PIL Target")
    var
        PNEPILLine: Record "PNE PIL Line";
        AdditionalCarrierQuantity: Decimal;
        CalculationText: Text;
    begin
        if PNEPILTarget."PIL Item No." = '' then
            exit;
        if PNEPILTarget.Kind in [
             PNEPILTarget.Kind::"Structural driver",
             PNEPILTarget.Kind::"CALC replacement"]
        then begin
            if (PNEPILTarget.Kind = PNEPILTarget.Kind::"Structural driver") and
               PNEPILLine.Get(PNEPILTarget."Header Entry No.", PNEPILTarget."PIL Line No.") and
               (PNEPILLine."Covered Quantity" > QuantityTolerance())
            then begin
                AdditionalCarrierQuantity := Round(
                    PNEPILTarget."Allocated PIL Quantity" / PNEPILTarget."Quantity per Carrier",
                    1,
                    '>');
                CalculationText := StrSubstNo(
                    ResidualPILCalculationDetailTxt,
                    PNEPILTarget."PIL Item No.",
                    PNEPILTarget."Allocated PIL Quantity",
                    PNEPILTarget."Quantity per Carrier",
                    AdditionalCarrierQuantity,
                    PNEPILTarget."Driver Suggested Quantity");
            end else
                CalculationText := StrSubstNo(
                    PILCalculationDetailTxt,
                    PNEPILTarget."PIL Item No.",
                    PNEPILTarget."Allocated PIL Quantity",
                    PNEPILTarget."Quantity per Carrier",
                    PNEPILTarget."Driver Suggested Quantity");
        end
        else
            CalculationText := PNEPILTarget."PIL Item No.";
        AppendPILDetailText(PILDetails, CalculationText);
    end;

    local procedure AppendPILDetail(var PILDetails: Text[250]; PILItemNo: Code[20])
    begin
        AppendPILDetailText(PILDetails, PILItemNo);
    end;

    local procedure AppendPILDetailText(var PILDetails: Text[250]; DetailText: Text)
    var
        Separator: Text[2];
        TruncatedSuffix: Text[30];
    begin
        if DetailText = '' then
            exit;
        if PILDetails <> '' then
            Separator := ', ';
        TruncatedSuffix := PILDetailsTruncatedTxt;
        if StrPos(PILDetails, TruncatedSuffix) > 0 then
            exit;
        if StrLen(PILDetails) + StrLen(Separator) + StrLen(DetailText) > MaxStrLen(PILDetails) then begin
            PILDetails := CopyStr(PILDetails, 1, MaxStrLen(PILDetails) - StrLen(TruncatedSuffix)) + TruncatedSuffix;
            exit;
        end;
        PILDetails += Separator + DetailText;
    end;

    local procedure GetNextChangeLineNo(PNEPILHeader: Record "PNE PIL Header"): Integer
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
    begin
        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILChangeLine.FindLast() then
            exit(PNEPILChangeLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure AssertProposalNotTransferred(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
    begin
        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILChangeLine.SetFilter("Sales Quote No.", '<>%1', '');
        PNEPILChangeLine.SetRange("Quote Reversed", false);
        if not PNEPILChangeLine.IsEmpty() then
            Error(ProposalTransferredErr, PNEPILHeader."Entry No.");
    end;

    local procedure CheckQuotedProposalStillMatchesTargets(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILChangeLine: Record "PNE PIL Change Line";
        PNEPILTarget: Record "PNE PIL Target";
        PNEPILSalesQuoteMgt: Codeunit "PNE PIL Sales Quote Mgt.";
        ActiveQuoteLineKeys: Dictionary of [Text, Boolean];
        ActiveQuoteLineKey: Text;
        QuotableNetChangeCount: Integer;
    begin
        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILChangeLine.SetFilter("Sales Quote No.", '<>%1', '');
        PNEPILChangeLine.SetRange("Quote Reversed", false);
        if PNEPILChangeLine.IsEmpty() then
            exit;

        PNEPILChangeLine.Reset();
        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILChangeLine.SetFilter("Sales Quote No.", '<>%1', '');
        PNEPILChangeLine.SetRange("Quote Reversed", false);
        if PNEPILChangeLine.FindSet() then
            repeat
                ActiveQuoteLineKey :=
                    PNEPILChangeLine."Sales Quote No." + '|' +
                    Format(PNEPILChangeLine."Sales Quote Line No.");
                if not ActiveQuoteLineKeys.ContainsKey(ActiveQuoteLineKey) then
                    ActiveQuoteLineKeys.Add(ActiveQuoteLineKey, true);
                if not PNEPILTarget.Get(PNEPILHeader."Entry No.", PNEPILChangeLine."Target Line No.") then
                    Error(QuotedProposalChangedErr, PNEPILChangeLine."Carrier Item No.");
                if not TargetMatchesQuotedChangeLine(PNEPILTarget, PNEPILChangeLine) then
                    Error(QuotedProposalChangedErr, PNEPILChangeLine."Carrier Item No.");
            until PNEPILChangeLine.Next() = 0;

        PNEPILChangeLine.Reset();
        PNEPILChangeLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILChangeLine.FindSet() then
            repeat
                if (Abs(PNEPILChangeLine."Quantity Difference") > QuantityTolerance()) and
                   not PNEPILSalesQuoteMgt.IsDirectComponentChangeLine(PNEPILChangeLine) and
                   (Abs(PNEPILSalesQuoteMgt.GetCommercialGroupNetQuantity(PNEPILChangeLine)) > QuantityTolerance()) and
                   ((PNEPILChangeLine."Sales Quote No." = '') or PNEPILChangeLine."Quote Reversed")
                then
                    Error(QuotedProposalChangedErr, PNEPILChangeLine."Carrier Item No.");
            until PNEPILChangeLine.Next() = 0;

        QuotableNetChangeCount :=
            PNEPILSalesQuoteMgt.GetQuotableNetChangeCount(PNEPILHeader);
        if QuotableNetChangeCount <> ActiveQuoteLineKeys.Count() then
            Error(QuotedProposalChangedErr, PNEPILHeader."Production Order No.");
    end;

    local procedure TargetMatchesQuotedChangeLine(PNEPILTarget: Record "PNE PIL Target"; PNEPILChangeLine: Record "PNE PIL Change Line"): Boolean
    var
        ExpectedOriginalQuantity: Decimal;
        ExpectedProposedQuantity: Decimal;
    begin
        if PNEPILTarget.Kind = PNEPILTarget.Kind::"Direct component addition" then begin
            ExpectedOriginalQuantity := PNEPILTarget."Existing Actual PIL Quantity";
            ExpectedProposedQuantity :=
                PNEPILTarget."Existing Actual PIL Quantity" +
                PNEPILTarget."Allocated PIL Quantity";
        end else begin
            ExpectedOriginalQuantity := PNEPILTarget."Original Carrier Quantity";
            ExpectedProposedQuantity := PNEPILTarget."New Carrier Quantity";
        end;
        exit(
            (Abs(ExpectedOriginalQuantity - PNEPILChangeLine."Original Quantity") <= QuantityTolerance()) and
            (Abs(ExpectedProposedQuantity - PNEPILChangeLine."Proposed Quantity") <= QuantityTolerance()));
    end;

    local procedure CheckApplySafety(PNEPILHeader: Record "PNE PIL Header")
    var
        CarrierProdOrderComponent: Record "Prod. Order Component";
        CarrierProdOrderLine: Record "Prod. Order Line";
        PNEPILTarget: Record "PNE PIL Target";
        TempAncestorExpandedProdOrderLine: Record "Prod. Order Line" temporary;
        TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary;
        TempCheckedProdOrderLine: Record "Prod. Order Line" temporary;
        TempTreeExpandedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILTarget.FindSet() then
            repeat
                if not HasEarlierTargetForCarrier(PNEPILTarget) then
                    CheckTargetCarrierUnchanged(PNEPILTarget);
                if PNEPILTarget.Kind = PNEPILTarget.Kind::"Structural driver" then
                    CheckStructuralTargetUnchanged(PNEPILTarget);
                if PNEPILTarget.Kind = PNEPILTarget.Kind::"CALC replacement" then
                    CheckCALCSourceUnchanged(PNEPILTarget);
                if PNEPILTarget.Kind = PNEPILTarget.Kind::"Point carrier addition" then
                    CheckPointCarrierAdditionUnchanged(PNEPILTarget);
                if PNEPILTarget.Kind = PNEPILTarget.Kind::"Direct component addition" then
                    CheckDirectComponentUnchanged(PNEPILTarget, TempCheckedProdOrderComponent);
                if not HasEarlierTargetForCarrier(PNEPILTarget) then
                    case PNEPILTarget."Carrier Type" of
                        PNEPILTarget."Carrier Type"::"Production Order Line":
                            begin
                                CarrierProdOrderLine.Get(
                                    PNEPILTarget."Carrier Status",
                                    PNEPILTarget."Carrier Production Order No.",
                                    PNEPILTarget."Carrier Order Line No.");
                                if PNEPILTarget.Kind = PNEPILTarget.Kind::"Point carrier addition" then
                                    CheckPointCarrierDestinationSafety(
                                        CarrierProdOrderLine,
                                        TempCheckedProdOrderLine,
                                        TempCheckedProdOrderComponent,
                                        TempAncestorExpandedProdOrderLine)
                                else
                                    CheckCarrierSafety(
                                        CarrierProdOrderLine,
                                        PNEPILTarget,
                                        TempCheckedProdOrderLine,
                                        TempCheckedProdOrderComponent,
                                        TempAncestorExpandedProdOrderLine,
                                        TempTreeExpandedProdOrderLine);
                            end;
                        PNEPILTarget."Carrier Type"::"Production Order Component":
                            begin
                                CarrierProdOrderComponent.Get(
                                    PNEPILTarget."Carrier Status",
                                    PNEPILTarget."Carrier Production Order No.",
                                    PNEPILTarget."Carrier Order Line No.",
                                    PNEPILTarget."Carrier Component Line No.");
                                CheckComponentCarrierSafety(
                                    CarrierProdOrderComponent,
                                    PNEPILTarget,
                                    TempCheckedProdOrderLine,
                                    TempCheckedProdOrderComponent,
                                    TempAncestorExpandedProdOrderLine);
                            end;
                    end;
            until PNEPILTarget.Next() = 0;
        EnsureNoExistingActualPILComponentsForCALCTargetsOnce(PNEPILHeader, TempCheckedProdOrderComponent);
    end;

    local procedure CheckDirectComponentUnchanged(PNEPILTarget: Record "PNE PIL Target"; var TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary)
    var
        ExistingProdOrderComponent: Record "Prod. Order Component";
    begin
        ExistingProdOrderComponent.SetRange(Status, PNEPILTarget."Carrier Status");
        ExistingProdOrderComponent.SetRange("Prod. Order No.", PNEPILTarget."Carrier Production Order No.");
        ExistingProdOrderComponent.SetRange("Prod. Order Line No.", PNEPILTarget."Carrier Order Line No.");
        ExistingProdOrderComponent.SetRange("Item No.", PNEPILTarget."PIL Item No.");

        if IsNullGuid(PNEPILTarget."Existing Direct Comp. SystemId") then begin
            if not ExistingProdOrderComponent.IsEmpty() then
                Error(DirectComponentChangedSincePrepareErr, PNEPILTarget."PIL Item No.");
            exit;
        end;

        if not ExistingProdOrderComponent.Get(
             PNEPILTarget."Carrier Status",
             PNEPILTarget."Carrier Production Order No.",
             PNEPILTarget."Carrier Order Line No.",
             PNEPILTarget."Existing Direct Comp. Line No.")
        then
            Error(DirectComponentChangedSincePrepareErr, PNEPILTarget."PIL Item No.");
        if (ExistingProdOrderComponent.SystemId <> PNEPILTarget."Existing Direct Comp. SystemId") or
           (ExistingProdOrderComponent."Item No." <> PNEPILTarget."PIL Item No.") or
           (Abs(
              ExistingProdOrderComponent."Expected Quantity" -
              PNEPILTarget."Existing Actual PIL Quantity") > QuantityTolerance())
        then
            Error(DirectComponentChangedSincePrepareErr, PNEPILTarget."PIL Item No.");
        CheckProductionOrderComponentUnitOfMeasure(ExistingProdOrderComponent);
        CheckComponentSafetyOnce(ExistingProdOrderComponent, TempCheckedProdOrderComponent);
    end;

    local procedure CheckPointCarrierAdditionUnchanged(PNEPILTarget: Record "PNE PIL Target")
    var
        PointCarrierItem: Record Item;
        ExistingProdOrderComponent: Record "Prod. Order Component";
        DestinationProdOrderLine: Record "Prod. Order Line";
    begin
        PointCarrierItem.Get(PNEPILTarget."New Point Carrier Item No.");
        if (PointCarrierItem.SystemId <> PNEPILTarget."New Point Carrier SystemId") or
           (PointCarrierItem."Production BOM No." <> PNEPILTarget."New Point Carrier BOM No.") or
           (PointCarrierItem."Base Unit of Measure" <> PiecesUnitOfMeasureLbl) or
           (PointCarrierItem."Replenishment System" <> PointCarrierItem."Replenishment System"::"Prod. Order")
        then
            Error(PointCarrierItemChangedErr, PointCarrierItem."No.");

        DestinationProdOrderLine.Get(
            PNEPILTarget."Carrier Status",
            PNEPILTarget."Carrier Production Order No.",
            PNEPILTarget."Carrier Order Line No.");
        if Abs(DestinationProdOrderLine.Quantity - PNEPILTarget."Destination Original Quantity") > QuantityTolerance() then
            Error(CarrierChangedSincePrepareErr, DestinationProdOrderLine."Item No.");
        ExistingProdOrderComponent.SetRange(Status, DestinationProdOrderLine.Status);
        ExistingProdOrderComponent.SetRange("Prod. Order No.", DestinationProdOrderLine."Prod. Order No.");
        ExistingProdOrderComponent.SetRange("Item No.", PointCarrierItem."No.");
        if not ExistingProdOrderComponent.IsEmpty() then
            Error(PointCarrierAlreadyAddedErr, PointCarrierItem."No.");
    end;

    local procedure CheckPointCarrierDestinationSafety(DestinationProdOrderLine: Record "Prod. Order Line"; var TempCheckedProdOrderLine: Record "Prod. Order Line" temporary; var TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary; var TempAncestorExpandedProdOrderLine: Record "Prod. Order Line" temporary)
    begin
        CheckProductionOrderLineSafetyOnce(DestinationProdOrderLine, TempCheckedProdOrderLine);
        if DestinationProdOrderLine.Quantity <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, DestinationProdOrderLine."Item No.");
        CheckProductionOrderLineAncestorSafety(
            DestinationProdOrderLine,
            TempCheckedProdOrderLine,
            TempCheckedProdOrderComponent,
            TempAncestorExpandedProdOrderLine);
    end;

    local procedure CheckTargetCarrierUnchanged(PNEPILTarget: Record "PNE PIL Target")
    var
        CarrierProdOrderComponent: Record "Prod. Order Component";
        CarrierProdOrderLine: Record "Prod. Order Line";
    begin
        case PNEPILTarget."Carrier Type" of
            PNEPILTarget."Carrier Type"::"Production Order Line":
                begin
                    CarrierProdOrderLine.Get(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.");
                    if (CarrierProdOrderLine.SystemId <> PNEPILTarget."Carrier SystemId") or
                       (CarrierProdOrderLine."Item No." <> PNEPILTarget."Carrier Item No.") or
                       (CarrierProdOrderLine."Variant Code" <> PNEPILTarget."Carrier Variant Code") or
                       (CarrierProdOrderLine."Unit of Measure Code" <> PNEPILTarget."Carrier Unit of Measure Code")
                    then
                        Error(CarrierIdentityChangedErr, PNEPILTarget."Carrier Item No.");
                    CheckProductionOrderLineUnitOfMeasure(CarrierProdOrderLine);
                end;
            PNEPILTarget."Carrier Type"::"Production Order Component":
                begin
                    CarrierProdOrderComponent.Get(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.",
                        PNEPILTarget."Carrier Component Line No.");
                    if (CarrierProdOrderComponent.SystemId <> PNEPILTarget."Carrier SystemId") or
                       (CarrierProdOrderComponent."Item No." <> PNEPILTarget."Carrier Item No.") or
                       (CarrierProdOrderComponent."Variant Code" <> PNEPILTarget."Carrier Variant Code") or
                       (CarrierProdOrderComponent."Unit of Measure Code" <> PNEPILTarget."Carrier Unit of Measure Code")
                    then
                        Error(CarrierIdentityChangedErr, PNEPILTarget."Carrier Item No.");
                    CheckProductionOrderComponentUnitOfMeasure(CarrierProdOrderComponent);
                end;
        end;
    end;

    local procedure CheckCALCSourceUnchanged(PNEPILTarget: Record "PNE PIL Target")
    var
        CarrierProdOrderLine: Record "Prod. Order Line";
        FoundCALCProdOrderComponent: Record "Prod. Order Component";
        SourceCALCProdOrderComponent: Record "Prod. Order Component";
        FoundCount: Integer;
    begin
        GetAndCheckCALCSourceIdentity(PNEPILTarget, SourceCALCProdOrderComponent);
        if (Abs(SourceCALCProdOrderComponent."Expected Quantity" - PNEPILTarget."Source CALC Expected Quantity") > QuantityTolerance()) or
           (Abs(SourceCALCProdOrderComponent."Quantity per" - PNEPILTarget."Source CALC Quantity per") > QuantityTolerance())
        then
            Error(CALCSourceChangedErr, PNEPILTarget."CALC Item No.", PNEPILTarget."Carrier Item No.");

        CarrierProdOrderLine.Get(
            PNEPILTarget."Carrier Status",
            PNEPILTarget."Carrier Production Order No.",
            PNEPILTarget."Carrier Order Line No.");
        FindComponentInCarrierTree(CarrierProdOrderLine, PNEPILTarget."CALC Item No.", FoundCALCProdOrderComponent, FoundCount);
        if (FoundCount <> 1) or (FoundCALCProdOrderComponent.SystemId <> PNEPILTarget."Source CALC SystemId") then
            Error(CALCSourceChangedErr, PNEPILTarget."CALC Item No.", PNEPILTarget."Carrier Item No.");
    end;

    local procedure GetAndCheckCALCSourceIdentity(PNEPILTarget: Record "PNE PIL Target"; var SourceCALCProdOrderComponent: Record "Prod. Order Component")
    begin
        SourceCALCProdOrderComponent.Get(
            PNEPILTarget."Source CALC Status",
            PNEPILTarget."CALC Source Prod. Order No.",
            PNEPILTarget."Source CALC Order Line No.",
            PNEPILTarget."Source CALC Component Line No.");
        if (SourceCALCProdOrderComponent.SystemId <> PNEPILTarget."Source CALC SystemId") or
           (SourceCALCProdOrderComponent."Item No." <> PNEPILTarget."Source CALC Item No.") or
           (SourceCALCProdOrderComponent."Item No." <> PNEPILTarget."CALC Item No.") or
           (SourceCALCProdOrderComponent."Variant Code" <> PNEPILTarget."Source CALC Variant Code") or
           (SourceCALCProdOrderComponent."Unit of Measure Code" <> PNEPILTarget."CALC Source UOM Code") or
           (Abs(SourceCALCProdOrderComponent."Qty. per Unit of Measure" - PNEPILTarget."Source CALC Qty. per UOM") > QuantityTolerance())
        then
            Error(CALCSourceChangedErr, PNEPILTarget."CALC Item No.", PNEPILTarget."Carrier Item No.");
        CheckProductionOrderComponentUnitOfMeasure(SourceCALCProdOrderComponent);
        if SourceCALCProdOrderComponent."Supplied-by Line No." <> 0 then
            Error(CALCSourceSuppliesOrderErr, PNEPILTarget."CALC Item No.");
    end;

    local procedure EnsureNoExistingActualPILComponentsForCALCTargets(PNEPILHeader: Record "PNE PIL Header")
    var
        TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary;
    begin
        EnsureNoExistingActualPILComponentsForCALCTargetsOnce(
            PNEPILHeader,
            TempCheckedProdOrderComponent);
    end;

    local procedure EnsureNoExistingActualPILComponentsForCALCTargetsOnce(PNEPILHeader: Record "PNE PIL Header"; var TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary)
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"CALC replacement");
        if PNEPILTarget.FindSet() then
            repeat
                if not HasEarlierCALCTargetForCarrierAndGroup(PNEPILTarget) then
                    EnsureNoExistingActualPILComponentsForCarrierAndGroup(
                        PNEPILTarget,
                        TempCheckedProdOrderComponent);
            until PNEPILTarget.Next() = 0;
    end;

    local procedure EnsureNoExistingActualPILComponentsForCarrierAndGroup(FirstPNEPILTarget: Record "PNE PIL Target"; var TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary)
    var
        CarrierProdOrderLine: Record "Prod. Order Line";
        FoundActualProdOrderComponent: Record "Prod. Order Component";
        PNEPILTarget: Record "PNE PIL Target";
        FoundCount: Integer;
    begin
        CarrierProdOrderLine.Get(
            FirstPNEPILTarget."Carrier Status",
            FirstPNEPILTarget."Carrier Production Order No.",
            FirstPNEPILTarget."Carrier Order Line No.");
        SetCALCTargetGroupFilter(PNEPILTarget, FirstPNEPILTarget);
        if PNEPILTarget.FindSet() then
            repeat
                if PNEPILTarget."Allocated PIL Quantity" > QuantityTolerance() then begin
                    FindComponentInCarrierTree(
                        CarrierProdOrderLine,
                        PNEPILTarget."PIL Item No.",
                        FoundActualProdOrderComponent,
                        FoundCount);
                    if FoundCount > 1 then
                        Error(
                            ActualPILComponentAlreadyExistsErr,
                            PNEPILTarget."PIL Item No.",
                            FirstPNEPILTarget."Carrier Item No.",
                            FoundCount);
                    if FoundCount = 1 then begin
                        CheckComponentSafetyOnce(FoundActualProdOrderComponent, TempCheckedProdOrderComponent);
                        if Abs(
                             FoundActualProdOrderComponent."Expected Quantity" -
                             PNEPILTarget."Existing Actual PIL Quantity") > QuantityTolerance()
                        then
                            Error(
                                ExistingActualPILComponentChangedErr,
                                PNEPILTarget."PIL Item No.",
                                FirstPNEPILTarget."Carrier Item No.");
                    end else
                        if PNEPILTarget."Existing Actual PIL Quantity" > QuantityTolerance() then
                            Error(
                                ExistingActualPILComponentChangedErr,
                                PNEPILTarget."PIL Item No.",
                                FirstPNEPILTarget."Carrier Item No.");
                end;
            until PNEPILTarget.Next() = 0;
    end;

    local procedure CheckStructuralTargetUnchanged(PNEPILTarget: Record "PNE PIL Target")
    var
        CurrentQuantityPerCarrier: Decimal;
    begin
        case PNEPILTarget."Analysis Source" of
            PNEPILTarget."Analysis Source"::"Live Production Order":
                CurrentQuantityPerCarrier := GetLiveStructuralQuantityPerCarrier(PNEPILTarget);
            PNEPILTarget."Analysis Source"::"Current Master BOM":
                CurrentQuantityPerCarrier := GetMasterStructuralQuantityPerCarrier(PNEPILTarget);
        end;
        if Abs(CurrentQuantityPerCarrier - PNEPILTarget."Quantity per Carrier") > QuantityTolerance() then
            Error(StructuralDriverChangedErr, PNEPILTarget."PIL Item No.", PNEPILTarget."Carrier Item No.");
    end;

    local procedure GetLiveStructuralQuantityPerCarrier(PNEPILTarget: Record "PNE PIL Target"): Decimal
    var
        CarrierProdOrderLine: Record "Prod. Order Line";
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
        QuantityPerCarrier: Decimal;
    begin
        if PNEPILTarget."Carrier Type" <> PNEPILTarget."Carrier Type"::"Production Order Line" then
            Error(StructuralDriverChangedErr, PNEPILTarget."PIL Item No.", PNEPILTarget."Carrier Item No.");
        CarrierProdOrderLine.Get(
            PNEPILTarget."Carrier Status",
            PNEPILTarget."Carrier Production Order No.",
            PNEPILTarget."Carrier Order Line No.");
        CheckProductionOrderLineUnitOfMeasure(CarrierProdOrderLine);
        if CarrierProdOrderLine.Quantity <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, CarrierProdOrderLine."Item No.");
        SumLiveStructuralQuantityPerCarrier(
            CarrierProdOrderLine,
            CarrierProdOrderLine,
            PNEPILTarget."PIL Item No.",
            QuantityPerCarrier,
            TempVisitedProdOrderLine);
        exit(QuantityPerCarrier);
    end;

    local procedure SumLiveStructuralQuantityPerCarrier(CarrierProdOrderLine: Record "Prod. Order Line"; CurrentProdOrderLine: Record "Prod. Order Line"; PILItemNo: Code[20]; var QuantityPerCarrier: Decimal; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
        TempRelevantChildProdOrderLine: Record "Prod. Order Line" temporary;
        HasChildProdOrderLine: Boolean;
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                HasChildProdOrderLine := FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine);
                if ProdOrderComponent."Item No." = PILItemNo then begin
                    CheckProductionOrderComponentUnitOfMeasure(ProdOrderComponent);
                    if HasChildProdOrderLine then
                        CheckLinkedProductionOrderUnitOfMeasure(ProdOrderComponent, ChildProdOrderLine);
                    QuantityPerCarrier += ProdOrderComponent."Expected Quantity" / CarrierProdOrderLine.Quantity;
                end else
                    if HasChildProdOrderLine then begin
                        TempRelevantChildProdOrderLine.DeleteAll();
                        if HasStructuralItemInLine(PILItemNo, ChildProdOrderLine, TempRelevantChildProdOrderLine) then begin
                            CheckLinkedProductionOrderUnitOfMeasure(ProdOrderComponent, ChildProdOrderLine);
                            SumLiveStructuralQuantityPerCarrier(
                                CarrierProdOrderLine,
                                ChildProdOrderLine,
                                PILItemNo,
                                QuantityPerCarrier,
                                TempVisitedProdOrderLine);
                        end;
                    end;
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure HasStructuralItemInLine(PILItemNo: Code[20]; CurrentProdOrderLine: Record "Prod. Order Line"; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary): Boolean
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit(false);

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if ProdOrderComponent."Item No." = PILItemNo then
                    exit(true);
                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                    if HasStructuralItemInLine(PILItemNo, ChildProdOrderLine, TempVisitedProdOrderLine) then
                        exit(true);
            until ProdOrderComponent.Next() = 0;
        exit(false);
    end;

    local procedure GetMasterStructuralQuantityPerCarrier(PNEPILTarget: Record "PNE PIL Target"): Decimal
    var
        CarrierProdOrderComponent: Record "Prod. Order Component";
        CarrierProdOrderLine: Record "Prod. Order Line";
        BOMPath: List of [Code[20]];
        ProductionBOMNo: Code[20];
        QuantityPerCarrier: Decimal;
    begin
        case PNEPILTarget."Carrier Type" of
            PNEPILTarget."Carrier Type"::"Production Order Line":
                begin
                    CarrierProdOrderLine.Get(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.");
                    ProductionBOMNo := GetProductionBOMNoForLine(CarrierProdOrderLine);
                    CheckRootBOMUnitOfMeasure(
                        ProductionBOMNo,
                        CarrierProdOrderLine."Production BOM Version Code",
                        true,
                        GetCarrierCalculationDate(CarrierProdOrderLine),
                        CarrierProdOrderLine."Unit of Measure Code");
                    SumMasterStructuralQuantityPerCarrier(
                        ProductionBOMNo,
                        GetCarrierCalculationDate(CarrierProdOrderLine),
                        PNEPILTarget."PIL Item No.",
                        1,
                        CarrierProdOrderLine."Production BOM Version Code",
                        true,
                        QuantityPerCarrier,
                        BOMPath);
                end;
            PNEPILTarget."Carrier Type"::"Production Order Component":
                begin
                    CarrierProdOrderComponent.Get(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.",
                        PNEPILTarget."Carrier Component Line No.");
                    CarrierProdOrderLine.Get(
                        CarrierProdOrderComponent.Status,
                        CarrierProdOrderComponent."Prod. Order No.",
                        CarrierProdOrderComponent."Prod. Order Line No.");
                    ProductionBOMNo := GetProductionBOMNoForComponent(CarrierProdOrderComponent);
                    CheckRootBOMUnitOfMeasure(
                        ProductionBOMNo,
                        '',
                        false,
                        GetCarrierCalculationDate(CarrierProdOrderLine),
                        CarrierProdOrderComponent."Unit of Measure Code");
                    SumMasterStructuralQuantityPerCarrier(
                        ProductionBOMNo,
                        GetCarrierCalculationDate(CarrierProdOrderLine),
                        PNEPILTarget."PIL Item No.",
                        1,
                        '',
                        false,
                        QuantityPerCarrier,
                        BOMPath);
                end;
        end;
        exit(QuantityPerCarrier);
    end;

    local procedure SumMasterStructuralQuantityPerCarrier(ProductionBOMNo: Code[20]; CalculationDate: Date; PILItemNo: Code[20]; ParentQuantityPerCarrier: Decimal; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var QuantityPerCarrier: Decimal; var BOMPath: List of [Code[20]])
    var
        PhysicalItemBOMPath: List of [Code[20]];
        PhysicalItemNos: Dictionary of [Code[20], Boolean];
        SuppressedPhysicalItemNos: List of [Code[20]];
        VisitedProductionBOMNos: Dictionary of [Code[20], Boolean];
    begin
        CollectPhysicalItemNosInBOM(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            PhysicalItemNos,
            VisitedProductionBOMNos,
            PhysicalItemBOMPath);
        SumMasterStructuralQuantityPerCarrierInternal(
            ProductionBOMNo,
            CalculationDate,
            PILItemNo,
            ParentQuantityPerCarrier,
            RequestedVersionCode,
            UseRequestedVersion,
            PhysicalItemNos,
            SuppressedPhysicalItemNos,
            QuantityPerCarrier,
            BOMPath);
    end;

    local procedure BuildMasterStructuralQuantityMap(ProductionBOMNo: Code[20]; CalculationDate: Date; ParentQuantityPerCarrier: Decimal; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; EligiblePILItemNos: Dictionary of [Code[20], Boolean]; var QuantityPerPILItem: Dictionary of [Code[20], Decimal]; var BOMPath: List of [Code[20]])
    var
        PhysicalItemBOMPath: List of [Code[20]];
        PhysicalItemNos: Dictionary of [Code[20], Boolean];
        SuppressedMatchedPILItemNos: List of [Code[20]];
        SuppressedPhysicalItemNos: List of [Code[20]];
        VisitedProductionBOMNos: Dictionary of [Code[20], Boolean];
    begin
        CollectPhysicalItemNosInBOM(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            PhysicalItemNos,
            VisitedProductionBOMNos,
            PhysicalItemBOMPath);
        CollectMasterStructuralQuantitiesInternal(
            ProductionBOMNo,
            CalculationDate,
            ParentQuantityPerCarrier,
            RequestedVersionCode,
            UseRequestedVersion,
            EligiblePILItemNos,
            PhysicalItemNos,
            SuppressedPhysicalItemNos,
            SuppressedMatchedPILItemNos,
            QuantityPerPILItem,
            BOMPath);
    end;

    local procedure CollectMasterStructuralQuantitiesInternal(ProductionBOMNo: Code[20]; CalculationDate: Date; ParentQuantityPerCarrier: Decimal; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; EligiblePILItemNos: Dictionary of [Code[20], Boolean]; PhysicalItemNos: Dictionary of [Code[20], Boolean]; var SuppressedPhysicalItemNos: List of [Code[20]]; var SuppressedMatchedPILItemNos: List of [Code[20]]; var QuantityPerPILItem: Dictionary of [Code[20], Decimal]; var BOMPath: List of [Code[20]])
    var
        ProductionBOMLine: Record "Production BOM Line";
        ChildQuantityPerPILItem: Dictionary of [Code[20], Decimal];
        DirectPhysicalItemNos: Dictionary of [Code[20], Boolean];
        ProductionBOMHeadingNos: Dictionary of [Code[20], Boolean];
        ChildPILItemNos: List of [Code[20]];
        ChildProductionBOMNo: Code[20];
        ChildPILItemNo: Code[20];
        AddedMatchedItemSuppression: Boolean;
        AddedPhysicalItemSuppression: Boolean;
        ChildQuantity: Decimal;
        LineQuantity: Decimal;
        MatchedCurrentLine: Boolean;
    begin
        if BOMPath.Contains(ProductionBOMNo) then
            Error(CircularProductionBOMErr, ProductionBOMNo);
        if BOMPath.Count() >= MaximumProductionBOMDepth() then
            Error(ProductionBOMTooDeepErr, ProductionBOMNo);
        BOMPath.Add(ProductionBOMNo);

        CollectDirectProductionBOMHeadingNos(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            ProductionBOMHeadingNos);
        CollectDirectPhysicalItemNos(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            DirectPhysicalItemNos);
        SetActiveProductionBOMLineFilters(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                MatchedCurrentLine :=
                    EligiblePILItemNos.ContainsKey(ProductionBOMLine."No.") and
                    IsPreferredStructuralBOMLine(ProductionBOMLine, PhysicalItemNos) and
                    not IsSuppressedPhysicalItem(ProductionBOMLine, SuppressedPhysicalItemNos) and
                    not SuppressedMatchedPILItemNos.Contains(ProductionBOMLine."No.");
                if MatchedCurrentLine then begin
                    LineQuantity := GetBOMLineQuantity(ProductionBOMLine);
                    if ChildProductionBOMNo <> '' then
                        CheckChildBOMUnitOfMeasure(ProductionBOMLine, ChildProductionBOMNo, CalculationDate);
                    AddStructuralQuantityToMap(
                        ProductionBOMLine."No.",
                        ParentQuantityPerCarrier * LineQuantity,
                        QuantityPerPILItem);
                end;

                if (ChildProductionBOMNo <> '') and
                   not IsRedundantItemBOMExpansion(ProductionBOMLine, ProductionBOMHeadingNos)
                then begin
                    AddedPhysicalItemSuppression := false;
                    if (ProductionBOMLine.Type = ProductionBOMLine.Type::"Production BOM") and
                       DirectPhysicalItemNos.ContainsKey(ProductionBOMLine."No.") and
                       not SuppressedPhysicalItemNos.Contains(ProductionBOMLine."No.")
                    then begin
                        SuppressedPhysicalItemNos.Add(ProductionBOMLine."No.");
                        AddedPhysicalItemSuppression := true;
                    end;
                    AddedMatchedItemSuppression := false;
                    if MatchedCurrentLine and
                       not SuppressedMatchedPILItemNos.Contains(ProductionBOMLine."No.")
                    then begin
                        SuppressedMatchedPILItemNos.Add(ProductionBOMLine."No.");
                        AddedMatchedItemSuppression := true;
                    end;

                    Clear(ChildQuantityPerPILItem);
                    CollectMasterStructuralQuantitiesInternal(
                        ChildProductionBOMNo,
                        CalculationDate,
                        1,
                        '',
                        false,
                        EligiblePILItemNos,
                        PhysicalItemNos,
                        SuppressedPhysicalItemNos,
                        SuppressedMatchedPILItemNos,
                        ChildQuantityPerPILItem,
                        BOMPath);
                    if ChildQuantityPerPILItem.Count() > 0 then begin
                        if not MatchedCurrentLine then
                            CheckChildBOMUnitOfMeasure(ProductionBOMLine, ChildProductionBOMNo, CalculationDate);
                        if LineQuantity = 0 then
                            LineQuantity := GetBOMLineQuantity(ProductionBOMLine);
                        ChildPILItemNos := ChildQuantityPerPILItem.Keys();
                        foreach ChildPILItemNo in ChildPILItemNos do begin
                            ChildQuantityPerPILItem.Get(ChildPILItemNo, ChildQuantity);
                            AddStructuralQuantityToMap(
                                ChildPILItemNo,
                                ParentQuantityPerCarrier * LineQuantity * ChildQuantity,
                                QuantityPerPILItem);
                        end;
                    end;

                    if AddedMatchedItemSuppression then
                        SuppressedMatchedPILItemNos.Remove(ProductionBOMLine."No.");
                    if AddedPhysicalItemSuppression then
                        SuppressedPhysicalItemNos.Remove(ProductionBOMLine."No.");
                end;
                Clear(LineQuantity);
            until ProductionBOMLine.Next() = 0;

        BOMPath.Remove(ProductionBOMNo);
    end;

    local procedure AddStructuralQuantityToMap(PILItemNo: Code[20]; Quantity: Decimal; var QuantityPerPILItem: Dictionary of [Code[20], Decimal])
    var
        CurrentQuantity: Decimal;
    begin
        if QuantityPerPILItem.Get(PILItemNo, CurrentQuantity) then
            QuantityPerPILItem.Set(PILItemNo, CurrentQuantity + Quantity)
        else
            QuantityPerPILItem.Add(PILItemNo, Quantity);
    end;

    local procedure SumMasterStructuralQuantityPerCarrierInternal(ProductionBOMNo: Code[20]; CalculationDate: Date; PILItemNo: Code[20]; ParentQuantityPerCarrier: Decimal; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; PhysicalItemNos: Dictionary of [Code[20], Boolean]; var SuppressedPhysicalItemNos: List of [Code[20]]; var QuantityPerCarrier: Decimal; var BOMPath: List of [Code[20]])
    var
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
        DirectPhysicalItemNos: Dictionary of [Code[20], Boolean];
        ProductionBOMHeadingNos: Dictionary of [Code[20], Boolean];
        RelevantBOMPath: List of [Code[20]];
        AddedPhysicalItemSuppression: Boolean;
    begin
        if BOMPath.Contains(ProductionBOMNo) then
            Error(CircularProductionBOMErr, ProductionBOMNo);
        if BOMPath.Count() >= MaximumProductionBOMDepth() then
            Error(ProductionBOMTooDeepErr, ProductionBOMNo);
        BOMPath.Add(ProductionBOMNo);

        CollectDirectProductionBOMHeadingNos(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            ProductionBOMHeadingNos);
        CollectDirectPhysicalItemNos(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            DirectPhysicalItemNos);
        SetActiveProductionBOMLineFilters(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion, ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if (ProductionBOMLine."No." = PILItemNo) and
                   IsPreferredStructuralBOMLine(ProductionBOMLine, PhysicalItemNos) and
                   not IsSuppressedPhysicalItem(ProductionBOMLine, SuppressedPhysicalItemNos)
                then begin
                    if ChildProductionBOMNo <> '' then
                        CheckChildBOMUnitOfMeasure(ProductionBOMLine, ChildProductionBOMNo, CalculationDate);
                    QuantityPerCarrier += ParentQuantityPerCarrier * GetBOMLineQuantity(ProductionBOMLine);
                end else
                    if (ChildProductionBOMNo <> '') and
                       not IsRedundantItemBOMExpansion(ProductionBOMLine, ProductionBOMHeadingNos)
                    then begin
                        Clear(RelevantBOMPath);
                        if HasStructuralItemInBOM(
                            PILItemNo,
                            ChildProductionBOMNo,
                            CalculationDate,
                            '',
                            false,
                            RelevantBOMPath)
                        then begin
                            CheckChildBOMUnitOfMeasure(ProductionBOMLine, ChildProductionBOMNo, CalculationDate);
                            AddedPhysicalItemSuppression := false;
                            if (ProductionBOMLine.Type = ProductionBOMLine.Type::"Production BOM") and
                               DirectPhysicalItemNos.ContainsKey(ProductionBOMLine."No.") and
                               not SuppressedPhysicalItemNos.Contains(ProductionBOMLine."No.")
                            then begin
                                SuppressedPhysicalItemNos.Add(ProductionBOMLine."No.");
                                AddedPhysicalItemSuppression := true;
                            end;
                            SumMasterStructuralQuantityPerCarrierInternal(
                                ChildProductionBOMNo,
                                CalculationDate,
                                PILItemNo,
                                ParentQuantityPerCarrier * GetBOMLineQuantity(ProductionBOMLine),
                                '',
                                false,
                                PhysicalItemNos,
                                SuppressedPhysicalItemNos,
                                QuantityPerCarrier,
                                BOMPath);
                            if AddedPhysicalItemSuppression then
                                SuppressedPhysicalItemNos.Remove(ProductionBOMLine."No.");
                        end;
                    end;
            until ProductionBOMLine.Next() = 0;

        BOMPath.Remove(ProductionBOMNo);
    end;

    local procedure CollectPhysicalItemNosInBOM(ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var PhysicalItemNos: Dictionary of [Code[20], Boolean]; var VisitedProductionBOMNos: Dictionary of [Code[20], Boolean]; var BOMPath: List of [Code[20]])
    var
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
        ProductionBOMHeadingNos: Dictionary of [Code[20], Boolean];
    begin
        if BOMPath.Contains(ProductionBOMNo) then
            Error(CircularProductionBOMErr, ProductionBOMNo);
        if VisitedProductionBOMNos.ContainsKey(ProductionBOMNo) then
            exit;
        if BOMPath.Count() >= MaximumProductionBOMDepth() then
            Error(ProductionBOMTooDeepErr, ProductionBOMNo);
        BOMPath.Add(ProductionBOMNo);
        VisitedProductionBOMNos.Add(ProductionBOMNo, true);

        CollectDirectProductionBOMHeadingNos(
            ProductionBOMNo,
            CalculationDate,
            RequestedVersionCode,
            UseRequestedVersion,
            ProductionBOMHeadingNos);
        SetActiveProductionBOMLineFilters(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion, ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                if (ProductionBOMLine.Type = ProductionBOMLine.Type::Item) and
                   not PhysicalItemNos.ContainsKey(ProductionBOMLine."No.")
                then
                    PhysicalItemNos.Add(ProductionBOMLine."No.", true);

                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if (ChildProductionBOMNo <> '') and
                   not IsRedundantItemBOMExpansion(ProductionBOMLine, ProductionBOMHeadingNos)
                then
                    CollectPhysicalItemNosInBOM(
                        ChildProductionBOMNo,
                        CalculationDate,
                        '',
                        false,
                        PhysicalItemNos,
                        VisitedProductionBOMNos,
                        BOMPath);
            until ProductionBOMLine.Next() = 0;

        BOMPath.Remove(ProductionBOMNo);
    end;

    local procedure CollectDirectProductionBOMHeadingNos(ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var ProductionBOMHeadingNos: Dictionary of [Code[20], Boolean])
    var
        ProductionBOMLine: Record "Production BOM Line";
    begin
        SetActiveProductionBOMLineFilters(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion, ProductionBOMLine);
        ProductionBOMLine.SetRange(Type, ProductionBOMLine.Type::"Production BOM");
        if ProductionBOMLine.FindSet() then
            repeat
                if not ProductionBOMHeadingNos.ContainsKey(ProductionBOMLine."No.") then
                    ProductionBOMHeadingNos.Add(ProductionBOMLine."No.", true);
            until ProductionBOMLine.Next() = 0;
    end;

    local procedure CollectDirectPhysicalItemNos(ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var PhysicalItemNos: Dictionary of [Code[20], Boolean])
    var
        ProductionBOMLine: Record "Production BOM Line";
    begin
        SetActiveProductionBOMLineFilters(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion, ProductionBOMLine);
        ProductionBOMLine.SetRange(Type, ProductionBOMLine.Type::Item);
        if ProductionBOMLine.FindSet() then
            repeat
                if not PhysicalItemNos.ContainsKey(ProductionBOMLine."No.") then
                    PhysicalItemNos.Add(ProductionBOMLine."No.", true);
            until ProductionBOMLine.Next() = 0;
    end;

    local procedure IsSuppressedPhysicalItem(ProductionBOMLine: Record "Production BOM Line"; SuppressedPhysicalItemNos: List of [Code[20]]): Boolean
    begin
        exit(
            (ProductionBOMLine.Type = ProductionBOMLine.Type::Item) and
            SuppressedPhysicalItemNos.Contains(ProductionBOMLine."No."));
    end;

    local procedure IsRedundantItemBOMExpansion(ProductionBOMLine: Record "Production BOM Line"; ProductionBOMHeadingNos: Dictionary of [Code[20], Boolean]): Boolean
    begin
        exit(
            (ProductionBOMLine.Type = ProductionBOMLine.Type::Item) and
            ProductionBOMHeadingNos.ContainsKey(ProductionBOMLine."No."));
    end;

    local procedure IsPreferredStructuralBOMLine(ProductionBOMLine: Record "Production BOM Line"; PhysicalItemNos: Dictionary of [Code[20], Boolean]): Boolean
    begin
        case ProductionBOMLine.Type of
            ProductionBOMLine.Type::Item:
                exit(true);
            ProductionBOMLine.Type::"Production BOM":
                exit(not PhysicalItemNos.ContainsKey(ProductionBOMLine."No."));
        end;
        exit(false);
    end;

    local procedure HasStructuralItemInBOM(PILItemNo: Code[20]; ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var BOMPath: List of [Code[20]]): Boolean
    var
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
        HasItem: Boolean;
    begin
        if BOMPath.Contains(ProductionBOMNo) then
            Error(CircularProductionBOMErr, ProductionBOMNo);
        if BOMPath.Count() >= MaximumProductionBOMDepth() then
            Error(ProductionBOMTooDeepErr, ProductionBOMNo);
        BOMPath.Add(ProductionBOMNo);

        SetActiveProductionBOMLineFilters(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion, ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if ProductionBOMLine."No." = PILItemNo then
                    HasItem := true
                else
                    if ChildProductionBOMNo <> '' then
                        HasItem := HasStructuralItemInBOM(
                            PILItemNo,
                            ChildProductionBOMNo,
                            CalculationDate,
                            '',
                            false,
                            BOMPath);
            until (ProductionBOMLine.Next() = 0) or HasItem;

        BOMPath.Remove(ProductionBOMNo);
        exit(HasItem);
    end;

    local procedure CheckCarrierSafety(CarrierProdOrderLine: Record "Prod. Order Line"; PNEPILTarget: Record "PNE PIL Target"; var TempCheckedProdOrderLine: Record "Prod. Order Line" temporary; var TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary; var TempAncestorExpandedProdOrderLine: Record "Prod. Order Line" temporary; var TempTreeExpandedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ParentProdOrderComponent: Record "Prod. Order Component";
        ParentComponentCount: Integer;
        ParentExpectedQuantity: Decimal;
    begin
        if Abs(CarrierProdOrderLine.Quantity - PNEPILTarget."Original Carrier Quantity") > QuantityTolerance() then
            Error(CarrierChangedSincePrepareErr, CarrierProdOrderLine."Item No.");
        CheckProductionOrderLineSafetyOnce(CarrierProdOrderLine, TempCheckedProdOrderLine);
        if CarrierProdOrderLine.Quantity <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, CarrierProdOrderLine."Item No.");

        ParentProdOrderComponent.SetRange(Status, CarrierProdOrderLine.Status);
        ParentProdOrderComponent.SetRange("Prod. Order No.", CarrierProdOrderLine."Prod. Order No.");
        ParentProdOrderComponent.SetRange("Supplied-by Line No.", CarrierProdOrderLine."Line No.");
        ParentComponentCount := ParentProdOrderComponent.Count();
        if ParentComponentCount > 0 then begin
            ParentProdOrderComponent.CalcSums("Expected Quantity");
            ParentExpectedQuantity := ParentProdOrderComponent."Expected Quantity";
            if Abs(ParentExpectedQuantity - CarrierProdOrderLine.Quantity) > QuantityTolerance() then
                Error(InboundDemandMismatchErr, CarrierProdOrderLine."Item No.");
            if ParentProdOrderComponent.FindSet() then
                repeat
                    CheckInboundDemandComponent(ParentProdOrderComponent, CarrierProdOrderLine);
                    CheckLinkedProductionOrderUnitOfMeasure(ParentProdOrderComponent, CarrierProdOrderLine);
                    CheckComponentSafetyOnce(ParentProdOrderComponent, TempCheckedProdOrderComponent);
                until ParentProdOrderComponent.Next() = 0;
        end;

        CheckProductionOrderLineAncestorSafety(
            CarrierProdOrderLine,
            TempCheckedProdOrderLine,
            TempCheckedProdOrderComponent,
            TempAncestorExpandedProdOrderLine);
        CheckProductionOrderLineTreeSafety(
            CarrierProdOrderLine,
            TempCheckedProdOrderLine,
            TempCheckedProdOrderComponent,
            TempTreeExpandedProdOrderLine);
    end;

    local procedure CheckComponentCarrierSafety(var CarrierProdOrderComponent: Record "Prod. Order Component"; PNEPILTarget: Record "PNE PIL Target"; var TempCheckedProdOrderLine: Record "Prod. Order Line" temporary; var TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary; var TempAncestorExpandedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        OwningProdOrderLine: Record "Prod. Order Line";
    begin
        if Abs(CarrierProdOrderComponent."Expected Quantity" - PNEPILTarget."Original Carrier Quantity") > QuantityTolerance() then
            Error(CarrierChangedSincePrepareErr, CarrierProdOrderComponent."Item No.");
        if CarrierProdOrderComponent."Expected Quantity" <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, CarrierProdOrderComponent."Item No.");

        OwningProdOrderLine.Get(
            CarrierProdOrderComponent.Status,
            CarrierProdOrderComponent."Prod. Order No.",
            CarrierProdOrderComponent."Prod. Order Line No.");
        CheckProductionOrderLineSafetyOnce(OwningProdOrderLine, TempCheckedProdOrderLine);
        CheckComponentSafetyOnce(CarrierProdOrderComponent, TempCheckedProdOrderComponent);
        CheckProductionOrderLineAncestorSafety(
            OwningProdOrderLine,
            TempCheckedProdOrderLine,
            TempCheckedProdOrderComponent,
            TempAncestorExpandedProdOrderLine);
        if FindChildProdOrderLine(CarrierProdOrderComponent, ChildProdOrderLine) then
            Error(ComponentCarrierNowLinkedErr, CarrierProdOrderComponent."Item No.");
    end;

    local procedure CheckProductionOrderLineSafety(ProdOrderLine: Record "Prod. Order Line")
    begin
        CheckProductionOrderLineUnitOfMeasure(ProdOrderLine);
        if ProdOrderLine."Finished Quantity" <> 0 then
            Error(FinishedCarrierErr, ProdOrderLine."Item No.");
        ProdOrderLine.CalcFields("Reserved Quantity", "Reserved Qty. (Base)");
        if ((ProdOrderLine."Reserved Quantity" <> 0) or (ProdOrderLine."Reserved Qty. (Base)" <> 0)) and
           HasUnsafeProdOrderLineReservation(ProdOrderLine)
        then
            Error(CarrierReservedErr, ProdOrderLine."Item No.");
        CheckOpenProductionJournal(ProdOrderLine);
        CheckProductionOrderRoutingSafety(ProdOrderLine);
    end;

    local procedure CheckProductionOrderLineSafetyOnce(ProdOrderLine: Record "Prod. Order Line"; var TempCheckedProdOrderLine: Record "Prod. Order Line" temporary)
    begin
        if TempCheckedProdOrderLine.Get(
             ProdOrderLine.Status,
             ProdOrderLine."Prod. Order No.",
             ProdOrderLine."Line No.")
        then
            exit;
        CheckProductionOrderLineSafety(ProdOrderLine);
        TempCheckedProdOrderLine := ProdOrderLine;
        TempCheckedProdOrderLine.Insert();
    end;

    local procedure CheckOrderRoutingRecalculationSafety(ProductionOrder: Record "Production Order")
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProdOrderLine.FindSet() then
            repeat
                if ProdOrderLine."Finished Quantity" <> 0 then
                    Error(FinishedCarrierErr, ProdOrderLine."Item No.");
                CheckOpenProductionJournal(ProdOrderLine);
                CheckProductionOrderRoutingSafety(ProdOrderLine);
            until ProdOrderLine.Next() = 0;
    end;

    local procedure HasUnsafeProdOrderLineReservation(ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        ParentProdOrderComponent: Record "Prod. Order Component";
        PairedReservationEntry: Record "Reservation Entry";
        ReservationEntry: Record "Reservation Entry";
    begin
        ReservationEntry.SetSourceFilter(
            Database::"Prod. Order Line",
            ProdOrderLine.Status.AsInteger(),
            ProdOrderLine."Prod. Order No.",
            0,
            false);
        ReservationEntry.SetSourceFilter('', ProdOrderLine."Line No.");
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        if ReservationEntry.FindSet() then
            repeat
                if not PairedReservationEntry.Get(ReservationEntry."Entry No.", not ReservationEntry.Positive) then
                    exit(true);
                if (PairedReservationEntry."Source Type" <> Database::"Prod. Order Component") or
                   (PairedReservationEntry."Source ID" <> ProdOrderLine."Prod. Order No.") or
                   (PairedReservationEntry."Source Subtype" <> ProdOrderLine.Status.AsInteger())
                then
                    exit(true);
                if not ParentProdOrderComponent.Get(
                    PairedReservationEntry."Source Subtype",
                    PairedReservationEntry."Source ID",
                    PairedReservationEntry."Source Prod. Order Line",
                    PairedReservationEntry."Source Ref. No.")
                then
                    exit(true);
                if (ParentProdOrderComponent."Item No." <> ProdOrderLine."Item No.") or
                   (ParentProdOrderComponent."Variant Code" <> ProdOrderLine."Variant Code") or
                   ((ParentProdOrderComponent."Supplied-by Line No." <> 0) and
                    (ParentProdOrderComponent."Supplied-by Line No." <> ProdOrderLine."Line No."))
                then
                    exit(true);
            until ReservationEntry.Next() = 0;
        exit(false);
    end;

    local procedure CheckProductionOrderLineAncestorSafety(ProdOrderLine: Record "Prod. Order Line"; var TempCheckedProdOrderLine: Record "Prod. Order Line" temporary; var TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary; var TempAncestorExpandedProdOrderLine: Record "Prod. Order Line" temporary)
    begin
        CheckProductionOrderLineAncestorSafetyRecursive(
            ProdOrderLine,
            TempCheckedProdOrderLine,
            TempCheckedProdOrderComponent,
            TempAncestorExpandedProdOrderLine);
    end;

    local procedure CheckProductionOrderLineAncestorSafetyRecursive(CurrentProdOrderLine: Record "Prod. Order Line"; var TempCheckedProdOrderLine: Record "Prod. Order Line" temporary; var TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary; var TempAncestorExpandedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ParentProdOrderComponent: Record "Prod. Order Component";
        ParentProdOrderLine: Record "Prod. Order Line";
    begin
        if WasVisited(CurrentProdOrderLine, TempAncestorExpandedProdOrderLine) then
            exit;
        CheckProductionOrderLineSafetyOnce(CurrentProdOrderLine, TempCheckedProdOrderLine);

        ParentProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ParentProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ParentProdOrderComponent.SetRange("Supplied-by Line No.", CurrentProdOrderLine."Line No.");
        if ParentProdOrderComponent.FindSet() then
            repeat
                CheckInboundDemandComponent(ParentProdOrderComponent, CurrentProdOrderLine);
                CheckLinkedProductionOrderUnitOfMeasure(ParentProdOrderComponent, CurrentProdOrderLine);
                CheckComponentSafetyOnce(ParentProdOrderComponent, TempCheckedProdOrderComponent);
                ParentProdOrderLine.Get(
                    ParentProdOrderComponent.Status,
                    ParentProdOrderComponent."Prod. Order No.",
                    ParentProdOrderComponent."Prod. Order Line No.");
                CheckProductionOrderLineAncestorSafetyRecursive(
                    ParentProdOrderLine,
                    TempCheckedProdOrderLine,
                    TempCheckedProdOrderComponent,
                    TempAncestorExpandedProdOrderLine);
            until ParentProdOrderComponent.Next() = 0;
    end;

    local procedure CheckOpenProductionJournal(ProdOrderLine: Record "Prod. Order Line")
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        ItemJournalLine.SetRange("Order Type", ItemJournalLine."Order Type"::Production);
        ItemJournalLine.SetRange("Order No.", ProdOrderLine."Prod. Order No.");
        ItemJournalLine.SetRange("Order Line No.", ProdOrderLine."Line No.");
        if not ItemJournalLine.IsEmpty() then
            Error(OpenProductionJournalErr, ProdOrderLine."Item No.", ProdOrderLine."Prod. Order No.");
    end;

    local procedure CheckProductionOrderRoutingSafety(ProdOrderLine: Record "Prod. Order Line")
    var
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
    begin
        if ProdOrderLine."Routing No." = '' then
            exit;

        ProdOrderRoutingLine.SetRange(Status, ProdOrderLine.Status);
        ProdOrderRoutingLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        ProdOrderRoutingLine.SetRange("Routing Reference No.", ProdOrderLine."Routing Reference No.");
        ProdOrderRoutingLine.SetRange("Routing No.", ProdOrderLine."Routing No.");
        if ProdOrderRoutingLine.FindSet() then
            repeat
                if ProdOrderRoutingLine."Routing Status" in [
                    ProdOrderRoutingLine."Routing Status"::"In Progress",
                    ProdOrderRoutingLine."Routing Status"::Finished]
                then
                    Error(ProductionRoutingStartedErr, ProdOrderLine."Item No.", ProdOrderLine."Prod. Order No.");
                ProdOrderRoutingLine.CalcFields(
                    "Posted Output Quantity",
                    "Posted Scrap Quantity",
                    "Posted Run Time",
                    "Posted Setup Time");
                if (ProdOrderRoutingLine."Posted Output Quantity" <> 0) or
                   (ProdOrderRoutingLine."Posted Scrap Quantity" <> 0) or
                   (ProdOrderRoutingLine."Posted Run Time" <> 0) or
                   (ProdOrderRoutingLine."Posted Setup Time" <> 0)
                then
                    Error(ProductionRoutingPostedActivityErr, ProdOrderLine."Item No.", ProdOrderLine."Prod. Order No.");
            until ProdOrderRoutingLine.Next() = 0;
    end;

    local procedure CheckProductionOrderLineTreeSafety(CurrentProdOrderLine: Record "Prod. Order Line"; var TempCheckedProdOrderLine: Record "Prod. Order Line" temporary; var TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary; var TempTreeExpandedProdOrderLine: Record "Prod. Order Line" temporary)
    begin
        CheckProductionOrderLineTreeSafetyRecursive(
            CurrentProdOrderLine,
            TempCheckedProdOrderLine,
            TempCheckedProdOrderComponent,
            TempTreeExpandedProdOrderLine);
    end;

    local procedure CheckProductionOrderLineTreeSafetyRecursive(CurrentProdOrderLine: Record "Prod. Order Line"; var TempCheckedProdOrderLine: Record "Prod. Order Line" temporary; var TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary; var TempTreeExpandedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        if WasVisited(CurrentProdOrderLine, TempTreeExpandedProdOrderLine) then
            exit;
        CheckProductionOrderLineSafetyOnce(CurrentProdOrderLine, TempCheckedProdOrderLine);

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                CheckComponentSafetyOnce(ProdOrderComponent, TempCheckedProdOrderComponent);
                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then begin
                    CheckLinkedProductionOrderUnitOfMeasure(ProdOrderComponent, ChildProdOrderLine);
                    CheckProductionOrderLineTreeSafetyRecursive(
                        ChildProdOrderLine,
                        TempCheckedProdOrderLine,
                        TempCheckedProdOrderComponent,
                        TempTreeExpandedProdOrderLine);
                end;
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure CheckComponentSafety(var ProdOrderComponent: Record "Prod. Order Component")
    begin
        ProdOrderComponent.CalcFields("Act. Consumption (Qty)", "Reserved Qty. (Base)");
        if ProdOrderComponent."Act. Consumption (Qty)" <> 0 then
            Error(ComponentConsumedErr, ProdOrderComponent."Item No.");
        if (ProdOrderComponent."Reserved Qty. (Base)" <> 0) and
           HasUnsafeProdOrderComponentReservation(ProdOrderComponent)
        then
            Error(ComponentReservedErr, ProdOrderComponent."Item No.");
        if ProdOrderComponent."Qty. Picked (Base)" <> 0 then
            Error(ComponentPickedErr, ProdOrderComponent."Item No.");
    end;

    local procedure CheckComponentSafetyOnce(var ProdOrderComponent: Record "Prod. Order Component"; var TempCheckedProdOrderComponent: Record "Prod. Order Component" temporary)
    begin
        if TempCheckedProdOrderComponent.Get(
             ProdOrderComponent.Status,
             ProdOrderComponent."Prod. Order No.",
             ProdOrderComponent."Prod. Order Line No.",
             ProdOrderComponent."Line No.")
        then
            exit;
        CheckComponentSafety(ProdOrderComponent);
        TempCheckedProdOrderComponent := ProdOrderComponent;
        TempCheckedProdOrderComponent.Insert();
    end;

    local procedure HasUnsafeProdOrderComponentReservation(ProdOrderComponent: Record "Prod. Order Component"): Boolean
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        PairedReservationEntry: Record "Reservation Entry";
        ReservationEntry: Record "Reservation Entry";
        InternalChildLineNo: Integer;
    begin
        InternalChildLineNo := 0;
        ReservationEntry.SetSourceFilter(
            Database::"Prod. Order Component",
            ProdOrderComponent.Status.AsInteger(),
            ProdOrderComponent."Prod. Order No.",
            ProdOrderComponent."Line No.",
            false);
        ReservationEntry.SetSourceFilter('', ProdOrderComponent."Prod. Order Line No.");
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        if ReservationEntry.FindSet() then
            repeat
                if not PairedReservationEntry.Get(ReservationEntry."Entry No.", not ReservationEntry.Positive) then
                    exit(true);
                if (PairedReservationEntry."Source Type" <> Database::"Prod. Order Line") or
                   (PairedReservationEntry."Source ID" <> ProdOrderComponent."Prod. Order No.") or
                   (PairedReservationEntry."Source Subtype" <> ProdOrderComponent.Status.AsInteger()) or
                   (PairedReservationEntry."Source Ref. No." <> 0)
                then
                    exit(true);
                if not ChildProdOrderLine.Get(
                    PairedReservationEntry."Source Subtype",
                    PairedReservationEntry."Source ID",
                    PairedReservationEntry."Source Prod. Order Line")
                then
                    exit(true);
                if (ChildProdOrderLine."Item No." <> ProdOrderComponent."Item No.") or
                   (ChildProdOrderLine."Variant Code" <> ProdOrderComponent."Variant Code") or
                   ((ProdOrderComponent."Supplied-by Line No." <> 0) and
                    (ProdOrderComponent."Supplied-by Line No." <> ChildProdOrderLine."Line No."))
                then
                    exit(true);
                if InternalChildLineNo = 0 then
                    InternalChildLineNo := ChildProdOrderLine."Line No."
                else
                    if InternalChildLineNo <> ChildProdOrderLine."Line No." then
                        exit(true);
            until ReservationEntry.Next() = 0;
        exit(false);
    end;

    local procedure UpdateCarrierQuantities(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILTarget.FindSet() then
            repeat
                if not (PNEPILTarget.Kind in [
                        PNEPILTarget.Kind::"Direct component addition",
                        PNEPILTarget.Kind::"Point carrier addition"]) and
                   not HasEarlierQuantityTargetForCarrier(PNEPILTarget)
                then
                    case PNEPILTarget."Carrier Type" of
                        PNEPILTarget."Carrier Type"::"Production Order Line":
                            UpdateCarrierProductionOrderLine(PNEPILTarget);
                        PNEPILTarget."Carrier Type"::"Production Order Component":
                            UpdateCarrierProductionOrderComponent(PNEPILTarget);
                    end;
            until PNEPILTarget.Next() = 0;
    end;

    local procedure AddDirectPILComponents(PNEPILHeader: Record "PNE PIL Header")
    var
        DestinationProdOrderLine: Record "Prod. Order Line";
        ExistingProdOrderComponent: Record "Prod. Order Component";
        NewProdOrderComponent: Record "Prod. Order Component";
        PNEPILTarget: Record "PNE PIL Target";
        NextLineNo: Integer;
        DesiredQuantity: Decimal;
        NewQuantityPer: Decimal;
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Direct component addition");
        if PNEPILTarget.FindSet() then
            repeat
                DestinationProdOrderLine.Get(
                    PNEPILTarget."Carrier Status",
                    PNEPILTarget."Carrier Production Order No.",
                    PNEPILTarget."Carrier Order Line No.");
                if DestinationProdOrderLine.Quantity <= QuantityTolerance() then
                    Error(ZeroCarrierQuantityErr, DestinationProdOrderLine."Item No.");

                DesiredQuantity :=
                    PNEPILTarget."Existing Actual PIL Quantity" +
                    PNEPILTarget."Allocated PIL Quantity";
                if not IsNullGuid(PNEPILTarget."Existing Direct Comp. SystemId") then begin
                    ExistingProdOrderComponent.Get(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.",
                        PNEPILTarget."Existing Direct Comp. Line No.");
                    if ExistingProdOrderComponent."Expected Quantity" <= QuantityTolerance() then
                        Error(ReplacementQuantityMismatchErr, PNEPILTarget."PIL Item No.");
                    NewQuantityPer :=
                        ExistingProdOrderComponent."Quantity per" *
                        DesiredQuantity /
                        ExistingProdOrderComponent."Expected Quantity";
                    ExistingProdOrderComponent.Validate("Quantity per", NewQuantityPer);
                    if Abs(ExistingProdOrderComponent."Expected Quantity" - DesiredQuantity) > QuantityTolerance() then
                        Error(ReplacementQuantityMismatchErr, PNEPILTarget."PIL Item No.");
                    ExistingProdOrderComponent.Modify(true);
                end else begin

                    NextLineNo := GetNextComponentLineNoForOrderLine(DestinationProdOrderLine);
                    NewProdOrderComponent.Init();
                    NewProdOrderComponent.Status := DestinationProdOrderLine.Status;
                    NewProdOrderComponent."Prod. Order No." := DestinationProdOrderLine."Prod. Order No.";
                    NewProdOrderComponent."Prod. Order Line No." := DestinationProdOrderLine."Line No.";
                    NewProdOrderComponent."Line No." := NextLineNo + 10000;
                    NewProdOrderComponent."Location Code" := DestinationProdOrderLine."Location Code";
                    NewProdOrderComponent.Validate("Item No.", PNEPILTarget."PIL Item No.");
                    NewProdOrderComponent."Bin Code" := DestinationProdOrderLine."Bin Code";
                    NewProdOrderComponent."Due Date" := DestinationProdOrderLine."Starting Date";
                    NewProdOrderComponent."Due Time" := DestinationProdOrderLine."Starting Time";
                    NewProdOrderComponent."Planning Level Code" := DestinationProdOrderLine."Planning Level Code" + 1;
                    NewProdOrderComponent.Validate("Unit of Measure Code", PiecesUnitOfMeasureLbl);
                    NewQuantityPer := DesiredQuantity / DestinationProdOrderLine.Quantity;
                    NewProdOrderComponent.Validate("Quantity per", NewQuantityPer);
                    if Abs(NewProdOrderComponent."Expected Quantity" - DesiredQuantity) > QuantityTolerance() then
                        Error(ReplacementQuantityMismatchErr, PNEPILTarget."PIL Item No.");
                    NewProdOrderComponent.Insert(true);
                end;
            until PNEPILTarget.Next() = 0;
    end;

    local procedure AddPointCarrierPILComponents(PNEPILHeader: Record "PNE PIL Header")
    var
        DestinationProdOrderLine: Record "Prod. Order Line";
        ExistingProdOrderComponent: Record "Prod. Order Component";
        NewProdOrderComponent: Record "Prod. Order Component";
        NewPointCarrierProdOrderLine: Record "Prod. Order Line";
        PNEPILTarget: Record "PNE PIL Target";
        CalculateProdOrder: Codeunit "Calculate Prod. Order";
        Direction: Option Forward,Backward;
        NextProdOrderLineNo: Integer;
        NextLineNo: Integer;
        NewQuantityPer: Decimal;
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Point carrier addition");
        if PNEPILTarget.FindSet() then
            repeat
                if not HasEarlierTargetForCarrier(PNEPILTarget) then begin
                DestinationProdOrderLine.Get(
                    PNEPILTarget."Carrier Status",
                    PNEPILTarget."Carrier Production Order No.",
                    PNEPILTarget."Carrier Order Line No.");
                ExistingProdOrderComponent.SetRange(Status, DestinationProdOrderLine.Status);
                ExistingProdOrderComponent.SetRange("Prod. Order No.", DestinationProdOrderLine."Prod. Order No.");
                ExistingProdOrderComponent.SetRange("Prod. Order Line No.", DestinationProdOrderLine."Line No.");
                ExistingProdOrderComponent.SetRange("Item No.", PNEPILTarget."New Point Carrier Item No.");
                if not ExistingProdOrderComponent.IsEmpty() then
                    Error(PointCarrierAlreadyAddedErr, PNEPILTarget."New Point Carrier Item No.");
                ExistingProdOrderComponent.Reset();
                if DestinationProdOrderLine.Quantity <= QuantityTolerance() then
                    Error(ZeroCarrierQuantityErr, DestinationProdOrderLine."Item No.");

                NextLineNo := GetNextComponentLineNoForOrderLine(DestinationProdOrderLine);
                NewProdOrderComponent.Init();
                NewProdOrderComponent.Status := DestinationProdOrderLine.Status;
                NewProdOrderComponent."Prod. Order No." := DestinationProdOrderLine."Prod. Order No.";
                NewProdOrderComponent."Prod. Order Line No." := DestinationProdOrderLine."Line No.";
                NewProdOrderComponent."Line No." := NextLineNo + 10000;
                NewProdOrderComponent."Location Code" := DestinationProdOrderLine."Location Code";
                NewProdOrderComponent."Bin Code" := DestinationProdOrderLine."Bin Code";
                NewProdOrderComponent."Due Date" := DestinationProdOrderLine."Starting Date";
                NewProdOrderComponent."Due Time" := DestinationProdOrderLine."Starting Time";
                NewProdOrderComponent."Planning Level Code" := DestinationProdOrderLine."Planning Level Code" + 1;
                NewProdOrderComponent.Validate("Item No.", PNEPILTarget."New Point Carrier Item No.");
                NewProdOrderComponent.Validate("Unit of Measure Code", PiecesUnitOfMeasureLbl);
                NewQuantityPer := PNEPILTarget."New Carrier Quantity" / DestinationProdOrderLine.Quantity;
                NewProdOrderComponent.Validate("Quantity per", NewQuantityPer);
                if Abs(NewProdOrderComponent."Expected Quantity" - PNEPILTarget."New Carrier Quantity") > QuantityTolerance() then
                    Error(ReplacementQuantityMismatchErr, PNEPILTarget."New Point Carrier Item No.");
                NewProdOrderComponent.Insert(true);

                NextProdOrderLineNo := GetNextProductionOrderLineNo(DestinationProdOrderLine) + 10000;
                InitializePointCarrierProductionOrderLine(
                    NewPointCarrierProdOrderLine,
                    NewProdOrderComponent,
                    DestinationProdOrderLine,
                    NextProdOrderLineNo);
                NewPointCarrierProdOrderLine.Insert(true);
                CalculateProdOrder.Calculate(
                    NewPointCarrierProdOrderLine,
                    Direction::Backward,
                    true,
                    true,
                    true,
                    false);
                NewProdOrderComponent.Get(
                    DestinationProdOrderLine.Status,
                    DestinationProdOrderLine."Prod. Order No.",
                    DestinationProdOrderLine."Line No.",
                    NextLineNo + 10000);
                NewProdOrderComponent."Supplied-by Line No." := NewPointCarrierProdOrderLine."Line No.";
                NewProdOrderComponent.Modify(true);
                end;
            until PNEPILTarget.Next() = 0;
    end;

    local procedure InitializePointCarrierProductionOrderLine(var NewProdOrderLine: Record "Prod. Order Line"; NewProdOrderComponent: Record "Prod. Order Component"; DestinationProdOrderLine: Record "Prod. Order Line"; NewLineNo: Integer)
    begin
        NewProdOrderLine.Init();
        NewProdOrderLine.SetIgnoreErrors();
        NewProdOrderLine.Status := DestinationProdOrderLine.Status;
        NewProdOrderLine."Prod. Order No." := DestinationProdOrderLine."Prod. Order No.";
        NewProdOrderLine."Line No." := NewLineNo;
        NewProdOrderLine."Routing Reference No." := NewLineNo;
        NewProdOrderLine.Validate("Item No.", NewProdOrderComponent."Item No.");
        NewProdOrderLine."Location Code" := NewProdOrderComponent."Location Code";
        NewProdOrderLine.Validate("Variant Code", NewProdOrderComponent."Variant Code");
        NewProdOrderLine.Validate("Unit of Measure Code", NewProdOrderComponent."Unit of Measure Code");
        NewProdOrderLine."Qty. per Unit of Measure" := NewProdOrderComponent."Qty. per Unit of Measure";
        NewProdOrderLine."Bin Code" := NewProdOrderComponent."Bin Code";
        NewProdOrderLine.Description := NewProdOrderComponent.Description;
        NewProdOrderLine."Description 2" := NewProdOrderComponent."Description 2";
        NewProdOrderLine.Validate(Quantity, NewProdOrderComponent."Expected Quantity");
        NewProdOrderLine."Planning Level Code" := NewProdOrderComponent."Planning Level Code";
        NewProdOrderLine."Due Date" := NewProdOrderComponent."Due Date";
        NewProdOrderLine."Starting Date" := DestinationProdOrderLine."Starting Date";
        NewProdOrderLine."Starting Time" := DestinationProdOrderLine."Starting Time";
        NewProdOrderLine."Ending Date" := NewProdOrderComponent."Due Date";
        NewProdOrderLine."Ending Time" := NewProdOrderComponent."Due Time";
        NewProdOrderLine.UpdateDatetime();
        NewProdOrderLine.Validate("Unit Cost");
    end;

    local procedure GetNextProductionOrderLineNo(ProdOrderLine: Record "Prod. Order Line"): Integer
    var
        ExistingProdOrderLine: Record "Prod. Order Line";
    begin
        ExistingProdOrderLine.SetRange(Status, ProdOrderLine.Status);
        ExistingProdOrderLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        if ExistingProdOrderLine.FindLast() then
            exit(ExistingProdOrderLine."Line No.");
        exit(0);
    end;

    local procedure UpdateCarrierProductionOrderLine(PNEPILTarget: Record "PNE PIL Target")
    var
        CarrierProdOrderLine: Record "Prod. Order Line";
    begin
        CarrierProdOrderLine.Get(
            PNEPILTarget."Carrier Status",
            PNEPILTarget."Carrier Production Order No.",
            PNEPILTarget."Carrier Order Line No.");
        if Abs(CarrierProdOrderLine.Quantity - PNEPILTarget."Original Carrier Quantity") > QuantityTolerance() then
            Error(CarrierChangedSincePrepareErr, CarrierProdOrderLine."Item No.");
        if Abs(PNEPILTarget."New Carrier Quantity" - CarrierProdOrderLine.Quantity) <= QuantityTolerance() then
            exit;

        UpdateInboundDemand(CarrierProdOrderLine, PNEPILTarget."New Carrier Quantity");
        CarrierProdOrderLine.Validate(Quantity, PNEPILTarget."New Carrier Quantity");
        CarrierProdOrderLine.Modify(true);
        SynchronizeChildProductionOrderLines(CarrierProdOrderLine);
    end;

    local procedure UpdateCarrierProductionOrderComponent(PNEPILTarget: Record "PNE PIL Target")
    var
        CarrierProdOrderComponent: Record "Prod. Order Component";
        ChildProdOrderLine: Record "Prod. Order Line";
        NewQuantityPer: Decimal;
    begin
        CarrierProdOrderComponent.Get(
            PNEPILTarget."Carrier Status",
            PNEPILTarget."Carrier Production Order No.",
            PNEPILTarget."Carrier Order Line No.",
            PNEPILTarget."Carrier Component Line No.");
        if Abs(CarrierProdOrderComponent."Expected Quantity" - PNEPILTarget."Original Carrier Quantity") > QuantityTolerance() then
            Error(CarrierChangedSincePrepareErr, CarrierProdOrderComponent."Item No.");
        if Abs(
             PNEPILTarget."New Carrier Quantity" -
             CarrierProdOrderComponent."Expected Quantity") <= QuantityTolerance()
        then
            exit;
        if CarrierProdOrderComponent."Expected Quantity" <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, CarrierProdOrderComponent."Item No.");
        if FindChildProdOrderLine(CarrierProdOrderComponent, ChildProdOrderLine) then
            Error(ComponentCarrierNowLinkedErr, CarrierProdOrderComponent."Item No.");

        NewQuantityPer := CarrierProdOrderComponent."Quantity per" * PNEPILTarget."New Carrier Quantity" / CarrierProdOrderComponent."Expected Quantity";
        CarrierProdOrderComponent.Validate("Quantity per", NewQuantityPer);
        CarrierProdOrderComponent.Modify(true);
        if Abs(CarrierProdOrderComponent."Expected Quantity" - PNEPILTarget."New Carrier Quantity") > QuantityTolerance() then
            Error(CarrierQuantityMismatchErr, CarrierProdOrderComponent."Item No.");
    end;

    local procedure UpdateInboundDemand(CarrierProdOrderLine: Record "Prod. Order Line"; DesiredCarrierQuantity: Decimal)
    var
        ParentProdOrderComponent: Record "Prod. Order Component";
        NewQuantityPer: Decimal;
        OldCarrierQuantity: Decimal;
    begin
        OldCarrierQuantity := CarrierProdOrderLine.Quantity;
        if OldCarrierQuantity <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, CarrierProdOrderLine."Item No.");

        ParentProdOrderComponent.SetRange(Status, CarrierProdOrderLine.Status);
        ParentProdOrderComponent.SetRange("Prod. Order No.", CarrierProdOrderLine."Prod. Order No.");
        ParentProdOrderComponent.SetRange("Supplied-by Line No.", CarrierProdOrderLine."Line No.");
        if ParentProdOrderComponent.FindSet(true) then
            repeat
                CheckInboundDemandComponent(ParentProdOrderComponent, CarrierProdOrderLine);
                CheckLinkedProductionOrderUnitOfMeasure(ParentProdOrderComponent, CarrierProdOrderLine);
                NewQuantityPer := ParentProdOrderComponent."Quantity per" * DesiredCarrierQuantity / OldCarrierQuantity;
                ParentProdOrderComponent.Validate("Quantity per", NewQuantityPer);
                ParentProdOrderComponent.Modify(true);
            until ParentProdOrderComponent.Next() = 0;
    end;

    local procedure SynchronizeChildProductionOrderLines(ParentProdOrderLine: Record "Prod. Order Line")
    var
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        SynchronizeChildProductionOrderLinesRecursive(ParentProdOrderLine, TempVisitedProdOrderLine);
    end;

    local procedure SynchronizeChildProductionOrderLinesRecursive(ParentProdOrderLine: Record "Prod. Order Line"; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
        DesiredChildQuantity: Decimal;
    begin
        if WasVisited(ParentProdOrderLine, TempVisitedProdOrderLine) then
            exit;

        ProdOrderComponent.SetRange(Status, ParentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", ParentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", ParentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then begin
                    CheckLinkedProductionOrderUnitOfMeasure(ProdOrderComponent, ChildProdOrderLine);
                    DesiredChildQuantity := GetInboundDemandQuantity(ChildProdOrderLine);
                    if Abs(ChildProdOrderLine.Quantity - DesiredChildQuantity) > QuantityTolerance() then begin
                        ChildProdOrderLine.Validate(Quantity, DesiredChildQuantity);
                        ChildProdOrderLine.Modify(true);
                    end;
                    SynchronizeChildProductionOrderLinesRecursive(ChildProdOrderLine, TempVisitedProdOrderLine);
                end;
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure GetInboundDemandQuantity(CarrierProdOrderLine: Record "Prod. Order Line"): Decimal
    var
        ParentProdOrderComponent: Record "Prod. Order Component";
        InboundQuantity: Decimal;
    begin
        ParentProdOrderComponent.SetRange(Status, CarrierProdOrderLine.Status);
        ParentProdOrderComponent.SetRange("Prod. Order No.", CarrierProdOrderLine."Prod. Order No.");
        ParentProdOrderComponent.SetRange("Supplied-by Line No.", CarrierProdOrderLine."Line No.");
        if ParentProdOrderComponent.IsEmpty() then
            exit(CarrierProdOrderLine.Quantity);
        if ParentProdOrderComponent.FindSet() then
            repeat
                CheckInboundDemandComponent(ParentProdOrderComponent, CarrierProdOrderLine);
                CheckLinkedProductionOrderUnitOfMeasure(ParentProdOrderComponent, CarrierProdOrderLine);
            until ParentProdOrderComponent.Next() = 0;
        ParentProdOrderComponent.CalcSums("Expected Quantity");
        InboundQuantity := ParentProdOrderComponent."Expected Quantity";
        exit(InboundQuantity);
    end;

    local procedure ReplaceCALCComponents(PNEPILHeader: Record "PNE PIL Header")
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"CALC replacement");
        if PNEPILTarget.FindSet() then
            repeat
                if not HasEarlierCALCTargetForCarrierAndGroup(PNEPILTarget) then
                    ReplaceCALCComponentsForCarrierAndGroup(PNEPILTarget);
            until PNEPILTarget.Next() = 0;
    end;

    local procedure ReplaceCALCComponentsForCarrierAndGroup(FirstPNEPILTarget: Record "PNE PIL Target")
    var
        CarrierProdOrderLine: Record "Prod. Order Line";
        ExistingActualProdOrderComponent: Record "Prod. Order Component";
        ExistingActualProdOrderLine: Record "Prod. Order Line";
        FoundCALCProdOrderComponent: Record "Prod. Order Component";
        NewProdOrderComponent: Record "Prod. Order Component";
        PNEPILTarget: Record "PNE PIL Target";
        SourceCALCProdOrderComponent: Record "Prod. Order Component";
        SourceCALCProdOrderLine: Record "Prod. Order Line";
        AvailableCALCQuantity: Decimal;
        DesiredActualQuantity: Decimal;
        ExistingActualQuantity: Decimal;
        FoundCount: Integer;
        NextLineNo: Integer;
        NewQuantityPer: Decimal;
        ReleasedActualQuantity: Decimal;
        RemainingCALCQuantity: Decimal;
        ReplacementQuantity: Decimal;
        TotalReplacementQuantity: Decimal;
    begin
        CarrierProdOrderLine.Get(
            FirstPNEPILTarget."Carrier Status",
            FirstPNEPILTarget."Carrier Production Order No.",
            FirstPNEPILTarget."Carrier Order Line No.");
        SetCALCTargetGroupFilter(PNEPILTarget, FirstPNEPILTarget);

        GetAndCheckCALCSourceIdentity(FirstPNEPILTarget, SourceCALCProdOrderComponent);
        FindComponentInCarrierTree(
            CarrierProdOrderLine,
            FirstPNEPILTarget."CALC Item No.",
            FoundCALCProdOrderComponent,
            FoundCount);
        if (FoundCount <> 1) or (FoundCALCProdOrderComponent.SystemId <> FirstPNEPILTarget."Source CALC SystemId") then
            Error(CALCSourceChangedErr, FirstPNEPILTarget."CALC Item No.", CarrierProdOrderLine."Item No.");
        CheckComponentSafety(SourceCALCProdOrderComponent);
        if Abs(SourceCALCProdOrderComponent."Quantity per" - FirstPNEPILTarget."Source CALC Quantity per") > QuantityTolerance() then
            Error(CALCSourceChangedErr, FirstPNEPILTarget."CALC Item No.", CarrierProdOrderLine."Item No.");

        if PNEPILTarget.FindSet() then
            repeat
                FindComponentInCarrierTree(
                    CarrierProdOrderLine,
                    PNEPILTarget."PIL Item No.",
                    ExistingActualProdOrderComponent,
                    FoundCount);
                if FoundCount > 1 then
                    Error(
                        ActualPILComponentAlreadyExistsErr,
                        PNEPILTarget."PIL Item No.",
                        CarrierProdOrderLine."Item No.",
                        FoundCount);
                Clear(ExistingActualQuantity);
                if FoundCount = 1 then
                    ExistingActualQuantity := ExistingActualProdOrderComponent."Expected Quantity";
                DesiredActualQuantity :=
                    PNEPILTarget."Existing Actual PIL Quantity" +
                    PNEPILTarget."Allocated PIL Quantity";
                ReplacementQuantity := DesiredActualQuantity - ExistingActualQuantity;
                if ReplacementQuantity > QuantityTolerance() then
                    TotalReplacementQuantity += ReplacementQuantity
                else
                    if ReplacementQuantity < -QuantityTolerance() then
                        ReleasedActualQuantity += -ReplacementQuantity;
            until PNEPILTarget.Next() = 0;

        AvailableCALCQuantity :=
            SourceCALCProdOrderComponent."Expected Quantity" +
            ReleasedActualQuantity;
        if TotalReplacementQuantity > AvailableCALCQuantity + QuantityTolerance() then
            Error(CALCQuantityMismatchErr, FirstPNEPILTarget."CALC Item No.", CarrierProdOrderLine."Item No.");
        RemainingCALCQuantity := AvailableCALCQuantity - TotalReplacementQuantity;
        if Abs(RemainingCALCQuantity) <= QuantityTolerance() then
            RemainingCALCQuantity := 0;

        SourceCALCProdOrderLine.Get(
            SourceCALCProdOrderComponent.Status,
            SourceCALCProdOrderComponent."Prod. Order No.",
            SourceCALCProdOrderComponent."Prod. Order Line No.");
        if SourceCALCProdOrderLine.Quantity <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, SourceCALCProdOrderLine."Item No.");
        NextLineNo := GetNextComponentLineNo(SourceCALCProdOrderComponent);
        if PNEPILTarget.FindSet() then
            repeat
                FindComponentInCarrierTree(
                    CarrierProdOrderLine,
                    PNEPILTarget."PIL Item No.",
                    ExistingActualProdOrderComponent,
                    FoundCount);
                Clear(ExistingActualQuantity);
                if FoundCount = 1 then
                    ExistingActualQuantity := ExistingActualProdOrderComponent."Expected Quantity";
                DesiredActualQuantity :=
                    PNEPILTarget."Existing Actual PIL Quantity" +
                    PNEPILTarget."Allocated PIL Quantity";
                ReplacementQuantity := DesiredActualQuantity - ExistingActualQuantity;
                if Abs(ReplacementQuantity) > QuantityTolerance() then
                    if FoundCount = 1 then begin
                        CheckComponentSafety(ExistingActualProdOrderComponent);
                        ExistingActualProdOrderLine.Get(
                            ExistingActualProdOrderComponent.Status,
                            ExistingActualProdOrderComponent."Prod. Order No.",
                            ExistingActualProdOrderComponent."Prod. Order Line No.");
                        if ExistingActualProdOrderLine.Quantity <= QuantityTolerance() then
                            Error(ZeroCarrierQuantityErr, ExistingActualProdOrderLine."Item No.");
                        NewQuantityPer :=
                            DesiredActualQuantity /
                            ExistingActualProdOrderLine.Quantity;
                        ExistingActualProdOrderComponent.Validate("Quantity per", NewQuantityPer);
                        if Abs(
                             ExistingActualProdOrderComponent."Expected Quantity" -
                             DesiredActualQuantity) > QuantityTolerance()
                        then
                            Error(ReplacementQuantityMismatchErr, PNEPILTarget."PIL Item No.");
                        ExistingActualProdOrderComponent.Modify(true);
                    end else begin
                        if DesiredActualQuantity <= QuantityTolerance() then
                            Error(ReplacementQuantityMismatchErr, PNEPILTarget."PIL Item No.");
                        NewProdOrderComponent := SourceCALCProdOrderComponent;
                        NextLineNo += 10000;
                        NewProdOrderComponent."Line No." := NextLineNo;
                        NewProdOrderComponent.Validate("Item No.", PNEPILTarget."PIL Item No.");
                        NewQuantityPer := DesiredActualQuantity / SourceCALCProdOrderLine.Quantity;
                        NewProdOrderComponent.Validate("Quantity per", NewQuantityPer);
                        if Abs(
                             NewProdOrderComponent."Expected Quantity" -
                             DesiredActualQuantity) > QuantityTolerance()
                        then
                            Error(ReplacementQuantityMismatchErr, PNEPILTarget."PIL Item No.");
                        NewProdOrderComponent.Insert(true);
                    end;
            until PNEPILTarget.Next() = 0;
        NewQuantityPer := RemainingCALCQuantity / SourceCALCProdOrderLine.Quantity;
        SourceCALCProdOrderComponent.Validate("Quantity per", NewQuantityPer);
        if Abs(SourceCALCProdOrderComponent."Expected Quantity" - RemainingCALCQuantity) > QuantityTolerance() then
            Error(ReplacementQuantityMismatchErr, SourceCALCProdOrderComponent."Item No.");
        SourceCALCProdOrderComponent.Modify(true);
    end;

    local procedure CaptureRoutingHourSnapshot(PNEPILHeader: Record "PNE PIL Header"; var TempRoutingOwnerProdOrderLine: Record "Prod. Order Line" temporary; var RoutingHoursBefore: Dictionary of [Text, Decimal]; var CapacityUnitOfMeasureCode: Code[10])
    var
        ManufacturingSetup: Record "Manufacturing Setup";
        OrderLevelRoutingOwnerProdOrderLine: Record "Prod. Order Line";
        TempAffectedProdOrderLine: Record "Prod. Order Line" temporary;
        TempComponentOwnerProdOrderLine: Record "Prod. Order Line" temporary;
        CachedRoutingBOMs: Dictionary of [Text, Boolean];
        CapacityUnitOfMeasureCache: Dictionary of [Code[10], Boolean];
        NonInventoryItemCache: Dictionary of [Code[20], Boolean];
        RoutingBOMContributionCache: Dictionary of [Text, Decimal];
        RoutingBOMUnitOfMeasureCache: Dictionary of [Text, Code[10]];
    begin
        if FindOrderLevelRoutingOwnerForOrder(
             PNEPILHeader."Production Order Status",
             PNEPILHeader."Production Order No.",
             OrderLevelRoutingOwnerProdOrderLine)
        then begin
            TempRoutingOwnerProdOrderLine := OrderLevelRoutingOwnerProdOrderLine;
            TempRoutingOwnerProdOrderLine.Insert();
        end else begin
            CollectAffectedProductionOrderLinesForHeader(PNEPILHeader, TempAffectedProdOrderLine);
            if TempAffectedProdOrderLine.FindSet() then
                repeat
                    if HasLiveProductionOrderRouting(TempAffectedProdOrderLine) then
                        if not TempRoutingOwnerProdOrderLine.Get(
                            TempAffectedProdOrderLine.Status,
                            TempAffectedProdOrderLine."Prod. Order No.",
                            TempAffectedProdOrderLine."Line No.")
                        then begin
                            TempRoutingOwnerProdOrderLine := TempAffectedProdOrderLine;
                            TempRoutingOwnerProdOrderLine.Insert();
                        end;
                until TempAffectedProdOrderLine.Next() = 0;

            AddUniqueRoutingOwnerForOrder(
                PNEPILHeader."Production Order Status",
                PNEPILHeader."Production Order No.",
                TempRoutingOwnerProdOrderLine);
        end;

        if TempRoutingOwnerProdOrderLine.IsEmpty() then
            exit;
        ManufacturingSetup.Get();
        ManufacturingSetup.TestField("Show Capacity In");
        CapacityUnitOfMeasureCode := ManufacturingSetup."Show Capacity In";
        GetCapacityTimeFactor(CapacityUnitOfMeasureCode);

        TempRoutingOwnerProdOrderLine.Reset();
        if TempRoutingOwnerProdOrderLine.FindSet() then
            repeat
                CollectRoutingHoursPerOutputCached(
                    TempRoutingOwnerProdOrderLine,
                    CapacityUnitOfMeasureCode,
                    RoutingHoursBefore,
                    NonInventoryItemCache,
                    CapacityUnitOfMeasureCache,
                    TempComponentOwnerProdOrderLine,
                    CachedRoutingBOMs,
                    RoutingBOMContributionCache,
                    RoutingBOMUnitOfMeasureCache);
            until TempRoutingOwnerProdOrderLine.Next() = 0;
    end;

    local procedure ApplyRoutingHourChanges(var TempRoutingOwnerProdOrderLine: Record "Prod. Order Line" temporary; RoutingHoursBefore: Dictionary of [Text, Decimal]; CapacityUnitOfMeasureCode: Code[10]; var RoutingImpactSummary: Text)
    var
        CurrentRoutingOwnerProdOrderLine: Record "Prod. Order Line";
        TempComponentOwnerProdOrderLine: Record "Prod. Order Line" temporary;
        CachedRoutingBOMs: Dictionary of [Text, Boolean];
        CapacityUnitOfMeasureCache: Dictionary of [Code[10], Boolean];
        NonInventoryItemCache: Dictionary of [Code[20], Boolean];
        RoutingBOMContributionCache: Dictionary of [Text, Decimal];
        RoutingBOMUnitOfMeasureCache: Dictionary of [Text, Code[10]];
        RoutingHoursAfter: Dictionary of [Text, Decimal];
    begin
        if TempRoutingOwnerProdOrderLine.IsEmpty() then
            exit;

        TempRoutingOwnerProdOrderLine.Reset();
        if TempRoutingOwnerProdOrderLine.FindSet() then
            repeat
                CurrentRoutingOwnerProdOrderLine.Get(
                    TempRoutingOwnerProdOrderLine.Status,
                    TempRoutingOwnerProdOrderLine."Prod. Order No.",
                    TempRoutingOwnerProdOrderLine."Line No.");
                CollectRoutingHoursPerOutputCached(
                    CurrentRoutingOwnerProdOrderLine,
                    CapacityUnitOfMeasureCode,
                    RoutingHoursAfter,
                    NonInventoryItemCache,
                    CapacityUnitOfMeasureCache,
                    TempComponentOwnerProdOrderLine,
                    CachedRoutingBOMs,
                    RoutingBOMContributionCache,
                    RoutingBOMUnitOfMeasureCache);
                ApplyRoutingHourChangesForOwner(
                    CurrentRoutingOwnerProdOrderLine,
                    RoutingHoursBefore,
                    RoutingHoursAfter,
                    CapacityUnitOfMeasureCode,
                    true,
                    RoutingImpactSummary);
            until TempRoutingOwnerProdOrderLine.Next() = 0;
        if RoutingImpactSummary = '' then
            RoutingImpactSummary := NoRoutingHourAdjustmentTxt;
    end;

    local procedure CollectRoutingHoursPerOutput(RoutingOwnerProdOrderLine: Record "Prod. Order Line"; CapacityUnitOfMeasureCode: Code[10]; var RoutingHours: Dictionary of [Text, Decimal])
    var
        TempComponentOwnerProdOrderLine: Record "Prod. Order Line" temporary;
        CachedRoutingBOMs: Dictionary of [Text, Boolean];
        CapacityUnitOfMeasureCache: Dictionary of [Code[10], Boolean];
        NonInventoryItemCache: Dictionary of [Code[20], Boolean];
        RoutingBOMContributionCache: Dictionary of [Text, Decimal];
        RoutingBOMUnitOfMeasureCache: Dictionary of [Text, Code[10]];
    begin
        CollectRoutingHoursPerOutputCached(
            RoutingOwnerProdOrderLine,
            CapacityUnitOfMeasureCode,
            RoutingHours,
            NonInventoryItemCache,
            CapacityUnitOfMeasureCache,
            TempComponentOwnerProdOrderLine,
            CachedRoutingBOMs,
            RoutingBOMContributionCache,
            RoutingBOMUnitOfMeasureCache);
    end;

    local procedure CollectRoutingHoursPerOutputCached(RoutingOwnerProdOrderLine: Record "Prod. Order Line"; CapacityUnitOfMeasureCode: Code[10]; var RoutingHours: Dictionary of [Text, Decimal]; var NonInventoryItemCache: Dictionary of [Code[20], Boolean]; var CapacityUnitOfMeasureCache: Dictionary of [Code[10], Boolean]; var TempComponentOwnerProdOrderLine: Record "Prod. Order Line" temporary; var CachedRoutingBOMs: Dictionary of [Text, Boolean]; var RoutingBOMContributionCache: Dictionary of [Text, Decimal]; var RoutingBOMUnitOfMeasureCache: Dictionary of [Text, Code[10]])
    var
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
        RoutingHourTotals: Dictionary of [Text, Decimal];
        RoutingHourKeys: List of [Text];
        RoutingHourKey: Text;
        TotalQuantity: Decimal;
    begin
        if RoutingOwnerProdOrderLine.Quantity <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, RoutingOwnerProdOrderLine."Item No.");

        if IsOrderLevelRoutingOwnerForOrder(RoutingOwnerProdOrderLine) or
           IsUniqueRoutingOwnerForOrder(RoutingOwnerProdOrderLine)
        then
            CollectRoutingHourTotalsInOrder(
                RoutingOwnerProdOrderLine,
                CapacityUnitOfMeasureCode,
                RoutingHourTotals,
                NonInventoryItemCache,
                CapacityUnitOfMeasureCache,
                TempComponentOwnerProdOrderLine,
                CachedRoutingBOMs,
                RoutingBOMContributionCache,
                RoutingBOMUnitOfMeasureCache)
        else
            CollectRoutingHourTotalsInTree(
                RoutingOwnerProdOrderLine,
                RoutingOwnerProdOrderLine,
                CapacityUnitOfMeasureCode,
                RoutingHourTotals,
                TempVisitedProdOrderLine,
                NonInventoryItemCache,
                CapacityUnitOfMeasureCache,
                CachedRoutingBOMs,
                RoutingBOMContributionCache,
                RoutingBOMUnitOfMeasureCache);
        RoutingHourKeys := RoutingHourTotals.Keys();
        foreach RoutingHourKey in RoutingHourKeys do begin
            RoutingHourTotals.Get(RoutingHourKey, TotalQuantity);
            SetDecimalDictionaryValue(
                RoutingHours,
                GetRoutingHourOwnerPrefix(RoutingOwnerProdOrderLine) + RoutingHourKey,
                TotalQuantity / RoutingOwnerProdOrderLine.Quantity);
        end;
    end;

    local procedure AddUniqueRoutingOwnerForOrder(ProductionOrderStatus: Enum "Production Order Status"; ProductionOrderNo: Code[20]; var TempRoutingOwnerProdOrderLine: Record "Prod. Order Line" temporary)
    var
        CandidateProdOrderLine: Record "Prod. Order Line";
        UniqueRoutingOwnerProdOrderLine: Record "Prod. Order Line";
        RoutingOwnerCount: Integer;
    begin
        CandidateProdOrderLine.SetRange(Status, ProductionOrderStatus);
        CandidateProdOrderLine.SetRange("Prod. Order No.", ProductionOrderNo);
        if CandidateProdOrderLine.FindSet() then
            repeat
                if HasLiveProductionOrderRouting(CandidateProdOrderLine) then begin
                    RoutingOwnerCount += 1;
                    if RoutingOwnerCount > 1 then
                        exit;
                    UniqueRoutingOwnerProdOrderLine := CandidateProdOrderLine;
                end;
            until CandidateProdOrderLine.Next() = 0;

        if RoutingOwnerCount <> 1 then
            exit;
        if TempRoutingOwnerProdOrderLine.Get(
             UniqueRoutingOwnerProdOrderLine.Status,
             UniqueRoutingOwnerProdOrderLine."Prod. Order No.",
             UniqueRoutingOwnerProdOrderLine."Line No.")
        then
            exit;
        TempRoutingOwnerProdOrderLine := UniqueRoutingOwnerProdOrderLine;
        TempRoutingOwnerProdOrderLine.Insert();
    end;

    local procedure IsUniqueRoutingOwnerForOrder(RoutingOwnerProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        CandidateProdOrderLine: Record "Prod. Order Line";
        UniqueRoutingOwnerProdOrderLine: Record "Prod. Order Line";
        RoutingOwnerCount: Integer;
    begin
        CandidateProdOrderLine.SetRange(Status, RoutingOwnerProdOrderLine.Status);
        CandidateProdOrderLine.SetRange("Prod. Order No.", RoutingOwnerProdOrderLine."Prod. Order No.");
        if CandidateProdOrderLine.FindSet() then
            repeat
                if HasLiveProductionOrderRouting(CandidateProdOrderLine) then begin
                    RoutingOwnerCount += 1;
                    if RoutingOwnerCount > 1 then
                        exit(false);
                    UniqueRoutingOwnerProdOrderLine := CandidateProdOrderLine;
                end;
            until CandidateProdOrderLine.Next() = 0;

        exit(
            (RoutingOwnerCount = 1) and
            IsSameProdOrderLine(UniqueRoutingOwnerProdOrderLine, RoutingOwnerProdOrderLine));
    end;

    local procedure FindOrderLevelRoutingOwnerForOrder(ProductionOrderStatus: Enum "Production Order Status"; ProductionOrderNo: Code[20]; var OrderLevelRoutingOwnerProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        CandidateProdOrderLine: Record "Prod. Order Line";
        ProductionOrder: Record "Production Order";
        RoutingOwnerCount: Integer;
    begin
        Clear(OrderLevelRoutingOwnerProdOrderLine);
        if ProductionOrder.Get(ProductionOrderStatus, ProductionOrderNo) and
           (ProductionOrder."Source No." <> '')
        then begin
            CandidateProdOrderLine.SetRange(Status, ProductionOrderStatus);
            CandidateProdOrderLine.SetRange("Prod. Order No.", ProductionOrderNo);
            CandidateProdOrderLine.SetRange("Item No.", ProductionOrder."Source No.");
            if CandidateProdOrderLine.FindSet() then
                repeat
                    if HasLiveProductionOrderRouting(CandidateProdOrderLine) then begin
                        RoutingOwnerCount += 1;
                        OrderLevelRoutingOwnerProdOrderLine := CandidateProdOrderLine;
                    end;
                until CandidateProdOrderLine.Next() = 0;
            if RoutingOwnerCount = 1 then
                exit(true);
        end;

        Clear(OrderLevelRoutingOwnerProdOrderLine);
        Clear(RoutingOwnerCount);
        CandidateProdOrderLine.Reset();
        CandidateProdOrderLine.SetRange(Status, ProductionOrderStatus);
        CandidateProdOrderLine.SetRange("Prod. Order No.", ProductionOrderNo);
        if CandidateProdOrderLine.FindSet() then
            repeat
                if HasLiveProductionOrderRouting(CandidateProdOrderLine) and
                   not IsInternallySuppliedProductionOrderLine(CandidateProdOrderLine)
                then begin
                    RoutingOwnerCount += 1;
                    if RoutingOwnerCount > 1 then
                        exit(false);
                    OrderLevelRoutingOwnerProdOrderLine := CandidateProdOrderLine;
                end;
            until CandidateProdOrderLine.Next() = 0;
        exit(RoutingOwnerCount = 1);
    end;

    local procedure IsInternallySuppliedProductionOrderLine(ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        ParentProdOrderComponent: Record "Prod. Order Component";
    begin
        ParentProdOrderComponent.SetRange(Status, ProdOrderLine.Status);
        ParentProdOrderComponent.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        ParentProdOrderComponent.SetRange("Supplied-by Line No.", ProdOrderLine."Line No.");
        exit(not ParentProdOrderComponent.IsEmpty());
    end;

    local procedure IsOrderLevelRoutingOwnerForOrder(RoutingOwnerProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        OrderLevelRoutingOwnerProdOrderLine: Record "Prod. Order Line";
    begin
        if not FindOrderLevelRoutingOwnerForOrder(
             RoutingOwnerProdOrderLine.Status,
             RoutingOwnerProdOrderLine."Prod. Order No.",
             OrderLevelRoutingOwnerProdOrderLine)
        then
            exit(false);
        exit(IsSameProdOrderLine(OrderLevelRoutingOwnerProdOrderLine, RoutingOwnerProdOrderLine));
    end;

    local procedure CollectRoutingHourTotalsInOrder(RoutingOwnerProdOrderLine: Record "Prod. Order Line"; CapacityUnitOfMeasureCode: Code[10]; var RoutingHourTotals: Dictionary of [Text, Decimal]; var NonInventoryItemCache: Dictionary of [Code[20], Boolean]; var CapacityUnitOfMeasureCache: Dictionary of [Code[10], Boolean]; var TempComponentOwnerProdOrderLine: Record "Prod. Order Line" temporary; var CachedRoutingBOMs: Dictionary of [Text, Boolean]; var RoutingBOMContributionCache: Dictionary of [Text, Decimal]; var RoutingBOMUnitOfMeasureCache: Dictionary of [Text, Code[10]])
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ComponentOwnerProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
        CurrentTotal: Decimal;
    begin
        ProdOrderComponent.SetRange(Status, RoutingOwnerProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", RoutingOwnerProdOrderLine."Prod. Order No.");
        if ProdOrderComponent.FindSet() then
            repeat
                GetCachedComponentOwnerProdOrderLine(
                    ProdOrderComponent,
                    TempComponentOwnerProdOrderLine,
                    ComponentOwnerProdOrderLine);
                if (ProdOrderComponent."Routing Link Code" <> '') and
                   IsNonInventoryItem(ProdOrderComponent."Item No.", NonInventoryItemCache) and
                   IsCapacityUnitOfMeasureCached(ProdOrderComponent."Unit of Measure Code", CapacityUnitOfMeasureCache)
                then begin
                    CurrentTotal := GetDecimalDictionaryValue(
                        RoutingHourTotals,
                        ProdOrderComponent."Routing Link Code");
                    SetDecimalDictionaryValue(
                        RoutingHourTotals,
                        ProdOrderComponent."Routing Link Code",
                        CurrentTotal + ConvertCapacityQuantity(
                            ProdOrderComponent."Quantity per" * ComponentOwnerProdOrderLine.Quantity,
                            ProdOrderComponent."Unit of Measure Code",
                            CapacityUnitOfMeasureCode));
                end;
                if not FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                    CollectRoutingHourTotalsFromUnexpandedComponent(
                        RoutingOwnerProdOrderLine,
                        ComponentOwnerProdOrderLine,
                        ProdOrderComponent,
                        CapacityUnitOfMeasureCode,
                        RoutingHourTotals,
                        NonInventoryItemCache,
                        CapacityUnitOfMeasureCache,
                        CachedRoutingBOMs,
                        RoutingBOMContributionCache,
                        RoutingBOMUnitOfMeasureCache);
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure CollectRoutingHourTotalsInTree(RoutingOwnerProdOrderLine: Record "Prod. Order Line"; CurrentProdOrderLine: Record "Prod. Order Line"; CapacityUnitOfMeasureCode: Code[10]; var RoutingHourTotals: Dictionary of [Text, Decimal]; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary; var NonInventoryItemCache: Dictionary of [Code[20], Boolean]; var CapacityUnitOfMeasureCache: Dictionary of [Code[10], Boolean]; var CachedRoutingBOMs: Dictionary of [Text, Boolean]; var RoutingBOMContributionCache: Dictionary of [Text, Decimal]; var RoutingBOMUnitOfMeasureCache: Dictionary of [Text, Code[10]])
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
        CurrentTotal: Decimal;
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if (ProdOrderComponent."Routing Link Code" <> '') and
                   IsNonInventoryItem(ProdOrderComponent."Item No.", NonInventoryItemCache) and
                   IsCapacityUnitOfMeasureCached(ProdOrderComponent."Unit of Measure Code", CapacityUnitOfMeasureCache)
                then begin
                    CurrentTotal := GetDecimalDictionaryValue(
                        RoutingHourTotals,
                        ProdOrderComponent."Routing Link Code");
                    SetDecimalDictionaryValue(
                        RoutingHourTotals,
                        ProdOrderComponent."Routing Link Code",
                        CurrentTotal + ConvertCapacityQuantity(
                            ProdOrderComponent."Quantity per" * CurrentProdOrderLine.Quantity,
                            ProdOrderComponent."Unit of Measure Code",
                            CapacityUnitOfMeasureCode));
                end;

                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then begin
                    if IsSameProdOrderLine(ChildProdOrderLine, RoutingOwnerProdOrderLine) or
                       not HasLiveProductionOrderRouting(ChildProdOrderLine)
                    then
                        CollectRoutingHourTotalsInTree(
                            RoutingOwnerProdOrderLine,
                            ChildProdOrderLine,
                            CapacityUnitOfMeasureCode,
                            RoutingHourTotals,
                            TempVisitedProdOrderLine,
                            NonInventoryItemCache,
                            CapacityUnitOfMeasureCache,
                            CachedRoutingBOMs,
                            RoutingBOMContributionCache,
                            RoutingBOMUnitOfMeasureCache);
                end else
                    CollectRoutingHourTotalsFromUnexpandedComponent(
                        RoutingOwnerProdOrderLine,
                        CurrentProdOrderLine,
                        ProdOrderComponent,
                        CapacityUnitOfMeasureCode,
                        RoutingHourTotals,
                        NonInventoryItemCache,
                        CapacityUnitOfMeasureCache,
                        CachedRoutingBOMs,
                        RoutingBOMContributionCache,
                        RoutingBOMUnitOfMeasureCache);
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure CollectRoutingHourTotalsFromUnexpandedComponent(RoutingOwnerProdOrderLine: Record "Prod. Order Line"; ComponentOwnerProdOrderLine: Record "Prod. Order Line"; ProdOrderComponent: Record "Prod. Order Component"; CapacityUnitOfMeasureCode: Code[10]; var RoutingHourTotals: Dictionary of [Text, Decimal]; var NonInventoryItemCache: Dictionary of [Code[20], Boolean]; var CapacityUnitOfMeasureCache: Dictionary of [Code[10], Boolean]; var CachedRoutingBOMs: Dictionary of [Text, Boolean]; var RoutingBOMContributionCache: Dictionary of [Text, Decimal]; var RoutingBOMUnitOfMeasureCache: Dictionary of [Text, Code[10]])
    var
        BOMUnitOfMeasureCode: Code[10];
        RoutingBOMCacheKey: Text;
        CalculationDate: Date;
        ComponentQuantityPerOutput: Decimal;
        ProductionBOMNo: Code[20];
    begin
        ProductionBOMNo := GetProductionBOMNoForComponent(ProdOrderComponent);
        if ProductionBOMNo = '' then
            exit;

        CalculationDate := GetCarrierCalculationDate(ComponentOwnerProdOrderLine);
        RoutingBOMCacheKey := GetRoutingBOMCacheKey(
            ProductionBOMNo,
            CalculationDate,
            CapacityUnitOfMeasureCode);
        BOMUnitOfMeasureCode := GetCachedRoutingBOMUnitOfMeasure(
            RoutingBOMCacheKey,
            ProductionBOMNo,
            CalculationDate,
            RoutingBOMUnitOfMeasureCache);
        ComponentQuantityPerOutput :=
            ProdOrderComponent."Quantity per" *
            ComponentOwnerProdOrderLine.Quantity /
            RoutingOwnerProdOrderLine.Quantity;
        ComponentQuantityPerOutput :=
            ConvertItemQuantityBetweenUnits(
                ProdOrderComponent."Item No.",
                ComponentQuantityPerOutput,
                ProdOrderComponent."Unit of Measure Code",
                BOMUnitOfMeasureCode);
        EnsureRoutingBOMContributionCached(
            RoutingBOMCacheKey,
            ProductionBOMNo,
            CalculationDate,
            CapacityUnitOfMeasureCode,
            NonInventoryItemCache,
            CapacityUnitOfMeasureCache,
            CachedRoutingBOMs,
            RoutingBOMContributionCache);
        AddCachedRoutingBOMContribution(
            RoutingBOMCacheKey,
            ComponentQuantityPerOutput,
            RoutingBOMContributionCache,
            RoutingHourTotals);
    end;

    local procedure GetCachedComponentOwnerProdOrderLine(ProdOrderComponent: Record "Prod. Order Component"; var TempComponentOwnerProdOrderLine: Record "Prod. Order Line" temporary; var ComponentOwnerProdOrderLine: Record "Prod. Order Line")
    begin
        if TempComponentOwnerProdOrderLine.Get(
             ProdOrderComponent.Status,
             ProdOrderComponent."Prod. Order No.",
             ProdOrderComponent."Prod. Order Line No.")
        then begin
            ComponentOwnerProdOrderLine := TempComponentOwnerProdOrderLine;
            exit;
        end;

        ComponentOwnerProdOrderLine.Get(
            ProdOrderComponent.Status,
            ProdOrderComponent."Prod. Order No.",
            ProdOrderComponent."Prod. Order Line No.");
        TempComponentOwnerProdOrderLine := ComponentOwnerProdOrderLine;
        TempComponentOwnerProdOrderLine.Insert();
    end;

    local procedure GetCachedRoutingBOMUnitOfMeasure(RoutingBOMCacheKey: Text; ProductionBOMNo: Code[20]; CalculationDate: Date; var RoutingBOMUnitOfMeasureCache: Dictionary of [Text, Code[10]]): Code[10]
    var
        BOMUnitOfMeasureCode: Code[10];
    begin
        if RoutingBOMUnitOfMeasureCache.Get(RoutingBOMCacheKey, BOMUnitOfMeasureCode) then
            exit(BOMUnitOfMeasureCode);
        BOMUnitOfMeasureCode :=
            GetProductionBOMUnitOfMeasure(
                ProductionBOMNo,
                '',
                false,
                CalculationDate);
        RoutingBOMUnitOfMeasureCache.Add(RoutingBOMCacheKey, BOMUnitOfMeasureCode);
        exit(BOMUnitOfMeasureCode);
    end;

    local procedure EnsureRoutingBOMContributionCached(RoutingBOMCacheKey: Text; ProductionBOMNo: Code[20]; CalculationDate: Date; CapacityUnitOfMeasureCode: Code[10]; var NonInventoryItemCache: Dictionary of [Code[20], Boolean]; var CapacityUnitOfMeasureCache: Dictionary of [Code[10], Boolean]; var CachedRoutingBOMs: Dictionary of [Text, Boolean]; var RoutingBOMContributionCache: Dictionary of [Text, Decimal])
    var
        BOMPath: List of [Code[20]];
        PerUnitRoutingHourTotals: Dictionary of [Text, Decimal];
        RoutingLinkCodes: List of [Text];
        RoutingLinkCode: Text;
        RoutingQuantity: Decimal;
    begin
        if CachedRoutingBOMs.ContainsKey(RoutingBOMCacheKey) then
            exit;

        CollectRoutingHourTotalsInProductionBOM(
            ProductionBOMNo,
            CalculationDate,
            1,
            CapacityUnitOfMeasureCode,
            PerUnitRoutingHourTotals,
            BOMPath,
            NonInventoryItemCache,
            CapacityUnitOfMeasureCache);
        RoutingLinkCodes := PerUnitRoutingHourTotals.Keys();
        foreach RoutingLinkCode in RoutingLinkCodes do begin
            PerUnitRoutingHourTotals.Get(RoutingLinkCode, RoutingQuantity);
            RoutingBOMContributionCache.Add(
                RoutingBOMCacheKey + '|' + RoutingLinkCode,
                RoutingQuantity);
        end;
        CachedRoutingBOMs.Add(RoutingBOMCacheKey, true);
    end;

    local procedure AddCachedRoutingBOMContribution(RoutingBOMCacheKey: Text; ComponentQuantityPerOutput: Decimal; RoutingBOMContributionCache: Dictionary of [Text, Decimal]; var RoutingHourTotals: Dictionary of [Text, Decimal])
    var
        RoutingContributionKeys: List of [Text];
        RoutingContributionKey: Text;
        RoutingContributionPrefix: Text;
        RoutingLinkCode: Text;
        CurrentTotal: Decimal;
        RoutingQuantity: Decimal;
    begin
        RoutingContributionPrefix := RoutingBOMCacheKey + '|';
        RoutingContributionKeys := RoutingBOMContributionCache.Keys();
        foreach RoutingContributionKey in RoutingContributionKeys do
            if CopyStr(RoutingContributionKey, 1, StrLen(RoutingContributionPrefix)) = RoutingContributionPrefix then begin
                RoutingLinkCode := CopyStr(
                    RoutingContributionKey,
                    StrLen(RoutingContributionPrefix) + 1);
                RoutingBOMContributionCache.Get(RoutingContributionKey, RoutingQuantity);
                CurrentTotal := GetDecimalDictionaryValue(RoutingHourTotals, RoutingLinkCode);
                SetDecimalDictionaryValue(
                    RoutingHourTotals,
                    RoutingLinkCode,
                    CurrentTotal + (RoutingQuantity * ComponentQuantityPerOutput));
            end;
    end;

    local procedure GetRoutingBOMCacheKey(ProductionBOMNo: Code[20]; CalculationDate: Date; CapacityUnitOfMeasureCode: Code[10]): Text
    begin
        exit(
            ProductionBOMNo + '|' +
            Format(CalculationDate, 0, 9) + '|' +
            CapacityUnitOfMeasureCode);
    end;

    local procedure CollectRoutingHourTotalsInProductionBOM(ProductionBOMNo: Code[20]; CalculationDate: Date; ParentQuantityPerOutput: Decimal; CapacityUnitOfMeasureCode: Code[10]; var RoutingHourTotals: Dictionary of [Text, Decimal]; var BOMPath: List of [Code[20]]; var NonInventoryItemCache: Dictionary of [Code[20], Boolean]; var CapacityUnitOfMeasureCache: Dictionary of [Code[10], Boolean])
    var
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
        ChildQuantityPerOutput: Decimal;
        CurrentTotal: Decimal;
    begin
        if ProductionBOMNo = '' then
            exit;
        if BOMPath.Contains(ProductionBOMNo) then
            Error(CircularProductionBOMErr, ProductionBOMNo);
        if BOMPath.Count() >= MaximumProductionBOMDepth() then
            Error(ProductionBOMTooDeepErr, ProductionBOMNo);
        BOMPath.Add(ProductionBOMNo);

        SetActiveProductionBOMLineFilters(ProductionBOMNo, CalculationDate, '', false, ProductionBOMLine);
        if ProductionBOMLine.FindSet() then
            repeat
                if (ProductionBOMLine."Scrap %" <> 0) or
                   (ProductionBOMLine."Calculation Formula" = ProductionBOMLine."Calculation Formula"::"Fixed Quantity")
                then
                    Error(
                        UnsupportedHiddenRoutingBOMLineErr,
                        ProductionBOMLine."Production BOM No.",
                        ProductionBOMLine."No.");

                ChildQuantityPerOutput := ParentQuantityPerOutput * ProductionBOMLine.Quantity;
                if (ProductionBOMLine.Type = ProductionBOMLine.Type::Item) and
                   (ProductionBOMLine."Routing Link Code" <> '') and
                   IsNonInventoryItem(ProductionBOMLine."No.", NonInventoryItemCache) and
                   IsCapacityUnitOfMeasureCached(ProductionBOMLine."Unit of Measure Code", CapacityUnitOfMeasureCache)
                then begin
                    CurrentTotal := GetDecimalDictionaryValue(
                        RoutingHourTotals,
                        ProductionBOMLine."Routing Link Code");
                    SetDecimalDictionaryValue(
                        RoutingHourTotals,
                        ProductionBOMLine."Routing Link Code",
                        CurrentTotal + ConvertCapacityQuantity(
                            ChildQuantityPerOutput,
                            ProductionBOMLine."Unit of Measure Code",
                            CapacityUnitOfMeasureCode));
                end;

                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if ChildProductionBOMNo <> '' then begin
                    if ProductionBOMLine.Type = ProductionBOMLine.Type::Item then
                        ChildQuantityPerOutput :=
                            ConvertItemQuantityBetweenUnits(
                                ProductionBOMLine."No.",
                                ChildQuantityPerOutput,
                                ProductionBOMLine."Unit of Measure Code",
                                GetProductionBOMUnitOfMeasure(
                                    ChildProductionBOMNo,
                                    '',
                                    false,
                                    CalculationDate))
                    else
                        if ProductionBOMLine."Unit of Measure Code" <>
                           GetProductionBOMUnitOfMeasure(
                             ChildProductionBOMNo,
                             '',
                             false,
                             CalculationDate)
                        then
                            Error(
                                UnsupportedBOMUnitOfMeasureErr,
                                ChildProductionBOMNo,
                                ProductionBOMLine."Unit of Measure Code",
                                GetProductionBOMUnitOfMeasure(
                                    ChildProductionBOMNo,
                                    '',
                                    false,
                                    CalculationDate));
                    CollectRoutingHourTotalsInProductionBOM(
                        ChildProductionBOMNo,
                        CalculationDate,
                        ChildQuantityPerOutput,
                        CapacityUnitOfMeasureCode,
                        RoutingHourTotals,
                        BOMPath,
                        NonInventoryItemCache,
                        CapacityUnitOfMeasureCache);
                end;
            until ProductionBOMLine.Next() = 0;

        BOMPath.Remove(ProductionBOMNo);
    end;

    local procedure ConvertItemQuantityBetweenUnits(ItemNo: Code[20]; Quantity: Decimal; FromUnitOfMeasureCode: Code[10]; ToUnitOfMeasureCode: Code[10]): Decimal
    var
        Item: Record Item;
        UnitOfMeasureManagement: Codeunit "Unit of Measure Management";
    begin
        if FromUnitOfMeasureCode = ToUnitOfMeasureCode then
            exit(Quantity);
        Item.Get(ItemNo);
        exit(
            Quantity *
            UnitOfMeasureManagement.GetQtyPerUnitOfMeasure(Item, FromUnitOfMeasureCode) /
            UnitOfMeasureManagement.GetQtyPerUnitOfMeasure(Item, ToUnitOfMeasureCode));
    end;

    local procedure ApplyRoutingHourChangesForOwner(RoutingOwnerProdOrderLine: Record "Prod. Order Line"; RoutingHoursBefore: Dictionary of [Text, Decimal]; RoutingHoursAfter: Dictionary of [Text, Decimal]; CapacityUnitOfMeasureCode: Code[10]; AllowDecrease: Boolean; var RoutingImpactSummary: Text)
    var
        ProcessedRoutingLinks: Dictionary of [Code[10], Boolean];
        RoutingHourKey: Text;
        RoutingHourKeys: List of [Text];
        RoutingLinkCode: Code[10];
        OwnerPrefix: Text;
    begin
        OwnerPrefix := GetRoutingHourOwnerPrefix(RoutingOwnerProdOrderLine);
        RoutingHourKeys := RoutingHoursAfter.Keys();
        foreach RoutingHourKey in RoutingHourKeys do
            if CopyStr(RoutingHourKey, 1, StrLen(OwnerPrefix)) = OwnerPrefix then begin
                RoutingLinkCode := CopyStr(RoutingHourKey, StrLen(OwnerPrefix) + 1, MaxStrLen(RoutingLinkCode));
                ApplyRoutingHourChangeForLink(
                    RoutingOwnerProdOrderLine,
                    RoutingLinkCode,
                    RoutingHoursBefore,
                    RoutingHoursAfter,
                    CapacityUnitOfMeasureCode,
                    AllowDecrease,
                    RoutingImpactSummary);
                if not ProcessedRoutingLinks.ContainsKey(RoutingLinkCode) then
                    ProcessedRoutingLinks.Add(RoutingLinkCode, true);
            end;

        RoutingHourKeys := RoutingHoursBefore.Keys();
        foreach RoutingHourKey in RoutingHourKeys do
            if CopyStr(RoutingHourKey, 1, StrLen(OwnerPrefix)) = OwnerPrefix then begin
                RoutingLinkCode := CopyStr(RoutingHourKey, StrLen(OwnerPrefix) + 1, MaxStrLen(RoutingLinkCode));
                if not ProcessedRoutingLinks.ContainsKey(RoutingLinkCode) then
                    ApplyRoutingHourChangeForLink(
                        RoutingOwnerProdOrderLine,
                        RoutingLinkCode,
                        RoutingHoursBefore,
                        RoutingHoursAfter,
                        CapacityUnitOfMeasureCode,
                        AllowDecrease,
                        RoutingImpactSummary);
            end;
    end;

    local procedure CollectActiveRoutingLinksForOwner(RoutingOwnerProdOrderLine: Record "Prod. Order Line"; CapacityUnitOfMeasureCode: Code[10]; var RoutingLinks: Dictionary of [Text, Decimal])
    var
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
        LotSize: Decimal;
        CurrentQuantityPerOutput: Decimal;
    begin
        ProdOrderRoutingLine.SetRange(Status, RoutingOwnerProdOrderLine.Status);
        ProdOrderRoutingLine.SetRange("Prod. Order No.", RoutingOwnerProdOrderLine."Prod. Order No.");
        ProdOrderRoutingLine.SetRange("Routing Reference No.", RoutingOwnerProdOrderLine."Routing Reference No.");
        ProdOrderRoutingLine.SetRange("Routing No.", RoutingOwnerProdOrderLine."Routing No.");
        ProdOrderRoutingLine.SetFilter("Routing Link Code", '<>%1', '');
        ProdOrderRoutingLine.SetFilter("Run Time", '>%1', QuantityTolerance());
        if ProdOrderRoutingLine.FindSet() then
            repeat
                LotSize := ProdOrderRoutingLine."Lot Size";
                if LotSize = 0 then
                    LotSize := 1;
                CurrentQuantityPerOutput := ConvertCapacityQuantity(
                    ProdOrderRoutingLine."Run Time" / LotSize,
                    ProdOrderRoutingLine."Run Time Unit of Meas. Code",
                    CapacityUnitOfMeasureCode);
                SetDecimalDictionaryValue(
                    RoutingLinks,
                    GetRoutingHourOwnerPrefix(RoutingOwnerProdOrderLine) +
                    ProdOrderRoutingLine."Routing Link Code",
                    CurrentQuantityPerOutput);
            until ProdOrderRoutingLine.Next() = 0;
    end;

    local procedure ApplyRoutingHourChangeForLink(RoutingOwnerProdOrderLine: Record "Prod. Order Line"; RoutingLinkCode: Code[10]; RoutingHoursBefore: Dictionary of [Text, Decimal]; RoutingHoursAfter: Dictionary of [Text, Decimal]; CapacityUnitOfMeasureCode: Code[10]; AllowDecrease: Boolean; var RoutingImpactSummary: Text)
    var
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
        AfterQuantityPerOutput: Decimal;
        BeforeQuantityPerOutput: Decimal;
        CurrentQuantityPerOutput: Decimal;
        LotSize: Decimal;
        NewRunTime: Decimal;
        NewQuantityPerOutput: Decimal;
        RoutingHourKey: Text;
    begin
        RoutingHourKey := GetRoutingHourOwnerPrefix(RoutingOwnerProdOrderLine) + RoutingLinkCode;
        BeforeQuantityPerOutput := GetDecimalDictionaryValue(RoutingHoursBefore, RoutingHourKey);
        AfterQuantityPerOutput := GetDecimalDictionaryValue(RoutingHoursAfter, RoutingHourKey);

        GetUniqueProductionOrderRoutingLine(
            RoutingOwnerProdOrderLine,
            RoutingLinkCode,
            ProdOrderRoutingLine);

        if ProdOrderRoutingLine."Run Time" <= QuantityTolerance() then
            exit;

        LotSize := ProdOrderRoutingLine."Lot Size";
        if LotSize = 0 then
            LotSize := 1;
        CurrentQuantityPerOutput := ConvertCapacityQuantity(
            ProdOrderRoutingLine."Run Time" / LotSize,
            ProdOrderRoutingLine."Run Time Unit of Meas. Code",
            CapacityUnitOfMeasureCode);
        NewQuantityPerOutput :=
            CurrentQuantityPerOutput +
            (AfterQuantityPerOutput - BeforeQuantityPerOutput);
        if not AllowDecrease and (NewQuantityPerOutput < CurrentQuantityPerOutput) then
            NewQuantityPerOutput := CurrentQuantityPerOutput;
        NewRunTime := ConvertCapacityQuantity(
            NewQuantityPerOutput,
            CapacityUnitOfMeasureCode,
            ProdOrderRoutingLine."Run Time Unit of Meas. Code") * LotSize;
        if NewRunTime < -QuantityTolerance() then
            Error(RoutingHourTotalInvalidErr, RoutingLinkCode, RoutingOwnerProdOrderLine."Item No.");
        if NewRunTime < 0 then
            NewRunTime := 0;

        ProdOrderRoutingLine.Validate("Run Time", NewRunTime);
        ProdOrderRoutingLine.Modify(true);
        AppendRoutingImpactSummary(
            RoutingImpactSummary,
            RoutingLinkCode,
            CurrentQuantityPerOutput,
            NewQuantityPerOutput,
            AfterQuantityPerOutput - BeforeQuantityPerOutput,
            CapacityUnitOfMeasureCode);
    end;

    local procedure AppendRoutingImpactSummary(var RoutingImpactSummary: Text; RoutingLinkCode: Code[10]; CurrentQuantityPerOutput: Decimal; NewQuantityPerOutput: Decimal; LiveQuantityDifference: Decimal; CapacityUnitOfMeasureCode: Code[10])
    var
        ImpactLine: Text;
        LineFeed: Char;
        RequiredLength: Integer;
    begin
        if Abs(NewQuantityPerOutput - CurrentQuantityPerOutput) <= QuantityTolerance() then
            exit;
        ImpactLine := StrSubstNo(
            RoutingImpactLineTxt,
            RoutingLinkCode,
            CurrentQuantityPerOutput,
            NewQuantityPerOutput,
            CapacityUnitOfMeasureCode,
            LiveQuantityDifference);
        LineFeed := 10;
        RequiredLength := StrLen(ImpactLine);
        if RoutingImpactSummary <> '' then
            RequiredLength += 1;
        if StrLen(RoutingImpactSummary) + RequiredLength > MaximumRoutingImpactSummaryLength() then begin
            if StrPos(RoutingImpactSummary, RoutingImpactTruncatedTxt) = 0 then
                RoutingImpactSummary :=
                    CopyStr(
                        RoutingImpactSummary,
                        1,
                        MaximumRoutingImpactSummaryLength() - StrLen(RoutingImpactTruncatedTxt)) +
                    RoutingImpactTruncatedTxt;
            exit;
        end;
        if RoutingImpactSummary <> '' then
            RoutingImpactSummary += LineFeed;
        RoutingImpactSummary += ImpactLine;
    end;

    local procedure GetUniqueProductionOrderRoutingLine(RoutingOwnerProdOrderLine: Record "Prod. Order Line"; RoutingLinkCode: Code[10]; var ProdOrderRoutingLine: Record "Prod. Order Routing Line")
    var
        FirstProdOrderRoutingLine: Record "Prod. Order Routing Line";
    begin
        ProdOrderRoutingLine.Reset();
        ProdOrderRoutingLine.SetRange(Status, RoutingOwnerProdOrderLine.Status);
        ProdOrderRoutingLine.SetRange("Prod. Order No.", RoutingOwnerProdOrderLine."Prod. Order No.");
        ProdOrderRoutingLine.SetRange("Routing Reference No.", RoutingOwnerProdOrderLine."Routing Reference No.");
        ProdOrderRoutingLine.SetRange("Routing No.", RoutingOwnerProdOrderLine."Routing No.");
        ProdOrderRoutingLine.SetRange("Routing Link Code", RoutingLinkCode);
        if not ProdOrderRoutingLine.FindSet() then
            Error(MissingRoutingLinkForAddedHoursErr, RoutingLinkCode, RoutingOwnerProdOrderLine."Item No.");
        FirstProdOrderRoutingLine := ProdOrderRoutingLine;
        if ProdOrderRoutingLine.Next() <> 0 then
            Error(DuplicateProductionRoutingLinkErr, RoutingLinkCode, RoutingOwnerProdOrderLine."Item No.");
        ProdOrderRoutingLine := FirstProdOrderRoutingLine;
    end;

    local procedure GetDecimalDictionaryValue(Values: Dictionary of [Text, Decimal]; DictionaryKey: Text): Decimal
    var
        Value: Decimal;
    begin
        if not Values.ContainsKey(DictionaryKey) then
            exit(0);
        Values.Get(DictionaryKey, Value);
        exit(Value);
    end;

    local procedure SetDecimalDictionaryValue(var Values: Dictionary of [Text, Decimal]; DictionaryKey: Text; Value: Decimal)
    begin
        if Values.ContainsKey(DictionaryKey) then
            Values.Set(DictionaryKey, Value)
        else
            Values.Add(DictionaryKey, Value);
    end;

    local procedure DecimalDictionariesEqual(ConfirmedValues: Dictionary of [Text, Decimal]; CurrentValues: Dictionary of [Text, Decimal]): Boolean
    var
        ConfirmedKey: Text;
        ConfirmedKeys: List of [Text];
        ConfirmedValue: Decimal;
        CurrentValue: Decimal;
    begin
        if ConfirmedValues.Count() <> CurrentValues.Count() then
            exit(false);
        ConfirmedKeys := ConfirmedValues.Keys();
        foreach ConfirmedKey in ConfirmedKeys do begin
            ConfirmedValues.Get(ConfirmedKey, ConfirmedValue);
            if not CurrentValues.Get(ConfirmedKey, CurrentValue) then
                exit(false);
            if Abs(ConfirmedValue - CurrentValue) > QuantityTolerance() then
                exit(false);
        end;
        exit(true);
    end;

    local procedure GetRoutingHourOwnerPrefix(ProdOrderLine: Record "Prod. Order Line"): Text
    begin
        exit(
            Format(ProdOrderLine.Status.AsInteger()) + '|' +
            ProdOrderLine."Prod. Order No." + '|' +
            Format(ProdOrderLine."Line No.") + '|');
    end;

    local procedure HasLiveProductionOrderRouting(ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
    begin
        if ProdOrderLine."Routing No." = '' then
            exit(false);
        ProdOrderRoutingLine.SetRange(Status, ProdOrderLine.Status);
        ProdOrderRoutingLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        ProdOrderRoutingLine.SetRange("Routing Reference No.", ProdOrderLine."Routing Reference No.");
        ProdOrderRoutingLine.SetRange("Routing No.", ProdOrderLine."Routing No.");
        exit(not ProdOrderRoutingLine.IsEmpty());
    end;

    local procedure IsCapacityUnitOfMeasure(UnitOfMeasureCode: Code[10]): Boolean
    var
        CapacityUnitOfMeasure: Record "Capacity Unit of Measure";
    begin
        exit(CapacityUnitOfMeasure.Get(UnitOfMeasureCode));
    end;

    local procedure IsCapacityUnitOfMeasureCached(UnitOfMeasureCode: Code[10]; var CapacityUnitOfMeasureCache: Dictionary of [Code[10], Boolean]): Boolean
    var
        IsCapacityUnit: Boolean;
    begin
        if CapacityUnitOfMeasureCache.Get(UnitOfMeasureCode, IsCapacityUnit) then
            exit(IsCapacityUnit);
        IsCapacityUnit := IsCapacityUnitOfMeasure(UnitOfMeasureCode);
        CapacityUnitOfMeasureCache.Add(UnitOfMeasureCode, IsCapacityUnit);
        exit(IsCapacityUnit);
    end;

    local procedure IsNonInventoryItem(ItemNo: Code[20]; var NonInventoryItemCache: Dictionary of [Code[20], Boolean]): Boolean
    var
        Item: Record Item;
        IsNonInventory: Boolean;
    begin
        if NonInventoryItemCache.Get(ItemNo, IsNonInventory) then
            exit(IsNonInventory);
        Item.SetLoadFields(Type);
        IsNonInventory := Item.Get(ItemNo) and (Item.Type = Item.Type::"Non-Inventory");
        NonInventoryItemCache.Add(ItemNo, IsNonInventory);
        exit(IsNonInventory);
    end;

    local procedure ConvertCapacityQuantity(Quantity: Decimal; FromUnitOfMeasureCode: Code[10]; ToUnitOfMeasureCode: Code[10]): Decimal
    begin
        if FromUnitOfMeasureCode = ToUnitOfMeasureCode then
            exit(Quantity);
        exit(
            Quantity *
            GetCapacityTimeFactor(FromUnitOfMeasureCode) /
            GetCapacityTimeFactor(ToUnitOfMeasureCode));
    end;

    local procedure GetCapacityTimeFactor(UnitOfMeasureCode: Code[10]): Decimal
    var
        CapacityUnitOfMeasure: Record "Capacity Unit of Measure";
    begin
        CapacityUnitOfMeasure.Get(UnitOfMeasureCode);
        case CapacityUnitOfMeasure.Type of
            CapacityUnitOfMeasure.Type::Seconds:
                exit(1000);
            CapacityUnitOfMeasure.Type::Minutes:
                exit(60000);
            CapacityUnitOfMeasure.Type::"100/Hour":
                exit(36000);
            CapacityUnitOfMeasure.Type::Hours:
                exit(3600000);
            CapacityUnitOfMeasure.Type::Days:
                exit(86400000);
        end;
        exit(1);
    end;

    local procedure CollectAffectedProductionOrderLinesForHeader(PNEPILHeader: Record "PNE PIL Header"; var TempAffectedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILTarget.FindSet() then
            repeat
                if TargetChangesProductionOrder(PNEPILTarget) and
                   not HasEarlierChangingTargetForCarrier(PNEPILTarget)
                then
                    CollectAffectedProductionOrderLines(PNEPILTarget, TempAffectedProdOrderLine);
            until PNEPILTarget.Next() = 0;
    end;

    local procedure HasEarlierChangingTargetForCarrier(SourcePNEPILTarget: Record "PNE PIL Target"): Boolean
    var
        EarlierPNEPILTarget: Record "PNE PIL Target";
    begin
        SetCarrierTargetFilter(EarlierPNEPILTarget, SourcePNEPILTarget);
        EarlierPNEPILTarget.SetFilter("Line No.", '<%1', SourcePNEPILTarget."Line No.");
        if EarlierPNEPILTarget.FindSet() then
            repeat
                if TargetChangesProductionOrder(EarlierPNEPILTarget) then
                    exit(true);
            until EarlierPNEPILTarget.Next() = 0;
        exit(false);
    end;

    local procedure TargetChangesProductionOrder(PNEPILTarget: Record "PNE PIL Target"): Boolean
    begin
        case PNEPILTarget.Kind of
            PNEPILTarget.Kind::"Structural driver":
                exit(
                    Abs(
                        PNEPILTarget."New Carrier Quantity" -
                        PNEPILTarget."Original Carrier Quantity") > QuantityTolerance());
            PNEPILTarget.Kind::"CALC replacement",
            PNEPILTarget.Kind::"Direct component addition":
                exit(PNEPILTarget."Allocated PIL Quantity" > QuantityTolerance());
            PNEPILTarget.Kind::"Point carrier addition":
                exit(PNEPILTarget."New Carrier Quantity" > QuantityTolerance());
        end;
        exit(false);
    end;

    local procedure RecalculateAffectedProductionOrderRouting(PNEPILHeader: Record "PNE PIL Header")
    var
        TempAffectedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        CollectAffectedProductionOrderLinesForHeader(PNEPILHeader, TempAffectedProdOrderLine);

        TempAffectedProdOrderLine.Reset();
        if TempAffectedProdOrderLine.FindSet() then
            repeat
                RecalculateProductionOrderRouting(TempAffectedProdOrderLine);
            until TempAffectedProdOrderLine.Next() = 0;
    end;

    local procedure CollectAffectedProductionOrderLines(PNEPILTarget: Record "PNE PIL Target"; var TempAffectedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        CarrierProdOrderComponent: Record "Prod. Order Component";
        CarrierProdOrderLine: Record "Prod. Order Line";
        CALCSourceProdOrderLine: Record "Prod. Order Line";
        TempAncestorVisitedProdOrderLine: Record "Prod. Order Line" temporary;
        TempCALCSourceAncestorVisitedProdOrderLine: Record "Prod. Order Line" temporary;
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        case PNEPILTarget."Carrier Type" of
            PNEPILTarget."Carrier Type"::"Production Order Line":
                begin
                    CarrierProdOrderLine.Get(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.");
                    if PNEPILTarget.Kind = PNEPILTarget.Kind::"Structural driver" then
                        CollectRoutingLinesInProductionOrderTree(
                            CarrierProdOrderLine,
                            TempAffectedProdOrderLine,
                            TempVisitedProdOrderLine)
                    else
                        AddAffectedProductionOrderLine(
                            CarrierProdOrderLine,
                            TempAffectedProdOrderLine);
                    CollectRoutingLinesInProductionOrderAncestorChain(
                        CarrierProdOrderLine,
                        TempAffectedProdOrderLine,
                        TempAncestorVisitedProdOrderLine);
                end;
            PNEPILTarget."Carrier Type"::"Production Order Component":
                begin
                    CarrierProdOrderComponent.Get(
                        PNEPILTarget."Carrier Status",
                        PNEPILTarget."Carrier Production Order No.",
                        PNEPILTarget."Carrier Order Line No.",
                        PNEPILTarget."Carrier Component Line No.");
                    CarrierProdOrderLine.Get(
                        CarrierProdOrderComponent.Status,
                        CarrierProdOrderComponent."Prod. Order No.",
                        CarrierProdOrderComponent."Prod. Order Line No.");
                    AddAffectedProductionOrderLine(CarrierProdOrderLine, TempAffectedProdOrderLine);
                    CollectRoutingLinesInProductionOrderAncestorChain(
                        CarrierProdOrderLine,
                        TempAffectedProdOrderLine,
                        TempAncestorVisitedProdOrderLine);
                end;
        end;

        if PNEPILTarget.Kind = PNEPILTarget.Kind::"CALC replacement" then begin
            CALCSourceProdOrderLine.Get(
                PNEPILTarget."Source CALC Status",
                PNEPILTarget."CALC Source Prod. Order No.",
                PNEPILTarget."Source CALC Order Line No.");
            AddAffectedProductionOrderLine(CALCSourceProdOrderLine, TempAffectedProdOrderLine);
            CollectRoutingLinesInProductionOrderAncestorChain(
                CALCSourceProdOrderLine,
                TempAffectedProdOrderLine,
                TempCALCSourceAncestorVisitedProdOrderLine);
        end;
    end;

    local procedure CollectRoutingLinesInProductionOrderTree(CurrentProdOrderLine: Record "Prod. Order Line"; var TempAffectedProdOrderLine: Record "Prod. Order Line" temporary; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;
        AddAffectedProductionOrderLine(CurrentProdOrderLine, TempAffectedProdOrderLine);

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                    CollectRoutingLinesInProductionOrderTree(
                        ChildProdOrderLine,
                        TempAffectedProdOrderLine,
                        TempVisitedProdOrderLine);
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure CollectRoutingLinesInProductionOrderAncestorChain(CurrentProdOrderLine: Record "Prod. Order Line"; var TempAffectedProdOrderLine: Record "Prod. Order Line" temporary; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ParentProdOrderComponent: Record "Prod. Order Component";
        ParentProdOrderLine: Record "Prod. Order Line";
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;
        AddAffectedProductionOrderLine(CurrentProdOrderLine, TempAffectedProdOrderLine);

        ParentProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ParentProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ParentProdOrderComponent.SetRange("Supplied-by Line No.", CurrentProdOrderLine."Line No.");
        if ParentProdOrderComponent.FindSet() then
            repeat
                ParentProdOrderLine.Get(
                    ParentProdOrderComponent.Status,
                    ParentProdOrderComponent."Prod. Order No.",
                    ParentProdOrderComponent."Prod. Order Line No.");
                CollectRoutingLinesInProductionOrderAncestorChain(
                    ParentProdOrderLine,
                    TempAffectedProdOrderLine,
                    TempVisitedProdOrderLine);
            until ParentProdOrderComponent.Next() = 0;
    end;

    local procedure AddAffectedProductionOrderLine(ProdOrderLine: Record "Prod. Order Line"; var TempAffectedProdOrderLine: Record "Prod. Order Line" temporary)
    begin
        if TempAffectedProdOrderLine.Get(ProdOrderLine.Status, ProdOrderLine."Prod. Order No.", ProdOrderLine."Line No.") then
            exit;
        TempAffectedProdOrderLine := ProdOrderLine;
        TempAffectedProdOrderLine.Insert();
    end;

    local procedure RecalculateProductionOrderRouting(ProdOrderLine: Record "Prod. Order Line")
    var
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
        CalculateProdOrder: Codeunit "Calculate Prod. Order";
    begin
        if ProdOrderLine."Routing No." = '' then
            exit;

        ProdOrderRoutingLine.SetRange(Status, ProdOrderLine.Status);
        ProdOrderRoutingLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        ProdOrderRoutingLine.SetRange("Routing Reference No.", ProdOrderLine."Routing Reference No.");
        ProdOrderRoutingLine.SetRange("Routing No.", ProdOrderLine."Routing No.");
        if ProdOrderRoutingLine.FindFirst() then
            CalculateProdOrder.CalculateRoutingFromActual(ProdOrderRoutingLine, 0, true);
    end;

    local procedure FindComponentInCarrierTree(CarrierProdOrderLine: Record "Prod. Order Line"; ItemNo: Code[20]; var FoundProdOrderComponent: Record "Prod. Order Component"; var FoundCount: Integer)
    var
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        Clear(FoundProdOrderComponent);
        Clear(FoundCount);
        FindComponentsInLine(CarrierProdOrderLine, ItemNo, FoundProdOrderComponent, FoundCount, TempVisitedProdOrderLine);
    end;

    local procedure FindComponentsInLine(CurrentProdOrderLine: Record "Prod. Order Line"; ItemNo: Code[20]; var FoundProdOrderComponent: Record "Prod. Order Component"; var FoundCount: Integer; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if ProdOrderComponent."Item No." = ItemNo then begin
                    FoundProdOrderComponent := ProdOrderComponent;
                    FoundCount += 1;
                end;
                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                    FindComponentsInLine(ChildProdOrderLine, ItemNo, FoundProdOrderComponent, FoundCount, TempVisitedProdOrderLine);
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure GetQuantityPerCarrierForItem(CarrierProdOrderLine: Record "Prod. Order Line"; ItemNo: Code[20]): Decimal
    var
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
        QuantityPerCarrier: Decimal;
    begin
        if CarrierProdOrderLine.Quantity <= QuantityTolerance() then
            Error(ZeroCarrierQuantityErr, CarrierProdOrderLine."Item No.");
        SumQuantityPerCarrierInLine(CarrierProdOrderLine, CarrierProdOrderLine, ItemNo, QuantityPerCarrier, TempVisitedProdOrderLine);
        exit(QuantityPerCarrier);
    end;

    local procedure GetStructuralTargetCountForCarrierLine(PNEPILHeader: Record "PNE PIL Header"; CarrierProdOrderLine: Record "Prod. Order Line"): Integer
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Structural driver");
        PNEPILTarget.SetRange("Carrier Type", PNEPILTarget."Carrier Type"::"Production Order Line");
        PNEPILTarget.SetRange("Carrier Status", CarrierProdOrderLine.Status);
        PNEPILTarget.SetRange("Carrier Production Order No.", CarrierProdOrderLine."Prod. Order No.");
        PNEPILTarget.SetRange("Carrier Order Line No.", CarrierProdOrderLine."Line No.");
        PNEPILTarget.SetRange("Carrier Component Line No.", 0);
        exit(PNEPILTarget.Count());
    end;

    local procedure SumQuantityPerCarrierInLine(CarrierProdOrderLine: Record "Prod. Order Line"; CurrentProdOrderLine: Record "Prod. Order Line"; ItemNo: Code[20]; var QuantityPerCarrier: Decimal; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if ProdOrderComponent."Item No." = ItemNo then
                    QuantityPerCarrier += ProdOrderComponent."Expected Quantity" / CarrierProdOrderLine.Quantity;
                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                    SumQuantityPerCarrierInLine(CarrierProdOrderLine, ChildProdOrderLine, ItemNo, QuantityPerCarrier, TempVisitedProdOrderLine);
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure GetOuterCarrierLines(PNEPILHeader: Record "PNE PIL Header"; var TempOuterCarrierProdOrderLine: Record "Prod. Order Line" temporary)
    var
        RootProdOrderLine: Record "Prod. Order Line";
        TempAllCarrierProdOrderLine: Record "Prod. Order Line" temporary;
        TempVisitedPointCarrierProdOrderLine: Record "Prod. Order Line" temporary;
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        TempOuterCarrierProdOrderLine.DeleteAll();
        RootProdOrderLine.SetRange(Status, PNEPILHeader."Production Order Status");
        RootProdOrderLine.SetRange("Prod. Order No.", PNEPILHeader."Production Order No.");
        if RootProdOrderLine.FindSet() then
            repeat
                CollectCarrierLines(RootProdOrderLine, TempAllCarrierProdOrderLine, TempVisitedProdOrderLine);
            until RootProdOrderLine.Next() = 0;

        TempAllCarrierProdOrderLine.Reset();
        if TempAllCarrierProdOrderLine.FindSet() then
            repeat
                if not IsNestedCarrierLine(TempAllCarrierProdOrderLine, TempAllCarrierProdOrderLine) then
                    if IsGroupCarrierItemNo(TempAllCarrierProdOrderLine."Item No.") then begin
                        TempVisitedPointCarrierProdOrderLine.DeleteAll();
                        if not ContainsPointCarrierInLineTree(TempAllCarrierProdOrderLine, TempVisitedPointCarrierProdOrderLine) then begin
                            TempOuterCarrierProdOrderLine := TempAllCarrierProdOrderLine;
                            TempOuterCarrierProdOrderLine.Insert();
                        end;
                    end else begin
                        TempOuterCarrierProdOrderLine := TempAllCarrierProdOrderLine;
                        TempOuterCarrierProdOrderLine.Insert();
                    end;
            until TempAllCarrierProdOrderLine.Next() = 0;
    end;

    local procedure CollectCarrierLines(CurrentProdOrderLine: Record "Prod. Order Line"; var TempAllCarrierProdOrderLine: Record "Prod. Order Line" temporary; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;

        if IsCarrier(CurrentProdOrderLine) then
            if not TempAllCarrierProdOrderLine.Get(CurrentProdOrderLine.Status, CurrentProdOrderLine."Prod. Order No.", CurrentProdOrderLine."Line No.") then begin
                TempAllCarrierProdOrderLine := CurrentProdOrderLine;
                TempAllCarrierProdOrderLine.Insert();
            end;

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                    CollectCarrierLines(ChildProdOrderLine, TempAllCarrierProdOrderLine, TempVisitedProdOrderLine);
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure GetUnlinkedOuterCarrierComponents(PNEPILHeader: Record "PNE PIL Header"; var TempCarrierProdOrderComponent: Record "Prod. Order Component" temporary)
    var
        RootProdOrderLine: Record "Prod. Order Line";
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        TempCarrierProdOrderComponent.DeleteAll();
        RootProdOrderLine.SetRange(Status, PNEPILHeader."Production Order Status");
        RootProdOrderLine.SetRange("Prod. Order No.", PNEPILHeader."Production Order No.");
        if RootProdOrderLine.FindSet() then
            repeat
                CollectUnlinkedOuterCarrierComponents(
                    RootProdOrderLine,
                    IsCarrier(RootProdOrderLine),
                    IsPointCarrierItemNo(RootProdOrderLine."Item No."),
                    TempCarrierProdOrderComponent,
                    TempVisitedProdOrderLine);
            until RootProdOrderLine.Next() = 0;
    end;

    local procedure CollectUnlinkedOuterCarrierComponents(CurrentProdOrderLine: Record "Prod. Order Line"; IsBelowCarrier: Boolean; IsBelowPointCarrier: Boolean; var TempCarrierProdOrderComponent: Record "Prod. Order Component" temporary; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary)
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
        CanAddCarrier: Boolean;
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit;

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if IsCarrierComponent(ProdOrderComponent, GetCarrierCalculationDate(CurrentProdOrderLine)) and
                   not FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine)
                then begin
                    if IsPointCarrierItemNo(ProdOrderComponent."Item No.") then
                        CanAddCarrier := not IsBelowPointCarrier
                    else
                        CanAddCarrier := not IsBelowCarrier;
                    if CanAddCarrier then
                        if not TempCarrierProdOrderComponent.Get(
                            ProdOrderComponent.Status,
                            ProdOrderComponent."Prod. Order No.",
                            ProdOrderComponent."Prod. Order Line No.",
                            ProdOrderComponent."Line No.")
                        then begin
                            TempCarrierProdOrderComponent := ProdOrderComponent;
                            TempCarrierProdOrderComponent.Insert();
                        end;
                end;

                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                    CollectUnlinkedOuterCarrierComponents(
                        ChildProdOrderLine,
                        IsBelowCarrier or IsCarrier(CurrentProdOrderLine) or IsCarrierComponent(ProdOrderComponent, GetCarrierCalculationDate(CurrentProdOrderLine)),
                        IsBelowPointCarrier or IsPointCarrierItemNo(CurrentProdOrderLine."Item No.") or IsPointCarrierItemNo(ProdOrderComponent."Item No."),
                        TempCarrierProdOrderComponent,
                        TempVisitedProdOrderLine);
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure IsNestedCarrierLine(CandidateProdOrderLine: Record "Prod. Order Line"; TempAllCarrierProdOrderLine: Record "Prod. Order Line" temporary): Boolean
    var
        TempOtherCarrierProdOrderLine: Record "Prod. Order Line" temporary;
        TempVisitedProdOrderLine: Record "Prod. Order Line" temporary;
    begin
        TempOtherCarrierProdOrderLine.Copy(TempAllCarrierProdOrderLine, true);
        TempOtherCarrierProdOrderLine.Reset();
        if TempOtherCarrierProdOrderLine.FindSet() then
            repeat
                if not IsSameProdOrderLine(TempOtherCarrierProdOrderLine, CandidateProdOrderLine) then
                    if not (
                        IsPointCarrierItemNo(CandidateProdOrderLine."Item No.") and
                        IsGroupCarrierItemNo(TempOtherCarrierProdOrderLine."Item No."))
                    then begin
                        TempVisitedProdOrderLine.DeleteAll();
                        if LineContainsProdOrderLine(TempOtherCarrierProdOrderLine, CandidateProdOrderLine, TempVisitedProdOrderLine) then
                            exit(true);

                        if IsGroupCarrierItemNo(CandidateProdOrderLine."Item No.") and
                           IsPointCarrierItemNo(TempOtherCarrierProdOrderLine."Item No.")
                        then begin
                            TempVisitedProdOrderLine.DeleteAll();
                            if LineContainsProdOrderLine(CandidateProdOrderLine, TempOtherCarrierProdOrderLine, TempVisitedProdOrderLine) then
                                exit(true);
                        end;
                    end;
            until TempOtherCarrierProdOrderLine.Next() = 0;
        exit(false);
    end;

    local procedure LineContainsProdOrderLine(CurrentProdOrderLine: Record "Prod. Order Line"; TargetProdOrderLine: Record "Prod. Order Line"; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary): Boolean
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit(false);
        if IsSameProdOrderLine(CurrentProdOrderLine, TargetProdOrderLine) then
            exit(true);

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                    if LineContainsProdOrderLine(ChildProdOrderLine, TargetProdOrderLine, TempVisitedProdOrderLine) then
                        exit(true);
            until ProdOrderComponent.Next() = 0;
        exit(false);
    end;

    local procedure ContainsPointCarrierInLineTree(CurrentProdOrderLine: Record "Prod. Order Line"; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary): Boolean
    var
        ChildProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        if WasVisited(CurrentProdOrderLine, TempVisitedProdOrderLine) then
            exit(false);

        ProdOrderComponent.SetRange(Status, CurrentProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", CurrentProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", CurrentProdOrderLine."Line No.");
        if ProdOrderComponent.FindSet() then
            repeat
                if IsPointCarrierItemNo(ProdOrderComponent."Item No.") then
                    exit(true);
                if FindChildProdOrderLine(ProdOrderComponent, ChildProdOrderLine) then
                    if ContainsPointCarrierInLineTree(ChildProdOrderLine, TempVisitedProdOrderLine) then
                        exit(true);
            until ProdOrderComponent.Next() = 0;
        exit(false);
    end;

    local procedure FindChildProdOrderLine(ProdOrderComponent: Record "Prod. Order Component"; var ChildProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        CandidateProdOrderLine: Record "Prod. Order Line";
        PairedReservationEntry: Record "Reservation Entry";
        ReservationEntry: Record "Reservation Entry";
        ChildFound: Boolean;
    begin
        Clear(ChildProdOrderLine);
        if ProdOrderComponent."Supplied-by Line No." <> 0 then begin
            if not ChildProdOrderLine.Get(ProdOrderComponent.Status, ProdOrderComponent."Prod. Order No.", ProdOrderComponent."Supplied-by Line No.") then
                Error(BrokenSuppliedByLinkErr, ProdOrderComponent."Item No.");
            CheckChildProdOrderLineMatchesComponent(ProdOrderComponent, ChildProdOrderLine);
            exit(true);
        end;

        ReservationEntry.SetSourceFilter(
            Database::"Prod. Order Component",
            ProdOrderComponent.Status.AsInteger(),
            ProdOrderComponent."Prod. Order No.",
            ProdOrderComponent."Line No.",
            false);
        ReservationEntry.SetSourceFilter('', ProdOrderComponent."Prod. Order Line No.");
        if ReservationEntry.FindSet() then
            repeat
                if PairedReservationEntry.Get(ReservationEntry."Entry No.", not ReservationEntry.Positive) then
                    if PairedReservationEntry."Source Type" = Database::"Prod. Order Line" then begin
                        if (PairedReservationEntry."Source ID" <> ProdOrderComponent."Prod. Order No.") or
                           (PairedReservationEntry."Source Subtype" <> ProdOrderComponent.Status.AsInteger())
                        then
                            Error(CrossOrderChildErr, ProdOrderComponent."Item No.");
                        if CandidateProdOrderLine.Get(
                            PairedReservationEntry."Source Subtype",
                            PairedReservationEntry."Source ID",
                            PairedReservationEntry."Source Prod. Order Line")
                        then begin
                            CheckChildProdOrderLineMatchesComponent(ProdOrderComponent, CandidateProdOrderLine);
                            if ChildFound and not IsSameProdOrderLine(ChildProdOrderLine, CandidateProdOrderLine) then
                                Error(AmbiguousChildOrderErr, ProdOrderComponent."Item No.");
                            ChildProdOrderLine := CandidateProdOrderLine;
                            ChildFound := true;
                        end;
                    end;
            until ReservationEntry.Next() = 0;
        exit(ChildFound);
    end;

    local procedure CheckChildProdOrderLineMatchesComponent(ProdOrderComponent: Record "Prod. Order Component"; ChildProdOrderLine: Record "Prod. Order Line")
    begin
        if (ChildProdOrderLine."Item No." <> ProdOrderComponent."Item No.") or
           (ChildProdOrderLine."Variant Code" <> ProdOrderComponent."Variant Code")
        then
            Error(
                InvalidChildLinkErr,
                ProdOrderComponent."Item No.",
                ProdOrderComponent."Variant Code",
                ChildProdOrderLine."Item No.",
                ChildProdOrderLine."Variant Code");
    end;

    local procedure CheckInboundDemandComponent(ParentProdOrderComponent: Record "Prod. Order Component"; CarrierProdOrderLine: Record "Prod. Order Line")
    begin
        if (ParentProdOrderComponent."Item No." <> CarrierProdOrderLine."Item No.") or
           (ParentProdOrderComponent."Variant Code" <> CarrierProdOrderLine."Variant Code")
        then
            Error(
                InvalidInboundDemandErr,
                ParentProdOrderComponent."Item No.",
                ParentProdOrderComponent."Variant Code",
                CarrierProdOrderLine."Item No.",
                CarrierProdOrderLine."Variant Code");
    end;

    local procedure GetPILLine(PNEPILHeader: Record "PNE PIL Header"; ItemNo: Code[20]; var PNEPILLine: Record "PNE PIL Line"): Boolean
    begin
        PNEPILLine.Reset();
        PNEPILLine.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILLine.SetRange("Item No.", ItemNo);
        if not PNEPILLine.FindFirst() then
            exit(false);
        exit(not PNEPILLine."Ignore for Reconciliation");
    end;

    local procedure HasStructuralTarget(PNEPILHeader: Record "PNE PIL Header"; PILLineNo: Integer): Boolean
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", PILLineNo);
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Structural driver");
        exit(not PNEPILTarget.IsEmpty());
    end;

    local procedure HasDirectComponentTarget(PNEPILHeader: Record "PNE PIL Header"; PILLineNo: Integer): Boolean
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", PILLineNo);
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Direct component addition");
        exit(not PNEPILTarget.IsEmpty());
    end;

    local procedure HasPointCarrierAdditionTarget(PNEPILHeader: Record "PNE PIL Header"; PILLineNo: Integer): Boolean
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", PILLineNo);
        PNEPILTarget.SetRange(Kind, PNEPILTarget.Kind::"Point carrier addition");
        exit(not PNEPILTarget.IsEmpty());
    end;

    local procedure GetNextTargetLineNo(PNEPILHeader: Record "PNE PIL Header"): Integer
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        if PNEPILTarget.FindLast() then
            exit(PNEPILTarget."Line No." + 10000);
        exit(10000);
    end;

    local procedure GetNextComponentLineNo(ProdOrderComponent: Record "Prod. Order Component"): Integer
    var
        ExistingProdOrderComponent: Record "Prod. Order Component";
    begin
        ExistingProdOrderComponent.SetRange(Status, ProdOrderComponent.Status);
        ExistingProdOrderComponent.SetRange("Prod. Order No.", ProdOrderComponent."Prod. Order No.");
        ExistingProdOrderComponent.SetRange("Prod. Order Line No.", ProdOrderComponent."Prod. Order Line No.");
        if ExistingProdOrderComponent.FindLast() then
            exit(ExistingProdOrderComponent."Line No.");
        exit(0);
    end;

    local procedure GetNextComponentLineNoForOrderLine(ProdOrderLine: Record "Prod. Order Line"): Integer
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        ProdOrderComponent.SetRange(Status, ProdOrderLine.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", ProdOrderLine."Line No.");
        if ProdOrderComponent.FindLast() then
            exit(ProdOrderComponent."Line No.");
        exit(0);
    end;

    local procedure HasEarlierCALCTargetForCarrierAndGroup(PNEPILTarget: Record "PNE PIL Target"): Boolean
    var
        EarlierPNEPILTarget: Record "PNE PIL Target";
    begin
        SetCALCTargetGroupFilter(EarlierPNEPILTarget, PNEPILTarget);
        EarlierPNEPILTarget.SetFilter("Line No.", '<%1', PNEPILTarget."Line No.");
        exit(not EarlierPNEPILTarget.IsEmpty());
    end;

    local procedure HasEarlierTargetForPILLineAndKind(PNEPILTarget: Record "PNE PIL Target"): Boolean
    var
        EarlierPNEPILTarget: Record "PNE PIL Target";
    begin
        EarlierPNEPILTarget.SetRange("Header Entry No.", PNEPILTarget."Header Entry No.");
        EarlierPNEPILTarget.SetRange("PIL Line No.", PNEPILTarget."PIL Line No.");
        EarlierPNEPILTarget.SetRange(Kind, PNEPILTarget.Kind);
        EarlierPNEPILTarget.SetFilter("Line No.", '<%1', PNEPILTarget."Line No.");
        exit(not EarlierPNEPILTarget.IsEmpty());
    end;

    local procedure HasMultipleTargetsForPILLine(PNEPILHeader: Record "PNE PIL Header"; PNEPILLine: Record "PNE PIL Line"): Boolean
    var
        PNEPILTarget: Record "PNE PIL Target";
    begin
        PNEPILTarget.SetRange("Header Entry No.", PNEPILHeader."Entry No.");
        PNEPILTarget.SetRange("PIL Line No.", PNEPILLine."Line No.");
        exit(PNEPILTarget.Count() > 1);
    end;

    local procedure HasEarlierTargetForCarrier(PNEPILTarget: Record "PNE PIL Target"): Boolean
    var
        EarlierPNEPILTarget: Record "PNE PIL Target";
    begin
        if PNEPILTarget.Kind = PNEPILTarget.Kind::"Point carrier addition" then begin
            SetPointCarrierAdditionFilter(EarlierPNEPILTarget, PNEPILTarget);
            EarlierPNEPILTarget.SetFilter("Line No.", '<%1', PNEPILTarget."Line No.");
            exit(not EarlierPNEPILTarget.IsEmpty());
        end;
        SetCarrierTargetFilter(EarlierPNEPILTarget, PNEPILTarget);
        EarlierPNEPILTarget.SetFilter("Line No.", '<%1', PNEPILTarget."Line No.");
        exit(not EarlierPNEPILTarget.IsEmpty());
    end;

    local procedure SetPointCarrierAdditionFilter(var PNEPILTarget: Record "PNE PIL Target"; SourcePNEPILTarget: Record "PNE PIL Target")
    begin
        PNEPILTarget.Reset();
        PNEPILTarget.SetRange("Header Entry No.", SourcePNEPILTarget."Header Entry No.");
        PNEPILTarget.SetRange(Kind, SourcePNEPILTarget.Kind::"Point carrier addition");
        PNEPILTarget.SetRange("New Point Carrier Item No.", SourcePNEPILTarget."New Point Carrier Item No.");
        PNEPILTarget.SetRange("Carrier Type", SourcePNEPILTarget."Carrier Type");
        PNEPILTarget.SetRange("Carrier Status", SourcePNEPILTarget."Carrier Status");
        PNEPILTarget.SetRange("Carrier Production Order No.", SourcePNEPILTarget."Carrier Production Order No.");
        PNEPILTarget.SetRange("Carrier Order Line No.", SourcePNEPILTarget."Carrier Order Line No.");
        PNEPILTarget.SetRange("Carrier Component Line No.", SourcePNEPILTarget."Carrier Component Line No.");
    end;

    local procedure SetCALCTargetGroupFilter(var PNEPILTarget: Record "PNE PIL Target"; SourcePNEPILTarget: Record "PNE PIL Target")
    begin
        PNEPILTarget.Reset();
        PNEPILTarget.SetRange("Header Entry No.", SourcePNEPILTarget."Header Entry No.");
        PNEPILTarget.SetRange(Kind, SourcePNEPILTarget.Kind::"CALC replacement");
        PNEPILTarget.SetRange("PIL Group Code", SourcePNEPILTarget."PIL Group Code");
        PNEPILTarget.SetRange("Carrier Type", SourcePNEPILTarget."Carrier Type");
        PNEPILTarget.SetRange("Carrier Status", SourcePNEPILTarget."Carrier Status");
        PNEPILTarget.SetRange("Carrier Production Order No.", SourcePNEPILTarget."Carrier Production Order No.");
        PNEPILTarget.SetRange("Carrier Order Line No.", SourcePNEPILTarget."Carrier Order Line No.");
        PNEPILTarget.SetRange("Carrier Component Line No.", SourcePNEPILTarget."Carrier Component Line No.");
    end;

    local procedure SetCarrierTargetFilter(var PNEPILTarget: Record "PNE PIL Target"; SourcePNEPILTarget: Record "PNE PIL Target")
    begin
        PNEPILTarget.Reset();
        PNEPILTarget.SetRange("Header Entry No.", SourcePNEPILTarget."Header Entry No.");
        SetTargetCarrierFilter(PNEPILTarget, SourcePNEPILTarget);
    end;

    local procedure SetTargetCarrierFilter(var PNEPILTarget: Record "PNE PIL Target"; SourcePNEPILTarget: Record "PNE PIL Target")
    begin
        PNEPILTarget.SetRange("Carrier Type", SourcePNEPILTarget."Carrier Type");
        PNEPILTarget.SetRange("Carrier Status", SourcePNEPILTarget."Carrier Status");
        PNEPILTarget.SetRange("Carrier Production Order No.", SourcePNEPILTarget."Carrier Production Order No.");
        PNEPILTarget.SetRange("Carrier Order Line No.", SourcePNEPILTarget."Carrier Order Line No.");
        PNEPILTarget.SetRange("Carrier Component Line No.", SourcePNEPILTarget."Carrier Component Line No.");
    end;

    local procedure WasVisited(CurrentProdOrderLine: Record "Prod. Order Line"; var TempVisitedProdOrderLine: Record "Prod. Order Line" temporary): Boolean
    begin
        if TempVisitedProdOrderLine.Get(CurrentProdOrderLine.Status, CurrentProdOrderLine."Prod. Order No.", CurrentProdOrderLine."Line No.") then
            exit(true);
        if TempVisitedProdOrderLine.Count() >= MaximumProductionOrderTraversalNodes() then
            Error(ProductionOrderTraversalTooLargeErr, CurrentProdOrderLine."Prod. Order No.");
        TempVisitedProdOrderLine := CurrentProdOrderLine;
        TempVisitedProdOrderLine.Insert();
        exit(false);
    end;

    local procedure IsCarrier(ProdOrderLine: Record "Prod. Order Line"): Boolean
    begin
        if IsPointCarrierItemNo(ProdOrderLine."Item No.") then
            exit(true);
        exit(
            IsEligibleGroupCarrierItem(
                ProdOrderLine."Item No.",
                GetProductionBOMNoForLine(ProdOrderLine),
                GetCarrierCalculationDate(ProdOrderLine),
                ProdOrderLine."Production BOM Version Code",
                true));
    end;

    local procedure IsCarrierComponent(ProdOrderComponent: Record "Prod. Order Component"; CalculationDate: Date): Boolean
    begin
        if IsPointCarrierItemNo(ProdOrderComponent."Item No.") then
            exit(true);
        exit(
            IsEligibleGroupCarrierItem(
                ProdOrderComponent."Item No.",
                GetProductionBOMNoForComponent(ProdOrderComponent),
                CalculationDate,
                '',
                false));
    end;

    local procedure IsEligibleGroupCarrierItem(ItemNo: Code[20]; ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean): Boolean
    var
        Item: Record Item;
    begin
        if not IsGroupCarrierItemNo(ItemNo) then
            exit(false);
        if not Item.Get(ItemNo) then
            exit(false);
        if (Item.Type <> Item.Type::Inventory) or
           (Item."Replenishment System" <> Item."Replenishment System"::"Prod. Order") or
           (ProductionBOMNo = '')
        then
            exit(false);
        exit(HasCertifiedProductionBOM(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion));
    end;

    local procedure HasCertifiedProductionBOM(ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean): Boolean
    var
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMVersion: Record "Production BOM Version";
        VersionManagement: Codeunit VersionManagement;
        VersionCode: Code[20];
    begin
        if not ProductionBOMHeader.Get(ProductionBOMNo) then
            exit(false);

        if UseRequestedVersion and (RequestedVersionCode <> '') then
            VersionCode := RequestedVersionCode
        else
            VersionCode := VersionManagement.GetBOMVersion(ProductionBOMNo, CalculationDate, true);
        if VersionCode = '' then
            exit(ProductionBOMHeader.Status = ProductionBOMHeader.Status::Certified);
        if not ProductionBOMVersion.Get(ProductionBOMNo, VersionCode) then
            exit(false);
        exit(ProductionBOMVersion.Status = ProductionBOMVersion.Status::Certified);
    end;

    local procedure IsPointCarrierItemNo(ItemNo: Code[20]): Boolean
    begin
        exit(CopyStr(ItemNo, 1, 1) = '.');
    end;

    local procedure IsGroupCarrierItemNo(ItemNo: Code[20]): Boolean
    begin
        exit(CopyStr(ItemNo, 1, 2) = 'G.');
    end;

    local procedure IsSameProdOrderLine(FirstProdOrderLine: Record "Prod. Order Line"; SecondProdOrderLine: Record "Prod. Order Line"): Boolean
    begin
        exit(
            (FirstProdOrderLine.Status = SecondProdOrderLine.Status) and
            (FirstProdOrderLine."Prod. Order No." = SecondProdOrderLine."Prod. Order No.") and
            (FirstProdOrderLine."Line No." = SecondProdOrderLine."Line No."));
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterPILLiveChangesApplied(PNEPILHeader: Record "PNE PIL Header")
    begin
    end;

    local procedure QuantityTolerance(): Decimal
    begin
        exit(0.00001);
    end;

    local procedure MinDecimal(FirstValue: Decimal; SecondValue: Decimal): Decimal
    begin
        if FirstValue < SecondValue then
            exit(FirstValue);
        exit(SecondValue);
    end;

    local procedure MaxDecimal(FirstValue: Decimal; SecondValue: Decimal): Decimal
    begin
        if FirstValue > SecondValue then
            exit(FirstValue);
        exit(SecondValue);
    end;

    local procedure MaximumProductionBOMDepth(): Integer
    begin
        exit(50);
    end;

    local procedure MaximumProductionOrderTraversalNodes(): Integer
    begin
        exit(1000);
    end;

    var
        ActualPILComponentAlreadyExistsErr: Label 'AutoCAD-artikel %1 staat %3 keer als echte productiecomponent onder carrier %2. De app kan niet bepalen welke dubbele regel leidend is; ruim de dubbele componentregels op en analyseer opnieuw.', Comment = '%1 = AutoCAD item number, %2 = carrier item number, %3 = occurrence count';
        AdditionalPILLinesLinkedMsg: Label '%1 extra open AutoCAD-regel(s) uit hetzelfde puntartikel zijn automatisch gekoppeld aan %2. Het hoogste benodigde hele puntartikelaantal dekt alle gekoppelde regels.', Comment = '%1 = number of additionally linked PIL lines, %2 = point carrier item number';
        AlreadyAppliedErr: Label 'PIL-import %1 is al toegepast.', Comment = '%1 = import entry number';
        AllocationRequiredStatusTxt: Label 'De verdeling is nog niet gereed, maar er is geen afzonderlijke open regel gevonden. Kies Analyseer opnieuw om het voorstel volledig opnieuw op te bouwen.';
        AllocationWorkflowGuidanceTxt: Label 'Stap 2 van 4: verdeel alleen regels met meerdere carriers en kies daarna Verdeling controleren.';
        AllocationRequiredErr: Label 'PIL-import %1 heeft nog aantallen die eerst verdeeld moeten worden. Kies Verdeling controleren en los de open regels op.', Comment = '%1 = import entry number';
        AppliedWorkflowGuidanceTxt: Label 'Dit PIL-dossier is toegepast. Voor een nieuwe tekening importeert u een nieuw PIL-bestand.';
        ApplyImpactSummaryTxt: Label '%1 carrierwijziging(en), waarvan %2 positief; %3 CALC-verdelingsregel(s) worden gecontroleerd en waar nodig vervangen.', Comment = '%1 = aantal carrierwijzigingen, %2 = aantal positieve wijzigingen, %3 = aantal CALC-verdelingsregels';
        AmbiguousChildOrderErr: Label 'Component %1 heeft meer dan één gekoppelde productieorderregel en kan daardoor niet veilig worden geanalyseerd.', Comment = '%1 = component item number';
        AmbiguousStructuralCALCRouteErr: Label 'AutoCAD-artikel %1 zit zowel onder structurele driver %2 als via de losse CALC-route onder carrier %3 (CALC-placeholder %4). De PIL bevat geen bovenliggende context; verdeel dit eerst eenduidig in de productieorder.', Comment = '%1 = AutoCAD item number, %2 = structural driver item number, %3 = loose carrier item number, %4 = CALC placeholder item number';
        AutomaticResidualResolutionTxt: Label 'Automatisch gecorrigeerd naar het nog niet gedekte aantal';
        AutomaticResolutionTxt: Label 'Automatisch';
        BrokenSuppliedByLinkErr: Label 'Component %1 heeft een kapotte koppeling naar de toeleverende productieorderregel. Herstel de productieorderstructuur en bereid de PIL opnieuw voor.', Comment = '%1 = component item number';
        BlockingPILLineStatusTxt: Label 'AutoCAD-artikel %1 vereist nog een keuze. Huidige beslissing: %2. Selecteer deze regel bovenaan en kies Puntartikel verhogen, Als echt los materiaal toevoegen of Bewust negeren met reden.', Comment = '%1 = AutoCAD item number, %2 = current resolution';
        CALCCarrierMissingErr: Label 'Gekoppeld AutoCAD-artikel %1 heeft in deze productieorder geen carrier met CALC-placeholder %2. Voeg de placeholder toe of controleer de PIL-inrichting.', Comment = '%1 = AutoCAD item number, %2 = CALC item number';
        CALCQuantityMismatchErr: Label 'CALC-placeholder %1 onder carrier %2 is na herberekening niet gelijk aan het verdeelde PIL-aantal. Controleer de carrierstructuur en bereid opnieuw voor.', Comment = '%1 = CALC item number, %2 = carrier item number';
        CALCReplacementTxt: Label 'CALC-vervanging';
        CALCSourceAmbiguousErr: Label 'CALC-placeholder %1 komt %3 keer voor onder carrier %2. De bron kan niet veilig worden vervangen; laat slechts één placeholder over.', Comment = '%1 = CALC item number, %2 = carrier item number, %3 = occurrence count';
        CALCSourceChangedErr: Label 'CALC-placeholder %1 onder carrier %2 is gewijzigd sinds de voorbereiding. Kies PIL voorbereiden opnieuw voordat u toepast.', Comment = '%1 = CALC item number, %2 = carrier item number';
        CALCSourceSuppliesOrderErr: Label 'CALC-placeholder %1 levert zelf een productieorderregel en kan daarom niet veilig worden vervangen. Gebruik een losse CALC-component.', Comment = '%1 = CALC item number';
        CALCSourceUsedByMultipleGroupsErr: Label 'CALC-placeholder %1 onder carrier %2 is aan meerdere PIL-groepen gekoppeld. Gebruik per PIL-groep een eigen CALC-placeholder en bereid daarna opnieuw voor.', Comment = '%1 = CALC item number, %2 = carrier item number';
        CarrierChangedSincePrepareErr: Label 'Carrier %1 is gewijzigd nadat de PIL is voorbereid. Kies PIL voorbereiden opnieuw voordat u toepast.', Comment = '%1 = carrier item number';
        CarrierIdentityChangedErr: Label 'Carrier %1 heeft nu een ander artikel, variant of eenheid dan tijdens de voorbereiding. Kies PIL voorbereiden opnieuw.', Comment = '%1 = carrier item number';
        CarrierConflictStatusTxt: Label 'Carrier %1 heeft een bewuste aantalkeuze nodig. Berekening: %2. Selecteer de carrierregel bij de voorgestelde wijzigingen en kies Kies carrieraantal; vul daar het hele eindtotaal en een reden in.', Comment = '%1 = carrier item number, %2 = calculation details';
        CarrierQuantityChoiceAppliedTxt: Label 'Tegenstrijdige drivers; gekozen carrieraantal %1', Comment = '%1 = consciously chosen carrier quantity';
        CarrierQuantityChoiceBelowMinimumErr: Label 'Het gekozen aantal %2 voor carrier %1 is lager dan het veilig berekende minimum %3. Kies minimaal %3 of bereid de PIL opnieuw voor.', Comment = '%1 = carrier item number, %2 = chosen carrier quantity, %3 = calculated minimum carrier quantity';
        CarrierQuantityChoiceReasonErr: Label 'Vul een duidelijke reden in waarom dit carrieraantal leidend moet zijn.';
        CarrierQuantityChoiceNotWholeErr: Label 'Het gekozen carrieraantal moet een heel aantal STUKS zijn.';
        CarrierQuantityChoiceRequiredTxt: Label 'Actie vereist: kies het leidende carrieraantal';
        CarrierQuantityMismatchErr: Label 'Carrier %1 kan niet exact worden weergegeven met de berekende hoeveelheid van de productiecomponent. Controleer de eenheid en aantallen.', Comment = '%1 = carrier item number';
        CarrierReservedErr: Label 'Carrier %1 heeft een voorraadreservering en kan niet veilig worden gewijzigd. Hef de reservering op of gebruik een nieuwe productieorder.', Comment = '%1 = carrier item number';
        ComponentConsumedErr: Label 'Productiecomponent %1 heeft al geboekte verbruik. Gebruik een nieuwe productieorder of laat planning beoordelen.', Comment = '%1 = item number';
        ComponentCarrierNowLinkedErr: Label 'Componentcarrier %1 is nu gekoppeld aan een productieorderregel. Kies PIL voorbereiden opnieuw.', Comment = '%1 = component item number';
        ComponentPickedErr: Label 'Productiecomponent %1 zit al in een magazijnpick. Maak de pick ongedaan of gebruik een nieuwe productieorder.', Comment = '%1 = item number';
        ComponentReservedErr: Label 'Productiecomponent %1 heeft een voorraadreservering. Hef de reservering op voordat u de PIL toepast.', Comment = '%1 = item number';
        ConflictingDriversErr: Label 'Carrier %1 krijgt tegenstrijdige gewenste aantallen uit de PIL. Controleer de verdeling voordat u toepast.', Comment = '%1 = carrier item number';
        CircularProductionBOMErr: Label 'Productie-BOM %1 bevat een cirkel en kan niet veilig voor PIL worden geanalyseerd.', Comment = '%1 = production BOM number';
        CrossOrderChildErr: Label 'Component %1 is gekoppeld aan een productieorder buiten dit PIL-dossier en kan niet veilig worden geanalyseerd.', Comment = '%1 = component item number';
        CoveredPILLineCannotBeIgnoredErr: Label 'AutoCAD-artikel %1 wordt al gedekt door structurele driver %2 en kan daarom niet bewust worden genegeerd. Controleer de productieorderstructuur of bereid de PIL opnieuw voor.', Comment = '%1 = AutoCAD item number, %2 = structural driver item number';
        CoveredByDriverTxt: Label 'Gedekt door structurele carrier';
        DirectComponentAdditionTxt: Label 'Wordt als los productiecomponent toegevoegd';
        DirectComponentChangedSincePrepareErr: Label 'De bestaande productiecomponent voor AutoCAD-artikel %1 is gewijzigd sinds de voorbereiding. Kies Analyseer opnieuw voordat u veilig doorvoert.', Comment = '%1 = AutoCAD item number';
        DirectComponentOccursMultipleTimesErr: Label 'AutoCAD-artikel %1 staat %3 keer als component onder productieregel %2. Kies een eenduidige productieregel of ruim de dubbele componentregels eerst op.', Comment = '%1 = AutoCAD item number, %2 = production order line item number, %3 = occurrence count';
        DirectComponentItemNotSupportedErr: Label 'AutoCAD-artikel %1 is geen los STUKS-artikel zonder Production BOM. Kies hiervoor een samengesteld carrier-artikel; de app voegt zo''n artikel niet kaal als component toe.', Comment = '%1 = AutoCAD item number';
        DirectComponentNotEligibleErr: Label 'AutoCAD-artikel %1 kan alleen als los component worden toegevoegd wanneer het nog ongekoppeld, positief en niet gedekt is.', Comment = '%1 = AutoCAD item number';
        DirectComponentWrongOrderErr: Label 'De gekozen productieregel valt niet binnen deze PIL-productieorder. Kies een regel van dezelfde productieorder.';
        DuplicateLiveFactorNormalizedTxt: Label 'Actuele productieorder telt %1 per carrier; de geldige Production BOM telt %2. Het BOM-recept is leidend zodat een oude en een nieuwe route niet dubbel worden geteld.', Comment = '%1 = observed live quantity per carrier, %2 = canonical production BOM quantity per carrier';
        DuplicateProductionRoutingLinkErr: Label 'Productieartikel %2 heeft meerdere routingregels met koppeling %1. De uren kunnen niet eenduidig worden bijgewerkt; maak de routing-link uniek en probeer opnieuw.', Comment = '%1 = routing link code, %2 = production order item number';
        EmptyValueTxt: Label '<leeg>';
        ExistingOrderQuantityRetainedTxt: Label 'Bestaand productiecomponent; productieorderhoeveelheid blijft leidend';
        ExistingActualPILComponentChangedErr: Label 'Bestaand echt AutoCAD-component %1 onder carrier %2 is gewijzigd sinds de voorbereiding. Kies Analyseer opnieuw voordat u toepast.', Comment = '%1 = AutoCAD item number, %2 = carrier item number';
        FinishedCarrierErr: Label 'Carrier %1 heeft al gereedgemelde output en kan niet veilig worden gewijzigd. Gebruik een nieuwe productieorder.', Comment = '%1 = carrier item number';
        InformationalGroupHeaderTxt: Label 'Informatieve subconfiguratie; geen productieorderwijziging';
        IgnoredByUserTxt: Label 'Bewust genegeerd met reden';
        IgnoreReasonRequiredErr: Label 'Vul eerst een duidelijke reden in waarom AutoCAD-artikel %1 bewust niet wordt verwerkt.', Comment = '%1 = AutoCAD item number';
        ImportedWorkflowGuidanceTxt: Label 'Stap 1 van 4: kies PIL voorbereiden. Niet-gekoppelde AutoCAD-regels moeten eerst worden ingericht of bewust met reden worden genegeerd.';
        IncompleteAllocationStatusTxt: Label 'AutoCAD-artikel %1 is nog niet volledig verdeeld: nodig %2, verdeeld %3, resterend %4. Vul Naar deze carrier aan en kies daarna opnieuw Verdeling controleren.', Comment = '%1 = AutoCAD item number, %2 = required quantity, %3 = allocated quantity, %4 = remaining quantity';
        IncompleteIgnoreAuditErr: Label 'De negeerregistratie van AutoCAD-artikel %1 is onvolledig. Herstel de regel via Negeerherstel en leg daarna een reden vast.', Comment = '%1 = AutoCAD item number';
        InboundDemandMismatchErr: Label 'Carrier %1 wordt niet exact gevoed door de gekoppelde bovenliggende componenten en kan niet veilig worden gesynchroniseerd. Laat planning de koppeling herstellen.', Comment = '%1 = carrier item number';
        InconsistentCarrierQuantityChoiceErr: Label 'Carrier %1 bevat verschillende handmatige carrieraantalkeuzes. Kies het aantal opnieuw via de PIL-verdeling.', Comment = '%1 = carrier item number';
        InvalidChildLinkErr: Label 'Component %1, variant %2 is gekoppeld aan productieorderartikel %3, variant %4. Artikel en variant moeten identiek zijn; herstel de koppeling.', Comment = '%1 = component item number, %2 = component variant code, %3 = linked production order item number, %4 = linked production order variant code';
        InvalidInboundDemandErr: Label 'Bovenliggende component %1, variant %2 levert productieorderartikel %3, variant %4. Artikel en variant moeten identiek zijn; herstel de koppeling.', Comment = '%1 = parent component item number, %2 = parent component variant code, %3 = production order item number, %4 = production order variant code';
        ManualAllocationTxt: Label 'Handmatige verdeling nodig';
        MissingRoutingLinkForAddedHoursErr: Label 'De gewijzigde productiestructuur bevat extra uren voor routingkoppeling %1, maar productieartikel %2 heeft daarvoor geen productieroutingregel. Voeg de optionele routingregel met tijd 0 toe of herstel de configuratorrouting en probeer opnieuw.', Comment = '%1 = routing link code, %2 = production order item number';
        MappedPILLineCannotBeIgnoredErr: Label 'AutoCAD-artikel %1 is al gekoppeld aan een PIL-groep. Los de inrichting of productieorderstructuur op; alleen niet-gekoppelde regels kunnen bewust worden genegeerd.', Comment = '%1 = AutoCAD item number';
        NegativeCarrierQuantityChoiceErr: Label 'Het gekozen carrieraantal mag niet negatief zijn.';
        NoCarrierQuantityConflictErr: Label 'Carrier %1 heeft geen open conflict waarvoor een carrieraantal gekozen hoeft te worden.', Comment = '%1 = carrier item number';
        NoPointCarrierItemForBOMErr: Label 'AutoCAD-artikel %1 is als BOM-regel gevonden in Production BOM %2, maar geen puntartikel verwijst via het veld Production BOM No. naar deze BOM. Controleer het puntartikel.', Comment = '%1 = AutoCAD item number, %2 = production BOM number';
        NoPointCarrierRelationErr: Label 'Voor AutoCAD-artikel %1 is geen Item- of Production-BOM-regel in een bovenliggende Production BOM gevonden. Controleer het exacte nummer en de geldige BOM waarin het artikel thuishoort.', Comment = '%1 = AutoCAD item number';
        NoOrderRoutingHoursFoundMsg: Label 'Er zijn in productieorder %1 geen actuele Non-Inventory-uurcomponenten met een Routing Link Code gevonden. De routing is niet gewijzigd.', Comment = '%1 = production order number';
        NoRoutingHourAdjustmentTxt: Label 'Geen wijziging in de actieve routingtijden.';
        OrderRoutingHoursRecalculatedMsg: Label 'De routinguren van hoofdartikel %1 in productieorder %2 zijn opnieuw opgebouwd uit alle actuele U.-componenten van de order.\Controle per routingcode:\%3', Comment = '%1 = end-item number, %2 = production order number, %3 = routing impact summary';
        RecalculateOrderRoutingHoursQst: Label 'Hiermee worden de actieve routinguren van productieorder %1 volledig opnieuw opgebouwd uit alle actuele U.-componenten met een Routing Link Code. Een genest uur telt mee als Quantity per maal het aantal van zijn productieregel: het equivalent van Qty. per Top Item. Handmatig ingevulde tijden op die koppelingen worden overschreven; optionele stappen met tijd nul blijven nul.\Voorgestelde uren per geproduceerd hoofdartikel:\%2\Doorgaan?', Comment = '%1 = production order number, %2 = routing-hours preview';
        RoutingPreviewLineTxt: Label '%1: oud %2; nieuw %3; verschil %4 %5', Comment = '%1 = routing link code, %2 = current hours per output, %3 = proposed hours per output, %4 = difference, %5 = capacity unit of measure';
        InactiveRoutingPreviewLineTxt: Label '%1: blijft uit; berekend U.-totaal is %2 %3 maar de huidige routingtijd is nul.', Comment = '%1 = routing link code, %2 = calculated hours per output, %3 = capacity unit of measure';
        RoutingPreviewTruncatedTxt: Label '… overige routingkoppelingen staan in het productieroutingscherm.';
        RoutingImpactLineTxt: Label '%1: route %2 -> %3 %4 (verschil in live U.-componenten %5)', Comment = '%1 = routing link code, %2 = current routing hours per output, %3 = new routing hours per output, %4 = capacity unit of measure, %5 = live U-component hours difference';
        RoutingImpactTruncatedTxt: Label ' … overige routingwijzigingen staan in het productieroutingscherm.';
        RoutingChangedAfterPreviewErr: Label 'Productieorder %1 is gewijzigd nadat de routingpreview is bevestigd. Er is niets aangepast. Kies Routinguren opnieuw berekenen nogmaals en controleer het actuele voorstel.', Comment = '%1 = production order number';
        AmbiguousOrderRoutingOwnerErr: Label 'Productieorder %1 heeft niet precies één veilige bovenste routing-eigenaar. De routinguren zijn niet gewijzigd. Controleer het hoofdartikel en de interne productiestructuur.', Comment = '%1 = production order number';
        ResolvedPILLineCannotBeIgnoredErr: Label 'AutoCAD-artikel %1 heeft al een verdeelregel. Bereid de PIL eerst opnieuw voor; alleen niet-gebruikte regels kunnen bewust worden genegeerd.', Comment = '%1 = AutoCAD item number';
        SelectedPILLinesDifferentHeadersErr: Label 'De geselecteerde AutoCAD-regels horen niet bij hetzelfde PIL-dossier. Selecteer alleen regels uit de huidige import.';
        NotUsedTxt: Label 'Niet gebruikt op deze productieorder';
        OpenProductionJournalErr: Label 'Productieorder %2 heeft nog een open productiejournaalregel voor %1. Boek of verwijder die journaalregel eerst en kies daarna PIL toepassen opnieuw.', Comment = '%1 = production order item number, %2 = production order number';
        PiecesUnitOfMeasureLbl: Label 'STUKS';
        PILCalculationDetailTxt: Label '%1: %2 / %3 = %4', Comment = '%1 = AutoCAD item number, %2 = allocated PIL quantity, %3 = quantity per carrier, %4 = suggested carrier quantity';
        PartiallyCoveredTxt: Label 'Gedeeltelijk gedekt; rest nog verwerken';
        ResidualCarrierSuggestionTxt: Label '%1 van %2 is al door hogere carriers gedekt. De resterende %3 vraagt bij %4 per carrier om %5 extra; voorgesteld eindtotaal %6.', Comment = '%1 = covered quantity, %2 = total PIL quantity, %3 = remaining allocated quantity, %4 = quantity per carrier, %5 = additional whole carriers, %6 = proposed carrier total';
        ResidualPILCalculationDetailTxt: Label '%1: rest %2 / %3 => +%4, totaal %5', Comment = '%1 = AutoCAD item number, %2 = residual PIL quantity, %3 = quantity per carrier, %4 = additional whole carriers, %5 = total suggested carrier quantity';
        PILItemNoLongerExistsErr: Label 'Artikel %1 bestaat niet meer in Business Central. Werk de PIL-inrichting of productieorder bij en bereid het dossier opnieuw voor.', Comment = '%1 = item number';
        PointCarrierAdditionTxt: Label 'Puntartikel wordt met volledige Production BOM toegevoegd';
        PointCarrierAlreadyAddedErr: Label 'Puntartikel %1 is na de voorbereiding al aan de productieorder toegevoegd. Kies Analyseer opnieuw voordat u toepast.', Comment = '%1 = point carrier item number';
        PointCarrierBOMFieldMismatchErr: Label 'Puntartikel %1 bestaat, maar het veld Production BOM No. bevat %3 in plaats van %2. Kies Puntartikel verhogen opnieuw; de app kan deze koppeling na uw bevestiging herstellen.', Comment = '%1 = point carrier item number, %2 = expected production BOM number, %3 = current production BOM number';
        PointCarrierBOMNotCertifiedForOrderErr: Label 'Puntartikel %1 is gevonden, maar Production BOM %2 heeft geen gecertificeerde versie die geldig is op een datum van deze productieorder. Certificeer de juiste BOM of versie en open de PIL opnieuw.', Comment = '%1 = point carrier item number, %2 = production BOM number';
        PointCarrierDoesNotContainItemErr: Label 'Puntartikel %1 bevat AutoCAD-artikel %2 niet in de geldige Production BOM. Kies een ander puntartikel of controleer de BOM.', Comment = '%1 = point carrier item number, %2 = AutoCAD item number';
        PointCarrierInactiveBOMLinesErr: Label 'Puntartikel %1 en zijn Production BOM zijn gevonden en gecertificeerd, maar AutoCAD-artikel %2 staat niet op een BOM-regel die geldig is op een datum van deze productieorder. Controleer BOM-versie en begin-/einddatum van de regel.', Comment = '%1 = point carrier item number, %2 = AutoCAD item number';
        PointCarrierItemChangedErr: Label 'Puntartikel %1 of de gekoppelde Production BOM is gewijzigd na de voorbereiding. Kies Analyseer opnieuw.', Comment = '%1 = point carrier item number';
        PointCarrierItemNotSupportedErr: Label 'Puntartikel %1 moet een productievoorraadartikel in STUKS zijn met een gecertificeerde Production BOM.', Comment = '%1 = point carrier item number';
        PointCarrierLinkChangedDuringConfirmationErr: Label 'De Production BOM-koppeling van puntartikel %1 is door iemand anders gewijzigd terwijl u de bevestiging bekeek. Er is niets aangepast; kies Puntartikel verhogen opnieuw.', Comment = '%1 = point carrier item number';
        PointCarrierLinkNeedsReviewTxt: Label 'Production BOM-koppeling moet eerst worden gecontroleerd';
        PointCarrierLinkReadyTxt: Label 'Koppeling gereed';
        PointCarrierLinkWillBeRepairedTxt: Label 'Wordt na bevestiging gekoppeld aan Production BOM %1', Comment = '%1 = production BOM number';
        PointCarrierOccursMultipleTimesUnderLineErr: Label 'Puntartikel %1 komt meerdere keren voor onder productieregel %2. Kies een andere werkregel of laat planning de dubbele componentregels eerst opschonen.', Comment = '%1 = point carrier item number, %2 = destination production order line item number';
        PointCarrierWrongReplenishmentErr: Label 'Puntartikel %1 is gevonden, maar Aanvulsysteem is niet Productieorder. Pas de artikelinrichting aan voordat u dit puntartikel gebruikt.', Comment = '%1 = point carrier item number';
        PointCarrierWrongTypeErr: Label 'Puntartikel %1 is gevonden, maar Artikelsoort is niet Voorraad. Pas de artikelinrichting aan voordat u dit puntartikel gebruikt.', Comment = '%1 = point carrier item number';
        PointCarrierWrongUnitErr: Label 'Puntartikel %1 is gevonden, maar basiseenheid is %2 in plaats van STUKS. De AutoCAD-PIL kan deze carrier niet veilig omrekenen.', Comment = '%1 = point carrier item number, %2 = base unit of measure code';
        RepairPointCarrierProductionBOMQst: Label 'Puntartikel %1 verwijst nu naar Production BOM %2. Production BOM %3 bevat AutoCAD-artikel %4.\Wilt u het artikel permanent aan Production BOM %3 koppelen en daarna doorgaan? Deze artikelinrichting geldt ook voor toekomstige productieorders.', Comment = '%1 = point carrier item number, %2 = current production BOM number or empty, %3 = proposed production BOM number, %4 = AutoCAD item number';
        PILDetailsTruncatedTxt: Label ' … (meer in verdeling)';
        PointCarrierDestinationRequiredErr: Label 'Kies eerst onder welk werkgebied of welke subconfiguratie puntartikel %1 moet worden toegevoegd. De app plaatst een nieuw puntartikel niet automatisch onder het hoofdartikel.', Comment = '%1 = point carrier item number';
        PreparedNoChangesWorkflowGuidanceTxt: Label 'Deze PIL is al volledig in de huidige productieorder verwerkt of bevat alleen bewust genegeerde regels. Toepassen legt het dossier als compleet vast zonder dezelfde productieorderwijzigingen opnieuw uit te voeren.';
        PreparedWorkflowGuidanceTxt: Label 'Stap 3 van 4: controleer het wijzigingsvoorstel. Voeg positieve meerwerkregels eventueel toe aan een offerte en kies daarna Toepassen op productieorder.';
        ProductionRoutingPostedActivityErr: Label 'De routing van productieorder %2 voor %1 heeft al geboekte output, scrap of capaciteit. De PIL-wijziging is geblokkeerd; maak een nieuw productieorder of laat planning beoordelen.', Comment = '%1 = production order item number, %2 = production order number';
        ProductionRoutingStartedErr: Label 'De routing van productieorder %2 voor %1 is al gestart of gereedgemeld. De PIL-wijziging is geblokkeerd; laat planning eerst beoordelen.', Comment = '%1 = production order item number, %2 = production order number';
        RoutingHourTotalInvalidErr: Label 'Het actuele U.-urentotaal voor routingkoppeling %1 onder productieartikel %2 is negatief. Controleer de productiecomponenten voordat u de PIL toepast.', Comment = '%1 = routing link code, %2 = production order item number';
        ProductionBOMMissingErr: Label 'Productie-BOM %1 van de carrier bestaat niet. Herstel de artikel- of BOM-inrichting en bereid de PIL opnieuw voor.', Comment = '%1 = production BOM number';
        ProductionBOMNotCertifiedErr: Label 'Productie-BOM %1 heeft geen gecertificeerde versie die voor deze productieorder gebruikt kan worden. Certificeer de juiste BOM-versie.', Comment = '%1 = production BOM number';
        ProductionBOMTooDeepErr: Label 'Productie-BOM %1 is dieper dan veilig voor de PIL-analyse. Laat engineering of planning de structuur beoordelen.', Comment = '%1 = production BOM number';
        ProductionOrderTraversalTooLargeErr: Label 'Productieorder %1 heeft een te diepe of te grote gekoppelde productiestructuur voor een veilige PIL-analyse. Laat planning de structuur eerst controleren.', Comment = '%1 = production order number';
        ProposalTransferredErr: Label 'PIL-import %1 heeft al wijzigingsregels op een offerte. Importeer de PIL opnieuw om een nieuw technisch voorstel te maken.', Comment = '%1 = import entry number';
        ProposalMustBeCheckedErr: Label 'PIL-import %1 is gewijzigd of nog niet gecontroleerd. Kies eerst Verdeling controleren voordat u toepast.', Comment = '%1 = import entry number';
        QuotedProposalChangedErr: Label 'Het technische PIL-voorstel voor %1 komt niet meer overeen met de wijziging op de offerte. Importeer de PIL opnieuw voordat u toepast.', Comment = '%1 = carrier item number or production order number';
        ReplacementQuantityMismatchErr: Label 'AutoCAD-artikel %1 kan niet exact als productiecomponenthoeveelheid worden weergegeven. Controleer de aantallen en eenheden.', Comment = '%1 = AutoCAD item number';
        StructuralDriverChangedErr: Label 'Structureel AutoCAD-artikel %1 onder carrier %2 is gewijzigd na de voorbereiding. Kies PIL voorbereiden opnieuw.', Comment = '%1 = AutoCAD structural item number, %2 = carrier item number';
        StructuralDriverTxt: Label 'Structurele carrierdriver';
        UnsupportedBOMLineErr: Label 'Productie-BOM-regel %1 gebruikt een functie die niet veilig met de PIL-master-BOM-analyse kan worden verwerkt. Gebruik een eenvoudige STUKS-regel of pas de BOM aan.', Comment = '%1 = production BOM component number';
        UnsupportedBOMLineUnitOfMeasureErr: Label 'Productie-BOM-regel %1 gebruikt eenheid %2. AutoCAD PIL is eenheidsloos en ondersteunt hier alleen STUKS zonder omrekening.', Comment = '%1 = production BOM component number, %2 = unit of measure code';
        UnsupportedBOMPiecesUnitOfMeasureErr: Label 'Productie-BOM %1 gebruikt eenheid %2. AutoCAD PIL is eenheidsloos en ondersteunt hier alleen STUKS zonder omrekening.', Comment = '%1 = production BOM number, %2 = unit of measure code';
        UnsupportedBOMUnitOfMeasureErr: Label 'Productie-BOM %1 gebruikt eenheid %3 terwijl de carrier of bovenliggende regel %2 gebruikt. Deze master-BOM-route kan niet veilig worden geanalyseerd.', Comment = '%1 = production BOM number, %2 = carrier or parent unit of measure, %3 = production BOM unit of measure';
        UnsupportedOrderStatusErr: Label 'Productieorder %1 moet de status Gesimuleerd, Vast gepland of Vrijgegeven hebben.', Comment = '%1 = production order number';
        UnsupportedHiddenRoutingBOMLineErr: Label 'Production BOM %1 bevat op regel %2 afval of de formule Vast aantal. Daardoor kan het routingtotaal van deze niet-uitgevouwen component niet veilig per hoofdartikel worden berekend. Pas de BOM aan of laat BluAce de route herstellen; er is niets gewijzigd.', Comment = '%1 = production BOM number, %2 = production BOM component number';
        UnsupportedCarrierUnitOfMeasureErr: Label 'Carrier %1 gebruikt eenheid %2 of een omrekenfactor. AutoCAD PIL kan alleen STUKS zonder omrekening verwerken. Pas de carrier of gebruik een aparte inrichting.', Comment = '%1 = carrier item or BOM number, %2 = unit of measure code';
        UnsupportedComponentUnitOfMeasureErr: Label 'Productiecomponent %1 gebruikt eenheid %2 of een omrekenfactor. AutoCAD PIL kan alleen STUKS zonder omrekening verwerken.', Comment = '%1 = component item number, %2 = unit of measure code';
        UnsupportedPILItemUnitOfMeasureErr: Label 'AutoCAD-artikel %1 heeft basis-eenheid %2. AutoCAD PIL kan alleen artikelen in STUKS zonder omrekening verwerken.', Comment = '%1 = AutoCAD item number, %2 = base unit of measure';
        UnresolvedCarrierQuantityConflictErr: Label 'Carrier %1 heeft tegenstrijdige drivers. Open de verdeling, selecteer de juiste driver en kies Kies carrieraantal voordat u toepast.', Comment = '%1 = carrier item number';
        LinkedOrderUnitOfMeasureErr: Label 'Gekoppelde productieorder voor %1 gebruikt eenheid %3 terwijl de bovenliggende component %2 gebruikt. AutoCAD PIL kan deze omrekening niet veilig uitvoeren.', Comment = '%1 = item number, %2 = parent component unit of measure code, %3 = child production order unit of measure code';
        ZeroCarrierQuantityErr: Label 'Carrier %1 heeft hoeveelheid nul en kan niet met de PIL worden afgestemd. Corrigeer de productieorderhoeveelheid eerst.', Comment = '%1 = carrier item number';
        ZeroQuantityPerErr: Label 'AutoCAD-artikel %1 heeft hoeveelheid nul per carrier %2. Controleer de productieorderstructuur of BOM.', Comment = '%1 = AutoCAD item number, %2 = carrier item number';
        ZeroQuantityTxt: Label 'Hoeveelheid nul genegeerd';
        ZeroQuantityCannotBeIgnoredErr: Label 'AutoCAD-artikel %1 heeft hoeveelheid nul en hoeft niet bewust te worden genegeerd.', Comment = '%1 = AutoCAD item number';
}
