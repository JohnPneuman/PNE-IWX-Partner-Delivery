namespace Pneuman.ProductConfigurator;

codeunit 50114 "PNE Smart Item No. Mgt."
{
    procedure SetOptionTextSequenceValue(
        var SequenceValue: Text;
        IWXCfgSmartItemNoConfig: Record "IWX Cfg. Smart Item No. Config";
        var TempIWXConfiguratorBOMBuffer: Record "IWX Configurator BOM Buffer" temporary;
        var IsHandled: Boolean)
    var
        TempCopyIWXConfiguratorBOMBuffer: Record "IWX Configurator BOM Buffer" temporary;
    begin
        if IWXCfgSmartItemNoConfig.Type <> IWXCfgSmartItemNoConfig.Type::"Option Text" then
            exit;

        IsHandled := true;
        Clear(SequenceValue);

        if IWXCfgSmartItemNoConfig."Option Code" = '' then
            exit;

        TempCopyIWXConfiguratorBOMBuffer.Copy(TempIWXConfiguratorBOMBuffer, true);
        TempCopyIWXConfiguratorBOMBuffer.SetRange(
            "Configuration Option",
            IWXCfgSmartItemNoConfig."Option Code");

        if TempCopyIWXConfiguratorBOMBuffer.FindFirst() then
            SequenceValue := TempCopyIWXConfiguratorBOMBuffer."Option Text";
    end;
}
