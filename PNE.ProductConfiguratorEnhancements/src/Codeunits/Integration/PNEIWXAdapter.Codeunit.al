codeunit 50103 "PNE IWX Adapter"
{
    procedure IsProductionBOMAdditionalChoices(
        ConfiguratorOption: Record "IWX Configurator Option v3"): Boolean
    begin
        exit(
            ConfiguratorOption."Additional Choices Type" =
            ConfiguratorOption."Additional Choices Type"::"Production BOMs");
    end;


    procedure GetProductionBOMAdditionalChoicesFilter(
        ConfiguratorBOM: Record "IWX Configurator BOM v3";
        var AdditionalChoicesFilter: Text): Boolean
    var
        ConfiguratorOption: Record "IWX Configurator Option v3";
    begin
        if not ConfiguratorOption.Get(
            ConfiguratorBOM."Item Category Code",
            ConfiguratorBOM."Configuration Option")
        then
            exit(false);

        if not IsProductionBOMAdditionalChoices(
            ConfiguratorOption)
        then
            exit(false);

        AdditionalChoicesFilter :=
            ConfiguratorOption."Additional Choices Filter";

        exit(true);
    end;


    procedure EnsureAndApplyProductionBOMChoice(
        var ConfiguratorBOM: Record "IWX Configurator BOM v3";
        ProductionBOMHeader: Record "Production BOM Header")
    var
        OptionChoice: Record "IWX Cfg Option Choice v3";
    begin
        EnsureProductionBOMOptionChoice(
            ConfiguratorBOM,
            ProductionBOMHeader,
            OptionChoice);

        ApplyOptionChoiceToConfiguratorBOM(
            ConfiguratorBOM,
            OptionChoice);
    end;


    local procedure EnsureProductionBOMOptionChoice(
        ConfiguratorBOM: Record "IWX Configurator BOM v3";
        ProductionBOMHeader: Record "Production BOM Header";
        var OptionChoice: Record "IWX Cfg Option Choice v3")
    begin
        if OptionChoice.Get(
            ConfiguratorBOM."Item Category Code",
            ConfiguratorBOM."Configuration Option",
            ProductionBOMHeader."No.")
        then begin
            if OptionChoice.Type <>
               OptionChoice.Type::"Production BOM"
            then
                Error(
                    'Keuzecode %1 bestaat al, maar is geen Production BOM.',
                    ProductionBOMHeader."No.");

            if OptionChoice."No." <>
               ProductionBOMHeader."No."
            then
                Error(
                    'Keuzecode %1 is gekoppeld aan nummer %2.',
                    OptionChoice.Code,
                    OptionChoice."No.");

            // IWX-kostprijs opnieuw berekenen.
            // Het OnAfterUpdateUnitCost-event telt daarna
            // de non-inventory kosten erbij op.
            OptionChoice.UpdateUnitCost();
            OptionChoice.Modify(true);

            exit;
        end;

        OptionChoice.Init();

        OptionChoice."Item Category Code" :=
            ConfiguratorBOM."Item Category Code";

        OptionChoice."Configuration Option" :=
            ConfiguratorBOM."Configuration Option";

        OptionChoice.Validate(
            Type,
            OptionChoice.Type::"Production BOM");

        // IWX vult hiermee onder andere:
        // Code, Description en Unit Cost.
        OptionChoice.Validate(
            "No.",
            ProductionBOMHeader."No.");

        OptionChoice.Insert(true);
    end;


    local procedure ApplyOptionChoiceToConfiguratorBOM(
        var ConfiguratorBOM: Record "IWX Configurator BOM v3";
        OptionChoice: Record "IWX Cfg Option Choice v3")
    var
        IWXPricingMgt: Codeunit "PNE IWX Pricing Mgt.";
    begin
        ConfiguratorBOM."Choice Code" :=
            CopyStr(
                OptionChoice.Code,
                1,
                MaxStrLen(ConfiguratorBOM."Choice Code"));

        ConfiguratorBOM.Description :=
            CopyStr(
                OptionChoice.Description,
                1,
                MaxStrLen(ConfiguratorBOM.Description));

        ConfiguratorBOM."Choice Type" :=
            OptionChoice.Type;

        ConfiguratorBOM."Choice No." :=
            CopyStr(
                OptionChoice."No.",
                1,
                MaxStrLen(ConfiguratorBOM."Choice No."));

        ConfiguratorBOM."Choice Variant Code" :=
            OptionChoice."Variant Code";

        ConfiguratorBOM."Choice Unit Price" :=
            OptionChoice."Unit Price";

        ConfiguratorBOM."Unit Price" :=
            OptionChoice."Unit Price";

        ConfiguratorBOM."Unit Cost" :=
            OptionChoice."Unit Cost";

        ConfiguratorBOM."Unit of Measure Code" :=
            OptionChoice."Unit of Measure Code";

        ConfiguratorBOM."Ext. Text Template" :=
            OptionChoice."Ext. Text Template";

        ConfiguratorBOM."Image Set Code" :=
            OptionChoice."Image Set Code";

        ConfiguratorBOM."Routing Link Code" :=
            OptionChoice.GetRoutingLinkCode();

        if OptionChoice."Default Quantity" <> 0 then
            ConfiguratorBOM."Quantity per Unit" :=
                OptionChoice."Default Quantity";

        IWXPricingMgt.ApplyOptionChoiceToConfiguratorBOM(
            ConfiguratorBOM,
            OptionChoice);
    end;
}
