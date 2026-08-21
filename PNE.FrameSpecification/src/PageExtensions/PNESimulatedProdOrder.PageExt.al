namespace Pneuman.FrameSpecification;

using Microsoft.Manufacturing.Document;

pageextension 50163 "PNE Simulated Prod. Order" extends "Simulated Production Order"
{
    actions
    {
        addlast("F&unctions")
        {
            action(PNEFrameSpecification)
            {
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
