namespace Pneuman.ProductConfigurator;

using Microsoft.Manufacturing.ProductionBOM;

codeunit 50103 "PNE IWX Adapter"
{
    procedure IsProductionBOMAdditionalChoices(
        IWXConfiguratorOptionv3: Record "IWX Configurator Option v3"): Boolean
    begin
        exit(
            IWXConfiguratorOptionv3."Additional Choices Type" =
            IWXConfiguratorOptionv3."Additional Choices Type"::"Production BOMs");
    end;


    procedure GetProductionBOMAdditionalChoicesFilter(
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        var AdditionalChoicesFilter: Text): Boolean
    var
        IWXConfiguratorOptionv3: Record "IWX Configurator Option v3";
    begin
        if not IWXConfiguratorOptionv3.Get(
            IWXConfiguratorBOMv3."Item Category Code",
            IWXConfiguratorBOMv3."Configuration Option")
        then
            exit(false);

        if not IsProductionBOMAdditionalChoices(
            IWXConfiguratorOptionv3)
        then
            exit(false);

        AdditionalChoicesFilter :=
            IWXConfiguratorOptionv3."Additional Choices Filter";

        exit(true);
    end;


    procedure EnsureAndApplyProductionBOMChoice(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        ProductionBOMHeader: Record "Production BOM Header")
    var
        IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3";
    begin
        EnsureProductionBOMOptionChoice(
            IWXConfiguratorBOMv3,
            ProductionBOMHeader,
            IWXCfgOptionChoicev3);

        ApplyOptionChoiceToConfiguratorBOM(
            IWXConfiguratorBOMv3,
            IWXCfgOptionChoicev3);
    end;


    local procedure EnsureProductionBOMOptionChoice(
        IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        ProductionBOMHeader: Record "Production BOM Header";
        var IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3")
    begin
        if IWXCfgOptionChoicev3.Get(
            IWXConfiguratorBOMv3."Item Category Code",
            IWXConfiguratorBOMv3."Configuration Option",
            ProductionBOMHeader."No.")
        then begin
            if IWXCfgOptionChoicev3.Type <>
               IWXCfgOptionChoicev3.Type::"Production BOM"
            then
                Error(ChoiceCodeNotProductionBOMErr, ProductionBOMHeader."No.");

            if IWXCfgOptionChoicev3."No." <>
               ProductionBOMHeader."No."
            then
                Error(ChoiceCodeLinkedToDifferentNoErr, IWXCfgOptionChoicev3.Code, IWXCfgOptionChoicev3."No.");

            // IWX-kostprijs opnieuw berekenen.
            // Het OnAfterUpdateUnitCost-event telt daarna
            // de non-inventory kosten erbij op.
            IWXCfgOptionChoicev3.UpdateUnitCost();
            IWXCfgOptionChoicev3.Modify(true);

            exit;
        end;

        IWXCfgOptionChoicev3.Init();

        IWXCfgOptionChoicev3."Item Category Code" :=
            IWXConfiguratorBOMv3."Item Category Code";

        IWXCfgOptionChoicev3."Configuration Option" :=
            IWXConfiguratorBOMv3."Configuration Option";

        IWXCfgOptionChoicev3.Validate(
            Type,
            IWXCfgOptionChoicev3.Type::"Production BOM");

        // IWX vult hiermee onder andere:
        // Code, Description en Unit Cost.
        IWXCfgOptionChoicev3.Validate(
            "No.",
            ProductionBOMHeader."No.");

        IWXCfgOptionChoicev3.Insert(true);
    end;


    local procedure ApplyOptionChoiceToConfiguratorBOM(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3";
        IWXCfgOptionChoicev3: Record "IWX Cfg Option Choice v3")
    var
        PNEIWXPricingMgt: Codeunit "PNE IWX Pricing Mgt.";
    begin
        IWXConfiguratorBOMv3."Choice Code" :=
            CopyStr(
                IWXCfgOptionChoicev3.Code,
                1,
                MaxStrLen(IWXConfiguratorBOMv3."Choice Code"));

        IWXConfiguratorBOMv3.Description :=
            CopyStr(
                IWXCfgOptionChoicev3.Description,
                1,
                MaxStrLen(IWXConfiguratorBOMv3.Description));

        IWXConfiguratorBOMv3."Choice Type" :=
            IWXCfgOptionChoicev3.Type;

        IWXConfiguratorBOMv3."Choice No." :=
            CopyStr(
                IWXCfgOptionChoicev3."No.",
                1,
                MaxStrLen(IWXConfiguratorBOMv3."Choice No."));

        IWXConfiguratorBOMv3."Choice Variant Code" :=
            IWXCfgOptionChoicev3."Variant Code";

        IWXConfiguratorBOMv3."Choice Unit Price" :=
            IWXCfgOptionChoicev3."Unit Price";

        IWXConfiguratorBOMv3."Unit Price" :=
            IWXCfgOptionChoicev3."Unit Price";

        IWXConfiguratorBOMv3."Unit Cost" :=
            IWXCfgOptionChoicev3."Unit Cost";

        IWXConfiguratorBOMv3."Unit of Measure Code" :=
            IWXCfgOptionChoicev3."Unit of Measure Code";

        IWXConfiguratorBOMv3."Ext. Text Template" :=
            IWXCfgOptionChoicev3."Ext. Text Template";

        IWXConfiguratorBOMv3."Image Set Code" :=
            IWXCfgOptionChoicev3."Image Set Code";

        IWXConfiguratorBOMv3."Routing Link Code" :=
            IWXCfgOptionChoicev3.GetRoutingLinkCode();

        if IWXCfgOptionChoicev3."Default Quantity" <> 0 then
            IWXConfiguratorBOMv3."Quantity per Unit" :=
                IWXCfgOptionChoicev3."Default Quantity";

        PNEIWXPricingMgt.ApplyOptionChoiceToConfiguratorBOM(
            IWXConfiguratorBOMv3,
            IWXCfgOptionChoicev3);
    end;

    var
        ChoiceCodeLinkedToDifferentNoErr: Label 'Keuzecode %1 is gekoppeld aan nummer %2.', Comment = '%1 = option choice code, %2 = linked number';
        ChoiceCodeNotProductionBOMErr: Label 'Keuzecode %1 bestaat al, maar is geen Production BOM.', Comment = '%1 = production BOM number';
}
