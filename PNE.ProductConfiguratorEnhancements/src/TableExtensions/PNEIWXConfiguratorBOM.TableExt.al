namespace Pneuman.ProductConfigurator;

tableextension 50106 "PNE IWX Configurator BOM" extends "IWX Configurator BOM v3"
{
    fields
    {
        field(50105; "Item Profit Group Code PNE"; Code[10])
        {
            Caption = 'Item Profit Group Code';
            DataClassification = CustomerContent;
            TableRelation = "Item Profit Group PTE".Code;
            ToolTip = 'Specifies the profit group used to calculate the unit price for this configurator line.';

            trigger OnValidate()
            var
                PNEIWXPricingMgt: Codeunit "PNE IWX Pricing Mgt.";
            begin
                PNEIWXPricingMgt.UpdateConfiguratorBOMUnitPrice(Rec);
            end;
        }
    }
}
