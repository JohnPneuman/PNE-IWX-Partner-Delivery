namespace Pneuman.ProductionOrderReconciliation;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;

codeunit 50199 "PNE PO Config. Structure Mgt."
{
    procedure OpenForProductionOrder(ProductionOrder: Record "Production Order")
    var
        TempProductionBOMLine: Record "Production BOM Line" temporary;
        PNEPOConfigurationStructure: Page "PNE PO Configuration Structure";
        MainBOMSourceTxt: Text[250];
        ProductionOrderTxt: Text[250];
        StructureSourceTxt: Text[250];
    begin
        BuildStructure(ProductionOrder, TempProductionBOMLine, ProductionOrderTxt, MainBOMSourceTxt, StructureSourceTxt);
        PNEPOConfigurationStructure.SetStructure(TempProductionBOMLine, ProductionOrderTxt, MainBOMSourceTxt, StructureSourceTxt);
        PNEPOConfigurationStructure.Run();
    end;

    local procedure BuildStructure(ProductionOrder: Record "Production Order"; var TempProductionBOMLine: Record "Production BOM Line" temporary; var ProductionOrderTxt: Text[250]; var MainBOMSourceTxt: Text[250]; var StructureSourceTxt: Text[250])
    var
        ProdOrderLine: Record "Prod. Order Line";
        BOMPath: List of [Code[20]];
        CalculationDate: Date;
        FirstProductionBOMNo: Code[20];
        FirstProductionBOMVersionCode: Code[20];
        HasMultipleMainBOMs: Boolean;
        ProductionBOMNo: Code[20];
    begin
        TempProductionBOMLine.Reset();
        TempProductionBOMLine.DeleteAll();
        DisplayedLineCount := 0;
        DisplayLimitReached := false;
        StructureLineNo := 0;
        Clear(FirstProductionBOMNo);
        Clear(FirstProductionBOMVersionCode);
        Clear(HasMultipleMainBOMs);

        ProductionOrderTxt := StrSubstNo(ProductionOrderTxtLbl, Format(ProductionOrder.Status), ProductionOrder."No.");
        StructureSourceTxt := StrSubstNo(StructureSourceTxtLbl, Format(WorkDate()));

        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if not ProdOrderLine.FindSet() then
            Error(NoProductionOrderLinesErr, ProductionOrder."No.");

        repeat
            AddProductionOrderRoot(TempProductionBOMLine, ProdOrderLine);
            ProductionBOMNo := ProdOrderLine."Production BOM No.";
            CalculationDate := GetCalculationDate(ProdOrderLine);
            if ProductionBOMNo = '' then
                AddInformationLine(TempProductionBOMLine, 1, MissingRootBOMTxt)
            else begin
                if FirstProductionBOMNo = '' then begin
                    FirstProductionBOMNo := ProductionBOMNo;
                    FirstProductionBOMVersionCode := ProdOrderLine."Production BOM Version Code";
                end else
                    if (FirstProductionBOMNo <> ProductionBOMNo) or
                       (FirstProductionBOMVersionCode <> ProdOrderLine."Production BOM Version Code")
                    then
                        HasMultipleMainBOMs := true;
                AddProductionBOMLines(
                    TempProductionBOMLine,
                    ProductionBOMNo,
                    CalculationDate,
                    ProdOrderLine."Production BOM Version Code",
                    true,
                    1,
                    true,
                    BOMPath);
            end;
        until ProdOrderLine.Next() = 0;

        SetMainBOMSourceText(FirstProductionBOMNo, FirstProductionBOMVersionCode, HasMultipleMainBOMs, MainBOMSourceTxt);
    end;

    local procedure AddProductionOrderRoot(var TempProductionBOMLine: Record "Production BOM Line" temporary; ProdOrderLine: Record "Prod. Order Line")
    begin
        AddDisplayLine(
            TempProductionBOMLine,
            RootRoleTok,
            ProdOrderLine."Item No.",
            ProdOrderLine.Description,
            ProdOrderLine.Quantity,
            ProdOrderLine."Unit of Measure Code",
            '',
            0);
    end;

    local procedure AddProductionBOMLines(var TempProductionBOMLine: Record "Production BOM Line" temporary; ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; Level: Integer; ShowProductionBOMHeader: Boolean; var BOMPath: List of [Code[20]])
    var
        ProductionBOMLine: Record "Production BOM Line";
        ChildProductionBOMNo: Code[20];
        ComponentLevel: Integer;
        ResolvedVersionCode: Code[20];
    begin
        if DisplayLimitReached then
            exit;
        if BOMPath.Contains(ProductionBOMNo) then begin
            AddInformationLine(TempProductionBOMLine, Level, StrSubstNo(CircularBOMTxt, ProductionBOMNo));
            exit;
        end;
        if BOMPath.Count() >= MaximumProductionBOMDepth() then begin
            AddInformationLine(TempProductionBOMLine, Level, StrSubstNo(ProductionBOMTooDeepTxt, ProductionBOMNo));
            exit;
        end;
        if not SetProductionBOMLineFilters(ProductionBOMNo, CalculationDate, RequestedVersionCode, UseRequestedVersion, ProductionBOMLine, ResolvedVersionCode) then begin
            AddInformationLine(TempProductionBOMLine, Level, StrSubstNo(ProductionBOMUnavailableTxt, ProductionBOMNo));
            exit;
        end;

        BOMPath.Add(ProductionBOMNo);
        ComponentLevel := Level;
        if ShowProductionBOMHeader then begin
            AddProductionBOMHeader(TempProductionBOMLine, ProductionBOMNo, ResolvedVersionCode, Level);
            ComponentLevel += 1;
        end;
        if ProductionBOMLine.FindSet() then
            repeat
                if DisplayLimitReached then begin
                    BOMPath.Remove(ProductionBOMNo);
                    exit;
                end;
                AddProductionBOMLine(TempProductionBOMLine, ProductionBOMLine, ComponentLevel);
                ChildProductionBOMNo := GetChildProductionBOMNo(ProductionBOMLine);
                if ChildProductionBOMNo <> '' then
                    AddProductionBOMLines(
                        TempProductionBOMLine,
                        ChildProductionBOMNo,
                        CalculationDate,
                        '',
                        false,
                        ComponentLevel + 1,
                        ProductionBOMLine.Type = ProductionBOMLine.Type::Item,
                        BOMPath);
            until ProductionBOMLine.Next() = 0;
        BOMPath.Remove(ProductionBOMNo);
    end;

    local procedure AddProductionBOMHeader(var TempProductionBOMLine: Record "Production BOM Line" temporary; ProductionBOMNo: Code[20]; ProductionBOMVersionCode: Code[20]; Level: Integer)
    var
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMDescription: Text[100];
    begin
        if ProductionBOMHeader.Get(ProductionBOMNo) then
            ProductionBOMDescription := ProductionBOMHeader.Description
        else
            ProductionBOMDescription := ProductionBOMNo;
        if ProductionBOMVersionCode <> '' then
            ProductionBOMDescription := CopyStr(StrSubstNo(ProductionBOMHeaderVersionTxt, ProductionBOMDescription, ProductionBOMVersionCode), 1, MaxStrLen(ProductionBOMDescription));

        AddDisplayLine(
            TempProductionBOMLine,
            BOMRoleTok,
            ProductionBOMNo,
            ProductionBOMDescription,
            1,
            ProductionBOMHeader."Unit of Measure Code",
            '',
            Level);
    end;

    local procedure AddProductionBOMLine(var TempProductionBOMLine: Record "Production BOM Line" temporary; ProductionBOMLine: Record "Production BOM Line"; Level: Integer)
    var
        LineRole: Code[10];
    begin
        case ProductionBOMLine.Type of
            ProductionBOMLine.Type::"Production BOM":
                LineRole := BOMRoleTok;
            ProductionBOMLine.Type::Item:
                LineRole := ItemRoleTok;
            else
                LineRole := InformationRoleTok;
        end;

        AddDisplayLine(
            TempProductionBOMLine,
            LineRole,
            ProductionBOMLine."No.",
            ProductionBOMLine.Description,
            ProductionBOMLine.Quantity,
            ProductionBOMLine."Unit of Measure Code",
            ProductionBOMLine."Routing Link Code",
            Level);
    end;

    local procedure AddInformationLine(var TempProductionBOMLine: Record "Production BOM Line" temporary; Level: Integer; InformationTxt: Text)
    var
        InformationDescription: Text[100];
    begin
        InformationDescription := CopyStr(InformationTxt, 1, MaxStrLen(InformationDescription));
        AddDisplayLine(TempProductionBOMLine, InformationRoleTok, '', InformationDescription, 0, '', '', Level);
    end;

    local procedure AddDisplayLine(var TempProductionBOMLine: Record "Production BOM Line" temporary; LineRole: Code[10]; ComponentNo: Code[20]; ComponentDescription: Text[100]; Quantity: Decimal; UnitOfMeasureCode: Code[10]; RoutingLinkCode: Code[10]; Level: Integer)
    begin
        if DisplayedLineCount >= MaximumDisplayedLines() then begin
            if not DisplayLimitReached then begin
                DisplayLimitReached := true;
                InsertDisplayLine(
                    TempProductionBOMLine,
                    InformationRoleTok,
                    '',
                    CopyStr(StrSubstNo(ProductionBOMDisplayLimitTxt, MaximumDisplayedLines()), 1, MaxStrLen(ComponentDescription)),
                    0,
                    '',
                    '',
                    Level);
            end;
            exit;
        end;

        DisplayedLineCount += 1;
        InsertDisplayLine(TempProductionBOMLine, LineRole, ComponentNo, ComponentDescription, Quantity, UnitOfMeasureCode, RoutingLinkCode, Level);
    end;

    local procedure InsertDisplayLine(var TempProductionBOMLine: Record "Production BOM Line" temporary; LineRole: Code[10]; ComponentNo: Code[20]; ComponentDescription: Text[100]; Quantity: Decimal; UnitOfMeasureCode: Code[10]; RoutingLinkCode: Code[10]; Level: Integer)
    begin
        StructureLineNo += 10000;
        TempProductionBOMLine.Init();
        TempProductionBOMLine."Production BOM No." := TemporaryStructureBOMNoTok;
        TempProductionBOMLine."Version Code" := '';
        TempProductionBOMLine."Line No." := StructureLineNo;
        TempProductionBOMLine."No." := ComponentNo;
        TempProductionBOMLine.Description := CreateTreeDescription(LineRole, Level, ComponentDescription);
        TempProductionBOMLine.Quantity := Quantity;
        TempProductionBOMLine."Unit of Measure Code" := UnitOfMeasureCode;
        TempProductionBOMLine."Routing Link Code" := RoutingLinkCode;
        TempProductionBOMLine.Position := LineRole;
        TempProductionBOMLine.Insert(false);
    end;

    local procedure CreateTreeDescription(LineRole: Code[10]; Level: Integer; ComponentDescription: Text[100]): Text[100]
    var
        IndentTxt: Text;
        Index: Integer;
        PrefixTxt: Text;
        TreeDescription: Text[100];
    begin
        for Index := 1 to Level do
            IndentTxt += '  ';

        case LineRole of
            RootRoleTok:
                PrefixTxt := RootPrefixTok;
            BOMRoleTok:
                PrefixTxt := BOMPrefixTok;
            InformationRoleTok:
                PrefixTxt := InformationPrefixTok;
            else
                PrefixTxt := ItemPrefixTok;
        end;

        TreeDescription := CopyStr(IndentTxt + PrefixTxt + ComponentDescription, 1, MaxStrLen(TreeDescription));
        exit(TreeDescription);
    end;

    local procedure SetProductionBOMLineFilters(ProductionBOMNo: Code[20]; CalculationDate: Date; RequestedVersionCode: Code[20]; UseRequestedVersion: Boolean; var ProductionBOMLine: Record "Production BOM Line"; var ResolvedVersionCode: Code[20]): Boolean
    var
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMVersion: Record "Production BOM Version";
        VersionManagement: Codeunit VersionManagement;
    begin
        if not ProductionBOMHeader.Get(ProductionBOMNo) then
            exit(false);

        if UseRequestedVersion and (RequestedVersionCode <> '') then
            ResolvedVersionCode := RequestedVersionCode
        else
            ResolvedVersionCode := VersionManagement.GetBOMVersion(ProductionBOMNo, CalculationDate, true);
        if ResolvedVersionCode <> '' then begin
            if not ProductionBOMVersion.Get(ProductionBOMNo, ResolvedVersionCode) then
                exit(false);
            if (not UseRequestedVersion or (RequestedVersionCode = '')) and
               (ProductionBOMVersion.Status <> ProductionBOMVersion.Status::Certified)
            then
                exit(false);
        end else
            if ProductionBOMHeader.Status <> ProductionBOMHeader.Status::Certified then
                exit(false);

        ProductionBOMLine.Reset();
        ProductionBOMLine.SetRange("Production BOM No.", ProductionBOMNo);
        ProductionBOMLine.SetRange("Version Code", ResolvedVersionCode);
        ProductionBOMLine.SetFilter("Starting Date", '%1|..%2', 0D, CalculationDate);
        ProductionBOMLine.SetFilter("Ending Date", '%1|%2..', 0D, CalculationDate);
        exit(true);
    end;

    local procedure GetChildProductionBOMNo(ProductionBOMLine: Record "Production BOM Line"): Code[20]
    var
        Item: Record Item;
    begin
        case ProductionBOMLine.Type of
            ProductionBOMLine.Type::Item:
                if Item.Get(ProductionBOMLine."No.") then
                    exit(Item."Production BOM No.");
            ProductionBOMLine.Type::"Production BOM":
                exit(ProductionBOMLine."No.");
        end;
        exit('');
    end;

    local procedure GetCalculationDate(ProdOrderLine: Record "Prod. Order Line"): Date
    begin
        if ProdOrderLine."Starting Date" <> 0D then
            exit(ProdOrderLine."Starting Date");
        if ProdOrderLine."Due Date" <> 0D then
            exit(ProdOrderLine."Due Date");
        exit(WorkDate());
    end;

    local procedure SetMainBOMSourceText(FirstProductionBOMNo: Code[20]; FirstProductionBOMVersionCode: Code[20]; HasMultipleMainBOMs: Boolean; var MainBOMSourceTxt: Text[250])
    begin
        if FirstProductionBOMNo = '' then
            MainBOMSourceTxt := NoMainBOMTxt
        else
            if FirstProductionBOMVersionCode = '' then
                MainBOMSourceTxt := StrSubstNo(MainBOMWithoutVersionTxt, FirstProductionBOMNo)
            else
                MainBOMSourceTxt := StrSubstNo(MainBOMWithVersionTxt, FirstProductionBOMNo, FirstProductionBOMVersionCode);

        if HasMultipleMainBOMs then
            MainBOMSourceTxt := CopyStr(MainBOMSourceTxt + ' ' + MultipleMainBOMsTxt, 1, MaxStrLen(MainBOMSourceTxt));
    end;

    local procedure MaximumDisplayedLines(): Integer
    begin
        exit(20000);
    end;

    local procedure MaximumProductionBOMDepth(): Integer
    begin
        exit(50);
    end;

    var
        BOMPrefixTok: Label '+ ', Locked = true;
        BOMRoleTok: Label 'BOM', Locked = true;
        CircularBOMTxt: Label 'Circulaire Production BOM %1 is niet verder uitgeklapt.', Comment = '%1=Production BOM no.';
        InformationPrefixTok: Label '! ', Locked = true;
        InformationRoleTok: Label 'INFO', Locked = true;
        ItemPrefixTok: Label '- ', Locked = true;
        ItemRoleTok: Label 'ITEM', Locked = true;
        MainBOMWithVersionTxt: Label 'BOM %1, vastgelegde versie %2.', Comment = '%1=production BOM no.;%2=production BOM version code';
        MainBOMWithoutVersionTxt: Label 'BOM %1, geen versiecode op de productieorderregel.', Comment = '%1=production BOM no.';
        MissingRootBOMTxt: Label 'Geen Production BOM is op deze productieorderregel vastgelegd.';
        MultipleMainBOMsTxt: Label 'Deze order heeft meerdere hoofd-BOM’s; de eerste staat hierboven. Zie de structuurregels.';
        NoMainBOMTxt: Label 'Geen hoofd-BOM op de productieorderregel vastgelegd.';
        NoProductionOrderLinesErr: Label 'Productieorder %1 bevat geen productieorderregels.', Comment = '%1=Production order no.';
        ProductionBOMHeaderVersionTxt: Label '%1 (versie %2)', Comment = '%1=production BOM description;%2=production BOM version code';
        ProductionBOMDisplayLimitTxt: Label 'De structuur is afgekapt na %1 regels. Controleer de onderliggende Production BOM’s afzonderlijk.', Comment = '%1=maximum display lines';
        ProductionBOMTooDeepTxt: Label 'Production BOM %1 is dieper dan 50 niveaus en is niet verder uitgeklapt.', Comment = '%1=Production BOM no.';
        ProductionBOMUnavailableTxt: Label 'Production BOM %1 of de gebruikte versie kan niet worden gelezen.', Comment = '%1=Production BOM no.';
        ProductionOrderTxtLbl: Label '%1 productieorder %2', Comment = '%1=Production order status;%2=Production order no.';
        RootPrefixTok: Label '> ', Locked = true;
        RootRoleTok: Label 'ROOT', Locked = true;
        StructureSourceTxtLbl: Label 'Alleen-lezen stamgegevensweergave, geen actuele componentbehoefte of zaaglijst. De hoofd-BOM komt uit de productieorder. Onderliggende BOM-versies gelden op startdatum, anders uiterste datum en zonder beide op werkdatum %1.', Comment = '%1=work date';
        DisplayLimitReached: Boolean;
        DisplayedLineCount: Integer;
        StructureLineNo: Integer;
        TemporaryStructureBOMNoTok: Label 'PNE-TEMP-STRUCT', Locked = true;
}
