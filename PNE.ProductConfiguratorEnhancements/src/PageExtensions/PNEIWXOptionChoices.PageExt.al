namespace Pneuman.ProductConfigurator;

pageextension 50108 "PNE IWX Option Choices" extends "IWX Config. Option Choices"
{
    layout
    {
        addbefore("Unit Price")
        {
            field("Item Profit Group Code PNE"; Rec."Item Profit Group Code PNE")
            {
                ApplicationArea = All;
                Enabled = (Rec.Type = Rec.Type::Item) or
                    (Rec.Type = Rec.Type::"Production BOM");
            }
        }
    }
}
