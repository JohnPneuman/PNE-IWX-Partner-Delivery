namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Inventory.Item;

codeunit 50192 "PNE PIL Cost Mgt."
{
    Permissions =
        tabledata "PNE PIL Group" = rm,
        tabledata "PNE PIL Group Item" = r,
        tabledata Item = rm;

    procedure RecalculateGroupCost(var PNEPILGroup: Record "PNE PIL Group"; var WarningText: Text): Boolean
    var
        CALCItem: Record Item;
        Item: Record Item;
        PNEPILGroupItem: Record "PNE PIL Group Item";
        ActiveItemCount: Integer;
        PreviewWarningText: Text;
        ProposedUnitCost: Decimal;
        UsedCostSum: Decimal;
    begin
        Clear(WarningText);
        PNEPILGroup.TestField("CALC Item No.");
        PNEPILGroupItem.SetRange("Group Code", PNEPILGroup.Code);
        PNEPILGroupItem.SetRange(Enabled, true);
        if PNEPILGroupItem.FindSet() then
            repeat
                if not Item.Get(PNEPILGroupItem."Item No.") then
                    Error(GroupItemNotFoundErr, PNEPILGroupItem."Item No.", PNEPILGroup.Code);
                EnsurePiecesUnitOfMeasure(Item, PNEPILGroup.Code, false);
                ActiveItemCount += 1;
                UsedCostSum += Item."Unit Cost";
                AddWarnings(Item, WarningText);
            until PNEPILGroupItem.Next() = 0;
        if ActiveItemCount = 0 then
            Error(NoActiveItemsErr, PNEPILGroup.Code);

        if not CALCItem.Get(PNEPILGroup."CALC Item No.") then
            Error(CALCItemNotFoundErr, PNEPILGroup."CALC Item No.", PNEPILGroup.Code);
        CALCItem.TestField(Type, CALCItem.Type::"Non-Inventory");
        EnsurePiecesUnitOfMeasure(CALCItem, PNEPILGroup.Code, true);
        ProposedUnitCost := UsedCostSum / ActiveItemCount;
        PreviewWarningText := WarningText;
        if PreviewWarningText = '' then
            PreviewWarningText := NoWarningsTxt;
        if not Confirm(
                CostPreviewQst,
                false,
                PNEPILGroup.Code,
                CALCItem."No.",
                CALCItem."Unit Cost",
                ProposedUnitCost,
                ActiveItemCount,
                UsedCostSum,
                PreviewWarningText)
        then
            exit(false);

        CALCItem.Validate("Unit Cost", ProposedUnitCost);
        CALCItem.Modify(true);

        PNEPILGroup."Active Item Count" := ActiveItemCount;
        PNEPILGroup."Used Cost Sum" := UsedCostSum;
        PNEPILGroup."Average Unit Cost" := CALCItem."Unit Cost";
        PNEPILGroup."Last Cost Recalculated At" := CurrentDateTime();
        PNEPILGroup.Modify(true);
        exit(true);
    end;

    local procedure AddWarnings(Item: Record Item; var WarningText: Text)
    begin
        if Item."Unit Cost" = 0 then
            AddWarning(WarningText, ZeroCostWarningLbl, Item."No.");
    end;

    local procedure EnsurePiecesUnitOfMeasure(Item: Record Item; GroupCode: Code[20]; IsCALCItem: Boolean)
    begin
        if Item."Base Unit of Measure" = PiecesUnitOfMeasureLbl then
            exit;

        if IsCALCItem then
            Error(CALCUnitOfMeasureErr, Item."No.", GroupCode, Item."Base Unit of Measure");
        Error(GroupItemUnitOfMeasureErr, Item."No.", GroupCode, Item."Base Unit of Measure");
    end;

    local procedure AddWarning(var WarningText: Text; WarningLbl: Text; FirstValue: Text)
    begin
        if WarningText <> '' then
            WarningText += '\\';
        WarningText += StrSubstNo(WarningLbl, FirstValue);
    end;

    var
        CALCItemNotFoundErr: Label 'CALC-placeholder %1 van PIL-groep %2 bestaat niet meer.', Comment = '%1 = CALC item number, %2 = PIL group code';
        CALCUnitOfMeasureErr: Label 'CALC-placeholder %1 van PIL-groep %2 heeft basiseenheid %3. AutoCAD-PIL-aantallen zijn STUKS; wijzig de basiseenheid naar STUKS voordat je de kostprijs herberekent.', Comment = '%1 = CALC item number, %2 = PIL group code, %3 = base unit of measure';
        CostPreviewQst: Label 'PIL-groep %1 werkt CALC-placeholder %2 bij.\Huidige kostprijs: %3\Nieuwe gemiddelde kostprijs: %4\Actieve echte artikelen: %5\Totaal van de kostprijzen: %6\Waarschuwingen:\%7\\Doorgaan en het CALC-artikel bijwerken?', Comment = '%1 = PIL group code, %2 = CALC item number, %3 = current unit cost, %4 = proposed unit cost, %5 = active item count, %6 = total unit cost, %7 = warnings';
        GroupItemNotFoundErr: Label 'Actief PIL-artikel %1 van PIL-groep %2 bestaat niet meer.', Comment = '%1 = AutoCAD item number, %2 = PIL group code';
        GroupItemUnitOfMeasureErr: Label 'PIL-artikel %1 van PIL-groep %2 heeft basiseenheid %3. AutoCAD-PIL-aantallen zijn STUKS; wijzig de basiseenheid naar STUKS voordat je de kostprijs herberekent.', Comment = '%1 = AutoCAD item number, %2 = PIL group code, %3 = base unit of measure';
        NoActiveItemsErr: Label 'PIL-groep %1 heeft geen actieve echte artikelen.', Comment = '%1 = PIL group code';
        NoWarningsTxt: Label 'Geen.';
        PiecesUnitOfMeasureLbl: Label 'STUKS';
        ZeroCostWarningLbl: Label 'Artikel %1 heeft een kostprijs van nul.', Comment = '%1 = item number';
}
