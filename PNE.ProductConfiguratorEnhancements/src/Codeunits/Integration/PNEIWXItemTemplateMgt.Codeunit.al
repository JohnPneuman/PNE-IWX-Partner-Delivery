codeunit 50116 "PNE IWX Item Template Mgt."
{
    procedure ApplyConfiguredItemDiscGroup(
        Item: Record Item;
        ConfiguratorBOM: Record "IWX Configurator BOM v3")
    var
        ConfigTemplateLine: Record "Config. Template Line";
        ConfiguratorItemCategory: Record "IWX Cfg Item Category v3";
        CreatedItem: Record Item;
        OptionCode: Code[20];
        ChoiceCode: Code[20];
    begin
        if not ConfiguratorItemCategory.Get(
            ConfiguratorBOM."Item Category Code")
        then
            exit;

        if ConfiguratorItemCategory."Data Template" = '' then
            exit;

        ConfigTemplateLine.SetRange(
            "Data Template Code",
            ConfiguratorItemCategory."Data Template");
        ConfigTemplateLine.SetRange("Table ID", Database::Item);
        ConfigTemplateLine.SetRange(
            "Field ID",
            CreatedItem.FieldNo("Item Disc. Group"));
        if not ConfigTemplateLine.FindFirst() then
            exit;

        if not TryGetOptionCode(
            ConfigTemplateLine."Default Value",
            OptionCode)
        then
            exit;

        ChoiceCode := GetChoiceCode(ConfiguratorBOM, OptionCode);
        if not CreatedItem.Get(Item."No.") then
            exit;

        CreatedItem.Validate("Item Disc. Group", ChoiceCode);
        CreatedItem.Modify(true);
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

    local procedure GetChoiceCode(
        ConfiguratorBOM: Record "IWX Configurator BOM v3";
        OptionCode: Code[20]): Code[20]
    var
        SelectedConfiguratorBOM: Record "IWX Configurator BOM v3";
    begin
        SelectedConfiguratorBOM.SetRange(
            "Configuration ID",
            ConfiguratorBOM."Configuration ID");
        SelectedConfiguratorBOM.SetRange(
            "Configuration Option",
            OptionCode);
        if not SelectedConfiguratorBOM.FindFirst() then
            exit('');

        exit(SelectedConfiguratorBOM."Choice Code");
    end;
}
