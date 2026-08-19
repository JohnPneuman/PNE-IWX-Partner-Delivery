namespace Pneuman.ProductConfigurator;

using Microsoft.Inventory.Item;
using System.IO;

codeunit 50116 "PNE IWX Item Template Mgt."
{
    SingleInstance = true;

    procedure StartConfiguredItemCreation(
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3")
    var
        IWXCfgItemCategoryv3: Record "IWX Cfg Item Category v3";
    begin
        ClearConfiguredItemCreation();

        if not IWXCfgItemCategoryv3.Get(
            IWXConfiguratorBOMv3."Item Category Code")
        then
            exit;

        if IWXCfgItemCategoryv3."Data Template" = '' then
            exit;

        ActiveConfigurationID := IWXConfiguratorBOMv3."Configuration ID";
        ActiveDataTemplateCode := IWXCfgItemCategoryv3."Data Template";
    end;

    procedure ApplyItemDiscGroupPlaceholder(
        var RecordRef: RecordRef;
        FieldRef: FieldRef;
        ConfigTemplateLine: Record "Config. Template Line";
        var IsHandled: Boolean)
    var
        OptionCode: Code[20];
        ChoiceCode: Code[20];
    begin
        if not IsConfiguredItemDiscGroupPlaceholder(
            RecordRef,
            FieldRef,
            ConfigTemplateLine,
            OptionCode)
        then
            exit;

        ChoiceCode := GetChoiceCode(OptionCode);
        FieldRef.Validate(ChoiceCode);
        IsHandled := true;
    end;

    procedure ClearConfiguredItemCreation()
    begin
        Clear(ActiveConfigurationID);
        Clear(ActiveDataTemplateCode);
    end;

    local procedure IsConfiguredItemDiscGroupPlaceholder(
        RecordRef: RecordRef;
        FieldRef: FieldRef;
        ConfigTemplateLine: Record "Config. Template Line";
        var OptionCode: Code[20]): Boolean
    var
        Item: Record Item;
    begin
        if ActiveConfigurationID = '' then
            exit(false);

        if ConfigTemplateLine."Data Template Code" <> ActiveDataTemplateCode then
            exit(false);

        if (ConfigTemplateLine."Table ID" <> Database::Item) or
           (ConfigTemplateLine."Field ID" <> Item.FieldNo("Item Disc. Group"))
        then
            exit(false);

        if (RecordRef.Number <> Database::Item) or
           (FieldRef.Number <> Item.FieldNo("Item Disc. Group"))
        then
            exit(false);

        exit(TryGetOptionCode(ConfigTemplateLine."Default Value", OptionCode));
    end;

    local procedure TryGetOptionCode(
        DefaultValue: Text;
        var OptionCode: Code[20]): Boolean
    begin
        if (StrLen(DefaultValue) < 3) or
           (CopyStr(DefaultValue, 1, 1) <> '{') or
           (CopyStr(DefaultValue, StrLen(DefaultValue), 1) <> '}')
        then
            exit(false);

        if StrLen(DefaultValue) - 2 > MaxStrLen(OptionCode) then
            exit(false);

        exit(
            Evaluate(
                OptionCode,
                CopyStr(DefaultValue, 2, StrLen(DefaultValue) - 2)) and
            (OptionCode <> ''));
    end;

    local procedure GetChoiceCode(OptionCode: Code[20]): Code[20]
    var
        SelectedIWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
    begin
        SelectedIWXConfiguratorBOMv3.SetRange(
            "Configuration ID",
            ActiveConfigurationID);
        SelectedIWXConfiguratorBOMv3.SetRange(
            "Configuration Option",
            OptionCode);
        if not SelectedIWXConfiguratorBOMv3.FindFirst() then
            exit('');

        exit(SelectedIWXConfiguratorBOMv3."Choice Code");
    end;

    var
        ActiveConfigurationID: Code[20];
        ActiveDataTemplateCode: Code[10];
}
