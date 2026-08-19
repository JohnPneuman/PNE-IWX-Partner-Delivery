codeunit 50102 "PNE IWX Add. Choices Mgt."
{
    procedure SetProductionBOMFilterTable(
        var ObjectID: Integer;
        ConfiguratorOption: Record "IWX Configurator Option v3")
    var
        IWXAdapter: Codeunit "PNE IWX Adapter";
    begin
        if not IWXAdapter.IsProductionBOMAdditionalChoices(
            ConfiguratorOption)
        then
            exit;

        ObjectID := Database::"Production BOM Header";
    end;


    procedure SelectProductionBOM(
        var ConfiguratorBOM: Record "IWX Configurator BOM v3")
    var
        ProductionBOMHeader: Record "Production BOM Header";
        IWXAdapter: Codeunit "PNE IWX Adapter";
        ProductionBOMList: Page "Production BOM List";
        AdditionalChoicesFilter: Text;
    begin
        if not IWXAdapter.GetProductionBOMAdditionalChoicesFilter(
            ConfiguratorBOM,
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

        IWXAdapter.EnsureAndApplyProductionBOMChoice(
            ConfiguratorBOM,
            ProductionBOMHeader);
    end;
}
