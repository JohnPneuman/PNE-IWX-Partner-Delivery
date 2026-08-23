namespace Pneuman.FrameSpecification;

using Microsoft.Manufacturing.Document;

pageextension 50159 "PNE Released Prod. Order" extends "Released Production Order"
{
    actions
    {
        addlast("F&unctions")
        {
            action(PNEFrameSpecification)
            {
                AccessByPermission = codeunit "PNE Frame Spec. Action Mgt." = X;
                ApplicationArea = All;
                Caption = 'Frame Specification';
                Image = PrintReport;
                ToolTip = 'Creates the frame specification for the BMP configuration linked to this production order.';

                trigger OnAction()
                var
                    PNEFrameSpecActionMgt: Codeunit "PNE Frame Spec. Action Mgt.";
                begin
                    PNEFrameSpecActionMgt.OpenForProductionOrder(Rec);
                end;
            }
        }
    }
}
