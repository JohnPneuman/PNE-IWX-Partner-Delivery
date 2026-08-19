namespace Pneuman.ProductConfigurator;

pageextension 50107 "PNE IWX Option Choice Card" extends "IWX Configurator Choice Card"
{
    layout
    {
        addfirst(OptionChoicePrice)
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
