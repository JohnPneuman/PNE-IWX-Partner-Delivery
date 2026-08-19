codeunit 50116 "PNE IWX Item Template Mgt."
{
    SingleInstance = true;

    procedure StartConfiguredItemCreation(
        ConfiguratorBOM: Record "IWX Configurator BOM v3")
    var
        ConfiguratorItemCategory: Record "IWX Cfg Item Category v3";
    begin
        ClearConfiguredItemCreation();

        if not ConfiguratorItemCategory.Get(
            ConfiguratorBOM."Item Category Code")
        then
            exit;

        if ConfiguratorItemCategory."Data Template" = '' then
            exit;

        ActiveConfigurationID := ConfiguratorBOM."Configuration ID";
        ActiveDataTemplateCode := ConfiguratorItemCategory."Data Template";
    end;

    procedure ApplyItemDiscGroupPlaceholder(
        var RecRef: RecordRef;
        FieldRef: FieldRef;
        ConfigTemplateLine: Record "Config. Template Line";
        var IsHandled: Boolean)
    var
        OptionCode: Code[20];
        ChoiceCode: Code[20];
    begin
        if not IsConfiguredItemDiscGroupPlaceholder(
            RecRef,
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
        RecRef: RecordRef;
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

        if (RecRef.Number <> Database::Item) or
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
        SelectedConfiguratorBOM: Record "IWX Configurator BOM v3";
    begin
        SelectedConfiguratorBOM.SetRange(
            "Configuration ID",
            ActiveConfigurationID);
        SelectedConfiguratorBOM.SetRange(
            "Configuration Option",
            OptionCode);
        if not SelectedConfiguratorBOM.FindFirst() then
            exit('');

        exit(SelectedConfiguratorBOM."Choice Code");
    end;

    var
        ActiveConfigurationID: Code[20];
        ActiveDataTemplateCode: Code[10];
}
