codeunit 50154 "PNE Frame Spec. Mgt."
{
    procedure BuildLinesFromConfigurationID(
        ConfigurationID: Code[20];
        var TempFrameSpecLine: Record "PNE Frame Spec. Line" temporary)
    var
        TempConfiguratorBOM: Record "IWX Configurator BOM v3" temporary;
        ActiveConfigurationIDs: Dictionary of [Code[20], Boolean];
    begin
        CopyConfigurationBranch(ConfigurationID, TempConfiguratorBOM, ActiveConfigurationIDs);
        BuildLinesFromConfiguration(TempConfiguratorBOM, TempFrameSpecLine);
    end;

    procedure BuildLinesFromProductionOrder(
        var ProductionOrder: Record "Production Order";
        var TempFrameSpecLine: Record "PNE Frame Spec. Line" temporary;
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

        BuildLinesFromConfigurationID(ConfigurationID, TempFrameSpecLine);
    end;

    procedure FindConfigurationForProductionOrder(
        var ProductionOrder: Record "Production Order";
        var ConfigurationID: Code[20];
        var ProductionOrderLineNo: Integer;
        var ConfiguredItemNo: Code[20]): Boolean
    var
        ProductionOrderLine: Record "Prod. Order Line";
    begin
        Clear(ConfigurationID);
        Clear(ProductionOrderLineNo);
        Clear(ConfiguredItemNo);

        if TryFindConfigurationFromSalesOrder(
             ProductionOrder."Source No.",
             ConfigurationID,
             ConfiguredItemNo)
        then
            exit(true);

        if ProductionOrder."Source No." <> '' then
            if TryFindConfigurationForConfiguredItem(ProductionOrder."Source No.", ConfigurationID) then begin
                ConfiguredItemNo := ProductionOrder."Source No.";
                exit(true);
            end;

        ProductionOrderLine.SetRange(Status, ProductionOrder.Status);
        ProductionOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProductionOrderLine.FindSet() then
            repeat
                if TryFindConfigurationForConfiguredItem(ProductionOrderLine."Item No.", ConfigurationID) then begin
                    ProductionOrderLineNo := ProductionOrderLine."Line No.";
                    ConfiguredItemNo := ProductionOrderLine."Item No.";
                    exit(true);
                end;
            until ProductionOrderLine.Next() = 0;

        exit(false);
    end;

    local procedure TryFindConfigurationFromSalesOrder(
        SalesOrderNo: Code[20];
        var ConfigurationID: Code[20];
        var ConfiguredItemNo: Code[20]): Boolean
    var
        ConfiguratorBOM: Record "IWX Configurator BOM v3";
        SalesLine: Record "Sales Line";
    begin
        if SalesOrderNo = '' then
            exit(false);

        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", SalesOrderNo);
        SalesLine.SetFilter("IWX Cfg. Configuration ID", '<>%1', '');
        if SalesLine.FindSet() then
            repeat
                if TryGetFrameConfiguration(
                     SalesLine."IWX Cfg. Configuration ID",
                     ConfiguratorBOM)
                then begin
                    ConfigurationID := SalesLine."IWX Cfg. Configuration ID";
                    ConfiguredItemNo := ConfiguratorBOM."Configured Item No.";
                    if ConfiguredItemNo = '' then
                        ConfiguredItemNo := SalesLine."No.";
                    exit(true);
                end;
            until SalesLine.Next() = 0;

        exit(false);
    end;

    local procedure TryGetFrameConfiguration(
        ConfigurationID: Code[20];
        var ConfiguratorBOM: Record "IWX Configurator BOM v3"): Boolean
    begin
        if ConfigurationID = '' then
            exit(false);

        ConfiguratorBOM.Reset();
        ConfiguratorBOM.SetRange("Configuration ID", ConfigurationID);
        ConfiguratorBOM.SetRange("Configuration Option", FrameOptionCodeLbl);
        exit(ConfiguratorBOM.FindFirst());
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
        ConfiguratorBOM: Record "IWX Configurator BOM v3";
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

        if GetConfigurationOption(ConfiguratorBOM, ConfigurationID, ObjectOptionCodeLbl) then
            ObjectDescription := CopyStr(ConfiguratorBOM."Option Text", 1, MaxStrLen(ObjectDescription));
        if GetConfigurationOption(ConfiguratorBOM, ConfigurationID, FrameOptionCodeLbl) then begin
            FrameCode := ConfiguratorBOM."Choice Code";
            FrameQuantity := ConfiguratorBOM."Quantity per Unit";
        end;
        if GetConfigurationOption(ConfiguratorBOM, ConfigurationID, FrontOptionCodeLbl) then
            FrontCode := ConfiguratorBOM."Choice Code";
        if GetConfigurationOption(ConfiguratorBOM, ConfigurationID, FrameColorOptionCodeLbl) then
            ColorCode := ConfiguratorBOM."Choice Code";
        if GetConfigurationOption(ConfiguratorBOM, ConfigurationID, WidthOptionCodeLbl) then
            Width := ConfiguratorBOM."Quantity per Unit";
        if GetConfigurationOption(ConfiguratorBOM, ConfigurationID, HeightOptionCodeLbl) then
            Height := ConfiguratorBOM."Quantity per Unit";
        if GetConfigurationOption(ConfiguratorBOM, ConfigurationID, DepthOptionCodeLbl) then
            Depth := ConfiguratorBOM."Quantity per Unit";

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
        var TempConfiguratorBOM: Record "IWX Configurator BOM v3" temporary;
        var TempFrameSpecLine: Record "PNE Frame Spec. Line" temporary)
    var
        FrameSpecRule: Record "PNE Frame Spec. Rule";
        FrameWidth: Decimal;
        FrameHeight: Decimal;
        NextLineNo: Integer;
    begin
        TempFrameSpecLine.Reset();
        TempFrameSpecLine.DeleteAll();

        if not FindFrameConfiguration(TempConfiguratorBOM) then
            Error(FrameConfigurationNotFoundErr, FrameOptionCodeLbl);

        GetFrameDimensions(TempConfiguratorBOM, FrameWidth, FrameHeight);
        FrameSpecRule.SetRange("Frame Configuration Code", TempConfiguratorBOM."Choice Code");
        FrameSpecRule.SetRange(Enabled, true);
        FrameSpecRule.SetCurrentKey("Frame Configuration Code", "Sort Order");
        if FrameSpecRule.FindSet() then
            repeat
                if FrameOptionExists(TempConfiguratorBOM, FrameSpecRule."Configuration Option") then begin
                    NextLineNo += 10000;
                    InsertTemporaryLine(
                        TempFrameSpecLine,
                        TempConfiguratorBOM,
                        FrameSpecRule,
                        FrameWidth,
                        FrameHeight,
                        NextLineNo);
                end;
            until FrameSpecRule.Next() = 0;

        if TempFrameSpecLine.IsEmpty() then
            Error(NoMatchingRulesErr, TempConfiguratorBOM."Choice Code");
    end;

    local procedure FindFrameConfiguration(
        var TempConfiguratorBOM: Record "IWX Configurator BOM v3" temporary): Boolean
    begin
        TempConfiguratorBOM.Reset();
        TempConfiguratorBOM.SetRange("Configuration Option", FrameOptionCodeLbl);
        exit(TempConfiguratorBOM.FindFirst());
    end;

    local procedure CopyConfigurationBranch(
        ConfigurationID: Code[20];
        var TempConfiguratorBOM: Record "IWX Configurator BOM v3" temporary;
        var ActiveConfigurationIDs: Dictionary of [Code[20], Boolean])
    var
        ConfiguratorBOM: Record "IWX Configurator BOM v3";
    begin
        if ActiveConfigurationIDs.ContainsKey(ConfigurationID) then
            Error(CircularConfigurationErr, ConfigurationID);

        ActiveConfigurationIDs.Add(ConfigurationID, true);
        ConfiguratorBOM.SetRange("Configuration ID", ConfigurationID);
        if not ConfiguratorBOM.FindSet() then
            Error(ConfigurationNotFoundErr, ConfigurationID);

        repeat
            TempConfiguratorBOM.Init();
            TempConfiguratorBOM.TransferFields(ConfiguratorBOM);
            TempConfiguratorBOM.Insert();
            if ConfiguratorBOM."Choice Configuration ID" <> '' then
                CopyConfigurationBranch(
                    ConfiguratorBOM."Choice Configuration ID",
                    TempConfiguratorBOM,
                    ActiveConfigurationIDs);
        until ConfiguratorBOM.Next() = 0;
        ActiveConfigurationIDs.Remove(ConfigurationID);
    end;

    local procedure TryFindConfigurationForConfiguredItem(
        ConfiguredItemNo: Code[20];
        var ConfigurationID: Code[20]): Boolean
    var
        ConfiguratorBOM: Record "IWX Configurator BOM v3";
    begin
        if ConfiguredItemNo = '' then
            exit(false);

        ConfiguratorBOM.SetCurrentKey("Configured Item No.");
        ConfiguratorBOM.SetRange("Configured Item No.", ConfiguredItemNo);
        ConfiguratorBOM.SetRange("Configuration Option", FrameOptionCodeLbl);
        if not ConfiguratorBOM.FindFirst() then
            exit(false);

        ConfigurationID := ConfiguratorBOM."Configuration ID";
        exit(ConfigurationID <> '');
    end;

    local procedure GetConfigurationOption(
        var ConfiguratorBOM: Record "IWX Configurator BOM v3";
        ConfigurationID: Code[20];
        OptionCode: Code[20]): Boolean
    begin
        ConfiguratorBOM.Reset();
        ConfiguratorBOM.SetRange("Configuration ID", ConfigurationID);
        ConfiguratorBOM.SetRange("Configuration Option", OptionCode);
        exit(ConfiguratorBOM.FindFirst());
    end;

    local procedure GetOptionDisplayValue(ConfigurationID: Code[20]; OptionCode: Code[20]): Text[250]
    var
        ConfiguratorBOM: Record "IWX Configurator BOM v3";
    begin
        if not GetConfigurationOption(ConfiguratorBOM, ConfigurationID, OptionCode) then
            exit('');
        if ConfiguratorBOM."Option Text" <> '' then
            exit(ConfiguratorBOM."Option Text");
        exit(ConfiguratorBOM."Choice Code");
    end;

    local procedure GetFrameDimensions(
        var TempFrameConfiguratorBOM: Record "IWX Configurator BOM v3" temporary;
        var FrameWidth: Decimal;
        var FrameHeight: Decimal)
    var
        TempFrameConfigurationBOM: Record "IWX Configurator BOM v3" temporary;
    begin
        SetFrameConfigurationFilters(TempFrameConfigurationBOM, TempFrameConfiguratorBOM);
        FrameWidth := GetDimension(TempFrameConfigurationBOM, WidthOptionCodeLbl);
        FrameHeight := GetDimension(TempFrameConfigurationBOM, HeightOptionCodeLbl);
    end;

    local procedure GetDimension(
        var TempFrameConfigurationBOM: Record "IWX Configurator BOM v3" temporary;
        OptionCode: Code[20]): Decimal
    var
        TempDimensionBOM: Record "IWX Configurator BOM v3" temporary;
    begin
        TempDimensionBOM.Copy(TempFrameConfigurationBOM, true);
        TempDimensionBOM.SetRange("Configuration Option", OptionCode);
        if not TempDimensionBOM.FindFirst() then
            exit(0);

        exit(TempDimensionBOM."Quantity per Unit");
    end;

    local procedure FrameOptionExists(
        var TempFrameConfiguratorBOM: Record "IWX Configurator BOM v3" temporary;
        ConfigurationOption: Code[20]): Boolean
    var
        TempFrameConfigurationBOM: Record "IWX Configurator BOM v3" temporary;
    begin
        SetFrameConfigurationFilters(TempFrameConfigurationBOM, TempFrameConfiguratorBOM);
        TempFrameConfigurationBOM.SetRange("Configuration Option", ConfigurationOption);
        exit(not TempFrameConfigurationBOM.IsEmpty());
    end;

    local procedure SetFrameConfigurationFilters(
        var TempFrameConfigurationBOM: Record "IWX Configurator BOM v3" temporary;
        var TempFrameConfiguratorBOM: Record "IWX Configurator BOM v3" temporary)
    begin
        TempFrameConfigurationBOM.Copy(TempFrameConfiguratorBOM, true);
        TempFrameConfigurationBOM.Reset();
        TempFrameConfigurationBOM.SetRange("Configuration ID", TempFrameConfiguratorBOM."Choice Configuration ID");
    end;

    local procedure InsertTemporaryLine(
        var TempFrameSpecLine: Record "PNE Frame Spec. Line" temporary;
        var TempFrameConfiguratorBOM: Record "IWX Configurator BOM v3" temporary;
        FrameSpecRule: Record "PNE Frame Spec. Rule";
        FrameWidth: Decimal;
        FrameHeight: Decimal;
        LineNo: Integer)
    begin
        TempFrameSpecLine.Init();
        TempFrameSpecLine."Line No." := LineNo;
        TempFrameSpecLine."Source Configuration ID" := TempFrameConfiguratorBOM."Choice Configuration ID";
        TempFrameSpecLine."Frame Configuration Code" := TempFrameConfiguratorBOM."Choice Code";
        TempFrameSpecLine."Configuration Option" := FrameSpecRule."Configuration Option";
        TempFrameSpecLine."Item No." := FrameSpecRule."Component No.";
        TempFrameSpecLine.Description := FrameSpecRule.Description;
        TempFrameSpecLine.Quantity := FrameSpecRule.Quantity;
        TempFrameSpecLine."Width Correction (mm)" := FrameSpecRule."Width Correction (mm)";
        TempFrameSpecLine."Height Correction (mm)" := FrameSpecRule."Height Correction (mm)";
        if FrameSpecRule."Use Width" and FrameSpecRule."Use Height" then
            TempFrameSpecLine."Line Type" := TempFrameSpecLine."Line Type"::Plate
        else
            TempFrameSpecLine."Line Type" := TempFrameSpecLine."Line Type"::Profile;
        if FrameSpecRule."Use Width" then
            TempFrameSpecLine."Width (mm)" := FrameWidth + FrameSpecRule."Width Correction (mm)";
        if FrameSpecRule."Use Height" then
            TempFrameSpecLine."Height (mm)" := FrameHeight + FrameSpecRule."Height Correction (mm)";
        TempFrameSpecLine.Insert();
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
        ConfigurationNotFoundErr: Label 'Configuration %1 was not found in the Configurator BOM.', Comment = '%1 = configuration ID';
        FrameConfigurationNotFoundErr: Label 'No %1 option was found in this configuration or its sub-configurations.', Comment = '%1 = frame option code';
        NoMatchingRulesErr: Label 'No enabled frame specification rules match frame %1 and its selected configuration options.', Comment = '%1 = frame configuration code';
        ProductionOrderConfigurationNotFoundErr: Label 'No frame configuration could be found for production order %1. The report searched the source sales order, source item, and production-order lines for a configuration containing I_FRM.', Comment = '%1 = production order number';
}
