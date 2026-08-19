namespace Pneuman.FrameSpecification;

page 50156 "PNE Frame Spec. Preview"
{
    ApplicationArea = All;
    Caption = 'Frame Specification Preview';
    Editable = false;
    PageType = List;
    SourceTable = "PNE Frame Spec. Line";
    SourceTableTemporary = true;
    SourceTableView = sorting(Description, "Line No.");
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Configuration Option"; Rec."Configuration Option")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the configuration option that generated this line.';
                }
                field("Line Type"; Rec."Line Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this is a plate or profile line.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the calculated quantity.';
                }
                field("Width (mm)"; Rec."Width (mm)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the calculated width.';
                }
                field("Height (mm)"; Rec."Height (mm)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the calculated height.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the description from the rule.';
                }
            }
        }
    }

    procedure SetLines(var TempPNEFrameSpecLine: Record "PNE Frame Spec. Line" temporary)
    begin
        Rec.Copy(TempPNEFrameSpecLine, true);
    end;
}
