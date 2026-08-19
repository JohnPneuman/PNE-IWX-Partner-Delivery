page 50161 "PNE Frame BOM Components"
{
    ApplicationArea = All;
    Caption = 'Production BOM Components';
    Editable = false;
    PageType = List;
    SourceTable = "Production BOM Line";
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the component item number.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the component description.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the component quantity.';
                }
            }
        }
    }
}
