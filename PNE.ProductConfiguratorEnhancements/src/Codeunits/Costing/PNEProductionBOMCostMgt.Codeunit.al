namespace Pneuman.ProductConfigurator;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.ProductionBOM;

codeunit 50104 "PNE Production BOM Cost Mgt."
{
    // Berekent uitsluitend de non-inventory kosten.
    //
    // De normale inventory-kosten zijn al door IWX berekend
    // en staan al in IWXCfgOptionChoicev3."Unit Cost".
    procedure CalculateNonInventoryBOMCost(
        ProductionBOMNo: Code[20];
        CalculationDate: Date): Decimal
    var
        BOMPath: List of [Code[20]];
    begin
        exit(
            CalculateNonInventoryBOMCost(
                ProductionBOMNo,
                CalculationDate,
                BOMPath));
    end;


    local procedure CalculateNonInventoryBOMCost(
        ProductionBOMNo: Code[20];
        CalculationDate: Date;
        var BOMPath: List of [Code[20]]): Decimal
    var
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMLine: Record "Production BOM Line";
        VersionManagement: Codeunit VersionManagement;
        VersionCode: Code[20];
        TotalCost: Decimal;
    begin
        if ProductionBOMNo = '' then
            exit(0);

        // Beveiliging tegen een circulaire BOM:
        // BOM-A bevat BOM-B en BOM-B bevat weer BOM-A.
        if BOMPath.Contains(ProductionBOMNo) then
            Error(
                'Circulaire Production BOM gevonden bij %1.',
                ProductionBOMNo);

        if not ProductionBOMHeader.Get(ProductionBOMNo) then
            exit(0);

        BOMPath.Add(ProductionBOMNo);

        // Bepaal de actieve gecertificeerde versie.
        VersionCode :=
            VersionManagement.GetBOMVersion(
                ProductionBOMNo,
                CalculationDate,
                true);

        // Wanneer geen gecertificeerde versie bestaat,
        // mogen alleen de regels van een gecertificeerde
        // BOM-header worden gebruikt.
        if VersionCode = '' then
            if ProductionBOMHeader.Status <>
               ProductionBOMHeader.Status::Certified
            then begin
                BOMPath.Remove(ProductionBOMNo);
                exit(0);
            end;

        ProductionBOMLine.Reset();
        ProductionBOMLine.SetRange(
            "Production BOM No.",
            ProductionBOMNo);
        ProductionBOMLine.SetRange(
            "Version Code",
            VersionCode);

        // Alleen regels gebruiken die op de berekeningsdatum geldig zijn.
        ProductionBOMLine.SetFilter(
            "Starting Date",
            '%1|..%2',
            0D,
            CalculationDate);

        ProductionBOMLine.SetFilter(
            "Ending Date",
            '%1|%2..',
            0D,
            CalculationDate);

        if ProductionBOMLine.FindSet() then
            repeat
                TotalCost +=
                    CalculateNonInventoryBOMLineCost(
                        ProductionBOMLine,
                        CalculationDate,
                        BOMPath);
            until ProductionBOMLine.Next() = 0;

        BOMPath.Remove(ProductionBOMNo);

        exit(TotalCost);
    end;


    local procedure CalculateNonInventoryBOMLineCost(
        ProductionBOMLine: Record "Production BOM Line";
        CalculationDate: Date;
        var BOMPath: List of [Code[20]]): Decimal
    var
        ComponentItem: Record Item;
        LineQuantity: Decimal;
        ChildBOMCost: Decimal;
    begin
        if ProductionBOMLine."No." = '' then
            exit(0);

        LineQuantity :=
            GetBOMLineCostQuantity(
                ProductionBOMLine);

        case ProductionBOMLine.Type of
            ProductionBOMLine.Type::Item:
                begin
                    if not ComponentItem.Get(
                        ProductionBOMLine."No.")
                    then
                        exit(0);

                    if ComponentItem.Type <>
                       ComponentItem.Type::"Non-Inventory"
                    then
                        exit(0);

                    // Item Unit Cost is per basiseenheid.
                    // Daarom wordt de hoeveelheid in de BOM-UOM
                    // omgerekend naar de basiseenheid.
                    exit(
                        ComponentItem."Unit Cost" *
                        ProductionBOMLine.GetQtyPerUnitOfMeasure() *
                        LineQuantity);
                end;

            ProductionBOMLine.Type::"Production BOM":
                begin
                    ChildBOMCost :=
                        CalculateNonInventoryBOMCost(
                            ProductionBOMLine."No.",
                            CalculationDate,
                            BOMPath);

                    exit(
                        ChildBOMCost *
                        LineQuantity);
                end;
        end;

        exit(0);
    end;


    local procedure GetBOMLineCostQuantity(
        ProductionBOMLine: Record "Production BOM Line"): Decimal
    var
        CostQuantity: Decimal;
    begin
        // Quantity wordt door Business Central al opgebouwd uit:
        // Quantity per, Length, Width, Depth, Weight
        // en de gekozen Calculation Formula.
        CostQuantity :=
            ProductionBOMLine.Quantity;

        // Bij Fixed Quantity wordt Scrap % door
        // Business Central genegeerd.
        if ProductionBOMLine."Calculation Formula" <>
           ProductionBOMLine."Calculation Formula"::"Fixed Quantity"
        then
            CostQuantity *=
                1 + (ProductionBOMLine."Scrap %" / 100);

        exit(CostQuantity);
    end;
}
