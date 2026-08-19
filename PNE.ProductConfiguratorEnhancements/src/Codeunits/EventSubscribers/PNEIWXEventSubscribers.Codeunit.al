codeunit 50101 "PNE IWX Event Subscribers"
{
    // Bepaalt welke tabel IWX gebruikt voor het
    // instellen van het Additional Choices Filter.
    [EventSubscriber(
        ObjectType::Codeunit,
        Codeunit::"IWX Additional Choices Mgmt.",
        OnSetCustomAdditionalChoicesFilterObjectIDWithConfiguratorOption,
        '',
        false,
        false)]
    local procedure SetProductionBOMFilterTable(
        var piObjectID: Integer;
        precIWXConfiguratorOptionv3: Record "IWX Configurator Option v3")
    var
        AdditionalChoicesMgt: Codeunit "PNE IWX Add. Choices Mgt.";
    begin
        AdditionalChoicesMgt.SetProductionBOMFilterTable(
            piObjectID,
            precIWXConfiguratorOptionv3);
    end;


    // Selecteert een Production BOM vanuit Additional Choices.
    [EventSubscriber(
        ObjectType::Codeunit,
        Codeunit::"IWX Additional Choices Mgmt.",
        OnSelectCustomAdditionalChoicesWithConfiguratorBOM,
        '',
        false,
        false)]
    local procedure SelectProductionBOM(
        var precIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3")
    var
        AdditionalChoicesMgt: Codeunit "PNE IWX Add. Choices Mgt.";
    begin
        AdditionalChoicesMgt.SelectProductionBOM(
            precIWXConfiguratorBOMv3);
    end;


    // Wordt uitgevoerd nadat IWX zelf de Unit Cost
    // van een Option Choice heeft berekend.
    //
    // Voor Production BOMs tellen wij de door IWX
    // overgeslagen non-inventory componenten erbij op.
    //
    // Dit geldt voor alle Production BOM Option Choices,
    // niet alleen voor Additional Choices.
    [EventSubscriber(
        ObjectType::Table,
        Database::"IWX Cfg Option Choice v3",
        OnAfterUpdateUnitCost,
        '',
        false,
        false)]
    local procedure AddNonInventoryCostToProductionBOM(
        var precIWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3";
        pxrecIWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3")
    var
        ProductionBOMCostMgt: Codeunit "PNE Production BOM Cost Mgt.";
        IWXPricingMgt: Codeunit "PNE IWX Pricing Mgt.";
        NonInventoryCost: Decimal;
    begin
        if (precIWXCfgOptionChoicev3.Type =
            precIWXCfgOptionChoicev3.Type::"Production BOM") and
           (precIWXCfgOptionChoicev3."No." <> '')
        then begin
            NonInventoryCost :=
                ProductionBOMCostMgt.CalculateNonInventoryBOMCost(
                    precIWXCfgOptionChoicev3."No.",
                    WorkDate());

            precIWXCfgOptionChoicev3."Unit Cost" +=
                NonInventoryCost;
        end;

        IWXPricingMgt.UpdateWhenUsedUnitPriceAfterUnitCost(
            precIWXCfgOptionChoicev3);
    end;


    [EventSubscriber(
        ObjectType::Table,
        Database::"IWX Cfg Option Choice v3",
        OnBeforeUpdateUnitPrice,
        '',
        false,
        false)]
    local procedure CalculateOptionChoiceUnitPrice(
        var precIWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3";
        var pbIsHandled: Boolean)
    var
        IWXPricingMgt: Codeunit "PNE IWX Pricing Mgt.";
    begin
        if precIWXCfgOptionChoicev3."Item Profit Group Code PNE" = '' then
            exit;

        IWXPricingMgt.UpdateOptionChoiceUnitPriceFromProfitGroup(
            precIWXCfgOptionChoicev3);

        pbIsHandled := true;
    end;


    [EventSubscriber(
        ObjectType::Table,
        Database::"IWX Configurator BOM v3",
        OnAfterValidateChoiceCode,
        '',
        false,
        false)]
    local procedure ApplyProfitGroupToSelectedChoice(
        var precIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        pxrecIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3")
    var
        IWXPricingMgt: Codeunit "PNE IWX Pricing Mgt.";
    begin
        IWXPricingMgt.ApplySelectedChoiceToConfiguratorBOM(
            precIWXConfiguratorBOMv3);
    end;


    [EventSubscriber(
        ObjectType::Page,
        Page::"IWX Configurator BOM Designer",
        OnBeforeOpenPage,
        '',
        false,
        false)]
    local procedure ApplyProfitGroupDefaultsBeforeOpeningDesigner(
        var ptrecIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3" temporary;
        var pcodItemCategoryCode: Code[20])
    var
        IWXPricingMgt: Codeunit "PNE IWX Pricing Mgt.";
    begin
        IWXPricingMgt.ApplyDefaultsToConfiguratorBOM(
            ptrecIWXConfiguratorBOMv3);
    end;


    [EventSubscriber(
        ObjectType::Codeunit,
        Codeunit::"IWX Cfg. Smart Item No. Mgmt.",
        OnGetSequenceValueTypeElse,
        '',
        false,
        false)]
    local procedure SetSmartItemNoOptionText(
        var psValue: Text;
        precIWXCfgSmartItemNoConfig: Record "IWX Cfg. Smart Item No. Config";
        var ptrecIWXConfiguratorBOMBuffer: Record "IWX Configurator BOM Buffer" temporary;
        var pbIsHandled: Boolean)
    var
        SmartItemNoMgt: Codeunit "PNE Smart Item No. Mgt.";
    begin
        SmartItemNoMgt.SetOptionTextSequenceValue(
            psValue,
            precIWXCfgSmartItemNoConfig,
            ptrecIWXConfiguratorBOMBuffer,
            pbIsHandled);
    end;


    [EventSubscriber(
        ObjectType::Codeunit,
        Codeunit::"Transfer Extended Text",
        OnInsertSalesExtTextRetLastOnBeforeFindTempExtTextLine,
        '',
        false,
        false)]
    local procedure PrepareConfiguredSalesExtendedText(
        var TempExtendedTextLine: Record "Extended Text Line" temporary;
        SalesLine: Record "Sales Line")
    var
        IWXExtendedTextMgt: Codeunit "PNE IWX Extended Text Mgt.";
    begin
        if IsPreparingConfiguredSalesExtendedText then
            exit;

        IsPreparingConfiguredSalesExtendedText := true;
        IWXExtendedTextMgt.PrepareSalesExtendedText(
            TempExtendedTextLine,
            SalesLine);
        IsPreparingConfiguredSalesExtendedText := false;
    end;

    [EventSubscriber(
        ObjectType::Codeunit,
        Codeunit::"Transfer Extended Text",
        OnBeforeSalesCheckIfAnyExtText,
        '',
        false,
        false)]
    local procedure EnableConfiguredSalesExtendedText(
        var SalesLine: Record "Sales Line";
        SalesHeader: Record "Sales Header";
        Unconditionally: Boolean;
        var MakeUpdateRequired: Boolean;
        var AutoText: Boolean;
        var Result: Boolean;
        var IsHandled: Boolean)
    var
        IWXExtendedTextMgt: Codeunit "PNE IWX Extended Text Mgt.";
    begin
        if not IWXExtendedTextMgt.HasConfiguredSalesExtendedText(SalesLine) then
            exit;

        Result := true;
        IsHandled := true;
    end;

    [EventSubscriber(
        ObjectType::Codeunit,
        Codeunit::"IWX Configurator Mgmt.",
        OnBeforeCreateItemWithConfiguratorBOM,
        '',
        false,
        false)]
    local procedure StartConfiguredItemTemplateDefaults(
        precItem: Record Item;
        var precIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        var pbIsHandled: Boolean)
    var
        IWXItemTemplateMgt: Codeunit "PNE IWX Item Template Mgt.";
    begin
        IWXItemTemplateMgt.StartConfiguredItemCreation(
            precIWXConfiguratorBOMv3);
    end;

    [EventSubscriber(
        ObjectType::Codeunit,
        Codeunit::"Config. Template Management",
        OnInsertTemplateBeforeValidateFieldValue,
        '',
        false,
        false)]
    local procedure ApplyConfiguredItemTemplatePlaceholder(
        var RecRef: RecordRef;
        FieldRef: FieldRef;
        Value: Text[2048];
        LanguageID: Integer;
        var IsHandled: Boolean;
        ConfigTemplateLine: Record "Config. Template Line")
    var
        IWXItemTemplateMgt: Codeunit "PNE IWX Item Template Mgt.";
    begin
        IWXItemTemplateMgt.ApplyItemDiscGroupPlaceholder(
            RecRef,
            FieldRef,
            ConfigTemplateLine,
            IsHandled);
    end;

    [EventSubscriber(
        ObjectType::Codeunit,
        Codeunit::"IWX Configurator Mgmt.",
        OnAfterCreateItemWithConfiguratorBOM,
        '',
        false,
        false)]
    local procedure ClearConfiguredItemTemplateDefaults(
        precItem: Record Item;
        var precIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3")
    var
        IWXItemTemplateMgt: Codeunit "PNE IWX Item Template Mgt.";
    begin
        IWXItemTemplateMgt.ClearConfiguredItemCreation();
    end;


    var
        IsPreparingConfiguredSalesExtendedText: Boolean;
}
