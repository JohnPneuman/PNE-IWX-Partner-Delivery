tableextension 50105 "PNE IWX Option Choice" extends "IWX Cfg Option Choice v3"
{
    fields
    {
        field(50105; "Item Profit Group Code PNE"; Code[10])
        {
            Caption = 'Item Profit Group Code';
            DataClassification = CustomerContent;
            TableRelation = "Item Profit Group PTE".Code;
            ToolTip = 'Specifies the profit group used to calculate the unit price for this option choice. When blank for an item choice, the profit group from the item is used as the default in the configurator.';

            trigger OnValidate()
            var
                IWXPricingMgt: Codeunit "PNE IWX Pricing Mgt.";
            begin
                IWXPricingMgt.UpdateOptionChoiceUnitPrice(Rec);
            end;
        }
    }
}
