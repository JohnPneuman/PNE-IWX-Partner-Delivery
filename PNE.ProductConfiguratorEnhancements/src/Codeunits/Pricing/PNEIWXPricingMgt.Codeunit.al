namespace Pneuman.ProductConfigurator;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;

codeunit 50110 "PNE IWX Pricing Mgt."
{
    Permissions =
        tabledata "Item Profit Group PTE" = r;

    procedure GetEffectiveProfitGroupCode(
        IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3"): Code[10]
    var
        Item: Record Item;
    begin
        if IWXCfgOptionChoicev3."Item Profit Group Code PNE" <> '' then
            exit(IWXCfgOptionChoicev3."Item Profit Group Code PNE");

        if IWXCfgOptionChoicev3.Type <> IWXCfgOptionChoicev3.Type::Item then
            exit('');

        Item.SetLoadFields("Item Profit Group Code PTE");
        if not Item.Get(IWXCfgOptionChoicev3."No.") then
            exit('');

        exit(Item."Item Profit Group Code PTE");
    end;

    procedure ApplyOptionChoiceToConfiguratorBOM(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3")
    begin
        IWXConfiguratorBOMv3."Item Profit Group Code PNE" :=
            GetEffectiveProfitGroupCode(IWXCfgOptionChoicev3);
    end;

    procedure ApplySelectedChoiceToConfiguratorBOM(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3")
    var
        IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3";
    begin
        if IWXConfiguratorBOMv3."Choice Code" = '' then begin
            Clear(IWXConfiguratorBOMv3."Item Profit Group Code PNE");
            exit;
        end;

        if not IWXCfgOptionChoicev3.Get(
            IWXConfiguratorBOMv3."Item Category Code",
            IWXConfiguratorBOMv3."Configuration Option",
            IWXConfiguratorBOMv3."Choice Code")
        then begin
            Clear(IWXConfiguratorBOMv3."Item Profit Group Code PNE");
            exit;
        end;

        ApplyOptionChoiceToConfiguratorBOM(
            IWXConfiguratorBOMv3,
            IWXCfgOptionChoicev3);
    end;

    procedure ApplyDefaultsToConfiguratorBOM(
        var TempIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary)
    var
        TempLineIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
    begin
        TempLineIWXConfiguratorBOMv3.Copy(TempIWXConfiguratorBOMv3, true);
        if TempLineIWXConfiguratorBOMv3.FindSet(true) then
            repeat
                if TempLineIWXConfiguratorBOMv3."Item Profit Group Code PNE" = '' then begin
                    ApplySelectedChoiceToConfiguratorBOM(
                        TempLineIWXConfiguratorBOMv3);
                    TempLineIWXConfiguratorBOMv3.Modify(false);
                end;
            until TempLineIWXConfiguratorBOMv3.Next() = 0;
    end;

    procedure UpdateOptionChoiceUnitPrice(
        var IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3")
    begin
        if IWXCfgOptionChoicev3."Item Profit Group Code PNE" = '' then begin
            if IWXCfgOptionChoicev3.Type = IWXCfgOptionChoicev3.Type::Item then
                IWXCfgOptionChoicev3.UpdateUnitPrice();

            exit;
        end;

        EnsureSupportedChoiceType(IWXCfgOptionChoicev3.Type);
        UpdateOptionChoiceUnitPriceFromProfitGroup(IWXCfgOptionChoicev3);
    end;

    procedure UpdateOptionChoiceUnitPriceFromProfitGroup(
        var IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3")
    begin
        EnsureSupportedChoiceType(IWXCfgOptionChoicev3.Type);

        IWXCfgOptionChoicev3."Unit Price" :=
            CalculateUnitPrice(
                IWXCfgOptionChoicev3."Unit Cost",
                IWXCfgOptionChoicev3."Item Profit Group Code PNE");
    end;

    procedure UpdateWhenUsedUnitPriceAfterUnitCost(
        var IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3")
    begin
        if IWXCfgOptionChoicev3."Item Profit Group Code PNE" = '' then
            exit;

        if IWXCfgOptionChoicev3."Update Unit Price" <>
           IWXCfgOptionChoicev3."Update Unit Price"::"When Used"
        then
            exit;

        UpdateOptionChoiceUnitPriceFromProfitGroup(IWXCfgOptionChoicev3);
    end;

    procedure UpdateConfiguratorBOMUnitPrice(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3")
    var
        IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3";
    begin
        if IWXConfiguratorBOMv3."Item Profit Group Code PNE" <> '' then begin
            EnsureSupportedChoiceType(IWXConfiguratorBOMv3."Choice Type");

            IWXConfiguratorBOMv3."Unit Price" :=
                CalculateUnitPrice(
                    IWXConfiguratorBOMv3."Unit Cost",
                    IWXConfiguratorBOMv3."Item Profit Group Code PNE");
            exit;
        end;

        if IWXCfgOptionChoicev3.Get(
            IWXConfiguratorBOMv3."Item Category Code",
            IWXConfiguratorBOMv3."Configuration Option",
            IWXConfiguratorBOMv3."Choice Code")
        then
            IWXConfiguratorBOMv3."Unit Price" :=
                IWXCfgOptionChoicev3."Unit Price";
    end;

    procedure CalculateUnitPrice(
        UnitCost: Decimal;
        ItemProfitGroupCode: Code[10]): Decimal
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        ItemProfitGroupPTE: Record "Item Profit Group PTE";
        ProfitPercentage: Decimal;
    begin
        if ItemProfitGroupCode = '' then
            exit(0);

        if not ItemProfitGroupPTE.Get(ItemProfitGroupCode) then
            Error(
                ItemProfitGroupNotFoundErr,
                ItemProfitGroupCode);

        ProfitPercentage := ItemProfitGroupPTE."Profit %";
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
