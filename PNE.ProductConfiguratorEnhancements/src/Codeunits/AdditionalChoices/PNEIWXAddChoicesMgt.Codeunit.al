namespace Pneuman.ProductConfigurator;

using Microsoft.Manufacturing.ProductionBOM;

codeunit 50102 "PNE IWX Add. Choices Mgt."
{
    procedure SetProductionBOMFilterTable(
        var ObjectID: Integer;
        IWXConfiguratorOptionv3: Record "IWX Configurator Option v3")
    var
        PNEIWXAdapter: Codeunit "PNE IWX Adapter";
    begin
        if not PNEIWXAdapter.IsProductionBOMAdditionalChoices(
            IWXConfiguratorOptionv3)
        then
            exit;

        ObjectID := Database::"Production BOM Header";
    end;


    procedure SelectProductionBOM(
        var IWXConfiguratorBOMv3: Record "IWX Configurator BOM v3")
    var
        ProductionBOMHeader: Record "Production BOM Header";
        PNEIWXAdapter: Codeunit "PNE IWX Adapter";
        ProductionBOMList: Page "Production BOM List";
        AdditionalChoicesFilter: Text;
    begin
        if not PNEIWXAdapter.GetProductionBOMAdditionalChoicesFilter(
            IWXConfiguratorBOMv3,
            AdditionalChoicesFilter)
        then
            exit;

        if AdditionalChoicesFilter <> '' then
            ProductionBOMHeader.SetView(
                AdditionalChoicesFilter);

        ProductionBOMList.SetTableView(ProductionBOMHeader);
        ProductionBOMList.LookupMode(true);

        if ProductionBOMList.RunModal() <> Action::LookupOK then
            exit;

        ProductionBOMList.GetRecord(ProductionBOMHeader);

        PNEIWXAdapter.EnsureAndApplyProductionBOMChoice(
            IWXConfiguratorBOMv3,
            ProductionBOMHeader);
    end;
}
