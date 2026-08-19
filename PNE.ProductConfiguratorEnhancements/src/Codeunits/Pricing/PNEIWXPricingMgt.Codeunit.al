codeunit 50110 "PNE IWX Pricing Mgt."
{
    Permissions =
        tabledata "Item Profit Group PTE" = r;

    procedure GetEffectiveProfitGroupCode(
        OptionChoice: Record "IWX Cfg Option Choice v3"): Code[10]
    var
        Item: Record Item;
    begin
        if OptionChoice."Item Profit Group Code PNE" <> '' then
            exit(OptionChoice."Item Profit Group Code PNE");

        if OptionChoice.Type <> OptionChoice.Type::Item then
            exit('');

        Item.SetLoadFields("Item Profit Group Code PTE");
        if not Item.Get(OptionChoice."No.") then
            exit('');

        exit(Item."Item Profit Group Code PTE");
    end;

    procedure ApplyOptionChoiceToConfiguratorBOM(
        var ConfiguratorBOM: Record "IWX Configurator BOM v3";
        OptionChoice: Record "IWX Cfg Option Choice v3")
    begin
        ConfiguratorBOM."Item Profit Group Code PNE" :=
            GetEffectiveProfitGroupCode(OptionChoice);
    end;

    procedure ApplySelectedChoiceToConfiguratorBOM(
        var ConfiguratorBOM: Record "IWX Configurator BOM v3")
    var
        OptionChoice: Record "IWX Cfg Option Choice v3";
    begin
        if ConfiguratorBOM."Choice Code" = '' then begin
            Clear(ConfiguratorBOM."Item Profit Group Code PNE");
            exit;
        end;

        if not OptionChoice.Get(
            ConfiguratorBOM."Item Category Code",
            ConfiguratorBOM."Configuration Option",
            ConfiguratorBOM."Choice Code")
        then begin
            Clear(ConfiguratorBOM."Item Profit Group Code PNE");
            exit;
        end;

        ApplyOptionChoiceToConfiguratorBOM(
            ConfiguratorBOM,
            OptionChoice);
    end;

    procedure ApplyDefaultsToConfiguratorBOM(
        var TempConfiguratorBOM: Record "IWX Configurator BOM v3" temporary)
    var
        TempConfiguratorBOMLine: Record "IWX Configurator BOM v3" temporary;
    begin
        TempConfiguratorBOMLine.Copy(TempConfiguratorBOM, true);
        if TempConfiguratorBOMLine.FindSet(true) then
            repeat
                if TempConfiguratorBOMLine."Item Profit Group Code PNE" = '' then begin
                    ApplySelectedChoiceToConfiguratorBOM(
                        TempConfiguratorBOMLine);
                    TempConfiguratorBOMLine.Modify(false);
                end;
            until TempConfiguratorBOMLine.Next() = 0;
    end;

    procedure UpdateOptionChoiceUnitPrice(
        var OptionChoice: Record "IWX Cfg Option Choice v3")
    begin
        if OptionChoice."Item Profit Group Code PNE" = '' then begin
            if OptionChoice.Type = OptionChoice.Type::Item then
                OptionChoice.UpdateUnitPrice();

            exit;
        end;

        EnsureSupportedChoiceType(OptionChoice.Type);
        UpdateOptionChoiceUnitPriceFromProfitGroup(OptionChoice);
    end;

    procedure UpdateOptionChoiceUnitPriceFromProfitGroup(
        var OptionChoice: Record "IWX Cfg Option Choice v3")
    begin
        EnsureSupportedChoiceType(OptionChoice.Type);

        OptionChoice."Unit Price" :=
            CalculateUnitPrice(
                OptionChoice."Unit Cost",
                OptionChoice."Item Profit Group Code PNE");
    end;

    procedure UpdateWhenUsedUnitPriceAfterUnitCost(
        var OptionChoice: Record "IWX Cfg Option Choice v3")
    begin
        if OptionChoice."Item Profit Group Code PNE" = '' then
            exit;

        if OptionChoice."Update Unit Price" <>
           OptionChoice."Update Unit Price"::"When Used"
        then
            exit;

        UpdateOptionChoiceUnitPriceFromProfitGroup(OptionChoice);
    end;

    procedure UpdateConfiguratorBOMUnitPrice(
        var ConfiguratorBOM: Record "IWX Configurator BOM v3")
    var
        OptionChoice: Record "IWX Cfg Option Choice v3";
    begin
        if ConfiguratorBOM."Item Profit Group Code PNE" <> '' then begin
            EnsureSupportedChoiceType(ConfiguratorBOM."Choice Type");

            ConfiguratorBOM."Unit Price" :=
                CalculateUnitPrice(
                    ConfiguratorBOM."Unit Cost",
                    ConfiguratorBOM."Item Profit Group Code PNE");
            exit;
        end;

        if OptionChoice.Get(
            ConfiguratorBOM."Item Category Code",
            ConfiguratorBOM."Configuration Option",
            ConfiguratorBOM."Choice Code")
        then
            ConfiguratorBOM."Unit Price" :=
                OptionChoice."Unit Price";
    end;

    procedure CalculateUnitPrice(
        UnitCost: Decimal;
        ItemProfitGroupCode: Code[10]): Decimal
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        ItemProfitGroup: Record "Item Profit Group PTE";
        ProfitPercentage: Decimal;
    begin
        if ItemProfitGroupCode = '' then
            exit(0);

        if not ItemProfitGroup.Get(ItemProfitGroupCode) then
            Error(
                ItemProfitGroupNotFoundErr,
                ItemProfitGroupCode);

        ProfitPercentage := ItemProfitGroup."Profit %";
        if ProfitPercentage >= 100 then
            Error(
                InvalidProfitPercentageErr,
                ProfitPercentage,
                ItemProfitGroupCode);

        GeneralLedgerSetup.Get();

        exit(
            Round(
                UnitCost / (1 - (ProfitPercentage / 100)),
                GeneralLedgerSetup."Unit-Amount Rounding Precision"));
    end;

    local procedure EnsureSupportedChoiceType(
        ChoiceType: Enum "IWX Cfg. Option Choice Type")
    begin
        if ChoiceType in [ChoiceType::Item, ChoiceType::"Production BOM"] then
            exit;

        Error(
            UnsupportedChoiceTypeErr,
            ChoiceType);
    end;

    var
        InvalidProfitPercentageErr: Label 'Profit percentage %1 for item profit group %2 must be less than 100.', Comment = '%1 = Profit percentage, %2 = Item profit group code';
        ItemProfitGroupNotFoundErr: Label 'Item profit group %1 does not exist.', Comment = '%1 = Item profit group code';
        UnsupportedChoiceTypeErr: Label 'Item profit groups can only be used for Item or Production BOM choices. Current type: %1.', Comment = '%1 = IWX option choice type';
}
