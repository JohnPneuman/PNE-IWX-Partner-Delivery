pageextension 50111 "PNE IWX Config. Option SF" extends "IWX Config. Option Subform"
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
