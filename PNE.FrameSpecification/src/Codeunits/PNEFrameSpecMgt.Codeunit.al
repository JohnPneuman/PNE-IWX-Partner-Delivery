namespace Pneuman.FrameSpecification;

using Microsoft.Manufacturing.Document;
using Microsoft.Sales.Document;

codeunit 50154 "PNE Frame Spec. Mgt."
{
    procedure BuildLinesFromConfigurationID(
        ConfigurationID: Code[20];
        var TempPNEFrameSpecLine: Record "PNE Frame Spec. Line" temporary)
    var
        TempIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        ActiveConfigurationIDs: Dictionary of [Code[20], Boolean];
        ConfigurationNodeCount: Integer;
    begin
        CopyConfigurationBranch(
            ConfigurationID,
            TempIWXConfiguratorBOMv3,
            ActiveConfigurationIDs,
            1,
            ConfigurationNodeCount);
        BuildLinesFromConfiguration(TempIWXConfiguratorBOMv3, TempPNEFrameSpecLine);
    end;

    procedure BuildLinesFromProductionOrder(
        var ProductionOrder: Record "Production Order";
        var TempPNEFrameSpecLine: Record "PNE Frame Spec. Line" temporary;
        var ConfigurationID: Code[20];
        var ProductionOrderLineNo: Integer;
        var ConfiguredItemNo: Code[20])
    begin
        if not FindConfigurationForProductionOrder(
             ProductionOrder,
             ConfigurationID,
             ProductionOrderLineNo,
             ConfiguredItemNo)
        then
            Error(ProductionOrderConfigurationNotFoundErr, ProductionOrder."No.");

        BuildLinesFromConfigurationID(ConfigurationID, TempPNEFrameSpecLine);
    end;

    procedure FindConfigurationForProductionOrder(
        var ProductionOrder: Record "Production Order";
        var ConfigurationID: Code[20];
        var ProductionOrderLineNo: Integer;
        var ConfiguredItemNo: Code[20]): Boolean
    var
        ProdOrderLine: Record "Prod. Order Line";
        CandidateConfigurationID: Code[20];
        CandidateItemNo: Code[20];
        CandidateLineNo: Integer;
    begin
        Clear(ConfigurationID);
        Clear(ProductionOrderLineNo);
        Clear(ConfiguredItemNo);

        if TryFindConfigurationFromSalesOrder(
             ProductionOrder,
             ConfigurationID,
             ProductionOrderLineNo,
             ConfiguredItemNo)
        then
            exit(true);

        if (ProductionOrder."Source Type" = ProductionOrder."Source Type"::Item) and
           (ProductionOrder."Source No." <> '')
        then
            if TryFindConfigurationForConfiguredItem(ProductionOrder."Source No.", ConfigurationID) then begin
                ConfiguredItemNo := ProductionOrder."Source No.";
                ProductionOrderLineNo := FindProductionOrderLineNo(ProductionOrder, ConfiguredItemNo);
                exit(true);
            end;

        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderLine.SetRange("Planning Level Code", 0);
        if ProdOrderLine.FindSet() then
            repeat
                if TryFindConfigurationForConfiguredItem(ProdOrderLine."Item No.", CandidateConfigurationID) then
                    AddUniqueConfigurationCandidate(
                        ProductionOrder."No.",
                        CandidateConfigurationID,
                        ProdOrderLine."Item No.",
                        ProdOrderLine."Line No.",
                        ConfigurationID,
                        ConfiguredItemNo,
                        ProductionOrderLineNo);
            until ProdOrderLine.Next() = 0;

        if ConfigurationID <> '' then
            exit(true);

        ProdOrderLine.SetRange("Planning Level Code");
        if ProdOrderLine.FindSet() then
            repeat
                if TryFindConfigurationForConfiguredItem(ProdOrderLine."Item No.", CandidateConfigurationID) then begin
                    CandidateItemNo := ProdOrderLine."Item No.";
                    CandidateLineNo := ProdOrderLine."Line No.";
                    AddUniqueConfigurationCandidate(
                        ProductionOrder."No.",
                        CandidateConfigurationID,
                        CandidateItemNo,
                        CandidateLineNo,
                        ConfigurationID,
                        ConfiguredItemNo,
                        ProductionOrderLineNo);
                end;
            until ProdOrderLine.Next() = 0;

        exit(ConfigurationID <> '');
    end;

    local procedure TryFindConfigurationFromSalesOrder(
        ProductionOrder: Record "Production Order";
        var ConfigurationID: Code[20];
        var ProductionOrderLineNo: Integer;
        var ConfiguredItemNo: Code[20]): Boolean
    var
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        ProdOrderLine: Record "Prod. Order Line";
        SalesLine: Record "Sales Line";
        SalesHeader: Record "Sales Header";
        ProductionOrderItemNos: Dictionary of [Code[20], Boolean];
        CandidateConfigurationID: Code[20];
        CandidateItemNo: Code[20];
        CandidateLineNo: Integer;
    begin
        if (ProductionOrder."Source Type" <> ProductionOrder."Source Type"::"Sales Header") or
           (ProductionOrder."Source No." = '')
        then
            exit(false);
        if ProductionOrder.Status = ProductionOrder.Status::Simulated then begin
            if not SalesHeader.Get(SalesHeader."Document Type"::Quote, ProductionOrder."Source No.") then
                exit(false);
        end else
            if not SalesHeader.Get(SalesHeader."Document Type"::Order, ProductionOrder."Source No.") then
                exit(false);

        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderLine.SetRange("Planning Level Code", 0);
        if ProdOrderLine.FindSet() then
            repeat
                if not ProductionOrderItemNos.ContainsKey(ProdOrderLine."Item No.") then
                    ProductionOrderItemNos.Add(ProdOrderLine."Item No.", true);
            until ProdOrderLine.Next() = 0;
        if ProductionOrderItemNos.Count() = 0 then begin
            ProdOrderLine.SetRange("Planning Level Code");
            if ProdOrderLine.FindSet() then
                repeat
                    if not ProductionOrderItemNos.ContainsKey(ProdOrderLine."Item No.") then
                        ProductionOrderItemNos.Add(ProdOrderLine."Item No.", true);
                until ProdOrderLine.Next() = 0;
        end;

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", ProductionOrder."Source No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("IWX Cfg. Configuration ID", '<>%1', '');
        if SalesLine.FindSet() then
            repeat
                if TryGetFrameConfiguration(
                     SalesLine."IWX Cfg. Configuration ID",
                     IWXConfiguratorBOMv3)
                then begin
                    CandidateConfigurationID := SalesLine."IWX Cfg. Configuration ID";
                    CandidateItemNo := IWXConfiguratorBOMv3."Configured Item No.";
                    if CandidateItemNo = '' then
                        CandidateItemNo := SalesLine."No.";
                    if ProductionOrderItemNos.ContainsKey(CandidateItemNo) or
                       ProductionOrderItemNos.ContainsKey(SalesLine."No.")
                    then begin
                        if not ProductionOrderItemNos.ContainsKey(CandidateItemNo) then
                            CandidateItemNo := SalesLine."No.";
                        CandidateLineNo := FindProductionOrderLineNo(ProductionOrder, CandidateItemNo);
                        AddUniqueConfigurationCandidate(
                            ProductionOrder."No.",
                            CandidateConfigurationID,
                            CandidateItemNo,
                            CandidateLineNo,
                            ConfigurationID,
                            ConfiguredItemNo,
                            ProductionOrderLineNo);
                    end;
                end;
            until SalesLine.Next() = 0;

        exit(ConfigurationID <> '');
    end;

    local procedure AddUniqueConfigurationCandidate(
        ProductionOrderNo: Code[20];
        CandidateConfigurationID: Code[20];
        CandidateItemNo: Code[20];
        CandidateLineNo: Integer;
        var ConfigurationID: Code[20];
        var ConfiguredItemNo: Code[20];
        var ProductionOrderLineNo: Integer)
    begin
        if ConfigurationID = '' then begin
            ConfigurationID := CandidateConfigurationID;
            ConfiguredItemNo := CandidateItemNo;
            ProductionOrderLineNo := CandidateLineNo;
            exit;
        end;
        if ConfigurationID <> CandidateConfigurationID then
            Error(AmbiguousProductionOrderConfigurationErr, ProductionOrderNo, ConfigurationID, CandidateConfigurationID);
    end;

    local procedure FindProductionOrderLineNo(ProductionOrder: Record "Production Order"; ItemNo: Code[20]): Integer
    var
        ProdOrderLine: Record "Prod. Order Line";
        FoundLineNo: Integer;
    begin
        Clear(FoundLineNo);
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderLine.SetRange("Item No.", ItemNo);
        ProdOrderLine.SetRange("Planning Level Code", 0);
        if not ProdOrderLine.FindSet() then begin
            ProdOrderLine.SetRange("Planning Level Code");
            if not ProdOrderLine.FindSet() then
                exit(0);
        end;
        repeat
            if FoundLineNo <> 0 then
                exit(0);
            FoundLineNo := ProdOrderLine."Line No.";
        until ProdOrderLine.Next() = 0;
        exit(FoundLineNo);
    end;

    local procedure TryGetFrameConfiguration(
        ConfigurationID: Code[20];
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3"): Boolean
    begin
        if ConfigurationID = '' then
            exit(false);

        IWXConfiguratorBOMv3.Reset();
        IWXConfiguratorBOMv3.SetRange("Configuration ID", ConfigurationID);
        IWXConfiguratorBOMv3.SetRange("Configuration Option", FrameOptionCodeLbl);
        exit(IWXConfiguratorBOMv3.FindFirst());
    end;

    procedure GetConfigurationHeader(
        ConfigurationID: Code[20];
        var ObjectDescription: Text[100];
        var FrameCode: Code[20];
        var FrontCode: Code[20];
        var ColorCode: Code[20];
        var SpecialText: Text[100];
        var NoteText: Text[250];
        var FrameQuantity: Decimal;
        var Width: Decimal;
        var Height: Decimal;
        var Depth: Decimal)
    var
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
    begin
        Clear(ObjectDescription);
        Clear(FrameCode);
        Clear(FrontCode);
        Clear(ColorCode);
        Clear(SpecialText);
        Clear(NoteText);
        Clear(FrameQuantity);
        Clear(Width);
        Clear(Height);
        Clear(Depth);

        if GetConfigurationOption(IWXConfiguratorBOMv3, ConfigurationID, ObjectOptionCodeLbl) then
            ObjectDescription := CopyStr(IWXConfiguratorBOMv3."Option Text", 1, MaxStrLen(ObjectDescription));
        if GetConfigurationOption(IWXConfiguratorBOMv3, ConfigurationID, FrameOptionCodeLbl) then begin
            FrameCode := IWXConfiguratorBOMv3."Choice Code";
            FrameQuantity := IWXConfiguratorBOMv3."Quantity per Unit";
        end;
        if GetConfigurationOption(IWXConfiguratorBOMv3, ConfigurationID, FrontOptionCodeLbl) then
            FrontCode := IWXConfiguratorBOMv3."Choice Code";
        if GetConfigurationOption(IWXConfiguratorBOMv3, ConfigurationID, FrameColorOptionCodeLbl) then
            ColorCode := IWXConfiguratorBOMv3."Choice Code";
        if GetConfigurationOption(IWXConfiguratorBOMv3, ConfigurationID, WidthOptionCodeLbl) then
            Width := IWXConfiguratorBOMv3."Quantity per Unit";
        if GetConfigurationOption(IWXConfiguratorBOMv3, ConfigurationID, HeightOptionCodeLbl) then
            Height := IWXConfiguratorBOMv3."Quantity per Unit";
        if GetConfigurationOption(IWXConfiguratorBOMv3, ConfigurationID, DepthOptionCodeLbl) then
            Depth := IWXConfiguratorBOMv3."Quantity per Unit";

        SpecialText := CopyStr(
            GetOptionDisplayValue(ConfigurationID, SpecialOptionCodeLbl),
            1,
            MaxStrLen(SpecialText));
        if SpecialText = '' then
            SpecialText := CopyStr(
                GetOptionDisplayValue(ConfigurationID, SpecialOptionCode2Lbl),
                1,
                MaxStrLen(SpecialText));
        NoteText := GetOptionDisplayValue(ConfigurationID, NoteOptionCodeLbl);
        if NoteText = '' then
            NoteText := GetOptionDisplayValue(ConfigurationID, NoteOptionCode2Lbl);

        if FrameQuantity = 0 then
            FrameQuantity := 1;
    end;

    procedure BuildLinesFromConfiguration(
        var TempIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        var TempPNEFrameSpecLine: Record "PNE Frame Spec. Line" temporary)
    var
        PNEFrameSpecRule: Record "PNE Frame Spec. Rule";
        FrameWidth: Decimal;
        FrameHeight: Decimal;
        NextLineNo: Integer;
    begin
        TempPNEFrameSpecLine.Reset();
        TempPNEFrameSpecLine.DeleteAll();

        if not FindFrameConfiguration(TempIWXConfiguratorBOMv3) then
            Error(FrameConfigurationNotFoundErr, FrameOptionCodeLbl);

        GetFrameDimensions(TempIWXConfiguratorBOMv3, FrameWidth, FrameHeight);
        PNEFrameSpecRule.SetRange("Frame Configuration Code", TempIWXConfiguratorBOMv3."Choice Code");
        PNEFrameSpecRule.SetRange(Enabled, true);
        PNEFrameSpecRule.SetCurrentKey("Frame Configuration Code", "Sort Order");
        if PNEFrameSpecRule.FindSet() then
            repeat
                if FrameOptionExists(TempIWXConfiguratorBOMv3, PNEFrameSpecRule."Configuration Option") then begin
                    NextLineNo += 10000;
                    InsertTemporaryLine(
                        TempPNEFrameSpecLine,
                        TempIWXConfiguratorBOMv3,
                        PNEFrameSpecRule,
                        FrameWidth,
                        FrameHeight,
                        NextLineNo);
                end;
            until PNEFrameSpecRule.Next() = 0;

        if TempPNEFrameSpecLine.IsEmpty() then
            Error(NoMatchingRulesErr, TempIWXConfiguratorBOMv3."Choice Code");
    end;

    local procedure FindFrameConfiguration(
        var TempIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary): Boolean
    begin
        TempIWXConfiguratorBOMv3.Reset();
        TempIWXConfiguratorBOMv3.SetRange("Configuration Option", FrameOptionCodeLbl);
        exit(TempIWXConfiguratorBOMv3.FindFirst());
    end;

    local procedure CopyConfigurationBranch(
        ConfigurationID: Code[20];
        var TempIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        var ActiveConfigurationIDs: Dictionary of [Code[20], Boolean];
        Depth: Integer;
        var ConfigurationNodeCount: Integer)
    var
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
    begin
        if Depth > MaximumConfigurationDepth() then
            Error(ConfigurationDepthErr, ConfigurationID, MaximumConfigurationDepth());
        if ActiveConfigurationIDs.ContainsKey(ConfigurationID) then
            Error(CircularConfigurationErr, ConfigurationID);

        ActiveConfigurationIDs.Add(ConfigurationID, true);
        IWXConfiguratorBOMv3.SetRange("Configuration ID", ConfigurationID);
        if not IWXConfiguratorBOMv3.FindSet() then
            Error(ConfigurationNotFoundErr, ConfigurationID);

        repeat
            ConfigurationNodeCount += 1;
            if ConfigurationNodeCount > MaximumConfigurationNodes() then
                Error(ConfigurationNodeLimitErr, MaximumConfigurationNodes());
            TempIWXConfiguratorBOMv3.Init();
            TempIWXConfiguratorBOMv3.TransferFields(IWXConfiguratorBOMv3);
            TempIWXConfiguratorBOMv3.Insert();
            if IWXConfiguratorBOMv3."Choice Configuration ID" <> '' then
                CopyConfigurationBranch(
                    IWXConfiguratorBOMv3."Choice Configuration ID",
                    TempIWXConfiguratorBOMv3,
                    ActiveConfigurationIDs,
                    Depth + 1,
                    ConfigurationNodeCount);
        until IWXConfiguratorBOMv3.Next() = 0;
        ActiveConfigurationIDs.Remove(ConfigurationID);
    end;

    local procedure TryFindConfigurationForConfiguredItem(
        ConfiguredItemNo: Code[20];
        var ConfigurationID: Code[20]): Boolean
    var
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
    begin
        Clear(ConfigurationID);
        if ConfiguredItemNo = '' then
            exit(false);

        IWXConfiguratorBOMv3.SetCurrentKey("Configured Item No.");
        IWXConfiguratorBOMv3.SetRange("Configured Item No.", ConfiguredItemNo);
        IWXConfiguratorBOMv3.SetRange("Configuration Option", FrameOptionCodeLbl);
        if not IWXConfiguratorBOMv3.FindSet() then
            exit(false);

        repeat
            if ConfigurationID = '' then
                ConfigurationID := IWXConfiguratorBOMv3."Configuration ID"
            else
                if ConfigurationID <> IWXConfiguratorBOMv3."Configuration ID" then
                    Error(AmbiguousConfiguredItemErr, ConfiguredItemNo, ConfigurationID, IWXConfiguratorBOMv3."Configuration ID");
        until IWXConfiguratorBOMv3.Next() = 0;
        exit(ConfigurationID <> '');
    end;

    local procedure MaximumConfigurationDepth(): Integer
    begin
        exit(50);
    end;

    local procedure MaximumConfigurationNodes(): Integer
    begin
        exit(20000);
    end;

    local procedure GetConfigurationOption(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        ConfigurationID: Code[20];
        OptionCode: Code[20]): Boolean
    begin
        IWXConfiguratorBOMv3.Reset();
        IWXConfiguratorBOMv3.SetRange("Configuration ID", ConfigurationID);
        IWXConfiguratorBOMv3.SetRange("Configuration Option", OptionCode);
        exit(IWXConfiguratorBOMv3.FindFirst());
    end;

    local procedure GetOptionDisplayValue(ConfigurationID: Code[20]; OptionCode: Code[20]): Text[250]
    var
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
    begin
        if not GetConfigurationOption(IWXConfiguratorBOMv3, ConfigurationID, OptionCode) then
            exit('');
        if IWXConfiguratorBOMv3."Option Text" <> '' then
            exit(IWXConfiguratorBOMv3."Option Text");
        exit(IWXConfiguratorBOMv3."Choice Code");
    end;

    local procedure GetFrameDimensions(
        var TempFrameIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        var FrameWidth: Decimal;
        var FrameHeight: Decimal)
    var
        TempFrameConfigurationIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
    begin
        SetFrameConfigurationFilters(TempFrameConfigurationIWXConfiguratorBOMv3, TempFrameIWXConfiguratorBOMv3);
        FrameWidth := GetDimension(TempFrameConfigurationIWXConfiguratorBOMv3, WidthOptionCodeLbl);
        FrameHeight := GetDimension(TempFrameConfigurationIWXConfiguratorBOMv3, HeightOptionCodeLbl);
    end;

    local procedure GetDimension(
        var TempFrameConfigurationIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        OptionCode: Code[20]): Decimal
    var
        TempDimensionIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
    begin
        TempDimensionIWXConfiguratorBOMv3.Copy(TempFrameConfigurationIWXConfiguratorBOMv3, true);
        TempDimensionIWXConfiguratorBOMv3.SetRange("Configuration Option", OptionCode);
        if not TempDimensionIWXConfiguratorBOMv3.FindFirst() then
            exit(0);

        exit(TempDimensionIWXConfiguratorBOMv3."Quantity per Unit");
    end;

    local procedure FrameOptionExists(
        var TempFrameIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        ConfigurationOption: Code[20]): Boolean
    var
        TempFrameConfigurationIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
    begin
        SetFrameConfigurationFilters(TempFrameConfigurationIWXConfiguratorBOMv3, TempFrameIWXConfiguratorBOMv3);
        TempFrameConfigurationIWXConfiguratorBOMv3.SetRange("Configuration Option", ConfigurationOption);
        exit(not TempFrameConfigurationIWXConfiguratorBOMv3.IsEmpty());
    end;

    local procedure SetFrameConfigurationFilters(
        var TempFrameConfigurationIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        var TempFrameIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary)
    begin
        TempFrameConfigurationIWXConfiguratorBOMv3.Copy(TempFrameIWXConfiguratorBOMv3, true);
        TempFrameConfigurationIWXConfiguratorBOMv3.Reset();
        TempFrameConfigurationIWXConfiguratorBOMv3.SetRange("Configuration ID", TempFrameIWXConfiguratorBOMv3."Choice Configuration ID");
    end;

    local procedure InsertTemporaryLine(
        var TempPNEFrameSpecLine: Record "PNE Frame Spec. Line" temporary;
        var TempFrameIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        PNEFrameSpecRule: Record "PNE Frame Spec. Rule";
        FrameWidth: Decimal;
        FrameHeight: Decimal;
        LineNo: Integer)
    begin
        TempPNEFrameSpecLine.Init();
        TempPNEFrameSpecLine."Line No." := LineNo;
        TempPNEFrameSpecLine."Source Configuration ID" := TempFrameIWXConfiguratorBOMv3."Choice Configuration ID";
        TempPNEFrameSpecLine."Frame Configuration Code" := TempFrameIWXConfiguratorBOMv3."Choice Code";
        TempPNEFrameSpecLine."Configuration Option" := PNEFrameSpecRule."Configuration Option";
        TempPNEFrameSpecLine."Item No." := PNEFrameSpecRule."Component No.";
        TempPNEFrameSpecLine.Description := PNEFrameSpecRule.Description;
        TempPNEFrameSpecLine.Quantity := PNEFrameSpecRule.Quantity;
        TempPNEFrameSpecLine."Width Correction (mm)" := PNEFrameSpecRule."Width Correction (mm)";
        TempPNEFrameSpecLine."Height Correction (mm)" := PNEFrameSpecRule."Height Correction (mm)";
        if PNEFrameSpecRule."Use Width" and PNEFrameSpecRule."Use Height" then
            TempPNEFrameSpecLine."Line Type" := TempPNEFrameSpecLine."Line Type"::Plate
        else
            TempPNEFrameSpecLine."Line Type" := TempPNEFrameSpecLine."Line Type"::Profile;
        if PNEFrameSpecRule."Use Width" then
            TempPNEFrameSpecLine."Width (mm)" := FrameWidth + PNEFrameSpecRule."Width Correction (mm)";
        if PNEFrameSpecRule."Use Height" then
            TempPNEFrameSpecLine."Height (mm)" := FrameHeight + PNEFrameSpecRule."Height Correction (mm)";
        TempPNEFrameSpecLine.Insert();
    end;

    var
        FrameOptionCodeLbl: Label 'I_FRM', Locked = true;
        FrameColorOptionCodeLbl: Label 'I_FRMC', Locked = true;
        FrontOptionCodeLbl: Label 'I_FRT', Locked = true;
        HeightOptionCodeLbl: Label 'I_HGHT', Locked = true;
        WidthOptionCodeLbl: Label 'I_WDTH', Locked = true;
        DepthOptionCodeLbl: Label 'I_DPTH', Locked = true;
        ObjectOptionCodeLbl: Label 'I_OBJ', Locked = true;
        SpecialOptionCodeLbl: Label 'I_SPEC', Locked = true;
        SpecialOptionCode2Lbl: Label 'I_SPECIAL', Locked = true;
        NoteOptionCodeLbl: Label 'I_NOTE', Locked = true;
        NoteOptionCode2Lbl: Label 'I_NOTITIE', Locked = true;
        CircularConfigurationErr: Label 'Configuration %1 contains a circular sub-configuration reference.', Comment = '%1 = configuration ID';
        AmbiguousConfiguredItemErr: Label 'Configured item %1 is linked to multiple frame configurations (%2 and %3). The frame specification cannot choose safely.', Comment = '%1 = item no.; %2/%3 = configuration IDs';
        AmbiguousProductionOrderConfigurationErr: Label 'Production order %1 contains multiple different frame configurations (%2 and %3). Open the correct production-order line or repair the configuration link.', Comment = '%1 = production order no.; %2/%3 = configuration IDs';
        ConfigurationDepthErr: Label 'Configuration %1 is nested more than %2 levels. The frame specification stops to prevent an endless or corrupt configuration tree.', Comment = '%1 = configuration ID; %2 = maximum depth';
        ConfigurationNodeLimitErr: Label 'The frame configuration contains more than %1 rows. The frame specification stops to protect performance. Split or repair the configuration tree.', Comment = '%1 = maximum node count';
        ConfigurationNotFoundErr: Label 'Configuration %1 was not found in the Configurator BOM.', Comment = '%1 = configuration ID';
        FrameConfigurationNotFoundErr: Label 'No %1 option was found in this configuration or its sub-configurations.', Comment = '%1 = frame option code';
        NoMatchingRulesErr: Label 'No enabled frame specification rules match frame %1 and its selected configuration options.', Comment = '%1 = frame configuration code';
        ProductionOrderConfigurationNotFoundErr: Label 'No frame configuration could be found for production order %1. The report searched the source sales order, source item, and production-order lines for a configuration containing I_FRM.', Comment = '%1 = production order number';
}
