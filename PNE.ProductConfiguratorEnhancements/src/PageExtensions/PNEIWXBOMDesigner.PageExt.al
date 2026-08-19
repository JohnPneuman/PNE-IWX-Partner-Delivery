namespace Pneuman.ProductConfigurator;

pageextension 50109 "PNE IWX BOM Designer" extends "IWX Configurator BOM Designer"
{
    layout
    {
        addafter("Unit Price")
        {
            field("Item Profit Group Code PNE"; Rec."Item Profit Group Code PNE")
            {
                ApplicationArea = All;
                Enabled = (Rec."Choice Type" = Rec."Choice Type"::Item) or
                    (Rec."Choice Type" = Rec."Choice Type"::"Production BOM");
            }
        }
    }
}
