codeunit 50114 "PNE Smart Item No. Mgt."
{
    procedure SetOptionTextSequenceValue(
        var SequenceValue: Text;
        SmartItemNoConfig: Record "IWX Cfg. Smart Item No. Config";
        var TempConfiguratorBOMBuffer: Record "IWX Configurator BOM Buffer" temporary;
        var IsHandled: Boolean)
    var
        TempBOMBuffer: Record "IWX Configurator BOM Buffer" temporary;
    begin
        if SmartItemNoConfig.Type <> SmartItemNoConfig.Type::"Option Text" then
            exit;

        IsHandled := true;
        Clear(SequenceValue);

        if SmartItemNoConfig."Option Code" = '' then
            exit;

        TempBOMBuffer.Copy(TempConfiguratorBOMBuffer, true);
        TempBOMBuffer.SetRange(
            "Configuration Option",
            SmartItemNoConfig."Option Code");

        if TempBOMBuffer.FindFirst() then
            SequenceValue := TempBOMBuffer."Option Text";
    end;
}
